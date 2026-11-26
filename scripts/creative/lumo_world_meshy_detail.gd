extends RefCounted
## Optional high-detail render layer for the actual World village.
## Original facility collision, identity, economics and far LOD are untouched.
const MODELS := {
	"house": "res://assets/creative/lumo_world/meshy/lumo_house.glb",
	"market": "res://assets/creative/lumo_world/meshy/market_stall.glb",
}


static func apply(body: StaticBody3D, quality: String) -> bool:
	if quality not in ["high", "ultra"]:
		return false
	var kind := str(body.get_meta("facility_kind", ""))
	if not MODELS.has(kind) or body.has_node("MeshyDetail"):
		return false
	var original := body.get_node_or_null("Visual") as Node3D
	if original == null or not original.visible:
		return false
	var collider: CollisionShape3D
	for child in body.get_children():
		if child is CollisionShape3D and child.shape is BoxShape3D:
			collider = child
			break
	if collider == null:
		return false
	var shape := collider.shape as BoxShape3D
	var detail := fitted(str(MODELS[kind]), shape.size)
	if detail == null:
		return false
	detail.name = "MeshyDetail"
	detail.position += collider.position - Vector3.UP * shape.size.y * 0.5
	body.add_child(detail)
	original.hide()
	body.set_meta("meshy_detail_path", str(MODELS[kind]))
	return true


## Flatten only visual meshes, preserving nested transforms and imported
## material bindings; never import physics, scripts or navigation into World.
static func fitted(path: String, target: Vector3) -> Node3D:
	if not target.is_finite() or minf(target.x, minf(target.y, target.z)) <= 0.001:
		return null
	if not ResourceLoader.exists(path):
		return null
	var packed := ResourceLoader.load(path, "PackedScene") as PackedScene
	if packed == null:
		return null
	var source := packed.instantiate()
	if not source is Node3D:
		source.free()
		return null
	var detail := Node3D.new()
	var bounds: Array[AABB] = []
	_copy_meshes(source as Node3D, detail, Transform3D.IDENTITY, bounds)
	source.free()
	if bounds.is_empty():
		detail.free()
		return null
	var box := bounds[0]
	for i in range(1, bounds.size()):
		box = box.merge(bounds[i])
	if not box.size.is_finite() or not box.position.is_finite():
		detail.free()
		return null
	if minf(box.size.x, minf(box.size.y, box.size.z)) <= 0.001:
		detail.free()
		return null
	var factor := minf(target.x / box.size.x, minf(target.y / box.size.y, target.z / box.size.z))
	detail.scale = Vector3.ONE * factor
	var center := box.get_center()
	detail.position = -Vector3(center.x, box.position.y, center.z) * factor
	detail.set_meta("source_path", path)
	detail.set_meta("mesh_count", bounds.size())
	detail.set_meta("fitted_size", box.size * factor)
	return detail


static func _copy_meshes(node: Node3D, parent: Node3D, previous: Transform3D, bounds: Array[AABB]) -> void:
	if not node.visible:
		return
	var transform := previous * node.transform
	if node is MeshInstance3D and node.mesh != null:
		var item := MeshInstance3D.new()
		item.mesh = node.mesh
		item.transform = transform
		item.material_override = node.material_override
		item.material_overlay = node.material_overlay
		for surface in range(node.mesh.get_surface_count()):
			item.set_surface_override_material(surface, node.get_surface_override_material(surface))
		item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(item)
		bounds.append(transform * item.mesh.get_aabb())
	for child in node.get_children():
		if child is Node3D:
			_copy_meshes(child, parent, transform, bounds)
