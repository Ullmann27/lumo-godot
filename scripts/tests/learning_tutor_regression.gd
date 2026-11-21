# gdlint: disable=max-file-lines
extends SceneTree
## Lumo-Nachhilfe 3D (scenes/learning/tutor_world.tscn) mit den echten
## App-Daten (Fixtures aus launchLumo3D: 8 + 5, 6 + 7, 3 + 9). Jeder Weg ×
## jede Stufe wird aufgebaut und mit echten Eingaben (Ziehen am Rahmen, Tippen
## auf Steine und Knöpfe) durchgespielt. Dazu: Vorzeigen → Üben, konkrete
## Hilfe bei Fehlgriffen, Zwillingsaufgabe selbst lösen, genau eine Rückgabe
## an den Host ohne Sterne/XP, Pause/Zurück, reduzierte Bewegung, Stimme
## aus/an, Bildschirmgrößen und ungültige Daten (fail-closed).

const FIXTURE := "res://scripts/tests/fixtures/tutor_payloads.json"
const SCENE := "res://scenes/learning/tutor_world.tscn"
const PLAN_PATH := "res://scripts/learning/tutor/tutor_plan.gd"
const DENSITY := 2.625
const STUFEN: Array[String] = ["hinweis", "teilschritt", "vorzeigen", "ueben"]

var checks := 0
var failures := 0
var cases: Dictionary = {}
var bridge: Node
## Teilläufe für gezielte Prüfungen: -- --part=every,voice (Standard: alle).
var parts: Array[String] = []


class HostFixture:
	extends RefCounted
	# Exakte Java-Namen an dieser einen Testgrenze.
	# gdlint: disable=function-name
	var returns: Array[Dictionary] = []
	var rewards: Array[String] = []
	var allow := true

	func returnToApp(destination: String, payload: String) -> bool:
		returns.append({"destination": destination, "payload": payload})
		return allow

	func reward(payload: String) -> bool:
		rewards.append(payload)
		return true


class SpeechFixture:
	extends RefCounted
	# gdlint: disable=function-name
	var spoken: Array[Dictionary] = []
	var stops := 0

	func speakLearning(payload: String) -> bool:
		spoken.append(JSON.parse_string(payload))
		return true

	func stopLearningSpeech() -> void:
		stops += 1

	func getLearningSpeechStatus() -> String:
		var last: Dictionary = spoken[-1] if not spoken.is_empty() else {}
		return JSON.stringify({"id": last.get("id", 0), "state": "playing", "audible": true})


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("[Tutor] FAIL " + message)


func _frames(count: int) -> void:
	for frame in range(count):
		await process_frame


func _learning(name_value: String, weg: String = "", stufe: String = "") -> Dictionary:
	var learning: Dictionary = cases[name_value].duplicate(true)
	if not weg.is_empty():
		learning.startWeg = weg
	if not stufe.is_empty():
		learning.startStufe = stufe
	return learning


func _open(learning: Dictionary, reduced: bool = true, extra: Dictionary = {}) -> Node3D:
	var options := {
		"learning": learning, "reduceAnimations": reduced, "sessionId": "kotlin-session"
	}
	options.merge(extra, true)
	var game: Node3D = (load(SCENE) as PackedScene).instantiate()
	game.capture_options = options
	root.add_child(game)
	await _frames(3)
	return game


func _close(game: Node3D) -> void:
	game.queue_free()
	await _frames(2)


func _settle(game: Node3D, limit: float = 20.0) -> void:
	var started := Time.get_ticks_msec()
	while not game.is_settled() and Time.get_ticks_msec() - started < limit * 1000.0:
		await process_frame
	await _frames(2)


# ---------------------------------------------------------------- echte Eingaben


func _touch(point: Vector2, pressed: bool, index: int = 0) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	root.push_input(event)


func _tap(point: Vector2) -> void:
	_touch(point, true)
	await process_frame
	_touch(point, false)
	await _frames(2)


func _drag(from: Vector2, to: Vector2) -> void:
	_touch(from, true)
	await process_frame
	for step in range(1, 7):
		var move := InputEventScreenDrag.new()
		move.index = 0
		move.position = from.lerp(to, step / 6.0)
		root.push_input(move)
		await process_frame
	_touch(to, false)
	await _frames(2)


## Ein Knopf wird wie mit dem Finger gedrückt (Mausemulation des Touchs).
func _press(button: Button) -> bool:
	if button == null or not button.is_visible_in_tree() or button.disabled:
		return false
	var center := button.get_global_rect().get_center()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = center
		event.global_position = center
		event.pressed = pressed
		root.push_input(event)
		await process_frame
	await _frames(2)
	return true


## Wie am echten Rechenrahmen: die äußerste Perle der Gruppe greifen und
## schieben, bis links genau [count] Perlen liegen (Finger = Gruppenrand).
func _drag_beads(game: Node3D, row: int, count: int) -> void:
	var current: int = game.tutor.reihe1 if row == 1 else game.tutor.reihe2
	var grab: int = clampi(count - 1, 0, 9) if count > current else clampi(count, 0, 9)
	var start: Vector2 = game.camera.unproject_position(game.frame.bead_position(row - 1, grab))
	var goal: Vector2 = game.frame.count_point(game.camera, row, count)
	await _drag(start, Vector2(goal.x, start.y))


