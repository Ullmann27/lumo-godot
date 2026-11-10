class_name LumoEnvironmentCreativePresets
extends RefCounted
## Kreativwelt-Presets, die bewusst außerhalb von LumoEnvironment leben.
##
## Lumo · Spiele schließt diese Datei später an LumoEnvironment.apply() an.
## Bis dahin wendet die Bauwelt `apply()` direkt an, ohne lumo_environment.gd
## oder lumo_quality.gd zu ändern.
##
## Öffentliche Schnittstelle
## ------------------------
## PRESET_BAUWELT_DAY = "bauwelt_day"
## PRESET_PUZZLE_ATELIER = "puzzle_atelier"
## PRESET_RHYTHM_PARTY = "rhythm_party"
## PRESET_TREASURE_DAY = "treasure_day"
##
## describe(preset: String) -> Dictionary
##   Reine Daten (keine Nodes): Himmel, Ambient, Tonemap, Fog, Glow,
##   Sonne und Zusatzlichter. Unbekanntes Preset liefert {}.
##   glow.enabled ist optional; fehlt der Schlüssel, bleibt env.glow_enabled
##   unverändert (wie bisher bei bauwelt_day).
##
## configure(env, sun, preset, budget) -> Dictionary
##   Schreibt Himmel/Fog/Glow/Tonemap auf `env` und Sonnenwerte auf `sun`.
##   Liefert Zusatzlichter als Spezifikation (noch keine Nodes):
##     { "fill": { "name": "SkyFill", "rotation_degrees": Vector3,
##                 "light_color": Color, "light_energy": float,
##                 "light_specular": float, "shadow_enabled": false } }
##   `sun.shadow_enabled` setzt der Aufrufer aus `budget.shadows`
##   (anders als creative_night, das Schatten immer anlässt).
##   `sun.directional_shadow_max_distance` kommt aus `budget.shadow_distance`.
##
## apply(root: Node3D, preset: String, tier: String = "") -> Dictionary
##   Eigenständiger Pfad, Rückgabe analog zu LumoEnvironment.apply():
##     { "world", "environment", "sun", "rim", "fill" }
##   `rim` ist null, sofern das Preset keines setzt; `fill` ist optional.
##
## Bekannte Presets: bauwelt_day, puzzle_atelier, rhythm_party, treasure_day.
## wolkeninseln und creative_night bleiben bei LumoEnvironment.

const PRESET_BAUWELT_DAY := "bauwelt_day"
const PRESET_PUZZLE_ATELIER := "puzzle_atelier"
const PRESET_RHYTHM_PARTY := "rhythm_party"
const PRESET_TREASURE_DAY := "treasure_day"


static func describe(preset: String) -> Dictionary:
	match preset:
		PRESET_BAUWELT_DAY:
			return _spec_bauwelt_day()
		PRESET_PUZZLE_ATELIER:
			return _spec_puzzle_atelier()
		PRESET_RHYTHM_PARTY:
			return _spec_rhythm_party()
		PRESET_TREASURE_DAY:
			return _spec_treasure_day()
		_:
			return {}


