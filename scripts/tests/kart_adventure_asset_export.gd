extends SceneTree
## Export actual visible product geometry for editable Blender review.
## Karts are static snapshots; the runtime remains the animation authority.

const VEHICLE = preload("res://scripts/games/kart_vehicle.gd")
const WORLD = preload("res://scripts/games/kart_world.gd")
const SYMBOLS = preload("res://scripts/games/kart_item_symbols.gd")
const RESONANCE = preload("res://scripts/games/kart_resonance_system.gd")

var output := "res://exports/kart-adventure"
var mode := "all"
var track_id := "crystal_canyon"
var records: Array[Dictionary] = []
var translated_materials: Dictionary = {}


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
		elif argument.begins_with("--mode="):
			mode = argument.trim_prefix("--mode=")
		elif argument.begins_with("--track-id="):
			track_id = argument.trim_prefix("--track-id=")
	call_deferred("_run")


func _run() -> void:
	assert(mode in ["all", "vehicles", "items", "tunnel"])
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	if mode in ["all", "vehicles"]:
		for specification in [
			["rabbit", "glider", Color("a696ee")],
			["otter", "gecko_velo", Color("75d7f1")],
			["badger", "terra", Color("83dab9")],
			["cat", "phantom", Color("c8d8ef")],
		]:
			var kart = VEHICLE.new()
			kart.configure(specification[0], specification[2], specification[1])
			kart.reduced_motion = true
			root.add_child(kart)
			kart.set_process(false)
			await process_frame
			if kart.fur_normal != null and kart.fur_normal.get_image() == null:
				await kart.fur_normal.changed
			var model := Node3D.new()
			model.name = "Lumo_" + specification[0] + "_" + specification[1]
			_copy_visible(kart, model)
			_write_verified(model, specification[0] + "-" + specification[1], {
				"driver": specification[0], "kart": specification[1],
				"kind": "runtime_vehicle_static_snapshot",
			})
			model.free()
			kart.free()
	if mode in ["all", "items"]:
		for kind in ["boost", "shield", "pulse"]:
			var symbol: Node3D = SYMBOLS.build(kind)
			_write_verified(symbol, "item-" + kind, {"kind": "runtime_item_symbol", "item": kind})
			symbol.free()
		var holder := Node3D.new()
		var gate: Node3D = RESONANCE.build_ring(holder, Transform3D.IDENTITY)
		_write_verified(gate, "skill-gate", {"kind": "runtime_skill_gate", "award": "driving_skill"})
		holder.free()
	if mode in ["all", "tunnel"]:
		await _export_tunnel()
	var sources := {}
	for path in [
		"res://scripts/games/kart_vehicle.gd",
		"res://scripts/games/kart_world.gd",
		"res://scripts/games/kart_item_symbols.gd",
		"res://scripts/games/kart_resonance_system.gd",
	]:
		sources[path] = FileAccess.get_sha256(path)
	var manifest := FileAccess.open(output.path_join("manifest-" + mode + ".json"), FileAccess.WRITE)
	assert(manifest != null)
	manifest.store_string(JSON.stringify({
		"schema": 1, "engine": Engine.get_version_info().string,
		"source": "actual LUMO Kart runtime geometry",
		"source_hashes": sources, "models": records,
		"material_translations": translated_materials,
		"animation": "static snapshots; gameplay animation is implemented in Godot",
		"device_performance_test": false,
	}, "  "))
	manifest.close()
	await process_frame
	print("[KartAdventureExport] PASS: verified ", records.size(), " GLB exports, mode=", mode)
	quit(0)


