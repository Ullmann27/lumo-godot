extends SceneTree
## LumoRenderKit: one quality tier (PerformanceManager + Kart), environment
## presets and the Wolkeninseln art layer. Restores the saved tier at the end.


func _initialize() -> void:
	call_deferred("_run")


func _count(node: Node, type: String) -> int:
	var total: int = 1 if node.is_class(type) else 0
	for child in node.get_children():
		total += _count(child, type)
	return total


func _find(node: Node, name: String) -> Node:
	if node.name == name:
		return node
	for child in node.get_children():
		var found: Node = _find(child, name)
		if found != null:
			return found
	return null


func _jump(tier: int) -> Node:
	root.get_node("PerformanceManager").call("set_profile", tier, false)
	DirAccess.remove_absolute("user://jump_session.cfg")
	root.get_node("SceneRouter").launch_options = {"grade": 1, "subject": "Mathematik"}
	var game: Node = load("res://scenes/games/jump_islands.tscn").instantiate()
	root.add_child(game)
	await process_frame
	return game


func _run() -> void:
	await process_frame
	await process_frame
	var performance: Node = root.get_node("PerformanceManager")
	var store: Node = root.get_node("SettingsStore")
	var saved: String = str(store.call("get_profile"))
	var saved_tier: int = int(performance.get("current_profile"))
	# 1. One tier: LumoQuality reads and writes the PerformanceManager tier.
	assert(LumoQuality.tier() == str(performance.call("get_profile_name")))
	for name in ["low", "high", "medium"]:
		LumoQuality.set_tier(name)
		assert(str(performance.call("get_profile_name")) == name)
		assert(str(store.call("get_profile")) == name, "tier must persist like Kart's choice")
		assert(LumoQuality.budget() == LumoQuality.BUDGETS[name])
	# Kart camera range is unchanged (legacy 450 / 340 / 260 m).
	assert(LumoQuality.budget("high").camera_far == 450.0)
	assert(LumoQuality.budget("medium").camera_far == 340.0)
	assert(LumoQuality.budget("low").camera_far == 260.0)
	# 2. creative_night keeps the former creative_kit values on every tier.
	var holder := Node3D.new()
	root.add_child(holder)
	var night: Dictionary = LumoEnvironment.apply(holder, "creative_night", "high")
	var env: Environment = night.environment
	var sky_mat := env.sky.sky_material as ProceduralSkyMaterial
	assert(sky_mat.sky_top_color.is_equal_approx(Color("081537")))
	assert(is_equal_approx(env.ambient_light_energy, 0.36))
	assert(env.tonemap_mode == Environment.TONE_MAPPER_FILMIC)
	assert(is_equal_approx(env.glow_intensity, 0.75))
	assert(night.sun.shadow_enabled)
	assert(is_equal_approx(night.sun.directional_shadow_max_distance, 70.0))
	assert(is_equal_approx(night.sun.light_energy, 0.80))
	assert(night.sun.light_color.is_equal_approx(Color("d9e8ff")))
	var low_night: Dictionary = LumoEnvironment.apply(holder, "creative_night", "low")
	assert(low_night.sun.shadow_enabled, "creative_night must stay identical on every tier")
	assert(night.fill == null and night.rim == null)
	assert(env.fog_density < 0.005 and is_equal_approx(env.fog_sky_affect, 0.0), "creative_night fog explicit and thin")
	var day: Dictionary = LumoEnvironment.apply(holder, "bauwelt_day", "high")
	assert(day.fill is DirectionalLight3D and day.rim == null, "bauwelt_day fill light under key fill")
	holder.queue_free()
	# 3. Wolkeninseln: same colliders, sky + fog, detail scales with tier.
	var scatter: Dictionary = {}
	for tier in [0, 1, 2]:
		var game: Node = await _jump(tier)
		var world := _find(game, "WorldEnvironment") as WorldEnvironment
		assert(world != null and world.environment.background_mode == Environment.BG_SKY)
		assert(world.environment.fog_enabled or tier == 0)
		assert(game.islands.size() == 12)
		var boxes: int = 0
		for child in game.get_children():
			if child is StaticBody3D:
				for grand in child.get_children():
					if grand is CollisionShape3D and grand.shape is BoxShape3D:
						assert(grand.shape.size == Vector3(7, 0.5, 6), "island collider changed")
						boxes += 1
		assert(boxes == 12, "every island keeps its box collider")
		assert(game.crystals.size() == 11)
		for crystal in game.crystals:
			assert(crystal.get_node_or_null("StarGem") != null)
		var grass := _find(game, "GrassScatter") as MultiMeshInstance3D
		var clouds := _find(game, "CloudSea") as MultiMeshInstance3D
		scatter[tier] = [grass.multimesh.instance_count, clouds.multimesh.instance_count]
		assert((_find(game, "Sparkles") != null) == (tier > 0), "no particles on LOW")
		assert(_find(game, "Waterfall0") != null)
		var sun := _find(game, "Sun") as DirectionalLight3D
		assert(sun.shadow_enabled == (tier > 0))
		game.queue_free()
		await process_frame
	assert(scatter[0][0] < scatter[1][0] and scatter[1][0] < scatter[2][0])
	assert(scatter[0][1] < scatter[1][1] and scatter[1][1] < scatter[2][1])
	print(
		(
			"[LumoRenderKit] scatter grass/clouds low=%s medium=%s high=%s"
			% [scatter[0], scatter[1], scatter[2]]
		)
	)
	performance.call("set_profile", saved_tier, false)
	store.call("set_profile", saved)
	print(
		"[LumoRenderKit] PASS one tier, Kart far unchanged, creative preset identical, Wolkeninseln tiers"
	)
	quit(0)
