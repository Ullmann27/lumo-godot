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
const ORANGE := Color("f08a2c")
const GLOVE := Color("1d2230")
const FLEET = preload("res://scripts/games/kart_fleet.gd")
const FUR = preload("res://scripts/games/kart_fur_geometry.gd")

var vehicle_color: Color = Color("357cba")
var animal: String = "fox"
var kart_style: String = "comet"
var wheel_pivots: Array[Node3D] = []
var wheel_rotors: Array[Node3D] = []
var eyes: Array[Node3D] = []
var head: Node3D
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
var fur_normal: NoiseTexture2D
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
## Platz beim Zieleinlauf (0 = keine Feier): 1 jubelt am stärksten, 2–3 freuen
## sich, ab 4 nickt Lumo aufmunternd. Nutzt nur vorhandene Gelenke, keine
## zusätzliche Geometrie.
var celebration_place: int = 0
var celebration_time: float = 0.0
## Lumos rechter Arm hängt an einem Schultergelenk: Lenken, Winken, Jubeln.
const SHOULDER_RIGHT := Vector3(0.29, 1.215, 0.015)
## Schulter → Hand am Lenkrad (Ruhe) und Schulter → Hand hoch und nach außen (Jubel).
const ARM_REST_DIR := Vector3(-0.13, -0.16, -0.355)
const ARM_CHEER_DIR := Vector3(0.42, 0.78, -0.06)
var arm_right: Node3D
var arm_blend: float = 0.0


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
	return value if value in ["comet", "glider", "turbo"] or FLEET.IDS.has(value) else "comet"


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


func celebrate(place: int) -> void:
	celebration_place = maxi(0, place)
	celebration_time = 0.0


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
	arm_right = null
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


func _fur(parent: Node3D, geometry: Mesh, at: Vector3, color: Color, count: int, strand_length: float, seed_value: int) -> Node3D:
	var coat := Node3D.new()
	coat.name = "SculptedFur"
	coat.set_meta("fur_coat", true)
	coat.position = at
	parent.add_child(coat)
	var base_mesh := _mesh(coat, geometry, Vector3.ZERO, color, 0.0, 0.82)
	if animal == "fox":
		if fur_normal == null:
			var noise := FastNoiseLite.new()
			noise.seed = 801
			noise.frequency = 0.18
			noise.fractal_octaves = 3
			fur_normal = NoiseTexture2D.new()
			fur_normal.width = 256
			fur_normal.height = 256
			fur_normal.seamless = true
			fur_normal.as_normal_map = true
			fur_normal.bump_strength = 0.8
			fur_normal.noise = noise
		var finish := base_mesh.material_override.duplicate() as StandardMaterial3D
		finish.normal_enabled = true
		finish.normal_texture = fur_normal
		finish.normal_scale = 0.28
		finish.uv1_scale = Vector3(6, 1, 1)
		base_mesh.material_override = finish
	if animal == "fox":
		var strands := _mesh(coat, FUR.build(geometry, color, count, strand_length, seed_value), Vector3.ZERO, Color.WHITE, 0.0, 0.82)
		strands.set_meta("near_only", true)
	return coat


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
	var fleet_profile: Dictionary = FLEET.profile(kart_style)
	width = float(fleet_profile.get("width", width))
	body.scale.x = width
	# Lumo's starter racer retains the reference navy paint across character choices.
	var paint: Color = Color("172c49") if kart_style == "comet" else vehicle_color.lerp(Color("297cc0"), 0.25)
	if not fleet_profile.is_empty():
		paint = Color(str(fleet_profile.paint))
	var shell: Array[Vector4] = [
		Vector4(-1.16, 0.015, 0.018, 0.50), Vector4(-1.07, 0.24, 0.065, 0.51),
		Vector4(-0.81, 0.45, 0.17, 0.52), Vector4(-0.48, 0.58, 0.20, 0.50),
		Vector4(0.06, 0.61, 0.14, 0.45), Vector4(0.55, 0.61, 0.15, 0.46),
		Vector4(0.91, 0.48, 0.15, 0.49), Vector4(1.05, 0.20, 0.065, 0.50),
		Vector4(1.08, 0.01, 0.015, 0.50)]
	if not fleet_profile.is_empty():
		shell = FLEET.shell(kart_style)
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
		Vector4(-0.36, 0.01, 0.003, 0.78)], false, 20, 3), Vector3.ZERO, INK if kart_style == "comet" else WHITE, 0.18, 0.27)
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
	# A wraparound seat cradles the driver's hips and back rather than floating behind them.
	_make_cockpit(body, paint)
	# Wing is a shaped aerofoil, with style-specific stance and endplates.
	var wing_height: float = 1.04 if kart_style == "glider" else (0.95 if kart_style == "turbo" else 0.89)
	var wing_span: float = 1.65 if kart_style == "glider" else 1.35
	wing_height = float(fleet_profile.get("wing_y", wing_height))
	wing_span = float(fleet_profile.get("wing", wing_span))
	for side in [-1.0, 1.0]:
		_rod(body, Vector3(side * 0.40, 0.57, 0.77), Vector3(side * 0.45, wing_height, 0.95), 0.035, INK, 0.45)
	var wing := _mesh(body, _loft([
		Vector4(-wing_span / 2, 0.008, 0.008, 0), Vector4(-wing_span * 0.43, 0.18, 0.040, 0),
		Vector4(0.0, 0.17, 0.047, 0), Vector4(wing_span * 0.43, 0.18, 0.04, 0),
		Vector4(wing_span / 2, 0.008, 0.008, 0)], false, 24, 3, 0.8), Vector3(0, wing_height, 0.98), paint if kart_style == "comet" else WHITE, 0.36, 0.24)
	wing.rotation.y = PI / 2.0
	_ribbon(body, [Vector3(-wing_span * 0.42, wing_height + 0.037, 1.05), Vector3(0, wing_height + 0.047, 1.05), Vector3(wing_span * 0.42, wing_height + 0.037, 1.05)], 0.012, ICE, 0.3, 0.7)
	if kart_style == "turbo":
		for side in [-1.0, 1.0]:
			_mesh(body, _loft([Vector4(-0.48, 0.01, 0.01, 0), Vector4(-0.36, 0.11, 0.12, 0), Vector4(0.39, 0.13, 0.12, 0), Vector4(0.60, 0.01, 0.01, 0)], false, 20, 3), Vector3(side * 0.70, 0.54, 0), WHITE, 0.38, 0.3)
	_make_body_details(body, paint, wing_height, wing_span)
	FLEET.decorate(self, body, paint, kart_style)
	# Both axles pass through the lower chassis and meet the inner wheel hubs.
	for axle in [-0.66, 0.66]:
		var shaft := _rod(self, Vector3(-0.77 * width, 0.35, axle), Vector3(0.77 * width, 0.35, axle), 0.035, CHROME, 0.7)
		shaft.name = "FrontAxleShaft" if axle < 0 else "RearAxleShaft"
	for side in [-1.0, 1.0]:
		for axle in [-0.66, 0.66]:
			_make_wheel(side, axle, width)
	_make_steering_wheel()
	_make_driver()
	_make_far_mesh()
	_merge_static(self)


