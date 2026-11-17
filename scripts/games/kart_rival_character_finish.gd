extends RefCounted
## Real species anatomy for the existing animated procedural rival rigs.
## Original Lumo geometry and its imported skin are deliberately never passed here.
const FACE = preload("res://scripts/games/kart_character_finish.gd")


static func palette(kind: String) -> Dictionary:
	match kind:
		"rabbit":
			return {"fur": Color("c5c7c0"), "cream": Color("f0eadc"), "suit": Color("555877"), "iris": Color("796046")}
		"otter":
			return {"fur": Color("89644b"), "cream": Color("ddc6a4"), "suit": Color("315c61"), "iris": Color("668065")}
		"badger":
			return {"fur": Color("c7c6b9"), "cream": Color("e9e3d2"), "suit": Color("80583f"), "iris": Color("9a7845")}
		"cat":
			return {"fur": Color("b9895e"), "cream": Color("f1debc"), "suit": Color("765367"), "iris": Color("5c8b72")}
	return {"fur": Color("a5937d"), "cream": Color("ece3ce"), "suit": Color("43586d"), "iris": Color("697d82")}


static func head_profile(kind: String, fallback: Array[Vector4]) -> Array[Vector4]:
	match kind:
		"rabbit":
			return [Vector4(-0.31, 0.06, 0.07, 0.01), Vector4(-0.24, 0.235, 0.205, 0.015), Vector4(-0.10, 0.335, 0.277, 0.018), Vector4(0.065, 0.335, 0.287, 0.025), Vector4(0.245, 0.255, 0.243, 0.028), Vector4(0.34, 0.135, 0.145, 0.04), Vector4(0.375, 0.008, 0.012, 0.045)]
		"otter":
			return [Vector4(-0.31, 0.055, 0.06, 0.01), Vector4(-0.255, 0.26, 0.215, 0.015), Vector4(-0.12, 0.415, 0.285, 0.02), Vector4(0.06, 0.40, 0.304, 0.02), Vector4(0.23, 0.30, 0.27, 0.03), Vector4(0.32, 0.15, 0.16, 0.04), Vector4(0.35, 0.008, 0.012, 0.04)]
		"badger":
			return [Vector4(-0.32, 0.055, 0.06, -0.02), Vector4(-0.265, 0.23, 0.22, -0.01), Vector4(-0.13, 0.36, 0.29, 0.015), Vector4(0.055, 0.36, 0.305, 0.03), Vector4(0.23, 0.29, 0.265, 0.04), Vector4(0.33, 0.15, 0.17, 0.055), Vector4(0.37, 0.008, 0.012, 0.055)]
		"cat":
			return [Vector4(-0.32, 0.045, 0.055, -0.02), Vector4(-0.25, 0.22, 0.21, 0.0), Vector4(-0.11, 0.375, 0.29, 0.015), Vector4(0.075, 0.365, 0.307, 0.02), Vector4(0.23, 0.28, 0.255, 0.035), Vector4(0.33, 0.15, 0.15, 0.05), Vector4(0.37, 0.008, 0.012, 0.05)]
	return fallback


