extends RefCounted
## Imported, artist-authored meshes retain their UVs and per-surface materials.
## Instances are flattened once per size, never while animating a lesson.
const ROOT := "res://assets/lumo_next/learning/"
static var _meshes: Dictionary = {}
static var _failed: Dictionary = {}


static func make(asset: String, dimensions: Vector3, source_dimensions: Vector3) -> ArrayMesh:
	var key := asset + str(dimensions)
	if _meshes.has(key):
		return _meshes[key]
	if _failed.has(key):
		return null
	var path := ROOT + asset + ".glb"
	if not ResourceLoader.exists(path, "PackedScene"):
		_failed[key] = true
		push_warning("[LumoLearningAssets] Imported asset unavailable: " + path)
		return null
	var packed := load(path) as PackedScene
	if packed == null:
		_failed[key] = true
		return null
	var source := packed.instantiate() as Node3D
	if source == null:
		_failed[key] = true
		return null
	var scale_value := dimensions / source_dimensions
	var offset := Transform3D(Basis.from_scale(scale_value), Vector3(0.0, -dimensions.y * 0.5, 0.0))
	var result := ArrayMesh.new()
	var surfaces: Dictionary = {}
	_collect(source, offset, surfaces)
	for material: Variant in surfaces:
		var builder: SurfaceTool = surfaces[material]
		builder.commit(result)
		result.surface_set_material(result.get_surface_count() - 1, material)
	source.free()
	if result.get_surface_count() == 0:
		_failed[key] = true
		return null
	_meshes[key] = result
	return result


static func _collect(node: Node3D, parent_transform: Transform3D, surfaces: Dictionary) -> void:
	var transform_value := parent_transform * node.transform
	if node is MeshInstance3D and node.mesh != null:
		for surface in range(node.mesh.get_surface_count()):
			if node.mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
				continue
			var material: Material = node.get_active_material(surface)
			if not surfaces.has(material):
				var created := SurfaceTool.new()
				created.begin(Mesh.PRIMITIVE_TRIANGLES)
				surfaces[material] = created
			var builder: SurfaceTool = surfaces[material]
			builder.append_from(node.mesh, surface, transform_value)
	for child in node.get_children():
		if child is Node3D:
			_collect(child, transform_value, surfaces)
