extends SceneTree
## Sichtkontrolle: Schatzsuche und Rhythmus im echten Renderer, quer und hoch.
## Aufruf mit xvfb-run, gl_compatibility; Argumente: --out=<Ordner> --tag=<Name>
const TREASURE = preload("res://scripts/creative/treasure_state.gd")
var out_dir := "user://real_lumo_capture"
var tag := "shot"
var only := "worlds"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--tag="):
			tag = arg.trim_prefix("--tag=")
		elif arg.begins_with("--set="):
			only = arg.trim_prefix("--set=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	if only == "cover":
		await _treasure_cover()
		quit(0)
		return
	for size in [Vector2i(1600, 720), Vector2i(720, 1600)]:
		var orient := "quer" if size.x > size.y else "hoch"
		DisplayServer.window_set_size(size)
		root.size = size
		if only == "scenes":
			for scene in ["home_3d", "reading_hub", "star_collect", "word_build"]:
				await _plain(scene, orient)
			continue
		await _treasure(orient)
		await _rhythm(orient)
	print("[RealLumoCapture] done")
	quit(0)


## Ladebild der Schatzsuche (assets/creative/covers/treasure.png, 1280x720):
## derselbe Ausschnitt wie die bisherige Erkundungsaufnahme, jetzt mit echtem Lumo.
func _treasure_cover() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	root.size = Vector2i(1280, 720)
	var game = load("res://scenes/creative/treasure_world.tscn").instantiate()
	root.add_child(game)
	await _settle(10)
	game.model = TREASURE.new()
	game.model.result_id = "creative-treasure-cover"
	game.save_path = "user://lumo_treasure_cover.json"
	game.player.position = Vector3(-9, 0.2, -4)
	game.camera.position = game.player.position + game.CAMERA_OFFSET
	game.camera.look_at(game.player.position + game.CAMERA_LOOK_OFFSET, Vector3.UP)
	game._update()
	await _settle(40)
	await _capture("treasure_cover")
	game.queue_free()
	await process_frame


func _treasure(orient: String) -> void:
	var game = load("res://scenes/creative/treasure_world.tscn").instantiate()
	root.add_child(game)
	for _i in range(10):
		await process_frame
	game.model = TREASURE.new()
	game.model.result_id = "real-lumo-capture"
	game.save_path = "user://lumo_treasure_capture.json"
	game.player.position = Vector3(-9, 0.2, -4)
	game.camera.position = game.player.position + game.CAMERA_OFFSET
	game._update()
	await _settle(30)
	await _capture("treasure_steht_" + orient)
	game.joystick.target = Vector2(0.75, -0.66)
	game.joystick.axis = Vector2(0.75, -0.66)
	await _settle(40)
	await _capture("treasure_laeuft_" + orient)
	game.joystick.target = Vector2(-0.35, 0.25)
	game.joystick.axis = Vector2(-0.35, 0.25)
	await _settle(30)
	await _capture("treasure_geht_" + orient)
	game.joystick.target = Vector2.ZERO
	game.joystick.axis = Vector2.ZERO
	game.player.velocity = Vector3.ZERO
	game.player.position = TREASURE.CLUES[0].at
	await _settle(20)
	game._interact()
	game._answer(int(TREASURE.CLUES[0].correct))
	await _settle(45)
	await _capture("treasure_jubel_" + orient)
	game.queue_free()
	await process_frame


func _rhythm(orient: String) -> void:
	var game = load("res://scenes/creative/rhythm_world.tscn").instantiate()
	root.add_child(game)
	await _settle(20)
	await _capture("rhythm_start_" + orient)
	game.start()
	game.model.time = 4.0
	await _settle(4)
	for i in range(game.model.notes.size()):
		var note: Dictionary = game.model.notes[i]
		if float(note.time) > 4.2 and str(note.kind) == "tap":
			game.model.time = float(note.time)
			game._press(int(note.lane))
			break
	await _settle(30)
	await _capture("rhythm_treffer_" + orient)
	game.queue_free()
	await process_frame


## Szenen mit der Szenen-Lumo-Figur (lumo_character.tscn): Start und Geste.
func _plain(scene: String, orient: String) -> void:
	var path := "res://scenes/app/home_3d.tscn" if scene == "home_3d" else "res://scenes/games/%s.tscn" % scene
	var game: Node = load(path).instantiate()
	root.add_child(game)
	await _settle(60)
	await _capture(scene + "_" + orient)
	for node in game.find_children("*", "Node3D", true, false):
		if node.has_method("set_eye_state"):
			node.play_behavior("celebrate")
			break
	await _settle(40)
	await _capture(scene + "_jubel_" + orient)
	game.queue_free()
	await _settle(2)


func _settle(frames: int) -> void:
	for _i in range(frames):
		await process_frame


func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var frame: Image = root.get_texture().get_image()
	var path := out_dir.path_join(tag + "_" + name + ".png")
	frame.save_png(path)
	print("[RealLumoCapture] ", path, " ", frame.get_size())
