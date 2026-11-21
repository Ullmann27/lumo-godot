extends RefCounted
## Blender-Wahrzeichen von Lumos Riesengarten (tools/garden/build_garden_models.py).
## Jede GLB bringt drei Stufen _lod0/_lod1/_lod2 mit. place() hängt sie als drei
## MeshInstance3D mit Sichtweiten ein (LOW beginnt bei Stufe 1), scatter() baut aus einer
## Stufe ein MultiMesh je Zelle (Gras, Blüten, Pusteblumen: ein Draw-Call je Zelle).
## Blattmaterialien bekommen Rückseitenlicht (Durchscheinen), außer auf LOW.
const DIR: String = "res://assets/kart/riesengarten/models/%s.glb"
const LEAF_WORDS: Array[String] = ["leaf", "petal", "grass", "pad_green", "bloom", "lily", "butterfly"]

static var _meshes: Dictionary = {}


## Die drei Stufen eines Modells als Mesh (mit den Blender-Materialien). Nie leer:
## fehlt die Datei, liefert die Funktion einen Würfel, damit das Rennen nicht abbricht.
static func lods(name: String) -> Array[Mesh]:
	if _meshes.has(name):
		return _meshes[name]
	var result: Array[Mesh] = []
	var path: String = DIR % name
	var packed: PackedScene = load(path) as PackedScene if ResourceLoader.exists(path) else null
	if packed != null:
		var instance: Node = packed.instantiate()
		for level in range(3):
			var node: MeshInstance3D = _find(instance, "%s_lod%d" % [name, level])
			if node != null and node.mesh != null:
				result.append(_with_leaf_light(node.mesh))
		instance.free()
	if result.is_empty():
		push_warning("[Riesengarten] Modell fehlt: " + name)
		result.append(BoxMesh.new())
	while result.size() < 3:
		result.append(result[result.size() - 1])
	_meshes[name] = result
	return result


static func _find(node: Node, wanted: String) -> MeshInstance3D:
	if node is MeshInstance3D and str(node.name).begins_with(wanted):
		return node
	for child in node.get_children():
		var found: MeshInstance3D = _find(child, wanted)
		if found != null:
			return found
	return null


## Blätter, Blüten und Seerosen leuchten im Gegenlicht leicht durch (Rückseitenlicht).
static func _with_leaf_light(mesh: Mesh) -> Mesh:
	for surface in range(mesh.get_surface_count()):
		var material := mesh.surface_get_material(surface) as StandardMaterial3D
		if material == null:
			continue
		var leafy: bool = false
		for word in LEAF_WORDS:
			if material.resource_name.contains(word):
				leafy = true
		if leafy:
			material.backlight_enabled = true
			material.backlight = material.albedo_color.lightened(0.15) * 0.55
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mesh


## Ein Wahrzeichen mit drei Stufen. ranges = Umschaltweiten (Meter) zwischen den Stufen.
static func place(
	parent: Node3D,
	name: String,
	transform: Transform3D,
	low: bool,
	ranges: Vector2 = Vector2(90.0, 220.0),
	shadows: bool = true
) -> Node3D:
	var holder := Node3D.new()
	holder.name = name.capitalize().replace(" ", "")
	holder.transform = transform
	parent.add_child(holder)
	var meshes: Array[Mesh] = lods(name)
	var size: float = transform.basis.get_scale().length() / sqrt(3.0)
	var edges: Array[float] = [0.0, ranges.x * maxf(size, 1.0) ** 0.35, ranges.y * maxf(size, 1.0) ** 0.35]
	for level in range(3):
		if low and level == 0:
			continue
		var node := MeshInstance3D.new()
		node.name = "Lod%d" % level
		node.mesh = meshes[level]
		var begin: float = 0.0 if (low and level == 1) else edges[level]
		node.visibility_range_begin = begin
		node.visibility_range_begin_margin = 4.0 if begin > 0.0 else 0.0
		if level < 2:
			node.visibility_range_end = edges[level + 1]
			node.visibility_range_end_margin = 4.0
		node.cast_shadow = (
			GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			if shadows and level < 2 and not low
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		)
		holder.add_child(node)
	return holder


## Viele gleiche Pflanzen als MultiMesh, gruppiert in Zellen (Sichtweite je Zelle).
static func scatter(
	parent: Node3D,
	name: String,
	transforms: Array[Transform3D],
	level: int,
	visible_to: float,
	cell: float = 160.0,
	colors: PackedColorArray = PackedColorArray()
) -> int:
	var cells: Dictionary = {}
	for i in range(transforms.size()):
		var at: Vector3 = transforms[i].origin
		var key := Vector2i(floori(at.x / cell), floori(at.z / cell))
		if not cells.has(key):
			cells[key] = []
		cells[key].append(i)
	var mesh: Mesh = lods(name)[clampi(level, 0, 2)]
	var batches: int = 0
	for key in cells:
		var indices: Array = cells[key]
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_colors = not colors.is_empty()
		multimesh.mesh = mesh
		multimesh.instance_count = indices.size()
		for k in range(indices.size()):
			multimesh.set_instance_transform(k, transforms[indices[k]])
			if not colors.is_empty():
				multimesh.set_instance_color(k, colors[indices[k]])
		var node := MultiMeshInstance3D.new()
		node.name = "%s_%d_%d" % [name, key.x, key.y]
		node.multimesh = multimesh
		node.visibility_range_end = visible_to
		node.visibility_range_end_margin = 12.0
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(node)
		batches += 1
	return batches


## Drehung, die das Blender-Modell (+Y vorn) in Fahrtrichtung legt, plus Gierwinkel.
static func along(basis: Basis, yaw: float = 0.0) -> Basis:
	var flat_forward := Vector3(-basis.z.x, 0.0, -basis.z.z).normalized()
	var heading: float = atan2(-flat_forward.x, -flat_forward.z)
	return Basis(Vector3.UP, heading + yaw)
