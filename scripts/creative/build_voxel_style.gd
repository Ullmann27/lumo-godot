class_name BuildVoxelStyle
extends RefCounted
## Bauwelt-Voxeloptik: PBR-Materialien, kombinierte Meshes und MultiMesh-Batching.
## Kollision, Speicher-IDs und Rastermaße bleiben bei kit.part_node() / build_state.

const UNIT_BOX: Vector3 = Vector3.ONE * 0.96
const BATCHABLE: Array[String] = [
	"stone",
	"wood",
	"sand",
	"glass",
	"magic",
	"path",
	"platform",
	"water",
	"grass",
	"roof_flat",
	"wall",
]

const _ALBEDO := {
	"stone": preload("res://assets/creative/bauwelt_voxel/stone_albedo.png"),
	"sand": preload("res://assets/creative/bauwelt_voxel/sand_albedo.png"),
	"wood": preload("res://assets/creative/bauwelt_voxel/wood_albedo.png"),
	"roof": preload("res://assets/creative/bauwelt_voxel/roof_albedo.png"),
	"paving": preload("res://assets/creative/bauwelt_voxel/paving_albedo.png"),
	"plain": preload("res://assets/creative/bauwelt_voxel/plain_albedo.png"),
	"grass_top": preload("res://assets/creative/bauwelt_voxel/grass_top_albedo.png"),
	"grass_side": preload("res://assets/creative/bauwelt_voxel/grass_side_albedo.png"),
	"dirt": preload("res://assets/creative/bauwelt_voxel/dirt_albedo.png"),
	"leaves": preload("res://assets/creative/bauwelt_voxel/leaves_albedo.png"),
	"bark": preload("res://assets/creative/bauwelt_voxel/bark_albedo.png"),
	"magic": preload("res://assets/creative/bauwelt_voxel/magic_albedo.png"),
}
const _NORMAL := {
	"stone": preload("res://assets/creative/bauwelt_voxel/stone_normal.png"),
	"sand": preload("res://assets/creative/bauwelt_voxel/sand_normal.png"),
	"wood": preload("res://assets/creative/bauwelt_voxel/wood_normal.png"),
	"roof": preload("res://assets/creative/bauwelt_voxel/roof_normal.png"),
	"paving": preload("res://assets/creative/bauwelt_voxel/paving_normal.png"),
	"plain": preload("res://assets/creative/bauwelt_voxel/plain_normal.png"),
	"grass_top": preload("res://assets/creative/bauwelt_voxel/grass_top_normal.png"),
	"grass_side": preload("res://assets/creative/bauwelt_voxel/grass_side_normal.png"),
	"dirt": preload("res://assets/creative/bauwelt_voxel/dirt_normal.png"),
	"leaves": preload("res://assets/creative/bauwelt_voxel/leaves_normal.png"),
	"bark": preload("res://assets/creative/bauwelt_voxel/bark_normal.png"),
	"magic": preload("res://assets/creative/bauwelt_voxel/magic_normal.png"),
}

static var _materials: Dictionary = {}
static var _meshes: Dictionary = {}


static func material(kind: String, tint: Color = Color.WHITE) -> StandardMaterial3D:
	var key := kind + tint.to_html(true)
	if _materials.has(key):
		return _materials[key]
	var mat := StandardMaterial3D.new()
	var albedo_kind := kind
	if kind == "glass":
		albedo_kind = "plain"
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.metallic = 0.18
		mat.roughness = 0.08
		mat.refraction_enabled = false
		tint = Color(tint.r, tint.g, tint.b, 0.42) if tint.a >= 0.99 else tint
	elif kind == "magic":
		albedo_kind = "magic"
		mat.emission_enabled = true
		mat.emission = Color("5ad4ff")
		mat.emission_energy_multiplier = 0.55
		mat.roughness = 0.22
		mat.metallic = 0.25
	elif kind == "water":
		albedo_kind = "plain"
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.roughness = 0.12
		mat.metallic = 0.08
		tint = Color(0.18, 0.62, 0.88, 0.62)
	else:
		mat.roughness = 0.78 if kind in ["stone", "sand", "paving", "dirt"] else 0.62
	if _ALBEDO.has(albedo_kind):
		mat.albedo_texture = _ALBEDO[albedo_kind]
		mat.normal_enabled = true
		mat.normal_texture = _NORMAL[albedo_kind]
		mat.normal_scale = 0.85
	mat.albedo_color = tint
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if kind == "magic":
		mat.uv1_triplanar = false
		mat.uv1_scale = Vector3.ONE
	else:
		mat.uv1_triplanar = true
		mat.uv1_world_triplanar = true
		mat.uv1_triplanar_sharpness = 4.0
		mat.uv1_scale = Vector3.ONE
	_materials[key] = mat
	return mat


