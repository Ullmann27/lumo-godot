extends SceneTree
## Inspect the actual Volcano light pool and material inputs without a renderer claim.
const WORLD = preload("res://scripts/games/kart_world.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var mobile: bool = "--mobile" in OS.get_cmdline_user_args()
	var world = WORLD.new()
	root.add_child(world)
	world.build(mobile, "volcano_night", false)
	await process_frame
	var tunnel = world.production_tunnels
	var layout: Dictionary = world.production_tunnel_layout
	var at: float = (float(layout.start) + float(layout.end)) * 0.5
	var camera_position: Vector3 = world.position_at(at) - world.forward(at) * 4.8 + Vector3.UP * 2.52
	var road_sample: Vector3 = world.position_at(at)
	tunnel.update_light_focus(camera_position)
	var lights: Array[Dictionary] = []
	for light in tunnel.light_pool:
		var road: Dictionary = world.sample_road(world.to_local(light.global_position))
		lights.append({"active": light.visible, "energy": light.light_energy,
			"range_m": light.omni_range, "attenuation": light.omni_attenuation,
			"color_srgb": light.light_color.to_html(false), "shadows": light.shadow_enabled,
			"world_position": [light.global_position.x, light.global_position.y, light.global_position.z],
			"height_above_road_m": light.global_position.y - float(road.height),
			"distance_to_road_sample_m": light.global_position.distance_to(world.to_global(road_sample))})
	var environments: Array[Dictionary] = []
	for child in world.get_children():
		if child is WorldEnvironment:
			var env: Environment = child.environment
			environments.append({"ambient_energy": env.ambient_light_energy, "ambient_color": env.ambient_light_color.to_html(false),
				"contrast": env.adjustment_contrast, "adjustments": env.adjustment_enabled,
				"tonemapper": env.tonemap_mode, "exposure": env.tonemap_exposure})
	var materials: Array[Dictionary] = []
	for key in tunnel._materials:
		var material: Material = tunnel._materials[key]
		if material is StandardMaterial3D:
			var standard: StandardMaterial3D = material as StandardMaterial3D
			materials.append({"name": key, "albedo": standard.albedo_color.to_html(false),
				"metallic": standard.metallic, "roughness": standard.roughness,
				"emission": standard.emission.to_html(false), "emission_energy": standard.emission_energy_multiplier,
				"shading_mode": standard.shading_mode, "normal_enabled": standard.normal_enabled})
	var output: Dictionary = {"theme": "volcano_night", "engine": Engine.get_version_info().string,
		"low_detail": mobile,
		"light_mount_count": tunnel.light_mounts.size(), "light_pool_count": tunnel.light_pool.size(),
		"lights": lights, "environments": environments, "materials": materials,
		"notes": "Actual runtime state; native screenshot required for visual brightness judgement"}
	var suffix: String = "current"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--label="):
			suffix = argument.trim_prefix("--label=")
	var path: String = "res://evidence/lumo_kart_art/tracks/runtime/volcano_lighting_" + suffix + ".json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(output, "  "))
	print(JSON.stringify(output, "  "))
	world.queue_free()
	await process_frame
	quit()
