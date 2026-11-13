extends RefCounted
## Original Bauwelt facilities, merged by material and reused by both towns.
## Visuals never choose costs, production, AI actions or victory conditions.
const KIT = preload("res://scripts/creative/creative_kit.gd")
const CATALOG = preload("res://scripts/creative/build_catalog.gd")
const PARTS := {
	"house": "cottage",
	"farm": "vegetable_garden",
	"lumber": "cottage",
	"quarry": "platform",
	"market": "gazebo",
	"school": "cottage",
	"well": "fountain",
	"grain": "vegetable_garden",
	"bakery": "cottage",
	"road": "platform",
	"clinic": "cottage"
}
const TITLES := {
	"house": "Wohnhaus",
	"farm": "Bauernhof",
	"lumber": "Holzwerkstatt",
	"quarry": "Steinbruch",
	"market": "Markt",
	"school": "Lernhaus",
	"well": "Brunnen",
	"grain": "Kornfeld",
	"bakery": "Bäckerei",
	"road": "Wegeplatz",
	"clinic": "Fürsorgehaus"
}


class BakedFacility:
	extends RefCounted
	var surfaces: Array[Dictionary] = []
	var size := Vector3.ONE


# Entries are weak. Each live building owns its shared geometry through
# metadata, so the final building frees the material/mesh bundle naturally.
static var cache: Dictionary = {}


static func create(kind: String, opponent := false) -> StaticBody3D:
	var entry: BakedFacility = cache[kind].get_ref() if cache.has(kind) else null
	if entry == null:
		entry = _bake(kind)
		cache[kind] = weakref(entry)
	var body := StaticBody3D.new()
	body.name = "Facility_" + kind
	body.set_meta("settlement_visual_asset", entry)
	for surface in entry.surfaces:
		var mesh := MeshInstance3D.new()
		mesh.mesh = surface.mesh
		mesh.material_override = surface.material
		mesh.visibility_range_end = 165.0
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


static func _bake(kind: String) -> BakedFacility:
	var kit := KIT.new()
	var item: Dictionary = CATALOG.part(PARTS.get(kind, "cottage"))
	var source: StaticBody3D = kit.part_node(item)
	var size: Vector3 = item.size
	if kind in ["well", "grain", "road"]:
		source.free()
		source = StaticBody3D.new()
		var authored: Dictionary = _expansion_facility(kit, source, kind)
		size = authored.size
		item = {"size": size}
	else:
		_add_working_details(kit, source, kind)
	if kind in ["bakery", "clinic", "school"]:
		size.y = 3.8
	if kind == "lumber":
		for row in range(2):
			for col in range(3):
				var log := kit.cylinder(
					source,
					Vector3(0.6 + col * 0.55, 0.3 + row * 0.48, 3.2),
					0.22,
					0.72,
					Color("b9854c")
				)
				log.rotation.x = PI * 0.5
	if kind == "quarry":
		for i in range(7):
			kit.sphere(
				source,
				Vector3(0.5 + (i % 3), 1.1 + (i / 3) * 0.20, 0.6 + (i % 2) * 1.2),
				Vector3(0.85, 0.68, 0.83),
				Color("a0aeb9")
			)
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
	var result := BakedFacility.new()
	result.surfaces = surfaces
	result.size = size
	source.free()
	return result


static func _relative_transform(node: Node3D, ancestor: Node3D) -> Transform3D:
	var xform := node.transform
	var parent := node.get_parent()
	while parent != ancestor and parent is Node3D:
		xform = parent.transform * xform
		parent = parent.get_parent()
	return xform


