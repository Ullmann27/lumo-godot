extends RefCounted
## Blender-Modelle der Dorfwelt (tools/lumo_village_art/build_village_models.py).
## Alle Modelle teilen EIN Atlasmaterial; geteilte Netze werden schwach
## zwischengespeichert, damit das letzte Gebäude seine Daten freigibt.
const DIR := "res://assets/creative/village3d/models/"
const TEX := "res://assets/creative/village3d/textures/"
const SHADER = preload("res://assets/creative/village3d/shaders/village_building.gdshader")
const FOLIAGE_SHADER = preload("res://assets/creative/village3d/shaders/village_foliage.gdshader")
static var _material_ref: WeakRef
static var _foliage_ref: WeakRef
static var _bundles: Dictionary = {}


class Bundle:
	extends RefCounted
	## {"name": String, "mesh": Mesh, "transform": Transform3D}
	var parts: Array[Dictionary] = []
	var aabb := AABB()
	var material: ShaderMaterial
	var foliage: ShaderMaterial
	var triangles := 0


static func material() -> ShaderMaterial:
	var shared: ShaderMaterial = _material_ref.get_ref() if _material_ref != null else null
	if shared == null:
		shared = ShaderMaterial.new()
		shared.shader = SHADER
		shared.set_shader_parameter("atlas_albedo", load(TEX + "village_atlas_albedo.png"))
		shared.set_shader_parameter("atlas_normal", load(TEX + "village_atlas_normal.png"))
		_material_ref = weakref(shared)
	return shared


## Blattbüschel-Material (Alpha-Karten), geteilt von allen Bäumen und Büschen.
static func foliage_material() -> ShaderMaterial:
	var shared: ShaderMaterial = _foliage_ref.get_ref() if _foliage_ref != null else null
	if shared == null:
		shared = ShaderMaterial.new()
		shared.shader = FOLIAGE_SHADER
		shared.set_shader_parameter("leaf_texture", load(TEX + "leaf_cards.png"))
		_foliage_ref = weakref(shared)
	return shared


static func exists(name: String) -> bool:
	return ResourceLoader.exists(DIR + name + ".glb")


static func bundle(name: String) -> Bundle:
	var entry: Bundle = _bundles[name].get_ref() if _bundles.has(name) else null
	if entry != null:
		return entry
	entry = Bundle.new()
	entry.material = material()
	entry.foliage = foliage_material()
	if exists(name):
		var scene: PackedScene = load(DIR + name + ".glb")
		var source: Node = scene.instantiate() if scene != null else null
		if source != null:
			for node in source.find_children("*", "MeshInstance3D", true, false):
				var mesh_node := node as MeshInstance3D
				if mesh_node.mesh == null:
					continue
				var xform := Transform3D.IDENTITY
				var cursor: Node = mesh_node
				while cursor != source and cursor is Node3D:
					xform = (cursor as Node3D).transform * xform
					cursor = cursor.get_parent()
				# Every surface gets the shared village material by its Blender slot name.
				for surface in range(mesh_node.mesh.get_surface_count()):
					var source_material := mesh_node.mesh.surface_get_material(surface)
					var slot_name := source_material.resource_name if source_material != null else ""
					# Blender writes the atlas as slot 0 and leaf cards as slot 1.
					var leaves := slot_name.contains("foliage") or (slot_name.is_empty() and surface > 0)
					var surface_name: String = ""
					if mesh_node.mesh is ArrayMesh:
						surface_name = (mesh_node.mesh as ArrayMesh).surface_get_name(surface)
					leaves = leaves or surface_name.contains("foliage")
					mesh_node.mesh.surface_set_material(surface, entry.foliage if leaves else entry.material)
				var part := {"name": str(mesh_node.name), "mesh": mesh_node.mesh, "transform": xform}
				entry.parts.append(part)
				var box: AABB = xform * mesh_node.mesh.get_aabb()
				entry.aabb = box if entry.aabb.size == Vector3.ZERO else entry.aabb.merge(box)
				if mesh_node.mesh is ArrayMesh:
					for surface in range(mesh_node.mesh.get_surface_count()):
						entry.triangles += (mesh_node.mesh as ArrayMesh).surface_get_array_index_len(surface) / 3
			source.free()
	_bundles[name] = weakref(entry)
	return entry


## Stand-alone node: root mesh plus named moving parts (Spin_*).
static func instance(name: String, shadows := true) -> Node3D:
	var entry := bundle(name)
	var root := Node3D.new()
	root.name = name
	root.set_meta("village_art_bundle", entry)
	for part in entry.parts:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = str(part.name)
		mesh_instance.mesh = part.mesh
		mesh_instance.transform = part.transform
		if not shadows:
			mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mesh_instance)
	return root


## The main (non-moving) mesh of a model, for MultiMesh batches.
static func main_mesh(name: String) -> Mesh:
	for part in bundle(name).parts:
		if not str(part.name).begins_with("Spin_"):
			return part.mesh
	return null


static func batch(
	parent: Node, label: String, name: String, transforms: Array, range_end := 0.0, shadows := true,
	range_begin := 0.0
) -> MultiMeshInstance3D:
	if transforms.is_empty():
		return null
	var mesh := main_mesh(name)
	if mesh == null:
		return null
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = transforms.size()
	for index in range(transforms.size()):
		multi.set_instance_transform(index, transforms[index])
	# Preserve the authored placements for CPU-side visibility queries. The
	# headless renderer deliberately returns empty MultiMesh draw buffers.
	multi.set_meta("authored_transforms", transforms.duplicate())
	var node := MultiMeshInstance3D.new()
	node.name = label
	node.multimesh = multi
	node.set_meta("village_art_bundle", bundle(name))
	if range_end > 0.0:
		node.visibility_range_end = range_end
		node.visibility_range_end_margin = 12.0
	if range_begin > 0.0:
		node.visibility_range_begin = range_begin
		node.visibility_range_begin_margin = 12.0
	if not shadows:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node
