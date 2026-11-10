extends RefCounted

static var _rim: StandardMaterial3D
static var _pictures: Dictionary = {}


## Real thick puzzle meshes. Top UVs sample the corresponding region of the full motif.
## Top + combined gold rim/back share cached materials so equal pieces can batch.
static func create(model, id: int, picture: Texture2D) -> StaticBody3D:
	var outline: PackedVector2Array = model.outline(id)
	var triangles := Geometry2D.triangulate_polygon(outline)
	var target: Vector2 = model.target(id)
	var mesh := ArrayMesh.new()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in triangles:
		var p: Vector2 = outline[index]
		surface.set_normal(Vector3.UP)
		surface.set_uv((target + p + model.board_size() * 0.5) / model.board_size())
		surface.add_vertex(Vector3(p.x, 0.16, p.y))
	surface.set_material(_picture_material(picture))
	surface.commit(mesh)
	surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(outline.size()):
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i + 1) % outline.size()]
		var normal := Vector3(b.y - a.y, 0, a.x - b.x).normalized()
		for p in [
			Vector3(a.x, 0, a.y),
			Vector3(a.x, 0.16, a.y),
			Vector3(b.x, 0.16, b.y),
			Vector3(a.x, 0, a.y),
			Vector3(b.x, 0.16, b.y),
			Vector3(b.x, 0, b.y)
		]:
			surface.set_normal(normal)
			surface.add_vertex(p)
	for index in triangles:
		var q: Vector2 = outline[index]
		surface.set_normal(Vector3.DOWN)
		surface.add_vertex(Vector3(q.x, 0.0, q.y))
	surface.set_material(_rim_material())
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
		faces.append(Vector3(p.x, 0.16, p.y))
	shape.set_faces(faces)
	shape.backface_collision = true
	collision.shape = shape
	body.add_child(collision)
	return body


static func _picture_material(picture: Texture2D) -> StandardMaterial3D:
	var key: String = str(picture.resource_path)
	if _pictures.has(key):
		return _pictures[key]
	var picture_mat := StandardMaterial3D.new()
	picture_mat.albedo_texture = picture
	picture_mat.roughness = 0.82
	picture_mat.metallic_specular = 0.12
	picture_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	picture_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_pictures[key] = picture_mat
	return picture_mat


static func _rim_material() -> StandardMaterial3D:
	if _rim != null:
		return _rim
	_rim = StandardMaterial3D.new()
	_rim.albedo_color = Color("d6b25a")
	_rim.metallic = 0.72
	_rim.roughness = 0.34
	_rim.emission_enabled = true
	_rim.emission = Color("a67c28")
	_rim.emission_energy_multiplier = 0.22
	_rim.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _rim