func _tap_stone(game: Node3D, number: int) -> void:
	await _tap(game.camera.unproject_position(game.path.stone_position(number)))


func _choice(game: Node3D, name_value: String) -> Button:
	return game.choice_bar.get_node_or_null(name_value) as Button


## Den aktuellen Kind-Schritt mit echten Handgriffen richtig ausführen.
func _solve_step(game: Node3D) -> bool:
	var step: Dictionary = game.tutor.current()
	var before: int = game.tutor.schritt
	var action: Dictionary = step.aktion
	match str(action.art):
		"perlen":
			if game.tutor.reihe1 != int(action.reihe1):
				await _drag_beads(game, 1, int(action.reihe1))
			if game.tutor.schritt == before and game.tutor.reihe2 != int(action.reihe2):
				await _drag_beads(game, 2, int(action.reihe2))
		"huepfen":
			await _tap_stone(game, int(action.nach))
		"zerlegen":
			await _press(_choice(game, "Zerlegung_%d_%d" % [action.teil1, action.teil2]))
		"ergebnis":
			await _press(_choice(game, "Ergebnis_%d" % action.richtig))
		"zeigen":
			return false
	await _settle(game)
	return game.tutor.schritt == before + 1


## Ganzen Ablauf spielen: Lumo-Schritte mit „Weiter“, Kind-Schritte selbst.
func _play_through(game: Node3D, label: String) -> int:
	var guard := 0
	var by_child := 0
	while not game.tutor.current().is_empty() and guard < 12:
		guard += 1
		if game.tutor.lumo_turn():
			_check(game.weiter_button.visible, label + ": Weiter bei Lumos Schritt")
			_check(await _press(game.weiter_button), label + ": Weiter tippbar")
		else:
			_check(not game.weiter_button.visible, label + ": kein Weiter vor dem Handgriff")
			var art: String = game.tutor.current().aktion.art
			var step_text := str(game.tutor.current().aktion)
			var solved: bool = await _solve_step(game)
			_check(
				solved,
				(
					"%s: Handgriff %s erfüllt den Schritt %d %s (Rahmen %d/%d, '%s')"
					% [
						label,
						art,
						game.tutor.schritt,
						step_text,
						game.tutor.reihe1,
						game.tutor.reihe2,
						game.feedback.text
					]
				)
			)
			if not solved:
				return by_child
			by_child += 1
		await _settle(game)
	_check(game.tutor.fertig, label + ": Ablauf fertig")
	return by_child


# ---------------------------------------------------------------- Ablauf


func _run() -> void:
	bridge = root.get_node("HostBridge")
	bridge._options["displayDensity"] = DENSITY
	bridge._options["sessionId"] = "kotlin-session"
	root.size = Vector2i(1080, 2340)
	var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	_check(doc is Dictionary and doc.get("cases") is Array, "Fixture lesbar")
	for entry: Dictionary in doc.cases:
		cases[entry.name] = entry.learning
	_check(cases.size() == 3, "drei App-Fixtures (8+5, 6+7, 3+9)")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--part="):
			for part in argument.trim_prefix("--part=").split(","):
				parts.append(part)
	if _wants("validation"):
		_validation()
	if _wants("invalid"):
		await _invalid_scene()
	if _wants("every"):
		await _every_way_and_stage()
	if _wants("mistakes"):
		await _mistakes_get_concrete_help()
	if _wants("return"):
		await _show_then_practice_and_return()
	if _wants("bands"):
		await _row_bands()
	if _wants("walk"):
		await _lumo_walks_and_steps_back()
	if _wants("path"):
		await _path_steps_back()
	if _wants("pause"):
		await _pause_and_back()
	if _wants("voice"):
		await _voice()
	if _wants("layouts"):
		await _layouts()
	bridge._host = null
	bridge._return_pending = false
	print(
		"[Tutor] %s checks=%d failures=%d" % ["PASS" if failures == 0 else "FAIL", checks, failures]
	)
	var sound := root.get_node_or_null("GameSoundscape")
	if sound != null and sound.has_method("release_audio"):
		sound.release_audio()
	await create_timer(0.4).timeout
	quit(0 if failures == 0 else 1)


func _wants(part: String) -> bool:
	return parts.is_empty() or parts.has(part)


