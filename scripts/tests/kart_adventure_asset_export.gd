extends SceneTree
## Export actual visible product geometry for editable Blender review.
## Karts are static snapshots; the runtime remains the animation authority.
## Tunnel exports require an actual renderer: headless MultiMesh readback is empty.

const VEHICLE = preload("res://scripts/games/kart_vehicle.gd")
const WORLD = preload("res://scripts/games/kart_world.gd")
const TRACKS = preload("res://scripts/games/kart_tracks.gd")
const TUNNELS = preload("res://scripts/games/kart_adventure_tunnels.gd")
const EXPANSION = preload("res://scripts/games/kart_expansion_world.gd")
const SKY_ISLANDS = preload("res://scripts/games/kart_sky_islands.gd")
const SYMBOLS = preload("res://scripts/games/kart_item_symbols.gd")
const RESONANCE = preload("res://scripts/games/kart_resonance_system.gd")

var output := "res://exports/kart-adventure"
var mode := "all"
var track_id := "crystal_canyon"
var records: Array[Dictionary] = []
var translated_materials: Dictionary = {}
var tinted_portable_materials: Dictionary = {}
var linear_vertex_materials: Dictionary = {}
var linear_vertex_meshes: Dictionary = {}


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
	if mode in ["all", "tunnel"] and DisplayServer.get_name() == "headless":
		push_error("Tunnel export needs an actual renderer for MultiMesh transforms/colors. Use tools/run_local_renderer.py with --rendering-method gl_compatibility; omit --headless.")
		quit(2)
		return
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
		"res://scripts/games/kart_adventure_tunnels.gd",
		"res://scripts/games/kart_tracks.gd",
		"res://scripts/games/kart_adventure_routes.gd",
		"res://scripts/games/kart_premium_rail_kit.gd",
		"res://scripts/games/kart_item_symbols.gd",
		"res://scripts/games/kart_resonance_system.gd",
		"res://scripts/tests/kart_adventure_asset_export.gd",
	]:
		sources[path] = FileAccess.get_sha256(path)
	var manifest := FileAccess.open(output.path_join("manifest-" + mode + ".json"), FileAccess.WRITE)
	assert(manifest != null)
	manifest.store_string(JSON.stringify({
		"schema": 1, "engine": Engine.get_version_info().string,
		"source": "actual LUMO Kart runtime geometry",
		"source_hashes": sources, "models": records,
		"material_translations": translated_materials,
		"vertex_color_export": "sRGB-flagged vertex RGB converted once to linear glTF COLOR_0; alpha preserved",
		"animation": "static snapshots; gameplay animation is implemented in Godot",
		"device_performance_test": false,
	}, "  "))
	manifest.close()
	await process_frame
	print("[KartAdventureExport] PASS: verified ", records.size(), " GLB exports, mode=", mode)
	quit(0)


