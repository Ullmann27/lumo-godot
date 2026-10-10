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
const CHARACTER_FINISH = preload("res://scripts/games/kart_character_finish.gd")
const LUMO_ANIMATION = preload("res://scripts/characters/lumo/lumo_kart_animation_adapter.gd")
const CARBON := Color("0b1019")
const GUNMETAL := Color("2a3342")
## Leuchtstärke aller Neonteile: stark genug fürs Glühen, aber noch farbig (kein weißes Ausbrennen).
const NEON_GLOW: float = 1.15

## Aussehen aus Tuning und Flotte (siehe _resolved_look); leer = Werksvorgabe des Karts.
var look: Dictionary = {}
var chassis_look: Dictionary = {}
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
## Animation deltas are relative to the sculpted rest pose, also after a rebuild.
var jaw_rest_position := Vector3.ZERO
var ear_rest_angles: Array[float] = []
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
var racing_arm_joints: Array[Node3D] = []
var racing_rest_grips: Array[Vector3] = []
var wheel_rest_grips: Array[Vector3] = []
## Only the actual player race enables the new Lumo. Garage, ghosts and rivals
## retain their existing visuals until their own integration is approved.
var animated_lumo_enabled := false
var lumo_animation
var driver_airborne := false
var driver_hit_active := false
var driver_hit_pending := false
var driver_animation_paused := false
var _far_with_driver: Mesh
var _far_without_driver: Mesh
var _far_chassis_only := false


func _ready() -> void:
	_ensure_lumo_animation()


func set_animated_lumo_enabled(enabled: bool) -> void:
	animated_lumo_enabled = enabled
	if not enabled and is_instance_valid(lumo_animation):
		lumo_animation.free()
		lumo_animation = null
		if is_instance_valid(driver):
			driver.show()
		_refresh_far_proxy()
	else:
		_ensure_lumo_animation()


func set_driver_runtime_state(in_air: bool, hit_active: bool, suspended: bool) -> void:
	driver_airborne = in_air
	driver_hit_pending = driver_hit_pending or (hit_active and not driver_hit_active)
	driver_hit_active = hit_active
	driver_animation_paused = suspended
	if is_instance_valid(lumo_animation):
		lumo_animation.set_suspended(suspended)
		lumo_animation.set_reduced_motion(reduced_motion)


func _ensure_lumo_animation() -> void:
	if not is_inside_tree() or companion_mode or animal != "fox" or not animated_lumo_enabled:
		return
	if is_instance_valid(lumo_animation) or not is_instance_valid(steering_wheel):
		return
	var candidate = LUMO_ANIMATION.new()
	candidate.name = "AnimatedLumoDriver"
	add_child(candidate)
	if not candidate.bind_visual(self):
		candidate.free()
		return
	lumo_animation = candidate
	# Vehicle._process owns the only visual clock. No child timer can run
	# through a pause or evaluate the same animation a second time.
	lumo_animation.set_process(false)
	lumo_animation.set_reduced_motion(reduced_motion)
	lumo_animation.set_suspended(driver_animation_paused)
	driver.hide()
	_refresh_far_proxy()
	if celebration_place > 0:
		lumo_animation.celebrate_finished_race(celebration_place)


func _refresh_far_proxy() -> void:
	if companion_mode or not _built:
		return
	if is_instance_valid(far_mesh):
		# Both proxies are authored before static batching. Rebuilding from
		# batched multi-material surfaces would lose their source materials.
		far_mesh.mesh = (
			_far_without_driver if is_instance_valid(lumo_animation) else _far_with_driver
		)
		_set_far_detail(far_detail)


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
		ear_joints[i].rotation.z = ear_rest_angles[i] + sin(time_seconds * cycle + i * 0.7) * 0.018
	if tail:
		tail.rotation.y = 0.7 + sin(time_seconds * cycle) * (0.18 if mood == "cheer" else 0.08)
	if jaw:
		jaw.rotation.x = clampf(voice_open, 0.0, 1.0) * 0.6
		jaw.position = jaw_rest_position + Vector3(0, -clampf(voice_open, 0.0, 1.0) * 0.044, 0)


func _animal_id(value: String) -> String:
	return {"lumo": "fox", "nova": "rabbit", "milo": "otter"}.get(value, value)


func _style_id(value: String) -> String:
	return value if FLEET.has(value) else "comet"


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
	if is_instance_valid(lumo_animation):
		if place > 0:
			lumo_animation.celebrate_finished_race(place)
		else:
			lumo_animation.clear_celebration()


func set_speaking(amount: float) -> void:
	speaking_amount = clampf(amount, 0.0, 1.0)


func set_graphics_quality(profile: String) -> void:
	detail_distance = 14.0 if profile in ["light", "low"] else (22.0 if profile == "medium" else FAR_DETAIL_DISTANCE)
	detail_check_time = 0.0


func _rebuild() -> void:
	for child in get_children():
		child.free()
	lumo_animation = null
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
	ear_rest_angles.clear()
	jaw_rest_position = Vector3.ZERO
	racing_arm_joints.clear()
	racing_rest_grips.clear()
	wheel_rest_grips.clear()
	head = null
	tail = null
	jaw = null
	arm_right = null
	far_mesh = null
	_far_with_driver = null
	_far_without_driver = null
	far_detail = false
	if companion_mode:
		_make_driver()
		_merge_static(self)
	else:
		_build()
	_built = true
	_ensure_lumo_animation()


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
	if geometry.surface_get_arrays(0)[Mesh.ARRAY_COLOR] != null:
		# Authored meshes and the batched runtime must interpret pigmentation
		# identically. Keep coloured finishes distinct from plain white pieces.
		var pigment_finish := node.material_override.duplicate() as StandardMaterial3D
		pigment_finish.vertex_color_use_as_albedo = true
		pigment_finish.vertex_color_is_srgb = true
		node.material_override = pigment_finish
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
	var spec: Dictionary = _resolved_look()
	chassis_look = spec
	# Comet, Glider, Aurora GT und die sechs Profil-Designs nutzen die gelofteten Karosserien,
	# Blitz, Terra, Koloss, Phantom und Stella den Plattenbaukasten (_build_aero).
	if str(spec.body) == "loft":
		_build_loft(spec)
	else:
		_build_aero(spec)
	_make_steering_wheel()
	_make_driver()
	_make_far_mesh()
	_merge_static(self)


func _build_loft(spec: Dictionary) -> void:
	var body := Node3D.new()
	body.name = "AuroraCoachwork"
	add_child(body)
	var width: float = 1.1 if kart_style == "turbo" else (0.91 if kart_style == "glider" else 1.0)
	var fleet_profile: Dictionary = FLEET.profile(kart_style)
	width = float(fleet_profile.get("width", width))
	body.scale.x = width
	# Lumo's starter racer retains the reference navy paint across character choices.
	var paint: Color = Color("172c49") if kart_style == "comet" else vehicle_color.lerp(Color("297cc0"), 0.25)
	# Glider (perlweiß) und Aurora GT (violett) tragen ihren Flottenlack, damit sie sich in der
	# Auswahl von den blauen Profil-Designs abheben.
	if kart_style == "glider" or kart_style == "turbo":
		paint = spec.paint
	if not fleet_profile.is_empty():
		paint = Color(str(fleet_profile.paint))
	# Lack aus der Werkstatt ersetzt die Werksfarbe.
	if look.has("paint"):
		paint = spec.paint
	var shell: Array[Vector4] = [
		Vector4(-1.16, 0.015, 0.018, 0.50), Vector4(-1.07, 0.24, 0.065, 0.51),
		Vector4(-0.81, 0.45, 0.17, 0.52), Vector4(-0.48, 0.58, 0.20, 0.50),
		Vector4(0.06, 0.61, 0.14, 0.45), Vector4(0.55, 0.61, 0.15, 0.46),
		Vector4(0.91, 0.48, 0.15, 0.49), Vector4(1.05, 0.20, 0.065, 0.50),
		Vector4(1.08, 0.01, 0.015, 0.50)]
	if not fleet_profile.is_empty():
		shell = FLEET.shell(kart_style)
	_mesh(
		body, _loft(shell, false, 32, 5, 0.75), Vector3.ZERO, paint,
		0.42, 0.44 if kart_style == "comet" else 0.24
	)
	var hull := _mesh(body, _loft([
		Vector4(-1.09, 0.015, 0.01, 0.34), Vector4(-0.75, 0.51, 0.08, 0.33),
		Vector4(0.02, 0.63, 0.09, 0.31), Vector4(0.74, 0.54, 0.08, 0.32),
		Vector4(1.03, 0.01, 0.01, 0.36)], false, 24, 3, 0.6), Vector3.ZERO, INK, 0.2, 0.35)
	hull.name = "CarbonLowerHull"
	# Long bonnet, raised shoulder pods, smooth white nose stripe.
	var bonnet := _mesh(body, _loft([
		Vector4(-1.10, 0.01, 0.01, 0.54), Vector4(-0.9, 0.28, 0.06, 0.60),
		Vector4(-0.65, 0.37, 0.12, 0.67), Vector4(-0.52, 0.32, 0.105, 0.70),
		Vector4(-0.46, 0.25, 0.03, 0.65), Vector4(-0.43, 0.01, 0.01, 0.60)], false), Vector3.ZERO, paint.lightened(0.1), 0.48, 0.22)
	bonnet.name = "BonnetShell"
	if kart_style == "comet":
		var badge := Node3D.new()
		badge.name = "BonnetLumoBadge"
		badge.position = Vector3(0, 0.802, -0.66)
		badge.rotation.x = PI / 2.0 - 0.24
		body.add_child(badge)
		_glow_letter_l(badge, Vector3.ZERO, 0.17, false)
	if kart_style != "comet":
		_mesh(body, _loft([
			Vector4(-1.055, 0.015, 0.004, 0.584), Vector4(-0.85, 0.075, 0.01, 0.682),
			Vector4(-0.60, 0.085, 0.012, 0.795), Vector4(-0.52, 0.075, 0.01, 0.810),
			Vector4(-0.46, 0.01, 0.003, 0.685)], false, 20, 3),
			Vector3.ZERO, INK if kart_style == "comet" else WHITE, 0.18, 0.27)
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
		_ribbon(
			body,
			[Vector3(side * 0.19, 0.624, -1.079), Vector3(side * 0.34, 0.639, -0.979),
			Vector3(side * 0.42, 0.619, -0.854)],
			0.021, ICE if kart_style == "comet" else WHITE, 0.2, 1.0
		)
		# The light blades are inset into dark headlight housings.
		_ribbon(body, [Vector3(side * 0.19, 0.59, -1.05), Vector3(side * 0.35, 0.60, -0.952), Vector3(side * 0.43, 0.58, -0.83)], 0.037, INK, 0.4)
		# Lumo's reference racer has compact inset boost ports in its armoured
		# power unit. Other fleet styles retain their cylindrical exhausts.
		var port_x: float = 0.14 if kart_style == "comet" else 0.37
		var port_y: float = 0.43 if kart_style == "comet" else 0.52
		if kart_style == "comet":
			_box(body, Vector3(side * port_x, port_y, 1.125), Vector3(0.18, 0.09, 0.12), INK, 0.35)
			var port := _box(
				body, Vector3(side * port_x, port_y, 1.188), Vector3(0.12, 0.022, 0.006), ICE, 0.35
			)
			port.material_override = _mat(ICE, 0.18, 0.26, 0.8)
		else:
			_rod(
				body, Vector3(side * 0.33, 0.46, 0.79), Vector3(side * 0.37, 0.52, 1.16),
				0.105, CHROME, 0.75, 0.24
			)
			_rod(body, Vector3(side * 0.37, 0.52, 1.14), Vector3(side * 0.371, 0.52, 1.18), 0.079, INK, 0.3)
			var nozzle := _ring(body, Vector3(side * 0.37, 0.52, 1.183), 0.071, 0.084, ICE, 0.3, 0.8)
			nozzle.rotation.x = PI / 2.0
		var flame := _mesh(
			self,
			_loft([
				Vector4(0, 0.055, 0.055, 0), Vector4(0.18, 0.10, 0.09, 0),
				Vector4(0.60, 0.002, 0.002, 0)
			], false, 16, 3),
			Vector3(side * port_x * width, port_y, 1.20), ICE, 0.0, 0.25, 2.0
		)
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
	if kart_style == "comet":
		wing_height = 0.73
		wing_span = 1.22
	if kart_style != "comet":
		for side in [-1.0, 1.0]:
			_rod(
				body, Vector3(side * 0.40, 0.57, 0.77), Vector3(side * 0.45, wing_height, 0.95),
				0.035, INK, 0.45
			)
		var wing := _mesh(body, _loft([
			Vector4(-wing_span / 2, 0.008, 0.008, 0), Vector4(-wing_span * 0.43, 0.18, 0.040, 0),
			Vector4(0.0, 0.17, 0.047, 0), Vector4(wing_span * 0.43, 0.18, 0.04, 0),
			Vector4(wing_span / 2, 0.008, 0.008, 0)], false, 24, 3, 0.8),
			Vector3(0, wing_height, 0.98), paint if kart_style == "comet" else WHITE, 0.36, 0.24)
		wing.rotation.y = PI / 2.0
		_ribbon(
			body,
			[Vector3(-wing_span * 0.42, wing_height + 0.037, 1.05),
			Vector3(0, wing_height + 0.047, 1.05),
			Vector3(wing_span * 0.42, wing_height + 0.037, 1.05)],
			0.012, ICE, 0.3, 0.7
		)
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


