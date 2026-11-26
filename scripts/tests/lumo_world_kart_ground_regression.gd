extends SceneTree
## Kart ground contact on every entry path through the real SceneRouter world:
## first entry, re-entry from sunken and floating legacy saves, driving to the
## bridge, parking on hillside heightmap slopes, pushing against the compass
## pedestal and the welcome arch, and the fall reset. A tyre counts as clean
## when its bottom is within GAP_LIMIT of the floor straight below it, and the
## kart collision box (lifted by BOX_LIFT) must not overlap static geometry.
const STATE = preload("res://scripts/creative/lumo_world_state.gd")
const PROFILE := "lumo_world_kart_ground_regression_20261124"
const GAP_LIMIT := 0.03
const BOX_LIFT := 0.05
const WHEEL_RADIUS := 0.35
## Hillside spots measured on the village heightmap: one rising along both
## axes, one with a pure sideways slope.
const SLOPES: Array[Vector3] = [Vector3(442, 12, -62), Vector3(292, 4, 70)]
var checks := 0
var failures: Array[String] = []
var world_path := ""


func _initialize() -> void:
	_run.call_deferred()


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error("[LumoWorldKartGround] " + label)


func _run() -> void:
	world_path = "user://lumo_world_" + PROFILE.sha256_text().substr(0, 32) + ".json"
	DirAccess.remove_absolute(world_path)
	root.size = Vector2i(720, 1280)
	var scene = await _enter_world()
	_check(scene != null, "the real router opens a fresh World")
	if scene == null:
		_finish()
		return
	_expect_grounded(scene, "first entry")
	_check(_wheel_count(scene) == 4, "the production kart exposes four wheel pivots")
	await _drive_to_bridge(scene)
	_expect_grounded(scene, "parked on the island bridge")
	await _slopes(scene)
	await _decoration(scene)
	await _airborne_exit(scene)
	await _fall_reset(scene)
	for height in [-0.119, 0.2, 0.55]:
		await _reenter_with_height(height)
	await _reenter_unsupported(Vector3(50, 0.2, 30), "between the island and mainland")
	await _reenter_unsupported(Vector3(37.4, 0.2, 13), "past the island shoreline")
	DirAccess.remove_absolute(world_path)
	_finish()


func _enter_world() -> Node:
	var router: Node = root.get_node("SceneRouter")
	router.launch_options = {"childKey": PROFILE, "grade": 2, "reduceAnimations": true}
	router.goto("world")
	await _frames(90)
	return current_scene if is_instance_valid(current_scene) and current_scene.name == "LumoWorld" else null


func _wheel_count(scene: Node) -> int:
	return scene.kart_visual.wheel_pivots.size()


## Signed gaps of all tyres: positive floats above the floor, negative sinks in.
func _wheel_gaps(scene: Node) -> Array[float]:
	var space: PhysicsDirectSpaceState3D = scene.get_world_3d().direct_space_state
	var gaps: Array[float] = []
	var down: Vector3 = scene.kart_visual.global_basis.y.normalized()
	for pivot in scene.kart_visual.wheel_pivots:
		var bottom: Vector3 = pivot.global_position - down * WHEEL_RADIUS
		var ray := PhysicsRayQueryParameters3D.create(bottom + Vector3.UP * 1.2, bottom + Vector3.DOWN * 1.5, 0xFFFFFFFF, [scene.kart_body.get_rid(), scene.player.get_rid()])
		var hit: Dictionary = space.intersect_ray(ray)
		gaps.append(INF if hit.is_empty() else bottom.y - float(hit.position.y))
	return gaps


func _box_overlaps(scene: Node) -> int:
	var shape_node: CollisionShape3D = scene.kart_body.get_child(0)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape_node.shape
	query.transform = shape_node.global_transform.translated(Vector3.UP * BOX_LIFT)
	query.exclude = [scene.kart_body.get_rid(), scene.player.get_rid()]
	return scene.get_world_3d().direct_space_state.intersect_shape(query, 4).size()


func _expect_grounded(scene: Node, tag: String) -> void:
	var gaps := _wheel_gaps(scene)
	var worst := 0.0
	for gap in gaps:
		worst = maxf(worst, absf(gap))
	var text := ", ".join(gaps.map(func(gap: float) -> String: return "%.3f" % gap))
	_check(gaps.size() == 4 and worst <= GAP_LIMIT, "all tyres touch the floor (%s): [%s] m" % [tag, text])
	_check(_box_overlaps(scene) == 0, "the kart body is not inside geometry (%s)" % tag)