## Die Prüfung lehnt jede Abweichung vom App-Vertrag ab (fail-closed).
func _validation() -> void:
	var plan_script: GDScript = load(PLAN_PATH)
	for name_value: String in cases:
		_check(plan_script.new().configure(cases[name_value]), name_value + " wird angenommen")
	var base: Dictionary = cases.acht_plus_fuenf
	var broken: Array[Dictionary] = []
	broken.append({})
	broken.append({"kind": "tutor"})
	var variant := base.duplicate(true)
	variant.kind = "bridge_ten"
	broken.append(variant)
	variant = base.duplicate(true)
	variant.typ = "subtraktion"
	broken.append(variant)
	variant = base.duplicate(true)
	variant.b = 15
	broken.append(variant)
	variant = base.duplicate(true)
	variant.a = 8.5
	broken.append(variant)
	variant = base.duplicate(true)
	variant.wege = []
	broken.append(variant)
	variant = base.duplicate(true)
	variant.wege = ["rechenrahmen", "rechenrahmen", "zerlegen"]
	broken.append(variant)
	variant = base.duplicate(true)
	variant.wege = ["rechenrahmen", "zahlenstrahl", "zaubern"]
	broken.append(variant)
	variant = base.duplicate(true)
	variant.plaene.pop_back()
	broken.append(variant)
	variant = base.duplicate(true)
	variant.startWeg = "verdoppeln"
	broken.append(variant)
	variant = base.duplicate(true)
	variant.startStufe = "loesung"
	broken.append(variant)
	variant = base.duplicate(true)
	variant.fehler = "unbekannt"
	broken.append(variant)
	# Tipp an einer „Zwillingsaufgabe“: Hinweis gehört zur Originalaufgabe.
	variant = base.duplicate(true)
	variant.plaene[0].zwilling = true
	broken.append(variant)
	# Vorzeigen mit dem Ergebnis der Originalaufgabe würde sie verraten.
	variant = base.duplicate(true)
	for plan: Dictionary in variant.plaene:
		if plan.stufe == "vorzeigen":
			plan.a = 7
			plan.b = 6
	broken.append(variant)
	# Ergebniswahl an der Originalaufgabe (Hinweis) ist verboten.
	variant = base.duplicate(true)
	variant.plaene[0].schritte.append(
		{
			"id": "ergebnis",
			"wer": "kind",
			"text": "Tipp das Ergebnis.",
			"aktion": {"art": "ergebnis", "richtig": 13, "optionen": [12, 13, 14]}
		}
	)
	broken.append(variant)
	variant = base.duplicate(true)
	variant.plaene[0].schritte[0].text = "Ich schiebe\u0007 acht Perlen."
	broken.append(variant)
	variant = base.duplicate(true)
	variant.plaene[0].einleitung = "x".repeat(600)
	broken.append(variant)
	variant = base.duplicate(true)
	for index in range(8):
		variant.plaene[0].schritte.append(variant.plaene[0].schritte[0].duplicate(true))
	broken.append(variant)
	variant = base.duplicate(true)
	variant.plaene[0].schritte[0].aktion.reihe1 = 14
	broken.append(variant)
	variant = base.duplicate(true)
	for plan: Dictionary in variant.plaene:
		for step: Dictionary in plan.schritte:
			if step.aktion.art == "zerlegen":
				step.aktion.teil2 = 4
	broken.append(variant)
	variant = base.duplicate(true)
	for plan: Dictionary in variant.plaene:
		for step: Dictionary in plan.schritte:
			if step.aktion.art == "ergebnis":
				step.aktion.optionen = [1, 2, 3]
	broken.append(variant)
	variant = base.duplicate(true)
	for plan: Dictionary in variant.plaene:
		for step: Dictionary in plan.schritte:
			if step.aktion.art == "huepfen":
				step.aktion.nach = step.aktion.von
	broken.append(variant)
	variant = base.duplicate(true)
	variant.plaene[1].schritte[0].wer = "app"
	broken.append(variant)
	var refused := 0
	for index in range(broken.size()):
		var accepted: bool = plan_script.new().configure(broken[index])
		_check(not accepted, "ungültige Variante %d abgelehnt" % index)
		refused += 0 if accepted else 1
	print("[Tutor] fail-closed: %d/%d Varianten abgelehnt" % [refused, broken.size()])


func _invalid_scene() -> void:
	var host := HostFixture.new()
	bridge._host = host
	bridge._return_pending = false
	var game := await _open({"kind": "tutor", "a": 8, "b": 5})
	_check(not game.valid, "leerer Plan: Szene ungültig")
	_check(
		game.bubble_text.text.contains("nicht verfügbar"),
		"ungültig: ruhiger Hinweis statt Material"
	)
	_check(not game.frame.visible and not game.path.visible, "ungültig: kein Material")
	_check(
		not game.weiter_button.visible and not game.mehr_button.visible,
		"ungültig: keine Lernknöpfe"
	)
	await _tap(Vector2(540, 1300))
	_check(game.tutor.schritt == 0, "ungültig: Eingaben bewirken nichts")
	_check(await _press(game.zurueck_button), "ungültig: Zur Aufgabe bleibt bedienbar")
	_check(host.returns.size() == 1, "ungültig: genau eine Rückkehr")
	if host.returns.size() == 1:
		var payload: Dictionary = JSON.parse_string(host.returns[0].payload)
		_check(not payload.has("holo"), "ungültig: keine Zusammenfassung")
		_check(host.returns[0].destination == "learn", "ungültig: zurück zur Aufgabe")
	_check(host.rewards.is_empty(), "ungültig: kein Lohn")
	bridge._host = null
	bridge._return_pending = false
	await _close(game)