static func tint_for(item: Dictionary) -> Color:
	var ident := str(item.get("id", ""))
	match ident:
		"sand", "wall", "arch", "stairs", "pillar":
			return Color("d9a86c")
		"stone":
			return Color("d5d0c4")
		"wood", "bench", "door":
			return Color("e2b274")
		"bridge":
			return Color("d9a86c")
		"path", "platform":
			return Color("d8d2c4")
		"roof":
			return Color("2f5aad")
		"roof_red":
			return Color("c45b58")
		"roof_round", "roof_flat":
			return Color("355fbc")
		"grass":
			return Color("9ed56a")
		"tree", "bush":
			return Color.WHITE
		"glass":
			return Color("7ee7ff")
		"magic":
			return Color("7a8bff")
		_:
			return Color(item.get("color", Color.WHITE)).lightened(0.15)


static func kind_for(item: Dictionary) -> String:
	var ident := str(item.get("id", ""))
	var shape := str(item.get("shape", ""))
	if ident == "sand" or shape in ["wall", "arch", "pillar", "stairs"]:
		return "sand"
	if ident == "stone":
		return "stone"
	if ident == "bridge":
		return "sand"
	if ident == "wood" or shape in ["bench", "door"]:
		return "wood"
	if shape in ["roof", "cone"] or ident in ["roof", "roof_red", "roof_round", "roof_flat"]:
		return "roof"
	if ident == "path" or ident == "platform" or shape == "paving":
		return "paving"
	if ident == "glass" or shape == "glass":
		return "glass"
	if ident == "magic":
		return "magic"
	if ident == "water" or shape == "water":
		return "water"
	if ident == "grass" or shape == "grass":
		return "grass_top"
	if ident == "tree":
		return "leaves"
	if ident == "bush":
		return "leaves"
	return ""


static func is_batchable(item: Dictionary) -> bool:
	return str(item.get("id", "")) in BATCHABLE


static func unit_box() -> BoxMesh:
	if _meshes.has("unit_box"):
		return _meshes["unit_box"]
	var mesh := BoxMesh.new()
	mesh.size = UNIT_BOX
	_meshes["unit_box"] = mesh
	return mesh


static func grass_cap() -> BoxMesh:
	if _meshes.has("grass_cap"):
		return _meshes["grass_cap"]
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.98, 0.18, 0.98)
	_meshes["grass_cap"] = mesh
	return mesh


static func grass_body() -> BoxMesh:
	if _meshes.has("grass_body"):
		return _meshes["grass_body"]
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.96, 0.78, 0.96)
	_meshes["grass_body"] = mesh
	return mesh


static func lawn_material() -> StandardMaterial3D:
	if _materials.has("lawn"):
		return _materials["lawn"]
	var mat: StandardMaterial3D = material("grass_top", Color.WHITE).duplicate()
	mat.uv1_scale = Vector3(0.16, 0.16, 0.16)
	_materials["lawn"] = mat
	return mat


static func wall_mesh() -> ArrayMesh:
	if _meshes.has("wall"):
		return _meshes["wall"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var body := BoxMesh.new()
	body.size = Vector3(0.96, 1.96, 0.96)
	st.append_from(body, 0, Transform3D(Basis.IDENTITY, Vector3(0.5, 1.0, 0.5)))
	var lintel := BoxMesh.new()
	lintel.size = Vector3(0.72, 0.16, 0.12)
	st.append_from(lintel, 0, Transform3D(Basis.IDENTITY, Vector3(0.5, 1.58, 0.98)))
	var sill := BoxMesh.new()
	sill.size = Vector3(0.72, 0.10, 0.16)
	st.append_from(sill, 0, Transform3D(Basis.IDENTITY, Vector3(0.5, 0.78, 0.99)))
	var left := BoxMesh.new()
	left.size = Vector3(0.12, 0.70, 0.10)
	st.append_from(left, 0, Transform3D(Basis.IDENTITY, Vector3(0.22, 1.18, 0.98)))
	var right := BoxMesh.new()
	right.size = Vector3(0.12, 0.70, 0.10)
	st.append_from(right, 0, Transform3D(Basis.IDENTITY, Vector3(0.78, 1.18, 0.98)))
	var planter := BoxMesh.new()
	planter.size = Vector3(0.70, 0.12, 0.22)
	st.append_from(planter, 0, Transform3D(Basis.IDENTITY, Vector3(0.5, 0.68, 1.12)))
	st.generate_normals()
	st.generate_tangents()
	var mesh: ArrayMesh = st.commit()
	_meshes["wall"] = mesh
	return mesh


static func window_pane() -> BoxMesh:
	if _meshes.has("window_pane"):
		return _meshes["window_pane"]
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.44, 0.58, 0.04)
	_meshes["window_pane"] = mesh
	return mesh