func _make_cockpit(body: Node3D, paint: Color) -> void:
	body.set_meta("seat_design", "contoured_bucket")
	# The lower shell enters the chassis; its narrow centre clears the moving tail.
	var seat_shell := _mesh(body, _loft([
		Vector4(0.63, 0.21, 0.11, 0.10), Vector4(0.74, 0.32, 0.12, 0.18),
		Vector4(0.91, 0.33, 0.069, 0.35), Vector4(1.02, 0.32, 0.064, 0.37),
		Vector4(1.08, 0.25, 0.058, 0.39), Vector4(1.10, 0.075, 0.026, 0.39)
	], true, 24, 3, 0.70), Vector3.ZERO, INK, 0.12, 0.65)
	seat_shell.name = "ContouredSeatShell"
	_ellipsoid(body, Vector3(0, 0.69, 0.07), Vector3(0.29, 0.090, 0.28), NAVY, 0.0, 0.78)
	# Rear upholstery and piping are visible from the inspection camera.
	_mesh(body, _loft([
		Vector4(0.78, 0.19, 0.020, 0.392), Vector4(0.93, 0.255, 0.024, 0.412),
		Vector4(1.04, 0.24, 0.027, 0.427), Vector4(1.07, 0.17, 0.020, 0.428)
	], true, 20, 3, 0.72), Vector3.ZERO, NAVY, 0.0, 0.78)
	for side in [-1.0, 1.0]:
		_mesh(body, _loft([
			Vector4(0.72, 0.042, 0.11, 0.12), Vector4(0.82, 0.065, 0.11, 0.21),
			Vector4(1.01, 0.062, 0.10, 0.27), Vector4(1.05, 0.075, 0.077, 0.29),
			Vector4(1.08, 0.045, 0.045, 0.32)
		], true, 16, 3, 0.78), Vector3(side * 0.285, 0, 0), NAVY, 0.0, 0.78)
		_ribbon(body, [Vector3(side * 0.22, 0.80, 0.410), Vector3(side * 0.27, 0.96, 0.432), Vector3(side * 0.26, 1.03, 0.447), Vector3(side * 0.18, 1.07, 0.450)], 0.007, WHITE, 0.18)
		# The hoop is fixed into the coachwork, with a visible mounting collar at each foot.
		_ellipsoid(body, Vector3(side * 0.33, 0.69, 0.35), Vector3(0.067, 0.034, 0.065), paint, 0.35, 0.26)
	_ribbon(body, [Vector3(-0.32, 0.69, 0.35), Vector3(-0.35, 1.02, 0.45), Vector3(-0.23, 1.10, 0.47), Vector3(0.23, 1.10, 0.47), Vector3(0.35, 1.02, 0.45), Vector3(0.32, 0.69, 0.35)], 0.027, CHROME, 0.6)
	for seam in range(3):
		_box(body, Vector3(0, 0.90 + seam * 0.075, 0.441), Vector3(0.35, 0.005, 0.006), INK)