## Aufbau je Weg × Stufe mit echten App-Daten und echten Eingaben.
func _every_way_and_stage() -> void:
	var runs := 0
	var child_steps := 0
	for name_value: String in cases:
		var data: Dictionary = cases[name_value]
		for weg: String in data.wege:
			for stufe: String in STUFEN:
				var label := "%s %s/%s" % [name_value, weg, stufe]
				var game := await _open(_learning(name_value, weg, stufe))
				_check(game.valid, label + ": gültig")
				_check(game.tutor.weg == weg and game.tutor.stufe == stufe, label + ": Startpunkt")
				var art: String = game.tutor.material()
				_check(game.frame.visible == (art == "perlen"), label + ": Rahmen passt zum Weg")
				_check(game.path.visible == (art == "huepfen"), label + ": Steinweg passt zum Weg")
				var has_split := false
				for step: Dictionary in game.tutor.steps():
					has_split = has_split or step.aktion.art == "zerlegen"
				_check(
					game.split_blocks.visible == has_split, label + ": Zahlenhaus nur beim Zerlegen"
				)
				_check(game.stufe_buttons.size() == 4, label + ": vier Hilfestufen")
				_check(game.weg_buttons.size() == data.wege.size(), label + ": alle Wege wählbar")
				_check(not game.bubble_text.text.is_empty(), label + ": Lumo spricht als Text")
				child_steps += await _play_through(game, label)
				var done: bool = game.events.has("done:%s/%s" % [weg, stufe])
				_check(done, label + ": Abschluss erreicht")
				_check(game.bubble_role.text == "Geschafft!", label + ": Abschluss sichtbar")
				_check(game.zurueck_button.visible, label + ": Zurück zur Aufgabe angeboten")
				if stufe in ["hinweis", "teilschritt"]:
					# Die Originalaufgabe wird in der Nachhilfe nie gelöst.
					_check(
						not game.bubble_text.text.contains("= %d" % (data.a + data.b)),
						label + ": Original nicht verraten"
					)
				runs += 1
				await _close(game)
	print("[Tutor] Abläufe=%d Kind-Handgriffe=%d" % [runs, child_steps])
	_check(runs == 3 * 4 + 4 * 4 + 4 * 4, "alle 44 Weg×Stufe-Abläufe gespielt")


## Falscher Handgriff → ruhige, konkrete Hilfe; zweimal → Lumo zeigt es einmal.
func _mistakes_get_concrete_help() -> void:
	# Rahmen: zu viele Perlen.
	var game := await _open(_learning("acht_plus_fuenf", "rechenrahmen", "ueben"))
	var target: int = game.tutor.current().aktion.reihe1
	await _drag_beads(game, 1, target + 2)
	_check(game.tutor.schritt == 0, "Rahmen: zu viele erfüllen den Schritt nicht")
	_check(
		game.feedback.text.contains("oberen Reihe") and game.feedback.text.contains("zu viele"),
		"Rahmen: konkrete Hilfe '%s'" % game.feedback.text
	)
	_check(game.events.has("lumo:encourage"), "Rahmen: Lumo ermutigt ruhig")
	_check(not game.weiter_button.visible, "Rahmen: nach dem ersten Fehler kein Vorzeigen")
	await _drag_beads(game, 1, target + 1)
	_check(game.tutor.vorgezeigt, "Rahmen: nach zwei Fehlgriffen zeigt Lumo den Schritt")
	_check(
		game.feedback.text.contains("Ich zeige es dir einmal"), "Rahmen: angekündigtes Vorzeigen"
	)
	_check(game.tutor.reihe1 == target, "Rahmen: Zielzustand vorgezeigt")
	_check(game.weiter_button.visible, "Rahmen: danach weiter")
	await _press(game.weiter_button)
	await _settle(game)
	while not game.tutor.current().is_empty():
		if game.tutor.lumo_turn() or game.tutor.vorgezeigt:
			await _press(game.weiter_button)
		else:
			await _solve_step(game)
		await _settle(game)
	_check(not game.twin_solved, "Rahmen: mit Vorzeigen gilt die Übung nicht als allein gelöst")
	await _close(game)
	# Steinweg: zu kurz und zu weit.
	game = await _open(_learning("sechs_plus_sieben", "zahlenstrahl", "ueben"))
	var step: Dictionary = game.tutor.current().aktion
	await _tap_stone(game, int(step.nach) - 1)
	_check(
		game.feedback.text.contains("weiter springen"),
		"Steinweg: zu kurz '%s'" % game.feedback.text
	)
	_check(game.path._highlight.visible, "Steinweg: getippter Stein markiert")
	game.tutor.fehlversuche = 0
	await _tap_stone(game, int(step.nach) + 2)
	_check(game.feedback.text.contains("Zu weit"), "Steinweg: zu weit '%s'" % game.feedback.text)
	_check(game.tutor.schritt == 0, "Steinweg: falscher Stein erfüllt nichts")
	await _close(game)
	# Zerlegen: falsche Zerlegung.
	game = await _open(_learning("acht_plus_fuenf", "zerlegen", "ueben"))
	await _solve_step(game)
	var split: Dictionary = game.tutor.current().aktion
	_check(split.art == "zerlegen", "Zerlegen: zweiter Schritt ist das Zerlegen")
	for pair: Array in split.zerlegungen:
		if int(pair[0]) != int(split.teil1):
			await _press(_choice(game, "Zerlegung_%d_%d" % [pair[0], pair[1]]))
			break
	_check(
		game.feedback.text.contains("nicht genau 10"),
		"Zerlegen: konkrete Hilfe '%s'" % game.feedback.text
	)
	_check(game.tutor.zerlegung.is_empty(), "Zerlegen: falsche Teile nicht übernommen")
	await _close(game)
	# Ergebnis: falsche Zahl.
	game = await _open(_learning("drei_plus_neun", "tauschen", "ueben"))
	await _solve_step(game)
	await _solve_step(game)
	var result: Dictionary = game.tutor.current().aktion
	_check(result.art == "ergebnis", "Tauschen: dritter Schritt ist die Ergebniswahl")
	for value: int in result.optionen:
		if value != int(result.richtig):
			await _press(_choice(game, "Ergebnis_%d" % value))
			break
	_check(
		game.feedback.text.contains("gelandet"),
		"Ergebnis: Blick auf Lumos Landeplatz '%s'" % game.feedback.text
	)
	_check(game.tutor.gewaehlt == -1, "Ergebnis: falsche Zahl nicht übernommen")
	await _close(game)


