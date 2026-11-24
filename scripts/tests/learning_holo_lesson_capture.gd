extends SceneTree
## Bildbelege der Holo-Lernräume mit echtem Renderer (xvfb, gl_compatibility).
## Eingaben sind dieselben Kind-Aktionen wie im Regressionstest.
## Argumente: --output=DIR --size=WxH --kind=math|verb|order|noun [--calm] [--perf]
## [--density=2.625] (kleinere Fenster mit gleicher logischer Größe: Dichte mitskalieren)

const FIXTURES = preload("res://scripts/tests/holo_lesson_fixtures.gd")

var output := "res://exports/holo-lesson"
var size_value := Vector2i(1080, 2340)
var kind := "math"
var calm := false
var perf := false
var density := 2.625
var failures := 0
var shots := 0
var frame_times: Array[float] = []


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
		elif argument.begins_with("--size="):
			var parts := argument.trim_prefix("--size=").split("x")
			size_value = Vector2i(int(parts[0]), int(parts[1]))
		elif argument.begins_with("--kind="):
			kind = argument.trim_prefix("--kind=")
		elif argument == "--calm":
			calm = true
		elif argument == "--perf":
			perf = true
		elif argument.begins_with("--density="):
			density = float(argument.trim_prefix("--density="))
	_run.call_deferred()


func _settle(count: int = 10) -> void:
	for frame in range(count):
		await process_frame
	await RenderingServer.frame_post_draw


func _idle(game: Node3D, limit: float = 150.0) -> void:
	var started := Time.get_ticks_msec()
	while game.busy and Time.get_ticks_msec() - started < limit * 1000.0:
		await process_frame


func _shot(_game: Node3D, label: String) -> void:
	await _settle()
	var image := root.get_texture().get_image()
	if image == null or image.get_size() != size_value:
		failures += 1
		push_error("[HoloCapture] raster size %s" % label)
		return
	var name_value := (
		"%s-%s-%dx%d%s.png" % [kind, label, size_value.x, size_value.y, "-ruhig" if calm else ""]
	)
	if image.save_png(output.path_join(name_value)) == OK:
		shots += 1
		print("[HoloCapture] saved ", name_value)


## Jedes Bild zeigt den Schritt, den sein Name nennt: vor dem Bild wird der
## Zustand geprüft (bis 20 s Wartezeit für langsame Renderläufe).
## Zeitlupe für Bilder mitten in einer Bewegung (Bogenflug): Die Abläufe
## laufen über Prozesszeit, Engine.time_scale bremst sie für die Aufnahme.
func _slow_shot(game: Node3D, label: String) -> void:
	Engine.time_scale = 0.02
	await _shot(game, label)
	Engine.time_scale = 1.0


func _expect(game: Node3D, label: String, check: Callable) -> void:
	var started := Time.get_ticks_msec()
	while not check.call() and Time.get_ticks_msec() - started < 90000:
		await process_frame
	await _idle(game)
	if not check.call():
		failures += 1
		push_error("[HoloCapture] state for %s not reached" % label)


## Wie _expect, aber ohne auf das Ende des Ablaufs zu warten.
func _expect_now(game: Node3D, label: String, check: Callable) -> void:
	var started := Time.get_ticks_msec()
	while not check.call() and Time.get_ticks_msec() - started < 120000:
		await process_frame
	if not check.call():
		failures += 1
		push_error("[HoloCapture] state for %s not reached" % label)
	if game.reduced_motion:
		await _idle(game)


