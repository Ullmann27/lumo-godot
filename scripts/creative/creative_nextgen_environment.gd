extends RefCounted
## Daylight finishing pass for real creative scenes. Reuses the existing sun,
## fill, sky and cloud batch; never adds lights, postprocessing or collisions.
const MAX_CLOUD_PUFFS := 18
# Weak caches share materials between live meshes without retaining GPU
# resources until static GDScript teardown after the rendering server exits.
static var _ground: WeakRef
static var _plot: WeakRef
static var _stone: WeakRef


static func apply_day(root: Node3D) -> Dictionary:
	if bool(root.get_meta("creative_nextgen_day_applied", false)):
		return {"applied": false, "reason": "already_applied"}
	var world := root.get_node_or_null("WorldEnvironment") as WorldEnvironment
	var sun := root.get_node_or_null("Sun") as DirectionalLight3D
	if world == null or world.environment == null or sun == null:
		return {"applied": false, "reason": "missing_day_environment"}
	# creative_kit creates a new Environment and Sky for each scene. Finish
	# that owned instance; duplicating the GPU-backed Sky creates an unused
	# radiance allocation and extends its lifetime beyond the visible world.
	var environment := world.environment
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("a7c0d4")
	environment.ambient_light_sky_contribution = 0.35
	environment.ambient_light_energy = 0.43
	environment.tonemap_exposure = 0.94
	environment.tonemap_white = 4.0
	environment.adjustment_saturation = 1.04
	environment.adjustment_contrast = 1.08
	environment.fog_light_color = Color("8ba8b9")
	environment.fog_density = 0.0032
	environment.fog_aerial_perspective = 0.20
	environment.fog_sky_affect = 0.0
	if environment.sky != null and environment.sky.sky_material is ProceduralSkyMaterial:
		var sky := environment.sky.sky_material as ProceduralSkyMaterial
		sky.sky_top_color = Color("407db5")
		sky.sky_horizon_color = Color("c3d6db")
		sky.sky_curve = 0.21
		sky.ground_horizon_color = Color("a6bec7")
		sky.ground_bottom_color = Color("4c7389")
		sky.sun_angle_max = 9.0
		sky.sun_curve = 0.18
	sun.light_color = Color("ffe4b8")
	sun.light_energy = 0.98
	sun.light_specular = 0.35
	# Preserve shadow enablement, map budget, split count and shadow distance.
	var fill := root.get_node_or_null("SkyFill") as DirectionalLight3D
	if fill != null:
		fill.light_color = Color("a3c3da")
		fill.light_energy = 0.14
		fill.light_specular = 0.08
	var count := _finish_clouds(root.get_node_or_null("DayClouds") as MultiMeshInstance3D)
	root.set_meta("creative_nextgen_day_applied", true)
	return {"applied": true, "cloud_puffs": count, "extra_lights": 0, "extra_draw_calls": 0}


static func _finish_clouds(clouds: MultiMeshInstance3D) -> int:
	if clouds == null or clouds.multimesh == null:
		return 0
	var count := mini(MAX_CLOUD_PUFFS, clouds.multimesh.instance_count)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = clouds.multimesh.mesh
	multi.instance_count = count
	multi.visible_instance_count = count
	clouds.multimesh = multi
	var authored: Array[Transform3D] = []
	for index in range(count):
		# Clouds stay beyond the playable banks instead of crossing the
		# overview camera at 14–26 metres and obscuring the upper HUD.
		var fraction := float(index) / maxf(1.0, count - 1.0)
		var angle := -PI + fraction * PI
		var at := Vector3(
			cos(angle) * 73.0, 24.0 + sin(index * 0.73) * 3.0, -26.0 + sin(angle) * 53.0
		)
		var scale := Vector3(
			3.2 + fmod(index * 0.7, 2.3),
			0.80 + fmod(index * 0.13, 0.55),
			2.2 + fmod(index * 0.31, 1.3)
		)
		var transform := Transform3D(Basis.from_scale(scale), at)
		authored.append(transform)
		multi.set_instance_transform(index, transform)
	clouds.set_meta("nextgen_cloud_transforms", authored)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("c5d6de")
	material.roughness = 1.0
	material.metallic = 0.0
	material.emission_enabled = false
	clouds.material_override = material
	clouds.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return count


static func ground_material() -> StandardMaterial3D:
	var material: StandardMaterial3D = _ground.get_ref() if _ground != null else null
	if material == null:
		material = BuildVoxelStyle.material("grass_top").duplicate()
		material.albedo_color = Color("b4be8b")
		material.roughness = 0.94
		material.normal_scale = 0.32
		material.metallic_specular = 0.16
		material.uv1_scale = Vector3.ONE * 0.32
		_ground = weakref(material)
	return material


static func plot_material(_opponent := false) -> StandardMaterial3D:
	var material: StandardMaterial3D = _plot.get_ref() if _plot != null else null
	if material == null:
		material = BuildVoxelStyle.material("dirt").duplicate()
		material.albedo_color = Color("c0b68c")
		material.roughness = 0.96
		material.normal_scale = 0.35
		material.metallic_specular = 0.12
		material.uv1_scale = Vector3.ONE * 0.8
		_plot = weakref(material)
	return material


static func bank_material() -> StandardMaterial3D:
	var material: StandardMaterial3D = _stone.get_ref() if _stone != null else null
	if material == null:
		material = BuildVoxelStyle.material("stone").duplicate()
		material.albedo_color = Color("9b967e")
		material.roughness = 0.90
		material.normal_scale = 0.45
		_stone = weakref(material)
	return material
