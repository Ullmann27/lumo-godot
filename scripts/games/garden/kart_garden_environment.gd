extends Node3D
## Lumos Riesengarten – Licht, Himmel, Rasen, Hecke, Pflanzen und Wahrzeichen.
## Fahrbahn, Ränder und Kollision kommen aus kart_garden_world.gd; hier steht nur, was man
## sieht, und die Ereignisse (kart_garden_events.gd), die im Rennen laufen (advance_race).
## Profile: LOW = keine Schatten/Glow, weniger Pflanzen, LOD ab Stufe 1; MEDIUM/HIGH voll.
const COURSE = preload("res://scripts/games/garden/kart_garden_course.gd")
const EVENTS = preload("res://scripts/games/garden/kart_garden_events.gd")
const MODELS = preload("res://scripts/games/garden/kart_garden_models.gd")
const LANDMARKS = preload("res://scripts/games/garden/kart_garden_landmarks.gd")
const LAWN = preload("res://assets/shaders/garden/kart_garden_lawn.gdshader")
## Sichtweite im Garten: die Sonnenblume und die großen Wahrzeichen bleiben über die
## ganze Runde sichtbar (Pflanzen und Kleinteile haben eigene, kürzere Sichtweiten).
const FAR_BY_TIER: Dictionary = {"low": 420.0, "medium": 560.0, "high": 700.0}

var tier: String = "medium"
var parts: Dictionary = {}
var events: EVENTS
var environment: Environment
var placed_plants: int = 0
var _world: Node3D
var _sun: DirectionalLight3D
var _rng := RandomNumberGenerator.new()


func build(world: Node3D) -> void:
	_world = world
	tier = "low" if bool(world.get("low_detail")) else LumoQuality.tier()
	_rng.seed = 24002111
	_lighting()
	_ground()
	_hedge()
	parts = LANDMARKS.build(self, world, tier == "low")
	_flora()
	_mist()
	events = EVENTS.new(environment, parts, low())
	world.set_meta("garden_quality", tier)
	world.set_meta("garden_plants", placed_plants)


func low() -> bool:
	return tier == "low"


# ------------------------------------------------------------------ Licht


func _lighting() -> void:
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = _garden_sky()
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("e6f0d6")
	environment.ambient_light_energy = 0.44 if low() else 0.36
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 0.83
	environment.tonemap_white = 4.5
	environment.glow_enabled = not low()
	environment.glow_intensity = 0.55
	environment.glow_bloom = 0.0
	environment.glow_hdr_threshold = 1.1
	environment.adjustment_enabled = not low()
	environment.adjustment_saturation = 1.12
	environment.adjustment_contrast = 1.04
	# Dunst in der Ferne: das Miniatur-Gefühl (alles Große verschwimmt leicht).
	# Runde 1 Morgentau: etwas dichter; in Runde 2 lichtet er sich (Ereignisse).
	environment.fog_enabled = true
	environment.fog_light_color = Color("e3eedb")
	environment.fog_density = EVENTS.MORNING_DENSITY
	environment.fog_light_energy = 0.58
	environment.fog_aerial_perspective = 0.23
	environment.fog_sky_affect = 0.2
	var world_environment := WorldEnvironment.new()
	world_environment.name = "GardenEnvironment"
	world_environment.environment = environment
	add_child(world_environment)
	_sun = DirectionalLight3D.new()
	_sun.name = "GardenSun"
	_sun.rotation_degrees = Vector3(-46, -38, 0)
	_sun.light_color = Color("fff1cf")
	_sun.light_energy = 0.86
	_sun.shadow_enabled = not low()
	_sun.directional_shadow_max_distance = 80.0 if tier == "high" else 55.0
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	_sun.shadow_bias = 0.1
	_sun.shadow_normal_bias = 1.2
	add_child(_sun)
	var fill := DirectionalLight3D.new()
	fill.name = "GardenSkyFill"
	fill.rotation_degrees = Vector3(-30, 150, 0)
	fill.light_color = Color("b9dcff")
	fill.light_energy = 0.16
	fill.shadow_enabled = false
	add_child(fill)


