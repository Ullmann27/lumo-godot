extends SceneTree
## Bounded static geometry attribution of the actual 8+5 route. Per-node
## surface submissions are a lower-bound inventory, not GPU draw-call timing.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(412, 915)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var game = (load("res://scenes/learning/learning_world.tscn") as PackedScene).instantiate()
	game.capture_options = {
		"learning": {"kind": "bridge_ten", "a": 8, "b": 5}, "reduceAnimations": false
	}
	root.add_child(game)
	for index in range(4):
		await process_frame
	var entries: Array[Dictionary] = []
	var cache := {}
	var totals := {"triangles": 0, "mesh_surface_submissions": 0, "visible_nodes": 0}
	var groups := {}
	for node: Node in game.find_children("*", "GeometryInstance3D", true, false):
		if not node.is_visible_in_tree():
			continue
		var mesh: Mesh
		var instances := 1
		if node is MeshInstance3D:
			mesh = node.mesh
		elif node is MultiMeshInstance3D and node.multimesh != null:
			mesh = node.multimesh.mesh
			instances = node.multimesh.visible_instance_count
			if instances < 0:
				instances = node.multimesh.instance_count
		if mesh == null or instances <= 0:
			continue
		var key := mesh.get_instance_id()
		if not cache.has(key):
			cache[key] = int(mesh.get_faces().size() / 3)
		var triangles: int = cache[key] * instances
		var surfaces := mesh.get_surface_count()
		var group := "environment"
		if game.fox.is_ancestor_of(node):
			group = "lumo"
		elif game.content.is_ancestor_of(node):
			group = "learning_objects"
		if not groups.has(group):
			groups[group] = {"triangles": 0, "mesh_surface_submissions": 0, "visible_nodes": 0}
		for bucket: Dictionary in [totals, groups[group]]:
			bucket.triangles += triangles
			bucket.mesh_surface_submissions += surfaces
			bucket.visible_nodes += 1
		entries.append(
			{
				"node": str(game.get_path_to(node)),
				"group": group,
				"triangles": triangles,
				"triangles_per_instance": cache[key],
				"instances": instances,
				"mesh_surface_submissions": surfaces,
				"mesh_resource": mesh.resource_path
			}
		)
	entries.sort_custom(func(a: Dictionary, b: Dictionary): return a.triangles > b.triangles)
	var top_triangles := entries.slice(0, mini(10, entries.size())).duplicate(true)
	entries.sort_custom(
		func(a: Dictionary, b: Dictionary):
			return a.mesh_surface_submissions > b.mesh_surface_submissions
	)
	print(
		(
			"LUMO_LEARNING_GEOMETRY "
			+ (JSON.stringify(
				{
					"schema": "lumo.learning.geometry",
					"version": 1,
					"kind": "bridge_ten",
					"totals": totals,
					"groups": groups,
					"top_triangles": top_triangles,
					"top_surface_submissions": entries.slice(0, mini(10, entries.size())),
					"limits":
					(
						"Visible tree nodes; no frustum/occlusion/LOD test. "
						+ "Mesh surface submissions exclude shadows, material passes and UI; "
						+ "they are not measured per-node GPU draw calls."
					)
				}
			))
		)
	)
	game.queue_free()
	await process_frame
	quit(0)
