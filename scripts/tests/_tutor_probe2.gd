extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.get_node("HostBridge")._options["displayDensity"] = 2.625
	root.size = Vector2i(1080, 2340)
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://scripts/tests/fixtures/tutor_payloads.json"))
	var learning: Dictionary = doc.cases[0].learning.duplicate(true)
	learning.startStufe = "hinweis"
	var scene: PackedScene = load("res://scenes/learning/tutor_world.tscn")
	var game: Node3D = scene.instantiate()
	if game.get_script() == null:
		quit(1)
		return
	game.capture_options = {"learning": learning, "reduceAnimations": true}
	root.add_child(game)
	for f in range(4):
		await process_frame
	print("viewport ", root.get_visible_rect(), " ui.scale ", game.ui.scale)
	for p in [game.header, game.bubble, game.footer]:
		print(p.name, " rect ", p.get_global_rect())
	print("free ", game.free_rect)
	var b: Button = game.weiter_button
	print("weiter vis ", b.is_visible_in_tree(), " rect ", b.get_global_rect())
	var c := b.get_global_rect().get_center()
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.position = c
		e.global_position = c
		e.pressed = pressed
		root.push_input(e)
		await process_frame
	print("schritt after mouse push ", game.tutor.schritt)
	for pressed in [true, false]:
		var t := InputEventScreenTouch.new()
		t.position = c
		t.pressed = pressed
		Input.parse_input_event(t)
		await process_frame
	await process_frame
	print("schritt after Input touch ", game.tutor.schritt)
	var stone: Vector2 = game.camera.unproject_position(game.frame.bead_position(0, 0))
	print("bead00 screen ", stone, " cam ", game.camera.global_position)
	quit(0)