func _garden_sky() -> Sky:
	var sky := Sky.new()
	var material := ProceduralSkyMaterial.new()
	material.sky_top_color = Color("4f9fe0")
	material.sky_horizon_color = Color("e7f3e4")
	material.ground_horizon_color = Color("cfe3c4")
	material.ground_bottom_color = Color("5f8f45")
	material.sky_curve = 0.2
	material.sun_angle_max = 3.0
	material.sun_curve = 0.08
	sky.sky_material = material
	return sky


func sun_light() -> DirectionalLight3D:
	return _sun


func far_plane() -> float:
	return float(FAR_BY_TIER.get(tier, 560.0))


# ------------------------------------------------------------------ Boden


func _ground() -> void:
	var lawn := MeshInstance3D.new()
	lawn.name = "GardenLawn"
	var plane := PlaneMesh.new()
	plane.size = Vector2(1500.0, 1400.0)
	lawn.mesh = plane
	lawn.position = Vector3(0.0, 0.0, -310.0)
	var material := ShaderMaterial.new()
	material.shader = LAWN
	lawn.material_override = material
	lawn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lawn)


## Gartenhecke am Rand: schließt den Horizont (eine Ringwand, ein Draw-Call).
func _hedge() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corners: Array[Vector2] = [
		Vector2(-470.0, 120.0), Vector2(470.0, 120.0), Vector2(470.0, -760.0), Vector2(-470.0, -760.0)
	]
	for c in range(4):
		var a: Vector2 = corners[c]
		var b: Vector2 = corners[(c + 1) % 4]
		var steps: int = int(a.distance_to(b) / 20.0)
		for i in range(steps):
			var p0: Vector2 = a.lerp(b, float(i) / float(steps))
			var p1: Vector2 = a.lerp(b, float(i + 1) / float(steps))
			var h0: float = 70.0 + 14.0 * sin(p0.x * 0.05 + p0.y * 0.03)
			var h1: float = 70.0 + 14.0 * sin(p1.x * 0.05 + p1.y * 0.03)
			var shade: float = 0.85 + 0.15 * sin(float(i) * 1.7)
			st.set_color(Color(0.20, 0.42, 0.20) * shade)
			var normal := Vector3(-(p1 - p0).y, 0.0, (p1 - p0).x).normalized()
			st.set_normal(normal)
			for v in [
				Vector3(p0.x, 0.0, p0.y),
				Vector3(p1.x, 0.0, p1.y),
				Vector3(p0.x, h0, p0.y),
				Vector3(p0.x, h0, p0.y),
				Vector3(p1.x, 0.0, p1.y),
				Vector3(p1.x, h1, p1.y)
			]:
				st.add_vertex(v)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.95
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var hedge := MeshInstance3D.new()
	hedge.name = "GardenHedge"
	hedge.mesh = st.commit()
	hedge.material_override = material
	hedge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(hedge)


# ------------------------------------------------------------------ Pflanzen


## Grashalme wie Bäume, Blühbüsche, Pusteblumen und Blätter am Rand – je Abschnitt
## eigene Mischung, als MultiMesh je Zelle (Dichte nach Profil).
func _flora() -> void:
	var density: float = float(LumoQuality.budget(tier).decor_density)
	var grass: Array[Transform3D] = []
	var bushes: Array[Transform3D] = []
	var dandelions: Array[Transform3D] = []
	var leaves: Array[Transform3D] = []
	var d: float = 0.0
	var step: float = 7.0 / maxf(density, 0.3)
	while d < float(_world.length):
		var section: String = str(COURSE.SECTIONS[COURSE.section_at(d)].id)
		var skip: bool = section in ["glashaus"] or (d > 440.0 and d < 760.0)
		if not skip:
			for side in [-1.0, 1.0]:
				_plant_station(d, side, section, grass, bushes, dandelions, leaves)
		d += step
	var view: float = 210.0 if low() else 300.0
	MODELS.scatter(self, "grashalme", grass, 1 if not low() else 2, view)
	MODELS.scatter(self, "blumenbusch", bushes, 1 if not low() else 2, view * 0.8)
	MODELS.scatter(self, "pusteblume", dandelions, 1, view)
	MODELS.scatter(self, "gartenblatt", leaves, 2, view * 0.8)
	placed_plants = grass.size() + bushes.size() + dandelions.size() + leaves.size()