func _make_body_details(body: Node3D, paint: Color, wing_height: float, wing_span: float) -> void:
	body.set_meta("body_detail_revision", 2)
	# Connected nose intake and splitter. These read as one assembly from all five views.
	_ellipsoid(body, Vector3(0, 0.458, -1.027), Vector3(0.29, 0.064, 0.052), INK, 0.35, 0.26)
	for vane in range(2):
		_box(body, Vector3(0, 0.436 + vane * 0.039, -1.074), Vector3(0.41, 0.011, 0.018), CHROME, 0.7)
	_ribbon(body, [Vector3(-0.45, 0.38, -0.84), Vector3(-0.34, 0.38, -1.015), Vector3(0, 0.38, -1.108), Vector3(0.34, 0.38, -1.015), Vector3(0.45, 0.38, -0.84)], 0.022, INK, 0.35)
	for side in [-1.0, 1.0]:
		_rod(body, Vector3(side * 0.21, 0.33, -0.80), Vector3(side * 0.21, 0.38, -1.045), 0.026, CHROME, 0.7)
		# Brake-light lenses are set into rear bodywork, above the two exhaust nozzles.
		_ellipsoid(body, Vector3(side * 0.22, 0.562, 1.006), Vector3(0.112, 0.045, 0.044), INK, 0.35, 0.26)
		var lamp := _ellipsoid(body, Vector3(side * 0.22, 0.568, 1.045), Vector3(0.085, 0.020, 0.012), Color("ff515e"), 0.18, 0.26)
		lamp.material_override = _mat(Color("ff515e"), 0.18, 0.26, 0.45)
		# Endplates join the tips of the aerofoil and give the wing a finished side silhouette.
		var endplate := _mesh(body, _loft([
			Vector4(-0.07, 0.008, 0.025, 0), Vector4(-0.025, 0.021, 0.13, 0),
			Vector4(0.08, 0.019, 0.13, 0.025), Vector4(0.14, 0.005, 0.07, 0.035)
		], true, 16, 3, 0.7), Vector3(side * wing_span * 0.47, wing_height, 0.98), paint, 0.35, 0.26)
		endplate.rotation.z = -side * 0.08
		_box(body, Vector3(side * (wing_span * 0.47 + 0.02), wing_height + 0.065, 1.002), Vector3(0.009, 0.027, 0.11), WHITE, 0.35)
	# A compact diffuser meets the lower hull; its vanes extend to the rear edge.
	_box(body, Vector3(0, 0.338, 0.952), Vector3(0.49, 0.065, 0.21), INK, 0.35)
	for fin in range(5):
		var blade := _box(body, Vector3(-0.20 + fin * 0.10, 0.305, 0.983), Vector3(0.018, 0.074, 0.20), INK, 0.35)
		blade.rotation.x = -0.11
	_box(body, Vector3(0, 0.475, 1.084), Vector3(0.15, 0.064, 0.017), NAVY, 0.35)
	_box(body, Vector3(-0.026, 0.478, 1.095), Vector3(0.012, 0.039, 0.005), WHITE, 0.35)
	_box(body, Vector3(-0.007, 0.464, 1.095), Vector3(0.047, 0.011, 0.005), WHITE, 0.35)
	if kart_style == "comet":
		# Compact armoured rear power unit, cyan lenses and restrained gold edges.
		var unit := _mesh(body, _loft([
			Vector4(0.38, 0.15, 0.10, 1.015), Vector4(0.49, 0.24, 0.12, 1.015),
			Vector4(0.69, 0.22, 0.11, 0.99), Vector4(0.79, 0.12, 0.06, 0.95)
		], true, 24, 3, 0.55), Vector3.ZERO, INK, 0.35, 0.56)
		unit.name = "RearPowerUnit"
		for side in [-1.0, 1.0]:
			_ribbon(body, [Vector3(side * 0.20, 0.43, 1.12), Vector3(side * 0.25, 0.55, 1.13), Vector3(side * 0.23, 0.68, 1.09), Vector3(side * 0.12, 0.78, 1.00)], 0.012, Color("c79145"), 0.35)
			_ribbon(body, [Vector3(side * 0.50, 0.38, -0.63), Vector3(side * 0.64, 0.39, -0.24), Vector3(side * 0.65, 0.40, 0.35), Vector3(side * 0.51, 0.42, 0.76)], 0.008, Color("b78640"), 0.35)
			var lamp := _box(body, Vector3(side * 0.43, 0.64, 0.94), Vector3(0.21, 0.032, 0.035), ICE)
			lamp.material_override = _mat(ICE, 0.18, 0.26, 0.75)
		for vane in range(4):
			_box(body, Vector3(0, 0.45 + vane * 0.048, 1.137), Vector3(0.31, 0.018, 0.018), Color("495367"), 0.35)
		var strip := _box(body, Vector3(0, 0.67, 1.11), Vector3(0.22, 0.025, 0.022), ICE)
		strip.material_override = _mat(ICE, 0.18, 0.26, 0.8)


