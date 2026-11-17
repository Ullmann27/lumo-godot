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


func _assert_box_collider(body: StaticBody3D, expected_size: Vector3) -> void:
	var colliders: Array[CollisionShape3D] = []
	for child in body.get_children():
		if child is CollisionShape3D:
			colliders.append(child)
	assert(colliders.size() == 1, "%s must have exactly one collider" % body.name)
	var collider: CollisionShape3D = colliders[0]
	assert(collider.shape is BoxShape3D, "%s must keep its box shape" % body.name)
	assert(collider.shape.size == expected_size, "%s collider dimensions changed" % body.name)
	assert(not collider.disabled, "%s collider must remain enabled" % body.name)
	assert(
		collider.transform == Transform3D.IDENTITY,
		"%s collider offset or scale changed" % body.name
	)
	assert(body.basis == Basis.IDENTITY, "%s collision body rotation or scale changed" % body.name)
	assert(
		body.collision_layer == 1 and body.collision_mask == 1,
		"%s collision layers changed" % body.name
	)


func _assert_jump_colliders(game: Node) -> void:
	assert(game.islands.size() == 12, "all twelve original island anchors remain")
	var checked: Array[Node] = []
	for index in range(12):
		var original := Vector3(
			sin(float(index) * 0.75) * 3.0, sin(float(index) * 0.55) * 0.9, -float(index) * 8.0
		)
		assert(game.islands[index] == original, "original island anchor %d moved" % index)
		var matches: Array[StaticBody3D] = []
		for child in game.get_children():
			# AnimatableBody3D inherits StaticBody3D. Added moving platforms
			# must never satisfy the contract of an original stationary island.
			if child.get_class() == "StaticBody3D" and child.position == original:
				matches.append(child)
		assert(matches.size() == 1, "original island %d needs one stationary body" % index)
		_assert_box_collider(matches[0], Vector3(7.0, 0.5, 6.0))
		checked.append(matches[0])
	assert(game.movers.size() == 3, "three gameplay moving platforms remain")
	var moving_indices: Array[int] = [1, 4, 7]
	var moving_sides: Array[float] = [1.0, -1.0, 1.0]
	for index in range(3):
		var mover: Dictionary = game.movers[index]
		var body = mover.body
		var anchor: int = moving_indices[index]
		assert(body is AnimatableBody3D, "moving platform needs a real animatable collision body")
		assert(body.get_parent() == game and body.name == "MovingIsland%d" % anchor)
		assert(not checked.has(body), "each moving platform needs its own collision body")
		assert(body.sync_to_physics, "moving platforms must synchronize physical contacts")
		var origin: Vector3 = (game.islands[anchor] + game.islands[anchor + 1]) * 0.5
		origin += Vector3(moving_sides[index] * 5.8, 0.12, 0.0)
		assert(mover.origin == origin, "moving platform origin changed")
		assert(mover.axis == Vector3(moving_sides[index] * 1.75, 0.0, 0.0))
		_assert_box_collider(body, Vector3(3.15, 0.45, 2.55))
		checked.append(body)
	var bonus = game.get_node_or_null("BonusIsland")
	assert(
		bonus != null and bonus.get_class() == "StaticBody3D", "bonus island must stay stationary"
	)
	var bonus_position: Vector3 = game.islands[4] + Vector3(7.15, 0.55, -1.4)
	assert(game.extra_island == bonus_position and bonus.position == bonus_position)
	_assert_box_collider(bonus, Vector3(4.0, 0.5, 3.35))
	checked.append(bonus)
	for child in game.get_children():
		if child is StaticBody3D:
			assert(
				checked.has(child), "unexpected or duplicate island collision body: %s" % child.name
			)
	assert(checked.size() == 16, "twelve original, three moving and one bonus body are distinct")


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
	holder.queue_free()
	# 3. Wolkeninseln: same colliders, sky + fog, detail scales with tier.
	var scatter: Dictionary = {}
	for tier in [0, 1, 2]:
		var game: Node = await _jump(tier)
		var world := _find(game, "WorldEnvironment") as WorldEnvironment
		assert(world != null and world.environment.background_mode == Environment.BG_SKY)
		assert(world.environment.fog_enabled or tier == 0)
		_assert_jump_colliders(game)
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
