extends SceneTree
## Szenentest Lumo Schach (kopflos, Fold offen 1812×2176, Dichte 2,625):
## Start über app_boot mit --scene=chess, drei Wege, vier Stufen, der ganze
## Lernweg wird über echte Antipp-Ereignisse gelöst (jede Lektion, jedes
## Probespiel), Fortschritt gespeichert und fortgesetzt, eine ganze Partie
## Anfänger gegen Zufall bis zum Ende, Zurücknehmen, Umwandlung, Belohnung genau
## einmal, „Für Große“ ohne Hilfen, Touch-Ziele ≥ 126 px.
## Aufruf: godot --headless --path . --script res://scripts/tests/chess_table_regression.gd -- --scene=chess

const TABLE := "res://scenes/games/chess_table.tscn"
const BOOT := "res://scenes/app/boot.tscn"
const RULES = preload("res://scripts/games/chess/chess_rules.gd")
const SCHOOL = preload("res://scripts/games/chess/chess_school.gd")
const SESSION = preload("res://scripts/games/chess/chess_session.gd")
const CHILD := "chess-table-regression"
const FOLD := Vector2i(1812, 2176)
const MIN_TOUCH := 126.0

var checks := 0
var failures: Array[String] = []
var table: Node
var bridge: Node
var rewards: Array[Dictionary] = []
var min_touch := 100000.0
var min_touch_name := ""
var square_sizes: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("[ChessTable] " + label)


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _new_table() -> void:
	if table != null:
		table.queue_free()
		await _frames(2)
	table = load(TABLE).instantiate()
	_check(table.has_method("start_match"), "Tischskript geladen")
	if not table.has_method("start_match"):
		print("CHESS_TABLE_FAIL Tischskript lässt sich nicht laden")
		quit(1)
		return
	table.time_scale = 40.0
	root.add_child(table)
	await _frames(4)
	table.reduced_motion = true
	table.chess.reduced_motion = true
	table.ai.rng.seed = 77


func _wait_idle(limit: int = 4000) -> bool:
	for i in limit:
		if table.is_idle() and table.overlay_kind != "warn":
			return true
		await process_frame
	return false


## Physische Größe eines Knopfs (px) und Prüfung ≥ 126 px.
func _touch_ok(button: Button, label: String) -> void:
	var rect := button.get_global_rect()
	var side := minf(rect.size.x, rect.size.y)
	if side < min_touch:
		min_touch = side
		min_touch_name = label
	_check(side >= MIN_TOUCH, "Touch-Ziel %s ≥ %d px (%.0f)" % [label, MIN_TOUCH, side])


func _press(id: String) -> void:
	var button: Button = table.find_button(id)
	_check(button != null and button.is_visible_in_tree() and not button.disabled, "Knopf %s bedienbar" % id)
	if button == null:
		return
	_touch_ok(button, id)
	button.pressed.emit()
	await _frames(2)


func _visible_buttons_ok(label: String) -> void:
	await _frames(2)
	for id: String in table.buttons:
		var b: Button = table.buttons[id]
		if is_instance_valid(b) and b.is_visible_in_tree():
			_touch_ok(b, "%s/%s" % [label, id])


## Ein Antippen auf ein Feld (Maus-Ereignis wie am Gerät, Drücken + Loslassen).
func _tap_square(sq: int) -> void:
	var point: Vector2 = table.square_point(sq)
	for pressed: bool in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = point
		table._unhandled_input(ev)
	await _frames(1)


func _tap_move(from: int, to: int) -> void:
	await _tap_square(from)
	await _tap_square(to)


func _run() -> void:
	var started := Time.get_ticks_msec()
	bridge = root.get_node("HostBridge")
	bridge._options = {"displayDensity": 2.625, "childKey": CHILD, "soundEnabled": false}
	bridge.reward_reported.connect(func(p: Dictionary) -> void: rewards.append(p))
	DirAccess.remove_absolute(SESSION.path_for(CHILD))
	root.size = FOLD
	await _frames(3)
	await _boot_route()
	await _new_table()
	await _home_and_levels()
	await _learning_path()
	await _resume()
	await _match_vs_random()
	await _undo_and_promotion()
	await _reward_once()
	await _pro_mode()
	await _views_and_squares()
	print("[ChessTable] kleinstes Touch-Ziel: %.0f px (%s)" % [min_touch, min_touch_name])
	for key: String in square_sizes:
		print("[ChessTable] Feldgröße %s: %s" % [key, square_sizes[key]])
	DirAccess.remove_absolute(SESSION.path_for(CHILD))
	table.queue_free()
	await _frames(3)
	root.get_node("GameSoundscape").release_audio()
	await create_timer(0.4).timeout
	print("CHESS_TABLE_%s checks=%d failures=%d time=%.1fs" % [
		"PASS" if failures.is_empty() else "FAIL", checks, failures.size(),
		(Time.get_ticks_msec() - started) / 1000.0])
	for f: String in failures:
		print("  FEHLER: ", f)
	quit(0 if failures.is_empty() else 1)