func _export_tunnel() -> void:
	# Use exactly the bounded production pipeline of the accepted tunnel showcase.
	# Full outdoor landmarks are not needed for a road-and-passage asset.
	var world = WORLD.new()
	root.add_child(world)
	world.low_detail = false
	world._only_geometry = true
	world.track_id = track_id
	world.definition = TRACKS.definition(track_id)
	world.track_name = str(world.definition.name)
	world._rng.seed = int(world.definition.seed)
	world._make_curve()
	if track_id == "bergwelt":
		world.jump = SKY_ISLANDS.jump_layout(world.length)
	elif track_id in TRACKS.EXPANSION.IDS:
		EXPANSION.prepare(world)
	world._road()
	assert(world.road != null)
	var layout: Dictionary = world.adventure_tunnel
	assert(not layout.is_empty())
	var trim := _retain_nearby_road_instances(world, float(layout.start) - 55.0, float(layout.end) + 35.0)
	world._flush_instances()
	TUNNELS.build(world)
	for _frame in range(3):
		await process_frame
	var tunnel: Node3D = world.get_node_or_null("AdventureTunnel")
	assert(tunnel != null, "Selected route must have an actual AdventureTunnel")
	var readback := _verify_tunnel_instances(world, tunnel, int(trim.production_instances_retained))
	var origin: Vector3 = world.position_at(float(layout.start))
	var model := Node3D.new()
	model.name = "Lumo_" + track_id + "_AdventureTunnel"
	var shell := Node3D.new()
	shell.name = "AdventureTunnel"
	shell.transform = tunnel.transform
	model.add_child(shell)
	_copy_visible(tunnel, shell)
	# _road() is the only mesh producer on this parent. Copy all its ribbons,
	# including both shoulders when Godot has renamed duplicate node names.
	for child in world.get_children():
		if child is MeshInstance3D:
			var road_copy := _copy_mesh(child)
			road_copy.transform = child.transform
			model.add_child(road_copy)
	# These batches were cropped using their authoritative CPU transforms before
	# flushing. The real renderer now provides valid MultiMesh transform/color data.
	for node in world.find_children("*", "MultiMeshInstance3D", true, false):
		if tunnel.is_ancestor_of(node):
			continue
		var multi: MultiMesh = node.multimesh
		if multi == null or multi.mesh == null:
			continue
		for index in range(multi.instance_count):
			var transform: Transform3D = node.global_transform * multi.get_instance_transform(index)
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
	var camera_distance: float = float(layout.start) - 27.0
	var target_distance: float = float(layout.start) + 13.0
	var camera_basis: Basis = world.frame(camera_distance)
	var target_basis: Basis = world.frame(target_distance)
	var review_light_points: Array[Dictionary] = []
	for offset in [15.0, 40.0, 70.0, 110.0, 160.0]:
		var distance: float = minf(float(layout.start) + offset, float(layout.end) - 5.0)
		var point: Vector3 = world.position_at(distance) - origin
		var up: Vector3 = world.frame(distance).y
		review_light_points.append({"route_distance_m": distance,
			"position": _vector(point + up * 6.0), "target": _vector(point + up * 1.5)})
	_write_verified(model, "tunnel-" + track_id, {
		"kind": "runtime_tunnel_and_nearby_road_snapshot", "track": track_id,
		"layout": layout, "world_origin": _vector(origin),
		"entry_forward": _vector(-entry_basis.z), "entry_up": _vector(entry_basis.y),
		"camera": _vector(world.position_at(camera_distance, -0.65) - origin + camera_basis.y * 4.0),
		"target": _vector(world.position_at(target_distance) - origin + target_basis.y * 3.8),
		"camera_up": _vector(camera_basis.y), "vertical_fov_degrees": 60.0,
		"camera_route_distance_m": camera_distance, "target_route_distance_m": target_distance,
		"review_light_points": review_light_points,
		"review_lighting_scope": "Studio metadata only; no runtime lights added",
		"road_trim": trim, "multimesh_readback": readback,
		"runtime_multimesh_materials": _runtime_multimesh_materials(tunnel),
		"full_world_built": false, "renderer_display": DisplayServer.get_name(),
	})
	model.free()
	world.free()


func _retain_nearby_road_instances(world, start: float, finish: float) -> Dictionary:
	# Match kart_adventure_tunnel_showcase.gd: select unmodified production data
	# by route distance and height, not by renderer readback or a world-space ball.
	var original := 0
	var retained := 0
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
		"scope": "Unmodified production road transforms/colors cropped as in the tunnel showcase",
	}


