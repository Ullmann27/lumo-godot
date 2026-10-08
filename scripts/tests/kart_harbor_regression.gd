extends SceneTree
## Tests the actual hull vertices, rendered terrain triangles, road footprint and GPU batches.

const WORLD = preload("res://scripts/games/kart_world.gd")
const HARBOR = preload("res://scripts/games/kart_harbor_dressing.gd")
const OUTPUT := "res://exports/harbor-proof"


class HarborProbeWorld:
	extends "res://scripts/games/kart_world.gd"
	var uploaded: Dictionary = {}

	func _flush_instances() -> void:
		uploaded = groups.duplicate(true)
		super._flush_instances()


func _initialize() -> void:
	call_deferred("_run")


func _settle() -> void:
	for _i in range(3):
		await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw


func _terrain_height(world, p: Vector3, vertices: PackedVector3Array) -> float:
	# Query the triangles uploaded to SculptedIslandTerrain, including coastal interpolation.
	var count: int = 48 if world.low_detail else 72
	var x: float = (p.x + 114.0) * float(count) / 228.0
	var z: float = (p.z + 104.0) * float(count) / 208.0
	if x < 0.0 or z < 0.0 or x >= count or z >= count:
		return -INF
	var cell: int = (floori(z) * count + floori(x)) * 6
	var u: float = x - floorf(x)
	var v: float = z - floorf(z)
	if u + v <= 1.0:
		return (
			vertices[cell].y * (1.0 - u - v) + vertices[cell + 1].y * u + vertices[cell + 2].y * v
		)
	return (
		vertices[cell + 3].y * (1.0 - v)
		+ vertices[cell + 4].y * (u + v - 1.0)
		+ vertices[cell + 5].y * (1.0 - u)
	)


func _assert_hulls(world, expected: int) -> bool:
	var boats: Array = world.get_meta("harbor_boats")
	assert(boats.size() == expected, "Marina must include actual vessels at both detail levels")
	var sailing: int = 0
	var terrain: ArrayMesh = world.get_node("SculptedIslandTerrain").mesh
	var ground_vertices: PackedVector3Array = terrain.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var hull: Mesh = world._shape("hull")
	var vertices: PackedVector3Array = hull.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for boat in boats:
		var transform: Transform3D = boat.transform
		var found: bool = false
		for key in world.uploaded:
			var group: Dictionary = world.uploaded[key]
			if group.kind != "hull":
				continue
			for i in range(group.transforms.size()):
				var candidate: Transform3D = group.transforms[i]
				if candidate.is_equal_approx(transform):
					found = true
					var node: MultiMeshInstance3D = world.get_node("Decor_" + key)
					assert(node.multimesh.mesh == hull)
					assert(node.multimesh.instance_count == group.transforms.size())
					if DisplayServer.get_name() != "headless":
						assert(node.multimesh.get_instance_transform(i).is_equal_approx(transform))
		assert(found, "Metadata must describe a hull actually uploaded to a GPU batch")
		for vertex in vertices:
			var p: Vector3 = transform * vertex
			assert(
				_terrain_height(world, p, ground_vertices) < HARBOR.WATER_Y - 0.5,
				"Hull must float above sea floor, never island terrain"
			)
			assert(
				not world._near_road(p, HARBOR.ROAD_CLEARANCE),
				"Hull and its bow must remain outside the road"
			)
		assert(transform.origin.y > HARBOR.WATER_Y)
		var keel: Vector3 = transform * Vector3(0, -0.55, 0)
		assert(keel.y < HARBOR.WATER_Y, "A floating boat's keel must be partly submerged")
		if boat.sailing:
			sailing += 1
	assert(sailing == expected / 2, "Half the fleet must have the tall sailboat silhouette")
	assert(world.has_meta("harbor_gangway"), "Marina must connect to its actual shore")
	var gangway: Dictionary = world.get_meta("harbor_gangway")
	assert(world._ground_height(gangway.start.x, gangway.start.z) > -1.25)
	assert(gangway.end.x > gangway.start.x)
	assert(not world._near_road(world.get_meta("harbor_lighthouse"), HARBOR.ROAD_CLEARANCE + 4.5))
	var physical_nodes: int = 0
	for child in world.get_children():
		if child is PhysicsBody3D or child is Area3D:
			physical_nodes += 1
	assert(physical_nodes == 0, "Scenery must preserve the existing mathematical road physics")
	assert(
		world.get_meta("harbor_detail_count") < 750, "Marina retains a bounded mobile detail budget"
	)
	print(
		(
			"[KartHarbor] %d boats, %d added batched details"
			% [expected, world.get_meta("harbor_detail_count")]
		)
	)

	return true


func _capture(world) -> void:
	if DisplayServer.get_name() == "headless" or not OS.get_cmdline_user_args().has("--capture"):
		return
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.current = true
	camera.fov = 56.0
	for view in [
		{"name": "sonnenhafen-marina", "at": Vector3(139, 26, 61), "target": Vector3(110, 1, 3)},
		{"name": "sonnenhafen-dock", "at": Vector3(133, 10, 43), "target": Vector3(113, 0, 22)},
		{"name": "sonnenhafen-road-coast", "at": Vector3(92, 14, 48), "target": Vector3(108, 3, 7)},
	]:
		camera.position = view.at
		camera.look_at(view.target)
		await _settle()
		assert(root.get_texture().get_image().save_png(OUTPUT + "/" + view.name + ".png") == OK)
	camera.queue_free()
	world.queue_free()
	await _settle()


func _run() -> void:
	for lightweight in [true, false]:
		var world = HarborProbeWorld.new()
		root.add_child(world)
		world.build(lightweight, "sonnenhafen", not OS.get_cmdline_user_args().has("--capture"))
		await _settle()
		if not _assert_hulls(world, 4 if lightweight else 8):
			quit(1)
			return
		if not lightweight and OS.get_cmdline_user_args().has("--capture"):
			await _capture(world)
		else:
			world.queue_free()
			await _settle()
	print(
		"[KartHarbor] PASS: floating physical hulls, clear road, connected docks, batches and budgets"
	)
	quit(0)
