extends SceneTree
## Builds every selectable kart and exercises real geometry, motion and garage views.

const VEHICLE = preload("res://scripts/games/kart_vehicle.gd")
const CATALOG = preload("res://scripts/games/kart_catalog.gd")
const FLEET = preload("res://scripts/games/kart_fleet.gd")
const PRODUCTION = preload("res://scripts/games/kart_production_vehicle.gd")
const GARAGE = "res://scripts/games/kart_garage_menu.gd"
const WORLD = preload("res://scripts/games/kart_world.gd")


func _initialize() -> void:
	call_deferred("_run")


func _settle() -> void:
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw


func _geometry(node: Node3D, kart, result: Dictionary) -> void:
	for child in node.get_children():
		if child is Node3D and not child.is_visible_in_tree():
			continue
		if child is MeshInstance3D:
			if child == kart.far_mesh or kart.flames.has(child) or kart.sparks.has(child):
				continue
			result.surfaces += child.mesh.get_surface_count()
			for surface in range(child.mesh.get_surface_count()):
				var arrays: Array = child.mesh.surface_get_arrays(surface)
				result.vertices += arrays[Mesh.ARRAY_VERTEX].size()
		elif child is Node3D:
			_geometry(child, kart, result)


func _run() -> void:
	root.size = Vector2i(1280, 720)
	assert(CATALOG.KARTS.size() == 24)
	var seen: Dictionary = {}
	var signatures: Dictionary = {}
	var shell_geometry: Dictionary = {}
	var close_geometry: Dictionary = {}
	for entry in CATALOG.KARTS:
		assert(not seen.has(entry.id), "Garage IDs must be unique")
		seen[entry.id] = true
		var kart = VEHICLE.new()
		kart.configure("fox", Color("76d9ff"), str(entry.id))
		kart.set_animated_lumo_enabled(true)
		root.add_child(kart)
		kart.set_process(false)
		assert(kart.kart_style == entry.id, "Selectable design must not fall back to Comet")
		assert(kart.wheel_pivots.size() == 4 and kart.wheel_rotors.size() == 4)
		assert(is_instance_valid(kart.lumo_animation) and not kart.driver.visible)
		var shape := {"surfaces": 0, "vertices": 0}
		_geometry(kart, kart, shape)
		assert(shape.vertices > 1000)
		assert(shape.surfaces <= 64, "Fleet must retain the mobile draw-surface budget")
		if is_instance_valid(kart.production_vehicle):
			var sources: Array[String] = kart.production_vehicle.source_paths
			var platform := PRODUCTION.body_of(str(entry.id))
			assert(sources.size() == (4 if seen.size() <= 14 else 3), "All three mechanical LOD sources and every existing Meshy model")
			for level in range(3):
				var suffix := "" if level == 0 else "_lod%d" % level
				assert(sources[level] == PRODUCTION.MODEL_DIRECTORY + "aurora_" + platform + suffix + ".glb")
			if seen.size() <= 14:
				assert(sources[3] == PRODUCTION.MESHY_SHELL_DIRECTORY + str(entry.id) + ".glb")
			assert(kart.production_vehicle.visible_surface_count() <= 39)
			assert(kart.far_mesh.mesh == null, "The animated imported chassis needs no rigid proxy")
		else:
			assert(kart.far_mesh.mesh.get_surface_count() == 1)
		assert(float(entry.speed) >= 0.9 and float(entry.speed) <= 1.11)
		assert(float(entry.turn) >= 0.9 and float(entry.turn) <= 1.14)
		kart.set_motion(12.0, 0.7, true, true)
		kart._process(0.016)
		assert(kart.flames[0].visible and kart.sparks[0].visible)
		assert(is_instance_valid(kart.production_vehicle), "Every kart uses an authored exterior")
		var production = kart.production_vehicle
		assert(production.get_meta("fleet_design") == entry.id)
		assert(production.shell_path.ends_with("/%s.glb" % entry.id))
		var has_meshy: bool = seen.size() <= 14
		var close: MeshInstance3D = production.meshy_close_mesh if has_meshy else production.stock_close_mesh
		assert(is_instance_valid(close) and close.is_visible_in_tree(), "Authored shell is drawn at LOD0")
		var close_signature := hash(close.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX])
		assert(not close_geometry.has(close_signature), "Selectable close shells must have distinct geometry")
		close_geometry[close_signature] = entry.id
		var shell_vertices := 0
		for level in range(3):
			production.set_lod(level)
			var shell := production.asset_root.find_child("LOD%d" % level, true, false) as MeshInstance3D
			assert(shell != null and shell.is_visible_in_tree() == (level > 0 or not has_meshy))
			assert(close.is_visible_in_tree() == (level == 0), "Close and distant shells never overlap")
			var vertices := 0
			var outlines: Array[int] = []
			for surface in range(shell.mesh.get_surface_count()):
				vertices += shell.mesh.surface_get_array_len(surface)
				if level == 0:
					outlines.append(hash(shell.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]))
			if level == 0:
				var signature := hash(outlines)
				assert(not shell_geometry.has(signature), "Selectable shells must have distinct geometry")
				shell_geometry[signature] = entry.id
			else:
				assert(vertices < shell_vertices, "Each shell LOD must reduce geometry")
			shell_vertices = vertices
		var dressing: Array[String] = []
		for detail in production.dressing_nodes():
			dressing.append(str(detail.name))
		dressing.sort()
		assert(dressing == [
			"Dress_Number_L", "Dress_Number_Nose", "Dress_Number_R",
			"Dress_Sticker_Front_L", "Dress_Sticker_Front_R",
			"Dress_Sticker_Rear_L", "Dress_Sticker_Rear_R", "EvolutionCoachwork",
		], "Seven authored decals and the current splitter/diffuser stay attached: " + str(dressing))
		assert(is_instance_valid(kart.production_lumo_seat), "Original Lumo retains the pedal and seat fit")
		var signature: String = str(FLEET.multipliers(entry.stats, entry.traits))
		assert(not signatures.has(signature), "Each kart needs a distinct physical profile")
		signatures[signature] = true
		var stance := 0.91 if production.variant == "glider" else (1.10 if production.variant == "turbo" else 1.0)
		for pivot: Node3D in kart.wheel_pivots:
			assert(is_equal_approx(absf(pivot.position.x), 0.77 * stance), "Wheel stance matches its chassis")
			assert(is_equal_approx(pivot.position.y, 0.35), "Wheel radius matches the chassis ground plane")
			assert(is_equal_approx(absf(pivot.position.z), 0.66), "Wheelbase matches the chassis")
		var skeleton: Skeleton3D = kart.lumo_animation.actor.skeleton
		for side in range(2):
			var hand := skeleton.find_bone("Hand.L" if side == 0 else "Hand.R")
			var contact := skeleton.to_global(skeleton.get_bone_global_pose(hand).origin)
			var grip: Vector3 = kart.steering_wheel.to_global(kart.wheel_rest_grips[side])
			assert(contact.distance_to(grip) < 0.006, "Lumo's hand remains on the wheel")
		print(
			"[KartFleet] %s: %d surfaces, %d vertices" % [entry.id, shape.surfaces, shape.vertices]
		)
		kart.queue_free()
		await _settle()
	var fallback = VEHICLE.new()
	fallback.configure("fox", Color.WHITE, "unknown_future_kart")
	assert(fallback.kart_style == "comet")
	fallback.free()
	var garage = load(GARAGE).new()
	garage.stars = 100
	garage.reduced_motion = true
	root.add_child(garage)
	garage.step = 2
	garage.setup.kart = "boru_rally"
	garage._refresh()
	await process_frame
	assert(garage._entries().size() == 24)
	for view in range(1, 6):
		garage._choose_preview_view(view)
		assert(garage.preview_camera.projection == Camera3D.PROJECTION_ORTHOGONAL)
		assert(garage.preview_pivot.rotation.y == 0.0)
	garage.step = 3
	garage._refresh()
	assert(garage.preview_camera.projection == Camera3D.PROJECTION_PERSPECTIVE)
	garage.step = 2
	garage._refresh()
	garage._choose_preview_view(0)
	assert(garage.preview_camera.projection == Camera3D.PROJECTION_PERSPECTIVE)
	garage.queue_free()
	await _settle()
	for track in ["sonnenhafen", "zauberwald", "holo_city"]:
		var world = WORLD.new()
		root.add_child(world)
		world.build(false, track, true)
		await _settle()
		assert(world.get_meta("fleet_dressing_detail_count", 0) > 0)
		world.queue_free()
		await _settle()
	var game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	for id in FLEET.ids():
		game._start_selected_race(
			{
				"mode": "training",
				"driver": "fox",
				"kart": id,
				"track": "sonnenhafen",
				"difficulty": "flott"
			}
		)
		game._end_preview()
		await _settle()
		game.countdown = 0
		game.racing = true
		game.auto_gas = true
		assert(game.player.kart_style == id and game.selected_kart == id)
		for frame in range(90):
			game._physics_process(1.0 / 60.0)
		assert(game.speed > 5.0 and game.distance > 4.0, "Every selectable kart must actually drive")
		var configured: Dictionary = FLEET.multipliers(FLEET.base_stats(id), FLEET.entry(id).traits)
		for factor in ["speed", "accel", "brake", "grip", "turn", "boost_power", "boost_time", "offroad", "stability"]:
			assert(is_equal_approx(float(game.kart_factors[factor]), float(configured[factor])),
				"%s uses its own %s factor in the production race" % [id, factor])
		print("[KartFleet] road test %s: %.2f m/s after %.2f m" % [id, game.speed, game.distance])
		game._save_session()
		var saved := ConfigFile.new()
		assert(saved.load(game.SESSION) == OK)
		assert(str(saved.get_value("race", "selected_kart", "")) == id)
	game.abandoned = true
	game.queue_free()
	await _settle()
	await create_timer(0.2).timeout
	print("[KartFleet] PASS: 24 designs, animated chassis, LOD, budgets, garage views, scenery and actual race starts")
	quit()
