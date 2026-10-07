@tool
extends Node3D
## Non-driveable 360-degree authoring guide. It is intentionally not loaded by kart_world.gd.

const ROAD_WIDTH_M: float = 10.8
const EDGE_OFFSET_M: float = 6.05
const RADIUS_M: float = 12.0
const APPROACH_LENGTH_M: float = 18.0
const SEGMENTS: int = 96


func _ready() -> void:
	set_meta("track_id", "bergwelt")
	set_meta("setpiece_id", "sky_halo_loop")
	set_meta("runtime_driveable", false)
	set_meta("collision_included", false)
	set_meta("requires_inverted_physics_contract", true)
	_build_geometry()


func _build_geometry() -> void:
	var guide := Node3D.new()
	guide.name = "AuthoringOnly_NoRuntimeCollision"
	add_child(guide)
	_add_loop_surface(guide)
	_add_loop_edge_guides(guide)
	_add_approach(guide, true)
	_add_approach(guide, false)
	_add_labels(guide)


func _add_loop_surface(parent: Node3D) -> void:
	var centers := PackedVector3Array()
	var normals := PackedVector3Array()
	for index in range(SEGMENTS + 1):
		var angle: float = TAU * float(index) / float(SEGMENTS)
		centers.append(_loop_center(angle))
		normals.append(_loop_up(angle))
	var surface := _build_strip(centers, normals, ROAD_WIDTH_M * 0.5)
	var road := MeshInstance3D.new()
	road.name = "SkyHaloLoop_360deg_10p8mRoad"
	road.mesh = surface
	road.material_override = _material(Color("344d86"), 0.88)
	road.set_meta("centerline_radius_m", RADIUS_M)
	road.set_meta("road_width_m", ROAD_WIDTH_M)
	road.set_meta("driveable", false)
	parent.add_child(road)


func _add_loop_edge_guides(parent: Node3D) -> void:
	for side in [-1.0, 1.0]:
		var centers := PackedVector3Array()
		var normals := PackedVector3Array()
		for index in range(SEGMENTS + 1):
			var angle: float = TAU * float(index) / float(SEGMENTS)
			centers.append(
				_loop_center(angle)
				+ Vector3.RIGHT * side * EDGE_OFFSET_M
				+ _loop_up(angle) * 0.12
			)
			normals.append(_loop_up(angle))
		var guide_mesh := MeshInstance3D.new()
		guide_mesh.name = "AuthoringEdgeGuide_%s" % ("left" if side < 0.0 else "right")
		guide_mesh.mesh = _build_strip(centers, normals, 0.07)
		guide_mesh.material_override = _material(
			Color("4fe6ff") if side < 0.0 else Color("ffc94a"),
			0.42
		)
		guide_mesh.set_meta("collision_included", false)
		parent.add_child(guide_mesh)


func _add_approach(parent: Node3D, entry: bool) -> void:
	var centers := PackedVector3Array()
	var normals := PackedVector3Array()
	var start_z: float = APPROACH_LENGTH_M if entry else 0.0
	var end_z: float = 0.0 if entry else -APPROACH_LENGTH_M
	for index in range(9):
		var blend: float = float(index) / 8.0
		centers.append(Vector3(0.0, 0.0, lerpf(start_z, end_z, blend)))
		normals.append(Vector3.UP)
	var approach := MeshInstance3D.new()
	approach.name = "AuthoringEntryApproach" if entry else "AuthoringExitApproach"
	approach.mesh = _build_strip(centers, normals, ROAD_WIDTH_M * 0.5)
	approach.material_override = _material(Color("4c638d"), 0.88)
	approach.set_meta("driveable", false)
	parent.add_child(approach)


func _add_labels(parent: Node3D) -> void:
	var label := Label3D.new()
	label.name = "AuthoringStatus"
	label.text = "SKY HALO LOOP — AUTHORING ONLY\nR=12 m · Fahrbahn 10.8 m · 360°\nKeine Kollision / nicht befahrbar"
	label.position = Vector3(0.0, RADIUS_M * 2.0 + 4.0, 0.0)
	label.font_size = 48
	label.pixel_size = 0.018
	label.modulate = Color("f2ffff")
	parent.add_child(label)


func _loop_center(angle: float) -> Vector3:
	return Vector3(0.0, RADIUS_M * (1.0 - cos(angle)), -RADIUS_M * sin(angle))


func _loop_up(angle: float) -> Vector3:
	return Vector3(0.0, cos(angle), sin(angle))


func _build_strip(
	centers: PackedVector3Array, normals: PackedVector3Array, half_width: float
) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(centers.size() - 1):
		var left: Vector3 = centers[index] - Vector3.RIGHT * half_width
		var right: Vector3 = centers[index] + Vector3.RIGHT * half_width
		var next_left: Vector3 = centers[index + 1] - Vector3.RIGHT * half_width
		var next_right: Vector3 = centers[index + 1] + Vector3.RIGHT * half_width
		for vertex in [left, right, next_left, right, next_right, next_left]:
			surface.add_vertex(vertex)
	surface.generate_normals()
	return surface.commit()


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.28
	return material
