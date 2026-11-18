extends SceneTree
## Sichtkontrolle und Messung der Abenteuerwelten im echten Renderer.
## xvfb-run … --rendering-method gl_compatibility --script res://scripts/tests/adventure_worlds_capture.gd
##   -- --out=<Ordner> --tag=<Name> [--set=treasure,rhythm,puzzle,hub] [--profiles=low,medium,high]
## Schreibt JPGs (quer 1600x720, hoch 720x1600) und eine JSON-Datei mit Draw-Calls und
## Dreiecken je Szene und Profil. Spielregeln/Speicherstände werden nicht verändert
## (eigene childKeys, Speicherpfade im user://-Testordner).
const TREASURE = preload("res://scripts/creative/treasure_state.gd")
var out_dir := "user://adventure_capture"
var tag := "shot"
var sets: Array = ["treasure", "rhythm", "puzzle", "hub"]
var profiles: Array = []
var shots: Array = []
var orient_filter := ""
var metrics: Array[Dictionary] = []
var profile_name := "medium"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--tag="):
			tag = arg.trim_prefix("--tag=")
		elif arg.begins_with("--set="):
			sets = arg.trim_prefix("--set=").split(",")
		elif arg.begins_with("--profiles="):
			profiles = arg.trim_prefix("--profiles=").split(",")
		elif arg.begins_with("--shots="):
			shots = arg.trim_prefix("--shots=").split(",")
		elif arg.begins_with("--orient="):
			orient_filter = arg.trim_prefix("--orient=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var perf: Node = root.get_node_or_null("PerformanceManager")
	if profiles.is_empty():
		profiles = ["medium"]
	for profile in profiles:
		profile_name = str(profile)
		if perf != null:
			perf.call("set_profile", ["low", "medium", "high"].find(profile_name), false)
		for size in [Vector2i(1600, 720), Vector2i(720, 1600)]:
			var orient := "quer" if size.x > size.y else "hoch"
			if not orient_filter.is_empty() and orient != orient_filter:
				continue
			DisplayServer.window_set_size(size)
			root.size = size
			for set_name in sets:
				match str(set_name):
					"treasure":
						await _treasure(orient)
					"rhythm":
						await _rhythm(orient)
					"puzzle":
						await _puzzle(orient)
					"hub":
						await _hub(orient)
	var file := FileAccess.open(out_dir.path_join(tag + "_metrics.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(metrics, "  "))
		file.close()
	print("[AdventureCapture] done ", metrics.size(), " measurements")
	quit(0)


func _want(name: String) -> bool:
	return shots.is_empty() or name in shots


func _measure(scene: String, orient: String) -> void:
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	var vp := root.get_viewport_rid()
	var calls := RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
	var prims := RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
	var shadow_calls := RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
	var shadow_prims := RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
	var entry := {"scene": scene, "orient": orient, "profile": profile_name, "draw_calls": calls,
		"triangles": prims, "shadow_draw_calls": shadow_calls, "shadow_triangles": shadow_prims,
		"total_draw_calls": calls + shadow_calls, "total_triangles": prims + shadow_prims}
	metrics.append(entry)
	print("[AdventureCapture] metric ", JSON.stringify(entry))


func _treasure(orient: String) -> void:
	var options := {"childKey": "adventure-capture", "reduceAnimations": false}
	root.get_node("SceneRouter").launch_options = options
	DirAccess.remove_absolute("user://lumo_treasure_adventure-capture.json")
	var game = load("res://scenes/creative/treasure_world.tscn").instantiate()
	root.add_child(game)
	await _settle(10)
	game.model = TREASURE.new()
	game.model.result_id = "adventure-capture"
	game.save_path = "user://lumo_treasure_adventure_capture.json"
	game._update()
	var views := [
		["start", Vector3(0, 0.2, 6.5)],
		["wald", Vector3(-9, 0.2, -4)],
		["wasserfall", Vector3(10.5, 0.2, -16.0)],
		["ruinen", Vector3(-3.5, 0.2, -44.0)],
		["schloss", Vector3(0, 0.2, -52.0)],
		["strand", Vector3(24.0, 0.2, -2.0)],
	]
	for view in views:
		if not _want("treasure_" + view[0]):
			continue
		if view[0] in ["ruinen", "schloss"]:
			for clue in TREASURE.CLUES.slice(0, 6):
				game.model.answer(int(clue.correct), clue.at)
			game._update()
		game.player.position = view[1]
		game.player.velocity = Vector3.ZERO
		game.camera.position = game.player.position + game.CAMERA_OFFSET
		await _settle(30)
		if view[0] == "start":
			await _measure("treasure", orient)
		await _capture("treasure_%s_%s" % [view[0], orient])
	if _want("treasure_laeuft"):
		game.player.position = Vector3(-6, 0.2, -2)
		game.camera.position = game.player.position + game.CAMERA_OFFSET
		game.joystick.target = Vector2(0.75, -0.66)
		game.joystick.axis = Vector2(0.75, -0.66)
		await _settle(40)
		await _capture("treasure_laeuft_" + orient)
		game.joystick.target = Vector2.ZERO
		game.joystick.axis = Vector2.ZERO
	if _want("treasure_fund"):
		game.model = TREASURE.new()
		game.model.result_id = "adventure-capture"
		game._update()
		game.player.velocity = Vector3.ZERO
		game.player.position = TREASURE.CLUES[0].at
		game.camera.position = game.player.position + game.CAMERA_OFFSET
		await _settle(20)
		game._interact()
		game._answer(int(TREASURE.CLUES[0].correct))
		await _settle(36)
		await _capture("treasure_fund_" + orient)
	game.queue_free()
	await _settle(3)
	DirAccess.remove_absolute("user://lumo_treasure_adventure_capture.json")


func _rhythm(orient: String) -> void:
	root.get_node("SceneRouter").launch_options = {"childKey": "adventure-capture"}
	var game = load("res://scenes/creative/rhythm_world.tscn").instantiate()
	root.add_child(game)
	await _settle(20)
	if _want("rhythm_start"):
		await _capture("rhythm_start_" + orient)
	game.start()
	game.model.time = 4.0
	await _settle(4)
	var pressed := 0
	for i in range(game.model.notes.size()):
		var note: Dictionary = game.model.notes[i]
		if float(note.time) > 4.2 and str(note.kind) == "tap":
			game.model.time = float(note.time)
			game._press(int(note.lane))
			pressed += 1
			if pressed >= 6:
				break
	await _settle(12)
	await _measure("rhythm", orient)
	if _want("rhythm_spiel"):
		await _capture("rhythm_spiel_" + orient)
	game.queue_free()
	await _settle(3)


func _puzzle(orient: String) -> void:
	root.get_node("SceneRouter").launch_options = {"childKey": "adventure-capture"}
	var game = load("res://scenes/creative/puzzle_world.tscn").instantiate()
	root.add_child(game)
	await _settle(4)
	game.save_path = "user://lumo_puzzle_adventure_capture.json"
	game.selected_count = 24
	game.start()
	for id in range(14):
		game.model.try_snap(id, game.model.target(id))
	game._tray()
	game._labels()
	await _settle(20)
	await _measure("puzzle", orient)
	if _want("puzzle_spiel"):
		await _capture("puzzle_spiel_" + orient)
	game.queue_free()
	await _settle(3)
	DirAccess.remove_absolute("user://lumo_puzzle_adventure_capture.json")


func _hub(orient: String) -> void:
	root.get_node("SceneRouter").launch_options = {
		"grade": 2, "subject": "Mathematik", "childKey": "capture-no-production-save", "reduceAnimations": false
	}
	var hub: Node = load("res://scenes/games/game_hub.tscn").instantiate()
	root.add_child(hub)
	await _settle(40)
	await _measure("hub", orient)
	if _want("hub"):
		await _capture("hub_" + orient)
	hub.queue_free()
	await _settle(3)


func _settle(frames: int) -> void:
	for _i in range(frames):
		await process_frame


func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var frame: Image = root.get_texture().get_image()
	var path := out_dir.path_join("%s_%s_%s.jpg" % [tag, profile_name, name])
	frame.save_jpg(path, 0.86)
	print("[AdventureCapture] ", path, " ", frame.get_size())