func _verify_tunnel_instances(world, tunnel: Node3D, expected_road: int) -> Dictionary:
	var theme_instances := 0
	var road_instances := 0
	for node in world.find_children("*", "MultiMeshInstance3D", true, false):
		var multi: MultiMesh = node.multimesh
		assert(multi != null and multi.mesh != null)
		for index in range(multi.instance_count):
			var transform: Transform3D = multi.get_instance_transform(index)
			assert(not transform.is_equal_approx(Transform3D.IDENTITY), "Renderer lost an authored MultiMesh transform: " + str(node.name))
			assert(transform.origin.is_finite() and absf(transform.basis.determinant()) > 0.00000001)
			if multi.use_colors:
				var color: Color = multi.get_instance_color(index)
				assert(color.r > 0.0 or color.g > 0.0 or color.b > 0.0, "Renderer lost an authored road-instance color")
		if tunnel.is_ancestor_of(node):
			theme_instances += multi.instance_count
		else:
			road_instances += multi.instance_count
	var metrics: Dictionary = tunnel.get_meta("adventure_tunnel")
	assert(theme_instances == int(metrics.detail_instances) and theme_instances > 0)
	assert(road_instances == expected_road and road_instances > 0)
	return {"theme_instances": theme_instances, "road_instances": road_instances,
		"all_authored_transforms_nonidentity": true, "all_road_colors_nonzero": true}


func _copy_visible(source: Node3D, target: Node3D) -> void:
	for child in source.get_children():
		if not child is Node3D or not child.visible:
			continue
		var copy: Node3D
		if child is MeshInstance3D:
			assert(child.skin == null, "Skinned actors need their own rig-preserving exporter")
			copy = _copy_mesh(child)
		elif child is MultiMeshInstance3D:
			copy = _copy_multimesh(child)
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


func _copy_multimesh(source: MultiMeshInstance3D) -> MultiMeshInstance3D:
	var node := MultiMeshInstance3D.new()
	var original: MultiMesh = source.multimesh
	assert(original != null and original.mesh != null)
	var data: MultiMesh = original.duplicate()
	assert(data != original)
	if source.material_override != null:
		# Godot's glTF MultiMesh path does not serialize the node override.
		# Bake that same material onto an export-owned mesh, never the runtime mesh.
		var mesh: Mesh = original.mesh.duplicate()
		assert(mesh != original.mesh)
		var original_materials: Array[Material] = []
		for surface in range(original.mesh.get_surface_count()):
			original_materials.append(original.mesh.surface_get_material(surface))
		var material: Material = _portable_material(source.material_override)
		if mesh is PrimitiveMesh:
			assert(mesh.get_surface_count() == 1)
			mesh.material = material
		else:
			assert(mesh is ArrayMesh, "Unsupported MultiMesh mesh resource")
			for surface in range(mesh.get_surface_count()):
				mesh.surface_set_material(surface, material)
		for surface in range(original_materials.size()):
			assert(original.mesh.surface_get_material(surface) == original_materials[surface])
		data.mesh = mesh
	assert(data.instance_count == original.instance_count)
	assert(data.visible_instance_count == original.visible_instance_count)
	assert(data.use_colors == original.use_colors and data.use_custom_data == original.use_custom_data)
	for index in range(original.instance_count):
		assert(data.get_instance_transform(index) == original.get_instance_transform(index), "MultiMesh copy changed an instance transform")
		if original.use_colors:
			assert(data.get_instance_color(index) == original.get_instance_color(index))
		if original.use_custom_data:
			assert(data.get_instance_custom_data(index) == original.get_instance_custom_data(index))
	node.multimesh = data
	return node


func _runtime_multimesh_materials(parent: Node3D) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for node in parent.find_children("*", "MultiMeshInstance3D", true, false):
		assert(node.material_override is StandardMaterial3D)
		var material: StandardMaterial3D = node.material_override
		var albedo: Color = material.albedo_color.srgb_to_linear()
		var emission: Color = material.emission.srgb_to_linear() if material.emission_enabled else Color.BLACK
		result.append({"node": str(node.name), "instances": node.multimesh.instance_count,
			"source_albedo_srgb": [material.albedo_color.r, material.albedo_color.g, material.albedo_color.b, material.albedo_color.a],
			"base_color_linear": [albedo.r, albedo.g, albedo.b, material.albedo_color.a],
			"roughness": material.roughness, "metallic": material.metallic,
			"emission_linear": [emission.r, emission.g, emission.b],
			"emission_strength": material.emission_energy_multiplier if material.emission_enabled else 1.0,
			"unlit": material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED,
			"copy_transforms_exact": true, "runtime_mesh_materials_unmodified": true})
	return result


