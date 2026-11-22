extends SceneTree
## Vergleichskamera im echten Welt-/Garagen-Viewport. -- --out=<Ordner>.
const ROSTER = preload("res://scripts/games/lumo_opponent_roster.gd")
const TEARDOWN = preload("res://scripts/tests/helpers/kart_scene_teardown.gd")
var out := ""
var seen := {}
var failed := false


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	call_deferred("_run")


func _run() -> void:
	if out.is_empty() or DisplayServer.get_name() == "headless":
		printerr("Ein Bildordner und ein Renderer werden benötigt.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(out)
	for track in ["riesengarten_2400", "jungle_emerald_3600"]:
		var game = load("res://scenes/games/kart_island.tscn").instantiate()
		root.add_child(game)
		game.set_physics_process(false)
		root.size = Vector2i(800, 480)
		await process_frame
		if seen.is_empty():
			var garage = game.garage
			garage.setup.driver = "fox"
			garage.setup.kart = "comet"
			garage.step = 2
			garage._refresh()
			garage._choose_preview_view(6)
			await process_frame
			var kart = garage.preview_kart
			await _portrait("garage", kart)
			for entry in ROSTER.for_game("kart"):
				kart.set_animated_lumo_enabled(false)
				kart.configure(entry.id, Color(entry.color), "comet")
				kart.set_reference_rival_enabled(true)
				await _portrait("garage", kart)
		game._start_selected_race({"mode": "race", "driver": "fox", "kart": "comet",
			"track": track, "difficulty": "flott"})
		game._end_preview()
		await _field("start", game)
		game.racing = true
		game.countdown = 0.0
		game.gas_held = true
		for tick in 180:
			game._physics_process(1.0 / 60.0)
		await _field("rennen", game)
		game._finish(false)
		for frame in 12:
			await process_frame
		await _field("jubel", game)
		await TEARDOWN.release_scene(self, game, "[RosterContext]")
	if failed or seen.size() != 28:
		printerr("[RosterContext] FAIL ", seen.size())
		quit(1)
	else:
		print("[RosterContext] PASS 28 Spielansichten")
		quit(0)


func _field(stage: String, game) -> void:
	var field: Array = [game.player] + game.opponents
	for actor in field:
		if seen.has("%s_%s" % [stage, actor.animal]):
			continue
		# Startplätze liegen so eng, dass die Vergleichskamera sonst im Nachbarkart sitzt.
		var hidden: Array[Node3D] = []
		for other in field:
			if other != actor and other.visible:
				other.hide()
				hidden.append(other)
		await _portrait(stage, actor)
		for other in hidden:
			other.show()


func _portrait(stage: String, actor) -> void:
	var id := "%s_%s" % [stage, actor.animal]
	if seen.has(id):
		return
	if not is_instance_valid(actor.lumo_animation if actor.animal == "fox" else actor.production_driver):
		printerr("Figur fehlt: ", id)
		failed = true
		return
	actor.set_preview_detail(true)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(360, 300)
	viewport.world_3d = actor.get_world_3d()
	root.add_child(viewport)
	var camera := Camera3D.new()
	viewport.add_child(camera)
	camera.fov = 37.0
	camera.position = actor.to_global(Vector3(-1.65, 1.73, -3.2))
	camera.look_at(actor.to_global(Vector3(0, 1.03, -0.02)), actor.global_basis.y.normalized())
	camera.current = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	if image.save_png(out.path_join(id + ".png")) == OK:
		seen[id] = true
	else:
		failed = true
	viewport.free()