## Vorzeigen → Mehr Hilfe → Selbst üben → Zur Aufgabe: genau eine Rückgabe.
func _show_then_practice_and_return() -> void:
	var host := HostFixture.new()
	bridge._host = host
	bridge._return_pending = false
	var learning := _learning("acht_plus_fuenf", "rechenrahmen", "vorzeigen")
	var game := await _open(learning)
	var shown: Dictionary = game.tutor.plan()
	_check(shown.zwilling and shown.a + shown.b != 13, "Vorzeigen an einer Zwillingsaufgabe")
	_check(game.bubble_role.text == "Lumo zeigt", "Vorzeigen: Lumo macht vor")
	_check(game.fox_spot == "show", "Vorzeigen: Lumo steht am Rahmen")
	_check(await _play_through(game, "Vorzeigen") == 0, "Vorzeigen: das Kind schaut nur zu")
	_check(game.fox_spot == "home", "Vorzeigen: danach tritt Lumo zurück")
	_check(
		game.mehr_button.visible and game.mehr_button.text.contains("Selbst üben"),
		"Mehr Hilfe führt zu Selbst üben"
	)
	await _press(game.mehr_button)
	await _settle(game)
	_check(game.tutor.stufe == "ueben", "Stufe Selbst üben aktiv")
	var practice: Dictionary = game.tutor.plan()
	_check(practice.zwilling and practice.a + practice.b != 13, "Üben: ähnliche, andere Aufgabe")
	_check(practice.a != shown.a or practice.b != shown.b, "Üben: nicht dieselbe wie vorgezeigt")
	_check(
		game.task_label.text.contains("%d + %d" % [practice.a, practice.b]),
		"Üben: Rechnung sichtbar"
	)
	var child := await _play_through(game, "Üben")
	_check(child == game.tutor.steps().size(), "Üben: jeden Schritt macht das Kind")
	_check(game.twin_solved and game.twin_attempts == 1, "Üben: Zwilling allein im ersten Versuch")
	_check(not game.mehr_button.visible, "Üben: keine weitere Stufe")
	_check(game.events.count("return") == 0, "noch keine Rückgabe vor dem Tippen")
	_check(await _press(game.zurueck_button), "Zur Aufgabe tippbar")
	await _press(game.zurueck_button)
	game.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await _frames(2)
	_check(host.returns.size() == 1, "genau eine Rückgabe an den Host (%d)" % host.returns.size())
	_check(host.rewards.is_empty(), "kein Lohn/keine Sterne an den Host")
	if host.returns.size() >= 1:
		_check(host.returns[0].destination == "learn", "Rückkehr zur Aufgabe")
		var payload: Dictionary = JSON.parse_string(host.returns[0].payload)
		_check(
			payload.status == "illustrated" and payload.game == "learning",
			"Rückgabe als Illustration"
		)
		_check(payload.sessionId == "kotlin-session", "Rückgabe trägt die Sitzung")
		var summary: Dictionary = payload.get("holo", {})
		_check(summary.kind == "tutor", "Zusammenfassung: Nachhilfe")
		_check(summary.taskId == learning.scope.taskId, "Zusammenfassung: dieselbe Aufgabe")
		_check(
			summary.originalAnswer == "" and summary.originalCorrect == false,
			"Original bleibt offen"
		)
		_check(int(summary.originalAttempts) == 0, "keine Antwort auf das Original")
		_check(int(summary.hintLevel) == 3, "Hilfegrad: bis Selbst üben")
		_check(
			summary.twinSolved == true and int(summary.twinAttempts) == 1, "Zwilling allein gelöst"
		)
		_check(summary.twinPrompt == "%d + %d = ?" % [practice.a, practice.b], "Zwillings-Rechnung")
		_check(summary.mode == "rechenrahmen", "Weg der Übung")
		var text := JSON.stringify(payload).to_lower()
		for word in ["stars", "sterne", "xp", "reward", "score"]:
			_check(not text.contains('"%s"' % word), "keine %s in der Rückgabe" % word)
		_check(JSON.stringify(summary).length() < 4000, "Zusammenfassung unter der Kotlin-Grenze")
	await _close(game)
	# Fehlschlag beim Host: Hinweis, zweiter Versuch erlaubt.
	host = HostFixture.new()
	host.allow = false
	bridge._host = host
	bridge._return_pending = false
	game = await _open(_learning("sechs_plus_sieben", "verdoppeln", "hinweis"))
	await _press(game.zurueck_button)
	_check(game.feedback.text == bridge.SAVE_FAILURE, "Host lehnt ab: ehrlicher Hinweis")
	_check(game.return_count == 0, "Host lehnt ab: nichts als zurückgegeben gezählt")
	host.allow = true
	await _press(game.zurueck_button)
	_check(game.return_count == 1 and host.returns.size() == 2, "zweiter Versuch geht durch")
	var later: Dictionary = JSON.parse_string(host.returns[1].payload).holo
	_check(later.twinSolved == false and int(later.hintLevel) == 0, "nur Tipp: kein Lernnachweis")
	bridge._host = null
	bridge._return_pending = false
	await _close(game)


