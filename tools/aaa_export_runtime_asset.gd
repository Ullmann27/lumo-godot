extends SceneTree
## Preserve the real authored model as editable production source.
## The snapshot retains pivot hierarchy but NOT the procedural animation logic.
const VEHICLE = preload("res://scripts/games/kart_vehicle.gd")
const METADATA = preload("res://tools/aaa_capture_metadata.gd")
var triangles := 0
var mesh_count := 0
var material_ids: Dictionary = {}
var output := "res://exports/aaa-production"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
	call_deferred("_run")


func _copy(source: Node3D, destination: Node3D, kart) -> void:
	for child in source.get_children():
		if not child is Node3D:
			continue
		if child is MeshInstance3D and (
			child == kart.far_mesh or kart.flames.has(child)
			or kart.sparks.has(child) or not child.visible
		):
			continue
		var copied: Node3D
		if child is MeshInstance3D:
			var instance := MeshInstance3D.new()
			instance.mesh = child.mesh
			instance.material_override = child.material_override
			for index in range(child.mesh.get_surface_count()):
				var arrays: Array = child.mesh.surface_get_arrays(index)
				var indices = arrays[Mesh.ARRAY_INDEX]
				triangles += (indices.size() if indices != null and not indices.is_empty()
					else arrays[Mesh.ARRAY_VERTEX].size()) / 3
				var material: Material = child.get_active_material(index)
				if material != null:
					material_ids[material.get_instance_id()] = true
				instance.set_surface_override_material(index, child.get_surface_override_material(index))
			mesh_count += 1
			copied = instance
		else:
			copied = Node3D.new()
		copied.name = child.name
		copied.transform = child.transform
		destination.add_child(copied)
		_copy(child, copied, kart)


func _run() -> void:
	seed(1923)
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	var kart = VEHICLE.new()
	kart.configure("fox", Color("76d9ff"), "comet")
	kart.reduced_motion = true
	root.add_child(kart)
	kart.set_process(false)
	await process_frame
	# Let the existing authored noise normal finish without replacing its source.
	if kart.fur_normal != null and kart.fur_normal.get_image() == null:
		await kart.fur_normal.changed
	var model := Node3D.new()
	model.name = "Lumo_Comet_Existing_Runtime_Snapshot"
	_copy(kart, model, kart)
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	assert(document.append_from_scene(model, state) == OK)
	var output_file := output.path_join("lumo-comet-existing.glb")
	assert(document.write_to_filesystem(state, output_file) == OK)
	var check := GLTFDocument.new()
	var imported := GLTFState.new()
	assert(check.append_from_file(output_file, imported) == OK)
	var loaded: Node = check.generate_scene(imported)
	assert(loaded != null)
	var report := FileAccess.open(output.path_join("asset-manifest.json"), FileAccess.WRITE)
	assert(report != null, "Production manifest must be writable")
	var metadata: Dictionary = METADATA.source()
	metadata.merge({
		"asset": "lumo-comet-existing.glb",
		"sha256": FileAccess.get_sha256(output_file),
		"source": "Existing user-owned Godot procedural geometry; no external asset added",
		"geometry_modified": false,
		"triangles": triangles,
		"mesh_nodes": mesh_count,
		"material_resources": material_ids.size(),
		"godot_import_verified": true,
		"pivot_hierarchy": "retained",
		"animation": "static production snapshot; runtime animations remain in GDScript",
		"rigged_production_character": false,
		"runtime_replacement": false,
		"license_note": "Existing repository asset; no new third-party license claimed",
		"mobile_budget": "Measured inventory only; not a frame-time or device-performance approval",
	})
	report.store_string(JSON.stringify(metadata, "  "))
	report.close()
	loaded.free()
	model.free()
	kart.free()
	await process_frame
	print("[AAAProductionExport] PASS: actual GLB exported and reimported; triangles=", triangles,
		" meshes=", mesh_count, " materials=", material_ids.size())
	quit(0)