## with_hoop = false: Der Baukasten bringt eigene Überrollbügel mit (_make_cage).
func _make_cockpit(body: Node3D, paint: Color, with_hoop: bool = true) -> void:
	body.set_meta("seat_design", "contoured_bucket")
	# The boots rest inside a clear footwell behind the bonnet, on physical pedals.
	for side in [-1.0, 1.0]:
		var pedal := _box(body, Vector3(side * 0.18, 0.689, -0.24), Vector3(0.18, 0.045, 0.24), INK, 0.35)
		pedal.name = "FootPedalLeft" if side < 0 else "FootPedalRight"
		_rod(body, Vector3(side * 0.18, 0.59, -0.18), Vector3(side * 0.18, 0.675, -0.24), 0.024, CHROME, 0.7, 0.24)
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
		if with_hoop:
			_ellipsoid(body, Vector3(side * 0.33, 0.69, 0.35), Vector3(0.067, 0.034, 0.065), paint, 0.35, 0.26)
	if with_hoop:
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
		if kart_style != "comet":
			# Endplates join the tips of the aerofoil and give the wing a finished side silhouette.
			var endplate := _mesh(body, _loft([
				Vector4(-0.07, 0.008, 0.025, 0), Vector4(-0.025, 0.021, 0.13, 0),
				Vector4(0.08, 0.019, 0.13, 0.025), Vector4(0.14, 0.005, 0.07, 0.035)
			], true, 16, 3, 0.7), Vector3(side * wing_span * 0.47, wing_height, 0.98), paint, 0.35, 0.26)
			endplate.rotation.z = -side * 0.08
			_box(
				body, Vector3(side * (wing_span * 0.47 + 0.02), wing_height + 0.065, 1.002),
				Vector3(0.009, 0.027, 0.11), WHITE, 0.35
			)
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
			Vector4(0.83, 0.20, 0.15, 0.59), Vector4(0.96, 0.27, 0.205, 0.59),
			Vector4(1.11, 0.265, 0.20, 0.59), Vector4(1.145, 0.24, 0.18, 0.59),
			Vector4(1.15, 0.01, 0.01, 0.59)
		], false, 8, 2, 0.72), Vector3.ZERO, INK, 0.35, 0.56)
		unit.name = "RearPowerUnit"
		for side in [-1.0, 1.0]:
			_ribbon(
				body,
				[Vector3(side * 0.18, 0.40, 1.145), Vector3(side * 0.25, 0.49, 1.14),
				Vector3(side * 0.25, 0.69, 1.14), Vector3(side * 0.16, 0.77, 1.11)],
				0.012, Color("c79145"), 0.35
			)
			_ribbon(body, [Vector3(side * 0.50, 0.38, -0.63), Vector3(side * 0.64, 0.39, -0.24), Vector3(side * 0.65, 0.40, 0.35), Vector3(side * 0.51, 0.42, 0.76)], 0.008, Color("b78640"), 0.35)
			_box(body, Vector3(side * 0.45, 0.67, 1.02), Vector3(0.29, 0.105, 0.13), paint, 0.35)
			var lamp := _box(body, Vector3(side * 0.45, 0.69, 1.089), Vector3(0.23, 0.032, 0.008), ICE)
			lamp.material_override = _mat(ICE, 0.18, 0.26, 0.75)
		for vane in range(4):
			_box(
				body, Vector3(0, 0.49 + vane * 0.041, 1.159), Vector3(0.31, 0.015, 0.018),
				Color("495367"), 0.35
			)
		var strip := _box(body, Vector3(0, 0.705, 1.157), Vector3(0.22, 0.025, 0.016), ICE)
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
	var rim_glow: Color = chassis_look.get("neon", ICE) if bool(look.get("neon_custom", false)) else ICE
	_ring(
		rotor, Vector3(0, outside - side * 0.027, 0),
		0.218 if kart_style == "comet" else 0.224,
		0.233 if kart_style == "comet" else 0.231,
		rim_glow, 0.3, 0.8 if kart_style == "comet" else 0.4
	)
	for spoke in range(5):
		var angle: float = float(spoke) * TAU / 5.0
		var start := Vector3(cos(angle) * 0.047, outside - side * 0.034, sin(angle) * 0.047)
		var end := Vector3(cos(angle + 0.18) * 0.207, outside - side * 0.023, sin(angle + 0.18) * 0.207)
		var spoke_color: Color = Color("354d69") if kart_style == "comet" else WHITE
		_rod(rotor, start, end, 0.022, chassis_look.get("rim", spoke_color) if look.has("rim") else spoke_color, 0.64, 0.22)
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


func _tri(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, outward: Vector3) -> void:
	# Godot dreht Vorderseiten im Uhrzeigersinn: Dreieck so ordnen, dass die Normale nach außen zeigt.
	var normal: Vector3 = (c - a).cross(b - a)
	if normal.length_squared() < 0.0000001:
		return
	if normal.dot(outward) < 0.0:
		var swap: Vector3 = b
		b = c
		c = swap
		normal = -normal
	normal = normal.normalized()
	tool.set_normal(normal)
	tool.add_vertex(a)
	tool.set_normal(normal)
	tool.add_vertex(b)
	tool.set_normal(normal)
	tool.add_vertex(c)


## Kantige Platte über einem Umriss (x, z): senkrechte Wand, Fase, schräge Oberseite.
## y0 = Unterkante, y_front/y_back = Höhe der Oberseite am vordersten/hintersten Punkt.
func _slab(parent: Node3D, outline: PackedVector2Array, y0: float, y_front: float, y_back: float, inset: float, color: Color, metal: float = 0.0, rough: float = 0.5, glow: float = 0.0, far: bool = true) -> MeshInstance3D:
	var points := PackedVector2Array(outline)
	var count: int = points.size()
	var area: float = 0.0
	var min_z: float = INF
	var max_z: float = -INF
	for index in range(count):
		var a: Vector2 = points[index]
		var b: Vector2 = points[(index + 1) % count]
		area += a.x * b.y - b.x * a.y
		min_z = minf(min_z, a.y)
		max_z = maxf(max_z, a.y)
	if area < 0.0:
		points.reverse()
	var span: float = maxf(0.0001, max_z - min_z)
	var inner := PackedVector2Array()
	for index in range(count):
		var previous: Vector2 = points[(index - 1 + count) % count]
		var current: Vector2 = points[index]
		var following: Vector2 = points[(index + 1) % count]
		var e1: Vector2 = (current - previous).normalized()
		var e2: Vector2 = (following - current).normalized()
		var n1 := Vector2(-e1.y, e1.x)
		var n2 := Vector2(-e2.y, e2.x)
		var shift: Vector2 = (n1 + n2) * inset / maxf(0.25, 1.0 + n1.dot(n2))
		inner.append(current + shift)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bevel: float = inset * 0.9
	for index in range(count):
		var j: int = (index + 1) % count
		var p0: Vector2 = points[index]
		var p1: Vector2 = points[j]
		var t0: float = y_front + (y_back - y_front) * clampf((p0.y - min_z) / span, 0.0, 1.0)
		var t1: float = y_front + (y_back - y_front) * clampf((p1.y - min_z) / span, 0.0, 1.0)
		var edge: Vector2 = (p1 - p0).normalized()
		var out := Vector3(edge.y, 0.0, -edge.x)
		var b0 := Vector3(p0.x, y0, p0.y)
		var b1 := Vector3(p1.x, y0, p1.y)
		var w0 := Vector3(p0.x, t0 - bevel, p0.y)
		var w1 := Vector3(p1.x, t1 - bevel, p1.y)
		_tri(tool, b0, b1, w1, out)
		_tri(tool, b0, w1, w0, out)
		if inset > 0.0:
			var q0: Vector2 = inner[index]
			var q1: Vector2 = inner[j]
			var h0: float = y_front + (y_back - y_front) * clampf((q0.y - min_z) / span, 0.0, 1.0)
			var h1: float = y_front + (y_back - y_front) * clampf((q1.y - min_z) / span, 0.0, 1.0)
			var u0 := Vector3(q0.x, h0, q0.y)
			var u1 := Vector3(q1.x, h1, q1.y)
			var slope := Vector3(out.x, 1.0, out.z)
			_tri(tool, w0, w1, u1, slope)
			_tri(tool, w0, u1, u0, slope)
	var cap_points: PackedVector2Array = inner if inset > 0.0 else points
	var cap: PackedInt32Array = Geometry2D.triangulate_polygon(cap_points)
	for index in range(0, cap.size(), 3):
		var c0: Vector2 = cap_points[cap[index]]
		var c1: Vector2 = cap_points[cap[index + 1]]
		var c2: Vector2 = cap_points[cap[index + 2]]
		var v0 := Vector3(c0.x, y_front + (y_back - y_front) * clampf((c0.y - min_z) / span, 0.0, 1.0), c0.y)
		var v1 := Vector3(c1.x, y_front + (y_back - y_front) * clampf((c1.y - min_z) / span, 0.0, 1.0), c1.y)
		var v2 := Vector3(c2.x, y_front + (y_back - y_front) * clampf((c2.y - min_z) / span, 0.0, 1.0), c2.y)
		_tri(tool, v0, v1, v2, Vector3.UP)
	var mesh: ArrayMesh = tool.commit()
	if not far:
		mesh.set_meta("far_skip", true)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = _mat(color, metal, rough, glow)
	parent.add_child(node)
	return node


