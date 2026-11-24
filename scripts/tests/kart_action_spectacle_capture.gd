extends SceneTree
## Captures actual production KartWorld meshes and shaders with a real renderer.
const WORLD = preload("res://scripts/games/kart_world.gd")
const TRACKS = preload("res://scripts/games/kart_tracks.gd")
const LOOP = preload("res://scripts/games/kart_physical_loop.gd")
const SPECTACLE = preload("res://scripts/games/kart_course_spectacle.gd")
const SPEED_ZONE = preload("res://scripts/games/kart_stunt_speed_zone.gd")
var track: String = "sonnenhafen"
var output: String = "/tmp/lumo-kart-views"
var views: PackedStringArray = PackedStringArray(["course", "landscape"])
var world
var camera: Camera3D
var captures: Array = []


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--track="):
			track = argument.trim_prefix("--track=")
		elif argument.begins_with("--out="):
			output = argument.trim_prefix("--out=")
		elif argument.begins_with("--views="):
			views = argument.trim_prefix("--views=").split(",", false)
	call_deferred("_run")


func _camera_for(view: String) -> bool:
	var report: Dictionary = SPECTACLE.of(world)
	var eye := Vector3.ZERO
	var target := Vector3.ZERO
	if view.begins_with("loop_"):
		var data: Dictionary = world.loop_layout
		if data.is_empty():
			printerr("[KartCapture] Requested loop view on a track without a loop")
			return false
		var start: float = float(data.start)
		var radius: float = LOOP.radius_of(data)
		var basis: Basis = world.frame(LOOP.road_distance_at(data, 0.25))
		if view == "loop_approach":
			eye = world.position_at(start - 19.0, float(data.lane) - signf(float(data.lane)) * 2.4) + Vector3.UP * 3.5
			target = LOOP.point(world, data, 0.38) + Vector3.UP * 2.0
		elif view == "loop_side":
			target = LOOP.ring_center(world, data)
			eye = target + basis.x * signf(float(data.lane)) * radius * 3.6 + basis.z * radius * 0.7 + Vector3.UP * 3.2
		elif view == "loop_exit":
			eye = LOOP.point(world, data, 0.84) + Vector3.UP * 5.0 + world.frame(LOOP.road_distance_at(data, 0.84)).z * 13.0
			target = world.position_at(start + LOOP.advance_of(data) + 12.0, LOOP.exit_lane(data)) + Vector3.UP * 1.4
		else:
			return false
	elif view == "precision_braking":
		var zone: Dictionary = SPEED_ZONE.of(world)
		if zone.is_empty():
			return false
		var at: float = float(zone.safe_at) - 55.0
		eye = world.position_at(at - 24.0, -1.8) + Vector3.UP * 3.7
		target = world.position_at(at + 28.0) + Vector3.UP * 2.8
	elif view == "landscape":
		var sites: Array = report.get("sites", [])
		if sites.is_empty():
			return false
		var site: Dictionary = sites[mini(2, sites.size() - 1)]
		var d: float = float(site.distance)
		eye = world.position_at(d - 22.0, 0.0) + Vector3.UP * 7.0
		target = site.position + Vector3.UP * 6.0
	elif view == "course":
		var actions: Array = report.get("actions", [])
		if actions.is_empty():
			return false
		var entry: Dictionary = actions[0]
		for candidate in actions:
			if candidate.kind == "crest":
				entry = candidate
				break
		var d: float = float(entry.start)
		eye = world.position_at(d - 28.0, -1.6) + Vector3.UP * 4.5
		target = world.position_at(d + 23.0) + Vector3.UP * 2.0
	else:
		return false
	camera.position = eye
	camera.look_at(target, Vector3.UP)
	camera.fov = 64.0 if view == "loop_side" else 72.0
	captures.append({"track": track, "view": view, "eye": [eye.x, eye.y, eye.z],
		"target": [target.x, target.y, target.z], "fov": camera.fov})
	return true


