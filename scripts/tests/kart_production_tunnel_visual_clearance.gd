extends SceneTree
## Probe the actual visible warped Blender triangles, separately from physics proxies.
const WORLD = preload("res://scripts/games/kart_world.gd")
const LAYOUT = preload("res://scripts/games/kart_production_tunnel_layout.gd")
const VISUAL_LAYER: int = 1 << 21
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var selected: String = "all"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--track="):
			selected = argument.trim_prefix("--track=")
	var records: Array[Dictionary] = []
	for low_detail in [true, false]:
		for track in LAYOUT.THEMES:
			if selected != "all" and track != selected:
				continue
			var world = WORLD.new()
			root.add_child(world)
			world.build(low_detail, track, true)
			if not is_instance_valid(world.production_tunnels):
				failures += 1
				world.queue_free()
				await process_frame
				continue
			var tunnel = world.production_tunnels
			var layout: Dictionary = world.production_tunnel_layout
			var probe := StaticBody3D.new()
			probe.name = "TestOnlyVisibleTriangleProbe"
			probe.collision_layer = VISUAL_LAYER
			probe.collision_mask = 0
			world.add_child(probe)
			var faces := PackedVector3Array()
			var level: String = "1" if low_detail else "0"
			for module in tunnel.modules:
				for category in ["Core", "Terrain"]:
					_collect_faces(module.get_node(category + "LOD" + level), world.global_transform.affine_inverse(), faces)
			var shape := ConcavePolygonShape3D.new()
			shape.set_faces(faces)
			shape.backface_collision = true
			var collision := CollisionShape3D.new()
			collision.shape = shape
			probe.add_child(collision)
			await physics_frame
			await physics_frame
			var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
			var clearance := BoxShape3D.new()
			# The 15 cm floor offset excludes the structural underside, while
			# retaining the whole 11.8 m reserved width and 4.5 m top boundary.
			clearance.size = Vector3(11.8, 4.35, 0.05)
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = clearance
			query.margin = 0.002
			query.collision_mask = VISUAL_LAYER
			var clear_sections: int = 0
			var blocked: Array[float] = []
			var count: int = ceili(float(layout.length) * 2.0)
			for step in range(count + 1):
				var distance: float = lerpf(float(layout.start), float(layout.end), float(step) / count)
				var frame: Basis = world.frame(distance)
				query.transform = world.global_transform * Transform3D(frame, world.position_at(distance) + frame.y * 2.325)
				if space.intersect_shape(query, 1).is_empty():
					clear_sections += 1
				else:
					blocked.append(distance)
			if not blocked.is_empty():
				failures += 1
				push_error("[ProductionTunnelVisible] " + track + " LOD" + level + " obstructs reserved sections " + str(blocked))
			records.append({"track": track, "level": level, "visible_triangles": faces.size() / 3,
				"width_m": 11.8, "bottom_m": 0.15, "top_m": 4.5, "step_m": 0.5,
				"clear_cross_sections": clear_sections, "obstructed_sections": blocked, "passed": blocked.is_empty()})
			print("[ProductionTunnelVisible] ", track, " LOD", level, " ", "PASS" if blocked.is_empty() else "FAIL", " clear_sections=", clear_sections)
			world.queue_free()
			await process_frame
			await physics_frame
	var directory: String = "res://evidence/lumo_kart_art/tracks/runtime"
	DirAccess.make_dir_recursive_absolute(directory)
	var output := FileAccess.open(directory + "/visible_clearance_" + selected + ".json", FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify({"passed": failures == 0, "failures": failures,
			"method": "Actual warped visible LOD0/LOD1 core and terrain triangles, Godot concave intersection; independent of game collision proxies",
			"records": records}, "  "))
	quit(0 if failures == 0 else 1)


func _collect_faces(node: Node, world_inverse: Transform3D, faces: PackedVector3Array) -> void:
	if node is MeshInstance3D:
		var instance: MeshInstance3D = node as MeshInstance3D
		if instance.mesh != null:
			var transform: Transform3D = world_inverse * instance.global_transform
			for vertex in instance.mesh.get_faces():
				faces.append(transform * vertex)
	for child in node.get_children():
		_collect_faces(child, world_inverse, faces)
