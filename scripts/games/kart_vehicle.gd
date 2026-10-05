class_name LumoRaceKart
extends Node3D
## Original Lumo Aurora-series racers. All geometry is authored here, no external IP.
## The lofted bodywork/character shells use shared normals and retain animated joints.

const FAR_DETAIL_DISTANCE: float = 32.0
const DETAIL_HYSTERESIS: float = 4.0
const INK := Color("101c30")
const NAVY := Color("15355e")
const ICE := Color("72e6ff")
const WHITE := Color("edf9ff")
const CHROME := Color("b7cddd")

var vehicle_color: Color = Color("357cba")
var animal: String = "fox"
var kart_style: String = "comet"
var wheel_pivots: Array[Node3D] = []
var wheel_rotors: Array[Node3D] = []
var eyes: Array[Node3D] = []
var head: Node3D
var drive_arm_right: Node3D
var cheer_arm: Node3D
## Platz beim Zieleinlauf (0 = keine Feier). 1–3 jubeln, ab 4 aufmunternd.
var celebration_place: int = 0
var celebration_time: float = 0.0
var tail: Node3D
var steering_wheel: Node3D
var driver: Node3D
var jaw: Node3D
var flames: Array[MeshInstance3D] = []
var sparks: Array[MeshInstance3D] = []
var motion_speed: float = 0.0
var motion_steer: float = 0.0
var motion_boost: bool = false
var motion_drift: bool = false
var reduced_motion: bool = false
var animation_time: float = 0.0
var materials: Dictionary = {}
var geometries: Dictionary = {}
var near_meshes: Array[MeshInstance3D] = []
var far_mesh: MeshInstance3D
var far_detail: bool = false
var detail_check_time: float = 0.0
var detail_distance: float = FAR_DETAIL_DISTANCE
var wheel_spin_phase: float = 0.0
var speaking_amount: float = 0.0
var _built: bool = false
var _style_was_selected: bool = false
var companion_mode: bool = false
var arm_joints: Array[Node3D] = []
var elbow_joints: Array[Node3D] = []
var leg_joints: Array[Node3D] = []
var ear_joints: Array[Node3D] = []


func configure(kind: String, color: Color, variant: String = "") -> void:
	companion_mode = false
	animal = _animal_id(kind)
	vehicle_color = color
	if not variant.is_empty():
		kart_style = _style_id(variant)
	elif has_meta("variant"):
		kart_style = _style_id(str(get_meta("variant")))
	elif not _style_was_selected:
		kart_style = "comet"
	_rebuild()


func configure_companion(kind: String = "fox") -> void:
	companion_mode = true
	animal = _animal_id(kind)
	_rebuild()


func set_companion_pose(time_seconds: float, mood: String = "idle", voice_open: float = 0.0) -> void:
	if not companion_mode or not is_instance_valid(head):
		return
	animation_time = time_seconds
	var cycle: float = TAU / (4.0 if mood == "idle" else 1.0)
	var breath: float = sin(time_seconds * cycle)
	driver.position.y = breath * 0.007
	head.rotation = Vector3(breath * 0.014, sin(time_seconds * cycle) * 0.045, sin(time_seconds * cycle) * 0.025)
	var blink_phase: float = fposmod(time_seconds, 4.0)
	var blink: float = maxf(0.06, absf(blink_phase - 2.25) / 0.10) if blink_phase > 2.15 and blink_phase < 2.35 else 1.0
	for eye in eyes:
		eye.scale.y = blink
	for i in range(arm_joints.size()):
		var side: float = -1.0 if i == 0 else 1.0
		arm_joints[i].rotation = Vector3(sin(time_seconds * cycle + i) * 0.022, 0, side * (0.10 + breath * 0.016))
		elbow_joints[i].rotation = Vector3(0.13, 0, 0)
		leg_joints[i].rotation = Vector3.ZERO
		if mood == "walk":
			var stride: float = sin(time_seconds * TAU + i * PI)
			leg_joints[i].rotation.x = stride * 0.43
			arm_joints[i].rotation.x = -stride * 0.37
			driver.position.y = absf(cos(time_seconds * TAU)) * 0.025
		elif mood == "cheer":
			arm_joints[i].rotation.z = side * (2.35 + sin(time_seconds * TAU) * 0.12)
			arm_joints[i].rotation.x = 0.12
			elbow_joints[i].rotation.x = 0.30
			driver.position.y = absf(sin(time_seconds * PI)) * 0.045
			head.rotation.z = sin(time_seconds * TAU) * 0.035
		elif mood == "help":
			arm_joints[i].rotation.z = side * (0.43 + breath * 0.05)
			arm_joints[i].rotation.x = 0.35
			elbow_joints[i].rotation.x = 0.65
			elbow_joints[i].rotation.z = side * 0.2
		elif mood == "think" and i == 1:
			arm_joints[i].rotation.z = 0.38
			arm_joints[i].rotation.x = 0.92
			elbow_joints[i].rotation.x = 1.42
			elbow_joints[i].rotation.y = -0.6
			head.rotation.z = -0.11
			head.rotation.y = 0.08
		elif mood == "speaking":
			arm_joints[i].rotation.x = 0.18 + sin(time_seconds * TAU + i) * 0.10
			elbow_joints[i].rotation.x = 0.4
	for i in range(ear_joints.size()):
		var side: float = -1.0 if i == 0 else 1.0
		ear_joints[i].rotation.z = -side * 0.23 + sin(time_seconds * cycle + i * 0.7) * 0.018
	if tail:
		tail.rotation.y = 0.7 + sin(time_seconds * cycle) * (0.18 if mood == "cheer" else 0.08)
	if jaw:
		jaw.rotation.x = clampf(voice_open, 0.0, 1.0) * 0.6
		jaw.position.y = -0.257 - clampf(voice_open, 0.0, 1.0) * 0.044


func _animal_id(value: String) -> String:
	return {"lumo": "fox", "nova": "rabbit", "milo": "otter"}.get(value, value)


func _style_id(value: String) -> String:
	return value if value in ["comet", "glider", "turbo"] else "comet"


func configure_variant(value: String) -> void:
	kart_style = _style_id(value)
	_style_was_selected = true
	if _built:
		_rebuild()


func set_kart_style(value: String) -> void:
	configure_variant(value)


func set_driver_character(value: String) -> void:
	animal = _animal_id(value)
	if _built:
		_rebuild()


func set_speaking(amount: float) -> void:
	speaking_amount = clampf(amount, 0.0, 1.0)


func set_graphics_quality(profile: String) -> void:
	detail_distance = 14.0 if profile in ["light", "low"] else (22.0 if profile == "medium" else FAR_DETAIL_DISTANCE)
	detail_check_time = 0.0


func _rebuild() -> void:
	for child in get_children():
		child.free()
	wheel_pivots.clear()
	wheel_rotors.clear()
	eyes.clear()
	flames.clear()
	sparks.clear()
	near_meshes.clear()
	arm_joints.clear()
	elbow_joints.clear()
	leg_joints.clear()
	ear_joints.clear()
	head = null
	tail = null
	jaw = null
	far_mesh = null
	far_detail = false
	if companion_mode:
		_make_driver()
		_merge_static(self)
	else:
		_build()
	_built = true


