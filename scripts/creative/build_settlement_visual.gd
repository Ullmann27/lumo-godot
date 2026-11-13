extends RefCounted
## Original Bauwelt facilities, merged by material and reused by both towns.
## Visuals never choose costs, production, AI actions or victory conditions.
const KIT = preload("res://scripts/creative/creative_kit.gd")
const CATALOG = preload("res://scripts/creative/build_catalog.gd")
const PARTS := {
	"house": "cottage", "farm": "vegetable_garden", "lumber": "cottage",
	"quarry": "platform", "market": "gazebo", "school": "observatory"
}
const TITLES := {
	"house": "Wohnhaus", "farm": "Bauernhof", "lumber": "Holzwerkstatt",
	"quarry": "Steinbruch", "market": "Markt", "school": "Sternenschule"
}
static var cache: Dictionary = {}


static func create(kind: String, opponent := false) -> StaticBody3D:
	if not cache.has(kind):
		_bake(kind)
	var entry: Dictionary = cache[kind]
	var body := StaticBody3D.new()
	body.name = "Facility_" + kind
	for surface in entry.surfaces:
		var mesh := MeshInstance3D.new()
		mesh.mesh = surface.mesh
		mesh.material_override = surface.material
		body.add_child(mesh)
	var kit := KIT.new()
	var size: Vector3 = entry.size
	kit.collision(body, Vector3(0, size.y * 0.5, 0), size * 0.96)
	var side_color := Color("e89b58") if opponent else Color("55cdd3")
	kit.box(body, Vector3(0, 0.15, size.z * 0.5 + 0.22), Vector3(2.3, 0.2, 0.16), side_color)
	var sign := Label3D.new()
	sign.text = TITLES.get(kind, kind)
	sign.position = Vector3(0, size.y + 0.45, 0)
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.font_size = 48
	sign.pixel_size = 0.008
	sign.modulate = Color("fff6dd")
	sign.outline_modulate = Color("193b47")
	sign.outline_size = 10
	sign.visibility_range_end = 48
	body.add_child(sign)
	body.set_meta("facility_kind", kind)
	body.set_meta("opponent", opponent)
	return body


static func _bake(kind: String) -> void:
	var kit := KIT.new()
	var item: Dictionary = CATALOG.part(PARTS.get(kind, "cottage"))
	var source: StaticBody3D = kit.part_node(item)
	var size: Vector3 = item.size
	if kind == "lumber":
		for row in range(2):
			for col in range(3):
				var log := kit.cylinder(source, Vector3(0.6 + col * 0.55, 0.3 + row * 0.48, 3.2), 0.22, 0.72, Color("b9854c"))
				log.rotation.x = PI * 0.5
	if kind == "quarry":
		for i in range(7):
			kit.sphere(source, Vector3(0.5 + (i % 3), 1.1 + (i / 3) * 0.20, 0.6 + (i % 2) * 1.2), Vector3(0.85, 0.68, 0.83), Color("a0aeb9"))
		size.y = 1.9
	if kind == "house":
		for child in source.find_children("WorkshopRoof", "MeshInstance3D", true, false):
			child.material_override = BuildVoxelStyle.material("roof", Color("cb7455"))
	var buckets: Dictionary = {}
	for child: MeshInstance3D in source.find_children("*", "MeshInstance3D", true, false):
		var xform := _relative_transform(child, source)
		xform.origin -= Vector3(float(item.size.x) * 0.5, 0, float(item.size.z) * 0.5)
		for surface_index in range(child.mesh.get_surface_count()):
			var material := child.material_override
			if material == null:
				material = child.get_surface_override_material(surface_index)
			if material == null:
				material = child.mesh.surface_get_material(surface_index)
			if material == null:
				material = kit.material(Color("d6c497"))
			var key := material.get_instance_id()
			if not buckets.has(key):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				buckets[key] = {"tool": st, "material": material}
			buckets[key].tool.append_from(child.mesh, surface_index, xform)
	var surfaces: Array[Dictionary] = []
	for bucket in buckets.values():
		var st: SurfaceTool = bucket.tool
		st.generate_normals()
		st.generate_tangents()
		surfaces.append({"mesh": st.commit(), "material": bucket.material})
	cache[kind] = {"surfaces": surfaces, "size": size}
	source.free()


static func _relative_transform(node: Node3D, ancestor: Node3D) -> Transform3D:
	var xform := node.transform
	var parent := node.get_parent()
	while parent != ancestor and parent is Node3D:
		xform = parent.transform * xform
		parent = parent.get_parent()
	return xform