## Jede Perlenreihe ist ein Fingerstreifen von mindestens 48 dp: Ein Finger
## über Reihe 1 oder unter Reihe 2 (abseits der Perlen) greift die richtige Reihe.
func _row_bands() -> void:
	var minimum := 48.0 * DENSITY
	var game := await _open(_learning("acht_plus_fuenf", "rechenrahmen", "ueben"))
	var band_px: float = game.touch_band()
	var band: float = game.frame.row_band(game.camera, band_px)
	_check(band >= minimum, "Perlenreihe als Fingerziel %.0f px ≥ 48 dp" % band)
	var top: float = game.camera.unproject_position(game.frame.row_anchor(0)).y
	var bottom: float = game.camera.unproject_position(game.frame.row_anchor(1)).y
	var footer: Rect2 = game.footer.get_global_rect()
	var bubble: Rect2 = game.bubble.get_global_rect()
	# Reihe 1: Finger deutlich über der Stange, rechts bei den freien Perlen.
	var goal: Vector2 = game.frame.count_point(game.camera, 1, 8)
	var right: Vector2 = game.frame.count_point(game.camera, 1, 10)
	var above := Vector2(right.x, top - band_px * 0.7)
	_check(not bubble.has_point(above), "Fingerpunkt über Reihe 1 liegt auf der Bühne")
	await _drag(above, Vector2(goal.x, above.y))
	_check(
		game.tutor.reihe1 == 8 and game.tutor.schritt == 1,
		"Reihe 1 über der Stange gegriffen (%d)" % game.tutor.reihe1
	)
	await _settle(game)
	await _drag_beads(game, 1, 10)
	await _settle(game)
	_check(game.tutor.schritt == 2, "Reihe 1 voll")
	# Reihe 2: Finger unter der Stange.
	goal = game.frame.count_point(game.camera, 2, 2)
	right = game.frame.count_point(game.camera, 2, 10)
	var below := Vector2(right.x, bottom + band_px * 0.7)
	_check(not footer.has_point(below), "Fingerpunkt unter Reihe 2 liegt auf der Bühne")
	await _drag(below, Vector2(goal.x, below.y))
	_check(
		game.tutor.reihe2 == 2 and game.tutor.reihe1 == 10 and game.tutor.schritt == 3,
		"Reihe 2 unter der Stange gegriffen (%d/%d)" % [game.tutor.reihe1, game.tutor.reihe2]
	)
	# Zwischen den Stangen entscheidet die nähere Reihe (Kamera steht nach
	# dem Schrittwechsel neu: Lage frisch messen).
	await _settle(game)
	top = game.camera.unproject_position(game.frame.row_anchor(0)).y
	bottom = game.camera.unproject_position(game.frame.row_anchor(1)).y
	right = game.frame.count_point(game.camera, 2, 10)
	var middle := (top + bottom) * 0.5
	var probe := Vector2(right.x, middle - 2)
	_check(game.frame.row_at(game.camera, probe, band_px) == 1, "knapp über der Mitte: Reihe 1")
	probe.y = middle + 2
	_check(game.frame.row_at(game.camera, probe, band_px) == 2, "knapp unter der Mitte: Reihe 2")
	probe.y = top - band_px * 1.2
	_check(game.frame.row_at(game.camera, probe, band_px) == 0, "weit über dem Rahmen: keine Reihe")
	await _close(game)