func _mat(color: Color, metal: float = 0.0, rough: float = 0.5, glow: float = 0.0) -> StandardMaterial3D:
	# Shared finish families keep mobile draw calls bounded across decorative details.
	metal = 0.0 if metal < 0.15 else (0.35 if metal < 0.5 else 0.7)
	rough = 0.26 if rough < 0.38 else (0.56 if rough < 0.7 else 0.82)
	var key: String = color.to_html() + ":" + str(metal) + ":" + str(rough) + ":" + str(glow)
	if materials.has(key):
		return materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metal
	material.roughness = rough
	if metal > 0.2:
		material.clearcoat_enabled = true
		material.clearcoat = 0.65
		material.clearcoat_roughness = 0.18
	if glow > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = glow
	materials[key] = material
	return material


func _mesh(parent: Node3D, geometry: Mesh, at: Vector3, color: Color, metal: float = 0.0, rough: float = 0.5, glow: float = 0.0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = geometry
	node.position = at
	node.material_override = _mat(color, metal, rough, glow)
	parent.add_child(node)
	return node


func _ellipsoid(parent: Node3D, at: Vector3, size: Vector3, color: Color, metal: float = 0.0, rough: float = 0.5) -> MeshInstance3D:
	var small: bool = maxf(size.x, maxf(size.y, size.z)) < 0.09
	var geometry_key: String = "sphere_small" if small else "sphere"
	if not geometries.has(geometry_key):
		var geometry := SphereMesh.new()
		geometry.radius = 1.0
		geometry.height = 2.0
		geometry.radial_segments = 12 if small else 24
		geometry.rings = 6 if small else 12
		geometries[geometry_key] = geometry
	var node := _mesh(parent, geometries[geometry_key], at, color, metal, rough)
	node.scale = size
	return node


func _box(parent: Node3D, at: Vector3, size: Vector3, color: Color, metal: float = 0.0) -> MeshInstance3D:
	var key: String = "box:" + str(size)
	if not geometries.has(key):
		var geometry := BoxMesh.new()
		geometry.size = size
		geometries[key] = geometry
	return _mesh(parent, geometries[key], at, color, metal)


func _rod(parent: Node3D, start: Vector3, end: Vector3, radius: float, color: Color, metal: float = 0.0, rough: float = 0.5) -> MeshInstance3D:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = start.distance_to(end)
	cylinder.radial_segments = 12
	var node := _mesh(parent, cylinder, (start + end) * 0.5, color, metal, rough)
	node.quaternion = Quaternion(Vector3.UP, (end - start).normalized())
	return node


func _ring(parent: Node3D, at: Vector3, inner: float, outer: float, color: Color, metal: float = 0.0, glow: float = 0.0) -> MeshInstance3D:
	var key: String = "ring:" + str(inner) + ":" + str(outer)
	if not geometries.has(key):
		var geometry := TorusMesh.new()
		geometry.inner_radius = inner
		geometry.outer_radius = outer
		geometry.rings = 16 if outer < 0.1 else 28
		geometry.ring_segments = 6 if outer < 0.1 else 8
		geometries[key] = geometry
	return _mesh(parent, geometries[key], at, color, metal, 0.3, glow)


func _catmull(a: Vector4, b: Vector4, c: Vector4, d: Vector4, t: float) -> Vector4:
	return 0.5 * ((2.0 * b) + (-a + c) * t + (2.0 * a - 5.0 * b + 4.0 * c - d) * t * t + (-a + 3.0 * b - 3.0 * c + d) * t * t * t)


func _loft(rings: Array[Vector4], vertical: bool = false, sections: int = 28, steps: int = 4, power: float = 1.0) -> ArrayMesh:
	# Ring fields: longitudinal position, lateral radius, second radius, offset.
	# Catmull-Rom profiles make a continuous sculpted silhouette rather than stacked primitives.
	var samples: Array[Vector4] = []
	for index in range(rings.size() - 1):
		for j in range(steps):
			samples.append(_catmull(rings[maxi(0, index - 1)], rings[index], rings[index + 1], rings[mini(rings.size() - 1, index + 2)], float(j) / steps))
	samples.append(rings[-1])
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for row in range(samples.size()):
		var ring: Vector4 = samples[row]
		for segment in range(sections):
			var angle: float = TAU * float(segment) / float(sections)
			var cs: float = signf(cos(angle)) * pow(absf(cos(angle)), power)
			var sn: float = signf(sin(angle)) * pow(absf(sin(angle)), power)
			var point := Vector3(cs * maxf(0.002, ring.y), ring.w + sn * maxf(0.002, ring.z), ring.x)
			if vertical:
				point = Vector3(point.x, ring.x, ring.w + sn * maxf(0.002, ring.z))
			vertices.append(point)
			uvs.append(Vector2(float(segment) / sections, float(row) / (samples.size() - 1)))
			normals.append(Vector3.ZERO)
	for row in range(samples.size() - 1):
		for segment in range(sections):
			var a: int = row * sections + segment
			var b: int = (row + 1) * sections + segment
			var c: int = row * sections + (segment + 1) % sections
			var d: int = (row + 1) * sections + (segment + 1) % sections
			if vertical:
				indices.append_array(PackedInt32Array([a, c, b, c, d, b]))
			else:
				indices.append_array(PackedInt32Array([a, b, c, c, b, d]))
	for triangle in range(0, indices.size(), 3):
		var a: int = indices[triangle]
		var b: int = indices[triangle + 1]
		var c: int = indices[triangle + 2]
		var normal := (vertices[c] - vertices[a]).cross(vertices[b] - vertices[a])
		normals[a] += normal
		normals[b] += normal
		normals[c] += normal
	for i in range(normals.size()):
		normals[i] = normals[i].normalized()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if sections > 12:
		result.set_meta("far_geometry", _loft(rings, vertical, 8, 1, power))
	return result


func _ribbon(parent: Node3D, points: Array[Vector3], radius: float, color: Color, metal: float = 0.0, glow: float = 0.0) -> void:
	# Small tailored seams follow the surface. Batching combines them into one surface.
	for i in range(points.size() - 1):
		var part := _rod(parent, points[i], points[i + 1], radius, color, metal, 0.25)
		if glow > 0:
			part.material_override = _mat(color, metal, 0.25, glow)
		_ellipsoid(parent, points[i], Vector3.ONE * radius, color, metal, 0.25)


func _build() -> void:
	name = "Kart_" + animal + "_" + kart_style
	var body := Node3D.new()
	body.name = "AuroraCoachwork"
	add_child(body)
	var width: float = 1.1 if kart_style == "turbo" else (0.91 if kart_style == "glider" else 1.0)
	body.scale.x = width
	var paint: Color = vehicle_color.lerp(Color("297cc0"), 0.25)
	var shell: Array[Vector4] = [
		Vector4(-1.16, 0.015, 0.018, 0.50), Vector4(-1.07, 0.24, 0.065, 0.51),
		Vector4(-0.81, 0.45, 0.17, 0.52), Vector4(-0.48, 0.58, 0.20, 0.50),
		Vector4(0.06, 0.61, 0.14, 0.45), Vector4(0.55, 0.61, 0.15, 0.46),
		Vector4(0.91, 0.48, 0.15, 0.49), Vector4(1.05, 0.20, 0.065, 0.50),
		Vector4(1.08, 0.01, 0.015, 0.50)]
	_mesh(body, _loft(shell, false, 32, 5, 0.75), Vector3.ZERO, paint, 0.42, 0.24)
	var hull := _mesh(body, _loft([
		Vector4(-1.09, 0.015, 0.01, 0.34), Vector4(-0.75, 0.51, 0.08, 0.33),
		Vector4(0.02, 0.63, 0.09, 0.31), Vector4(0.74, 0.54, 0.08, 0.32),
		Vector4(1.03, 0.01, 0.01, 0.36)], false, 24, 3, 0.6), Vector3.ZERO, INK, 0.2, 0.35)
	hull.name = "CarbonLowerHull"
	# Long bonnet, raised shoulder pods, smooth white nose stripe.
	_mesh(body, _loft([
		Vector4(-1.10, 0.01, 0.01, 0.54), Vector4(-0.9, 0.28, 0.06, 0.60),
		Vector4(-0.65, 0.37, 0.12, 0.67), Vector4(-0.43, 0.32, 0.115, 0.70),
		Vector4(-0.32, 0.25, 0.04, 0.65), Vector4(-0.29, 0.01, 0.01, 0.60)], false), Vector3.ZERO, paint.lightened(0.1), 0.48, 0.22)
	_mesh(body, _loft([
		Vector4(-1.055, 0.015, 0.004, 0.584), Vector4(-0.85, 0.075, 0.01, 0.682),
		Vector4(-0.60, 0.085, 0.012, 0.795), Vector4(-0.43, 0.075, 0.01, 0.810),
		Vector4(-0.36, 0.01, 0.003, 0.78)], false, 20, 3), Vector3.ZERO, WHITE, 0.18, 0.27)
	for side in [-1.0, 1.0]:
		var sidepod := _mesh(body, _loft([
			Vector4(-0.52, 0.008, 0.015, 0.54), Vector4(-0.30, 0.12, 0.145, 0.54),
			Vector4(0.32, 0.12, 0.14, 0.52), Vector4(0.69, 0.055, 0.10, 0.53),
			Vector4(0.78, 0.008, 0.01, 0.55)], false, 24, 4, 0.8), Vector3(side * 0.53, 0, 0), paint, 0.4, 0.24)
		sidepod.name = "SculptedSidePod"
		_ribbon(body, [Vector3(side * 0.61, 0.58, -0.31), Vector3(side * 0.65, 0.56, 0.0), Vector3(side * 0.63, 0.55, 0.36), Vector3(side * 0.55, 0.55, 0.64)], 0.014, ICE, 0.15, 0.9)
		for vent in range(3):
			var panel := _box(body, Vector3(side * 0.645, 0.60, 0.20 + vent * 0.11), Vector3(0.012, 0.08, 0.044), INK, 0.4)
			panel.rotation.z = side * -0.18
		_ribbon(body, [Vector3(side * 0.19, 0.624, -1.079), Vector3(side * 0.34, 0.639, -0.979), Vector3(side * 0.42, 0.619, -0.854)], 0.018, WHITE, 0.2, 1.0)
		# The light blades are inset into dark headlight housings.
		_ribbon(body, [Vector3(side * 0.19, 0.59, -1.05), Vector3(side * 0.35, 0.60, -0.952), Vector3(side * 0.43, 0.58, -0.83)], 0.037, INK, 0.4)
		# Exhausts have an inset nozzle and a separate animated boost flame.
		_rod(body, Vector3(side * 0.33, 0.46, 0.79), Vector3(side * 0.37, 0.52, 1.16), 0.105, CHROME, 0.75, 0.24)
		_rod(body, Vector3(side * 0.37, 0.52, 1.14), Vector3(side * 0.371, 0.52, 1.18), 0.079, INK, 0.3)
		var nozzle := _ring(body, Vector3(side * 0.37, 0.52, 1.183), 0.071, 0.084, ICE, 0.3, 0.8)
		nozzle.rotation.x = PI / 2.0
		var flame := _mesh(self, _loft([Vector4(0, 0.055, 0.055, 0), Vector4(0.18, 0.10, 0.09, 0), Vector4(0.60, 0.002, 0.002, 0)], false, 16, 3), Vector3(side * 0.37 * width, 0.52, 1.20), ICE, 0.0, 0.25, 2.0)
		flame.hide()
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flames.append(flame)
	# Cockpit shell, padded seat and roll hoop with integrated light.
	_mesh(body, _loft([
		Vector4(0.63, 0.21, 0.12, 0.18), Vector4(0.79, 0.31, 0.12, 0.23),
		Vector4(1.09, 0.33, 0.11, 0.29), Vector4(1.16, 0.25, 0.05, 0.30)], true, 24, 4, 0.65), Vector3.ZERO, INK, 0.12, 0.65)
	_ellipsoid(body, Vector3(0, 0.68, 0.09), Vector3(0.30, 0.095, 0.30), NAVY, 0.0, 0.78)
	_ribbon(body, [Vector3(-0.32, 0.72, 0.34), Vector3(-0.34, 1.11, 0.40), Vector3(-0.23, 1.19, 0.43), Vector3(0.23, 1.19, 0.43), Vector3(0.34, 1.11, 0.40), Vector3(0.32, 0.72, 0.34)], 0.03, CHROME, 0.6)
	# Wing is a shaped aerofoil, with style-specific stance and endplates.
	var wing_height: float = 1.04 if kart_style == "glider" else (0.95 if kart_style == "turbo" else 0.89)
	var wing_span: float = 1.65 if kart_style == "glider" else 1.35
	for side in [-1.0, 1.0]:
		_rod(body, Vector3(side * 0.40, 0.57, 0.77), Vector3(side * 0.45, wing_height, 0.95), 0.035, INK, 0.45)
	var wing := _mesh(body, _loft([
		Vector4(-wing_span / 2, 0.008, 0.008, 0), Vector4(-wing_span * 0.43, 0.18, 0.040, 0),
		Vector4(0.0, 0.17, 0.047, 0), Vector4(wing_span * 0.43, 0.18, 0.04, 0),
		Vector4(wing_span / 2, 0.008, 0.008, 0)], false, 24, 3, 0.8), Vector3(0, wing_height, 0.98), WHITE, 0.36, 0.24)
	wing.rotation.y = PI / 2.0
	_ribbon(body, [Vector3(-wing_span * 0.42, wing_height + 0.037, 1.05), Vector3(0, wing_height + 0.047, 1.05), Vector3(wing_span * 0.42, wing_height + 0.037, 1.05)], 0.012, ICE, 0.3, 0.7)
	if kart_style == "turbo":
		for side in [-1.0, 1.0]:
			_mesh(body, _loft([Vector4(-0.48, 0.01, 0.01, 0), Vector4(-0.36, 0.11, 0.12, 0), Vector4(0.39, 0.13, 0.12, 0), Vector4(0.60, 0.01, 0.01, 0)], false, 20, 3), Vector3(side * 0.70, 0.54, 0), WHITE, 0.38, 0.3)
	for side in [-1.0, 1.0]:
		for axle in [-0.66, 0.66]:
			_make_wheel(side, axle, width)
	_make_steering_wheel()
	_make_driver()
	_make_far_mesh()
	_merge_static(self)


func _make_wheel(side: float, axle: float, stance: float) -> void:
	var pivot := Node3D.new()
	pivot.name = "SteeringHub" if axle < 0 else "RearHub"
	pivot.position = Vector3(side * 0.77 * stance, 0.35, axle)
	pivot.set_meta("front", axle < 0)
	add_child(pivot)
	wheel_pivots.append(pivot)
	var rotor := Node3D.new()
	rotor.rotation.z = PI / 2.0
	pivot.add_child(rotor)
	wheel_rotors.append(rotor)
	# Rounded shoulder racing tyre, with actual recessed shoulder grooves.
	var tyre_profile: Array[Vector4] = [Vector4(-0.19, 0.23, 0.23, 0), Vector4(-0.17, 0.30, 0.30, 0), Vector4(-0.105, 0.35, 0.35, 0), Vector4(0.105, 0.35, 0.35, 0), Vector4(0.17, 0.30, 0.30, 0), Vector4(0.19, 0.23, 0.23, 0)]
	_mesh(rotor, _loft(tyre_profile, true, 32, 3), Vector3.ZERO, Color("0c1422"), 0.02, 0.83)
	for shoulder in [-0.095, 0.095]:
		_ring(rotor, Vector3(0, shoulder, 0), 0.346, 0.352, Color("242f40"), 0.0)
	var outside: float = -side * 0.193
	var brake := CylinderMesh.new()
	brake.top_radius = 0.205
	brake.bottom_radius = 0.205
	brake.height = 0.014
	brake.radial_segments = 24
	_mesh(rotor, brake, Vector3(0, outside, 0), Color("233247"), 0.6, 0.4)
	_ring(rotor, Vector3(0, outside - side * 0.018, 0), 0.199, 0.232, CHROME, 0.78)
	_ring(rotor, Vector3(0, outside - side * 0.027, 0), 0.224, 0.231, ICE, 0.3, 0.4)
	for spoke in range(5):
		var angle: float = float(spoke) * TAU / 5.0
		var start := Vector3(cos(angle) * 0.047, outside - side * 0.034, sin(angle) * 0.047)
		var end := Vector3(cos(angle + 0.18) * 0.207, outside - side * 0.023, sin(angle + 0.18) * 0.207)
		_rod(rotor, start, end, 0.022, WHITE, 0.64, 0.22)
		var valve := Vector3(cos(angle + 0.4) * 0.16, outside - side * 0.01, sin(angle + 0.4) * 0.16)
		_ellipsoid(rotor, valve, Vector3(0.013, 0.010, 0.013), INK)
	_ellipsoid(rotor, Vector3(0, outside - side * 0.04, 0), Vector3(0.071, 0.029, 0.071), vehicle_color, 0.65, 0.25)
	_ellipsoid(rotor, Vector3(0, outside - side * 0.065, 0), Vector3(0.026, 0.01, 0.026), ICE, 0.35, 0.2)
	# Contact tread slashes stay restrained rather than producing noisy checker tyres.
	for tread in range(18):
		var angle: float = float(tread) * TAU / 18.0
		var at := Vector3(cos(angle) * 0.351, 0, sin(angle) * 0.351)
		var cut := _box(rotor, at, Vector3(0.014, 0.16, 0.012), Color("070d16"))
		cut.rotation.y = -angle
		cut.rotation.z = 0.22
	_rod(self, Vector3(side * 0.38, 0.36, axle - 0.09), pivot.position + Vector3(0, 0, 0.06), 0.026, CHROME, 0.72)
	_rod(self, Vector3(side * 0.38, 0.36, axle + 0.09), pivot.position - Vector3(0, 0, 0.06), 0.026, CHROME, 0.72)
	var spring_start := Vector3(side * 0.46, 0.64, axle)
	var spring_end := pivot.position + Vector3(0, 0.035, 0)
	_rod(self, spring_start, spring_end, 0.032, CHROME, 0.7)
	for loop in range(5):
		var coil := _ring(self, spring_start.lerp(spring_end, 0.19 + float(loop) * 0.13), 0.048, 0.063, ICE, 0.48)
		coil.quaternion = Quaternion(Vector3.UP, (spring_end - spring_start).normalized())
	if axle > 0:
		var spark := _mesh(self, _loft([Vector4(0, 0.07, 0.013, 0), Vector4(0.2, 0.03, 0.035, 0), Vector4(0.45, 0.002, 0.002, 0)], false, 12, 2), pivot.position + Vector3(0, -0.29, 0.14), ICE, 0, 0.3, 2.0)
		spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		spark.hide()
		sparks.append(spark)


func _make_steering_wheel() -> void:
	steering_wheel = Node3D.new()
	steering_wheel.name = "SteeringWheel"
	steering_wheel.position = Vector3(0, 1.035, -0.33)
	steering_wheel.rotation.x = -0.45
	add_child(steering_wheel)
	var wheel := _ring(steering_wheel, Vector3.ZERO, 0.135, 0.175, INK)
	wheel.rotation.x = PI / 2
	_rod(steering_wheel, Vector3(-0.13, 0, 0), Vector3(0.13, 0, 0), 0.022, CHROME, 0.6)
	_rod(steering_wheel, Vector3(0, 0, 0), Vector3(0, -0.13, 0), 0.02, CHROME, 0.6)
	_ellipsoid(steering_wheel, Vector3(0, 0, -0.023), Vector3(0.065, 0.042, 0.017), NAVY, 0.4, 0.3)
	_ellipsoid(steering_wheel, Vector3(0, 0, -0.04), Vector3(0.018, 0.018, 0.007), ICE, 0.3, 0.25)
	_rod(self, Vector3(0, 0.68, -0.22), steering_wheel.position, 0.035, INK, 0.4)


func _make_driver() -> void:
	var fur: Color = {"fox": Color("ed762d"), "otter": Color("ad8064"), "rabbit": Color("cedbe8"), "badger": Color("64718a"), "cat": Color("d4b396")}.get(animal, Color("ed762d"))
	var cream := Color("ffecd1") if animal == "fox" else Color("eaf4f9")
	var fur_shadow: Color = fur.darkened(0.18)
	driver = Node3D.new()
	driver.name = "RacerRig"
	add_child(driver)
	# Fitted racing suit with shoulder yoke, collar, sleeves and a distinct white back panel.
	_mesh(driver, _loft([Vector4(0.77, 0.19, 0.19, 0.13), Vector4(0.90, 0.25, 0.20, 0.13), Vector4(1.12, 0.26, 0.195, 0.10), Vector4(1.27, 0.28, 0.16, 0.11), Vector4(1.32, 0.17, 0.11, 0.11)], true, 28, 4, 0.88), Vector3.ZERO, NAVY, 0, 0.7)
	_mesh(driver, _loft([Vector4(0.89, 0.10, 0.017, -0.073), Vector4(1.02, 0.155, 0.022, -0.093), Vector4(1.21, 0.17, 0.020, -0.070), Vector4(1.29, 0.11, 0.012, -0.035)], true, 22, 4), Vector3.ZERO, WHITE, 0.04, 0.57)
	_mesh(driver, _loft([Vector4(0.91, 0.11, 0.015, 0.332), Vector4(1.12, 0.17, 0.015, 0.302), Vector4(1.28, 0.17, 0.014, 0.244), Vector4(1.31, 0.09, 0.012, 0.223)], true, 22, 4), Vector3.ZERO, WHITE, 0.03, 0.65)
	var collar := _ring(driver, Vector3(0, 1.32, 0.10), 0.112, 0.163, ICE, 0.18)
	collar.scale.z = 0.8
	_ribbon(driver, [Vector3(0, 0.92, -0.112), Vector3(0, 1.12, -0.112), Vector3(0, 1.28, -0.071)], 0.008, CHROME, 0.45)
	_star(driver, Vector3(0, 1.15, -0.124), 0.060, ICE)
	var back_star := _star(driver, Vector3(0, 1.16, 0.326), 0.074, NAVY)
	back_star.rotation.y = PI
	if companion_mode:
		_make_companion_limbs(fur)
	else:
		drive_arm_right = Node3D.new()
		drive_arm_right.name = "DriveArmRight"
		driver.add_child(drive_arm_right)
		for side in [-1.0, 1.0]:
			var arm_parent: Node3D = driver if side < 0 else drive_arm_right
			var sleeve := _mesh(arm_parent, _loft([Vector4(0.0, 0.07, 0.065, 0), Vector4(0.13, 0.11, 0.10, 0), Vector4(0.29, 0.081, 0.08, 0), Vector4(0.42, 0.065, 0.060, 0)], true, 20, 4), Vector3(side * 0.24, 1.20, 0.10), NAVY, 0.03, 0.72)
			sleeve.quaternion = Quaternion(Vector3.UP, Vector3(side * 0.13, -0.22, -0.37).normalized())
			_ellipsoid(arm_parent, Vector3(side * 0.29, 1.215, 0.015), Vector3(0.092, 0.056, 0.096), WHITE, 0.07, 0.6)
			_ribbon(arm_parent, [Vector3(side * 0.318, 1.225, 0.07), Vector3(side * 0.344, 1.11, -0.12), Vector3(side * 0.31, 1.03, -0.27)], 0.012, ICE, 0.12)
			_ellipsoid(driver, Vector3(side * 0.16, 0.81, -0.24), Vector3(0.105, 0.105, 0.20), NAVY, 0, 0.72)
			var glove := _ellipsoid(arm_parent, Vector3(side * 0.16, 1.055, -0.34), Vector3(0.079, 0.070, 0.083), WHITE, 0, 0.68)
			glove.rotation.z = side * -0.2
			for digit in range(3):
				_ellipsoid(arm_parent, Vector3(side * (0.126 + digit * 0.027), 1.036, -0.393), Vector3(0.016, 0.036, 0.022), WHITE, 0, 0.68)
			_ellipsoid(driver, Vector3(side * 0.18, 0.80, -0.39), Vector3(0.12, 0.09, 0.14), WHITE, 0.08, 0.6)
		_make_cheer_arm()
	head = Node3D.new()
	head.name = "LumoHead"
	head.position = Vector3(0, 1.68, 0.07)
	driver.add_child(head)
	var head_width: float = 0.41 if animal != "rabbit" else 0.36
	var head_profile: Array[Vector4] = [Vector4(-0.32, 0.055, 0.060, -0.025), Vector4(-0.26, 0.27, 0.225, -0.003), Vector4(-0.13, head_width, 0.30, 0.006), Vector4(0.055, head_width * 0.98, 0.326, 0.015), Vector4(0.23, 0.31, 0.277, 0.025), Vector4(0.33, 0.17, 0.17, 0.038), Vector4(0.375, 0.008, 0.012, 0.038)]
	_mesh(head, _loft(head_profile, true, 36, 5), Vector3.ZERO, fur, 0, 0.82)
	# The cheek mask is sculpted as two swept, tapered volumes, with a joined muzzle.
	for side in [-1.0, 1.0]:
		var cheek := _mesh(head, _loft([Vector4(-0.14, 0.018, 0.014, -0.035), Vector4(-0.025, 0.143, 0.123, -0.020), Vector4(0.115, 0.138, 0.112, -0.010), Vector4(0.225, 0.087, 0.062, 0.020), Vector4(0.30, 0.003, 0.003, 0.047)], false, 26, 4), Vector3(side * 0.14, -0.145, -0.252), cream, 0, 0.86)
		cheek.rotation.y = side * PI / 2
		# Purposeful tufts on cheeks and brow establish a fox silhouette at race distance.
		for tuft in range(2):
			var leaf := _mesh(head, _loft([Vector4(0, 0.05, 0.022, 0), Vector4(0.055, 0.055, 0.035, 0), Vector4(0.115, 0.002, 0.002, 0.018)], true, 16, 3), Vector3(side * (0.28 + tuft * 0.025), -0.11 - tuft * 0.06, -0.15), cream)
			leaf.rotation.z = -side * 1.20
		_make_ear(side, fur, cream)
		_make_eye(side, fur_shadow)
		# Soft brow arc gives the neutral expression a curious, friendly shape.
		var brow: Array[Vector3] = []
		for p in range(6):
			var t: float = float(p) / 5.0
			brow.append(Vector3(side * (0.075 + t * 0.195), 0.205 + sin(t * PI) * 0.047 - t * 0.014, -0.277 + t * 0.018))
		_ribbon(head, brow, 0.018, fur.darkened(0.5))
	var muzzle: Array[Vector4] = [Vector4(-0.455, 0.038, 0.028, -0.101), Vector4(-0.418, 0.113, 0.060, -0.122), Vector4(-0.351, 0.168, 0.090, -0.135), Vector4(-0.264, 0.15, 0.08, -0.15), Vector4(-0.21, 0.01, 0.012, -0.15)]
	_mesh(head, _loft(muzzle, false, 28, 4), Vector3.ZERO, cream, 0, 0.83)
	# A small triangular, polished nose and a real mouth cavity underneath.
	var nose := _mesh(head, _loft([Vector4(-0.16, 0.004, 0.016, -0.453), Vector4(-0.112, 0.075, 0.044, -0.463), Vector4(-0.079, 0.060, 0.032, -0.449), Vector4(-0.068, 0.004, 0.005, -0.435)], true, 24, 4), Vector3.ZERO, Color("2a1d22"), 0.08, 0.22)
	nose.name = "SculptedNose"
	_ellipsoid(head, Vector3(-0.020, -0.09, -0.493), Vector3(0.020, 0.009, 0.005), Color("ae8f85"), 0, 0.25)
	_ellipsoid(head, Vector3(0, -0.236, -0.289), Vector3(0.115, 0.065, 0.055), Color("472e39"), 0, 0.7)
	jaw = Node3D.new()
	jaw.name = "MouthViseme"
	jaw.position = Vector3(0, -0.257, -0.263)
	head.add_child(jaw)
	_ellipsoid(jaw, Vector3(0, 0, -0.018), Vector3(0.123, 0.033, 0.054), cream, 0, 0.82)
	_ellipsoid(jaw, Vector3(0, 0.021, -0.041), Vector3(0.049, 0.014, 0.019), Color("df8890"), 0, 0.58)
	_ribbon(head, [Vector3(-0.127, -0.192, -0.32), Vector3(-0.101, -0.216, -0.342), Vector3(-0.057, -0.221, -0.352)], 0.008, Color("714333"))
	_ribbon(head, [Vector3(0.127, -0.192, -0.32), Vector3(0.101, -0.216, -0.342), Vector3(0.057, -0.221, -0.352)], 0.008, Color("714333"))
	for tuft in range(3):
		var quiff := _mesh(head, _loft([Vector4(0, 0.034, 0.03, 0), Vector4(0.09, 0.048, 0.047, 0), Vector4(0.18, 0.003, 0.005, 0.058)], true, 18, 4), Vector3(-0.10 + tuft * 0.068, 0.30, -0.06 + tuft * 0.018), fur)
		quiff.rotation.z = 0.15 + tuft * 0.14
	# A small earpiece integrates the racing identity without obscuring the face.
	for side in [-1.0, 1.0]:
		_ellipsoid(head, Vector3(side * 0.372, 0.01, 0.085), Vector3(0.030, 0.085, 0.075), NAVY, 0.35, 0.3)
		_ellipsoid(head, Vector3(side * 0.395, 0.01, 0.080), Vector3(0.012, 0.047, 0.043), ICE, 0.45, 0.22)
	if animal == "badger":
		for side in [-1.0, 1.0]:
			var stripe := _mesh(head, _loft([Vector4(-0.15, 0.028, 0.014, -0.28), Vector4(0.06, 0.059, 0.013, -0.310), Vector4(0.29, 0.039, 0.01, -0.172)], true, 16, 4), Vector3(side * 0.17, 0, 0), Color("e8f2fa"))
			stripe.rotation.z = side * -0.16
	_make_tail(fur, cream)


func _make_cheer_arm() -> void:
	# Erhobener rechter Arm für den Jubel im Ziel, sonst unsichtbar.
	cheer_arm = Node3D.new()
	cheer_arm.name = "CheerArm"
	cheer_arm.position = Vector3(0.29, 1.215, 0.015)
	cheer_arm.visible = false
	driver.add_child(cheer_arm)
	_mesh(cheer_arm, _loft([Vector4(0.0, 0.07, 0.065, 0), Vector4(0.13, 0.11, 0.10, 0), Vector4(0.29, 0.081, 0.08, 0), Vector4(0.40, 0.065, 0.060, 0)], true, 18, 3), Vector3.ZERO, NAVY, 0.02, 0.75)
	_ribbon(cheer_arm, [Vector3(0.07, 0.02, 0.0), Vector3(0.07, 0.20, 0.0), Vector3(0.06, 0.36, 0.0)], 0.011, ICE, 0.15)
	var glove := _ellipsoid(cheer_arm, Vector3(0, 0.46, 0), Vector3(0.085, 0.09, 0.085), WHITE, 0, 0.68)
	glove.rotation.x = -0.2
	# Nach einem Neuaufbau (Grafikstufe) bleibt die Feier sichtbar.
	if celebration_place > 0:
		celebrate(celebration_place)


## Lumo reagiert auf seine Platzierung: 1 = beide Gesten + Kopf hoch,
## 2/3 = Faust in die Luft, ab 4 = freundliches Nicken (keine Strafe).
func celebrate(place: int) -> void:
	celebration_place = maxi(0, place)
	celebration_time = 0.0
	if is_instance_valid(cheer_arm):
		cheer_arm.visible = celebration_place >= 1 and celebration_place <= 3
	if is_instance_valid(drive_arm_right):
		drive_arm_right.visible = not (celebration_place >= 1 and celebration_place <= 3)


func clear_celebration() -> void:
	celebrate(0)


func _make_companion_limbs(fur: Color) -> void:
	for side in [-1.0, 1.0]:
		var shoulder := Node3D.new()
		shoulder.name = "ShoulderLeft" if side < 0 else "ShoulderRight"
		shoulder.position = Vector3(side * 0.25, 1.255, 0.09)
		driver.add_child(shoulder)
		arm_joints.append(shoulder)
		_mesh(shoulder, _loft([Vector4(-0.31, 0.071, 0.071, 0), Vector4(-0.22, 0.087, 0.087, 0), Vector4(-0.04, 0.102, 0.094, 0), Vector4(0.025, 0.055, 0.050, 0)], true, 22, 4), Vector3.ZERO, NAVY, 0.02, 0.75)
		_ellipsoid(shoulder, Vector3(side * 0.01, -0.018, -0.030), Vector3(0.09, 0.065, 0.09), WHITE, 0.02, 0.62)
		_ribbon(shoulder, [Vector3(side * 0.087, -0.06, -0.023), Vector3(side * 0.082, -0.18, -0.026), Vector3(side * 0.070, -0.28, -0.023)], 0.011, ICE, 0.15)
		var elbow := Node3D.new()
		elbow.name = "ElbowJoint"
		elbow.position = Vector3(0, -0.29, 0)
		shoulder.add_child(elbow)
		elbow_joints.append(elbow)
		_mesh(elbow, _loft([Vector4(-0.27, 0.055, 0.052, 0), Vector4(-0.21, 0.061, 0.062, 0), Vector4(-0.02, 0.073, 0.073, 0), Vector4(0.025, 0.050, 0.051, 0)], true, 20, 4), Vector3.ZERO, NAVY, 0.02, 0.73)
		var cuff := _ring(elbow, Vector3(0, -0.23, 0), 0.055, 0.070, WHITE)
		cuff.scale.y = 0.6
		_ellipsoid(elbow, Vector3(0, -0.315, -0.006), Vector3(0.076, 0.096, 0.048), fur, 0, 0.8)
		for digit in range(3):
			_ellipsoid(elbow, Vector3(-0.047 + digit * 0.043, -0.366, -0.009), Vector3(0.024, 0.057, 0.034), fur, 0, 0.8)
		_ellipsoid(elbow, Vector3(-side * 0.067, -0.294, -0.018), Vector3(0.031, 0.045, 0.035), fur, 0, 0.8)
		var hip := Node3D.new()
		hip.name = "HipLeft" if side < 0 else "HipRight"
		hip.position = Vector3(side * 0.14, 0.85, 0.12)
		driver.add_child(hip)
		leg_joints.append(hip)
		_mesh(hip, _loft([Vector4(-0.49, 0.079, 0.083, 0), Vector4(-0.32, 0.097, 0.095, 0.015), Vector4(-0.09, 0.125, 0.120, 0), Vector4(0.028, 0.091, 0.10, 0)], true, 22, 4), Vector3.ZERO, NAVY, 0.02, 0.74)
		_ribbon(hip, [Vector3(side * 0.115, -0.05, 0), Vector3(side * 0.105, -0.24, 0.01), Vector3(side * 0.08, -0.45, 0)], 0.012, ICE, 0.1)
		_mesh(hip, _loft([Vector4(-0.72, 0.075, 0.082, -0.006), Vector4(-0.62, 0.09, 0.09, 0), Vector4(-0.47, 0.078, 0.081, 0)], true, 20, 4), Vector3.ZERO, fur, 0, 0.8)
		_ellipsoid(hip, Vector3(0, -0.748, -0.072), Vector3(0.12, 0.090, 0.175), WHITE, 0.06, 0.56)
		_ellipsoid(hip, Vector3(0, -0.811, -0.069), Vector3(0.119, 0.027, 0.17), NAVY, 0.1, 0.7)
		_ribbon(hip, [Vector3(-0.105, -0.76, -0.11), Vector3(0, -0.756, -0.229), Vector3(0.105, -0.76, -0.11)], 0.012, ICE, 0.25)


func _make_ear(side: float, fur: Color, cream: Color) -> void:
	var ear := Node3D.new()
	ear.name = "Ear"
	ear.position = Vector3(side * 0.273, 0.255, 0.035)
	ear.rotation.z = -side * 0.23
	head.add_child(ear)
	ear_joints.append(ear)
	if animal == "rabbit":
		_mesh(ear, _loft([Vector4(0, 0.073, 0.061, 0), Vector4(0.18, 0.093, 0.071, 0), Vector4(0.44, 0.076, 0.053, 0.025), Vector4(0.57, 0.008, 0.008, 0.034)], true, 24, 4), Vector3.ZERO, fur)
		_mesh(ear, _loft([Vector4(0.07, 0.023, 0.008, -0.057), Vector4(0.22, 0.051, 0.012, -0.071), Vector4(0.42, 0.039, 0.01, -0.029), Vector4(0.51, 0.004, 0.004, -0.01)], true, 20, 4), Vector3.ZERO, Color("d9a8b7"))
	elif animal in ["otter", "badger"]:
		_mesh(ear, _loft([Vector4(-0.055, 0.025, 0.032, 0), Vector4(0.035, 0.11, 0.079, 0), Vector4(0.12, 0.075, 0.055, 0), Vector4(0.16, 0.005, 0.005, 0)], true, 24, 4), Vector3.ZERO, fur.darkened(0.16))
		_ellipsoid(ear, Vector3(0, 0.05, -0.073), Vector3(0.06, 0.060, 0.012), cream)
	else:
		_mesh(ear, _loft([Vector4(-0.075, 0.085, 0.078, 0), Vector4(0.0, 0.124, 0.092, 0), Vector4(0.14, 0.103, 0.080, 0.006), Vector4(0.32, 0.046, 0.048, 0.017), Vector4(0.40, 0.003, 0.004, 0.024)], true, 28, 4), Vector3.ZERO, fur.darkened(0.27))
		_mesh(ear, _loft([Vector4(-0.033, 0.063, 0.026, -0.072), Vector4(0.055, 0.088, 0.035, -0.065), Vector4(0.17, 0.063, 0.028, -0.058), Vector4(0.31, 0.007, 0.005, -0.029)], true, 24, 4), Vector3.ZERO, cream)
		for fluff in range(3):
			var tuft := _mesh(ear, _loft([Vector4(0, 0.022, 0.012, 0), Vector4(0.05, 0.029, 0.018, 0), Vector4(0.105, 0.002, 0.002, 0)], true, 12, 3), Vector3(-0.030 + fluff * 0.031, 0.012 + (fluff % 2) * 0.034, -0.10), cream)
			tuft.rotation.z = (fluff - 1) * -0.30


func _make_eye(side: float, fur_shadow: Color) -> void:
	var eye := Node3D.new()
	eye.name = "Eye"
	eye.position = Vector3(side * 0.169, 0.052, -0.282)
	eye.rotation.y = -side * 0.12
	head.add_child(eye)
	eyes.append(eye)
	_ellipsoid(eye, Vector3(0, 0.005, 0.006), Vector3(0.119, 0.156, 0.064), fur_shadow)
	_ellipsoid(eye, Vector3(0, 0, -0.009), Vector3(0.104, 0.142, 0.067), WHITE, 0, 0.3)
	_ellipsoid(eye, Vector3(-side * 0.013, -0.009, -0.066), Vector3(0.067, 0.089, 0.018), Color("634122") if animal == "fox" else Color("287788"), 0.08, 0.22)
	_ellipsoid(eye, Vector3(-side * 0.013, -0.004, -0.081), Vector3(0.043, 0.066, 0.013), Color("111b24"), 0.10, 0.15)
	_ellipsoid(eye, Vector3(-0.026, 0.032, -0.093), Vector3(0.019, 0.025, 0.008), Color.WHITE, 0, 0.1)
	_ellipsoid(eye, Vector3(0.020, -0.038, -0.093), Vector3(0.007, 0.010, 0.004), Color.WHITE, 0, 0.1)


func _make_tail(fur: Color, cream: Color) -> void:
	tail = Node3D.new()
	tail.name = "TailJoint"
	tail.position = Vector3(0.22, 0.94, 0.31)
	tail.rotation.y = 0.5
	tail.rotation.x = -0.15
	driver.add_child(tail)
	if animal == "rabbit":
		_ellipsoid(tail, Vector3(0.05, 0.03, 0.18), Vector3(0.13, 0.14, 0.15), cream, 0, 0.9)
		return
	var scale_factor: float = 0.8 if animal in ["otter", "badger"] else 1.0
	var tail_shape: Array[Vector4] = [Vector4(0.00, 0.055, 0.075, 0), Vector4(0.17, 0.115, 0.13, 0.00), Vector4(0.38, 0.195, 0.22, 0.07), Vector4(0.61, 0.22, 0.24, 0.21), Vector4(0.77, 0.165, 0.21, 0.37), Vector4(0.84, 0.072, 0.13, 0.56), Vector4(0.83, 0.004, 0.008, 0.73)]
	var mesh := _mesh(tail, _loft(tail_shape, false, 28, 4), Vector3.ZERO, fur, 0, 0.87)
	mesh.scale *= scale_factor
	if animal in ["fox", "cat"]:
		_mesh(tail, _loft([Vector4(0.60, 0.207, 0.205, 0.24), Vector4(0.73, 0.181, 0.225, 0.345), Vector4(0.83, 0.092, 0.145, 0.52), Vector4(0.85, 0.039, 0.075, 0.655), Vector4(0.83, 0.004, 0.008, 0.745)], false, 26, 4), Vector3.ZERO, cream, 0, 0.88)


func _star(parent: Node3D, at: Vector3, size: float, color: Color) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(10):
		var angle_a: float = -PI / 2 + float(i) * TAU / 10.0
		var angle_b: float = -PI / 2 + float(i + 1) * TAU / 10.0
		var ra: float = size if i % 2 == 0 else size * 0.48
		var rb: float = size if (i + 1) % 2 == 0 else size * 0.48
		surface.set_normal(Vector3.FORWARD)
		surface.add_vertex(Vector3.ZERO)
		surface.add_vertex(Vector3(cos(angle_a) * ra, -sin(angle_a) * ra, 0))
		surface.add_vertex(Vector3(cos(angle_b) * rb, -sin(angle_b) * rb, 0))
	return _mesh(parent, surface.commit(), at, color, 0.2, 0.3)


func _merge_static(parent: Node3D) -> void:
	# One surface per PBR material family, preserving all animated joints.
	var surfaces: Dictionary = {}
	for child in parent.get_children():
		if child is MeshInstance3D and child != far_mesh and not flames.has(child) and not sparks.has(child):
			var material: StandardMaterial3D = child.material_override
			var key: String = str(material.metallic) + ":" + str(material.roughness) + ":" + str(material.emission_enabled) + ":" + str(material.emission_energy_multiplier)
			if material.emission_enabled:
				key += ":" + material.emission.to_html()
			if not surfaces.has(key):
				var tool := SurfaceTool.new()
				tool.begin(Mesh.PRIMITIVE_TRIANGLES)
				tool.set_material(_vertex_material(material))
				surfaces[key] = tool
			surfaces[key].append_from(_paint_mesh(child.mesh, material.albedo_color), 0, child.transform)
			child.free()
		elif child is Node3D and not child is MeshInstance3D:
			_merge_static(child)
	if surfaces.is_empty():
		return
	var merged := ArrayMesh.new()
	for tool in surfaces.values():
		tool.commit(merged)
	var shadow := ArrayMesh.new()
	for surface in range(merged.get_surface_count()):
		var shadow_arrays: Array = merged.surface_get_arrays(surface)
		for attribute in [Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT, Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2]:
			shadow_arrays[attribute] = null
		shadow.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, shadow_arrays)
	merged.shadow_mesh = shadow
	var node := MeshInstance3D.new()
	node.name = "BatchedSculptedSurfaces"
	node.mesh = merged
	if eyes.has(parent) or parent == steering_wheel or parent == jaw:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	near_meshes.append(node)