func _run() -> void:
	if DisplayServer.get_name() == "headless" or not track in TRACKS.IDS:
		printerr("[KartCapture] A real GL/Vulkan display and a production track are required")
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.msaa_3d = Viewport.MSAA_2X
	world = WORLD.new()
	root.add_child(world)
	world.build(false, track, false)
	camera = Camera3D.new()
	camera.near = 0.15
	camera.far = 1600.0
	root.add_child(camera)
	camera.make_current()
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		printerr("[KartCapture] Cannot create output directory")
		quit(1)
		return
	for view in views:
		if not _camera_for(view):
			printerr("[KartCapture] Cannot compose ", track, "/", view)
			quit(1)
			return
		for i in range(10):
			await process_frame
		if track in ["zauberwald", "galaxy_ringway"]:
			_diagnose_view(view)
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		if image.is_empty() or image.get_width() != 1280 or image.get_height() != 720:
			printerr("[KartCapture] Invalid viewport image")
			quit(1)
			return
		var filename: String = track + "-" + view + ".png"
		if image.save_png(output.path_join(filename)) != OK:
			quit(1)
			return
		captures[captures.size() - 1]["file"] = filename
		print("[KART_CAPTURE] ", filename)
	var report: Dictionary = {"track": track, "renderer": RenderingServer.get_current_rendering_method(),
		"engine": Engine.get_version_info().string, "captures": captures,
		"source_commit": OS.get_environment("LUMO_PRODUCT_SHA"), "width": 1280, "height": 720}
	var file := FileAccess.open(output.path_join(track + "-capture.json"), FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("[KartCapture] PASS ", track, " views=", captures.size())
	quit(0)



## Read-only picking against actual production meshes, without collision proxies.
## The capture and normal chase sightline are logged together to identify a real
## decorative obstruction instead of hiding it by moving the screenshot camera.
func _segment_hits_box(box: AABB, from: Vector3, to: Vector3) -> bool:
	var direction: Vector3 = to - from
	var begin: float = 0.0
	var end: float = 1.0
	for axis in range(3):
		if absf(direction[axis]) < 0.0000001:
			if from[axis] < box.position[axis] or from[axis] > box.end[axis]:
				return false
			continue
		var low: float = (box.position[axis] - from[axis]) / direction[axis]
		var high: float = (box.end[axis] - from[axis]) / direction[axis]
		begin = maxf(begin, minf(low, high))
		end = minf(end, maxf(low, high))
		if begin > end:
			return false
	return true


func _triangle_hit(from: Vector3, direction: Vector3, a: Vector3, b: Vector3, c: Vector3) -> float:
	var edge_b: Vector3 = b - a
	var edge_c: Vector3 = c - a
	var p: Vector3 = direction.cross(edge_c)
	var determinant: float = edge_b.dot(p)
	if absf(determinant) < 0.00000001:
		return INF
	var inverse: float = 1.0 / determinant
	var offset: Vector3 = from - a
	var u: float = offset.dot(p) * inverse
	if u < 0.0 or u > 1.0:
		return INF
	var q: Vector3 = offset.cross(edge_b)
	var v: float = direction.dot(q) * inverse
	if v < 0.0 or u + v > 1.0:
		return INF
	var along: float = edge_c.dot(q) * inverse
	return along if along >= 0.0 and along <= 1.0 else INF


func _instance_hit(node: Node3D, mesh: Mesh, transform: Transform3D, index: int,
		from: Vector3, to: Vector3, faces_cache: Dictionary, hits: Array, tint: Color = Color.WHITE) -> void:
	if mesh == null:
		return
	var inverse: Transform3D = transform.affine_inverse()
	var local_from: Vector3 = inverse * from
	var local_to: Vector3 = inverse * to
	if not _segment_hits_box(mesh.get_aabb(), local_from, local_to):
		return
	var key: int = mesh.get_instance_id()
	if not faces_cache.has(key):
		faces_cache[key] = mesh.get_faces()
	var vertices: PackedVector3Array = faces_cache[key]
	var closest: float = INF
	for i in range(0, vertices.size(), 3):
		closest = minf(closest, _triangle_hit(local_from, local_to - local_from, vertices[i], vertices[i + 1], vertices[i + 2]))
	if not is_finite(closest):
		return
	hits.append({"node": str(node.get_path()), "instance": index, "distance": closest * from.distance_to(to),
		"at": [transform.origin.x, transform.origin.y, transform.origin.z],
		"scale": [transform.basis.x.length(), transform.basis.y.length(), transform.basis.z.length()],
		"tint": [tint.r, tint.g, tint.b], "mesh": mesh.resource_path})


func _mesh_hits(node: Node, from: Vector3, to: Vector3, cache: Dictionary, hits: Array) -> void:
	if node is MeshInstance3D and node.visible:
		_instance_hit(node, node.mesh, node.global_transform, -1, from, to, cache, hits)
	elif node is MultiMeshInstance3D and node.visible and node.multimesh != null:
		var mm: MultiMesh = node.multimesh
		for i in range(mm.instance_count):
			_instance_hit(node, mm.mesh, node.global_transform * mm.get_instance_transform(i), i,
				from, to, cache, hits, mm.get_instance_color(i) if mm.use_colors else Color.WHITE)
	for child in node.get_children():
		_mesh_hits(child, from, to, cache, hits)


func _sight_hits(from: Vector3, to: Vector3) -> Array:
	var hits: Array = []
	_mesh_hits(world, from, to, {}, hits)
	hits.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.distance) < float(b.distance))
	return hits.slice(0, 8)