## Rundet die Ecken eines Umrisses (x, z) mit Kreisbögen vom Radius `radius` (begrenzt auf die halbe Kante).
func _rounded_polygon(points: PackedVector2Array, radius: float, samples: int = 3) -> PackedVector2Array:
	var count: int = points.size()
	var area: float = 0.0
	for index in range(count):
		var a: Vector2 = points[index]
		var b: Vector2 = points[(index + 1) % count]
		area += a.x * b.y - b.x * a.y
	var ordered := PackedVector2Array(points)
	if area < 0.0:
		ordered.reverse()
	var result := PackedVector2Array()
	for index in range(count):
		var previous: Vector2 = ordered[(index - 1 + count) % count]
		var current: Vector2 = ordered[index]
		var following: Vector2 = ordered[(index + 1) % count]
		var to_previous: Vector2 = previous - current
		var to_next: Vector2 = following - current
		var cut: float = minf(radius, minf(to_previous.length(), to_next.length()) * 0.5)
		if cut < 0.0005 or absf(to_previous.normalized().dot(to_next.normalized())) > 0.995:
			result.append(current)
			continue
		var start: Vector2 = current + to_previous.normalized() * cut
		var end: Vector2 = current + to_next.normalized() * cut
		for step in range(samples + 1):
			var t: float = float(step) / float(samples)
			# Quadratischer Bézier-Bogen mit der Ecke als Kontrollpunkt.
			result.append(start * (1.0 - t) * (1.0 - t) + current * 2.0 * (1.0 - t) * t + end * t * t)
	return result


## Weich gerundete Platte: senkrechte Wand, ein Viertelkreis als Kante und eine geneigte Oberseite,
## alles mit glatten Normalen (wie ein spritzgegossenes Karosserieteil). `fillet` ist der Kantenradius,
## `corner` der Eckenradius des Umrisses. Oberseite = lineare Neigung von vorn (y_front) nach hinten (y_back).
func _round_slab(parent: Node3D, outline: PackedVector2Array, y0: float, y_front: float, y_back: float, fillet: float, corner: float, color: Color, metal: float = 0.0, rough: float = 0.5, glow: float = 0.0, far: bool = true, segments: int = 3, crown: float = 0.0) -> MeshInstance3D:
	var points: PackedVector2Array = _rounded_polygon(outline, corner)
	var count: int = points.size()
	var min_z: float = INF
	var max_z: float = -INF
	var min_x: float = INF
	var max_x: float = -INF
	for point in points:
		min_z = minf(min_z, point.y)
		max_z = maxf(max_z, point.y)
		min_x = minf(min_x, point.x)
		max_x = maxf(max_x, point.x)
	var span: float = maxf(0.0001, max_z - min_z)
	var slope: float = (y_back - y_front) / span
	var up_vector: Vector3 = Vector3(0.0, 1.0, -slope).normalized()
	var outward: Array[Vector2] = []
	for index in range(count):
		var previous: Vector2 = points[(index - 1 + count) % count]
		var current: Vector2 = points[index]
		var following: Vector2 = points[(index + 1) % count]
		var e1: Vector2 = (current - previous).normalized()
		var e2: Vector2 = (following - current).normalized()
		var n: Vector2 = Vector2(e1.y, -e1.x) + Vector2(e2.y, -e2.x)
		outward.append(n.normalized() if n.length() > 0.0001 else Vector2(e2.y, -e2.x))
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var rings: int = segments + 2
	for ring in range(rings):
		for index in range(count):
			var p: Vector2 = points[index]
			var out2: Vector2 = outward[index]
			var out3 := Vector3(out2.x, 0.0, out2.y)
			var top: float = y_front + slope * (p.y - min_z)
			var vertex: Vector3
			var normal: Vector3
			if ring == 0:
				vertex = Vector3(p.x, y0, p.y)
				normal = out3
			else:
				var theta: float = (PI * 0.5) * float(ring - 1) / float(segments)
				var inset: float = fillet * (1.0 - cos(theta))
				var lift: float = top - fillet + fillet * sin(theta)
				var shifted: Vector2 = p - out2 * inset
				vertex = Vector3(shifted.x, lift, shifted.y)
				normal = (out3 * cos(theta) + up_vector * sin(theta)).normalized()
			vertices.append(vertex)
			normals.append(normal)
	for ring in range(rings - 1):
		for index in range(count):
			var j: int = (index + 1) % count
			var a: int = ring * count + index
			var b: int = ring * count + j
			var c: int = (ring + 1) * count + index
			var d: int = (ring + 1) * count + j
			for triangle in [[a, c, b], [b, c, d]]:
				var face: Vector3 = (vertices[triangle[2]] - vertices[triangle[0]]).cross(vertices[triangle[1]] - vertices[triangle[0]])
				var hint: Vector3 = normals[triangle[0]] + normals[triangle[1]] + normals[triangle[2]]
				if face.dot(hint) < 0.0:
					indices.append_array(PackedInt32Array([triangle[0], triangle[2], triangle[1]]))
				else:
					indices.append_array(PackedInt32Array(triangle))
	# Deckel: Oberkante triangulieren (Ring `rings - 1`), optional leicht gewölbt.
	var top_start: int = (rings - 1) * count
	var cap_points := PackedVector2Array()
	for index in range(count):
		cap_points.append(Vector2(vertices[top_start + index].x, vertices[top_start + index].z))
	var cap: PackedInt32Array = Geometry2D.triangulate_polygon(cap_points)
	for index in range(0, cap.size(), 3):
		var i0: int = top_start + cap[index]
		var i1: int = top_start + cap[index + 1]
		var i2: int = top_start + cap[index + 2]
		var face: Vector3 = (vertices[i2] - vertices[i0]).cross(vertices[i1] - vertices[i0])
		if face.dot(up_vector) < 0.0:
			indices.append_array(PackedInt32Array([i0, i2, i1]))
		else:
			indices.append_array(PackedInt32Array([i0, i1, i2]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if not far:
		mesh.set_meta("far_skip", true)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = _mat(color, metal, rough, glow)
	parent.add_child(node)
	return node


## Platte in beliebiger Lage (z. B. senkrecht auf der Rückseite): lokale Oberseite zeigt nach +Y.
func _panel(parent: Node3D, outline: PackedVector2Array, at: Vector3, euler: Vector3, thickness: float, inset: float, color: Color, metal: float = 0.0, rough: float = 0.5, glow: float = 0.0, far: bool = false) -> MeshInstance3D:
	var node: MeshInstance3D = _slab(parent, outline, 0.0, thickness, thickness, inset, color, metal, rough, glow, far)
	node.position = at
	node.rotation = euler
	return node


func _shape(half: Array, mirrored: bool = true) -> PackedVector2Array:
	# half: Punkte (x, z) der rechten Seite von vorn nach hinten; gespiegelt ergibt das den ganzen Umriss.
	var result := PackedVector2Array()
	for point in half:
		result.append(Vector2(point[0], point[1]))
	if mirrored:
		for index in range(half.size() - 1, -1, -1):
			var point: Array = half[index]
			if absf(float(point[0])) > 0.0001:
				result.append(Vector2(-float(point[0]), float(point[1])))
	return result


func _curve(points: Array, steps: int = 6) -> Array[Vector3]:
	# Weiche Kurve durch die Punkte (Catmull-Rom), z. B. für Rohre.
	var result: Array[Vector3] = []
	var count: int = points.size()
	for index in range(count - 1):
		var p0: Vector3 = points[maxi(0, index - 1)]
		var p1: Vector3 = points[index]
		var p2: Vector3 = points[index + 1]
		var p3: Vector3 = points[mini(count - 1, index + 2)]
		for step in range(steps):
			var t: float = float(step) / float(steps)
			result.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t))
	result.append(points[count - 1])
	return result