static func _add_working_details(kit, root: Node3D, kind: String) -> void:
	if kind == "farm":
		for row in range(3):
			for column in range(3):
				var at := Vector3(0.34 + column * 0.61, 0.60, 0.34 + row * 0.61)
				kit.sphere(root, at, Vector3(0.18, 0.25, 0.18), Color("ef943f"))
				for leaf in [-1.0, 1.0]:
					var stalk = kit.box(
						root,
						at + Vector3(leaf * 0.04, 0.21, 0),
						Vector3(0.06, 0.28, 0.05),
						Color("508c40")
					)
					stalk.rotation.z = leaf * 0.25
	if kind in ["house", "bakery", "clinic", "school"]:
		# The cottages share source geometry but have readable roles and warm entrances.
		var roof_color: Color = {
			"house": Color("ca785a"),
			"bakery": Color("d99c4c"),
			"clinic": Color("58a9aa"),
			"school": Color("668cbd")
		}[kind]
		for roof in root.find_children("WorkshopRoof", "MeshInstance3D", true, false):
			roof.material_override = BuildVoxelStyle.material("roof", roof_color)
		kit.box(root, Vector3(1.5, 0.10, 3.12), Vector3(1.10, 0.13, 0.35), Color("cda577"))
		for x in [0.30, 2.70]:
			kit.box(root, Vector3(x, 0.45, 3.12), Vector3(0.46, 0.32, 0.38), Color("b98a53"))
			for offset in [-0.10, 0.10]:
				kit.sphere(
					root,
					Vector3(x + offset, 0.76, 3.12),
					Vector3(0.20, 0.24, 0.20),
					Color("6d9f54")
				)
				kit.sphere(
					root, Vector3(x + offset, 0.88, 3.12), Vector3.ONE * 0.14, Color("f2b06c")
				)
	if kind == "bakery":
		kit.box(root, Vector3(0.72, 3.15, 1.10), Vector3(0.47, 1.2, 0.47), Color("b58c69"))
		kit.box(root, Vector3(1.48, 1.14, 3.08), Vector3(1.70, 0.12, 0.58), Color("c38f4c"))
		for x in [0.88, 1.42, 1.96]:
			kit.sphere(root, Vector3(x, 1.34, 3.08), Vector3(0.42, 0.25, 0.30), Color("e2ae54"))
	if kind == "clinic":
		kit.cylinder(root, Vector3(2.65, 3.25, 0.60), 0.035, 1.1, Color("b6bcad"))
		kit.box(root, Vector3(2.96, 3.55, 0.60), Vector3(0.63, 0.38, 0.045), Color("67b9b7"))
		for x in [1.38, 1.62]:
			kit.sphere(root, Vector3(x, 2.35, 3.05), Vector3(0.31, 0.30, 0.08), Color("fff2d0"))
		var heart = kit.box(
			root, Vector3(1.5, 2.20, 3.05), Vector3(0.28, 0.28, 0.08), Color("fff2d0")
		)
		heart.rotation.z = PI * 0.25
	if kind == "school":
		for x in [1.25, 1.75]:
			var page = kit.box(
				root, Vector3(x, 2.35, 3.08), Vector3(0.48, 0.49, 0.09), Color("fff0ce")
			)
			page.rotation.z = -0.09 if x < 1.5 else 0.09
		kit.box(root, Vector3(1.5, 2.35, 3.12), Vector3(0.04, 0.54, 0.05), Color("516c9d"))
		for x in [0.56, 2.42]:
			kit.box(root, Vector3(x, 0.42, 3.14), Vector3(0.35, 0.71, 0.35), Color("7799b5"))
	if kind == "market":
		for x in [0.68, 2.32]:
			kit.box(root, Vector3(x, 0.54, 2.55), Vector3(0.77, 0.90, 0.63), Color("bd8c50"))
			for index in range(3):
				kit.sphere(
					root,
					Vector3(x - 0.22 + index * 0.22, 1.05, 2.55),
					Vector3(0.18, 0.22, 0.18),
					Color("f0a447") if x < 1.5 else Color("d86c50")
				)


static func _expansion_facility(kit, root: Node3D, kind: String) -> Dictionary:
	var size := Vector3(3.8, 0.3, 3.8)
	if kind == "road":
		kit.box(root, Vector3(1.9, 0.05, 1.9), Vector3(3.8, 0.10, 3.8), Color("c9bc96"))
		for row in range(5):
			for col in range(5):
				kit.box(
					root,
					Vector3(0.43 + col * 0.74, 0.12, 0.43 + row * 0.74),
					Vector3(0.68, 0.12, 0.68),
					Color("e1cfaa")
				)
	elif kind == "grain":
		size.y = 1.4
		kit.box(root, Vector3(1.9, 0.12, 1.9), Vector3(3.8, 0.24, 3.8), Color("92744d"))
		for row in range(5):
			for col in range(5):
				var at := Vector3(0.45 + col * 0.72, 0.80, 0.45 + row * 0.72)
				kit.box(root, at, Vector3(0.045, 1.10, 0.045), Color("b7a65a"))
				for head in [-1.0, 1.0]:
					var ear = kit.sphere(
						root,
						at + Vector3(head * 0.08, 0.38, 0),
						Vector3(0.14, 0.34, 0.10),
						Color("e6bb57")
					)
					ear.rotation.z = head * 0.24
	elif kind == "well":
		size = Vector3(3.5, 3.3, 3.5)
		kit.cylinder(root, Vector3(1.75, 0.30, 1.75), 1.55, 0.60, Color("c4b89d"))
		kit.cylinder(root, Vector3(1.75, 0.63, 1.75), 1.18, 0.05, Color("62b7c3"))
		for index in range(12):
			var angle := float(index) / 12.0 * TAU
			var stone = kit.box(
				root,
				Vector3(1.75 + cos(angle) * 1.35, 0.63, 1.75 + sin(angle) * 1.35),
				Vector3(0.56, 0.35, 0.38),
				Color("e0cda6")
			)
			stone.rotation.y = -angle + PI * 0.5
		for x in [0.48, 3.02]:
			kit.box(root, Vector3(x, 1.7, 1.75), Vector3(0.18, 2.4, 0.18), Color("a37a4c"))
		var roof := PrismMesh.new()
		roof.size = Vector3(3.45, 0.82, 2.1)
		kit.mesh(root, roof, Vector3(1.75, 2.90, 1.75), Color("658f9f"))
		kit.box(root, Vector3(1.75, 1.93, 1.75), Vector3(0.035, 1.0, 0.035), Color("c4ab7e"))
		kit.cylinder(root, Vector3(1.75, 1.40, 1.75), 0.26, 0.37, Color("b98c5d"))
	return {"size": size}