func _tap_screen(point: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 3
		event.position = point
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await process_frame


func _drag_screen(from: Vector2, to: Vector2) -> void:
	var down := InputEventScreenTouch.new()
	down.index = 4
	down.position = from
	down.pressed = true
	Input.parse_input_event(down)
	await process_frame
	for step in range(1, 9):
		var move := InputEventScreenDrag.new()
		move.index = 4
		move.position = from.lerp(to, step / 8.0)
		Input.parse_input_event(move)
		await process_frame
	var up := InputEventScreenTouch.new()
	up.index = 4
	up.position = to
	up.pressed = false
	Input.parse_input_event(up)
	await process_frame
	await process_frame


func _press(button: Button, game: Node3D = null) -> void:
	if button == null:
		failures += 1
		push_error("[HoloCapture] missing button")
		return
	var before: int = -1 if game == null else game.events.size()
	await _tap_screen(button.get_global_rect().get_center())
	if game != null and game.events.size() == before:
		print(
			(
				"[HoloCapture] tap had no effect on %s visible=%s disabled=%s rect=%s busy=%s"
				% [
					button.name,
					button.is_visible_in_tree(),
					button.disabled,
					button.get_global_rect(),
					game.busy
				]
			)
		)
		await _settle(6)
		await _tap_screen(button.get_global_rect().get_center())


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("[HoloCapture] real renderer required")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	root.size = size_value
	var bridge = root.get_node("HostBridge")
	bridge._options["displayDensity"] = density
	await _settle(4)
	var started := Time.get_ticks_usec()
	var scene := load("res://scenes/learning/holo_lesson.tscn") as PackedScene
	var game: Node3D = scene.instantiate()
	var fixture: Dictionary = (
		{"math": FIXTURES.math(), "verb": FIXTURES.verb(), "noun": FIXTURES.noun()}
		. get(kind, FIXTURES.order())
	)
	game.capture_options = {"learning": fixture, "reduceAnimations": calm}
	root.add_child(game)
	await RenderingServer.frame_post_draw
	print(
		(
			"[HoloCapture] container_start_to_first_frame_ms=%.1f"
			% ((Time.get_ticks_usec() - started) / 1000.0)
		)
	)
	await _idle(game)
	if kind == "math":
		await _math(game)
	elif kind == "verb":
		await _verb(game)
	elif kind == "noun":
		await _noun(game)
	else:
		await _order(game)
	if perf:
		_report_frames()
	game.queue_free()
	await _settle(4)
	var sound := root.get_node_or_null("GameSoundscape")
	if sound != null and sound.has_method("release_audio"):
		sound.release_audio()
	await create_timer(0.4).timeout
	print("[HoloCapture] shots=%d failures=%d" % [shots, failures])
	quit(0 if failures == 0 else 1)


func _sample_frames(_game: Node3D, seconds: float) -> void:
	var start := Time.get_ticks_msec()
	var last := Time.get_ticks_usec()
	while Time.get_ticks_msec() - start < seconds * 1000.0:
		await process_frame
		var now := Time.get_ticks_usec()
		frame_times.append((now - last) / 1000.0)
		last = now


func _report_frames() -> void:
	if frame_times.is_empty():
		return
	var sorted := frame_times.duplicate()
	sorted.sort()
	var total := 0.0
	for value in sorted:
		total += value
	print(
		(
			"[HoloCapture] container_frame_ms avg=%.2f p50=%.2f p95=%.2f max=%.2f n=%d"
			% [
				total / sorted.size(),
				sorted[sorted.size() / 2],
				sorted[int(sorted.size() * 0.95)],
				sorted[-1],
				sorted.size()
			]
		)
	)


func _math(game: Node3D) -> void:
	await _shot(game, "01-aufgabe")
	# Zählen durch echtes Antippen der Äpfel im Bild.
	for index in [0, 1, 2]:
		var point: Vector2 = game.camera.unproject_position(
			game.math_room.apples[index].global_position + Vector3(0, 0.27, 0)
		)
		await _tap_screen(point)
	var from: Vector2 = game.camera.unproject_position(game.math_room.apples[9].global_position)
	var to: Vector2 = game.camera.unproject_position(game.math_room.slot_position(0))
	await _drag_screen(from, to)
	if perf:
		await _sample_frames(game, 2.0)
	await _shot(game, "02-entdecken")
	await _press(game.find_child("Antwort_12", true, false), game)
	await _expect_now(game, "falsch", func() -> bool: return game.plan.wrong == 1)
	if perf:
		await _sample_frames(game, 3.0)
	# Lumo zeigt gerade auf den Korb (erste Menge leuchtet, Anhänger „Im Korb“).
	await _expect_now(game, "korb", func() -> bool: return game.math_room.badges[0].visible)
	await _shot(game, "03-falsch-hinweis1")
	await _idle(game)
	await _shot(game, "04-hinweis1-mengen")
	await _press(game.find_child("Antwort_14", true, false), game)
	await _expect_now(
		game,
		"hilfe",
		func() -> bool:
			return game.plan.hint_level == 2 and game.math_room.paths.get_child_count() >= 2
	)
	if not game.reduced_motion:
		await _slow_shot(game, "05-hilfe-zehnerbildung")
	await _idle(game)
	await _expect(game, "10plus3", func() -> bool: return game.events.has("ten_complete"))
	if game.reduced_motion:
		await _shot(game, "05-hilfe-zehnerbildung")
	await _shot(game, "06-hilfe-10plus3")
	await _press(game.find_child("Antwort_13", true, false), game)
	await _expect(game, "richtig", func() -> bool: return game.plan.original_correct)
	await _shot(game, "07-richtig")
	await _press(game.twin_button, game)
	await _expect(game, "zwilling", func() -> bool: return game.plan.phase == "twin")
	await _shot(game, "08-aehnliche-aufgabe")
	await _press(game.find_child("Antwort_14", true, false), game)
	await _expect(game, "allein", func() -> bool: return game.plan.phase == "done")
	await _shot(game, "09-allein-geloest")
	game.return_to_lesson()
	print("[HoloCapture] events=", game.events)
	print("[HoloCapture] return=", JSON.stringify(game.last_return))


## Karte antippen, wenn sie still liegt (langsamer Software-Renderer).
func _tap_card(game: Node3D, index: int) -> void:
	await _settle(3)
	await _tap_screen(_card_point(game, index))


func _card_point(game: Node3D, index: int) -> Vector2:
	return game.word_room.card_rect(game.camera, index).get_center()


func _verb(game: Node3D) -> void:
	await _shot(game, "01-aufgabe")
	await _tap_screen(_card_point(game, 2))
	await _expect(game, "gewaehlt", func() -> bool: return game.word_room.selected == 2)
	await _shot(game, "02-karte-gewaehlt")
	await _press(game.confirm_button, game)
	if game.reduced_motion:
		# Ruhige Bewegung: kein Sprung – der Name sagt es.
		await _expect(game, "springt", func() -> bool: return game.events.has("lumo_jump"))
		await _shot(game, "03-falsch-hinweis1-ohne-sprung")
	else:
		# Lumo mitten im Sprung (Füße frei über dem Boden).
		await _expect_now(game, "springt", func() -> bool: return game._fox_ground().y > 0.55)
		await _slow_shot(game, "03-falsch-lumo-springt")
	await _expect(game, "frage", func() -> bool: return game.plan.hint_level == 1 and not game.busy)
	await _shot(game, "04-hinweis1-frage")
	var field: Vector3 = game.word_room.answer_field.global_position
	await _drag_screen(_card_point(game, 1), game.camera.unproject_position(field))
	await _expect(game, "hilfe", func() -> bool: return game.plan.hint_level == 2)
	if not game.reduced_motion:
		await create_timer(1.6).timeout
	await _shot(game, "05-hilfe-lumo-zeigt")
	await _expect(game, "tunwort", func() -> bool: return game.events.has("show_verb:springt"))
	await _shot(game, "06-hilfe-tunwort")
	await _tap_screen(_card_point(game, 3))
	await _press(game.confirm_button, game)
	await _expect(game, "richtig", func() -> bool: return game.plan.original_correct)
	await _shot(game, "07-richtig")
	await _press(game.twin_button, game)
	await _expect(game, "zwilling", func() -> bool: return game.plan.phase == "twin")
	await _shot(game, "08-aehnlicher-satz")
	await _tap_screen(_card_point(game, 2))
	await _press(game.confirm_button, game)
	await _expect(game, "allein", func() -> bool: return game.plan.phase == "done")
	await _shot(game, "09-allein-geloest")
	game.return_to_lesson()
	print("[HoloCapture] events=", game.events)
	print("[HoloCapture] return=", JSON.stringify(game.last_return))


func _noun(game: Node3D) -> void:
	await _shot(game, "01-aufgabe")
	await _tap_screen(_card_point(game, 1))
	await _expect(game, "gewaehlt", func() -> bool: return game.word_room.selected == 1)
	await _shot(game, "02-karte-gewaehlt")
	await _press(game.confirm_button, game)
	await _expect(game, "begleiter", func() -> bool: return game.events.has("article_glow:Der"))
	await _shot(game, "03-falsch-begleiter-leuchtet")
	var field: Vector3 = game.word_room.answer_field.global_position
	await _drag_screen(_card_point(game, 3), game.camera.unproject_position(field))
	await _expect(game, "hilfe", func() -> bool: return game.events.has("show_noun:Fuchs"))
	await _shot(game, "04-hilfe-namenwort")
	await _tap_screen(_card_point(game, 2))
	await _press(game.confirm_button, game)
	await _expect(game, "bild", func() -> bool: return game.events.has("picture:fuchs"))
	await _shot(game, "05-richtig-hologramm")
	await _press(game.twin_button, game)
	await _expect(game, "zwilling", func() -> bool: return game.plan.phase == "twin")
	await _shot(game, "06-aehnlicher-satz")
	await _tap_screen(_card_point(game, 1))
	await _press(game.confirm_button, game)
	await _expect(game, "allein", func() -> bool: return game.events.has("picture:katze"))
	await _shot(game, "07-allein-geloest")
	game.return_to_lesson()
	print("[HoloCapture] events=", game.events)
	print("[HoloCapture] return=", JSON.stringify(game.last_return))


func _order(game: Node3D) -> void:
	await _shot(game, "01-aufgabe")
	for index in [0, 2, 1, 3]:
		await _tap_card(game, index)
	await _expect(game, "gelegt", func() -> bool: return game.plan.placed.size() == 4)
	await _shot(game, "02-gelegt")
	await _press(game.confirm_button, game)
	await _expect(game, "hinweis1", func() -> bool: return game.plan.hint_level == 1)
	await _shot(game, "03-falsch-hinweis1")
	await _idle(game)
	for index in [0, 2, 1, 3]:
		await _tap_card(game, index)
	await _press(game.hint_button, game)
	# Lumo hat den Satz in die Leiste gelegt (vor dem Zurücklegen).
	await _expect_now(game, "hilfe", func() -> bool: return game.events.has("show_sentence"))
	if game.reduced_motion:
		await _shot(game, "04-hilfe-satz")
	else:
		await _slow_shot(game, "04-hilfe-satz")
	await _idle(game)
	# Karten erst ganz zurück aufs Tablett, dann tippen.
	await _settle(8)
	for index in [0, 1, 2, 3]:
		await _tap_card(game, index)
	await _press(game.confirm_button, game)
	await _expect(game, "richtig", func() -> bool: return game.plan.original_correct)
	await _shot(game, "05-richtig")
	await _press(game.twin_button, game)
	await _expect(game, "neu", func() -> bool: return game.plan.phase == "twin")
	await _shot(game, "06-neuer-satz")
	for index in [0, 1, 2, 3]:
		await _tap_card(game, index)
	await _press(game.confirm_button, game)
	await _expect(game, "allein", func() -> bool: return game.plan.phase == "done")
	await _shot(game, "07-allein-geloest")
	game.return_to_lesson()
	print("[HoloCapture] events=", game.events)
	print("[HoloCapture] return=", JSON.stringify(game.last_return))