func _portable_material(source: Material, tint: Color = Color.WHITE) -> Material:
	if source is StandardMaterial3D:
		if tint == Color.WHITE:
			return source
		# Keep the source Resource as the key, and all RGBA components exactly.
		# Shared instance colours must not create thousands of duplicate materials.
		if not tinted_portable_materials.has(source):
			tinted_portable_materials[source] = {}
		var variants: Dictionary = tinted_portable_materials[source]
		var tint_key := Vector4(tint.r, tint.g, tint.b, tint.a)
		if variants.has(tint_key):
			return variants[tint_key]
		var copy: StandardMaterial3D = source.duplicate()
		copy.albedo_color *= tint
		variants[tint_key] = copy
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
	var converted_surfaces: int = _linearize_export_vertex_colors(state)
	assert(document.write_to_filesystem(state, path) == OK, path)
	var emission_report: Dictionary = _correct_serialized_emission(path, state)
	if metadata.has("runtime_multimesh_materials"):
		metadata["multimesh_materials_verified"] = _verify_multimesh_materials(path, metadata.runtime_multimesh_materials)
	var importer := GLTFDocument.new()
	var imported := GLTFState.new()
	assert(importer.append_from_file(path, imported) == OK, path)
	var instance := importer.generate_scene(imported)
	assert(instance != null)
	var meshes := instance.find_children("*", "MeshInstance3D", true, false).size()
	assert(meshes > 0, "Export must re-import actual geometry")
	instance.free()
	metadata.merge({"file": filename + ".glb", "sha256": FileAccess.get_sha256(path), "mesh_nodes": meshes,
		"srgb_vertex_surfaces_converted": converted_surfaces, "emission_export": emission_report})
	records.append(metadata)
	print("[KartAdventureExport] ", filename, " meshes=", meshes)


func _verify_multimesh_materials(path: String, expected: Array[Dictionary]) -> int:
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var json_length: int = bytes.decode_u32(12)
	var document: Dictionary = JSON.parse_string(bytes.slice(20, 20 + json_length).get_string_from_utf8())
	var checked := 0
	for group: Dictionary in expected:
		var instances := 0
		for node: Dictionary in document.nodes:
			if not node.has("mesh") or not str(node.get("name", "")).begins_with(str(group.node)):
				continue
			instances += 1
			for primitive: Dictionary in document.meshes[int(node.mesh)].primitives:
				assert(primitive.has("material"), "glTF lost the runtime MultiMesh material: " + str(group.node))
				var material: Dictionary = document.materials[int(primitive.material)]
				var pbr: Dictionary = material.get("pbrMetallicRoughness", {})
				_assert_material_values(pbr.get("baseColorFactor", [1.0, 1.0, 1.0, 1.0]), group.base_color_linear)
				_assert_material_values([pbr.get("roughnessFactor", 1.0), pbr.get("metallicFactor", 1.0)], [group.roughness, group.metallic])
				_assert_material_values(material.get("emissiveFactor", [0.0, 0.0, 0.0]), group.emission_linear)
				var extensions: Dictionary = material.get("extensions", {})
				assert(extensions.has("KHR_materials_unlit") == bool(group.unlit))
				var strength: Dictionary = extensions.get("KHR_materials_emissive_strength", {})
				_assert_material_values([strength.get("emissiveStrength", 1.0)], [group.emission_strength])
		assert(instances == int(group.instances), "glTF changed a runtime MultiMesh instance count")
		checked += instances
	return checked


func _assert_material_values(actual: Array, expected: Array) -> void:
	assert(actual.size() == expected.size())
	for index in range(actual.size()):
		assert(absf(float(actual[index]) - float(expected[index])) <= 0.000001, "glTF material differs from the runtime material")