func _plant_station(
	d: float,
	side: float,
	section: String,
	grass: Array[Transform3D],
	bushes: Array[Transform3D],
	dandelions: Array[Transform3D],
	leaves: Array[Transform3D]
) -> void:
	var half: float = COURSE.width_at(d) * 0.5
	var near: float = half + _rng.randf_range(3.0, 9.0)
	var far: float = half + _rng.randf_range(12.0, 46.0)
	var turn := Basis(Vector3.UP, _rng.randf() * TAU)
	for lateral in [side * near, side * far]:
		var at: Vector3 = _world.position_at(d + _rng.randf_range(-3.0, 3.0), lateral)
		at.y = 0.0
		if LANDMARKS.clearance(_world, at) < 2.5:
			continue
		var roll: float = _rng.randf()
		match section:
			"tau", "start", "ziel":
				var size: float = _rng.randf_range(10.0, 22.0) if section == "tau" else _rng.randf_range(6.0, 14.0)
				grass.append(Transform3D(turn.scaled(Vector3(size * 0.8, size, size * 0.8)), at))
			"loewenzahn":
				if roll < 0.55:
					var size: float = _rng.randf_range(14.0, 28.0)
					dandelions.append(Transform3D(turn.scaled(Vector3.ONE * size), at))
				else:
					grass.append(Transform3D(turn.scaled(Vector3.ONE * _rng.randf_range(6.0, 12.0)), at))
			"kuerbis":
				leaves.append(Transform3D(turn.scaled(Vector3.ONE * _rng.randf_range(5.0, 9.0)), at))
			_:
				if roll < 0.4:
					bushes.append(Transform3D(turn.scaled(Vector3.ONE * _rng.randf_range(6.0, 12.0)), at))
				elif roll < 0.8:
					grass.append(Transform3D(turn.scaled(Vector3.ONE * _rng.randf_range(7.0, 16.0)), at))
				else:
					leaves.append(Transform3D(turn.scaled(Vector3.ONE * _rng.randf_range(4.0, 8.0)), at))


## Morgennebel der ersten Runde: flache Schleier über dem Rasen (lichten sich in Runde 2).
func _mist() -> void:
	if low():
		return
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 1.0, 0.98, 0.16)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.disable_receive_shadows = true
	var gradient := GradientTexture2D.new()
	gradient.fill = GradientTexture2D.FILL_RADIAL
	gradient.fill_from = Vector2(0.5, 0.5)
	gradient.fill_to = Vector2(1.0, 0.5)
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	gradient.gradient = ramp
	material.albedo_texture = gradient
	var mist := Node3D.new()
	mist.name = "MorningMist"
	add_child(mist)
	var d: float = 60.0
	while d < float(_world.length):
		for side in [-1.0, 1.0]:
			var at: Vector3 = _world.position_at(d, side * (COURSE.width_at(d) * 0.5 + 26.0))
			at.y = 2.5
			if LANDMARKS.clearance(_world, at) < 8.0:
				continue
			var sheet := MeshInstance3D.new()
			var quad := QuadMesh.new()
			quad.size = Vector2(70.0, 70.0)
			sheet.mesh = quad
			sheet.material_override = material
			sheet.rotation_degrees = Vector3(-90.0, d, 0.0)
			sheet.position = at
			sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			sheet.visibility_range_end = 260.0
			mist.add_child(sheet)
		d += 90.0
	parts["mist"] = mist
	parts["mist_material"] = material


# ------------------------------------------------------------------ Rennen


## Ein Takt im Rennen (aus kart_island._advance_garden_world).
func advance_race(game: Node, delta: float) -> void:
	if events != null and not game.paused and game.countdown <= 0.0 and not game.finished:
		events.advance(game.distance >= game.track_length, delta)
		events.advance_train(game.elapsed)


func celebrate_finish() -> void:
	if events != null:
		events.advance(true, EVENTS.CLEAR_SECONDS)