# --- Start über die App-Route --------------------------------------------------


func _boot_route() -> void:
	var router: Node = root.get_node("SceneRouter")
	_check(router.SCENES.get("chess", "") == TABLE, "SceneRouter kennt chess")
	var options: Dictionary = bridge.validated_options({"game": "chess"})
	_check(options.scene == "chess", "HostBridge lässt chess durch")
	_check(bridge.validated_options({"game": "chess_x"}).scene != "chess_x", "unbekannte Szene abgelehnt")
	var boot_src := FileAccess.get_file_as_string("res://scripts/app/app_boot.gd")
	_check(boot_src.contains("\"chess\""), "app_boot nimmt chess an")
	# Echter Start wie in der App: Der Test läuft mit `-- --scene=chess`, app_boot
	# liest das selbst aus den Startargumenten.
	var via_args := "--scene=chess" in OS.get_cmdline_user_args()
	_check(via_args, "Test mit -- --scene=chess gestartet")
	var boot: Node = load(BOOT).instantiate()
	if not via_args:
		boot.auto_begin = false
	root.add_child(boot)
	current_scene = boot
	await _frames(2)
	if not via_args:
		boot._begin_loading("chess")
	var found := false
	for i in 900:
		await process_frame
		if current_scene != null and current_scene.name == "ChessTable":
			found = true
			break
	_check(found, "--scene=chess lädt den Schachtisch")
	if current_scene != null and current_scene.name == "ChessTable":
		_check(current_scene.screen == "home", "Start zeigt die Auswahl")
		current_scene.queue_free()
		current_scene = null
	elif is_instance_valid(boot):
		boot.queue_free()
	await _frames(4)


# --- Startauswahl und Stufen ---------------------------------------------------


func _home_and_levels() -> void:
	_check(table.screen == "home", "Startbildschirm")
	for id: String in ["o_Kids", "o_Play", "o_Pro"]:
		_check(table.find_button(id) != null, "Weg %s vorhanden" % id)
	_check(table.find_button("o_Kids").text.begins_with("Schach lernen"), "Kinderweg heißt Schach lernen")
	_check(table.overlay_box.get_child(1) == table.find_button("o_Kids"), "Kinderweg steht oben")
	await _visible_buttons_ok("Start")
	for which: String in ["Play", "Pro"]:
		await _press("o_" + which)
		var names: Array[String] = []
		for i in 4:
			var b: Button = table.find_button("o_Level%d" % i)
			_check(b != null and b.is_visible_in_tree(), "Stufe %d sichtbar (%s)" % [i, which])
			if b != null:
				names.append(b.text.get_slice("\n", 0))
		_check(names == ["Anfänger", "Fortgeschritten", "Meister", "Militärschachspieler"],
			"genau die vier Stufen (%s): %s" % [which, names])
		await _visible_buttons_ok("Stufen-" + which)
		await _press("o_Back")


# --- Lernweg ---------------------------------------------------------------------


func _solve_lesson(id: String) -> void:
	table.start_lesson(id)
	await _frames(2)
	var info: Dictionary = SCHOOL.lesson(id)
	var steps: Array = info.steps
	var guard := 0
	while table.screen == "lesson" and not table.finished and guard < 60:
		guard += 1
		await _wait_idle()
		if table.finished or table.screen != "lesson":
			break
		var step: Dictionary = table._step()
		var index: int = table.step_index
		match str(step.get("type", "")):
			"show":
				await _press("Next")
			"tap":
				var sol: Array = SCHOOL.solution(step)
				await _tap_square(int(sol[0]))
			"move":
				var sol: Array = SCHOOL.solution(step)
				_check(not sol.is_empty(), "Lösung vorhanden: %s Schritt %d" % [id, index + 1])
				if sol.is_empty():
					return
				var m := int(sol[0])
				await _tap_move(RULES.move_from(m), RULES.move_to(m))
			"collect":
				var route: Array = SCHOOL.collect_route(step)
				_check(not route.is_empty(), "Sternenweg vorhanden: " + id)
				for hop: Array in route:
					await _wait_idle()
					await _tap_move(int(hop[0]), int(hop[1]))
		await _wait_idle()
		for i in 200:
			if table.finished or table.step_index != index:
				break
			await process_frame
		_check(table.finished or table.step_index != index, "%s Schritt %d gelöst" % [id, index + 1])
		if not table.finished and table.step_index == index:
			return
	_check(table.finished and table.overlay_kind == "end", "Lektion %s beendet" % id)
	_check(table.session.lesson_stars(id) == 3, "Lektion %s mit 3 Sternen (%d)" % [id, table.session.lesson_stars(id)])
	_check(steps.size() > 0, "Lektion %s hat Schritte" % id)


