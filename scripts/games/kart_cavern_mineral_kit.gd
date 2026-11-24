extends RefCounted
## Original Blender-authored, single-surface minerals. Real mobile topology,
## shared mesh resources and no collision or scene nodes retained at runtime.
const SCENES: Dictionary = {
	"strata_shelf": [
		preload("res://assets/kart/cavern/mineral_kit/strata_shelf_mobile.glb"),
		preload("res://assets/kart/cavern/mineral_kit/strata_shelf_high.glb"),
	],
	"split_ledge": [
		preload("res://assets/kart/cavern/mineral_kit/split_ledge_mobile.glb"),
		preload("res://assets/kart/cavern/mineral_kit/split_ledge_high.glb"),
	],
	"hanging_canopy": [
		preload("res://assets/kart/cavern/mineral_kit/hanging_canopy_mobile.glb"),
		preload("res://assets/kart/cavern/mineral_kit/hanging_canopy_high.glb"),
	],
	"crystal_fan": [
		preload("res://assets/kart/cavern/mineral_kit/crystal_fan_mobile.glb"),
		preload("res://assets/kart/cavern/mineral_kit/crystal_fan_high.glb"),
	],
	"crystal_spire": [
		preload("res://assets/kart/cavern/mineral_kit/crystal_spire_mobile.glb"),
		preload("res://assets/kart/cavern/mineral_kit/crystal_spire_high.glb"),
	],
	"crystal_rosette": [
		preload("res://assets/kart/cavern/mineral_kit/crystal_rosette_mobile.glb"),
		preload("res://assets/kart/cavern/mineral_kit/crystal_rosette_high.glb"),
	],
}
static var _meshes: Dictionary = {}


static func mesh(identity: String, low_detail: bool) -> Mesh:
	assert(SCENES.has(identity), "Unknown cavern mineral silhouette")
	var key: String = identity + ("_mobile" if low_detail else "_high")
	if _meshes.has(key):
		return _meshes[key] as Mesh
	var scene: Node = SCENES[identity][0 if low_detail else 1].instantiate()
	var stack: Array[Node] = [scene]
	var result: Mesh
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			assert(result == null, "A kit mineral must remain one reusable mesh")
			assert((node as Node3D).transform.is_equal_approx(Transform3D.IDENTITY))
			result = (node as MeshInstance3D).mesh
		for child in node.get_children():
			stack.append(child)
	assert(result != null and result.get_surface_count() == 1, "A kit mineral must use one batch")
	_meshes[key] = result
	scene.free()
	return result


static func triangles(identity: String, low_detail: bool) -> int:
	var source: Mesh = mesh(identity, low_detail)
	var indexed: int = source.surface_get_array_index_len(0)
	return (indexed if indexed > 0 else source.surface_get_array_len(0)) / 3
