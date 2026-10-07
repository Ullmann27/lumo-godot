extends RefCounted


## Real thick puzzle meshes. Top UVs sample the corresponding region of the full motif.
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
		surface.set_uv((target + p + model.BOARD * 0.5) / model.BOARD)
		surface.add_vertex(Vector3(p.x, 0.16, p.y))
	var picture_mat := StandardMaterial3D.new()
	picture_mat.albedo_texture = picture
	picture_mat.roughness = 0.55
	picture_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	picture_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	surface.set_material(picture_mat)
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
	var rim := StandardMaterial3D.new()
	rim.albedo_color = Color("1e4678")
	rim.metallic = 0.15
	rim.roughness = 0.5
	rim.cull_mode = BaseMaterial3D.CULL_DISABLED
	surface.set_material(rim)
	surface.commit(mesh)
	var body := StaticBody3D.new()
	body.set_meta("piece", id)
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
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
