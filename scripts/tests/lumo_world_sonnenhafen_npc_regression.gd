extends SceneTree
## Sonnenhafen residents in the production World: navigation mesh coverage,
## path following along the mesh (near with NavigationAgent3D + avoidance, far
## as simplified polylines), no jump larger than one walking step per frame,
## daily targets reached, varied activities instead of permanent standing,
## evening homecoming and honest "Computerfigur" labels. Headless-capable.
const PROFILE := "lumo_c12_sonnenhafen_npc"
## Upper bound of the horizontal movement of one resident in one physics frame:
## walking speed 1.35 m/s * 1.25 avoidance margin * 0.1 s maximum step + slack.
const MAX_FRAME_STEP := 0.25
const TIME_SCALE := 4.0
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("[SonnenhafenNpc] " + label)


func _frames(count: int) -> void:
	for index in range(count):
		await physics_frame


func _run() -> void:
	DirAccess.remove_absolute("user://lumo_world_" + PROFILE.sha256_text().substr(0, 32) + ".json")
	root.size = Vector2i(1080, 2340)
	var router: Node = root.get_node("SceneRouter")
	router.launch_options = {"childKey": PROFILE, "grade": 2, "reduceAnimations": false}
	router.goto("world")
	await _frames(40)
	var scene: Node = current_scene
	_check(is_instance_valid(scene) and scene.name == "LumoWorld", "production World opens")
	if not is_instance_valid(scene) or scene.name != "LumoWorld":
		_finish()
		return
	var harbour: Node = scene.sonnenhafen
	_check(harbour != null and harbour.unlocked(), "Sonnenhafen region is loaded and unlocked")
	if harbour == null or not harbour.unlocked():
		_finish()
		return
	var crowd: Node = harbour.crowd
	var layout = harbour.layout
	_check(crowd.actors.size() == 14, "fourteen residents are present")
	_check(
		int(harbour.town.get_meta("nav_polygon_count", 0)) > 100,
		"navigation mesh is built from the town plan"
	)
	_check(
		harbour.town.batch_count > 50 and harbour.town.module_count > 2000,
		"town is assembled from the modular kit as MultiMesh batches"
	)
	for id in crowd.order:
		var actor: Dictionary = crowd.actors[id]
		var walker: bool = not str(actor.walk_clip).is_empty() or (actor.limbs as Array).size() >= 4
		_check(walker, "resident has a real walking body: " + id)
		_check(
			not (actor.root as Node3D).find_children("*", "AnimationPlayer", true, false).any(
				func(player): return (player as AnimationPlayer).has_animation("kart_seated")
			),
			"no seated kart rig is used as walker: " + id
		)
		_check(
			(actor.labels.role as Label3D).text.begins_with("Computerfigur"),
			"honest role label: " + id
		)
		_check(actor.agent is NavigationAgent3D, "resident steers with a NavigationAgent3D: " + id)
		var home: Vector3 = actor.home
		_check(
			home.is_finite() and layout.is_walkable(Vector2(home.x, home.z)),
			"home door is on walkable ground: " + id
		)
	# Every authored spot of every schedule is reachable from the home door.
	var map: RID = scene.get_world_3d().navigation_map
	_check(NavigationServer3D.map_get_iteration_id(map) > 0, "navigation map is synchronised")
	var unreachable: Array[String] = []
	for id in crowd.order:
		var actor: Dictionary = crowd.actors[id]
		var schedule: Dictionary = actor.brain.profile.get("schedule", {})
		for phase in schedule:
			for entry in schedule[phase]:
				var target: Vector3 = crowd._spot_position(actor, str(entry.spot))
				var path := NavigationServer3D.map_get_path(map, actor.home, target, true)
				if path.size() < 2 or path[path.size() - 1].distance_to(target) > 0.8:
					unreachable.append("%s→%s" % [id, str(entry.spot)])
	_check(
		unreachable.is_empty(),
		"every schedule spot is reachable along the navmesh: " + ", ".join(unreachable)
	)

	# --- Day simulation near Lumo (agents with avoidance) -------------------------
	scene.player.position = Vector3(196, 0.1, -147)
	scene.last_safe = scene.player.position
	Engine.time_scale = TIME_SCALE
	var previous: Dictionary = {}
	for id in crowd.order:
		previous[id] = (crowd.actors[id].root as Node3D).position
	var worst := 0.0
	var off_mesh: Array[String] = []
	var frames := 0
	var start_clock: float = scene.open_world.routines.elapsed
	while float(scene.open_world.routines.elapsed) - start_clock < 300.0 and frames < 9000:
		await physics_frame
		frames += 1
		for id in crowd.order:
			var now: Vector3 = (crowd.actors[id].root as Node3D).position
			var before: Vector3 = previous[id]
			worst = maxf(worst, Vector2(now.x - before.x, now.z - before.z).length())
			previous[id] = now
			if frames % 20 == 0 and (crowd.actors[id].root as Node3D).visible:
				var closest := NavigationServer3D.map_get_closest_point(map, now)
				if Vector2(closest.x - now.x, closest.z - now.z).length() > 0.3:
					off_mesh.append("%s@%s" % [id, str(now)])
	Engine.time_scale = 1.0
	var simulated: float = float(scene.open_world.routines.elapsed) - start_clock
	print(
		(
			"[SonnenhafenNpc] simulated %.1f s in %d frames, worst step %.3f m, stats %s"
			% [simulated, frames, worst, str(crowd.stats)]
		)
	)
	_check(simulated >= 200.0, "at least 200 s of the day were simulated (%.1f)" % simulated)
	_check(
		worst <= MAX_FRAME_STEP,
		"no resident moved more than %.2f m in one frame (worst %.3f)" % [MAX_FRAME_STEP, worst]
	)
	_check(int(crowd.stats.teleports) == 0, "no teleport was recorded by the crowd")
	_check(
		off_mesh.is_empty(),
		"residents stay on the navigation mesh: " + ", ".join(off_mesh.slice(0, 5))
	)
	_check(
		int(crowd.stats.agent_moves) > 100, "near residents move through their NavigationAgent3D"
	)
	var lazy: Array[String] = []
	var reached_total := 0
	for id in crowd.order:
		var actor: Dictionary = crowd.actors[id]
		var reached := 0
		for spot in actor.spots_reached:
			reached += int(actor.spots_reached[spot])
		reached_total += reached
		if reached < 2 or float(actor.travelled) < 4.0:
			lazy.append("%s(reached %d, %.1f m)" % [id, reached, float(actor.travelled)])
		print(
			(
				"[SonnenhafenNpc] %s reached=%d travelled=%.1f plans=%d stuck=%d max_idle=%.1f state=%s"
				% [
					id,
					reached,
					float(actor.travelled),
					int(actor.brain.plans_made),
					int(actor.stuck_events),
					float(actor.max_idle),
					actor.brain.status_text()
				]
			)
		)
		_check(
			float(actor.max_idle) < 70.0,
			"no permanent standing: %s idled at most %.1f s" % [id, float(actor.max_idle)]
		)
		_check(int(actor.brain.plans_made) >= 3, "resident changed activity several times: " + id)
	_check(lazy.is_empty(), "every resident reached daily targets and walked: " + ", ".join(lazy))
	_check(
		int(crowd.stats.chats) >= 1,
		"residents met and chatted with each other (%d chats)" % int(crowd.stats.chats)
	)
	_check(reached_total >= 40, "the town is busy: %d targets reached" % reached_total)

	# --- Pause: an open dialog freezes every resident and the day -------------------
	scene._open_dialog("Pause", "Die Welt wartet.")
	var frozen: Dictionary = {}
	for id in crowd.order:
		frozen[id] = (crowd.actors[id].root as Node3D).position
	var paused_clock: float = harbour.clock
	await _frames(60)
	var still := true
	for id in crowd.order:
		still = still and (crowd.actors[id].root as Node3D).position == frozen[id]
	_check(
		still and harbour.clock == paused_clock,
		"an open dialog freezes all residents and the harbour day"
	)
	scene._close_dialog()

	# --- Far simulation (Lumo on the mainland) ------------------------------------
	scene.player.position = Vector3(110, 0.1, 18)
	scene.last_safe = scene.player.position
	var far_before: int = int(crowd.stats.far_moves)
	print("[SonnenhafenNpc] far phase starts at physics frame %d" % Engine.get_physics_frames())
	Engine.time_scale = TIME_SCALE
	await _frames(900)
	Engine.time_scale = 1.0
	var all_far := true
	for id in crowd.order:
		all_far = all_far and not bool(crowd.actors[id].near)
	_check(all_far, "distant residents switch to simplified simulation")
	_check(int(crowd.stats.far_moves) > far_before, "distant residents keep following their paths")
	_check(
		int(crowd.stats.teleports) == 0,
		(
			"no teleport in the simplified simulation either "
			+ str(crowd.stats.get("last_teleport", ""))
		)
	)

	# --- Evening: residents go home and disappear only at their own door ----------
	scene.player.position = Vector3(200, 0.1, -128)
	scene.open_world.routines.elapsed = 610.0
	Engine.time_scale = TIME_SCALE
	await _frames(1300)
	Engine.time_scale = 1.0
	var home_count := 0
	var wrong_door: Array[String] = []
	for id in crowd.order:
		var actor: Dictionary = crowd.actors[id]
		if actor.brain.state == actor.brain.State.HOME:
			home_count += 1
			if (actor.root as Node3D).position.distance_to(actor.home) > 1.0:
				wrong_door.append(id)
	print(
		(
			"[SonnenhafenNpc] residents at home in the evening: %d, hour %.2f"
			% [home_count, float(harbour.hour)]
		)
	)
	_check(home_count >= 8, "most residents walked home in the evening (%d)" % home_count)
	_check(
		wrong_door.is_empty(),
		"residents vanish only at their own front door: " + ", ".join(wrong_door)
	)
	_check(harbour.evening > 0.5, "evening light is active")
	_finish()


func _finish() -> void:
	Engine.time_scale = 1.0
	print("[SonnenhafenNpc] %s %d checks" % ["PASS" if failures.is_empty() else "FAIL", checks])
	for failure in failures:
		print("  FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)
