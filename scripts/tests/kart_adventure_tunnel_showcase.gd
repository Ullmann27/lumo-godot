extends SceneTree
## Bounded review of actual production road/tunnel geometry and materials.
## Builds no terrain, landmarks, course environment, or full racing scene.
## Neutral studio lighting is intentional; these are not full gameplay frames
## and do not establish physical Android performance.
## Usage: godot --rendering-method gl_compatibility --script
## scripts/tests/kart_adventure_tunnel_showcase.gd -- --output=/absolute/path
## Optional: --track-id=crystal_canyon or --low-detail. Default: all 11, high detail.

const WORLD = preload("res://scripts/games/kart_world.gd")
const TRACKS = preload("res://scripts/games/kart_tracks.gd")
const ROUTES = preload("res://scripts/games/kart_adventure_routes.gd")
const TUNNELS = preload("res://scripts/games/kart_adventure_tunnels.gd")
const EXPANSION = preload("res://scripts/games/kart_expansion_world.gd")
const SKY_ISLANDS = preload("res://scripts/games/kart_sky_islands.gd")
const SIZE := Vector2i(1440, 900)

var output: String = "res://exports/kart-adventure/tunnel-review"
var selected: String = "all"
var low_detail: bool = false
var stage: Node3D
var camera: Camera3D
var title: Label
var subtitle: Label
var reports: Array[Dictionary] = []
var route_records: Array[Dictionary] = []
var ids: Array[String] = []


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
		elif argument.begins_with("--track-id="):
			selected = argument.trim_prefix("--track-id=")
		elif argument == "--low-detail":
			low_detail = true
	call_deferred("_run")


func _run() -> void:
	assert(DisplayServer.get_name() != "headless", "Tunnel views need the actual rasterizer.")
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	if selected == "all":
		ids.assign(ROUTES.IDS)
	else:
		assert(ROUTES.supports(selected), "Only the eleven production adventure tunnels are reviewed.")
		ids.append(selected)
	root.size = SIZE
	root.content_scale_size = SIZE
	root.msaa_3d = Viewport.MSAA_2X
	stage = Node3D.new()
	stage.name = "TunnelGeometryReviewStage"
	root.add_child(stage)
	_build_review_lighting()
	_build_caption()
	_write_manifest(false)
	for id in ids:
		await _capture_track(id)
		_write_manifest(false)
	assert(reports.size() == ids.size() * 2)
	_write_manifest(true)
	stage.free()
	for _frame in range(3):
		await process_frame
	print("[KartTunnelShowcase] PASS: ", reports.size(), " actual production geometry frames across ", ids.size(), " tunnels; studio lighting")
	quit(0)


func _build_review_lighting() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("172330")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("e5eaf0")
	environment.ambient_light_energy = 0.65
	environment.fog_enabled = false
	environment.volumetric_fog_enabled = false
	environment.glow_enabled = false
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	stage.add_child(world_environment)
	camera = Camera3D.new()
	camera.near = 0.10
	camera.far = 300.0
	camera.fov = 60.0
	stage.add_child(camera)
	camera.make_current()
	# Lighting follows the inspection camera, so all route palettes receive the
	# same neutral review illumination without authoring course-specific lights.
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-32, -38, 0)
	key.light_color = Color("fff3e2")
	key.light_energy = 0.85
	key.shadow_enabled = false
	camera.add_child(key)
	var fill := OmniLight3D.new()
	fill.position = Vector3(0, 2, -4)
	fill.omni_range = 72.0
	fill.light_color = Color("e4f1ff")
	fill.light_energy = 1.0
	fill.shadow_enabled = false
	camera.add_child(fill)


func _build_caption() -> void:
	var layer := CanvasLayer.new()
	stage.add_child(layer)
	var background := ColorRect.new()
	background.color = Color(0.035, 0.06, 0.095, 0.90)
	background.position = Vector2.ZERO
	background.size = Vector2(SIZE.x, 92)
	layer.add_child(background)
	title = Label.new()
	title.position = Vector2(32, 13)
	title.size = Vector2(SIZE.x - 64, 39)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("edf6ff"))
	layer.add_child(title)
	subtitle = Label.new()
	subtitle.position = Vector2(32, 53)
	subtitle.size = Vector2(SIZE.x - 64, 30)
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color("bacbdc"))
	layer.add_child(subtitle)


