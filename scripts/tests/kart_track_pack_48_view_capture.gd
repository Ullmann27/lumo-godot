extends SceneTree
## Renders the 48 developer-pack views for one Lumo Kart world.
## Loop views are explicit authoring previews and never mark the loop driveable.

const WORLD = preload("res://scripts/games/kart_world.gd")
const VEHICLE = preload("res://scripts/games/kart_vehicle.gd")
const KART_ISLAND = preload("res://scripts/games/kart_island.gd")

const CAPTURE_SIZE := Vector2i(960, 540)
const LOOP_RADIUS_M := 12.0
const LOOP_ROAD_WIDTH_M := 10.8
const LOOP_SEGMENTS := 96

var track_id: String = ""
var pack: Dictionary = {}
var views: Array = []
var world
var camera: Camera3D
var kart
var item_root: Node3D
var ai_debug_root: Node3D
var collision_debug_root: Node3D
var shortcut_debug_root: Node3D
var loop_root: Node3D
var capture_index: int = 0
var frame_index: int = 0
var out_dir: String = ""
var route_center := Vector3.ZERO
var route_extent_m: float = 180.0
var capture_report: Array = []


func _initialize() -> void:
	call_deferred("_setup")


func _setup() -> void:
	track_id = _track_id_from_args()
	assert(track_id in ["sonnenhafen", "zauberwald", "bergwelt", "holo_city"])
	out_dir = "res://exports/track-pack-views/" + track_id
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = CAPTURE_SIZE

	var pack_path := "res://docs/track_expansion/2026-10-06/packs/" + track_id + ".json"
	var raw := FileAccess.get_file_as_string(pack_path)
	var parsed = JSON.parse_string(raw)
	assert(typeof(parsed) == TYPE_DICTIONARY)
	pack = parsed
	views = pack.get("views", [])
	assert(views.size() == 48)

	world = WORLD.new()
	root.add_child(world)
	world.build(false, track_id)

	camera = Camera3D.new()
	camera.far = 1400.0
	camera.fov = 58.0
	world.add_child(camera)
	camera.make_current()

	kart = VEHICLE.new()
	world.add_child(kart)
	kart.configure("fox", Color("3586bc"), "comet")
	kart.set_process(false)

	_build_runtime_items()
	_compute_route_bounds()
	_build_debug_overlays()
	_build_loop_preview()

	print("[TrackPackViews] track=", track_id, " views=", views.size(), " length=", world.length)
	_place_current_view()


func _track_id_from_args() -> String:
	for arg in OS.get_cmdline_user_args():
		var text := str(arg)
		if text.begins_with("--track-id="):
			return text.trim_prefix("--track-id=")
	return ""


func _build_runtime_items() -> void:
	item_root = Node3D.new()
	item_root.name = "DeveloperPackMysteryPrisms"
	world.add_child(item_root)

	var helper: Node = KART_ISLAND.new()
	helper.set("world", world)
	helper.set("race_root", item_root)
	for zone in pack.get("mystery_prism_zones", []):
		var fraction: float = float(zone.get("route_fraction", 0.0))
		var lateral: float = float(zone.get("lateral_m", 0.0))
		helper.call("_item_box", fraction * world.length, lateral)


func _compute_route_bounds() -> void:
	var minimum: Vector3 = Vector3(INF, INF, INF)
	var maximum: Vector3 = Vector3(-INF, -INF, -INF)
	for i in range(128):
		var d: float = float(world.length) * float(i) / 128.0
		var p: Vector3 = world.position_at(d)
		minimum.x = min(minimum.x, p.x)
		minimum.y = min(minimum.y, p.y)
		minimum.z = min(minimum.z, p.z)
		maximum.x = max(maximum.x, p.x)
		maximum.y = max(maximum.y, p.y)
		maximum.z = max(maximum.z, p.z)
	route_center = (minimum + maximum) * 0.5
	route_extent_m = max(maximum.x - minimum.x, maximum.z - minimum.z) + 35.0