func _settle_parked(scene: Node, frames: int) -> void:
	scene.joystick.target = Vector2.ZERO
	scene.joystick.axis = Vector2.ZERO
	scene.kart_body.velocity = Vector3.ZERO
	scene.drive_speed = 0.0
	await _frames(frames)


func _drive_to_bridge(scene: Node) -> void:
	scene.vehicle_button.pressed.emit()
	await _frames(4)
	_check(scene.driving, "the real entry control seats Lumo in the kart")
	var deepest := 0.0
	var reached := false
	for index in range(900):
		var at: Vector3 = scene.kart_body.position
		var desired := atan2(-(45.0 - at.x), -(6.0 - at.z)) if at.x > 6.0 else -PI * 0.5
		var steer := clampf(wrapf(scene.kart_body.rotation.y - desired, -PI, PI) * 2.5, -1.0, 1.0)
		scene.joystick.target = Vector2(steer, -1.0)
		await physics_frame
		if scene.kart_body.is_on_floor():
			for gap in _wheel_gaps(scene):
				deepest = minf(deepest, gap)
		if at.x > 40.0 and absf(at.z - 6.0) < 2.6:
			reached = true
			break
	scene.joystick.target = Vector2.ZERO
	scene.joystick.axis = Vector2.ZERO
	_check(reached, "driving straight east from the start reaches the island bridge")
	_check(deepest >= -GAP_LIMIT, "no tyre sinks into the floor while driving (deepest %.3f m)" % deepest)
	scene.run_button.pressed.emit()
	await _frames(40)
	scene.vehicle_button.pressed.emit()
	await _frames(6)
	_check(not scene.driving, "the real exit control parks the kart")


func _slopes(scene: Node) -> void:
	scene.vehicle_button.pressed.emit()
	await _frames(4)
	for spot in SLOPES:
		scene.kart_body.position = spot
		scene.kart_body.rotation.y = 0.4
		await _settle_parked(scene, 90)
		var tag := "hillside %.0f,%.0f" % [spot.x, spot.z]
		_check(scene.kart_body.is_on_floor(), "the kart rests on the " + tag)
		_expect_grounded(scene, tag)
		var tilt := absf(scene.kart_visual.rotation.x) + absf(scene.kart_visual.rotation.z)
		_check(tilt > 0.05, "the kart visual leans with the %s (%.3f rad)" % [tag, tilt])
		_check(scene._save(), "parking on the %s saves" % tag)
	var flat := Vector3(45, 1.0, 6)
	scene.kart_body.position = flat
	scene.kart_body.rotation.y = -PI * 0.5
	await _settle_parked(scene, 90)
	var level := absf(scene.kart_visual.rotation.x) + absf(scene.kart_visual.rotation.z)
	_check(level < 0.02, "on the flat bridge deck the visual returns level (%.3f rad)" % level)


func _decoration(scene: Node) -> void:
	# Push into the compass pedestal from the west and into the right arch
	# pillar from the north; the old southern fixture started inside the
	# adjacent compass pedestal instead of in a clear approach lane.
	var pushes := [[Vector3(-0.8, 0.0, 4.55), -PI * 0.5, "compass pedestal"], [Vector3(2.55, 0.0, -2.0), PI, "welcome arch pillar"]]
	for push in pushes:
		scene.kart_body.position = push[0]
		scene.kart_body.rotation.y = push[1]
		await _settle_parked(scene, 20)
		scene.drive_speed = 0.0
		var start: Vector3 = scene.kart_body.position
		_check(_box_overlaps(scene) == 0, "the approach starts outside solid geometry: " + str(push[2]))
		# Use the same input path as the first-entry journey. Calling _drive_tick
		# manually while the scene also runs physics applied brake and throttle
		# in the same frame and never reproduced the child's actual driving.
		scene.joystick.target = Vector2(0, -1)
		await _frames(150)
		await _settle_parked(scene, 30)
		var moved: float = start.distance_to(scene.kart_body.position)
		_check(moved > 0.3 and moved < 3.0, "the kart drives up to the %s and is stopped by it (%.2f m)" % [push[2], moved])
		_expect_grounded(scene, "against the " + str(push[2]))
	var space: PhysicsDirectSpaceState3D = scene.get_world_3d().direct_space_state
	var probe := PhysicsRayQueryParameters3D.create(Vector3(2.45, 3.0, 4.55), Vector3(2.45, -1.0, 4.55), 0xFFFFFFFF, [scene.kart_body.get_rid(), scene.player.get_rid()])
	var top: Dictionary = space.intersect_ray(probe)
	_check(not top.is_empty() and float(top.position.y) > 1.2, "the compass pedestal is solid up to its top plate")