func _vertex_material(source: StandardMaterial3D) -> StandardMaterial3D:
	var material := source.duplicate() as StandardMaterial3D
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.albedo_color = Color.WHITE
	return material


func _paint_mesh(mesh: Mesh, color: Color) -> ArrayMesh:
	var arrays: Array = mesh.surface_get_arrays(0)
	var colors := PackedColorArray()
	colors.resize(arrays[Mesh.ARRAY_VERTEX].size())
	colors.fill(color)
	arrays[Mesh.ARRAY_COLOR] = colors
	var painted := ArrayMesh.new()
	painted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return painted


func _far_geometry(mesh: Mesh) -> Mesh:
	if mesh.has_meta("far_geometry"):
		return mesh.get_meta("far_geometry") as Mesh
	if mesh is SphereMesh:
		var simple := mesh.duplicate() as SphereMesh
		simple.radial_segments = 6
		simple.rings = 3
		return simple
	if mesh is CylinderMesh:
		var simple := mesh.duplicate() as CylinderMesh
		simple.radial_segments = 6
		return simple
	if mesh is TorusMesh:
		var simple := mesh.duplicate() as TorusMesh
		simple.rings = 8
		simple.ring_segments = 3
		return simple
	return mesh


func _append_far(parent: Node3D, transform_from_kart: Transform3D, tool: SurfaceTool) -> void:
	for child in parent.get_children():
		if child is MeshInstance3D:
			if flames.has(child) or sparks.has(child):
				continue
			var material: StandardMaterial3D = child.material_override
			tool.append_from(_paint_mesh(_far_geometry(child.mesh), material.albedo_color), 0, transform_from_kart * child.transform)
		elif child is Node3D:
			_append_far(child, transform_from_kart * child.transform, tool)


