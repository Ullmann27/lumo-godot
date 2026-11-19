extends Node3D
## Dschungelherz scenery for the measured 3600 m course (kart_jungle_course.gd).
##
## Built from the shared instanced prop kinds of kart_world.gd, so every section
## stays one MultiMesh batch per kind and cell on Android. Visual only: the
## measured road, rails and collision come from kart_jungle_course.gd and are
## never touched here. Placement keeps a clear margin to every part of the road,
## including the stacked canopy sections.

const JUNGLE = preload("res://scripts/games/kart_jungle_course.gd")
const GROUND_Y: float = 0.0
const CLEARANCE: float = 3.2

const LEAF_GREENS: Array[Color] = [
	Color("1f6b3a"), Color("2c8a47"), Color("3f9e4f"), Color("17583a"), Color("4caf63")
]
const BARK: Array[Color] = [Color("5a3d28"), Color("6b4a31"), Color("4a3324")]
const BLOSSOMS: Array[Color] = [
	Color("ff6fa8"), Color("ffd24a"), Color("ff8a3d"), Color("b46cff"), Color("5fd7ff")
]

var _world: Node3D
var _rng := RandomNumberGenerator.new()
var _low: bool = false
var _fireflies: CPUParticles3D
var _rain: CPUParticles3D
var _celebration: CPUParticles3D
var _water: Array[MeshInstance3D] = []
var _time: float = 0.0
var placed_props: int = 0


func build(world: Node3D) -> void:
	_world = world
	_low = bool(world.get("low_detail"))
	_rng.seed = 36001115
	_build_ground()
	var length: float = float(world.length)
	var step: float = 9.0 if _low else 6.0
	var distance: float = 0.0
	while distance < length:
		var section: int = clampi(int(distance / JUNGLE.SECTION_LENGTH), 0, 11)
		for side in [-1.0, 1.0]:
			_dress_station(distance, side, section)
		distance += step
	_build_landmarks()
	_build_effects()
	world.set_meta("jungle_environment_props", placed_props)
	world.set_meta("jungle_environment_sections", 12)


# --- placement helpers -------------------------------------------------------

func _clear_of_road(point: Vector3, margin: float = CLEARANCE) -> bool:
	var curve: Curve3D = _world.curve
	var closest: Vector3 = curve.get_closest_point(point)
	var flat := Vector2(point.x - closest.x, point.z - closest.z)
	var road_distance: float = curve.get_closest_offset(point)
	var half: float = JUNGLE.width_at(road_distance) * 0.5 + 1.5
	return flat.length() > half + margin


func _put(kind: String, at: Vector3, size: Vector3, color: Color,
		basis: Basis = Basis.IDENTITY, glow: bool = false) -> void:
	_world._prop(kind, at, size, color, basis, glow)
	placed_props += 1


func _pick(colors: Array[Color]) -> Color:
	return colors[_rng.randi_range(0, colors.size() - 1)]


func _turn() -> Basis:
	return Basis(Vector3.UP, _rng.randf_range(0.0, TAU))


# --- terrain -----------------------------------------------------------------

func _build_ground() -> void:
	var ground := MeshInstance3D.new()
	ground.name = "JungleFloor"
	var plane := PlaneMesh.new()
	plane.size = Vector2(1500.0, 1200.0)
	plane.subdivide_width = 0
	plane.subdivide_depth = 0
	ground.mesh = plane
	ground.position = Vector3(45.0, GROUND_Y, 35.0)
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("2f6b3f")
	floor_material.roughness = 0.95
	ground.material_override = floor_material
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)
	# Smaragdfluss (section 3) and Flusskaskaden (section 10) get real water.
	for section in [2, 9]:
		var start: float = section * JUNGLE.SECTION_LENGTH
		var d: float = start
		while d < start + JUNGLE.SECTION_LENGTH:
			var basis: Basis = _world.frame(d)
			var centre: Vector3 = _world.position_at(d, 0.0)
			var pool := MeshInstance3D.new()
			pool.name = "Smaragdwasser%d_%d" % [section, int(d)]
			var water_plane := PlaneMesh.new()
			water_plane.size = Vector2(70.0, 34.0)
			pool.mesh = water_plane
			pool.position = Vector3(centre.x, GROUND_Y + 0.08, centre.z)
			pool.basis = Basis(Vector3.UP, atan2(basis.z.x, basis.z.z))
			var water := StandardMaterial3D.new()
			water.albedo_color = Color(0.13, 0.62, 0.58, 0.82)
			water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			water.metallic = 0.2
			water.roughness = 0.08
			water.emission_enabled = true
			water.emission = Color("0f4f4a")
			water.emission_energy_multiplier = 0.35
			pool.material_override = water
			pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(pool)
			_water.append(pool)
			d += 30.0