func _diagnose_view(view: String) -> void:
	var entry: Dictionary = captures[captures.size() - 1]
	var target: Vector3 = Vector3(entry.target[0], entry.target[1], entry.target[2])
	var road: Dictionary = world.sample_road(camera.position, 0.0)
	var d: float = float(road.distance)
	var chase_eye: Vector3 = world.position_at(d - 8.0) + Vector3.UP * 3.5
	var chase_target: Vector3 = world.position_at(d + 18.0) + Vector3.UP * 1.2
	var screen_rays: Array = []
	for uv in [Vector2(0.5, 0.8), Vector2(0.75, 0.55), Vector2(0.25, 0.55)]:
		var pixel: Vector2 = uv * Vector2(root.size)
		var origin: Vector3 = camera.project_ray_origin(pixel)
		var direction: Vector3 = camera.project_ray_normal(pixel)
		screen_rays.append({"uv": [uv.x, uv.y], "hits": _sight_hits(origin, origin + direction * 160.0)})
	var info: Dictionary = {"track": track, "view": view, "road_distance": d,
		"capture": _sight_hits(camera.position, target), "chase_reference": _sight_hits(chase_eye, chase_target),
		"screen_rays": screen_rays}
	if track == "zauberwald":
		info["eye_above_terrain"] = camera.position.y - world._ground_height(camera.position.x, camera.position.z)
	entry["mesh_diagnostics"] = info
	print("[KartMeshSight] ", JSON.stringify(info))
	if track == "galaxy_ringway" and view == views[0]:
		for child in world.get_children():
			if child is MultiMeshInstance3D and str(child.name).begins_with("Decor_torus"):
				var mm: MultiMesh = child.multimesh
				if mm.instance_count > 0:
					var first: Transform3D = mm.get_instance_transform(0)
					var tint: Color = mm.get_instance_color(0)
					print("[KartPlanetMesh] ", JSON.stringify({"node": str(child.name), "count": mm.instance_count,
						"size": [first.basis.x.length(), first.basis.y.length(), first.basis.z.length()],
						"tint": [tint.r, tint.g, tint.b]}))
