class_name LumoEnvironment
extends RefCounted
## LumoRenderKit · sky, atmosphere and light presets per world.
##
## apply() adds a WorldEnvironment plus sun (and optional rim light) to a scene
## root; shadow settings come from LumoQuality (except creative_night).
## PerformanceManager still owns the glow/fog/SSAO switches per tier and
## re-applies them on scene change.
## Presets:
##   creative_night – Bauwelt, Puzzle, Rhythmus, Schatzsuche (values identical
##                    to the former creative_kit.environment()).
##   wolkeninseln   – 3D-Jump, target portal_jump_run.png: turquoise sky,
##                    warm sun, aerial depth fog over a cloud sea, soft bloom.


static func apply(root: Node3D, preset: String, tier: String = "") -> Dictionary:
	var budget: Dictionary = LumoQuality.budget(tier)
	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	var env := Environment.new()
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	var rim: DirectionalLight3D = null
	match preset:
		"creative_night":
			_creative_night(env, sun)
		"wolkeninseln":
			_wolkeninseln(env, sun, budget)
			rim = DirectionalLight3D.new()
			rim.name = "RimLight"
			rim.rotation_degrees = Vector3(-20, 150, 0)
			rim.light_color = Color("a8e4ff")
			rim.light_energy = 0.35
			rim.shadow_enabled = false
		_:
			push_warning("[LumoEnvironment] unknown preset %s" % preset)
	world.environment = env
	root.add_child(world)
	# Tier-driven shadows (LOW = off, largest single GPU cost). creative_night
	# stays behaviour-identical to the former creative_kit: shadows always on.
	sun.shadow_enabled = true if preset == "creative_night" else bool(budget.shadows)
	root.add_child(sun)
	if rim != null:
		root.add_child(rim)
	return {"world": world, "environment": env, "sun": sun, "rim": rim}


static func _creative_night(env: Environment, sun: DirectionalLight3D) -> void:
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("081537")
	sky_mat.sky_horizon_color = Color("1a3264")
	sky_mat.ground_horizon_color = Color("1a3264")
	sky_mat.ground_bottom_color = Color("07152d")
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("a8c7fa")
	env.ambient_light_energy = 0.36
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.75
	env.glow_bloom = 0.04
	sun.rotation_degrees = Vector3(-48, -30, 0)
	sun.light_color = Color("d9e8ff")
	sun.light_energy = 0.80
	sun.directional_shadow_max_distance = 70.0


static func _wolkeninseln(env: Environment, sun: DirectionalLight3D, budget: Dictionary) -> void:
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("1557a8")
	sky_mat.sky_horizon_color = Color("8fe0ef")
	sky_mat.sky_curve = 0.18
	sky_mat.ground_horizon_color = Color("b8eef4")
	sky_mat.ground_bottom_color = Color("5aa9d0")
	sky_mat.ground_curve = 0.08
	sky_mat.sun_angle_max = 18.0
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.75
	env.ambient_light_energy = 0.85
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.tonemap_white = 5.0
	env.fog_enabled = true
	env.fog_light_color = Color("bfeaf6")
	env.fog_density = 0.0042
	env.fog_aerial_perspective = 0.35
	env.fog_sky_affect = 0.15
	env.fog_height = -5.0
	env.fog_height_density = 0.12
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 0.95
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.04
	sun.rotation_degrees = Vector3(-40, -35, 0)
	sun.light_color = Color("fff0d2")
	sun.light_energy = 1.15
	sun.shadow_blur = 1.5
	sun.directional_shadow_max_distance = float(budget.shadow_distance)
