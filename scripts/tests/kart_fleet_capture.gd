extends SceneTree
## Real Godot renders and static GLB exports, never image-generated screenshots.
const VEHICLE = preload("res://scripts/games/kart_vehicle.gd")
const FLEET = preload("res://scripts/games/kart_fleet.gd")
const WORLD = preload("res://scripts/games/kart_world.gd")
const DRESSING = preload("res://scripts/games/kart_fleet_dressing.gd")
const PROP_EXPORT = preload("res://scripts/tests/kart_fleet_prop_export.gd")

var stage: Node3D
var camera: Camera3D
var kart
var model_report: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("_run")


func _capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	assert(image.save_png("res://exports/fleet-proof/" + name + ".png") == OK)
	print("[FleetCapture] " + name)


func _copy_visual(source: Node3D, destination: Node3D, owner_kart) -> void:
	for child in source.get_children():
		if not child is Node3D:
			continue
		if (
			child is MeshInstance3D
			and (
				child == owner_kart.far_mesh
				or owner_kart.flames.has(child)
				or owner_kart.sparks.has(child)
				or not child.visible
			)
		):
			continue
		var copy: Node3D
		if child is MeshInstance3D:
			var mesh := MeshInstance3D.new()
			mesh.mesh = child.mesh
			mesh.material_override = child.material_override
			copy = mesh
		else:
			copy = Node3D.new()
		copy.name = child.name
		copy.transform = child.transform
		destination.add_child(copy)
		_copy_visual(child, copy, owner_kart)


func _export_model(id: String) -> void:
	var model := Node3D.new()
	model.name = "Lumo_" + id
	_copy_visual(kart, model, kart)
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	assert(document.append_from_scene(model, state) == OK)
	var path: String = "res://exports/fleet-models/" + id + ".glb"
	assert(document.write_to_filesystem(state, path) == OK)
	model_report.append(
		{
			"id": id,
			"file": id + ".glb",
			"source": "authored Godot geometry",
			"animations": "procedural in game; GLB is a static snapshot"
		}
	)
	model.free()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute("res://exports/fleet-proof")
	DirAccess.make_dir_recursive_absolute("res://exports/fleet-models")
	stage = Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("07182b")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d4e3ff")
	env.ambient_light_energy = 0.52
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.environment = env
	stage.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38, -34, 0)
	key.light_color = Color("ffe5c4")
	key.light_energy = 1.3
	stage.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 144, 0)
	fill.light_color = Color("84c4f4")
	fill.light_energy = 0.5
	stage.add_child(fill)
	camera = Camera3D.new()
	camera.fov = 34
	stage.add_child(camera)
	camera.make_current()
	var ids: Array[String] = ["comet", "glider", "turbo"]
	ids.append_array(FLEET.IDS)
	for id in ids:
		kart = VEHICLE.new()
		kart.configure("fox", Color("76d9ff"), id)
		kart.reduced_motion = true
		stage.add_child(kart)
		kart.set_process(false)
		_export_model(id)
		var views: Array[Vector3] = [
			Vector3(3.4, 2.6, -5.5), Vector3(-5.7, 1.2, 0), Vector3(0, 1.2, 5.7), Vector3(0, 6.0, 0)
		]
		var names: Array[String] = ["hero", "left", "rear", "top"]
		for i in range(views.size()):
			camera.projection = (
				Camera3D.PROJECTION_PERSPECTIVE if i == 0 else Camera3D.PROJECTION_ORTHOGONAL
			)
			camera.size = 4.25
			camera.position = views[i]
			camera.look_at(Vector3(0, 0.90, 0), Vector3.FORWARD if i == 3 else Vector3.UP)
			await _capture(id + "-" + names[i])
		kart.free()
	var report := FileAccess.open("res://exports/fleet-models/models.json", FileAccess.WRITE)
	report.store_string(JSON.stringify(model_report, "  "))
	report.close()
	for kind in DRESSING.KINDS:
		var prop: Node3D = PROP_EXPORT.build_model(kind)
		stage.add_child(prop)
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.position = Vector3(6, 5.5, -9.8)
		camera.look_at(Vector3(0, 1.3, 0))
		await _capture("module-" + kind + "-hero")
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 6.0
		camera.position = Vector3(0, 1.3, -9.8)
		camera.look_at(Vector3(0, 1.3, 0))
		await _capture("module-" + kind + "-front")
		prop.free()
	root.world_3d.fallback_environment = null
	stage.free()
	var game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game._start_selected_race(
		{
			"mode": "race",
			"driver": "fox",
			"kart": "gecko_velo",
			"track": "sonnenhafen",
			"difficulty": "gemuetlich"
		}
	)
	game.set_physics_process(false)
	game._end_preview()
	game.countdown = 0.0
	game.racing = true
	game.paused = false
	game.modal.hide()
	game.speed = 14.0
	for fraction in [0.06, 0.31, 0.65]:
		game.distance = game.track_length * fraction
		game.previous_road_distance = game.distance
		game.player.transform = game.world.reset_transform(game.distance, 0.0)
		game.player_heading = game._heading(game.distance)
		game.physical_velocity = (
			Vector3(-sin(game.player_heading), 0, -cos(game.player_heading)) * game.speed
		)
		for i in range(game.opponents.size()):
			game.opponent_distances[i] = game.distance + 6.0 + i * 6.0
			game.opponents[i].transform = game.world.reset_transform(
				game.opponent_distances[i], game.opponent_lanes[i]
			)
			game.opponent_headings[i] = game._heading(game.opponent_distances[i])
		game._physics_process(0.0)
		game._update_camera(1.0, true)
		await _capture("sonnenhafen-fleet-" + str(roundi(fraction * 100)))
	root.size = Vector2i(640, 320)
	await process_frame
	game._apply_responsive_layout()
	await _capture("fleet-compact-640x320")
	print(
		"[FleetCapture] PASS: 36 native kart views, 12 prop views, 9 kart GLBs, 4 live race captures"
	)
	game.abandoned = true
	root.world_3d.fallback_environment = null
	game.queue_free()
	await process_frame
	await create_timer(0.8).timeout
	quit()