## Spielt ein Probespiel für das Kind mit einer kurzen Suche (zieht über Antippen).
func _solve_trial(id: String) -> bool:
	table.hints = false
	table.start_trial(id)
	var helper: RefCounted = load("res://scripts/games/chess/chess_ai.gd").new(5)
	for ply in 400:
		await _wait_idle()
		if table.finished:
			break
		if table.rules.side != 0:
			continue
		var race: bool = SCHOOL.trial(id).get("goal", "") == "race"
		var r: Dictionary = await helper.think(table.rules, 2, {"budget_ms": 150, "slice_ms": 0, "race": race})
		var m: int = int(r.move)
		if m < 0:
			break
		await _tap_move(RULES.move_from(m), RULES.move_to(m))
		if table.overlay_kind == "promo":
			await _press("o_Promo5")
	await _wait_idle()
	table.hints = true
	return table.finished and table.session.trial_done(id)


func _learning_path() -> void:
	var t0 := Time.get_ticks_msec()
	_check(str(SCHOOL.PATH[1][1]) == "bauer" and str(SCHOOL.PATH[2][1]) == "t1",
		"Lernweg beginnt mit Bauern und Bauernrennen")
	var order: Array[String] = []
	for entry: Array in SCHOOL.PATH:
		if entry[0] == "lesson" and entry[1] in ["bauer", "turm", "laeufer", "dame", "springer", "koenig", "schach", "matt"]:
			order.append(entry[1])
	_check(order == ["bauer", "turm", "laeufer", "dame", "springer", "koenig", "schach", "matt"],
		"Figuren in der Reihenfolge Bauer, Turm, Läufer, Dame, Springer, König, Schach, Matt")
	var t5 := SCHOOL.PATH.find(["trial", "t5"])
	_check(t5 > SCHOOL.PATH.find(["lesson", "matt"]), "begleitetes Probespiel nach Schach und Matt")
	await _press("o_Kids")
	await _visible_buttons_ok("Lernweg")
	for i in SCHOOL.PATH.size():
		var kind := str(SCHOOL.PATH[i][0])
		var id := str(SCHOOL.PATH[i][1])
		table.open_path()
		await _frames(2)
		var b: Button = table.find_button("o_Path_" + id)
		_check(b != null and not b.disabled, "Lernweg-Eintrag %s offen" % id)
		if i + 1 < SCHOOL.PATH.size():
			var next: Button = table.find_button("o_Path_" + str(SCHOOL.PATH[i + 1][1]))
			_check(next != null and next.disabled, "nächster Eintrag nach %s noch zu" % id)
		await _press("o_Path_" + id)
		if kind == "lesson":
			await _solve_lesson(id)
		else:
			var ok := await _solve_trial(id)
			_check(ok, "Probespiel %s gewonnen" % id)
		if failures.size() > 12:
			return
	print("[ChessTable] Lernweg komplett gelöst: %d Einträge, %.1f s" % [SCHOOL.PATH.size(), (Time.get_ticks_msec() - t0) / 1000.0])
	var lesson_rewards := 0
	for p: Dictionary in rewards:
		if str(p.get("variant", "")).begins_with("lesson:") or str(p.get("variant", "")).begins_with("trial:"):
			lesson_rewards += 1
	_check(lesson_rewards == SCHOOL.PATH.size(), "je Lernschritt genau eine Belohnung (%d)" % lesson_rewards)


# --- Fortsetzen -------------------------------------------------------------------


func _resume() -> void:
	# Fortschritt bleibt nach Neustart erhalten.
	await _new_table()
	table.open_path()
	await _frames(2)
	for entry: Array in SCHOOL.PATH:
		var b: Button = table.find_button("o_Path_" + str(entry[1]))
		_check(b != null and not b.disabled and b.text.contains("★"), "nach Neustart geschafft: %s" % entry[1])
	# Teilweise gespielte Probepartie wird an derselben Stelle fortgesetzt.
	table.hints = false
	table.start_trial("t5")
	await _wait_idle()
	await _tap_move(RULES.square_from_name("e2"), RULES.square_from_name("e4"))
	await _wait_idle()
	var played: int = table.rules.played.size()
	_check(played == 2, "Probespiel: Kind und Lumo haben gezogen (%d)" % played)
	var fen: String = table.rules.get_fen()
	await _new_table()
	table.start_trial("t5")
	await _wait_idle()
	_check(table.rules.get_fen() == fen, "Probespiel nach Neustart an derselben Stelle")
	table.open_home()