static func cloud_mesh() -> SphereMesh:
	if _meshes.has("cloud"):
		return _meshes["cloud"]
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 1.15
	mesh.radial_segments = 12
	mesh.rings = 8
	_meshes["cloud"] = mesh
	return mesh


static func multimesh(
	root: Node3D, node_name: String, mesh: Mesh, mat: Material, xforms: Array[Transform3D]
) -> MultiMeshInstance3D:
	var previous: Node = root.get_node_or_null(node_name)
	if previous != null:
		root.remove_child(previous)
		previous.queue_free()
	if xforms.is_empty():
		return null
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = xforms.size()
	for i in range(xforms.size()):
		multi.set_instance_transform(i, xforms[i])
	var node := MultiMeshInstance3D.new()
	node.name = node_name
	node.multimesh = multi
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	root.add_child(node)
	return node


static func collision_body(kit: RefCounted, item: Dictionary) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.set_meta("part", item.id)
	var size: Vector3 = item.size
	var mid := Vector3(size.x * 0.5, size.y * 0.5, size.z * 0.5)
	kit.collision(body, mid, size * 0.98)
	return body


static func piece_transform(piece: Dictionary, item: Dictionary) -> Transform3D:
	var turns := int(piece.turn)
	var size: Vector3 = item.size
	var offset: Vector3 = [
		Vector3.ZERO, Vector3(0, 0, size.x), Vector3(size.x, 0, size.z), Vector3(size.z, 0, 0)
	][posmod(turns, 4)]
	var origin := Vector3(piece.x, piece.y, piece.z) + offset
	var basis := Basis.from_euler(Vector3(0, turns * PI * 0.5, 0))
	return Transform3D(basis, origin)


static func box_instance_transform(piece_xform: Transform3D, item: Dictionary) -> Transform3D:
	var size: Vector3 = item.size
	var mid := Vector3(size.x * 0.5, size.y * 0.5, size.z * 0.5)
	var scaled := piece_xform.basis.scaled(size)
	return Transform3D(scaled, piece_xform.origin + piece_xform.basis * mid)


static func add_clouds(root: Node3D, count: int) -> void:
	var xforms: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 61110
	for i in range(count):
		var at := Vector3(
			rng.randf_range(-55, 55), rng.randf_range(14, 26), rng.randf_range(-62, 8)
		)
		var scale := Vector3(rng.randf_range(4.0, 8.5), rng.randf_range(1.4, 2.4), rng.randf_range(3.0, 5.5))
		xforms.append(Transform3D(Basis.from_scale(scale), at))
		if i % 3 == 0:
			xforms.append(
				Transform3D(
					Basis.from_scale(scale * Vector3(0.62, 0.8, 0.7)),
					at + Vector3(scale.x * 0.45, 0.15, 0.2)
				)
			)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("dceaf6")
	mat.roughness = 1.0
	mat.metallic = 0.0
	mat.emission_enabled = true
	mat.emission = Color("e3eef8")
	mat.emission_energy_multiplier = 0.12
	var clouds := multimesh(root, "DayClouds", cloud_mesh(), mat, xforms)
	if clouds != null:
		clouds.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func style_unique_part(body: Node, item: Dictionary) -> void:
	var kind := kind_for(item)
	var tint := tint_for(item)
	if kind.is_empty():
		return
	var meshes: Array[MeshInstance3D] = []
	for child in body.get_children():
		if child is MeshInstance3D:
			meshes.append(child)
	if meshes.is_empty():
		return
	if str(item.get("shape", "")) == "tree":
		meshes[0].material_override = material("bark", Color("c4a07a"))
		for i in range(1, meshes.size()):
			meshes[i].material_override = material("leaves", Color.WHITE)
		return
	if str(item.get("shape", "")) == "grass":
		meshes[0].material_override = material("dirt", Color("c4a078"))
		if meshes.size() > 1:
			meshes[1].material_override = material("grass_top", Color.WHITE)
		return
	if str(item.get("id", "")) == "waterfall":
		return
	for mesh_node in meshes:
		if mesh_node.material_override is ShaderMaterial:
			continue
		mesh_node.material_override = material(kind, tint)
