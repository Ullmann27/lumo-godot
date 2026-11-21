extends Node3D
## Lumos Riesengarten – Licht, Himmel, Gartenboden, Teich und Bauteile.
## Fahrbahn, Ränder und Kollision kommen aus kart_garden_world.gd; hier steht nur,
## was man sieht und hört, und was sich im Rennen bewegt (advance_race).
const COURSE = preload("res://scripts/games/garden/kart_garden_course.gd")

var tier: String = "medium"
var _world: Node3D
var _sun: DirectionalLight3D


func build(world: Node3D) -> void:
	_world = world
	tier = "low" if bool(world.get("low_detail")) else LumoQuality.tier()
	_lighting()
	_ground()
	world.set_meta("garden_quality", tier)


func _lighting() -> void:
	var low: bool = tier == "low"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = _world._sky_for(_world.track_id)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("e6f0d6")
	environment.ambient_light_energy = 0.42 if low else 0.34
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.02
	environment.glow_enabled = not low
	environment.glow_intensity = 0.55
	environment.glow_bloom = 0.06
	environment.glow_hdr_threshold = 1.1
	environment.adjustment_enabled = not low
	environment.adjustment_saturation = 1.12
	environment.adjustment_contrast = 1.04
	# Dunst in der Ferne: das Miniatur-Gefühl (alles Große verschwimmt leicht).
	environment.fog_enabled = true
	environment.fog_light_color = Color("dcebd2")
	environment.fog_density = 0.0019
	environment.fog_aerial_perspective = 0.35
	environment.fog_sky_affect = 0.25
	var world_environment := WorldEnvironment.new()
	world_environment.name = "GardenEnvironment"
	world_environment.environment = environment
	add_child(world_environment)
	_sun = DirectionalLight3D.new()
	_sun.name = "GardenSun"
	_sun.rotation_degrees = Vector3(-48, -32, 0)
	_sun.light_color = Color("fff1cf")
	_sun.light_energy = 1.12
	_sun.shadow_enabled = not low
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


func _ground() -> void:
	var lawn := MeshInstance3D.new()
	lawn.name = "GardenLawn"
	var plane := PlaneMesh.new()
	plane.size = Vector2(1400.0, 1400.0)
	lawn.mesh = plane
	lawn.position = Vector3(0.0, 0.0, -310.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("5c9a3d")
	material.roughness = 0.95
	lawn.material_override = material
	lawn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lawn)


## Ein Takt im Rennen (aus kart_island._advance_garden_world).
func advance_race(_game: Node, _delta: float) -> void:
	pass


func celebrate_finish() -> void:
	pass
