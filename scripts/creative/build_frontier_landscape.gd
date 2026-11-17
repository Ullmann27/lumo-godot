extends RefCounted
## Sparse outer land around the preserved, detailed original building island.
## Each terrain patch has its own bounds for renderer frustum culling. Empty
## terrain never creates one node per cell, and decoration stays off build land.
const ORIGINAL_EDGE := 24.5
const CHUNK := 32.0


static func dress(root: Node3D, kit: RefCounted, edge: float) -> void:
	var frontier := Node3D.new()
	frontier.name = "BuildFrontier"
	root.add_child(frontier)
	var strips: Array[Rect2] = [
		Rect2(-edge, -edge, edge - ORIGINAL_EDGE, edge * 2.0),
		Rect2(ORIGINAL_EDGE, -edge, edge - ORIGINAL_EDGE, edge * 2.0),
		Rect2(-ORIGINAL_EDGE, -edge, ORIGINAL_EDGE, edge - ORIGINAL_EDGE),
		Rect2(4.0, -edge, ORIGINAL_EDGE - 4.0, edge - ORIGINAL_EDGE),
		Rect2(-ORIGINAL_EDGE, ORIGINAL_EDGE, ORIGINAL_EDGE, edge - ORIGINAL_EDGE),
		Rect2(4.0, ORIGINAL_EDGE, ORIGINAL_EDGE - 4.0, edge - ORIGINAL_EDGE),
	]
	var material: Material = BuildVoxelStyle.lawn_material()
	var chunk_count := 0
	for strip in strips:
		var z := strip.position.y
		while z < strip.end.y - 0.001:
			var x := strip.position.x
			while x < strip.end.x - 0.001:
				var x_end := minf(x + CHUNK, strip.end.x)
				var z_end := minf(z + CHUNK, strip.end.y)
				_add_ground_patch(frontier, Rect2(x, z, x_end - x, z_end - z), material)
				chunk_count += 1
				x = x_end
			z = minf(z + CHUNK, strip.end.y)
	frontier.set_meta("terrain_chunks", chunk_count)
	frontier.set_meta("half_extent", edge)
	# A distinct outer rim makes the large world readable at map scale. These
	# decorative faces lie outside legal build cells and have no collision.
	for side in [-1.0, 1.0]:
		kit.box(frontier, Vector3(side * (edge + 0.3), -1.15, 0),
			Vector3(0.6, 2.3, edge * 2.0), Color("b9a080"))
		kit.box(frontier, Vector3(-edge * 0.5, -1.15, side * (edge + 0.3)),
			Vector3(edge, 2.3, 0.6), Color("b9a080"))
		kit.box(frontier, Vector3((edge + 4.0) * 0.5, -1.15, side * (edge + 0.3)),
			Vector3(edge - 4.0, 2.3, 0.6), Color("b9a080"))
	_add_border_groves(frontier, edge)
	_add_district_sign(frontier, "Sonnenwiese", Vector3(-66, 0, 48), Color("f4cf72"))
	_add_district_sign(frontier, "Bachgärten", Vector3(45, 0, -52), Color("7bd2cc"))
	_add_district_sign(frontier, "Deine großen Ideen", Vector3(88, 0, 62), Color("bdace6"))


static func _add_ground_patch(root: Node3D, area: Rect2, material: Material) -> void:
	var points: Array[Vector3] = [
		Vector3(area.position.x, 0.015, area.position.y),
		Vector3(area.position.x, 0.015, area.end.y),
		Vector3(area.end.x, 0.015, area.end.y),
		Vector3(area.end.x, 0.015, area.position.y),
	]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in [0, 1, 2, 0, 2, 3]:
		var point: Vector3 = points[index]
		surface.set_normal(Vector3.UP)
		surface.set_uv(Vector2(point.x, point.z))
		surface.add_vertex(point)
	surface.generate_tangents()
	var mesh := MeshInstance3D.new()
	mesh.name = "FrontierGround_%d_%d" % [roundi(area.position.x * 2), roundi(area.position.y * 2)]
	mesh.mesh = surface.commit()
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mesh)


static func _add_border_groves(root: Node3D, edge: float) -> void:
	for side in [-1.0, 1.0]:
		for section in range(8):
			var transforms: Array[Transform3D] = []
			for index in range(7):
				var z := -edge + float(section) * edge / 4.0 + float(index) * 4.4
				var scale := 1.1 + float(index % 3) * 0.18
				transforms.append(Transform3D(Basis.from_scale(Vector3.ONE * scale),
					Vector3(side * (edge + 2.2), -0.12, z)))
			var suffix := "%d_%d" % [int(side), section]
			var bark := BuildVoxelStyle.multimesh(root, "FrontierBark_" + suffix,
				BuildLandmarks.branched_tree_bark_mesh(),
				BuildVoxelStyle.material("bark", Color("c4a07a")), transforms)
			var leaves := BuildVoxelStyle.multimesh(root, "FrontierLeaves_" + suffix,
				BuildLandmarks.branched_tree_leaves_mesh(),
				BuildVoxelStyle.material("leaves", Color("9ed56a")), transforms)
			bark.visibility_range_end = 200.0
			leaves.visibility_range_end = 200.0


static func _add_district_sign(root: Node3D, text: String, at: Vector3, tint: Color) -> void:
	var sign := Label3D.new()
	sign.text = text
	sign.position = at + Vector3.UP * 2.0
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.font_size = 52
	sign.pixel_size = 0.02
	sign.modulate = tint
	sign.outline_modulate = Color("233c3b")
	sign.visibility_range_end = 90.0
	root.add_child(sign)