static func coat(source: Mesh, kind: String, fur: Color, cream: Color) -> ArrayMesh:
	var arrays: Array = source.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var pigments := PackedColorArray()
	for p in points:
		var front: float = 1.0 - smoothstep(-0.05, 0.13, p.z)
		var chin: float = (1.0 - smoothstep(-0.18, -0.035, p.y)) * front
		var pigment: Color = fur.lerp(cream, chin * 0.90)
		if kind == "badger":
			# The eye mask is pigmentation on the actual head, not a floating plate.
			var stripe_x: float = 0.155 + (p.y + 0.08) * 0.10
			var stripe: float = 1.0 - smoothstep(0.045, 0.093, absf(absf(p.x) - stripe_x))
			pigment = pigment.lerp(Color("3b4245"), stripe * front * smoothstep(-0.25, -0.12, p.y))
		elif kind == "cat":
			var forehead: float = smoothstep(0.06, 0.19, p.y) * front
			var band: float = pow(maxf(0.0, cos(p.x * 43.0 + absf(p.y) * 9.0)), 7.0)
			pigment = pigment.lerp(fur.darkened(0.38), band * forehead * 0.72)
		elif kind == "otter":
			var face: float = (1.0 - smoothstep(0.035, 0.23, p.y)) * front
			pigment = pigment.lerp(cream, face * 0.38)
		elif kind == "rabbit":
			pigment = pigment.lerp(cream, front * 0.23)
		var soft_back: float = smoothstep(0.03, 0.27, p.z) * 0.10
		pigments.append(pigment.darkened(soft_back))
	arrays[Mesh.ARRAY_COLOR] = pigments
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if source.has_meta("far_geometry"):
		result.set_meta("far_geometry", coat(source.get_meta("far_geometry"), kind, fur, cream))
	return result


static func _iris(size: Vector3, support: Vector3, offset: Vector2, tint: Color, low: bool = false) -> ArrayMesh:
	var geometry: ArrayMesh = FACE.eye_overlay(size, support, offset, 0.0012, false, low)
	var arrays: Array = geometry.surface_get_arrays(0)
	var pigments := PackedColorArray()
	for p: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
		var radius: float = Vector2(p.x / size.x, p.y / size.y).length()
		var angle: float = atan2(p.y / size.y, p.x / size.x)
		var fibres: float = sin(angle * 29.0 + radius * 13.0) * 0.10 + sin(angle * 47.0 - radius * 7.0) * 0.06
		var pigment: Color = tint.lightened(maxf(0.0, fibres)).darkened(maxf(0.0, -fibres))
		pigments.append(pigment.lerp(tint.darkened(0.64), smoothstep(0.80, 1.0, radius)))
	arrays[Mesh.ARRAY_COLOR] = pigments
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if not low:
		result.set_meta("far_geometry", _iris(size, support, offset, tint, true))
	return result


static func make_eye(kart, side: float, fur_shadow: Color) -> void:
	var rabbit: bool = kart.animal == "rabbit"
	var eye := Node3D.new()
	eye.name = "Eye"
	eye.position = Vector3(side * (0.143 if rabbit else 0.165), 0.055, -0.254 if rabbit else -0.270)
	eye.rotation.y = -side * 0.35
	kart.head.add_child(eye)
	kart.eyes.append(eye)
	var support := Vector3(0.074, 0.093, 0.021) if rabbit else Vector3(0.085, 0.102, 0.024)
	var socket: MeshInstance3D = kart._ellipsoid(eye, Vector3(0, 0.002, 0.005), support + Vector3(0.012, 0.012, 0.003), fur_shadow, 0.0, 0.82)
	socket.name = "RecessedEyeSocket"
	var white: MeshInstance3D = kart._ellipsoid(eye, Vector3(0, 0, -0.004), support, Color("ece8dc"), 0.0, 0.42)
	white.name = "InsetEyeWhite"
	var offset := Vector2(-side * 0.003, -0.003)
	var iris_size := Vector3(0.049, 0.061, 0.005) if rabbit else Vector3(0.055, 0.066, 0.006)
	var iris: MeshInstance3D = kart._mesh(eye, _iris(iris_size, support, offset, palette(kart.animal).iris), Vector3(offset.x, offset.y, -0.004), Color.WHITE, 0.0, 0.30)
	iris.name = "CurvedPigmentedIris"
	var pupil_size := Vector3(0.027, 0.037, 0.004) if rabbit else Vector3(0.031, 0.040, 0.004)
	var pupil: MeshInstance3D = kart._mesh(eye, FACE.eye_overlay(pupil_size, support, offset, 0.0027, false), Vector3(offset.x, offset.y, -0.004), Color("11191d"), 0.0, 0.22)
	pupil.name = "SeatedPupil"
	for highlight in [Vector3(-0.015, 0.019, -0.004), Vector3(0.011, -0.022, -0.004)]:
		var r: float = pow(highlight.x / support.x, 2) + pow(highlight.y / support.y, 2)
		highlight.z = -0.004 - support.z * sqrt(1.0 - r) - 0.004
		kart._ellipsoid(eye, highlight, Vector3(0.008, 0.010, 0.0015) if highlight.x < 0 else Vector3(0.003, 0.004, 0.001), Color("fff9e8"), 0.0, 0.25)


