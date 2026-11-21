extends SceneTree
## Bildbelege der 3D-Nachhilfe mit echtem Renderer (xvfb, gl_compatibility).
## Daten: die App-Fixtures (8 + 5, 6 + 7, 3 + 9). Eingaben sind die echten
## Handgriffe der Szene (Ziehen, Tippen) wie im Regressionstest.
## Argumente: --output=DIR --size=WxH [--density=2.625] [--weg=all|<weg>]
## [--state=all|zeigt|kind]

const FIXTURE := "res://scripts/tests/fixtures/tutor_payloads.json"
const SCENE := "res://scenes/learning/tutor_world.tscn"
const FALL_FUER_WEG := {
	"rechenrahmen": "acht_plus_fuenf",
	"zahlenstrahl": "acht_plus_fuenf",
	"zerlegen": "acht_plus_fuenf",
	"verdoppeln": "sechs_plus_sieben",
	"tauschen": "drei_plus_neun",
}

var output := "res://exports/tutor"
var size_value := Vector2i(1080, 2340)
var density := 2.625
var only_weg := "all"
var only_state := "all"
var failures := 0
var shots := 0


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
		elif argument.begins_with("--size="):
			var parts := argument.trim_prefix("--size=").split("x")
			size_value = Vector2i(int(parts[0]), int(parts[1]))
		elif argument.begins_with("--density="):
			density = float(argument.trim_prefix("--density="))
		elif argument.begins_with("--weg="):
			only_weg = argument.trim_prefix("--weg=")
		elif argument.begins_with("--state="):
			only_state = argument.trim_prefix("--state=")
	_run.call_deferred()


func _settle(count: int = 8) -> void:
	for frame in range(count):
		await process_frame
	await RenderingServer.frame_post_draw


func _wait_settled(game: Node3D, limit: float = 40.0) -> void:
	var started := Time.get_ticks_msec()
	while not game.is_settled() and Time.get_ticks_msec() - started < limit * 1000.0:
		await process_frame
	await _settle(12)


func _shot(label: String) -> void:
	await _settle()
	var image := root.get_texture().get_image()
	if image == null or image.get_size() != size_value:
		failures += 1
		push_error("[TutorCapture] raster size %s" % label)
		return
	var name_value := "tutor-%s-%dx%d.jpg" % [label, size_value.x, size_value.y]
	if image.save_jpg(output.path_join(name_value), 0.88) == OK:
		shots += 1
		print("[TutorCapture] saved ", name_value)
	else:
		failures += 1


func _tap(point: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 2
		event.position = point
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await process_frame


func _drag(from: Vector2, to: Vector2) -> void:
	var down := InputEventScreenTouch.new()
	down.index = 3
	down.position = from
	down.pressed = true
	Input.parse_input_event(down)
	await process_frame
	for step in range(1, 9):
		var move := InputEventScreenDrag.new()
		move.index = 3
		move.position = from.lerp(to, step / 8.0)
		Input.parse_input_event(move)
		await process_frame
	var up := InputEventScreenTouch.new()
	up.index = 3
	up.position = to
	up.pressed = false
	Input.parse_input_event(up)
	await _settle(3)


## Echter Handgriff: Reihe [row] bis zur Anzahl [count] ziehen.
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


func _press(button: Button) -> void:
	if button == null or not button.is_visible_in_tree():
		failures += 1
		push_error("[TutorCapture] button missing")
		return
	await _tap(button.get_global_rect().get_center())


func _choice(game: Node3D, name_value: String) -> Button:
	return game.choice_bar.get_node_or_null(name_value) as Button


func _open(weg: String, stufe: String) -> Node3D:
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var learning: Dictionary = {}
	for entry: Dictionary in doc.cases:
		if entry.name == FALL_FUER_WEG[weg]:
			learning = entry.learning.duplicate(true)
	learning.startWeg = weg
	learning.startStufe = stufe
	var game: Node3D = (load(SCENE) as PackedScene).instantiate()
	game.capture_options = {"learning": learning, "reduceAnimations": false}
	root.add_child(game)
	await _settle(4)
	await _wait_settled(game)
	return game


## Lumo zeigt: Stufe „Lumo zeigt“, zweiter Schritt (Lumo steht am Material).
func _lumo_zeigt(weg: String) -> void:
	var game := await _open(weg, "vorzeigen")
	await _press(game.weiter_button)
	await _wait_settled(game)
	await _shot("%s-lumo-zeigt" % weg)
	game.queue_free()
	await _settle(4)


## Kind ist dran: Stufe „Selbst üben“ mit echten Handgriffen, dann ein
## Fehlgriff (konkrete Hilfe) oder die Ergebniswahl.
func _kind(weg: String) -> void:
	var game := await _open(weg, "ueben")
	var step: Dictionary = game.tutor.current()
	match weg:
		"rechenrahmen", "verdoppeln", "zerlegen":
			await _drag_beads(game, 1, int(step.aktion.reihe1))
			if weg == "verdoppeln":
				await _drag_beads(game, 2, int(step.aktion.reihe2))
		"zahlenstrahl", "tauschen":
			await _tap_stone(game, int(step.aktion.nach))
	await _wait_settled(game)
	step = game.tutor.current()
	match str(step.aktion.art):
		"perlen":
			await _drag_beads(game, 1, 10)
			if game.tutor.schritt < 2:
				await _drag_beads(game, 2, 3)
		"huepfen":
			var wrong: int = mini(20, int(step.aktion.nach) + 2)
			await _tap_stone(game, wrong)
		"zerlegen":
			var pairs: Array = step.aktion.zerlegungen
			for pair: Array in pairs:
				if int(pair[0]) != int(step.aktion.teil1):
					await _press(_choice(game, "Zerlegung_%d_%d" % [pair[0], pair[1]]))
					break
		"ergebnis":
			pass
	await _wait_settled(game)
	await _shot("%s-kind" % weg)
	game.queue_free()
	await _settle(4)


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("[TutorCapture] real renderer required")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	root.size = size_value
	var bridge = root.get_node("HostBridge")
	bridge._options["displayDensity"] = density
	await _settle(4)
	for weg: String in ["rechenrahmen", "zahlenstrahl", "zerlegen", "verdoppeln", "tauschen"]:
		if only_weg != "all" and only_weg != weg:
			continue
		if only_state in ["all", "zeigt"]:
			await _lumo_zeigt(weg)
		if only_state in ["all", "kind"]:
			await _kind(weg)
	var sound := root.get_node_or_null("GameSoundscape")
	if sound != null and sound.has_method("release_audio"):
		sound.release_audio()
	await create_timer(0.4).timeout
	print("[TutorCapture] shots=%d failures=%d" % [shots, failures])
	quit(0 if failures == 0 else 1)