func _make_tyre_geometry() -> ArrayMesh:
	if geometries.has("directional_tyre"):
		return geometries["directional_tyre"]
	# Rows create rounded sidewalls and two actual recessed circumferential channels.
	var rows: Array[Vector2] = [
		Vector2(-0.19, 0.23), Vector2(-0.17, 0.30), Vector2(-0.125, 0.344),
		Vector2(-0.105, 0.350), Vector2(-0.090, 0.337), Vector2(-0.075, 0.350),
		Vector2(0, 0.350), Vector2(0.075, 0.350), Vector2(0.090, 0.337),
		Vector2(0.105, 0.350), Vector2(0.125, 0.344), Vector2(0.17, 0.30), Vector2(0.19, 0.23)
	]
	const SECTIONS: int = 72
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for row in rows:
		for segment in range(SECTIONS):
			var angle: float = TAU * float(segment) / SECTIONS
			var tread_phase: float = fposmod(float(segment) / 4.0 + absf(row.x) * 1.5, 1.0)
			var cut: float = 0.014 if absf(row.x) <= 0.125 and tread_phase < 0.26 else 0.0
			var radius: float = row.y - cut
			vertices.append(Vector3(cos(angle) * radius, row.x, sin(angle) * radius))
			normals.append(Vector3.ZERO)
			uvs.append(Vector2(float(segment) / SECTIONS, (row.x + 0.19) / 0.38))
	for row in range(rows.size() - 1):
		for segment in range(SECTIONS):
			var a: int = row * SECTIONS + segment
			var b: int = (row + 1) * SECTIONS + segment
			var c: int = row * SECTIONS + (segment + 1) % SECTIONS
			var d: int = (row + 1) * SECTIONS + (segment + 1) % SECTIONS
			indices.append_array(PackedInt32Array([a, c, b, c, d, b]))
	for triangle in range(0, indices.size(), 3):
		var a: int = indices[triangle]
		var b: int = indices[triangle + 1]
		var c: int = indices[triangle + 2]
		var normal := (vertices[c] - vertices[a]).cross(vertices[b] - vertices[a])
		normals[a] += normal
		normals[b] += normal
		normals[c] += normal
	for index in range(normals.size()):
		normals[index] = normals[index].normalized()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	result.set_meta("far_geometry", _loft([
		Vector4(-0.19, 0.23, 0.23, 0), Vector4(-0.14, 0.33, 0.33, 0),
		Vector4(0.14, 0.33, 0.33, 0), Vector4(0.19, 0.23, 0.23, 0)
	], true, 12, 1))
	geometries["directional_tyre"] = result
	return result


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
	# Tread is recessed into one continuous tyre mesh; no projecting box spikes.
	var tyre := _mesh(rotor, _make_tyre_geometry(), Vector3.ZERO, Color("111a26"), 0.02, 0.83)
	tyre.name = "DirectionalTyre"
	var outside: float = -side * 0.193
	var brake := CylinderMesh.new()
	brake.top_radius = 0.205
	brake.bottom_radius = 0.205
	brake.height = 0.014
	brake.radial_segments = 24
	_mesh(rotor, brake, Vector3(0, outside, 0), Color("233247"), 0.6, 0.3)
	_ring(rotor, Vector3(0, outside - side * 0.018, 0), 0.199, 0.232, CHROME, 0.78)
	_ring(rotor, Vector3(0, outside - side * 0.027, 0), 0.224, 0.231, ICE, 0.3, 0.4)
	for spoke in range(5):
		var angle: float = float(spoke) * TAU / 5.0
		var start := Vector3(cos(angle) * 0.047, outside - side * 0.034, sin(angle) * 0.047)
		var end := Vector3(cos(angle + 0.18) * 0.207, outside - side * 0.023, sin(angle + 0.18) * 0.207)
		_rod(rotor, start, end, 0.022, WHITE, 0.64, 0.22)
		# Five wheel nuts sit on the hub flange; the brake disc remains visible behind the spokes.
		var bolt := Vector3(cos(angle) * 0.076, outside - side * 0.043, sin(angle) * 0.076)
		_ellipsoid(rotor, bolt, Vector3(0.013, 0.011, 0.013), CHROME, 0.7, 0.24)
	_ellipsoid(rotor, Vector3(0, outside - side * 0.04, 0), Vector3(0.071, 0.029, 0.071), vehicle_color, 0.65, 0.25)
	_ellipsoid(rotor, Vector3(0, outside - side * 0.065, 0), Vector3(0.026, 0.01, 0.026), ICE, 0.7, 0.2)
	# A fixed caliper follows the steering hub while the disc and spokes rotate inside it.
	var caliper := _box(pivot, Vector3(side * 0.165, 0.07, -0.15), Vector3(0.055, 0.13, 0.07), ORANGE, 0.7)
	caliper.name = "BrakeCaliper"
	caliper.rotation.x = -0.26
	caliper.material_override = _mat(ORANGE, 0.7, 0.24)
	_rod(pivot, Vector3(-side * 0.15, 0, 0), Vector3(side * 0.16, 0, 0), 0.063, CHROME, 0.7, 0.24)
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
	wheel.name = "SteeringGripRim"
	wheel.rotation.x = PI / 2
	_rod(steering_wheel, Vector3(-0.13, 0, 0), Vector3(0.13, 0, 0), 0.022, CHROME, 0.6)
	_rod(steering_wheel, Vector3(0, 0, 0), Vector3(0, -0.13, 0), 0.02, CHROME, 0.6)
	_ellipsoid(steering_wheel, Vector3(0, 0, -0.023), Vector3(0.065, 0.042, 0.017), NAVY, 0.4, 0.3)
	_ellipsoid(steering_wheel, Vector3(0, 0, -0.04), Vector3(0.018, 0.018, 0.007), ICE, 0.3, 0.25)
	_rod(self, Vector3(0, 0.68, -0.22), steering_wheel.position, 0.035, INK, 0.4)


