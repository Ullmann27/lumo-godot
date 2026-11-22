extends SceneTree
## Durchgehende Fahrt vom Schlaucheintritt bis unter die obere Windung der Topfspirale.
const COURSE = preload("res://scripts/games/garden/kart_garden_course.gd")
const TEARDOWN = preload("res://scripts/tests/helpers/kart_scene_teardown.gd")
const STEP := 1.0 / 60.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	game._start_selected_race({"mode": "training", "driver": "fox", "kart": "comet",
		"track": COURSE.ID, "difficulty": "flott"})
	game._end_preview()
	await physics_frame
	await physics_frame
	game.countdown = 0.0
	game.racing = true
	game.auto_gas = true
	game.distance = COURSE.HOSE.x - 15.0
	game.previous_road_distance = game.distance
	game.player.transform = game.world.reset_transform(game.distance)
	game.player_heading = game._heading(game.distance)
	var starting_resets: int = game.reset_count
	var min_normal_y := 1.0
	var failed := false
	var overhead := false
	var last_probe := -1.0
	for frame in range(3600):
		var at: float = game.previous_road_distance
		if at >= COURSE.SPIRAL.y + 32.0:
			break
		var aim: Vector3 = game.world.position_at(at + 9.0) - game.player.position
		game.steering = clampf(-angle_difference(game.player_heading, atan2(-aim.x, -aim.z)) * 2.6, -1.0, 1.0)
		game._physics_process(STEP)
		if at >= COURSE.HOSE.x and at < COURSE.HOSE.y:
			min_normal_y = minf(min_normal_y, game.player.basis.y.y)
		if at > COURSE.SPIRAL.x and at > last_probe + 1.0:
			last_probe = at
			var space: PhysicsDirectSpaceState3D = game.world.get_world_3d().direct_space_state
			var origin: Vector3 = game.player.position + Vector3.UP * 0.4
			var query := PhysicsRayQueryParameters3D.create(origin, origin + Vector3.UP * 40.0, 1)
			var hit := space.intersect_ray(query)
			if not hit.is_empty():
				var height := origin.distance_to(hit.position) + 0.4
				if height < 6.0:
					printerr("[GardenDrive] Durchfahrtshöhe %.1f m bei %.1f m" % [height, at])
					failed = true
					break
				overhead = overhead or str(hit.collider.name).begins_with("RoadCollision")
		if frame % 120 == 0:
			await process_frame
	var end: float = game.previous_road_distance
	var ok: bool = (not failed and overhead and min_normal_y < 0.84 and end >= COURSE.SPIRAL.y + 32.0
		and game.reset_count == starting_resets)
	print("[GardenDrive] %s: %.1f m, Normale %.3f, Überführung %s, Rücksetzer %d" % [
		"PASS" if ok else "FAIL", end, min_normal_y, overhead, game.reset_count - starting_resets])
	var released: bool = await TEARDOWN.release_scene(self, game, "[GardenDrive]")
	quit(0 if ok and released else 1)