func _linearize_export_vertex_colors(state: GLTFState) -> int:
	# Godot's runtime shader decodes sRGB vertex colours when this flag is set.
	# glTF COLOR_0 is linear. Convert only the exporter-owned ImporterMesh arrays:
	# this also avoids quantizing linear colours through an 8-bit ArrayMesh again.
	# Scene/runtime mesh buffers, material flags, geometry and alpha stay untouched.
	# GLTFState.materials is populated only during serialization. At this stage
	# each ImporterMesh surface carries the actual active instance material.
	var converted_surfaces := 0
	for entry: GLTFMesh in state.get_meshes():
		var source: ImporterMesh = entry.get_mesh()
		if source == null:
			continue
		var overrides: Array[Material] = entry.get_instance_materials()
		var active_materials: Array[Material] = []
		var key: String = str(source.get_instance_id())
		for surface in range(source.get_surface_count()):
			var active: Material = source.get_surface_material(surface)
			if surface < overrides.size() and overrides[surface] != null:
				active = overrides[surface]
			active_materials.append(active)
			key += ":" + str(active.get_instance_id() if active != null else 0)
		if linear_vertex_meshes.has(key):
			var cached: Dictionary = linear_vertex_meshes[key]
			entry.set_mesh(cached.mesh)
			entry.set_instance_materials(cached.materials)
			converted_surfaces += int(cached.surfaces)
			continue
		var copy := ImporterMesh.new()
		copy.set_blend_shape_mode(source.get_blend_shape_mode())
		for shape in range(source.get_blend_shape_count()):
			copy.add_blend_shape(source.get_blend_shape_name(shape))
		var count := 0
		var portable_materials: Array[Material] = []
		for surface in range(source.get_surface_count()):
			var arrays: Array = source.get_surface_arrays(surface)
			var material: Material = active_materials[surface]
			if material is StandardMaterial3D and material.vertex_color_use_as_albedo and material.vertex_color_is_srgb:
				var material_key: int = material.get_instance_id()
				if not linear_vertex_materials.has(material_key):
					var portable: StandardMaterial3D = material.duplicate()
					portable.vertex_color_is_srgb = false
					linear_vertex_materials[material_key] = portable
				material = linear_vertex_materials[material_key]
				if arrays[Mesh.ARRAY_COLOR] != null:
					var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR].duplicate()
					for vertex in range(colors.size()):
						var original: Color = colors[vertex]
						colors[vertex] = original.srgb_to_linear()
						colors[vertex].a = original.a
					arrays[Mesh.ARRAY_COLOR] = colors
					count += 1
			portable_materials.append(material)
			var shapes: Array[Array] = []
			for shape in range(source.get_blend_shape_count()):
				shapes.append(source.get_surface_blend_shape_arrays(surface, shape))
			var lods: Dictionary = {}
			for lod in range(source.get_surface_lod_count(surface)):
				lods[source.get_surface_lod_size(surface, lod)] = source.get_surface_lod_indices(surface, lod)
			copy.add_surface(source.get_surface_primitive_type(surface), arrays, shapes, lods,
				material, source.get_surface_name(surface), source.get_surface_format(surface))
		linear_vertex_meshes[key] = {"mesh": copy, "materials": portable_materials, "surfaces": count}
		entry.set_mesh(copy)
		entry.set_instance_materials(portable_materials)
		converted_surfaces += count
	return converted_surfaces