static func _spec_bauwelt_day() -> Dictionary:
	return {
		"id": PRESET_BAUWELT_DAY,
		"owner": "creative",
		"worlds": ["build"],
		"shadow_policy": "budget",
		"sky":
		{
			"sky_top_color": Color("3d8fe0"),
			"sky_horizon_color": Color("bfe6fa"),
			"sky_curve": 0.12,
			"ground_horizon_color": Color("cdeaf2"),
			"ground_bottom_color": Color("6fa6c2"),
			"ground_curve": 0.06,
			"sun_angle_max": 22.0,
			"sun_curve": 0.08,
			"radiance_size": Sky.RADIANCE_SIZE_64,
		},
		"ambient":
		{
			"source": Environment.AMBIENT_SOURCE_SKY,
			"sky_contribution": 0.7,
			"color": Color("dceeff"),
			"energy": 0.75,
			"reflected": Environment.REFLECTION_SOURCE_SKY,
		},
		"tonemap":
		{"mode": Environment.TONE_MAPPER_FILMIC, "exposure": 1.0, "white": 4.0},
		"fog":
		{
			"light_color": Color("d6eef8"),
			"density": 0.0025,
			"aerial_perspective": 0.25,
			"sky_affect": 0.0,
			"volumetric_density": 0.004,
			"volumetric_albedo": Color("eaf6ff"),
		},
		"ssao":
		{"radius": 0.9, "intensity": 1.6, "power": 1.4, "light_affect": 0.15},
		"glow": {"intensity": 0.45, "bloom": 0.03, "hdr_threshold": 1.1},
		"adjustment": {"saturation": 1.1, "contrast": 1.03},
		"sun":
		{
			"rotation_degrees": Vector3(-42, -38, 0),
			"light_color": Color("ffe9c7"),
			"light_energy": 1.25,
			"shadow_blur": 1.6,
			"shadow_bias": 0.04,
			"shadow_normal_bias": 1.2,
			"directional_shadow_mode": DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS,
			"directional_shadow_blend_splits": true,
		},
		"fill":
		{
			"name": "SkyFill",
			"rotation_degrees": Vector3(-35, 140, 0),
			"light_color": Color("bfe3ff"),
			"light_energy": 0.28,
			"light_specular": 0.1,
			"shadow_enabled": false,
		},
	}


static func configure(
	env: Environment, sun: DirectionalLight3D, preset: String, budget: Dictionary
) -> Dictionary:
	var spec: Dictionary = describe(preset)
	if spec.is_empty():
		push_warning("[LumoEnvironmentCreativePresets] unknown preset %s" % preset)
		return {}
	var sky_spec: Dictionary = spec.sky
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = sky_spec.sky_top_color
	sky_mat.sky_horizon_color = sky_spec.sky_horizon_color
	sky_mat.sky_curve = sky_spec.sky_curve
	sky_mat.ground_horizon_color = sky_spec.ground_horizon_color
	sky_mat.ground_bottom_color = sky_spec.ground_bottom_color
	sky_mat.ground_curve = sky_spec.ground_curve
	sky_mat.sun_angle_max = sky_spec.sun_angle_max
	sky_mat.sun_curve = sky_spec.sun_curve
	sky.sky_material = sky_mat
	sky.radiance_size = sky_spec.radiance_size
	env.sky = sky
	var ambient: Dictionary = spec.ambient
	env.ambient_light_source = ambient.source
	env.ambient_light_sky_contribution = ambient.sky_contribution
	env.ambient_light_color = ambient.color
	env.ambient_light_energy = ambient.energy
	env.reflected_light_source = ambient.reflected
	var tonemap: Dictionary = spec.tonemap
	env.tonemap_mode = tonemap.mode
	env.tonemap_exposure = tonemap.exposure
	env.tonemap_white = tonemap.white
	var fog: Dictionary = spec.fog
	env.fog_light_color = fog.light_color
	env.fog_density = fog.density
	env.fog_aerial_perspective = fog.aerial_perspective
	env.fog_sky_affect = fog.sky_affect
	env.volumetric_fog_density = fog.volumetric_density
	env.volumetric_fog_albedo = fog.volumetric_albedo
	var ssao: Dictionary = spec.ssao
	env.ssao_radius = ssao.radius
	env.ssao_intensity = ssao.intensity
	env.ssao_power = ssao.power
	env.ssao_light_affect = ssao.light_affect
	var glow: Dictionary = spec.glow
	if glow.has("enabled"):
		env.glow_enabled = bool(glow.enabled)
	env.glow_intensity = glow.intensity
	env.glow_bloom = glow.bloom
	env.glow_hdr_threshold = glow.hdr_threshold
	var adjustment: Dictionary = spec.adjustment
	env.adjustment_enabled = true
	env.adjustment_saturation = adjustment.saturation
	env.adjustment_contrast = adjustment.contrast
	var sun_spec: Dictionary = spec.sun
	sun.rotation_degrees = sun_spec.rotation_degrees
	sun.light_color = sun_spec.light_color
	sun.light_energy = sun_spec.light_energy
	sun.shadow_blur = sun_spec.shadow_blur
	sun.shadow_bias = sun_spec.shadow_bias
	sun.shadow_normal_bias = sun_spec.shadow_normal_bias
	sun.directional_shadow_mode = sun_spec.directional_shadow_mode
	sun.directional_shadow_blend_splits = sun_spec.directional_shadow_blend_splits
	sun.directional_shadow_max_distance = float(budget.get("shadow_distance", 70.0))
	var extras: Dictionary = {}
	if spec.has("fill"):
		extras["fill"] = (spec.fill as Dictionary).duplicate()
	if spec.has("rim"):
		extras["rim"] = (spec.rim as Dictionary).duplicate()
	return extras