# --- vegetation ----------------------------------------------------------------

func _dress_station(distance: float, side: float, section: int) -> void:
	var half: float = JUNGLE.width_at(distance) * 0.5
	var road_y: float = _world.position_at(distance).y
	# Near band: ferns, flowers and stones directly behind the timber rail.
	var near: Vector3 = _world.position_at(distance, side * (half + _rng.randf_range(3.5, 7.0)))
	near.y = GROUND_Y if road_y > 7.0 else road_y - 0.4
	if _clear_of_road(near, 1.6):
		if section == 8:
			_flower_bed(near)
		elif _rng.randf() < 0.55:
			_fern(near)
		else:
			_put("rock", near, Vector3.ONE * _rng.randf_range(0.8, 1.9), Color("6d7464"), _turn())
	# Mid band: the actual forest.
	var count: int = 1 if _low else 2
	for i in count:
		var lateral: float = side * (half + _rng.randf_range(8.0, 30.0))
		var at: Vector3 = _world.position_at(distance + _rng.randf_range(-2.5, 2.5), lateral)
		at.y = GROUND_Y
		if not _clear_of_road(at):
			continue
		var canopy_target: float = maxf(road_y + 7.0, 14.0)
		if section in [0, 11] and _rng.randf() < 0.6:
			_palm(at, _rng.randf_range(9.0, 14.0))
		elif section == 1 or (section in [5, 6, 7] and _rng.randf() < 0.45):
			_giant_tree(at, canopy_target + _rng.randf_range(4.0, 10.0))
		else:
			_tree(at, canopy_target + _rng.randf_range(-2.0, 6.0))
	# Far band: dense backdrop crowns that close the horizon cheaply.
	if not _low and _rng.randf() < 0.5:
		var far: Vector3 = _world.position_at(distance, side * (half + _rng.randf_range(38.0, 70.0)))
		far.y = GROUND_Y
		if _clear_of_road(far, 10.0):
			_tree(far, _rng.randf_range(18.0, 30.0))


## Kulissen-Paket: Farn, Baeume und Palmen sind strukturierte Blender-Modelle
## (kart_scenery.gd) statt Kegel/Kugeln. Die Zufallszuege bleiben unveraendert.
func _fern(at: Vector3) -> void:
	var colour: Color = _pick(LEAF_GREENS)
	var turn := 0.0
	for blade in 5:
		turn += _rng.randf()
	_plant("farnflur", at + Vector3.UP * 0.35, 1.3, turn, colour)


func _plant(species: String, at: Vector3, scale: float, yaw: float, colour: Color) -> void:
	var tint := Color(0.5, 0.5 + (colour.g - 0.55) * 0.15, 0.48)
	_world.plant_scenery(species, at, scale, yaw, tint, fposmod(at.x * 0.13 + at.z * 0.07, 1.0))
	placed_props += 1


func _flower_bed(at: Vector3) -> void:
	for flower in 4:
		var offset := Vector3(_rng.randf_range(-1.6, 1.6), 0.0, _rng.randf_range(-1.6, 1.6))
		_put("flower", at + offset, Vector3.ONE * _rng.randf_range(0.7, 1.2), _pick(BLOSSOMS), _turn())