func _make_driver() -> void:
	var fur: Color = {"fox": Color("ed762d"), "otter": Color("ad8064"), "rabbit": Color("cedbe8"), "badger": Color("64718a"), "cat": Color("d4b396")}.get(animal, Color("ed762d"))
	var cream := Color("f4f2ea") if animal == "fox" else Color("eaf4f9")
	var fur_shadow: Color = fur.darkened(0.18)
	driver = Node3D.new()
	driver.name = "RacerRig"
	add_child(driver)
	# Fitted racing suit with shoulder yoke, collar, sleeves and a distinct white back panel.
	_mesh(driver, _loft([Vector4(0.77, 0.19, 0.19, 0.13), Vector4(0.90, 0.25, 0.20, 0.13), Vector4(1.12, 0.26, 0.195, 0.10), Vector4(1.27, 0.28, 0.16, 0.11), Vector4(1.32, 0.17, 0.11, 0.11)], true, 28, 4, 0.88), Vector3.ZERO, NAVY, 0, 0.7)
	# The neck bridges the collar and the head base, keeping the silhouette connected in side view.
	var neck := _mesh(driver, _loft([Vector4(1.285, 0.11, 0.10, 0.10), Vector4(1.36, 0.115, 0.105, 0.09), Vector4(1.43, 0.10, 0.09, 0.075)], true, 20, 3), Vector3.ZERO, fur, 0.0, 0.82)
	neck.name = "NeckBridge"
	var is_lumo: bool = animal == "fox"
	# Closed navy racing armour and large cyan L match the supplied character sheet.
	var chest_fill: Color = cream if is_lumo else WHITE
	if is_lumo:
		_mesh(driver, _loft([Vector4(0.98, 0.085, 0.022, -0.106), Vector4(1.07, 0.17, 0.025, -0.117), Vector4(1.22, 0.18, 0.027, -0.092), Vector4(1.29, 0.11, 0.020, -0.065)], true, 24, 4, 0.72), Vector3.ZERO, Color("183962"), 0.18, 0.56)
		for side in [-1.0, 1.0]:
			_ribbon(driver, [Vector3(side * 0.175, 1.02, -0.12), Vector3(side * 0.20, 1.14, -0.12), Vector3(side * 0.18, 1.25, -0.084)], 0.009, ICE, 0.18, 0.4)
	else:
		_mesh(driver, _loft([Vector4(0.89, 0.10, 0.017, -0.073), Vector4(1.02, 0.155, 0.022, -0.093), Vector4(1.21, 0.17, 0.020, -0.070), Vector4(1.29, 0.11, 0.012, -0.035)], true, 22, 4), Vector3.ZERO, WHITE, 0.04, 0.57)
	_mesh(driver, _loft([Vector4(0.91, 0.11, 0.015, 0.332), Vector4(1.12, 0.17, 0.015, 0.302), Vector4(1.28, 0.17, 0.014, 0.244), Vector4(1.31, 0.09, 0.012, 0.223)], true, 22, 4), Vector3.ZERO, Color("0f2a52") if is_lumo else WHITE, 0.03, 0.65)
	var collar := _ring(driver, Vector3(0, 1.32, 0.10), 0.112, 0.163, NAVY if is_lumo else ICE, 0.18)
	collar.scale.z = 0.8
	if is_lumo:
		_ring(driver, Vector3(0, 1.335, 0.10), 0.158, 0.170, ICE, 0.18).scale.z = 0.8
		# Reißverschluss, der unten am Brustfell endet.
		_ribbon(driver, [Vector3(0, 0.86, -0.118), Vector3(0, 0.98, -0.120), Vector3(0, 1.04, -0.112)], 0.007, CHROME, 0.45)
		# Leuchtendes L links auf der Brust (vom Fahrer aus) und groß auf dem Rücken.
		_glow_letter_l(driver, Vector3(0, 1.15, -0.15), 0.19, false)
		_glow_letter_l(driver, Vector3(0, 1.17, 0.345), 0.20, true)
	else:
		_ribbon(driver, [Vector3(0, 0.92, -0.112), Vector3(0, 1.12, -0.112), Vector3(0, 1.28, -0.071)], 0.008, CHROME, 0.45)
		_star(driver, Vector3(0, 1.15, -0.124), 0.060, ICE)
		var back_star := _star(driver, Vector3(0, 1.16, 0.326), 0.074, NAVY)
		back_star.rotation.y = PI
	if companion_mode:
		_make_companion_limbs(fur)
	else:
		for side in [-1.0, 1.0]:
			# Rechter Arm von Lumo hängt an einem Schultergelenk; alles andere bleibt am Körper.
			var limb: Node3D = driver
			var origin := Vector3.ZERO
			if is_lumo and side > 0:
				arm_right = Node3D.new()
				arm_right.name = "ArmRight"
				arm_right.position = SHOULDER_RIGHT
				driver.add_child(arm_right)
				limb = arm_right
				origin = SHOULDER_RIGHT
			var sleeve := _mesh(limb, _loft([Vector4(0.0, 0.07, 0.065, 0), Vector4(0.13, 0.11, 0.10, 0), Vector4(0.29, 0.081, 0.08, 0), Vector4(0.42, 0.065, 0.060, 0)], true, 20, 4), Vector3(side * 0.24, 1.20, 0.10) - origin, NAVY, 0.03, 0.72)
			sleeve.quaternion = Quaternion(Vector3.UP, Vector3(side * 0.13, -0.22, -0.37).normalized())
			_ellipsoid(limb, Vector3(side * 0.29, 1.215, 0.015) - origin, Vector3(0.092, 0.056, 0.096), NAVY if is_lumo else WHITE, 0.07, 0.6)
			var seam: Array[Vector3] = []
			for point in [Vector3(side * 0.318, 1.225, 0.07), Vector3(side * 0.344, 1.11, -0.12), Vector3(side * 0.31, 1.03, -0.27)]:
				seam.append(point - origin)
			_ribbon(limb, seam, 0.012, ICE, 0.12)
			if is_lumo:
				# Orange-weiße Ärmelstreifen wie auf der Jacke der Vorlage.
				for band in range(2):
					var at := Vector3(side * (0.315 - band * 0.012), 1.135 - band * 0.05, -0.085 - band * 0.06)
					var stripe := _ring(limb, at - origin, 0.070, 0.100, ORANGE if band == 0 else WHITE, 0.18)
					stripe.scale.y = 1.8
					stripe.quaternion = Quaternion(Vector3.UP, Vector3(side * 0.13, -0.22, -0.37).normalized())
			_ellipsoid(driver, Vector3(side * 0.16, 0.81, -0.24), Vector3(0.105, 0.105, 0.20), NAVY, 0, 0.72)
			var glove_color: Color = GLOVE if is_lumo else WHITE
			var glove := _ellipsoid(limb, Vector3(side * 0.16, 1.055, -0.34) - origin, Vector3(0.079, 0.070, 0.083), glove_color, 0, 0.68)
			glove.name = "GripGlove"
			glove.rotation.z = side * -0.2
			for digit in range(3):
				_ellipsoid(limb, Vector3(side * (0.126 + digit * 0.027), 1.036, -0.393) - origin, Vector3(0.016, 0.036, 0.022), glove_color, 0, 0.68)
			_ellipsoid(driver, Vector3(side * 0.18, 0.80, -0.39), Vector3(0.12, 0.09, 0.14), NAVY, 0.08, 0.6)
			_ellipsoid(driver, Vector3(side * 0.18, 0.742, -0.405), Vector3(0.119, 0.026, 0.15), WHITE, 0.08, 0.6)
	head = Node3D.new()
	head.name = "LumoHead"
	head.position = Vector3(0, 1.68, 0.07)
	driver.add_child(head)
	var head_width: float = 0.43 if animal != "rabbit" else 0.36
	var head_profile: Array[Vector4] = [Vector4(-0.32, 0.055, 0.060, -0.025), Vector4(-0.26, 0.27, 0.225, -0.003), Vector4(-0.13, head_width, 0.30, 0.006), Vector4(0.055, head_width * 0.98, 0.326, 0.015), Vector4(0.23, 0.31, 0.277, 0.025), Vector4(0.33, 0.17, 0.17, 0.038), Vector4(0.375, 0.008, 0.012, 0.038)]
	_fur(head, _loft(head_profile, true, 48, 5), Vector3.ZERO, fur, 2900, 0.016, 715)
	# The cheek mask is sculpted as two swept, tapered volumes, with a joined muzzle.
	for side in [-1.0, 1.0]:
		var cheek := _fur(head, _loft([Vector4(-0.15, 0.045, 0.035, -0.012), Vector4(-0.045, 0.145, 0.130, -0.010), Vector4(0.095, 0.16, 0.135, 0.005), Vector4(0.245, 0.11, 0.077, 0.023), Vector4(0.335, 0.010, 0.013, 0.050)], false, 32, 4), Vector3(side * 0.12, -0.16, -0.21), cream, 700, 0.028, 821 + int(side))
		cheek.rotation.y = side * PI / 2
		# The white cheek fringe wraps around the lower sides of the head and
		# remains recognizable in the player's binding rear-camera reference.
		_fur(head, _loft([Vector4(-0.285, 0.012, 0.018, 0), Vector4(-0.22, 0.10, 0.125, 0.018), Vector4(-0.16, 0.137, 0.153, 0.008), Vector4(-0.10, 0.067, 0.102, 0), Vector4(-0.075, 0.005, 0.010, 0)], true, 28, 4), Vector3(side * 0.315, 0, 0.044), cream, 330, 0.025, 531 + int(side))
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
	_fur(head, _loft(muzzle, false, 32, 4), Vector3.ZERO, cream, 350, 0.009, 228)
	# A small triangular, polished nose and a real mouth cavity underneath.
	var nose := _mesh(head, _loft([Vector4(-0.16, 0.004, 0.016, -0.453), Vector4(-0.112, 0.075, 0.044, -0.463), Vector4(-0.079, 0.060, 0.032, -0.449), Vector4(-0.068, 0.004, 0.005, -0.435)], true, 24, 4), Vector3.ZERO, Color("2a1d22"), 0.08, 0.22)
	nose.name = "SculptedNose"
	_ellipsoid(head, Vector3(-0.020, -0.09, -0.493), Vector3(0.020, 0.009, 0.005), Color("ae8f85"), 0, 0.25)
	_ellipsoid(head, Vector3(0, -0.231, -0.285), Vector3(0.098, 0.027, 0.046), Color("472e39"), 0, 0.7)
	_fur(head, _loft([Vector4(-0.31, 0.025, 0.025, -0.18), Vector4(-0.265, 0.16, 0.11, -0.17), Vector4(-0.22, 0.19, 0.12, -0.17)], true, 28, 3), Vector3.ZERO, cream, 220, 0.011, 4431)
	jaw = Node3D.new()
	jaw.name = "MouthViseme"
	jaw.position = Vector3(0, -0.257, -0.263)
	head.add_child(jaw)
	_ellipsoid(jaw, Vector3(0, 0, -0.018), Vector3(0.123, 0.033, 0.054), cream, 0, 0.82)
	_ellipsoid(jaw, Vector3(0, 0.021, -0.041), Vector3(0.049, 0.014, 0.019), Color("df8890"), 0, 0.58)
	_ribbon(head, [Vector3(-0.127, -0.192, -0.32), Vector3(-0.101, -0.216, -0.342), Vector3(-0.057, -0.221, -0.352)], 0.008, Color("714333"))
	_ribbon(head, [Vector3(0.127, -0.192, -0.32), Vector3(0.101, -0.216, -0.342), Vector3(0.057, -0.221, -0.352)], 0.008, Color("714333"))
	for tuft in range(3):
		var quiff := _fur(head, _loft([Vector4(0, 0.034, 0.03, 0), Vector4(0.055, 0.038, 0.034, 0), Vector4(0.11, 0.003, 0.005, 0.030)], true, 18, 4), Vector3(-0.10 + tuft * 0.068, 0.30, -0.06 + tuft * 0.018), fur, 90, 0.019, 175 + tuft)
		quiff.rotation.z = 0.15 + tuft * 0.14
	if animal == "fox":
		_make_goggles()
	else:
		# A small earpiece integrates the racing identity without obscuring the face.
		for side in [-1.0, 1.0]:
			_ellipsoid(head, Vector3(side * 0.372, 0.01, 0.085), Vector3(0.030, 0.085, 0.075), NAVY, 0.35, 0.3)
			_ellipsoid(head, Vector3(side * 0.395, 0.01, 0.080), Vector3(0.012, 0.047, 0.043), ICE, 0.45, 0.22)
	if animal == "badger":
		for side in [-1.0, 1.0]:
			var stripe := _mesh(head, _loft([Vector4(-0.15, 0.028, 0.014, -0.28), Vector4(0.06, 0.059, 0.013, -0.310), Vector4(0.29, 0.039, 0.01, -0.172)], true, 16, 4), Vector3(side * 0.17, 0, 0), Color("e8f2fa"))
			stripe.rotation.z = side * -0.16
	_make_tail(fur, cream)