func _build_debug_overlays() -> void:
	ai_debug_root = Node3D.new()
	ai_debug_root.name = "AIRacingLineDebug"
	world.add_child(ai_debug_root)
	for anchor in pack.get("ai_racing_line", []):
		var d: float = float(anchor.get("route_fraction", 0.0)) * float(world.length)
		var lateral: float = float(anchor.get("lateral_m", 0.0))
		var p: Vector3 = world.position_at(d) + world.frame(d) * Vector3(lateral, 1.0, 0.0)
		_add_sphere(ai_debug_root, p, 0.85, Color("ffd84d"))

	collision_debug_root = Node3D.new()
	collision_debug_root.name = "CollisionGuideDebug"
	world.add_child(collision_debug_root)
	for i in range(48):
		var d: float = float(world.length) * float(i) / 48.0
		for lateral in [-6.05, 6.05]:
			var rail_p: Vector3 = world.position_at(d) + world.frame(d) * Vector3(lateral, 0.5, 0.0)
			_add_box(collision_debug_root, rail_p, Vector3(0.35, 1.0, 1.8), Color("31d8ff"))
		for lateral in [-5.0, 5.0]:
			var wall_p: Vector3 = world.position_at(d) + world.frame(d) * Vector3(lateral, 0.85, 0.0)
			_add_box(collision_debug_root, wall_p, Vector3(0.28, 1.7, 1.5), Color("ff5a6e"))
	for checkpoint in pack.get("checkpoints", []):
		var d: float = float(checkpoint.get("route_fraction", 0.0)) * float(world.length)
		_add_box(collision_debug_root, world.position_at(d) + Vector3.UP * 2.4, Vector3(0.8, 4.8, 0.8), Color("5dff91"))

	shortcut_debug_root = Node3D.new()
	shortcut_debug_root.name = "ShortcutAnchorDebug"
	world.add_child(shortcut_debug_root)
	var shortcut_fraction: float = _shortcut_fraction()
	_add_sphere(
		shortcut_debug_root,
		world.position_at(shortcut_fraction * world.length) + Vector3.UP * 2.4,
		1.5,
		Color("ff9b42")
	)

	ai_debug_root.visible = false
	collision_debug_root.visible = false
	shortcut_debug_root.visible = false


func _add_sphere(parent: Node3D, position: Vector3, radius: float, color: Color) -> void:
	var instance: MeshInstance3D = MeshInstance3D.new()
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	instance.mesh = mesh
	instance.position = position
	instance.material_override = _debug_material(color)
	parent.add_child(instance)


func _add_box(parent: Node3D, position: Vector3, size: Vector3, color: Color) -> void:
	var instance: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = position
	instance.material_override = _debug_material(color)
	parent.add_child(instance)


func _debug_material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.7
	return material


func _build_loop_preview() -> void:
	loop_root = Node3D.new()
	loop_root.name = "AuthoringOnlyFullLoop"
	loop_root.set_meta("runtime_driveable", false)
	loop_root.set_meta("collision_included", false)
	loop_root.set_meta("requires_inverted_physics_contract", true)
	world.add_child(loop_root)

	var vertices: PackedVector3Array = PackedVector3Array()
	var indices: PackedInt32Array = PackedInt32Array()
	for i in range(LOOP_SEGMENTS + 1):
		var theta: float = -PI * 0.5 + TAU * float(i) / float(LOOP_SEGMENTS)
		var center: Vector3 = Vector3(
			0.0,
			LOOP_RADIUS_M + LOOP_RADIUS_M * sin(theta),
			-LOOP_RADIUS_M * cos(theta)
		)
		vertices.append(center + Vector3(-LOOP_ROAD_WIDTH_M * 0.5, 0.0, 0.0))
		vertices.append(center + Vector3(LOOP_ROAD_WIDTH_M * 0.5, 0.0, 0.0))
	for i in range(LOOP_SEGMENTS):
		var a: int = i * 2
		var b: int = a + 1
		var c: int = a + 2
		var d: int = a + 3
		indices.append(a)
		indices.append(c)
		indices.append(b)
		indices.append(b)
		indices.append(c)
		indices.append(d)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _debug_material(_loop_color())
	loop_root.add_child(instance)
	loop_root.visible = false


func _loop_color() -> Color:
	match track_id:
		"sonnenhafen":
			return Color("48e7ff")
		"zauberwald":
			return Color("7cff83")
		"bergwelt":
			return Color("ffd75a")
		"holo_city":
			return Color("ff54e8")
	return Color("54dcff")