func _tree(at: Vector3, height: float) -> void:
	var bark: Color = _pick(BARK)
	var leaf: Color = _pick(LEAF_GREENS)
	var crown: float = clampf(height * 0.22, 2.6, 6.5)
	var yaw := 0.0
	for lobe in (2 if _low else 3):
		yaw += _rng.randf()
		_rng.randf_range(0.55, 0.75)
		_rng.randf_range(0.0, 0.18)
	var species: String = "dschungelbaum" if int(at.x * 3.0 + at.z) % 3 != 0 else "laubbaum"
	_plant(species, at, height / (15.6 if species == "dschungelbaum" else 10.4), yaw * 2.0, leaf)
	if _rng.randf() < 0.35:
		# Hanging liana with a blossom at its end.
		var vine_length: float = minf(height * 0.45, 9.0)
		var vine_at: Vector3 = at + Vector3(crown * 0.6, height - crown * 0.3 - vine_length * 0.5, 0.0)
		_put("cylinder", vine_at, Vector3(0.06, vine_length, 0.06), Color("3b6b2a"))
		_put("flower", vine_at - Vector3.UP * vine_length * 0.5, Vector3.ONE * 0.6, _pick(BLOSSOMS))


func _giant_tree(at: Vector3, height: float) -> void:
	var bark: Color = _pick(BARK)
	# Riesenwurzeln sind im Modell (Brettwurzeln am Stammfuss).
	var yaw := 0.0
	for root in 5:
		yaw += _rng.randf()
	var leaf: Color = _pick(LEAF_GREENS)
	_plant("dschungelbaum", at, height / 15.6 * 1.15, yaw, leaf)


func _palm(at: Vector3, height: float) -> void:
	var lean: float = _rng.randf_range(-0.12, 0.12)
	_plant("palme", at, height / 8.9, lean * 30.0, Color("3c9a4a"))


# --- landmarks per section ---------------------------------------------------

func _landmark_point(section: int, side: float, lateral_extra: float) -> Dictionary:
	var d: float = section * JUNGLE.SECTION_LENGTH + JUNGLE.SECTION_LENGTH * 0.5
	var lateral: float = side * (JUNGLE.width_at(d) * 0.5 + lateral_extra)
	var at: Vector3 = _world.position_at(d, lateral)
	at.y = GROUND_Y
	return {"distance": d, "at": at, "basis": _world.frame(d)}


func _build_landmarks() -> void:
	# 1 Expeditionshafen / 12 Rückkehr: piers, crates and lanterns.
	for section in [0, 11]:
		var spot: Dictionary = _landmark_point(section, 1.0, 16.0)
		if _clear_of_road(spot.at, 6.0):
			for plank in 6:
				_put("box", spot.at + spot.basis.x * plank * 2.2 + Vector3.UP * 0.6,
					Vector3(2.0, 0.25, 9.0), Color("8b6340"), spot.basis)
			for crate in 4:
				_put("box", spot.at + spot.basis.z * (crate * 1.6 - 2.4) + Vector3.UP * 1.3,
					Vector3.ONE * 1.2, Color("a77a4b"), spot.basis)
			for lantern in 3:
				_put("ball", spot.at + spot.basis.x * lantern * 4.0 + Vector3.UP * 3.2,
					Vector3.ONE * 0.35, Color("ffcf6b"), Basis.IDENTITY, true)
	# 4 Hinter dem Wasserfall: the large waterfall is the Wasserfall-Blick of kart_passages.gd.
	# 5 Wurzelgrotte: mossy boulders on both sides.
	for side in [-1.0, 1.0]:
		var grotto: Dictionary = _landmark_point(4, side, 9.0)
		for boulder in 6:
			var at: Vector3 = grotto.at + grotto.basis.z * (boulder * 6.0 - 15.0)
			if _clear_of_road(at, 2.5):
				_put("rock", at + Vector3.UP * 2.5, Vector3(4.5, 5.0, 4.0), Color("4f5e48"), _turn())
				_put("crystal", at + Vector3.UP * 5.6, Vector3.ONE * 0.9, Color("5fffd2"), _turn(), true)
	# 8 Lichtung des Sonnentempels: stepped sandstone temple with a sun crystal.
	var temple: Dictionary = _landmark_point(7, 1.0, 34.0)
	if _clear_of_road(temple.at, 14.0):
		for level in 5:
			var width: float = 24.0 - level * 4.2
			_put("box", temple.at + Vector3.UP * (1.5 + level * 3.0), Vector3(width, 3.0, width),
				Color("c9a16a").darkened(level * 0.04), temple.basis)
		_put("crystal", temple.at + Vector3.UP * 18.5, Vector3(2.2, 3.6, 2.2), Color("ffd45c"), temple.basis, true)