func _airborne_exit(scene: Node) -> void:
	scene.kart_body.position = Vector3(50, 0.15, 10.5)
	scene.kart_body.rotation.y = -PI * 0.5
	scene.drive_speed = 0.0
	scene.kart_body.velocity = Vector3.ZERO
	scene._drive_tick(Vector2.ZERO, 1.0 / 60.0)
	_check(not scene.kart_body.is_on_floor(), "the kart is falling beside the island bridge")
	_check(scene._safe_vehicle_exit() != null, "an adjacent bridge exit is available to the raycast")
	scene.vehicle_button.pressed.emit()
	_check(scene.driving and not scene.fox.visible, "the exit control keeps Lumo seated until the kart has landed")


func _fall_reset(scene: Node) -> void:
	scene.kart_body.position = Vector3(0, -7.0, 70)
	scene.kart_body.velocity = Vector3.ZERO
	scene._drive_tick(Vector2.ZERO, 1.0 / 60.0)
	var xz := Vector2(scene.kart_body.position.x - STATE.KART_SPAWN.x, scene.kart_body.position.z - STATE.KART_SPAWN.z)
	_check(xz.length() < 0.5, "a fallen kart returns to the Sonnendorf parking place")
	await _settle_parked(scene, 30)
	_expect_grounded(scene, "after the fall reset")
	scene.vehicle_button.pressed.emit()
	await _frames(6)
	_check(not scene.driving, "the child can leave the kart after the fall reset")
	_check(scene._save(), "the reset parking place saves")


## Saves written before the collision box fix rest 0.119 m too low; the old
## first-entry pose floated at 0.2 m. Both must load with tyres on the floor.
func _reenter_with_height(height: float) -> void:
	_write_kart_save(Vector3(STATE.KART_START.x, height, STATE.KART_START.z), STATE.KART_START_YAW)
	var scene = await _enter_world()
	_check(scene != null and not scene.save_blocked, "a save with kart height %.3f opens" % height)
	if scene == null:
		return
	var xz := Vector2(scene.kart_body.position.x - STATE.KART_START.x, scene.kart_body.position.z - STATE.KART_START.z)
	_check(xz.length() < 0.001, "re-entry keeps the saved parking place (height %.3f)" % height)
	_expect_grounded(scene, "re-entry from saved height %.3f" % height)
	_check(absf(scene.model.kart_position.y - scene.kart_body.position.y) < 0.001, "the grounded height replaces the saved height %.3f" % height)


func _reenter_unsupported(pose: Vector3, tag: String) -> void:
	_write_kart_save(pose, 0.0, ["meet_nelli"])
	var scene = await _enter_world()
	_check(scene != null and not scene.save_blocked, "a structurally valid save %s still opens" % tag)
	if scene == null:
		return
	var xz := Vector2(scene.kart_body.position.x - STATE.KART_SPAWN.x, scene.kart_body.position.z - STATE.KART_SPAWN.z)
	_check(xz.length() < 0.001, "unsupported pose %s recovers to the marked parking place" % tag)
	_expect_grounded(scene, "re-entry after an unsupported pose " + tag)
	_check(scene._save(), "the repaired pose saves " + tag)
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(world_path))
	var restored = STATE.new()
	_check(restored.restore(saved) and restored.kart_position.is_equal_approx(scene.kart_body.position),
		"the file contains the repaired kart pose " + tag)
	_check(restored.completed == ["meet_nelli"], "restoring the kart keeps the child's completed mission " + tag)


func _write_kart_save(position: Vector3, yaw: float, completed: Array = []) -> void:
	var data: Dictionary = STATE.new().to_data()
	data.kart = {"position": [position.x, position.y, position.z], "yaw": yaw}
	data.completed = completed
	var file := FileAccess.open(world_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()


func _frames(count: int) -> void:
	for index in range(count):
		await physics_frame
		await process_frame


func _finish() -> void:
	_check(await preload("res://scripts/tests/lumo_scene_teardown.gd").release(self, "[LumoWorldKartGround]"), "production scene and audio playbacks are released")
	print("[LumoWorldKartGround] %s %d checks engine=%s" % ["PASS" if failures.is_empty() else "FAIL", checks, Engine.get_version_info().string])
	quit(0 if failures.is_empty() else 1)