## Am Rahmen geht Lumo zum linken Rahmenende, zeigt und tritt wieder zurück.
func _lumo_walks_and_steps_back() -> void:
	var game := await _open(_learning("acht_plus_fuenf", "rechenrahmen", "teilschritt"), false)
	_check(game.events.has("walk:show"), "Lumo geht für seinen Schritt zum Rahmen")
	var walked := false
	for frame in range(6):
		walked = walked or game.fox_spot == "walking"
		await process_frame
	_check(walked or game.fox_spot == "show", "Lumo läuft sichtbar (keine Teleportation)")
	await _settle(game)
	_check(game.fox_spot == "show", "Lumo steht am Zeigeplatz")
	_check(game.fox.position.distance_to(game.FOX_SHOW) < 1.0, "Zeigeplatz am linken Rahmenende")
	_check(game.events.has("lumo:explain"), "Lumo zeigt")
	_check(game.fox_point_target.x < -1.0, "Lumo zeigt auf die gezählten Perlen links")
	var left_bead: Vector2 = game.camera.unproject_position(game.frame.bead_position(0, 0))
	var fox_screen: Vector2 = game.camera.unproject_position(game.fox.global_position)
	_check(fox_screen.x < left_bead.x, "Lumo steht links neben den Perlen, nicht davor")
	await _press(game.weiter_button)
	_check(game.bubble_role.text == "Du bist dran", "danach ist das Kind dran")
	await _settle(game)
	_check(game.fox_spot == "home", "Lumo tritt aus der Mitte zurück")
	_check(game.events.has("lumo:encourage"), "Lumo ermutigt vom Rand aus")
	await _close(game)
	# Reduzierte Bewegung: gleiche Plätze, kein Laufen.
	game = await _open(_learning("acht_plus_fuenf", "zerlegen", "vorzeigen"), true)
	_check(game.fox_spot == "show", "reduziert: sofort am Zeigeplatz")
	_check(game.is_settled(), "reduziert: Perlen stehen sofort")
	await _press(game.weiter_button)
	var parts: Dictionary = game.tutor.current().aktion
	_check(parts.art == "zerlegen", "Zerlegen: Lumo zerlegt im zweiten Schritt")
	_check(game.split_blocks.split_count() == int(parts.teil1), "Zerlegen: Teil macht die 10 voll")
	var first: Vector3 = game.split_blocks.first_part_position()
	_check(game.fox_point_target.distance_to(first) < 0.01, "Lumo zeigt auf den ersten Teil")
	await _close(game)


## Auf dem Steinweg springt Lumo und tritt danach hinter den Weg.
func _path_steps_back() -> void:
	var game := await _open(_learning("sechs_plus_sieben", "zahlenstrahl", "vorzeigen"), false)
	var hopping := false
	var start_x: float = game.fox.position.x
	for frame in range(20):
		hopping = hopping or game.fox_spot == "stone"
		await process_frame
	_check(hopping, "Lumo springt über die Steine")
	await _settle(game)
	_check(game.fox.position.x > start_x + 1.0, "Lumo ist vorwärts gesprungen")
	_check(game.fox_spot == "behind", "nach dem Sprung tritt Lumo hinter den Weg")
	var landing: Vector3 = game.path.stone_position(game.tutor.position)
	_check(absf(game.fox.position.x - landing.x) < 0.05, "Lumo bleibt bei seiner Zahl")
	_check(game.fox.position.z < landing.z - 0.8, "die Zahl unter Lumo liegt frei")
	_check(game.path.hop_count() == game.tutor.position, "jeder Einersprung als Bogen sichtbar")
	await _close(game)
	# Reduziert: alle Bögen sofort.
	game = await _open(_learning("sechs_plus_sieben", "zahlenstrahl", "vorzeigen"), true)
	_check(game.path.hop_count() == game.tutor.position, "reduziert: alle Bögen sofort")
	_check(game.fox_spot == "behind", "reduziert: Lumo sofort hinter dem Weg")
	await _close(game)


## Pause friert alles ein (auch Eingaben); Zurück-Taste kehrt einmal zurück.
func _pause_and_back() -> void:
	var host := HostFixture.new()
	bridge._host = host
	bridge._return_pending = false
	var game := await _open(_learning("acht_plus_fuenf", "zahlenstrahl", "teilschritt"), false)
	game.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	var frozen: Vector3 = game.fox.position
	await _frames(10)
	_check(game.suspended, "Pause erkannt")
	_check(game.fox.position == frozen, "Pause: Lumo bleibt stehen")
	game.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	await _settle(game)
	_check(not game.suspended and game.fox_spot == "behind", "nach der Pause geht es weiter")
	_check(await _press(game.weiter_button), "Lumos Schritt fertig")
	await _settle(game)
	game.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	var number: int = game.tutor.current().aktion.nach
	await _tap_stone(game, number)
	_check(game.tutor.schritt == 1, "Pause: Tippen wird ignoriert")
	game.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	await _tap_stone(game, number)
	_check(game.tutor.schritt == 2, "nach der Pause zählt das Tippen")
	game.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	game.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await _frames(2)
	_check(host.returns.size() == 1, "Zurück-Taste: genau eine Rückgabe")
	if host.returns.size() == 1:
		var summary: Dictionary = JSON.parse_string(host.returns[0].payload).holo
		_check(
			int(summary.hintLevel) == 1 and summary.twinSolved == false,
			"Teilschritt: kein Lernnachweis"
		)
	bridge._host = null
	bridge._return_pending = false
	await _close(game)