# --- living atmosphere ---------------------------------------------------------

## Particle quad with white vertex colours. A plain QuadMesh has no colour attribute;
## with vertex_color_use_as_albedo single particles then drew as black squares in the
## compatibility renderer (seen as a dark firefly square on the Dschungelherz course).
static func _coloured_quad(size: float) -> ArrayMesh:
	var half := size * 0.5
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		Vector3(-half, -half, 0), Vector3(half, -half, 0), Vector3(half, half, 0), Vector3(-half, half, 0)
	])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])
	arrays[Mesh.ARRAY_COLOR] = PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 2, 1, 0, 3, 2])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _particles(name_text: String, amount: int, colour: Color, size: float, glow: bool) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.name = name_text
	particles.amount = amount
	var quad := _coloured_quad(size)
	var material := StandardMaterial3D.new()
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = colour
	material.vertex_color_use_as_albedo = true
	if glow:
		material.emission_enabled = true
		material.emission = colour
		material.emission_energy_multiplier = 1.4
	quad.surface_set_material(0, material)
	particles.mesh = quad
	particles.local_coords = false
	add_child(particles)
	return particles


func _build_effects() -> void:
	_fireflies = _particles("Glühwürmchen", 24 if _low else 48, Color("e8ff7a"), 0.18, true)
	_fireflies.lifetime = 4.0
	_fireflies.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_fireflies.emission_box_extents = Vector3(28.0, 6.0, 28.0)
	_fireflies.gravity = Vector3.ZERO
	_fireflies.initial_velocity_min = 0.2
	_fireflies.initial_velocity_max = 0.8
	_fireflies.direction = Vector3.UP
	_fireflies.spread = 180.0
	_rain = _particles("Tropenregen", 140 if _low else 320, Color(0.75, 0.88, 1.0, 0.55), 0.06, false)
	_rain.lifetime = 1.2
	_rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_rain.emission_box_extents = Vector3(24.0, 0.5, 24.0)
	_rain.gravity = Vector3(0.0, -28.0, 0.0)
	_rain.scale_amount_min = 1.0
	_rain.scale_amount_max = 4.0
	_rain.emitting = false
	_celebration = _particles("Blütenregen", 160, Color.WHITE, 0.35, false)
	_celebration.lifetime = 3.0
	_celebration.one_shot = true
	_celebration.explosiveness = 0.9
	_celebration.direction = Vector3.UP
	_celebration.spread = 70.0
	_celebration.initial_velocity_min = 6.0
	_celebration.initial_velocity_max = 12.0
	_celebration.gravity = Vector3(0.0, -4.0, 0.0)
	var petals := Gradient.new()
	petals.colors = PackedColorArray(BLOSSOMS)
	petals.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
	_celebration.color_initial_ramp = petals
	_celebration.emitting = false


## Called every frame by kart_island.gd while the Dschungelherz race runs.
func advance(delta: float, player_position: Vector3, active: bool, reduced_motion: bool) -> void:
	_time += delta
	if _fireflies == null:
		return
	_fireflies.global_position = player_position + Vector3.UP * 2.5
	_fireflies.emitting = active and not reduced_motion
	var road_distance: float = _world.curve.get_closest_offset(player_position)
	var section: int = int(road_distance / JUNGLE.SECTION_LENGTH)
	_rain.global_position = player_position + Vector3.UP * 14.0
	_rain.emitting = active and not reduced_motion and section == 10
	if not reduced_motion:
		for pool in _water:
			pool.position.y = GROUND_Y + 0.08 + sin(_time * 0.8 + pool.position.x * 0.05) * 0.05


## Called once when the player crosses the finish line.
func celebrate_finish() -> void:
	if _celebration == null:
		return
	_celebration.global_position = _world.position_at(1.0) + Vector3.UP * 1.5
	_celebration.restart()
	_celebration.emitting = true