# --- Ganze Partie Anfänger gegen Zufall --------------------------------------------


func _match_vs_random() -> void:
	var t0 := Time.get_ticks_msec()
	await _new_table()
	table.hints = false
	table.mode = "play"
	table.start_match(0, false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var child_moves := 0
	for i in 2000:
		await _wait_idle()
		if table.finished:
			break
		if table.rules.side != 0:
			continue
		var moves: PackedInt32Array = table.rules.legal_moves()
		var m: int = moves[rng.randi_range(0, moves.size() - 1)]
		await _tap_move(RULES.move_from(m), RULES.move_to(m))
		if table.overlay_kind == "promo":
			await _press("o_Promo5")
		child_moves += 1
	await _wait_idle()
	var status: String = table.rules.status()
	print("[ChessTable] Partie Anfänger gegen Zufall: %s nach %d Halbzügen (%d Kinderzüge), %.1f s" % [
		status, table.rules.played.size(), child_moves, (Time.get_ticks_msec() - t0) / 1000.0])
	_check(table.finished and status != "playing", "Partie läuft bis zum Ende (%s)" % status)
	_check(table.overlay_kind == "end", "Endbildschirm erscheint")
	_check(not table.session.has_game("play"), "beendete Partie nicht mehr gespeichert")


# --- Zurücknehmen und Umwandlung ------------------------------------------------------


func _undo_and_promotion() -> void:
	await _new_table()
	table.hints = false
	table.mode = "play"
	table.start_match(1, false)
	await _wait_idle()
	await _tap_move(RULES.square_from_name("d2"), RULES.square_from_name("d4"))
	await _wait_idle()
	_check(table.rules.played.size() == 2, "Lumo hat geantwortet")
	await _press("Undo")
	_check(table.rules.played.size() == 0 and table.rules.side == 0, "Zurück nimmt beide Züge zurück")
	_check(table.rules.get_fen() == RULES.START_FEN, "Grundstellung wieder da")
	# Umwandlung: Das Kind wählt die Figur (hier Springer mit Schach).
	table.rules = RULES.new("4k3/2P5/8/8/8/8/8/4K3 w - - 0 1")
	table._show_position()
	await _tap_move(RULES.square_from_name("c7"), RULES.square_from_name("c8"))
	_check(table.overlay_kind == "promo", "Umwandlung fragt nach der Figur")
	for t in [5, 4, 3, 2]:
		_check(table.find_button("o_Promo%d" % t) != null, "Umwandlung in Figur %d wählbar" % t)
	await _visible_buttons_ok("Umwandlung")
	await _press("o_Promo2")
	await _wait_idle()
	_check(table.rules.played.size() >= 1 and table.rules.played[0] == "c7c8n", "Springer gewählt: " + str(table.rules.played))


# --- Belohnung genau einmal -----------------------------------------------------------


func _reward_once() -> void:
	await _new_table()
	table.hints = false
	table.mode = "play"
	table.start_match(0, false)
	table.rules = RULES.new("6k1/5ppp/8/8/8/8/8/R5K1 w - - 0 1")
	table._show_position()
	var before := rewards.size()
	await _tap_move(RULES.square_from_name("a1"), RULES.square_from_name("a8"))
	await _wait_idle()
	_check(table.finished and table.rules.status() == "checkmate", "Matt beendet die Partie")
	_check(rewards.size() == before + 1, "genau eine Belohnung gemeldet")
	if rewards.size() > before:
		var p: Dictionary = rewards[-1]
		_check(p.game == "chess" and p.variant == "play:anfaenger" and int(p.stars) == 1 and p.outcome == "win",
			"Belohnung: %s" % p)
		_check(str(p.resultId).begins_with("chess-play-0-"), "resultId eindeutig: " + str(p.resultId))
		var again: Dictionary = table._settle(str(p.variant), 1, "win", str(p.resultId))
		_check(again.is_empty() and rewards.size() == before + 1, "dieselbe resultId wird nicht doppelt gebucht")


# --- Für Große ------------------------------------------------------------------------


func _pro_mode() -> void:
	await _new_table()
	await _press("o_Pro")
	await _press("o_Level3")
	_check(table.screen == "match" and table.mode == "pro" and table.level == 3, "Militärschachspieler gestartet")
	for id: String in ["Hint", "Why", "Undo"]:
		_check(not (table.buttons[id] as Button).visible, "Für Große ohne %s" % id)
	await _visible_buttons_ok("Partie-Pro")
	# Ein Fehlerzug wird ohne Warnung ausgeführt; Lumo antwortet in Schachschrift.
	await _tap_move(RULES.square_from_name("f2"), RULES.square_from_name("f3"))
	_check(table.overlay_kind != "warn", "keine Warnung für Große")
	var t0 := Time.get_ticks_msec()
	var frames_during := 0
	while not table.is_idle() and frames_during < 3000:
		await process_frame
		frames_during += 1
	print("[ChessTable] Militärschachspieler-Antwort: %.1f s, %d Bilder während des Rechnens" % [
		(Time.get_ticks_msec() - t0) / 1000.0, frames_during])
	_check(table.rules.played.size() == 2, "Lumo hat geantwortet")
	_check(table.bubble_text.text.begins_with("Ich ziehe "), "Antwort in Schachschrift: " + table.bubble_text.text)
	_check(frames_during >= 5, "Bilder laufen während Lumo rechnet weiter")
	var before := rewards.size()
	await _press("Pause")
	await _visible_buttons_ok("Pause")
	await _press("o_Resign")
	_check(table.finished and table.overlay_kind == "end", "Aufgeben beendet die Partie")
	_check(rewards.size() == before, "Aufgeben bringt keine Sterne")
	_check(not table.session.has_game("pro"), "aufgegebene Partie nicht mehr gespeichert")


# --- Ansichten und Feldgrößen ----------------------------------------------------------


func _measure_squares(label: String) -> void:
	# Ohne Fangradius messen (busy = keine Kinderzüge): jedes Feld genau treffen.
	table.busy = true
	var smallest := 100000.0
	var largest := 0.0
	for sq in 64:
		var c: Vector2 = table.square_point(sq)
		var right: Vector2 = table.square_point(sq + 1) if (sq & 7) < 7 else table.square_point(sq - 1)
		var up: Vector2 = table.square_point(sq + 8) if sq < 56 else table.square_point(sq - 8)
		var w := minf(c.distance_to(right), c.distance_to(up))
		smallest = minf(smallest, w)
		largest = maxf(largest, w)
		_check(table.square_at_point(c) == sq, "%s: Antippen trifft Feld %d" % [label, sq])
	table.busy = false
	square_sizes[label] = "kleinstes %.0f px, größtes %.0f px" % [smallest, largest]
	if label.begins_with("Draufsicht") and not label.ends_with("1080x2340"):
		_check(smallest >= MIN_TOUCH, "%s: Felder ≥ %d px (%.0f)" % [label, MIN_TOUCH, smallest])


func _views_and_squares() -> void:
	await _new_table()
	table.mode = "play"
	table.start_match(1, false)
	await _wait_idle()
	for size: Vector2i in [FOLD, Vector2i(2176, 1812), Vector2i(1080, 2340)]:
		root.size = size
		await _frames(3)
		table._layout()
		await _frames(2)
		for view: String in ["3d", "top"]:
			table.view = view
			table._update_view()
			await _frames(2)
			var label := "%s %dx%d" % ["Draufsicht" if view == "top" else "3D", size.x, size.y]
			await _measure_squares(label)
			await _visible_buttons_ok(label)
			# Die Knöpfe liegen innerhalb des Bildschirms.
			for id: String in ["View", "Pause", "Hint"]:
				var b: Button = table.buttons[id]
				var rect := b.get_global_rect()
				_check(Rect2(Vector2.ZERO, Vector2(size)).encloses(rect), "%s: Knopf %s im Bild" % [label, id])
	root.size = FOLD
	await _frames(3)
	table._layout()
	table.view = "3d"
	table._update_view()
	await _frames(2)
	# Fangradius in 3D: Tipp 20 dp über dem Bauern e2 (Richtung e3) wählt ihn trotzdem.
	if table.rules.side == 0 and table.rules.played.is_empty():
		var e2 := RULES.square_from_name("e2")
		var p: Vector2 = table.square_point(e2) + Vector2(0, -20.0 * table._density)
		_check(table.chess.pick(table.camera, p) != e2, "Prüfpunkt liegt außerhalb von e2")
		_check(table.square_at_point(p) == e2, "3D: knapp daneben getippt trifft die eigene Figur")
