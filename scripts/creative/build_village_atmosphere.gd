extends RefCounted
## Licht und Stimmung der Dorfwelt: tiefe Sonne mit Schatten, weiche
## Himmelshelligkeit, Dunst über dem Tal, Tag- und Abendstimmung.
## Nur Umgebung/Sonne/Material-Parameter; keine Bildschirmeffekte, die der
## Mobile- oder gl_compatibility-Renderer nicht kann.
const ART = preload("res://scripts/creative/build_village_art.gd")
const SHADOWS := {
	"low": {"enabled": false, "distance": 0.0, "mode": DirectionalLight3D.SHADOW_ORTHOGONAL},
	"medium": {"enabled": true, "distance": 80.0, "mode": DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS},
	"high": {"enabled": true, "distance": 190.0, "mode": DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS},
}
## Zwei Schlüsselbilder; dazwischen wird weich gemischt.
const DAY := {
	"sun_color": Color("fff1da"), "sun_energy": 1.75, "sun_pitch": -38.0, "sun_yaw": -32.0,
	"sky_top": Color("2f6fb4"), "sky_horizon": Color("b9d4e4"), "ground_horizon": Color("a7bccb"),
	"ambient": Color("aac2da"), "ambient_energy": 0.32, "fog": Color("a4bfd6"), "fog_density": 0.0009,
	"exposure": 0.86, "night": 0.0, "fill": 0.18,
}
const EVENING := {
	"sun_color": Color("ffa868"), "sun_energy": 1.05, "sun_pitch": -15.0, "sun_yaw": -68.0,
	"sky_top": Color("34407a"), "sky_horizon": Color("f2a072"), "ground_horizon": Color("8c6f86"),
	"ambient": Color("8a8fbf"), "ambient_energy": 0.42, "fog": Color("b88f96"), "fog_density": 0.0016,
	"exposure": 1.05, "night": 1.0, "fill": 0.12,
}


static func apply(root: Node3D, tier: String) -> void:
	var world := root.get_node_or_null("WorldEnvironment") as WorldEnvironment
	var sun := root.get_node_or_null("Sun") as DirectionalLight3D
	if world == null or world.environment == null or sun == null:
		return
	var env := world.environment
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_sky_contribution = 0.0
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_sky_affect = 0.2
	env.fog_aerial_perspective = 0.06
	env.fog_sun_scatter = 0.18
	env.fog_height = 6.0
	env.fog_height_density = 0.0 if tier == "low" else 0.006
	env.glow_enabled = tier != "low"
	env.glow_intensity = 0.35
	env.glow_strength = 0.9
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.25
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.ssao_enabled = tier == "high"
	env.ssao_radius = 1.4
	env.ssao_intensity = 1.1
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.16
	env.adjustment_contrast = 1.12
	var shadow: Dictionary = SHADOWS.get(tier, SHADOWS.medium)
	sun.shadow_enabled = bool(shadow.enabled)
	sun.directional_shadow_max_distance = float(shadow.distance)
	sun.directional_shadow_mode = int(shadow.mode)
	sun.directional_shadow_blend_splits = true
	sun.directional_shadow_fade_start = 0.85
	sun.shadow_blur = 1.4
	sun.shadow_bias = 0.05
	sun.shadow_normal_bias = 1.4
	sun.light_specular = 0.6
	root.set_meta("village_shadow_distance", float(shadow.distance))
	set_time(root, 0.35)


## t: 0.35 = Vormittag, 0.82 = Abendrot mit beleuchteten Fenstern.
static func set_time(root: Node3D, t: float) -> void:
	var world := root.get_node_or_null("WorldEnvironment") as WorldEnvironment
	var sun := root.get_node_or_null("Sun") as DirectionalLight3D
	if world == null or world.environment == null or sun == null:
		return
	var k := smoothstep(0.45, 0.82, clampf(t, 0.0, 1.0))
	var env := world.environment
	sun.light_color = (DAY.sun_color as Color).lerp(EVENING.sun_color, k)
	sun.light_energy = lerpf(DAY.sun_energy, EVENING.sun_energy, k)
	sun.rotation_degrees = Vector3(
		lerpf(DAY.sun_pitch, EVENING.sun_pitch, k), lerpf(DAY.sun_yaw, EVENING.sun_yaw, k), 0.0
	)
	env.ambient_light_color = (DAY.ambient as Color).lerp(EVENING.ambient, k)
	env.ambient_light_energy = lerpf(DAY.ambient_energy, EVENING.ambient_energy, k)
	env.fog_light_color = (DAY.fog as Color).lerp(EVENING.fog, k)
	env.fog_density = lerpf(DAY.fog_density, EVENING.fog_density, k) * float(root.get_meta("village_fog_scale", 1.0))
	env.tonemap_exposure = lerpf(DAY.exposure, EVENING.exposure, k)
	if env.sky != null and env.sky.sky_material is ProceduralSkyMaterial:
		var sky := env.sky.sky_material as ProceduralSkyMaterial
		sky.sky_top_color = (DAY.sky_top as Color).lerp(EVENING.sky_top, k)
		sky.sky_horizon_color = (DAY.sky_horizon as Color).lerp(EVENING.sky_horizon, k)
		sky.ground_horizon_color = (DAY.ground_horizon as Color).lerp(EVENING.ground_horizon, k)
		sky.ground_bottom_color = sky.ground_horizon_color.darkened(0.35)
		sky.sky_curve = 0.12
		sky.sun_angle_max = 12.0
		sky.sun_curve = 0.12
	var fill := root.get_node_or_null("SkyFill") as DirectionalLight3D
	if fill != null:
		fill.light_energy = lerpf(DAY.fill, EVENING.fill, k)
		fill.shadow_enabled = false
	ART.material().set_shader_parameter("night", k)
	root.set_meta("village_time_of_day", t)
	root.set_meta("village_night", k)


## Aus großer Höhe (Übersicht, Karte der Nachbarstädte) weniger Dunst: der
## Nebel wird mit dem Kameraabstand dünner, damit Schilder und Städte klar bleiben.
static func set_view_distance(root: Node3D, distance: float) -> void:
	var scale := clampf(110.0 / maxf(distance, 1.0), 0.2, 1.0)
	if is_equal_approx(scale, float(root.get_meta("village_fog_scale", 1.0))):
		return
	root.set_meta("village_fog_scale", scale)
	set_time(root, float(root.get_meta("village_time_of_day", 0.35)))
