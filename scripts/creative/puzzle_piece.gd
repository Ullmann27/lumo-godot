extends RefCounted

static var _rim: StandardMaterial3D
static var _bottom: StandardMaterial3D
static var _pictures: Dictionary = {}

const THICKNESS := 0.16
const BEVEL := 0.035
const ADVENTURE = preload("res://scripts/creative/adventure_kit.gd")


## Real thick puzzle meshes like pressed cardboard: printed top with a rounded
## bevel (the picture wraps over the edge), fibrous cardboard sides and a grey
## back. Top UVs sample the corresponding region of the full motif; UV2 carries
## a small paper-grain detail. Materials are cached so equal pieces can batch.
static func create(model, id: int, picture: Texture2D) -> StaticBody3D:
	var outline: PackedVector2Array = model.outline(id)
	var triangles := Geometry2D.triangulate_polygon(outline)
	var target: Vector2 = model.target(id)
	var board: Vector2 = model.board_size()
	var inset := _inset(outline, BEVEL)
	var inset_tris := Geometry2D.triangulate_polygon(inset)
	var bevel_ok := inset_tris.size() >= 3
	var top_outline := inset if bevel_ok else outline
	var top_tris := inset_tris if bevel_ok else triangles
	var mesh := ArrayMesh.new()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in top_tris:
		var p: Vector2 = top_outline[index]
		surface.set_normal(Vector3.UP)
		surface.set_uv((target + p + board * 0.5) / board)
		surface.set_uv2(p * 1.6 + target * 0.37)
		surface.add_vertex(Vector3(p.x, THICKNESS, p.y))
	if bevel_ok:
		# Abgerundete Kante: das Motiv läuft über die Fase nach außen.
		var low := THICKNESS - BEVEL * 0.8
		for i in range(outline.size()):
			var j := (i + 1) % outline.size()
			var oa: Vector2 = outline[i]
			var ob: Vector2 = outline[j]
			var ia: Vector2 = inset[i]
			var ib: Vector2 = inset[j]
			var out_n := Vector3(ob.y - oa.y, 0, oa.x - ob.x).normalized() * _winding(outline)
			var n := (out_n + Vector3.UP * 1.1).normalized()
			for v in [[oa, low], [ia, THICKNESS], [ib, THICKNESS], [oa, low], [ib, THICKNESS], [ob, low]]:
				var q: Vector2 = v[0]
				surface.set_normal(n)
				surface.set_uv((target + q + board * 0.5) / board)
				surface.set_uv2(q * 1.6 + target * 0.37)
				surface.add_vertex(Vector3(q.x, float(v[1]), q.y))
	surface.set_material(_picture_material(picture))
	surface.commit(mesh)
	surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var side_top := THICKNESS - BEVEL * 0.8 if bevel_ok else THICKNESS
	var along := 0.0
	for i in range(outline.size()):
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i + 1) % outline.size()]
		var normal := Vector3(b.y - a.y, 0, a.x - b.x).normalized() * _winding(outline)
		var next := along + a.distance_to(b)
		for v in [[a, 0.0, along], [a, side_top, along], [b, side_top, next], [a, 0.0, along], [b, side_top, next], [b, 0.0, next]]:
			var q: Vector2 = v[0]
			surface.set_normal(normal)
			surface.set_uv(Vector2(float(v[2]) * 2.2, float(v[1]) * 6.0))
			surface.add_vertex(Vector3(q.x, float(v[1]), q.y))
		along = next
	surface.set_material(_rim_material())
	surface.commit(mesh)
	surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in triangles:
		var q: Vector2 = outline[index]
		surface.set_normal(Vector3.DOWN)
		surface.set_uv(q * 0.8)
		surface.add_vertex(Vector3(q.x, 0.0, q.y))
	surface.set_material(_bottom_material())
	surface.commit(mesh)
	var body := StaticBody3D.new()
	body.set_meta("piece", id)
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.name = "Visual"
	body.add_child(visual)
	var collision := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	var faces := PackedVector3Array()
	for index in triangles:
		var p: Vector2 = outline[index]
		faces.append(Vector3(p.x, THICKNESS, p.y))
	shape.set_faces(faces)
	shape.backface_collision = true
	collision.shape = shape
	body.add_child(collision)
	return body


## +1 für gegen den Uhrzeigersinn (Außennormale = rechts der Kante), sonst -1.
static func _winding(outline: PackedVector2Array) -> float:
	var area := 0.0
	for i in range(outline.size()):
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i + 1) % outline.size()]
		area += a.x * b.y - b.x * a.y
	# Bei positiver Fläche zeigt (dy, -dx) nach außen.
	return 1.0 if area > 0.0 else -1.0


## Gleich viele Punkte, jeder um `amount` nach innen verschoben (Gehrung begrenzt).
static func _inset(outline: PackedVector2Array, amount: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	var w := _winding(outline)
	var count := outline.size()
	for i in range(count):
		var prev: Vector2 = outline[(i - 1 + count) % count]
		var here: Vector2 = outline[i]
		var next: Vector2 = outline[(i + 1) % count]
		var n1 := Vector2(here.y - prev.y, prev.x - here.x).normalized() * w
		var n2 := Vector2(next.y - here.y, here.x - next.x).normalized() * w
		var bis := (n1 + n2)
		if bis.length() < 0.001:
			bis = n1
		bis = bis.normalized()
		var miter := amount / maxf(0.45, bis.dot(n1))
		result.append(here - bis * miter)
	return result


static func _picture_material(picture: Texture2D) -> StandardMaterial3D:
	var key: String = str(picture.resource_path)
	if _pictures.has(key):
		return _pictures[key]
	var picture_mat := StandardMaterial3D.new()
	picture_mat.albedo_texture = picture
	picture_mat.roughness = 0.62
	picture_mat.metallic_specular = 0.35
	picture_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	picture_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Feine Karton-/Papierstruktur über dem Druck (UV2, nur Normalen).
	var grain := ADVENTURE.texture("paper_normal.jpg")
	if grain != null:
		picture_mat.detail_enabled = true
		picture_mat.detail_uv_layer = BaseMaterial3D.DETAIL_UV_2
		picture_mat.detail_normal = grain
		picture_mat.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MIX
		picture_mat.detail_mask = null
		picture_mat.detail_albedo = null
	_pictures[key] = picture_mat
	return picture_mat


static func _rim_material() -> StandardMaterial3D:
	if _rim != null:
		return _rim
	# Gepresste Pappe an den Schnittkanten: hell, faserig, matt.
	_rim = StandardMaterial3D.new()
	_rim.albedo_color = Color("d9c7a6")
	var paper := ADVENTURE.texture("paper_albedo.jpg")
	if paper != null:
		_rim.albedo_texture = paper
		_rim.normal_enabled = true
		_rim.normal_texture = ADVENTURE.texture("paper_normal.jpg")
	_rim.roughness = 0.95
	_rim.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _rim


static func _bottom_material() -> StandardMaterial3D:
	if _bottom != null:
		return _bottom
	_bottom = StandardMaterial3D.new()
	_bottom.albedo_color = Color("8a8170")
	var paper := ADVENTURE.texture("paper_albedo.jpg")
	if paper != null:
		_bottom.albedo_texture = paper
	_bottom.roughness = 1.0
	_bottom.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _bottom