## Lumos Fliegerbrille: dunkelblaues Band rund um den Kopf, zwei Chromringe
## mit blau leuchtenden Gläsern, hochgeschoben auf die Stirn. Alle Teile
## hängen direkt am Kopf, damit sie mit ihm zu wenigen Render-Durchgängen
## verschmelzen.
func _make_goggles() -> void:
	var base := Transform3D(Basis(), Vector3(0, 0.285, 0.03))
	# Band liegt knapp außerhalb der Kopfform (Profil bei y≈0.29: ~0.24 × 0.21).
	var strap := _ring(head, Vector3.ZERO, 0.245, 0.282, NAVY, 0.18)
	strap.transform = base * Transform3D(Basis.from_scale(Vector3(1.04, 1.5, 0.98)), Vector3.ZERO)
	for side in [-1.0, 1.0]:
		# Gläser schauen nach vorn-oben: hochgeschobene Fliegerbrille.
		var lens := base * Transform3D(Basis.from_euler(Vector3(PI / 2 - 0.62, side * -0.34, 0)), Vector3(side * 0.112, 0.035, -0.245))
		_attach(_ring(head, Vector3.ZERO, 0.066, 0.096, CHROME, 0.18), lens)
		_attach(_ring(head, Vector3.ZERO, 0.090, 0.106, NAVY, 0.18), lens * Transform3D(Basis.from_scale(Vector3(1, 1.8, 1)), Vector3(0, -0.014, 0)))
		var glass := _ellipsoid(head, Vector3.ZERO, Vector3(0.078, 0.024, 0.078), Color("2f8fe0"), 0.3, 0.08)
		# Teilt das Leuchtmaterial des L-Logos: kein zusätzlicher Render-Durchgang.
		glass.material_override = _mat(Color("0876b8"), 0.35, 0.26)
		_attach(glass, lens * Transform3D(Basis(), Vector3(0, 0.004, 0)))
		_attach(_ellipsoid(head, Vector3.ZERO, Vector3(0.022, 0.006, 0.016), Color.WHITE, 0, 0.1), lens * Transform3D(Basis(), Vector3(-0.024, 0.022, -0.024)))
	_ellipsoid(head, base * Vector3(0, 0.02, -0.27), Vector3(0.042, 0.026, 0.028), CHROME, 0.08, 0.22)
	var buckle := _box(head, Vector3(0, 0.292, 0.269), Vector3(0.081, 0.060, 0.021), CHROME, 0.35)
	buckle.material_override = _mat(CHROME, 0.35, 0.26)
	var insert := _box(head, Vector3(0, 0.292, 0.281), Vector3(0.053, 0.033, 0.006), NAVY, 0.35)
	insert.material_override = _mat(NAVY, 0.35, 0.26)


