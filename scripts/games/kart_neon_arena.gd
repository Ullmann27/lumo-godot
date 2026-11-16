extends Node3D
## A procedural mobile-friendly neon racing hall around the existing live kart.
## The selected vehicle/driver remain the ONE source of truth; this is scenery.
const CYAN := Color("19ccff")
const BLUE := Color("2476ff")
const PINK := Color("ff4dce")
const GOLD := Color("ffc04d")
const DARK := Color("061535")
var elapsed := 0.0
var active := false
var reduced_motion := false
var _ring_materials: Array[StandardMaterial3D] = []
var _motions: Array[Node3D] = []


func build() -> void:
	name = "LumoKartNeonArena"
	var floor_mat := _surface(Color("0b1740"), 0.85, 0.16)
	var floor := _box("GlossyRacingHallFloor", Vector3(38.0, 0.20, 46.0), Vector3(0, -0.16, 10), floor_mat)
	floor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# The arena rear wall is far behind the selected kart and its orbit camera.
	_box("NeonArenaBackWall", Vector3(36, 13, 0.40), Vector3(0, 4.9, 29), _surface(Color("0b1c4e"), 0.30, 0.35))
	for side in [-1.0, 1.0]:
		_box("NeonSideWall", Vector3(0.3, 13, 44), Vector3(side * 18.4, 4.9, 9), _surface(Color("0b1d50"), 0.25, 0.45))
		for lane in range(7):
			var pillar_z := -12.0 + lane * 6.0
			_box("NeonArchPillar", Vector3(0.42, 10, 0.46), Vector3(side * 14.8, 4.7, pillar_z), _emissive(BLUE, 0.55))
			_box("NeonArchGlow", Vector3(0.18, 10.4, 0.18), Vector3(side * 14.63, 4.7, pillar_z), _emissive(CYAN, 1.6))
	for z in range(-11, 30, 5):
		_box("CeilingCrossbeam", Vector3(32, 0.20, 0.34), Vector3(0, 10.25, float(z)), _emissive(BLUE, 0.7))
	# Native 3D circular turntable; its rings remain beneath the real wheels.
	var plinth := _cylinder("KartTurntable", 2.45, 0.08, Vector3(0, -0.025, 0), _surface(Color("102658"), 0.78, 0.18))
	plinth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for radius in [2.30, 2.08, 1.78]:
		_ring("TurntableGlow", radius, 0.02, CYAN if radius != 2.08 else GOLD)
	# Two floating holographic helixes and energetic light bands in the arena.
	for i in range(7):
		var z := 17.0 + i * 1.2
		var ring := _ring("SuspendedHologramRing", 4.6 - i * 0.19, 5.8 + i * 0.22, CYAN if i % 2 == 0 else PINK)
		ring.position.z = z
		_motions.append(ring)
	for row in range(3):
		var y := 2.5 + row * 2.45
		_box("GlowingRacingBanner", Vector3(0.12, 0.60, 8.8), Vector3(-17.8, y, 17), _emissive(PINK if row == 1 else CYAN, 1.0))
		_box("GlowingRacingBanner", Vector3(0.12, 0.60, 8.8), Vector3(17.8, y, 17), _emissive(PINK if row == 1 else CYAN, 1.0))
	for index in range(15):
		var x := float(index - 7) * 2.2
		_box("ReflectiveFloorGuide", Vector3(1.0, 0.018, 0.08), Vector3(x, -0.055, 7.0), _emissive(GOLD if index % 4 == 0 else CYAN, 0.95))
	# All base geometry is unlit or emissive and has no rigid bodies or collision.
	set_meta("neon_material_palette", [CYAN.to_html(), BLUE.to_html(), PINK.to_html(), GOLD.to_html()])
	set_meta("race_logic_unchanged", true)
	visible = false


func _surface(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	return mat


func _emissive(color: Color, power: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color.darkened(0.45)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = power
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


func _box(label: String, size_m: Vector3, position_m: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var box := MeshInstance3D.new()
	box.name = label
	var mesh := BoxMesh.new()
	mesh.size = size_m
	box.mesh = mesh
	box.position = position_m
	box.material_override = material
	box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(box)
	return box


func _cylinder(label: String, radius: float, height: float, position_m: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = label
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 48
	instance.mesh = mesh
	instance.position = position_m
	instance.material_override = material
	add_child(instance)
	return instance


func _ring(label: String, radius: float, y: float, color: Color) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = label
	pivot.position.y = y
	add_child(pivot)
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - 0.045
	mesh.outer_radius = radius + 0.045
	mesh.rings = 64
	mesh.ring_segments = 8
	var body := MeshInstance3D.new()
	body.mesh = mesh
	body.material_override = _emissive(color, 2.8)
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivot.add_child(body)
	return pivot


func set_active(value: bool, motion_reduced: bool) -> void:
	active = value
	visible = value
	reduced_motion = motion_reduced


func advance(delta: float) -> void:
	if not active or reduced_motion:
		return
	elapsed += clampf(delta, 0.0, 0.1)
	for index in range(_motions.size()):
		_motions[index].rotation.y = elapsed * (0.035 if index % 2 == 0 else -0.024)
		_motions[index].position.y = 5.8 + index * 0.22 + sin(elapsed * 0.5 + index * 0.4) * 0.04