func _capture_track(id: String) -> void:
	print("[KartTunnelShowcase] building bounded production geometry: ", id)
	var world = WORLD.new()
	world.name = "Review_" + id
	stage.add_child(world)
	world.low_detail = low_detail
	world._only_geometry = true
	world.track_id = id
	world.definition = TRACKS.definition(id)
	world.track_name = str(world.definition.name)
	world._rng.seed = int(world.definition.seed)
	world._make_curve()
	if id == "bergwelt":
		world.jump = SKY_ISLANDS.jump_layout(world.length)
	elif id in TRACKS.EXPANSION.IDS:
		EXPANSION.prepare(world)
	world._road()
	assert(world.road != null, "The exact production road ribbon must exist.")
	var span: Dictionary = world.adventure_tunnel
	assert(not span.is_empty())
	# _road() also creates start arches/action dressing outside this passage.
	# Keep its exact ribbon nodes and only near-road instance transforms around
	# the reviewed tunnel; never assemble or flush an outdoor landmark world.
	var hidden_road_nodes: int = 0
	for child in world.get_children():
		# At this point _road() has created only ribbon meshes and arch labels.
		# Keep both shoulder strips even when Godot renames a duplicate node name.
		if child is Node3D and not child is MeshInstance3D:
			child.visible = false
			hidden_road_nodes += 1
	var trim: Dictionary = _retain_nearby_road_instances(world, float(span.start_m) - 55.0, float(span.end_m) + 35.0)
	world._flush_instances()
	TUNNELS.build(world)
	var passage: Node3D = world.get_node("AdventureTunnel")
	var metrics: Dictionary = passage.get_meta("adventure_tunnel")
	assert(metrics == world.get_meta("adventure_tunnel"))
	assert(metrics.track_id == id)
	assert(passage.has_node("ContinuousInnerVault") and passage.has_node("CarvedEntranceAndExit"))
	var start: float = float(span.start_m)
	var finish: float = float(span.end_m)
	for view in ["approach", "inside"]:
		var at: float = start - 27.0 if view == "approach" else lerpf(start, finish, 0.43)
		var aim_distance: float = start + 13.0 if view == "approach" else at + 24.0
		var basis: Basis = world.frame(at)
		var aim_basis: Basis = world.frame(aim_distance)
		var height: float = 4.0 if view == "approach" else 3.3
		var eye: Vector3 = world.position_at(at, -0.65) + basis.y * height
		var target: Vector3 = world.position_at(aim_distance, 0.0) + aim_basis.y * 3.8
		camera.fov = 60.0 if view == "approach" else 65.0
		camera.look_at_from_position(eye, target, basis.y)
		title.text = str(world.track_name) + " · " + str(span.name)
		subtitle.text = ("Einfahrt" if view == "approach" else "Tunnelinnenraum") + "  ·  Produktionsgeometrie mit neutralem Studiolicht"
		var filename: String = id + "-" + view + ".png"
		await _capture(filename)
		reports.append({
			"track_id": id, "track_name": world.track_name, "tunnel_name": span.name,
			"view": view, "file": filename,
			"camera_m": _vector(eye), "target_m": _vector(target), "camera_up": _vector(basis.y),
			"camera_route_distance_m": at, "target_route_distance_m": aim_distance,
			"vertical_fov_degrees": camera.fov, "resolution": [SIZE.x, SIZE.y],
			"actual_production_geometry": true, "lighting": "neutral studio",
		})
	route_records.append({
		"track_id": id, "track_name": world.track_name, "route_length_m": world.length,
		"low_detail": low_detail, "production_tunnel_metrics": metrics,
		"road_trim": trim, "unrelated_road_child_nodes_hidden": hidden_road_nodes,
		"full_world_built": false, "terrain_built": false, "landmarks_built": false,
	})
	world.free()
	for _frame in range(3):
		await process_frame


func _retain_nearby_road_instances(world, start: float, finish: float) -> Dictionary:
	var original: int = 0
	var retained: int = 0
	var selected_groups: Dictionary = {}
	for key in world.groups:
		var group: Dictionary = world.groups[key]
		var transforms: Array = []
		var colors: Array = []
		original += group.transforms.size()
		for index in range(group.transforms.size()):
			var transform: Transform3D = group.transforms[index]
			var near: Vector2 = world._nearest_horizontal(transform.origin)
			var distance: float = world._road_distances[int(near.y)]
			if distance < start or distance > finish or near.x > 7.1:
				continue
			var local: Vector3 = world.frame(distance).inverse() * (transform.origin - world.position_at(distance))
			if local.y < -2.0 or local.y > 2.0:
				continue
			transforms.append(transform)
			colors.append(group.colors[index])
			retained += 1
		if not transforms.is_empty():
			var selected_group: Dictionary = group.duplicate()
			selected_group.transforms = transforms
			selected_group.colors = colors
			selected_groups[key] = selected_group
	world.groups = selected_groups
	world.decoration_count = retained
	return {
		"production_instances_generated": original, "production_instances_retained": retained,
		"route_start_m": start, "route_end_m": finish,
		"scope": "Unmodified production instance transforms/colors near the tunnel; unrelated outdoor groups omitted",
	}


func _capture(filename: String) -> void:
	for _frame in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	var frame: Image = root.get_texture().get_image()
	assert(frame.get_size() == SIZE)
	assert(frame.save_png(output.path_join(filename)) == OK)
	print("[KartTunnelShowcase] captured ", filename)


func _write_manifest(complete: bool) -> void:
	var file := FileAccess.open(output.path_join("capture-manifest.json"), FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify({
		"schema_version": 1, "complete": complete,
		"engine": Engine.get_version_info().string,
		"renderer": "Godot Compatibility / local Mesa software renderer",
		"scope": "Production road and tunnel geometry review with neutral studio lighting",
		"actual_production_geometry": true, "materials_modified": false,
		"full_gameplay_frame": false, "physical_android_performance": false,
		"terrain_or_landmark_world_built": false, "vehicles_included": false,
		"pipeline": ["TRACKS.definition", "WORLD._make_curve", "production jump/expansion metadata", "WORLD._road", "nearby production road-instance crop", "WORLD._flush_instances", "TUNNELS.build"],
		"expected_track_ids": ids, "expected_frame_count": ids.size() * 2,
		"low_detail": low_detail, "routes": route_records, "captures": reports,
	}, "  "))
	file.close()


func _vector(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]