## Setzt ein Teil relativ zu einem lokalen Bezugsrahmen, behält aber seine
## eigene Form-Skalierung (z. B. von _ellipsoid).
func _attach(node: Node3D, frame: Transform3D) -> void:
	node.transform = frame * node.transform


## Leuchtendes „L“ aus zwei Balken (Lumo-Logo). facing_back: auf dem Rücken
## lesbar von hinten, sonst von vorn.
func _glow_letter_l(parent: Node3D, at: Vector3, size: float, facing_back: bool) -> void:
	var bar := size * 0.24
	# Von vorn betrachtet liegt +x links im Bild; der Stamm gehört nach links.
	var stem_x := size * 0.25 if not facing_back else -size * 0.25
	var foot_x := -size * 0.02 if not facing_back else size * 0.02
	var stem := _box(parent, at + Vector3(stem_x, 0, 0), Vector3(bar, size, 0.012), ICE)
	var foot := _box(parent, at + Vector3(foot_x, -size * 0.5 + bar * 0.5, 0), Vector3(size * 0.78, bar, 0.012), ICE)
	for piece in [stem, foot]:
		piece.material_override = _mat(Color("25bfff"), 0.0, 0.3, 0.4)


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
		_fur(ear, _loft([Vector4(-0.075, 0.085, 0.078, 0), Vector4(0.0, 0.135, 0.092, 0), Vector4(0.14, 0.112, 0.080, 0.006), Vector4(0.32, 0.046, 0.048, 0.017), Vector4(0.40, 0.003, 0.004, 0.024)], true, 32, 4), Vector3.ZERO, fur.darkened(0.06), 300, 0.021, 440 + int(side))
		_fur(ear, _loft([Vector4(-0.033, 0.063, 0.026, -0.072), Vector4(0.055, 0.088, 0.035, -0.065), Vector4(0.17, 0.063, 0.028, -0.058), Vector4(0.31, 0.007, 0.005, -0.029)], true, 28, 4), Vector3.ZERO, cream, 200, 0.016, 555 + int(side))
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
	_ellipsoid(eye, Vector3(0, 0.005, 0.006), Vector3(0.134, 0.155, 0.064), fur_shadow)
	_ellipsoid(eye, Vector3(0, 0, -0.009), Vector3(0.119, 0.141, 0.065), WHITE, 0, 0.3)
	_ellipsoid(eye, Vector3(-side * 0.008, -0.009, -0.066), Vector3(0.075, 0.093, 0.018), Color("965123") if animal == "fox" else Color("287788"), 0.08, 0.22)
	_ellipsoid(eye, Vector3(-side * 0.008, -0.004, -0.081), Vector3(0.049, 0.062, 0.013), Color("080c12"), 0.10, 0.15)
	_ellipsoid(eye, Vector3(-0.026, 0.032, -0.093), Vector3(0.019, 0.025, 0.008), Color.WHITE, 0, 0.1)
	_ellipsoid(eye, Vector3(0.020, -0.038, -0.093), Vector3(0.007, 0.010, 0.004), Color.WHITE, 0, 0.1)