func _make_far_mesh() -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_material(_vertex_material(_mat(Color.WHITE, 0.16, 0.58)))
	_append_far(self, Transform3D.IDENTITY, tool)
	far_mesh = MeshInstance3D.new()
	far_mesh.name = "DistantKart"
	far_mesh.mesh = tool.commit()
	far_mesh.hide()
	add_child(far_mesh)


func _set_far_detail(enabled: bool) -> void:
	far_detail = enabled
	far_mesh.visible = enabled
	for node in near_meshes:
		node.visible = not enabled


func _update_detail(camera: Camera3D) -> void:
	var distance_squared: float = camera.global_position.distance_squared_to(global_position)
	var switch_distance: float = detail_distance - DETAIL_HYSTERESIS if far_detail else detail_distance
	var distant: bool = distance_squared > switch_distance * switch_distance
	if distant != far_detail:
		_set_far_detail(distant)


func set_motion(speed: float, steer: float, boost: bool, drift: bool) -> void:
	motion_speed = speed
	motion_steer = steer
	motion_boost = boost
	motion_drift = drift


func update_motion(speed: float, steer: float, drift: bool, boost: bool) -> void:
	set_motion(speed, steer, boost, drift)


func _process(delta: float) -> void:
	if companion_mode:
		set_companion_pose(animation_time + delta, "speaking" if speaking_amount > 0 else "idle", speaking_amount)
		return
	animation_time += delta
	wheel_spin_phase = fposmod(wheel_spin_phase + motion_speed * delta / 0.35, TAU)
	for flame in flames:
		flame.visible = motion_boost and motion_speed > 0.5
		flame.scale.z = 0.7 if reduced_motion else 0.85 + sin(animation_time * 30) * 0.18
	for spark in sparks:
		spark.visible = motion_drift and absf(motion_steer) > 0.2 and motion_speed > 1.0
		spark.scale.z = 0.9 + sin(animation_time * 23.0) * 0.3
	detail_check_time -= delta
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera and detail_check_time <= 0:
		_update_detail(camera)
		detail_check_time = 0.2
	if far_detail:
		return
	if camera and camera.global_position.distance_squared_to(global_position) > 225.0:
		if not camera.is_position_in_frustum(global_position + Vector3.UP):
			return
	for i in range(wheel_rotors.size()):
		wheel_rotors[i].quaternion = Quaternion(Vector3.BACK, PI / 2) * Quaternion(Vector3.UP, wheel_spin_phase)
		wheel_pivots[i].rotation.y = -motion_steer * 0.34 if wheel_pivots[i].get_meta("front") else 0.0
		wheel_pivots[i].position.y = 0.35 if reduced_motion else 0.35 + sin(animation_time * 11.0 + i * 1.7) * minf(0.010, absf(motion_speed) * 0.0005)
	if driver:
		driver.rotation.z = lerpf(driver.rotation.z, -motion_steer * 0.06, minf(1, delta * 7.0))
		driver.position.y = 0.0 if reduced_motion else sin(animation_time * 7.0) * minf(0.009, absf(motion_speed) * 0.0006)
	if head:
		head.rotation.y = lerpf(head.rotation.y, -motion_steer * 0.22, minf(1, delta * 8))
		head.rotation.z = 0.0 if reduced_motion else sin(animation_time * 2.2) * 0.014 - motion_steer * 0.024
		head.rotation.x = lerpf(head.rotation.x, -0.035 if motion_boost else 0.0, minf(1, delta * 5))
	for eye in eyes:
		var blink_phase: float = fposmod(animation_time + 0.45, 4.6)
		var blink: float = 1.0
		if blink_phase < 0.14:
			blink = maxf(0.07, absf(blink_phase - 0.07) / 0.07)
		eye.scale.y = blink
	if celebration_place > 0:
		celebration_time += delta
		var wave: float = 0.0 if reduced_motion else sin(celebration_time * TAU * 1.4)
		if is_instance_valid(cheer_arm) and cheer_arm.visible:
			cheer_arm.rotation.z = -0.25 + wave * 0.22
			cheer_arm.rotation.x = -0.15
		if is_instance_valid(head):
			if celebration_place == 1:
				head.rotation.x = -0.12 + wave * 0.03
			elif celebration_place <= 3:
				head.rotation.x = -0.07
			else:
				head.rotation.x = 0.05 + absf(wave) * 0.05
			head.rotation.y = lerpf(head.rotation.y, 0.35, minf(1, delta * 3))
		if driver and not reduced_motion and celebration_place <= 3:
			driver.position.y = absf(sin(celebration_time * PI * 2.2)) * (0.05 if celebration_place == 1 else 0.025)
	if jaw:
		jaw.rotation.x = speaking_amount * 0.45
		jaw.position.y = -0.257 - speaking_amount * 0.035
	if tail and not reduced_motion:
		tail.rotation.y = 0.5 + sin(animation_time * 2.6) * 0.085 - motion_steer * 0.11
	if steering_wheel:
		steering_wheel.rotation.z = -motion_steer * 0.40