## Ton aus → Text bleibt. Ton an → Vorlesen, Stopp, erneut hören, überspringen.
func _voice() -> void:
	var game := await _open(_learning("acht_plus_fuenf", "rechenrahmen", "teilschritt"))
	_check(not game.voice_button.visible, "Ton aus: kein Vorlesen-Knopf")
	_check(game.bubble_text.text.contains("8 Perlen"), "Ton aus: Lumos Satz steht als Text")
	await _close(game)
	var voice := {"learningVoiceEnabled": true, "localVoiceLicenseAccepted": true}
	game = await _open(_learning("acht_plus_fuenf", "rechenrahmen", "teilschritt"), true, voice)
	var speech := SpeechFixture.new()
	game._speech_host = speech
	_check(game.voice_button.visible and game.voice_button.text == "Vorlesen", "Ton an: Vorlesen")
	await _press(game.voice_button)
	_check(speech.spoken.size() == 1, "Vorlesen startet genau eine Ansage")
	if speech.spoken.size() == 1:
		_check(str(speech.spoken[0].text).contains("8 Perlen"), "es wird Lumos Satz gelesen")
		_check(speech.spoken[0].taskId == game.companion_scope.task_id, "Ansage im Lern-Scope")
	await _frames(4)
	_check(game.voice_button.text == "Stopp", "während des Lesens: Stopp")
	await _press(game.voice_button)
	_check(speech.stops >= 1 and game.voice_button.text == "Vorlesen", "Stopp beendet die Ansage")
	await _press(game.voice_button)
	_check(speech.spoken.size() == 2, "erneut hören")
	var stops: int = speech.stops
	await _press(game.weiter_button)
	_check(speech.stops > stops, "Weiter überspringt die laufende Ansage")
	_check(speech.spoken.size() == 2, "ohne automatisches Vorlesen keine neue Ansage")
	await _close(game)
	voice["learningAutoRead"] = true
	game = await _open(_learning("acht_plus_fuenf", "rechenrahmen", "teilschritt"), true, voice)
	speech = SpeechFixture.new()
	game._speech_host = speech
	await _press(game.weiter_button)
	_check(speech.spoken.size() == 1, "automatisches Vorlesen beim nächsten Schritt")
	await _close(game)


func _panel_rect(control: Control) -> Rect2:
	return control.get_global_rect()


## Fold zu/auf, quer: nichts verdeckt Material und Knöpfe, Ziele ≥ 48 dp.
func _layouts() -> void:
	var minimum := 48.0 * DENSITY
	for size_value in [Vector2i(1080, 2340), Vector2i(1812, 2176), Vector2i(2176, 1812)]:
		root.size = size_value
		for weg: String in ["rechenrahmen", "zahlenstrahl", "zerlegen"]:
			var label := "%s %dx%d" % [weg, size_value.x, size_value.y]
			var game := await _open(_learning("acht_plus_fuenf", weg, "ueben"))
			if weg == "zerlegen":
				await _solve_step(game)
			await _frames(3)
			var screen := Rect2(Vector2.ZERO, Vector2(size_value))
			var panels: Array[Rect2] = [
				_panel_rect(game.header), _panel_rect(game.bubble), _panel_rect(game.footer)
			]
			for panel in panels:
				_check(screen.encloses(panel), label + ": Tafel ganz im Bild %s" % panel)
			_check(not panels[0].intersects(panels[2]), label + ": Kopf und Fuß überlappen nicht")
			_check(not panels[1].intersects(panels[2]), label + ": Sprechblase und Fuß getrennt")
			var buttons: Array[Button] = []
			for container: Node in [game.stufen_row, game.wege_row, game.choice_bar, game.actions]:
				for child in container.get_children():
					if child is Button and child.visible:
						buttons.append(child)
			buttons.append(game.zurueck_button)
			for button in buttons:
				var rect: Rect2 = button.get_global_rect()
				_check(
					rect.size.x >= minimum and rect.size.y >= minimum,
					label + ": %s ≥ 48 dp (%s)" % [button.text, rect.size]
				)
				_check(screen.encloses(rect), label + ": %s im Bild" % button.text)
			if weg != "zahlenstrahl":
				var band: float = game.frame.row_band(game.camera, game.touch_band())
				_check(band >= minimum, label + ": Perlenreihe ≥ 48 dp (%.0f px)" % band)
			var font_px: float = game.bubble_text.get_theme_font_size("font_size") * game.ui.scale.x
			_check(font_px >= 16.0 * DENSITY, label + ": Lumos Text lesbar (%.0f px)" % font_px)
			var points: Array[Vector3] = []
			if weg == "zahlenstrahl":
				var step: Dictionary = game.tutor.current().aktion
				for number in range(int(step.von), int(step.nach) + 1):
					points.append(game.path.stone_position(number))
			else:
				for row in range(2):
					for index in [0, 9]:
						points.append(game.frame.bead_position(row, index))
				points.append(game.frame.get_node("Reihe1Zahl").global_position)
				if weg == "zerlegen":
					points.append(game.split_blocks.first_part_position())
			for point in points:
				var projected: Vector2 = game.camera.unproject_position(point)
				var covered := false
				for panel in panels:
					covered = covered or panel.has_point(projected)
				_check(
					screen.has_point(projected) and not covered,
					label + ": Material frei %s" % projected
				)
			await _close(game)
	root.size = Vector2i(1080, 2340)
