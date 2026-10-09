extends Node3D
## Standalone, non-driveable loop visualization shared by capture and geometry export.

const RADIUS_M: float = 12.0
const ROAD_WIDTH_M: float = 10.8
const SEGMENTS: int = 96


func configure(track_id: String) -> void:
	name = "AuthoringOnlyFullLoop"
	set_meta("runtime_driveable", false)
	set_meta("collision_included", false)
	set_meta("requires_inverted_physics_contract", true)

	var road_material := _material(_loop_color(track_id))
	var rail_material := _material(Color.WHITE)
	var segment_length: float = 2.0 * RADIUS_M * sin(PI / float(SEGMENTS)) * 1.08
	for i in range(SEGMENTS):
		var theta: float = -PI * 0.5 + TAU * (float(i) + 0.5) / float(SEGMENTS)
		var holder := Node3D.new()
		holder.position = Vector3(
			0.0,
			RADIUS_M + RADIUS_M * sin(theta),
			-RADIUS_M * cos(theta)
		)
		holder.rotation.x = theta - PI * 0.5
		add_child(holder)

		var slab := MeshInstance3D.new()
		var slab_mesh := BoxMesh.new()
		slab_mesh.size = Vector3(ROAD_WIDTH_M, 0.72, segment_length)
		slab.mesh = slab_mesh
		slab.material_override = road_material
		holder.add_child(slab)

		for side in [-1.0, 1.0]:
			var rail := MeshInstance3D.new()
			var rail_mesh := BoxMesh.new()
			rail_mesh.size = Vector3(0.34, 1.2, segment_length)
			rail.mesh = rail_mesh
			rail.position = Vector3(side * (ROAD_WIDTH_M * 0.5 - 0.18), 0.58, 0.0)
			rail.material_override = rail_material
			holder.add_child(rail)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.7
	return material


func _loop_color(track_id: String) -> Color:
	match track_id:
		"sonnenhafen":
			return Color("48e7ff")
		"zauberwald":
			return Color("7cff83")
		"bergwelt":
			return Color("ffd75a")
		"holo_city":
			return Color("ff54e8")
	return Color("54dcff")