func _place_current_view() -> void:
	var view: Dictionary = views[capture_index]
	var kind: String = str(view.get("kind", ""))
	var cam: Dictionary = view.get("camera", {})

	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 58.0
	camera.size = 120.0
	kart.visible = true
	item_root.visible = true
	ai_debug_root.visible = false
	collision_debug_root.visible = false
	shortcut_debug_root.visible = false
	loop_root.visible = false

	match kind:
		"orbit":
			_place_orbit(view, cam)
		"orthographic":
			kart.visible = false
			_place_orthographic(str(cam.get("axis", "top")), float(cam.get("orthographic_size_m", route_extent_m)), route_center)
		"driver":
			_place_driver(view, cam)
		"signature":
			_place_signature(view, cam)
		"loop":
			kart.visible = false
			_place_loop(view, cam)
		"item_lane":
			_place_item_lane(cam)
		"shortcut_entry":
			shortcut_debug_root.visible = true
			_place_shortcut(cam)
		"ai_debug":
			kart.visible = false
			ai_debug_root.visible = true
			_place_orthographic("top", float(cam.get("orthographic_size_m", route_extent_m)), route_center)
		"collision_debug":
			kart.visible = false
			collision_debug_root.visible = true
			_place_orthographic("top", max(route_extent_m, 150.0), route_center)
		_:
			assert(false, "Unknown view kind: " + kind)

	frame_index = 0


func _place_orbit(view: Dictionary, cam: Dictionary) -> void:
	kart.visible = false
	var fraction: float = _route_fraction(str(view.get("target", "route_fraction:0.500")), 0.5)
	var target: Vector3 = world.position_at(fraction * float(world.length))
	target.y += float(cam.get("target_height_m", 8.0))
	var azimuth: float = deg_to_rad(float(cam.get("azimuth_deg", 0.0)))
	var elevation: float = deg_to_rad(float(cam.get("elevation_deg", 30.0)))
	var distance: float = float(cam.get("distance_m", 105.0))
	var direction: Vector3 = Vector3(
		cos(elevation) * sin(azimuth),
		sin(elevation),
		cos(elevation) * cos(azimuth)
	)
	camera.position = target + direction * distance
	camera.look_at(target, Vector3.UP)


func _place_driver(view: Dictionary, cam: Dictionary) -> void:
	var fraction: float = _route_fraction(str(view.get("target", "route_fraction:0.000")), 0.0)
	var d: float = fraction * float(world.length)
	kart.transform = world.reset_transform(d, 0.0)
	var distance: float = float(cam.get("distance_m", 9.0))
	var elevation: float = deg_to_rad(float(cam.get("elevation_deg", 18.0)))
	var local_offset: Vector3 = Vector3(0.0, 1.8 + sin(elevation) * distance, cos(elevation) * distance)
	camera.position = kart.position + world.frame(d) * local_offset
	camera.look_at(world.position_at(d + 16.0) + Vector3.UP * 1.5, Vector3.UP)


func _place_signature(view: Dictionary, cam: Dictionary) -> void:
	var setpiece_id: String = str(view.get("target", "")).trim_prefix("setpiece:")
	var fraction: float = _setpiece_fraction(setpiece_id, 0.5)
	var d: float = fraction * float(world.length)
	var target: Vector3 = world.position_at(d) + Vector3.UP * 2.6
	var distance: float = float(cam.get("distance_m", 34.0))
	var elevation: float = deg_to_rad(float(cam.get("elevation_deg", 24.0)))
	var side: String = str(cam.get("side", "front"))
	var signed_distance: float = distance if side == "front" else -distance
	var local_offset: Vector3 = Vector3(0.0, sin(elevation) * distance + 2.0, cos(elevation) * signed_distance)
	camera.position = target + world.frame(d) * local_offset
	camera.look_at(target, Vector3.UP)