static func make_muzzle(kart, cream: Color) -> void:
	var rabbit: bool = kart.animal == "rabbit"
	var spread: float = 0.062 if rabbit else 0.079
	for side in [-1.0, 1.0]:
		var pad: MeshInstance3D = kart._ellipsoid(kart.head, Vector3(side * spread, -0.155, -0.300), Vector3(0.100 if rabbit else 0.116, 0.077, 0.073), cream, 0.0, 0.82)
		pad.name = "WhiskerPad"
		for dot in range(3):
			kart._ellipsoid(kart.head, Vector3(side * (spread + 0.012 + dot * 0.018), -0.145 - (dot % 2) * 0.018, -0.368 + dot * 0.006), Vector3(0.0038, 0.0034, 0.002), cream.darkened(0.40), 0.0, 0.82)
	var nose_color := Color("9c7875") if rabbit else Color("33302e")
	var nose: MeshInstance3D = kart._ellipsoid(kart.head, Vector3(0, -0.097, -0.357), Vector3(0.043 if rabbit else 0.059, 0.030, 0.023), nose_color, 0.0, 0.56)
	nose.name = "SculptedNose"
	if rabbit:
		for side in [-1.0, 1.0]:
			var tooth: MeshInstance3D = kart._ellipsoid(kart.head, Vector3(side * 0.018, -0.220, -0.333), Vector3(0.016, 0.025, 0.008), Color("f4e9d6"), 0.0, 0.56)
			tooth.name = "SmallRabbitIncisor"


static func make_tail(kart, fur: Color, cream: Color) -> bool:
	if kart.animal == "rabbit":
		var rabbit_shape: Array[Vector4] = [Vector4(0.0, 0.035, 0.04, 0), Vector4(0.10, 0.12, 0.13, 0.01), Vector4(0.23, 0.10, 0.11, 0.02), Vector4(0.30, 0.008, 0.008, 0.02)]
		kart._fur(kart.tail, kart._loft(rabbit_shape, false, 24, 3), Vector3.ZERO, cream, 260, 0.018, 118)
		return true
	if kart.animal in ["otter", "badger", "cat"]:
		var shape: Array[Vector4]
		if kart.animal == "otter":
			shape = [Vector4(0.0, 0.095, 0.09, 0), Vector4(0.20, 0.14, 0.10, -0.05), Vector4(0.48, 0.11, 0.07, -0.12), Vector4(0.77, 0.055, 0.04, -0.15), Vector4(0.95, 0.006, 0.006, -0.13)]
		elif kart.animal == "badger":
			shape = [Vector4(0.0, 0.075, 0.07, 0), Vector4(0.13, 0.13, 0.12, 0.03), Vector4(0.34, 0.095, 0.10, 0.10), Vector4(0.49, 0.008, 0.008, 0.15)]
		else:
			shape = [Vector4(0.0, 0.065, 0.07, 0), Vector4(0.24, 0.085, 0.09, 0.03), Vector4(0.49, 0.082, 0.085, 0.13), Vector4(0.67, 0.077, 0.08, 0.36), Vector4(0.65, 0.065, 0.065, 0.57), Vector4(0.55, 0.008, 0.008, 0.66)]
		kart._fur(kart.tail, kart._loft(shape, false, 28, 4), Vector3.ZERO, fur, 500, 0.018, 811)
		return true
	return false