static func apply(root: Node3D, preset: String, tier: String = "") -> Dictionary:
	var budget: Dictionary = LumoQuality.budget(tier)
	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	var env := Environment.new()
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	var extras: Dictionary = configure(env, sun, preset, budget)
	world.environment = env
	root.add_child(world)
	sun.shadow_enabled = bool(budget.get("shadows", true))
	root.add_child(sun)
	var rim: DirectionalLight3D = _spawn_light(root, extras.get("rim", {}))
	var fill: DirectionalLight3D = _spawn_light(root, extras.get("fill", {}))
	return {"world": world, "environment": env, "sun": sun, "rim": rim, "fill": fill}


static func _spawn_light(root: Node3D, spec: Dictionary) -> DirectionalLight3D:
	if spec.is_empty():
		return null
	var light := DirectionalLight3D.new()
	light.name = str(spec.get("name", "ExtraLight"))
	light.rotation_degrees = spec.get("rotation_degrees", Vector3.ZERO)
	light.light_color = spec.get("light_color", Color.WHITE)
	light.light_energy = float(spec.get("light_energy", 1.0))
	light.light_specular = float(spec.get("light_specular", 0.5))
	light.shadow_enabled = bool(spec.get("shadow_enabled", false))
	root.add_child(light)
	return light


static func _spec_puzzle_atelier() -> Dictionary:
	return {
		"id": PRESET_PUZZLE_ATELIER,
		"owner": "creative",
		"worlds": ["puzzle"],
		"shadow_policy": "budget",
		"sky":
		{
			"sky_top_color": Color("6eb0e4"),
			"sky_horizon_color": Color("f3e2c2"),
			"sky_curve": 0.16,
			"ground_horizon_color": Color("e8d2ae"),
			"ground_bottom_color": Color("c4a47a"),
			"ground_curve": 0.08,
			"sun_angle_max": 28.0,
			"sun_curve": 0.1,
			"radiance_size": Sky.RADIANCE_SIZE_64,
		},
		"ambient":
		{
			"source": Environment.AMBIENT_SOURCE_COLOR,
			"sky_contribution": 0.35,
			"color": Color("ffe6c8"),
			"energy": 0.88,
			"reflected": Environment.REFLECTION_SOURCE_SKY,
		},
		"tonemap":
		{"mode": Environment.TONE_MAPPER_FILMIC, "exposure": 1.02, "white": 4.0},
		"fog":
		{
			"light_color": Color("f0e2cc"),
			"density": 0.0014,
			"aerial_perspective": 0.08,
			"sky_affect": 0.0,
			"volumetric_density": 0.002,
			"volumetric_albedo": Color("f7ebda"),
		},
		"ssao":
		{"radius": 0.7, "intensity": 1.2, "power": 1.2, "light_affect": 0.1},
		"glow": {"intensity": 0.35, "bloom": 0.025, "hdr_threshold": 1.15},
		"adjustment": {"saturation": 1.08, "contrast": 1.02},
		"sun":
		{
			"rotation_degrees": Vector3(-28, 175, 0),
			"light_color": Color("ffe2b4"),
			"light_energy": 1.18,
			"shadow_blur": 1.8,
			"shadow_bias": 0.04,
			"shadow_normal_bias": 1.1,
			"directional_shadow_mode": DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS,
			"directional_shadow_blend_splits": true,
		},
		"fill":
		{
			"name": "WarmFill",
			"rotation_degrees": Vector3(-20, 20, 0),
			"light_color": Color("ffd2a0"),
			"light_energy": 0.32,
			"light_specular": 0.12,
			"shadow_enabled": false,
		},
	}