func _make_tail(fur: Color, cream: Color) -> void:
	tail = Node3D.new()
	tail.name = "TailJoint"
	# Route through the right cockpit opening, clear of the seat's x=0.35 edge.
	tail.position = Vector3(0.39, 0.99, 0.24)
	tail.rotation.y = 0.63
	tail.rotation.x = -0.15
	driver.add_child(tail)
	if animal == "rabbit":
		_ellipsoid(tail, Vector3(0.05, 0.03, 0.18), Vector3(0.13, 0.14, 0.15), cream, 0, 0.9)
		return
	var scale_factor: float = 0.8 if animal in ["otter", "badger"] else 1.0
	var tail_shape: Array[Vector4] = [Vector4(0.00, 0.055, 0.075, 0), Vector4(0.17, 0.115, 0.13, 0.00), Vector4(0.38, 0.195, 0.22, 0.07), Vector4(0.61, 0.22, 0.24, 0.21), Vector4(0.77, 0.165, 0.21, 0.37), Vector4(0.84, 0.072, 0.13, 0.56), Vector4(0.83, 0.004, 0.008, 0.73)]
	var mesh := _fur(tail, _loft(tail_shape, false, 32, 4), Vector3.ZERO, fur, 950, 0.033, 7138)
	mesh.scale *= scale_factor
	if animal in ["fox", "cat"]:
		_fur(tail, _loft([Vector4(0.60, 0.207, 0.205, 0.24), Vector4(0.73, 0.181, 0.225, 0.345), Vector4(0.83, 0.092, 0.145, 0.52), Vector4(0.85, 0.039, 0.075, 0.655), Vector4(0.83, 0.004, 0.008, 0.745)], false, 32, 4), Vector3.ZERO, cream, 600, 0.032, 8226)


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
	# Fur volumes have no independent animation. Bake their local transform into
	# the head/ear/tail batch, rather than adding a draw pass for every cheek.
	for child in parent.get_children():
		if child is Node3D and child.has_meta("fur_coat"):
			for part in child.get_children():
				var baked: Transform3D = child.transform * part.transform
				child.remove_child(part)
				parent.add_child(part)
				part.transform = baked
			child.free()
	var surfaces: Dictionary = {}
	for child in parent.get_children():
		if child is MeshInstance3D and child != far_mesh and not flames.has(child) and not sparks.has(child):
			var material: StandardMaterial3D = child.material_override
			var key: String = str(material.metallic) + ":" + str(material.roughness) + ":" + str(material.emission_enabled) + ":" + str(material.emission_energy_multiplier)
			if material.normal_enabled:
				key += ":fur:" + str(material.normal_texture.get_instance_id())
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
	var source_colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
	for i in range(colors.size()):
		colors[i] = source_colors[i] * color if source_colors.size() == colors.size() else color
	arrays[Mesh.ARRAY_COLOR] = colors
	# SurfaceTool.append_from() does not synthesize indices for unindexed
	# triangles. Mixed batches would silently omit those pieces (star badges)
	# once another source contributes an index buffer. Preserve every vertex
	# and the original winding by indexing unindexed triangles explicitly.
	var indices: PackedInt32Array = (
		arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	)
	if indices.is_empty():
		indices.resize(colors.size())
		for index in range(indices.size()):
			indices[index] = index
		arrays[Mesh.ARRAY_INDEX] = indices
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
			if flames.has(child) or sparks.has(child) or child.has_meta("near_only"):
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
	if jaw:
		jaw.rotation.x = speaking_amount * 0.45
		jaw.position.y = -0.257 - speaking_amount * 0.035
	if tail and not reduced_motion:
		tail.rotation.y = 0.63 + sin(animation_time * 2.6) * 0.055 - motion_steer * 0.07
	if steering_wheel:
		steering_wheel.rotation.z = -motion_steer * 0.40
	if arm_right:
		var cheer: bool = celebration_place >= 1 and celebration_place <= 3
		# Hand folgt leicht dem Lenkrad; beim Jubel geht der Arm hoch nach außen und winkt.
		arm_blend = move_toward(arm_blend, 1.0 if cheer else 0.0, delta * 3.2)
		var raise: float = smoothstep(0.0, 1.0, arm_blend)
		var cheer_q := Quaternion(ARM_REST_DIR.normalized(), ARM_CHEER_DIR.normalized())
		var pose: Quaternion = Quaternion.IDENTITY.slerp(cheer_q, raise)
		var wave: float = 0.0 if reduced_motion else sin(celebration_time * TAU * 1.8) * 0.3 * raise
		var steer_follow: float = -motion_steer * 0.08 * (1.0 - raise)
		arm_right.quaternion = Quaternion(Vector3.BACK, wave + steer_follow) * pose
	if celebration_place > 0:
		_apply_celebration(delta)


func _apply_celebration(delta: float) -> void:
	celebration_time += delta
	var happy: bool = celebration_place <= 3
	var tempo: float = 1.7 if celebration_place == 1 else 1.15
	var beat: float = 0.0 if reduced_motion else sin(celebration_time * TAU * tempo)
	if driver:
		# Freudensprung im Sitz: Platz 1 hüpft, 2–3 wippen, ab 4 bleibt Lumo ruhig.
		var hop: float = 0.0 if reduced_motion or not happy else absf(beat) * (0.075 if celebration_place == 1 else 0.035)
		driver.position.y = hop
		driver.rotation.z = beat * (0.05 if happy else 0.0)
	if head:
		var nod: float = 0.06 + absf(beat) * 0.06
		head.rotation.x = lerpf(head.rotation.x, (-0.16 if celebration_place == 1 else -0.08) if happy else nod, minf(1, delta * 6))
		head.rotation.z = beat * (0.09 if happy else 0.02)
		# Zur Kamera drehen, die beim Zieleinlauf seitlich nach vorn schwenkt.
		head.rotation.y = lerpf(head.rotation.y, 0.3, minf(1, delta * 3))
	for ear in ear_joints:
		ear.rotation.x = lerpf(ear.rotation.x, (-0.22 if happy else 0.08) + beat * 0.06, minf(1, delta * 6))
	if tail:
		tail.rotation.y = 0.63 + beat * (0.20 if happy else 0.08)
	if jaw and happy:
		# Fröhlich offener Mund, solange Lumo nicht spricht.
		jaw.rotation.x = maxf(jaw.rotation.x, 0.22 + absf(beat) * 0.12)