func _correct_serialized_emission(path: String, state: GLTFState) -> Dictionary:
	# Godot 4.6.3 serializes emission with linear_to_srgb(), while the authored
	# palette uses sRGB colours. Write glTF's linear factors from those exact
	# source colours. Keep emission strength and every binary byte unchanged.
	var original: PackedByteArray = FileAccess.get_file_as_bytes(path)
	assert(original.size() >= 20 and original.decode_u32(0) == 0x46546c67)
	assert(original.decode_u32(4) == 2 and original.decode_u32(8) == original.size())
	var json_size: int = original.decode_u32(12)
	assert(original.decode_u32(16) == 0x4e4f534a and json_size % 4 == 0)
	assert(20 + json_size <= original.size())
	var parsed: Variant = JSON.parse_string(original.slice(20, 20 + json_size).get_string_from_utf8())
	assert(parsed is Dictionary)
	var document: Dictionary = parsed
	var serialized: Array = document.get("materials", [])
	var sources: Array[Material] = state.get_materials()
	assert(serialized.size() == sources.size(), "Export material indices must match GLTFState")
	var corrected := 0
	for index in range(sources.size()):
		var source: Material = sources[index]
		if not source is StandardMaterial3D or not source.emission_enabled:
			continue
		var previous: Array = serialized[index].get("emissiveFactor", [0.0, 0.0, 0.0])
		var emitted: Color = source.emission.linear_to_srgb()
		assert(previous.size() == 3 and absf(float(previous[0]) - emitted.r) < 0.00001
			and absf(float(previous[1]) - emitted.g) < 0.00001 and absf(float(previous[2]) - emitted.b) < 0.00001,
			"Serialized material index must match the source emission before correction")
		var color: Color = source.emission.srgb_to_linear()
		assert(is_finite(color.r) and is_finite(color.g) and is_finite(color.b))
		assert(minf(color.r, minf(color.g, color.b)) >= 0.0 and maxf(color.r, maxf(color.g, color.b)) <= 1.0,
			"Authored emission factors must be bounded; brightness uses emission_energy_multiplier")
		serialized[index]["emissiveFactor"] = [color.r, color.g, color.b]
		corrected += 1
	var binary_chunk: PackedByteArray = original.slice(20 + json_size)
	var binary_hash: String = _bytes_sha256(binary_chunk)
	if corrected == 0:
		return {"materials_corrected": 0, "binary_chunk_unchanged": true,
			"binary_sha256_before": binary_hash, "binary_sha256_after": binary_hash}
	var json_bytes: PackedByteArray = JSON.stringify(_native_glb_numbers(document), "", false, true).to_utf8_buffer()
	while json_bytes.size() % 4 != 0:
		json_bytes.append(0x20)
	var header := PackedByteArray()
	header.resize(20)
	header.encode_u32(0, 0x46546c67)
	header.encode_u32(4, 2)
	header.encode_u32(8, 20 + json_bytes.size() + binary_chunk.size())
	header.encode_u32(12, json_bytes.size())
	header.encode_u32(16, 0x4e4f534a)
	var packed: PackedByteArray = header + json_bytes + binary_chunk
	assert(packed.slice(20 + json_bytes.size()) == binary_chunk)
	var temporary: String = path + ".color-tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	assert(file != null)
	file.store_buffer(packed)
	file.close()
	assert(DirAccess.rename_absolute(temporary, path) == OK)
	var verified: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var after_hash: String = _bytes_sha256(verified.slice(20 + verified.decode_u32(12)))
	assert(after_hash == binary_hash)
	return {"materials_corrected": corrected, "binary_chunk_unchanged": true,
		"binary_sha256_before": binary_hash, "binary_sha256_after": after_hash}


func _bytes_sha256(value: PackedByteArray) -> String:
	var context := HashingContext.new()
	assert(context.start(HashingContext.HASH_SHA256) == OK)
	assert(context.update(value) == OK)
	return context.finish().hex_encode()


func _native_glb_numbers(value: Variant) -> Variant:
	# Godot JSON parsing represents every JSON number as a float. Restore
	# integral values so indices remain usable by strict glTF importers.
	if value is Dictionary:
		var result: Dictionary = {}
		for key in value:
			result[key] = _native_glb_numbers(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item in value:
			result.append(_native_glb_numbers(item))
		return result
	if value is float and is_finite(value) and absf(value) <= 9007199254740991.0 and value == floor(value):
		return int(value)
	return value


func _vector(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]
