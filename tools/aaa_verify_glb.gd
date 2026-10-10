extends SceneTree
## Reimport the Blender roundtrip in the actual target engine.
var folder := "res://exports/aaa-production"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			folder = arg.trim_prefix("--output=")
	call_deferred("_run")


func _count(node: Node) -> Vector2i:
	var inventory := Vector2i.ZERO
	if node is MeshInstance3D:
		inventory.x = 1
		for index in range(node.mesh.get_surface_count()):
			var arrays: Array = node.mesh.surface_get_arrays(index)
			var indices = arrays[Mesh.ARRAY_INDEX]
			inventory.y += (indices.size() if indices != null and not indices.is_empty()
				else arrays[Mesh.ARRAY_VERTEX].size()) / 3
			assert(node.get_active_material(index) != null, "No lost materials in roundtrip")
	for child in node.get_children():
		inventory += _count(child)
	return inventory


func _run() -> void:
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("asset-manifest.json")))
	assert(manifest is Dictionary and manifest.mesh_nodes > 0)
	assert(FileAccess.get_sha256(folder.path_join(manifest.asset)) == manifest.sha256,
		"The original GLB changed after its inventory was recorded")
	var blender = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("blender-import-report.json")))
	assert(blender is Dictionary and blender.source_glb_sha256 == manifest.sha256)
	var roundtrip_path := folder.path_join("lumo-comet-blender-roundtrip.glb")
	assert(FileAccess.get_sha256(roundtrip_path) == blender.roundtrip_glb_sha256,
		"The Blender output changed after its report was recorded")
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	assert(doc.append_from_file(roundtrip_path, state) == OK)
	var model: Node = doc.generate_scene(state)
	assert(model != null)
	var inventory := _count(model)
	assert(inventory.x == int(manifest.mesh_nodes), "Mesh count changed in Blender roundtrip")
	assert(inventory.y == int(manifest.triangles), "Geometry changed in Blender roundtrip")
	var report := FileAccess.open(folder.path_join("roundtrip-verification.json"), FileAccess.WRITE)
	assert(report != null)
	report.store_string(JSON.stringify({
		"status": "PASS",
		"godot": Engine.get_version_info().string,
		"mesh_nodes": inventory.x,
		"triangles": inventory.y,
		"all_surfaces_have_materials": true,
		"geometry_count_preserved": true,
		"source_commit": manifest.source_commit,
		"original_glb_sha256": manifest.sha256,
		"roundtrip_glb_sha256": blender.roundtrip_glb_sha256,
		"material_fidelity_approved": false,
		"runtime_replacement": false,
	}, "  "))
	report.close()
	model.free()
	print("[AAAGlbRoundtrip] PASS: Godot to Blender to Godot; meshes=", inventory.x,
		" triangles=", inventory.y, "; materials retained")
	quit(0)