## Glattes Rohr entlang eines Linienzugs, mit runden Enden.
func _tube(parent: Node3D, points: Array, radius: float, color: Color, metal: float = 0.0, rough: float = 0.5, glow: float = 0.0, sides: int = 8, far: bool = false) -> MeshInstance3D:
	var count: int = points.size()
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var carry := Vector3.ZERO
	for index in range(count):
		var tangent: Vector3
		if index == 0:
			tangent = (points[1] - points[0]).normalized()
		elif index == count - 1:
			tangent = (points[index] - points[index - 1]).normalized()
		else:
			tangent = ((points[index] - points[index - 1]).normalized() + (points[index + 1] - points[index]).normalized()).normalized()
		var reference: Vector3 = carry if index > 0 and carry.length_squared() > 0.5 else (Vector3.UP if absf(tangent.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT)
		var side_axis: Vector3 = tangent.cross(reference)
		if side_axis.length_squared() < 0.0001:
			side_axis = tangent.cross(Vector3.RIGHT)
		side_axis = side_axis.normalized()
		var up_axis: Vector3 = side_axis.cross(tangent).normalized()
		carry = up_axis
		var widen: float = 1.0
		if index > 0 and index < count - 1:
			var before: Vector3 = (points[index] - points[index - 1]).normalized()
			var after: Vector3 = (points[index + 1] - points[index]).normalized()
			widen = 1.0 / maxf(0.55, sqrt((1.0 + before.dot(after)) * 0.5))
		for corner in range(sides):
			var angle: float = TAU * float(corner) / float(sides)
			var direction: Vector3 = side_axis * cos(angle) + up_axis * sin(angle)
			vertices.append(points[index] + direction * radius * widen)
			normals.append(direction)
	for index in range(count - 1):
		for corner in range(sides):
			var a: int = index * sides + corner
			var b: int = index * sides + (corner + 1) % sides
			var c: int = (index + 1) * sides + corner
			var d: int = (index + 1) * sides + (corner + 1) % sides
			for triangle in [[a, c, b], [b, c, d]]:
				var normal: Vector3 = (vertices[triangle[2]] - vertices[triangle[0]]).cross(vertices[triangle[1]] - vertices[triangle[0]])
				var outward: Vector3 = normals[triangle[0]] + normals[triangle[1]] + normals[triangle[2]]
				if normal.dot(outward) < 0.0:
					indices.append_array(PackedInt32Array([triangle[0], triangle[2], triangle[1]]))
				else:
					indices.append_array(PackedInt32Array(triangle))
	for end in [0, count - 1]:
		var center_index: int = vertices.size()
		vertices.append(points[end])
		var cap_normal: Vector3 = (points[0] - points[1]).normalized() if end == 0 else (points[count - 1] - points[count - 2]).normalized()
		normals.append(cap_normal)
		for corner in range(sides):
			var a: int = end * sides + corner
			var b: int = end * sides + (corner + 1) % sides
			var normal: Vector3 = (vertices[b] - vertices[center_index]).cross(vertices[a] - vertices[center_index])
			if normal.dot(cap_normal) < 0.0:
				indices.append_array(PackedInt32Array([center_index, b, a]))
			else:
				indices.append_array(PackedInt32Array([center_index, a, b]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if not far:
		mesh.set_meta("far_skip", true)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = _mat(color, metal, rough, glow)
	parent.add_child(node)
	return node


## Flacher Balken zwischen zwei Punkten (Leuchtstreifen, Zierleisten, Streben).
func _bar(parent: Node3D, from: Vector3, to: Vector3, width: float, height: float, color: Color, metal: float = 0.0, rough: float = 0.5, glow: float = 0.0, far: bool = false) -> MeshInstance3D:
	var length: float = from.distance_to(to)
	var direction: Vector3 = (to - from).normalized()
	var node: MeshInstance3D = _box(parent, (from + to) * 0.5, Vector3(width, height, length), color, metal)
	node.material_override = _mat(color, metal, rough, glow)
	var up: Vector3 = Vector3.UP if absf(direction.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	node.basis = Basis.looking_at(direction, up)
	if not far:
		node.mesh = node.mesh.duplicate()
		node.mesh.set_meta("far_skip", true)
	return node

## Aussehen des Karts: Werksvorgabe der Flotte, Neonfarbe nach Fahrer, darüber das Tuning.
func _resolved_look() -> Dictionary:
	var base: Dictionary = FLEET.entry(kart_style).look
	var result: Dictionary = {
		"body": str(base.body),
		"paint": base.paint,
		"trim": base.trim,
		"accent": base.accent,
		"neon": (base.neon as Color).lerp(vehicle_color, 0.35),
		"rim": Color("c9d6e6"),
		"rim_neon": false,
		"levels": {},
		"underglow": false,
	}
	for key in look:
		if key == "neon" and not bool(look.get("neon_custom", false)):
			continue
		result[key] = look[key]
	return result


func set_look(value: Dictionary) -> void:
	look = value.duplicate(true)
	if _built:
		_rebuild()


func _hood_top(z: float) -> float:
	return 0.50 + 0.16 * clampf((z + 1.17) / 0.81, 0.0, 1.0)


func _letter_l_outline(cx: float, cz: float, w: float, h: float, bar: float) -> PackedVector2Array:
	# Von vorn gelesen steht der Stamm links = +x; „oben“ des Buchstabens zeigt nach hinten (+z).
	return PackedVector2Array([
		Vector2(cx + w * 0.5, cz + h * 0.5), Vector2(cx + w * 0.5 - bar, cz + h * 0.5),
		Vector2(cx + w * 0.5 - bar, cz - h * 0.5 + bar), Vector2(cx - w * 0.5, cz - h * 0.5 + bar),
		Vector2(cx - w * 0.5, cz - h * 0.5), Vector2(cx + w * 0.5, cz - h * 0.5)])


## Maße und Ausstattung je Karosserie. Alles, was fehlt, übernimmt BODY_DEFAULTS.
const BODY_DEFAULTS: Dictionary = {
	"wheel_r_f": 0.38, "wheel_r_r": 0.38, "wheel_w_f": 0.34, "wheel_w_r": 0.40,
	"track_f": 0.84, "track_r": 0.88, "axle_f": -0.70, "axle_r": 0.68,
	"nose": 0.0, "hood_w": 1.0, "pod_w": 1.0, "pods": true,
	"hoop": 1, "front_wing": false, "rear_wing": 0, "bullbar": false, "stacks": 0,
	"armor": false, "star": false, "knobby": false, "scoop": false, "tall_hood": 0.0,
}
const BODIES: Dictionary = {
	"dragster": {"wheel_r_f": 0.30, "wheel_r_r": 0.47, "wheel_w_f": 0.20, "wheel_w_r": 0.54, "track_f": 0.62, "track_r": 0.92, "nose": 0.16, "hood_w": 0.78, "pod_w": 0.7, "stacks": 2, "scoop": true, "hoop": 1},
	"buggy": {"wheel_r_f": 0.44, "wheel_r_r": 0.46, "wheel_w_f": 0.34, "wheel_w_r": 0.38, "track_f": 0.94, "track_r": 0.98, "hood_w": 0.86, "pods": false, "hoop": 2, "knobby": true, "nose": -0.06},
	"heavy": {"wheel_r_f": 0.40, "wheel_r_r": 0.42, "wheel_w_f": 0.44, "wheel_w_r": 0.48, "track_f": 0.90, "track_r": 0.94, "hood_w": 1.14, "pod_w": 1.18, "bullbar": true, "armor": true, "stacks": 2, "hoop": 1, "tall_hood": 0.08},
	"phantom": {"wheel_r_f": 0.36, "wheel_r_r": 0.37, "wheel_w_f": 0.30, "wheel_w_r": 0.36, "track_f": 0.80, "track_r": 0.84, "nose": 0.14, "hood_w": 1.0, "pod_w": 0.96, "hoop": 0},
	"champion": {"wheel_r_f": 0.38, "wheel_r_r": 0.39, "wheel_w_f": 0.34, "wheel_w_r": 0.40, "track_f": 0.84, "track_r": 0.88, "nose": 0.06, "hood_w": 1.06, "hoop": 1, "rear_wing": 2, "star": true},
}


func _body_params(body: String) -> Dictionary:
	var result: Dictionary = BODY_DEFAULTS.duplicate()
	result.merge(BODIES.get(body, {}), true)
	return result


## Sucht auf einem geschlossenen Umriss den zusammenhängenden Abschnitt mit z < z_limit (Nase).
func _front_run(points: PackedVector2Array, z_limit: float) -> Array[Vector2]:
	var count: int = points.size()
	var start: int = -1
	for index in range(count):
		if points[index].y >= z_limit and points[(index + 1) % count].y < z_limit:
			start = (index + 1) % count
			break
	var run: Array[Vector2] = []
	if start < 0:
		return run
	var cursor: int = start
	while points[cursor].y < z_limit and run.size() < count:
		run.append(points[cursor])
		cursor = (cursor + 1) % count
	return run


func _star_outline(cx: float, cz: float, outer: float, inner: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for index in range(10):
		var angle: float = -PI / 2.0 + float(index) * TAU / 10.0
		var r: float = outer if index % 2 == 0 else inner
		result.append(Vector2(cx + cos(angle) * r, cz + sin(angle) * r))
	return result


## Die Flotte: eine Grundbauweise (Schalensitz, Wanne, Haube, Seitenkästen, Heckblock, Räder),
## die je Karosserie in Maßen und Anbauteilen abweicht (siehe BODIES).
func _build_aero(spec: Dictionary) -> void:
	var b: Dictionary = _body_params(str(spec.body))
	var paint: Color = spec.paint
	var trim: Color = spec.trim
	var accent: Color = spec.accent
	var neon: Color = spec.neon
	var nose: float = float(b.nose)
	var hood_w: float = float(b.hood_w)
	var pod_w: float = float(b.pod_w)
	var body := Node3D.new()
	body.name = "AuroraCoachwork"
	add_child(body)
	# --- Wanne (dunkler Unterbau)
	_round_slab(body, _shape([[0.30 * hood_w, -1.10 - nose], [0.42 * hood_w, -0.92 - nose], [0.46, -0.40], [0.46, 0.55], [0.43, 1.10], [0.30, 1.21]]), 0.14, 0.46, 0.62, 0.05, 0.14, CARBON, 0.0, 0.5)
	# --- Haube: weich gerundetes Schild, leuchtendes L (oder Stern), orange U-Linie, silberne Zierlinien
	var hood_height: float = float(b.tall_hood)
	var hood_outline: PackedVector2Array = _shape([[0.20 * hood_w, -1.19 - nose], [0.34 * hood_w, -1.04 - nose], [0.43 * hood_w, -0.75 - nose * 0.4], [0.44 * hood_w, -0.50], [0.37, -0.36]])
	_round_slab(body, hood_outline, 0.34, 0.50 + hood_height, 0.66 + hood_height, 0.075, 0.11, paint, 0.42, 0.24)
	var l_front: float = -0.92 - nose * 0.3
	var l_back: float = -0.58
	var top_front: float = 0.50 + hood_height + 0.16 * clampf((l_front + 1.17) / 0.81, 0.0, 1.0)
	var top_back: float = 0.50 + hood_height + 0.16 * clampf((l_back + 1.17) / 0.81, 0.0, 1.0)
	if bool(b.star):
		_slab(body, _star_outline(0.0, -0.74, 0.18, 0.075), top_front - 0.03, top_front + 0.012, top_back + 0.012, 0.006, neon, 0.0, 0.3, NEON_GLOW, false)
	else:
		_slab(body, _letter_l_outline(0.0, (l_front + l_back) * 0.5, 0.27, l_back - l_front, 0.078), top_front - 0.03, top_front + 0.010, top_back + 0.010, 0.006, neon, 0.0, 0.3, NEON_GLOW, false)
	var rounded_hood: PackedVector2Array = _rounded_polygon(hood_outline, 0.11)
	var run: Array[Vector2] = _front_run(rounded_hood, -0.50)
	var u_line: Array = []
	for point in run:
		var t: float = 0.50 + hood_height + 0.16 * clampf((point.y + 1.17) / 0.81, 0.0, 1.0)
		u_line.append(Vector3(point.x * 0.985, t - 0.062, point.y))
	if u_line.size() >= 2:
		_tube(body, u_line, 0.017, accent, 0.3, 0.35)
	for side in [-1.0, 1.0]:
		_tube(body, [Vector3(side * 0.33 * hood_w, 0.60 + hood_height + 0.004, -0.42), Vector3(side * 0.27 * hood_w, 0.55 + hood_height, -0.72), Vector3(side * 0.14 * hood_w, 0.51 + hood_height, -1.08 - nose * 0.6)], 0.014, trim, 0.5, 0.25)
	# --- Nasenflügel in Lackfarbe mit Leuchtaugen, dunkler Mittelgrill
	var front_z: float = -1.22 - nose
	_round_slab(body, _shape([[0.0, front_z], [0.16, front_z + 0.005], [0.12, front_z + 0.14]]), 0.12, 0.26, 0.28, 0.025, 0.04, CARBON, 0.3, 0.45)
	for side in [-1.0, 1.0]:
		var wing: PackedVector2Array = PackedVector2Array([Vector2(side * 0.14, front_z + 0.01), Vector2(side * 0.62 * hood_w, front_z + 0.06), Vector2(side * 0.84 * hood_w, front_z + 0.22), Vector2(side * 0.74 * hood_w, front_z + 0.29), Vector2(side * 0.16, front_z + 0.23)])
		_round_slab(body, wing, 0.14, 0.31, 0.37, 0.04, 0.06, paint, 0.42, 0.24)
		_bar(body, Vector3(side * 0.30, 0.285, front_z + 0.015), Vector3(side * 0.76 * hood_w, 0.305, front_z + 0.165), 0.024, 0.052, neon, 0.0, 0.3, NEON_GLOW)
		_bar(body, Vector3(side * 0.22, 0.205, front_z + 0.015), Vector3(side * 0.66 * hood_w, 0.215, front_z + 0.12), 0.014, 0.012, accent, 0.3, 0.4)
	for slit in range(3):
		_bar(body, Vector3(-0.07 + slit * 0.07, 0.19, front_z - 0.002), Vector3(-0.07 + slit * 0.07, 0.25, front_z - 0.002), 0.012, 0.012, Color("05080e"))
	if bool(b.front_wing):
		_front_wing(body, paint, trim, neon, front_z - 0.16)
	if bool(b.bullbar):
		_bull_bar(body, front_z)
	# --- Seitenkästen mit Leuchtleiste, orange Cockpitkante und Käfigstreben
	for side in [-1.0, 1.0]:
		if bool(b.pods):
			var pod: PackedVector2Array = PackedVector2Array([Vector2(side * 0.46, -0.28), Vector2(side * (0.46 + 0.31 * pod_w), -0.25), Vector2(side * (0.46 + 0.35 * pod_w), 0.00), Vector2(side * (0.46 + 0.31 * pod_w), 0.27), Vector2(side * 0.46, 0.30)])
			_round_slab(body, pod, 0.16, 0.44, 0.54, 0.07, 0.13, paint, 0.42, 0.24)
			var edge: float = 0.46 + 0.375 * pod_w
			_bar(body, Vector3(side * edge, 0.205, -0.20), Vector3(side * edge, 0.205, 0.22), 0.016, 0.032, neon, 0.0, 0.3, NEON_GLOW)
			var top_edge: float = 0.46 + 0.28 * pod_w
			_tube(body, [Vector3(side * top_edge, 0.50, -0.20), Vector3(side * (top_edge + 0.03), 0.52, 0.02), Vector3(side * top_edge, 0.55, 0.24)], 0.014, trim, 0.5, 0.25)
		_tube(body, [Vector3(side * 0.43, 0.66, -0.34), Vector3(side * 0.47, 0.70, 0.02), Vector3(side * 0.47, 0.68, 0.46)], 0.021, accent, 0.3, 0.4)
		_tube(body, [Vector3(side * 0.485, 0.70, 0.46), Vector3(side * 0.485, 1.06, 0.50)], 0.048, accent, 0.25, 0.4, 0.0, 10)
	_make_cage(body, int(b.hoop))
	# --- Schalensitz, Fußraum und Pedale wie bei der Loft-Karosserie: passt zum abgesenkten Fahrer.
	_make_cockpit(body, paint, false)
	# --- Heckblock mit Lüftung, Sechseck-Rücklicht, orangen Ecken
	var rear_top: float = 0.74 if int(b.stacks) == 0 else 0.62
	_round_slab(body, _shape([[0.40, 0.50], [0.50, 0.72], [0.50, 1.08], [0.38, 1.21]]), 0.26, rear_top, rear_top - 0.10, 0.06, 0.09, CARBON, 0.35, 0.45)
	var hex := PackedVector2Array([Vector2(-0.09, 0.0), Vector2(-0.045, -0.075), Vector2(0.045, -0.075), Vector2(0.09, 0.0), Vector2(0.045, 0.075), Vector2(-0.045, 0.075)])
	_panel(body, hex, Vector3(0.0, 0.58 - (0.0 if int(b.stacks) == 0 else 0.08), 1.215), Vector3(PI / 2.0, 0.0, 0.0), 0.02, 0.012, neon, 0.0, 0.3, NEON_GLOW)
	_bar(body, Vector3(-0.16, 0.45 - (0.0 if int(b.stacks) == 0 else 0.08), 1.225), Vector3(0.16, 0.45 - (0.0 if int(b.stacks) == 0 else 0.08), 1.225), 0.018, 0.035, neon, 0.0, 0.3, NEON_GLOW)
	for slit in range(3):
		_bar(body, Vector3(-0.17, 0.30 + slit * 0.034, 1.224), Vector3(0.17, 0.30 + slit * 0.034, 1.224), 0.012, 0.014, Color("05080e"))
	for side in [-1.0, 1.0]:
		_bar(body, Vector3(side * 0.32, 0.78, 1.17), Vector3(side * 0.53, 0.71, 1.12), 0.022, 0.05, neon, 0.0, 0.3, NEON_GLOW)
		_bar(body, Vector3(side * 0.51, 0.70, 1.12), Vector3(side * 0.30, 0.43, 1.215), 0.02, 0.02, accent, 0.3, 0.4)
		# Achsgehäuse verbinden Wanne und Räder
		_rod(body, Vector3(side * 0.44, float(b.wheel_r_r), float(b.axle_r)), Vector3(side * (float(b.track_r) - float(b.wheel_w_r) * 0.5), float(b.wheel_r_r), float(b.axle_r)), 0.075, CARBON, 0.4, 0.45)
		_rod(body, Vector3(side * 0.40, 0.33, float(b.axle_f)), Vector3(side * (float(b.track_f) - float(b.wheel_w_f) * 0.5), float(b.wheel_r_f), float(b.axle_f)), 0.06, CARBON, 0.4, 0.45)
		# Düsen für den Boost
		_ring(body, Vector3(side * 0.30, 0.36, 1.225), 0.045, 0.062, GUNMETAL, 0.6, 0.0).rotation.x = PI / 2.0
		var flame := _mesh(self, _loft([Vector4(0, 0.052, 0.052, 0), Vector4(0.18, 0.095, 0.085, 0), Vector4(0.60, 0.002, 0.002, 0)], false, 16, 3), Vector3(side * 0.30, 0.36, 1.235), neon, 0.0, 0.25, 2.0)
		flame.hide()
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flames.append(flame)
	if int(b.stacks) > 0:
		_exhaust_stacks(body, int(b.stacks), bool(b.scoop))
	if int(b.rear_wing) > 0:
		_rear_wing(body, int(b.rear_wing), paint, trim, neon, bool(b.star))
	if bool(b.armor):
		_armor_plates(body, accent)
	# --- Unterboden-Leuchten
	if bool(spec.underglow) or str(spec.body) == "phantom":
		_bar(body, Vector3(0, 0.10, -0.95), Vector3(0, 0.10, 0.95), 0.80, 0.008, neon, 0.0, 0.3, 1.1)
	# --- Räder
	for side in [-1.0, 1.0]:
		_make_kit_wheel(side, float(b.axle_f), float(b.wheel_r_f), float(b.wheel_w_f), float(b.track_f), spec, bool(b.knobby))
		_make_kit_wheel(side, float(b.axle_r), float(b.wheel_r_r), float(b.wheel_w_r), float(b.track_r), spec, bool(b.knobby))


## Überrollbügel: 0 keiner, 1 Bügel hinter dem Fahrer, 2 voller Käfig (Buggy).
func _make_cage(body: Node3D, kind: int) -> void:
	if kind <= 0:
		return
	for side in [-1.0, 1.0]:
		_tube(body, [Vector3(side * 0.50, 0.56, 0.52), Vector3(side * 0.52, 0.98, 0.58), Vector3(side * 0.34, 1.20, 0.62)], 0.03, CARBON, 0.3, 0.45)
	_tube(body, [Vector3(-0.34, 1.20, 0.62), Vector3(0.0, 1.24, 0.63), Vector3(0.34, 1.20, 0.62)], 0.03, CARBON, 0.3, 0.45)
	if kind >= 2:
		for side in [-1.0, 1.0]:
			_tube(body, [Vector3(side * 0.47, 0.64, -0.36), Vector3(side * 0.44, 1.05, -0.28), Vector3(side * 0.34, 1.20, 0.30), Vector3(side * 0.34, 1.20, 0.62)], 0.03, CARBON, 0.3, 0.45)
		_tube(body, [Vector3(-0.44, 1.05, -0.28), Vector3(0.0, 1.10, -0.30), Vector3(0.44, 1.05, -0.28)], 0.03, CARBON, 0.3, 0.45)
		_tube(body, [Vector3(-0.36, 1.20, 0.30), Vector3(0.0, 1.24, 0.31), Vector3(0.36, 1.20, 0.30)], 0.026, CARBON, 0.3, 0.45)


func _front_wing(body: Node3D, paint: Color, trim: Color, neon: Color, z: float) -> void:
	_round_slab(body, PackedVector2Array([Vector2(-0.80, z), Vector2(0.80, z), Vector2(0.80, z + 0.16), Vector2(-0.80, z + 0.16)]), 0.16, 0.21, 0.23, 0.02, 0.04, paint, 0.4, 0.25)
	for side in [-1.0, 1.0]:
		_round_slab(body, PackedVector2Array([Vector2(side * 0.80, z - 0.01), Vector2(side * 0.84, z - 0.01), Vector2(side * 0.84, z + 0.19), Vector2(side * 0.80, z + 0.19)]), 0.12, 0.40, 0.44, 0.012, 0.02, trim, 0.4, 0.3)
	_bar(body, Vector3(-0.74, 0.215, z - 0.004), Vector3(0.74, 0.215, z - 0.004), 0.012, 0.014, neon, 0.0, 0.3, NEON_GLOW)


func _bull_bar(body: Node3D, front_z: float) -> void:
	_tube(body, [Vector3(-0.66, 0.30, front_z - 0.04), Vector3(-0.62, 0.52, front_z - 0.10), Vector3(0.62, 0.52, front_z - 0.10), Vector3(0.66, 0.30, front_z - 0.04)], 0.04, GUNMETAL, 0.6, 0.35)
	_tube(body, [Vector3(-0.30, 0.52, front_z - 0.10), Vector3(-0.30, 0.24, front_z - 0.02)], 0.032, GUNMETAL, 0.6, 0.35)
	_tube(body, [Vector3(0.30, 0.52, front_z - 0.10), Vector3(0.30, 0.24, front_z - 0.02)], 0.032, GUNMETAL, 0.6, 0.35)
	_tube(body, [Vector3(0.0, 0.52, front_z - 0.10), Vector3(0.0, 0.24, front_z - 0.02)], 0.032, GUNMETAL, 0.6, 0.35)


func _exhaust_stacks(body: Node3D, count: int, scoop: bool) -> void:
	var offsets: Array[float] = []
	if count >= 2:
		offsets.append(-0.30)
		offsets.append(0.30)
	else:
		offsets.append(0.0)
	for x in offsets:
		_tube(body, [Vector3(x, 0.60, 0.95), Vector3(x, 1.20, 0.98)], 0.058, Color("b7cddd"), 0.75, 0.25)
		_ring(body, Vector3(x, 1.215, 0.98), 0.052, 0.088, GUNMETAL, 0.6, 0.0)
	if scoop:
		_round_slab(body, _shape([[0.10, 0.62], [0.17, 0.78], [0.12, 0.96]]), 0.62, 0.70, 0.86, 0.03, 0.05, GUNMETAL, 0.6, 0.35)


func _rear_wing(body: Node3D, kind: int, paint: Color, trim: Color, neon: Color, star: bool) -> void:
	if kind == 1:
		# Entenbürzel über dem Heck
		_round_slab(body, _shape([[0.46, 1.06], [0.52, 1.30]]), 0.60, 0.74, 0.86, 0.03, 0.06, paint, 0.4, 0.25)
		return
	for side in [-1.0, 1.0]:
		_tube(body, [Vector3(side * 0.34, 0.70, 1.02), Vector3(side * 0.40, 1.14, 1.12)], 0.034, CARBON, 0.3, 0.45)
		_round_slab(body, PackedVector2Array([Vector2(side * 0.80, 1.04), Vector2(side * 0.86, 1.04), Vector2(side * 0.86, 1.34), Vector2(side * 0.80, 1.34)]), 1.06, 1.36, 1.40, 0.012, 0.02, trim, 0.4, 0.3)
	_round_slab(body, _shape([[0.80, 1.06], [0.80, 1.32]]), 1.16, 1.20, 1.26, 0.025, 0.04, paint, 0.42, 0.24)
	_bar(body, Vector3(-0.76, 1.255, 1.335), Vector3(0.76, 1.255, 1.335), 0.014, 0.018, neon, 0.0, 0.3, NEON_GLOW)
	if star:
		_slab(body, _star_outline(0.0, 1.19, 0.10, 0.042), 1.215, 1.236, 1.236, 0.004, trim, 0.4, 0.3, 0.0, false)


func _armor_plates(body: Node3D, accent: Color) -> void:
	for side in [-1.0, 1.0]:
		_round_slab(body, PackedVector2Array([Vector2(side * 0.80, -0.30), Vector2(side * 0.90, -0.26), Vector2(side * 0.92, 0.26), Vector2(side * 0.80, 0.30)]), 0.20, 0.56, 0.56, 0.02, 0.03, GUNMETAL, 0.55, 0.4, 0.0, false)
		_bar(body, Vector3(side * 0.925, 0.30, -0.22), Vector3(side * 0.925, 0.46, -0.04), 0.012, 0.05, accent, 0.2, 0.4)
		_bar(body, Vector3(side * 0.925, 0.30, 0.04), Vector3(side * 0.925, 0.46, 0.22), 0.012, 0.05, accent, 0.2, 0.4)


func _make_kit_wheel(side: float, axle: float, radius: float, width: float, track: float, spec: Dictionary, knobby: bool = false) -> void:
	var neon: Color = spec.neon
	var rim_color: Color = Color.WHITE if bool(spec.rim_neon) else spec.rim
	var half: float = width * 0.5
	var pivot := Node3D.new()
	pivot.name = "SteeringHub" if axle < 0 else "RearHub"
	pivot.position = Vector3(side * track, radius, axle)
	pivot.set_meta("front", axle < 0)
	pivot.set_meta("height", radius)
	add_child(pivot)
	wheel_pivots.append(pivot)
	var rotor := Node3D.new()
	rotor.rotation.z = PI / 2.0
	pivot.add_child(rotor)
	wheel_rotors.append(rotor)
	# Reifen mit gerundeter Schulter
	var tyre: Array[Vector4] = [
		Vector4(-half, radius * 0.60, radius * 0.60, 0), Vector4(-half * 0.94, radius * 0.80, radius * 0.80, 0),
		Vector4(-half * 0.64, radius * 0.97, radius * 0.97, 0), Vector4(-half * 0.30, radius, radius, 0),
		Vector4(half * 0.30, radius, radius, 0), Vector4(half * 0.64, radius * 0.97, radius * 0.97, 0),
		Vector4(half * 0.94, radius * 0.80, radius * 0.80, 0), Vector4(half, radius * 0.60, radius * 0.60, 0)]
	_mesh(rotor, _loft(tyre, true, 36, 3), Vector3.ZERO, Color("0b111b"), 0.0, 0.83)
	var outside: float = -side * half
	var inward: float = side
	# Felge: dunkle Scheibe, Leuchtring auf der Reifenflanke, fünf Speichen, Nabenkappe
	var disc := CylinderMesh.new()
	disc.top_radius = radius * 0.63
	disc.bottom_radius = radius * 0.63
	disc.height = 0.022
	disc.radial_segments = 28
	_mesh(rotor, disc, Vector3(0, outside + inward * 0.016, 0), GUNMETAL, 0.7, 0.3)
	var glow_ring: MeshInstance3D = _ring(rotor, Vector3(0, outside, 0), radius * 0.655 - 0.016, radius * 0.655 + 0.016, neon, 0.0, NEON_GLOW)
	glow_ring.material_override = _mat(neon, 0.0, 0.3, NEON_GLOW)
	for spoke in range(5):
		var angle: float = float(spoke) * TAU / 5.0
		var from := Vector3(cos(angle) * 0.05, outside - inward * 0.002, sin(angle) * 0.05)
		var to := Vector3(cos(angle + 0.16) * radius * 0.60, outside - inward * 0.002, sin(angle + 0.16) * radius * 0.60)
		_bar(rotor, from, to, 0.05, 0.020, rim_color, 0.65, 0.28, 1.2 if bool(spec.rim_neon) else 0.0)
	_ellipsoid(rotor, Vector3(0, outside - inward * 0.012, 0), Vector3(0.050, 0.020, 0.050), GUNMETAL, 0.7, 0.28)
	var cap: MeshInstance3D = _ellipsoid(rotor, Vector3(0, outside - inward * 0.024, 0), Vector3(0.026, 0.010, 0.026), neon)
	cap.material_override = _mat(neon, 0.0, 0.3, NEON_GLOW)
	# Bremsscheibe hinter den Speichen, Sattel steht still am Achsträger
	var brake := CylinderMesh.new()
	brake.top_radius = radius * 0.50
	brake.bottom_radius = radius * 0.50
	brake.height = 0.012
	brake.radial_segments = 24
	_mesh(rotor, brake, Vector3(0, outside + inward * 0.075, 0), Color("323d4f"), 0.7, 0.3)
	var caliper: MeshInstance3D = _box(pivot, Vector3(side * (half - 0.06), radius * 0.46, 0.0), Vector3(0.05, 0.12, 0.09), spec.accent, 0.35)
	caliper.material_override = _mat(spec.accent, 0.35, 0.35)
	# Profil: zwei Längsrillen; Geländereifen bekommen grobe Stollen am Rand
	for groove in [-0.30, 0.30]:
		var groove_ring: MeshInstance3D = _ring(rotor, Vector3(0, half * groove, 0), radius - 0.006, radius + 0.002, Color("05090f"), 0.0)
		groove_ring.material_override = _mat(Color("05090f"), 0.0, 0.83)
	if knobby:
		for lug in range(20):
			var angle: float = float(lug) * TAU / 20.0
			for row in [-1.0, 1.0]:
				var at := Vector3(cos(angle) * radius * 0.99, row * half * 0.52, sin(angle) * radius * 0.99)
				var block := _box(rotor, at, Vector3(0.026, half * 0.62, 0.075), Color("0b111b"), 0.0)
				block.material_override = _mat(Color("0b111b"), 0.0, 0.83)
				block.rotation.y = -angle
	# Aufhängung: Querlenker, Feder und Dämpfer
	var hub: Vector3 = pivot.position
	_rod(self, Vector3(side * 0.40, 0.30, axle - 0.12), hub + Vector3(-side * (half - 0.04), -0.02, -0.02), 0.024, GUNMETAL, 0.6, 0.3)
	_rod(self, Vector3(side * 0.40, 0.30, axle + 0.12), hub + Vector3(-side * (half - 0.04), -0.02, 0.02), 0.024, GUNMETAL, 0.6, 0.3)
	var spring_start := Vector3(side * 0.47, 0.62, axle)
	var spring_end := hub + Vector3(-side * (half - 0.07), 0.04, 0)
	_rod(self, spring_start, spring_end, 0.03, GUNMETAL, 0.6, 0.3)
	for loop in range(4):
		var coil := _ring(self, spring_start.lerp(spring_end, 0.22 + float(loop) * 0.16), 0.045, 0.058, spec.accent, 0.35)
		coil.quaternion = Quaternion(Vector3.UP, (spring_end - spring_start).normalized())
	if axle > 0:
		var spark := _mesh(self, _loft([Vector4(0, 0.07, 0.013, 0), Vector4(0.2, 0.03, 0.035, 0), Vector4(0.45, 0.002, 0.002, 0)], false, 12, 2), hub + Vector3(0, -radius + 0.07, 0.14), neon, 0, 0.3, 2.0)
		spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		spark.hide()
		sparks.append(spark)


func _racing_sleeve_frame(side: float, fraction: float) -> Transform3D:
	var wrist := Vector3(-side * 0.13, -0.16, -0.355)
	var along: Vector3 = wrist.normalized()
	var length_value: float = wrist.length() - 0.045
	var bend := Vector3(side * 0.09, -0.015, 0)
	bend -= along * bend.dot(along)
	var centre: Vector3 = along * length_value * fraction + bend * sin(PI * fraction)
	var tangent: Vector3 = along * length_value + bend * PI * cos(PI * fraction)
	return Transform3D(Basis(Quaternion(Vector3.UP, tangent.normalized())), centre)


func _curve_racing_sleeve(source: ArrayMesh, side: float) -> ArrayMesh:
	var arrays: Array = source.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var wrist := Vector3(-side * 0.13, -0.16, -0.355)
	var length_value: float = wrist.length() - 0.045
	for i in range(vertices.size()):
		var point: Vector3 = vertices[i]
		var frame: Transform3D = _racing_sleeve_frame(side, point.y / length_value)
		vertices[i] = frame * Vector3(point.x, 0, point.z)
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
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
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var sleeve := ArrayMesh.new()
	sleeve.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if source.has_meta("far_geometry"):
		sleeve.set_meta("far_geometry", _curve_racing_sleeve(source.get_meta("far_geometry"), side))
	return sleeve


func _make_racing_sleeve(limb: Node3D, side: float, is_lumo: bool) -> void:
	var wrist := Vector3(-side * 0.13, -0.16, -0.355)
	var cuff_distance: float = wrist.length() - 0.045
	var sleeve_shape: ArrayMesh = _curve_racing_sleeve(
		_loft([
			Vector4(0, 0.075, 0.075, 0),
			Vector4(0.11, 0.105, 0.098, 0),
			Vector4(0.23, 0.086, 0.082, 0),
			Vector4(cuff_distance, 0.064, 0.060, 0)
		], true, 20, 4), side
	)
	var sleeve := _mesh(limb, sleeve_shape, Vector3.ZERO, NAVY, 0.0, 0.82)
	sleeve.name = "RacingSleeve"
	sleeve_shape.set_meta("cuff_vertex_start", sleeve_shape.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() - 20)
	sleeve_shape.set_meta("cuff_vertex_count", 20)
	var seam: Array[Vector3] = []
	var sleeve_arrays: Array = sleeve_shape.surface_get_arrays(0)
	var sleeve_vertices: PackedVector3Array = sleeve_arrays[Mesh.ARRAY_VERTEX]
	var sleeve_normals: PackedVector3Array = sleeve_arrays[Mesh.ARRAY_NORMAL]
	# Sewn cyan follows the real curved surface; approximating its radius
	# would bury the middle of the seam underneath the elbow.
	for row in [1, 3, 5, 7, 9, 11]:
		var vertex: int = row * 20 + (0 if side > 0 else 10)
		seam.append(sleeve_vertices[vertex] + sleeve_normals[vertex] * 0.005)
	_ribbon(limb, seam, 0.009, ICE)
	if is_lumo:
		for band in range(2):
			var frame: Transform3D = _racing_sleeve_frame(side, 0.26 + band * 0.12)
			var stripe := _ring(limb, Vector3.ZERO, 0.098, 0.116, ORANGE if band == 0 else WHITE)
			stripe.scale.y = 1.35
			_attach(stripe, frame)


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
			# Retain the authored arm shells at their existing shoulders. Both
			# grips follow the physical wheel while the torso leans underneath.
			var origin := Vector3(
				side * SHOULDER_RIGHT.x, SHOULDER_RIGHT.y, SHOULDER_RIGHT.z
			)
			var limb := Node3D.new()
			limb.name = "ArmLeft" if side < 0 else "ArmRight"
			limb.position = origin
			driver.add_child(limb)
			racing_arm_joints.append(limb)
			if is_lumo and side > 0:
				arm_right = limb
			_make_racing_sleeve(limb, side, is_lumo)
			_ellipsoid(limb, Vector3(side * 0.29, 1.215, 0.015) - origin, Vector3(0.092, 0.056, 0.096), NAVY if is_lumo else WHITE, 0.07, 0.6)
			var leg := _ellipsoid(driver, Vector3(side * 0.16, 0.81, -0.18), Vector3(0.105, 0.105, 0.16), NAVY, 0, 0.72)
			leg.name = "SeatedLegLeft" if side < 0 else "SeatedLegRight"
			var glove_color: Color = GLOVE if is_lumo else WHITE
			var glove := _ellipsoid(limb, Vector3(side * 0.16, 1.055, -0.34) - origin, Vector3(0.079, 0.070, 0.083), glove_color, 0, 0.68)
			glove.name = "GripGlove"
			glove.rotation.z = side * -0.2
			var grip := Node3D.new()
			grip.name = "SteeringGripAnchor"
			grip.position = glove.position
			limb.add_child(grip)
			racing_rest_grips.append(grip.position)
			wheel_rest_grips.append(
				steering_wheel.transform.affine_inverse() * (origin + grip.position)
			)
			for digit in range(3):
				_ellipsoid(limb, Vector3(side * (0.126 + digit * 0.027), 1.036, -0.393) - origin, Vector3(0.016, 0.036, 0.022), glove_color, 0, 0.68)
			# These are fabric sleeves, sewn stripes and cloth gloves, not
			# metallic body trim. Share their matte finish while vertex colours
			# retain every navy/cyan/orange/white detail after arm batching.
			for cloth_part in limb.get_children():
				if cloth_part is MeshInstance3D:
					var finish: StandardMaterial3D = cloth_part.material_override
					cloth_part.material_override = _mat(finish.albedo_color, 0.0, 0.82)
			var boot := _ellipsoid(driver, Vector3(side * 0.18, 0.80, -0.24), Vector3(0.12, 0.09, 0.14), NAVY, 0.08, 0.6)
			boot.name = "RacingBootLeft" if side < 0 else "RacingBootRight"
			var sole := _ellipsoid(driver, Vector3(side * 0.18, 0.742, -0.24), Vector3(0.119, 0.026, 0.15), WHITE, 0.08, 0.6)
			sole.name = "BootSoleLeft" if side < 0 else "BootSoleRight"
	head = Node3D.new()
	head.name = "LumoHead"
	head.position = Vector3(0, 1.68, 0.07)
	driver.add_child(head)
	var head_width: float = 0.43 if animal != "rabbit" else 0.36
	var head_profile: Array[Vector4] = [Vector4(-0.32, 0.055, 0.060, -0.025), Vector4(-0.26, 0.27, 0.225, -0.003), Vector4(-0.13, head_width, 0.30, 0.006), Vector4(0.055, head_width * 0.98, 0.326, 0.015), Vector4(0.23, 0.31, 0.277, 0.025), Vector4(0.33, 0.17, 0.17, 0.038), Vector4(0.375, 0.008, 0.012, 0.038)]
	var head_mesh: Mesh = _loft(head_profile, true, 48, 5)
	if is_lumo:
		head_mesh = CHARACTER_FINISH.coat(head_mesh, fur, cream, "head")
	_fur(head, head_mesh, Vector3.ZERO, Color.WHITE if is_lumo else fur, 2900, 0.016, 715)
	# The cheek mask is sculpted as two swept, tapered volumes, with a joined muzzle.
	for side in [-1.0, 1.0]:
		var cheek_mesh: Mesh = _loft(
			[
				Vector4(-0.15, 0.045, 0.035, -0.012),
				Vector4(-0.045, 0.145, 0.130, -0.010),
				Vector4(0.095, 0.16, 0.135, 0.005),
				Vector4(0.245, 0.11, 0.077, 0.023),
				Vector4(0.335, 0.010, 0.013, 0.050),
			],
			false, 32, 4
		)
		if is_lumo:
			cheek_mesh = CHARACTER_FINISH.wrap_cheek(cheek_mesh, side)
		var cheek := _fur(
			head, cheek_mesh, Vector3(side * 0.12, -0.16, -0.21),
			cream, 700, 0.028, 821 + int(side)
		)
		cheek.rotation.y = side * PI / 2
		if not is_lumo:
			# Other drivers retain their existing cheek anatomy. Lumo's continuous
			# cream head and wrapped cheek now provide the side/rear fringe.
			_fur(head, _loft([Vector4(-0.285, 0.012, 0.018, 0), Vector4(-0.22, 0.10, 0.125, 0.018), Vector4(-0.16, 0.137, 0.153, 0.008), Vector4(-0.10, 0.067, 0.102, 0), Vector4(-0.075, 0.005, 0.010, 0)], true, 28, 4), Vector3(side * 0.315, 0, 0.044), cream, 330, 0.025, 531 + int(side))
		if not is_lumo:
			# Lumo's wrapped cheek and its fur now carry the continuous silhouette.
			# Keep the other drivers' original separate cheek tufts.
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
		if is_lumo:
			var brow_root := Node3D.new()
			head.add_child(brow_root)
			_ribbon(brow_root, brow, 0.013, fur.darkened(0.68))
			for part in brow_root.get_children():
				if part is MeshInstance3D:
					part.material_override = _mat(fur.darkened(0.68), 0.0, 0.82)
		else:
			_ribbon(head, brow, 0.012, fur.darkened(0.45))
	var muzzle: Array[Vector4] = [Vector4(-0.455, 0.038, 0.028, -0.101), Vector4(-0.418, 0.113, 0.060, -0.122), Vector4(-0.351, 0.168, 0.090, -0.135), Vector4(-0.264, 0.15, 0.08, -0.15), Vector4(-0.21, 0.01, 0.012, -0.15)]
	_fur(head, _loft(muzzle, false, 32, 4), Vector3.ZERO, cream, 350, 0.009, 228)
	# A small triangular, polished nose and a real mouth cavity underneath.
	var nose := _mesh(head, _loft([Vector4(-0.16, 0.004, 0.016, -0.453), Vector4(-0.112, 0.075, 0.044, -0.463), Vector4(-0.079, 0.060, 0.032, -0.449), Vector4(-0.068, 0.004, 0.005, -0.435)], true, 24, 4), Vector3.ZERO, Color("2a1d22"), 0.08, 0.22)
	nose.name = "SculptedNose"
	_ellipsoid(head, Vector3(-0.020, -0.09, -0.493), Vector3(0.020, 0.009, 0.005), Color("ae8f85"), 0, 0.25)
	# The original Lumo mascot smiles with an open, friendly mouth, visible
	# even when the kart camera is pulled back. Keep his real 3D jaw viseme;
	# only fox gets the extra sculpted cavity, teeth and tongue. Other
	# selectable drivers retain their existing closed-mouth geometry.
	if is_lumo:
		var smile := _mesh(
			head, CHARACTER_FINISH.smile_shell(), Vector3.ZERO,
			Color("382029"), 0.0, 0.82
		)
		smile.name = "LumoSmileCavity"
		var teeth := _ellipsoid(
			head, Vector3(0, -0.207, -0.389),
			Vector3(0.086, 0.010, 0.006), Color("fff6ec"), 0.0, 0.55
		)
		teeth.name = "LumoSmileTeeth"
		var tongue := _ellipsoid(
			head, Vector3(0, -0.274, -0.381),
			Vector3(0.057, 0.016, 0.006), Color("d87280"), 0.0, 0.68
		)
		tongue.name = "LumoSmileTongue"
	else:
		_ellipsoid(head, Vector3(0, -0.231, -0.285), Vector3(0.098, 0.027, 0.046), Color("472e39"), 0, 0.7)
	var chin_profile: Array[Vector4] = [Vector4(-0.31, 0.025, 0.025, -0.18), Vector4(-0.265, 0.16, 0.11, -0.17), Vector4(-0.22, 0.19, 0.12, -0.17)]
	if is_lumo:
		# A continuous cream chin supports the mouth in front AND side view.
		chin_profile = [Vector4(-0.337, 0.025, 0.035, -0.23), Vector4(-0.302, 0.145, 0.112, -0.240), Vector4(-0.255, 0.225, 0.120, -0.245), Vector4(-0.20, 0.235, 0.112, -0.250), Vector4(-0.165, 0.17, 0.080, -0.240)]
	_fur(head, _loft(chin_profile, true, 32 if is_lumo else 28, 4 if is_lumo else 3), Vector3.ZERO, cream, 220, 0.011, 4431)
	jaw = Node3D.new()
	jaw.name = "MouthViseme"
	jaw.position = Vector3(0, -0.305, -0.287) if is_lumo else Vector3(0, -0.257, -0.263)
	jaw_rest_position = jaw.position
	head.add_child(jaw)
	if is_lumo:
		# The lower lip includes a hidden upper root inside the cream chin.
		# It stays connected when the speech viseme lowers the jaw.
		_mesh(jaw, _loft([
			Vector4(-0.043, 0.018, 0.018, 0.005),
			Vector4(-0.028, 0.085, 0.042, -0.010),
			Vector4(0.0, 0.124, 0.051, -0.012),
			Vector4(0.04, 0.124, 0.067, 0.032),
			Vector4(0.09, 0.075, 0.045, 0.075)
		], true, 24, 3), Vector3.ZERO, cream, 0.0, 0.82)
	else:
		_ellipsoid(jaw, Vector3(0, 0, -0.018), Vector3(0.123, 0.033, 0.054), cream, 0, 0.82)
	if not is_lumo:
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
	# Lumos ears fan out like the original rounded-triangle silhouette;
	# the older, upright geometry made him look like a different fox.
	ear.rotation.z = -side * (0.41 if animal == "fox" else 0.23)
	if animal == "fox":
		ear.scale = Vector3(1.12, 0.96, 1.0)
	head.add_child(ear)
	ear_joints.append(ear)
	ear_rest_angles.append(ear.rotation.z)
	if animal == "rabbit":
		_mesh(ear, _loft([Vector4(0, 0.073, 0.061, 0), Vector4(0.18, 0.093, 0.071, 0), Vector4(0.44, 0.076, 0.053, 0.025), Vector4(0.57, 0.008, 0.008, 0.034)], true, 24, 4), Vector3.ZERO, fur)
		_mesh(ear, _loft([Vector4(0.07, 0.023, 0.008, -0.057), Vector4(0.22, 0.051, 0.012, -0.071), Vector4(0.42, 0.039, 0.01, -0.029), Vector4(0.51, 0.004, 0.004, -0.01)], true, 20, 4), Vector3.ZERO, Color("d9a8b7"))
	elif animal in ["otter", "badger"]:
		_mesh(ear, _loft([Vector4(-0.055, 0.025, 0.032, 0), Vector4(0.035, 0.11, 0.079, 0), Vector4(0.12, 0.075, 0.055, 0), Vector4(0.16, 0.005, 0.005, 0)], true, 24, 4), Vector3.ZERO, fur.darkened(0.16))
		_ellipsoid(ear, Vector3(0, 0.05, -0.073), Vector3(0.06, 0.060, 0.012), cream)
	else:
		var outer_ear: Mesh = _loft([
			Vector4(-0.075, 0.085, 0.078, 0), Vector4(0.0, 0.135, 0.092, 0),
			Vector4(0.14, 0.112, 0.080, 0.006), Vector4(0.32, 0.046, 0.048, 0.017),
			Vector4(0.40, 0.003, 0.004, 0.024)
		], true, 32, 4)
		if animal == "fox":
			outer_ear = CHARACTER_FINISH.coat(outer_ear, fur, cream, "ear")
		_fur(
			ear, outer_ear, Vector3.ZERO, Color.WHITE if animal == "fox" else fur.darkened(0.06),
			300, 0.021, 440 + int(side)
		)
		var ear_lining := Color("f0d6bc") if animal == "fox" else cream
		_fur(ear, _loft([Vector4(-0.033, 0.063, 0.026, -0.072), Vector4(0.055, 0.088, 0.035, -0.065), Vector4(0.17, 0.063, 0.028, -0.058), Vector4(0.31, 0.007, 0.005, -0.029)], true, 28, 4), Vector3.ZERO, ear_lining, 200, 0.016, 555 + int(side))
		for fluff in range(3):
			var tuft := _mesh(ear, _loft([Vector4(0, 0.022, 0.012, 0), Vector4(0.05, 0.029, 0.018, 0), Vector4(0.105, 0.002, 0.002, 0)], true, 12, 3), Vector3(-0.030 + fluff * 0.031, 0.012 + (fluff % 2) * 0.034, -0.10), cream)
			tuft.rotation.z = (fluff - 1) * -0.30


func _make_eye(side: float, fur_shadow: Color) -> void:
	var eye := Node3D.new()
	eye.name = "Eye"
	# Compared with the previous full spherical eyeball, this sculpt keeps
	# the brown iris but recesses the flatter white surface into the cheek.
	# Do not alter the existing joint, blink, brow or non-fox animal anatomy.
	eye.position = (
		Vector3(side * 0.173, 0.065, -0.274)
		if animal == "fox" else Vector3(side * 0.169, 0.052, -0.282)
	)
	eye.rotation.y = -side * (0.33 if animal == "fox" else 0.12)
	head.add_child(eye)
	eyes.append(eye)
	if animal == "fox":
		# Vertical almond-like shell, not a 6 cm protruding sphere.
		_ellipsoid(eye, Vector3(0, 0.005, 0.008), Vector3(0.113, 0.128, 0.025), fur_shadow)
		_ellipsoid(eye, Vector3(0, 0, -0.004), Vector3(0.100, 0.114, 0.024), WHITE, 0.0, 0.42)
	else:
		_ellipsoid(eye, Vector3(0, 0.005, 0.006), Vector3(0.134, 0.155, 0.064), fur_shadow)
		_ellipsoid(eye, Vector3(0, 0, -0.009), Vector3(0.119, 0.141, 0.065), WHITE, 0, 0.3)
	var iris_size := Vector3(0.076, 0.082, 0.008) if animal == "fox" else Vector3(0.075, 0.093, 0.018)
	var pupil_size := Vector3(0.047, 0.051, 0.006) if animal == "fox" else Vector3(0.049, 0.062, 0.013)
	if animal == "fox":
		_mesh(
			eye, CHARACTER_FINISH.eye_overlay(iris_size, Vector3(0.100, 0.114, 0.024), Vector2(-side * 0.006, -0.009), 0.0015, true), Vector3(-side * 0.006, -0.009, -0.004),
			Color.WHITE, 0.08, 0.27
		)
	else:
		_ellipsoid(eye, Vector3(-side * 0.008, -0.009, -0.066), iris_size, Color("287788"), 0.08, 0.22)
	if animal == "fox":
		_mesh(eye, CHARACTER_FINISH.eye_overlay(pupil_size, Vector3(0.100, 0.114, 0.024), Vector2(-side * 0.006, -0.004), 0.003, false), Vector3(-side * 0.006, -0.004, -0.004), Color("080c12"), 0.10, 0.18)
	else:
		_ellipsoid(eye, Vector3(-side * 0.008, -0.004, -0.081), pupil_size, Color("080c12"), 0.10, 0.15)
	_ellipsoid(
		eye, Vector3(-0.022, 0.027, -0.031) if animal == "fox" else Vector3(-0.026, 0.032, -0.093),
		Vector3(0.014, 0.017, 0.003) if animal == "fox" else Vector3(0.019, 0.025, 0.008), Color.WHITE, 0, 0.1
	)
	_ellipsoid(
		eye, Vector3(0.019, -0.033, -0.030) if animal == "fox" else Vector3(0.020, -0.038, -0.093),
		Vector3(0.005, 0.007, 0.002) if animal == "fox" else Vector3(0.007, 0.010, 0.004), Color.WHITE, 0, 0.1
	)


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
	var tail_mesh: Mesh = _loft(tail_shape, false, 32, 4)
	if animal == "fox":
		tail_mesh = CHARACTER_FINISH.coat(tail_mesh, fur, cream, "tail")
	var mesh := _fur(
		tail, tail_mesh, Vector3.ZERO, Color.WHITE if animal == "fox" else fur,
		1550 if animal == "fox" else 950, 0.033, 7138
	)
	mesh.scale *= scale_factor
	if animal == "cat":
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
		# Keep one visible character, including at LOD distance. The rigged
		# skin must never be baked into a rigid proxy or drawn over old Lumo.
		if child == lumo_animation or (child == driver and _far_chassis_only):
			continue
		if child is MeshInstance3D:
			if flames.has(child) or sparks.has(child) or child.has_meta("near_only") or child.mesh.has_meta("far_skip"):
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
	_far_with_driver = tool.commit()
	# Keep a chassis-only alternative for the same fox vehicle. This small
	# proxy avoids rebuilding the Kart (and deleting shield/host attachments)
	# when the visual is enabled or disabled after it entered the scene tree.
	if animal == "fox":
		var chassis := SurfaceTool.new()
		chassis.begin(Mesh.PRIMITIVE_TRIANGLES)
		chassis.set_material(_vertex_material(_mat(Color.WHITE, 0.16, 0.58)))
		_far_chassis_only = true
		_append_far(self, Transform3D.IDENTITY, chassis)
		_far_chassis_only = false
		_far_without_driver = chassis.commit()
	far_mesh = MeshInstance3D.new()
	far_mesh.name = "DistantKart"
	far_mesh.mesh = _far_with_driver
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


func _update_lumo_visual(delta: float) -> void:
	if steering_wheel:
		steering_wheel.rotation.z = -motion_steer * 0.40
	lumo_animation.set_reduced_motion(reduced_motion)
	lumo_animation.apply_vehicle_sample(
		motion_speed, motion_steer, driver_airborne, driver_hit_pending, motion_boost, motion_drift
	)
	driver_hit_pending = false
	lumo_animation.advance_tick(delta)


func _process(delta: float) -> void:
	if driver_animation_paused:
		return
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
	if is_instance_valid(lumo_animation):
		# The animated player stays the same character in both LODs. Keep
		# its wheel anchors current even while the chassis uses a far proxy.
		_update_lumo_visual(delta)
	if far_detail:
		return
	if camera and camera.global_position.distance_squared_to(global_position) > 225.0:
		if not camera.is_position_in_frustum(global_position + Vector3.UP):
			return
	for i in range(wheel_rotors.size()):
		wheel_rotors[i].quaternion = Quaternion(Vector3.BACK, PI / 2) * Quaternion(Vector3.UP, wheel_spin_phase)
		wheel_pivots[i].rotation.y = -motion_steer * 0.34 if wheel_pivots[i].get_meta("front") else 0.0
		var hub_height: float = float(wheel_pivots[i].get_meta("height", 0.35))
		wheel_pivots[i].position.y = hub_height if reduced_motion else hub_height + sin(animation_time * 11.0 + i * 1.7) * minf(0.010, absf(motion_speed) * 0.0005)
	if is_instance_valid(lumo_animation):
		return
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
		jaw.position = jaw_rest_position + Vector3(0, -speaking_amount * 0.035, 0)
	if tail and not reduced_motion:
		tail.rotation.y = 0.63 + sin(animation_time * 2.6) * 0.055 - motion_steer * 0.07
	if steering_wheel:
		steering_wheel.rotation.z = -motion_steer * 0.40
	if celebration_place > 0:
		_apply_celebration(delta)
	_solve_steering_grips(delta)


func _solve_steering_grips(delta: float) -> void:
	if not steering_wheel or not driver:
		return
	var cheer: bool = arm_right != null and celebration_place >= 1 and celebration_place <= 3
	arm_blend = move_toward(arm_blend, 1.0 if cheer else 0.0, delta * 3.2)
	var raise: float = smoothstep(0.0, 1.0, arm_blend)
	for i in range(racing_arm_joints.size()):
		var arm: Node3D = racing_arm_joints[i]
		var rest: Vector3 = racing_rest_grips[i]
		var target: Vector3 = (
			driver.to_local(steering_wheel.to_global(wheel_rest_grips[i])) - arm.position
		)
		# Rotate around the unchanged shoulder and stretch only along the arm
		# direction. This reaches the rim without scaling its width or adding
		# a second rig/skin. The rest pose remains geometrically identical.
		var alignment := Basis(Quaternion(Vector3.UP, rest.normalized()))
		var stretch_ratio: float = target.length() / rest.length()
		var stretch: Basis = (
			alignment * Basis.from_scale(Vector3(1, stretch_ratio, 1)) * alignment.transposed()
		)
		var rotation := Quaternion(rest.normalized(), target.normalized())
		var grip_pose := Basis(rotation) * stretch
		if arm == arm_right and raise > 0.0:
			# Existing victory deliberately releases only the right hand; the
			# left stays on the moving wheel throughout the finish coast.
			var wave: float = 0.0 if reduced_motion else sin(celebration_time * TAU * 1.8) * 0.3
			var cheer_pose := (
				Quaternion(Vector3.BACK, wave)
				* Quaternion(ARM_REST_DIR.normalized(), ARM_CHEER_DIR.normalized())
			)
			var cheer_stretch: Basis = (
				alignment
				* Basis.from_scale(Vector3(1, lerpf(stretch_ratio, 1.0, raise), 1))
				* alignment.transposed()
			)
			arm.basis = Basis(rotation.slerp(cheer_pose, raise)) * cheer_stretch
		else:
			arm.basis = grip_pose


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