static func _spec_rhythm_party() -> Dictionary:
	return {
		"id": PRESET_RHYTHM_PARTY,
		"owner": "creative",
		"worlds": ["rhythm"],
		"shadow_policy": "budget",
		"sky":
		{
			"sky_top_color": Color("10061f"),
			"sky_horizon_color": Color("3a1574"),
			"sky_curve": 0.22,
			"ground_horizon_color": Color("24104a"),
			"ground_bottom_color": Color("0c0618"),
			"ground_curve": 0.1,
			"sun_angle_max": 16.0,
			"sun_curve": 0.12,
			"radiance_size": Sky.RADIANCE_SIZE_64,
		},
		"ambient":
		{
			"source": Environment.AMBIENT_SOURCE_COLOR,
			"sky_contribution": 0.2,
			"color": Color("4a2a88"),
			"energy": 0.48,
			"reflected": Environment.REFLECTION_SOURCE_DISABLED,
		},
		"tonemap":
		{"mode": Environment.TONE_MAPPER_FILMIC, "exposure": 1.05, "white": 3.6},
		"fog":
		{
			"light_color": Color("1c0a36"),
			"density": 0.0035,
			"aerial_perspective": 0.12,
			"sky_affect": 0.0,
			"volumetric_density": 0.006,
			"volumetric_albedo": Color("2a1050"),
		},
		"ssao":
		{"radius": 0.6, "intensity": 1.1, "power": 1.1, "light_affect": 0.08},
		"glow":
		{"enabled": true, "intensity": 0.88, "bloom": 0.14, "hdr_threshold": 0.72},
		"adjustment": {"saturation": 1.18, "contrast": 1.06},
		"sun":
		{
			"rotation_degrees": Vector3(-38, 8, 0),
			"light_color": Color("ffc2ee"),
			"light_energy": 0.95,
			"shadow_blur": 1.4,
			"shadow_bias": 0.05,
			"shadow_normal_bias": 1.0,
			"directional_shadow_mode": DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS,
			"directional_shadow_blend_splits": true,
		},
		"fill":
		{
			"name": "CyanFill",
			"rotation_degrees": Vector3(-25, 160, 0),
			"light_color": Color("5ad8ff"),
			"light_energy": 0.42,
			"light_specular": 0.2,
			"shadow_enabled": false,
		},
		"rim":
		{
			"name": "MagentaRim",
			"rotation_degrees": Vector3(-15, -130, 0),
			"light_color": Color("d080ff"),
			"light_energy": 0.28,
			"light_specular": 0.15,
			"shadow_enabled": false,
		},
	}


static func _spec_treasure_day() -> Dictionary:
	var spec: Dictionary = _spec_bauwelt_day()
	spec["id"] = PRESET_TREASURE_DAY
	spec["worlds"] = ["treasure"]
	spec["sky"]["sky_top_color"] = Color("2f86d4")
	spec["sky"]["sky_horizon_color"] = Color("b7e3f4")
	spec["sky"]["ground_horizon_color"] = Color("7eb8d0")
	spec["sky"]["ground_bottom_color"] = Color("1a4e6a")
	spec["sun"]["light_color"] = Color("ffe0a8")
	spec["sun"]["light_energy"] = 1.32
	spec["sun"]["rotation_degrees"] = Vector3(-46, -28, 0)
	spec["fog"]["light_color"] = Color("c8e4f2")
	spec["adjustment"]["saturation"] = 1.06
	return spec