func _export_tunnel() -> void:
	var world = WORLD.new()
	root.add_child(world)
	world.build(false, track_id, true)
	await process_frame
	var tunnel: Node3D = world.get_node_or_null("AdventureTunnel")
	assert(tunnel != null, "Selected route must have an actual AdventureTunnel")
	var layout: Dictionary = world.adventure_tunnel
	assert(not layout.is_empty())
	var origin: Vector3 = world.position_at(float(layout.start))
	var model := Node3D.new()
	model.name = "Lumo_" + track_id + "_AdventureTunnel"
	var shell := Node3D.new()
	shell.name = "AdventureTunnel"
	shell.transform = tunnel.transform
	model.add_child(shell)
	_copy_visible(tunnel, shell)
	# Keep original road ribbons, including their exact bank and elevation.
	for child in world.get_children():
		if child is MeshInstance3D and (
			child == world.road or str(child.name).begins_with("RaisedShoulder")
			or str(child.name).begins_with("RoadFoundation")
			or str(child.name).begins_with("EdgePaint")
			or str(child.name).begins_with("CinematicLightEdge")
		):
			var road_copy := _copy_mesh(child)
			road_copy.transform = child.transform
			model.add_child(road_copy)
	# Export existing nearby batched rails and decorations with instance color.
	var centre: Vector3 = world.position_at((float(layout.start) + float(layout.end)) * 0.5)
	var radius: float = (float(layout.end) - float(layout.start)) * 0.65 + 35.0
	for node in world.find_children("*", "MultiMeshInstance3D", true, false):
		if tunnel.is_ancestor_of(node):
			continue
		var multi: MultiMesh = node.multimesh
		if multi == null or multi.mesh == null:
			continue
		for index in range(multi.instance_count):
			var transform: Transform3D = node.global_transform * multi.get_instance_transform(index)
			if transform.origin.distance_to(centre) > radius:
				continue
			var piece := MeshInstance3D.new()
			piece.name = str(node.name) + "_" + str(index)
			piece.mesh = multi.mesh
			piece.transform = transform
			var color := multi.get_instance_color(index) if multi.use_colors else Color.WHITE
			for surface in range(multi.mesh.get_surface_count()):
				var material: Material = node.material_override
				if material == null:
					material = multi.mesh.surface_get_material(surface)
				piece.set_surface_override_material(surface, _portable_material(material, color))
			model.add_child(piece)
	# Centre the Blender asset without changing the relative geometry.
	for child in model.get_children():
		child.position -= origin
	var entry_basis: Basis = world.frame(float(layout.start))
	_write_verified(model, "tunnel-" + track_id, {
		"kind": "runtime_tunnel_and_nearby_road_snapshot", "track": track_id,
		"layout": layout, "world_origin": _vector(origin),
		"entry_forward": _vector(-entry_basis.z), "entry_up": _vector(entry_basis.y),
		"camera": _vector(world.position_at(float(layout.start) - 20.0) - origin + Vector3.UP * 3.2),
		"target": _vector(world.position_at(float(layout.start) + 18.0) - origin + Vector3.UP * 2.5),
	})
	model.free()
	world.free()


func _copy_visible(source: Node3D, target: Node3D) -> void:
	for child in source.get_children():
		if not child is Node3D or not child.visible:
			continue
		var copy: Node3D
		if child is MeshInstance3D:
			assert(child.skin == null, "Skinned actors need their own rig-preserving exporter")
			copy = _copy_mesh(child)
		elif child is MultiMeshInstance3D:
			var batch := MultiMeshInstance3D.new()
			batch.multimesh = child.multimesh
			if child.material_override != null:
				batch.material_override = _portable_material(child.material_override)
			copy = batch
		else:
			copy = Node3D.new()
		copy.name = child.name
		copy.transform = child.transform
		target.add_child(copy)
		_copy_visible(child, copy)


func _copy_mesh(source: MeshInstance3D) -> MeshInstance3D:
	var copy := MeshInstance3D.new()
	copy.name = source.name
	copy.mesh = source.mesh
	for surface in range(source.mesh.get_surface_count()):
		copy.set_surface_override_material(surface, _portable_material(source.get_active_material(surface)))
	return copy


func _portable_material(source: Material, tint: Color = Color.WHITE) -> Material:
	if source is StandardMaterial3D:
		if tint == Color.WHITE:
			return source
		var copy: StandardMaterial3D = source.duplicate()
		copy.albedo_color *= tint
		return copy
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.65
	if source is ShaderMaterial:
		var road_color = source.get_shader_parameter("road_tint")
		if road_color is Color:
			material.albedo_color *= road_color
		var identifier: String = source.shader.resource_path if source.shader != null else "unnamed_shader"
		translated_materials[identifier] = "portable PBR approximation; runtime shader remains in Godot"
	return material


func _write_verified(model: Node3D, filename: String, metadata: Dictionary) -> void:
	var path := output.path_join(filename + ".glb")
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	assert(document.append_from_scene(model, state) == OK, path)
	assert(document.write_to_filesystem(state, path) == OK, path)
	var importer := GLTFDocument.new()
	var imported := GLTFState.new()
	assert(importer.append_from_file(path, imported) == OK, path)
	var instance := importer.generate_scene(imported)
	assert(instance != null)
	var meshes := instance.find_children("*", "MeshInstance3D", true, false).size()
	assert(meshes > 0, "Export must re-import actual geometry")
	instance.free()
	metadata.merge({"file": filename + ".glb", "sha256": FileAccess.get_sha256(path), "mesh_nodes": meshes})
	records.append(metadata)
	print("[KartAdventureExport] ", filename, " meshes=", meshes)


func _vector(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]
