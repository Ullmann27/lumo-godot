extends RefCounted
## Billboard quad for particle emitters, with white vertex colours.
##
## A plain QuadMesh has no colour attribute. Together with
## vertex_color_use_as_albedo the compatibility renderer (the one the Android
## host starts the games with) then drew single particles black. Use this quad
## wherever a particle material multiplies by the particle colour.


static func make(size: Vector2 = Vector2.ONE) -> ArrayMesh:
	var half := size * 0.5
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		Vector3(-half.x, -half.y, 0), Vector3(half.x, -half.y, 0),
		Vector3(half.x, half.y, 0), Vector3(-half.x, half.y, 0)
	])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])
	arrays[Mesh.ARRAY_COLOR] = PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 2, 1, 0, 3, 2])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