func _place_loop(view: Dictionary, cam: Dictionary) -> void:
	var setpiece_id: String = str(view.get("target", "")).trim_prefix("setpiece:")
	var fraction: float = _setpiece_fraction(setpiece_id, 0.72)
	var d: float = fraction * float(world.length)
	loop_root.transform = world.reset_transform(d, 0.0)
	loop_root.visible = true
	var target: Vector3 = loop_root.global_position + Vector3.UP * LOOP_RADIUS_M
	var axis: String = str(cam.get("axis", "side"))
	var distance: float = float(cam.get("distance_m", 54.0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = float(cam.get("orthographic_size_m", 58.0))
	if axis == "top":
		camera.position = target + Vector3.UP * distance
		camera.look_at(target, Vector3.FORWARD)
	else:
		camera.position = target + world.frame(d) * Vector3(distance, 0.0, 0.0)
		camera.look_at(target, Vector3.UP)


func _place_item_lane(cam: Dictionary) -> void:
	var zones: Array = pack.get("mystery_prism_zones", [])
	assert(not zones.is_empty())
	var fraction: float = float(zones[0].get("route_fraction", 0.18))
	var lateral: float = float(zones[0].get("lateral_m", 0.0))
	var d: float = fraction * float(world.length)
	kart.transform = world.reset_transform(d, lateral)
	var distance: float = float(cam.get("distance_m", 12.0))
	var elevation: float = deg_to_rad(float(cam.get("elevation_deg", 16.0)))
	var local_offset: Vector3 = Vector3(0.0, 1.8 + sin(elevation) * distance, cos(elevation) * distance)
	camera.position = kart.position + world.frame(d) * local_offset
	camera.look_at(world.position_at(d + 20.0) + Vector3.UP * 1.5, Vector3.UP)


func _place_shortcut(cam: Dictionary) -> void:
	var fraction: float = _shortcut_fraction()
	var d: float = fraction * float(world.length)
	var target: Vector3 = world.position_at(d) + Vector3.UP * 2.2
	var azimuth: float = deg_to_rad(float(cam.get("azimuth_deg", 25.0)))
	var elevation: float = deg_to_rad(float(cam.get("elevation_deg", 30.0)))
	var distance: float = float(cam.get("distance_m", 30.0))
	var direction: Vector3 = Vector3(
		cos(elevation) * sin(azimuth),
		sin(elevation),
		cos(elevation) * cos(azimuth)
	)
	camera.position = target + world.frame(d) * (direction * distance)
	camera.look_at(target, Vector3.UP)


func _place_orthographic(axis: String, size_m: float, target: Vector3) -> void:
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = size_m
	var distance: float = maxf(size_m * 0.85, 100.0)
	match axis:
		"top":
			camera.position = target + Vector3.UP * distance
			camera.look_at(target, Vector3.FORWARD)
		"front":
			camera.position = target + Vector3(0.0, 0.0, distance)
			camera.look_at(target, Vector3.UP)
		"left", "side":
			camera.position = target + Vector3(-distance, 0.0, 0.0)
			camera.look_at(target, Vector3.UP)
		"right":
			camera.position = target + Vector3(distance, 0.0, 0.0)
			camera.look_at(target, Vector3.UP)
		_:
			camera.position = target + Vector3.UP * distance
			camera.look_at(target, Vector3.FORWARD)


func _route_fraction(target: String, fallback: float) -> float:
	if target.begins_with("route_fraction:"):
		return float(target.trim_prefix("route_fraction:"))
	return fallback


func _setpiece_fraction(setpiece_id: String, fallback: float) -> float:
	for setpiece in pack.get("signature_setpieces", []):
		if str(setpiece.get("id", "")) == setpiece_id:
			return float(setpiece.get("anchor_fraction", fallback))
	return fallback


func _shortcut_fraction() -> float:
	for setpiece in pack.get("signature_setpieces", []):
		var folded: String = (
			str(setpiece.get("id", ""))
			+ " "
			+ str(setpiece.get("name", ""))
			+ " "
			+ JSON.stringify(setpiece.get("handoff_notes", []))
		).to_lower()
		if "shortcut" in folded or "abkürzung" in folded or "rampe" in folded or "ramp" in folded:
			return float(setpiece.get("anchor_fraction", 0.55))
	return 0.55


func _capture_state(kind: String) -> String:
	match kind:
		"loop":
			return "authoring_preview_non_driveable"
		"ai_debug", "collision_debug":
			return "runtime_debug_overlay"
		"shortcut_entry":
			return "runtime_or_planned_anchor_context"
		_:
			return "runtime_render"


func _safe_name(value: String) -> String:
	return value.replace("/", "_").replace(":", "_").replace(" ", "_")


func _finish_report() -> void:
	var report_path: String = out_dir + "/capture_report.json"
	var file: FileAccess = FileAccess.open(report_path, FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(capture_report, "\t"))
	file.close()
	print("[TrackPackViews] PASS track=", track_id, " captured=", capture_report.size(), " out=", out_dir)


func _process(_delta: float) -> bool:
	frame_index += 1
	if frame_index < 6:
		return false

	var view: Dictionary = views[capture_index]
	var filename: String = _safe_name(str(view.get("id", "view_" + str(capture_index)))) + ".png"
	var image: Image = root.get_texture().get_image()
	assert(image.save_png(out_dir + "/" + filename) == OK)
	capture_report.append(
		{
			"id": view.get("id"),
			"kind": view.get("kind"),
			"target": view.get("target"),
			"acceptance": view.get("acceptance"),
			"file": filename,
			"capture_state": _capture_state(str(view.get("kind", ""))),
		}
	)
	print("[TrackPackViews] captured ", track_id, " ", capture_index + 1, "/48 ", filename)

	capture_index += 1
	if capture_index >= views.size():
		_finish_report()
		quit(0)
	else:
		_place_current_view()
	return false
