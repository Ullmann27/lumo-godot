extends SceneTree
## Measures Lumo foot sliding in the real 3D Jump scene with CharacterBody
## physics input (no teleports). A foot counts as planted when its lowest
## point is on the ground plane recorded while Lumo stands still. Slip ratio =
## horizontal travel of planted feet / body travel in the same frames.
## Without a gait both rigid legs stay "planted" and glide: ratio ~ 1.0.
## Set LUMO_GAIT_BASELINE=1 to only print metrics (for measuring old builds).

const PLANT_TOLERANCE: float = 0.015
const SETTLE_FRAMES: int = 30  # skip acceleration


func _initialize() -> void:
	call_deferred("_run")


func _legs(node: Node, out: Array) -> void:
	for child in node.get_children():
		if child.name in ["LegLeft", "LegRight"]:
			out.append(child)
		_legs(child, out)


func _foot(leg: Node3D) -> Vector3:
	return leg.global_transform * Vector3(0.0, -0.275, 0.0)


func _measure(game: Node, direction: Vector2, frames: int) -> Dictionary:
	var legs: Array = []
	_legs(game.actor, legs)
	var samples: Array = []
	game.touch_direction = direction
	for frame in range(frames):
		await physics_frame
		(
			samples
			. append(
				{
					"body": game.actor.global_position,
					"feet": [_foot(legs[0]), _foot(legs[1])],
					"floor": game.actor.is_on_floor(),
				}
			)
		)
	game.touch_direction = Vector2.ZERO
	# Ground plane = lowest foot point seen while moving on the floor.
	var ground: float = INF
	for sample in samples:
		for foot in sample.feet:
			ground = minf(ground, foot.y)
	var planted_travel: float = 0.0
	var planted_body: float = 0.0
	var planted_frames: int = 0
	for f in range(SETTLE_FRAMES, samples.size()):
		var a: Dictionary = samples[f - 1]
		var b: Dictionary = samples[f]
		if not (a.floor and b.floor):
			continue
		var body_step: float = Vector2(b.body.x - a.body.x, b.body.z - a.body.z).length()
		for i in range(2):
			var p: Vector3 = a.feet[i]
			var q: Vector3 = b.feet[i]
			if p.y - ground <= PLANT_TOLERANCE and q.y - ground <= PLANT_TOLERANCE:
				planted_travel += Vector2(q.x - p.x, q.z - p.z).length()
				planted_body += body_step
				planted_frames += 1
	var first: Vector3 = samples[SETTLE_FRAMES].body
	var last: Vector3 = samples[-1].body
	var seconds: float = (samples.size() - SETTLE_FRAMES) / float(Engine.physics_ticks_per_second)
	return {
		"ratio": planted_travel / maxf(planted_body, 0.0001),
		"planted_frames": planted_frames,
		"speed": Vector2(last.x - first.x, last.z - first.z).length() / seconds,
	}


func _run() -> void:
	var baseline: bool = OS.get_environment("LUMO_GAIT_BASELINE") == "1"
	DirAccess.remove_absolute("user://jump_session.cfg")
	root.get_node("SceneRouter").launch_options = {"grade": 2, "subject": "Mathematik"}
	var game: Node = load("res://scenes/games/jump_islands.tscn").instantiate()
	root.add_child(game)
	for frame in range(40):
		await physics_frame
	assert(game.actor.is_on_floor())
	var legs: Array = []
	_legs(game.actor, legs)
	assert(legs.size() == 2, "Lumo legs must exist")
	# Long flat test strip (real collider) far from the islands, so walking
	# and running can be measured for seconds without reaching an edge.
	var strip := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(200, 0.5, 8)
	strip.add_child(shape)
	strip.position = Vector3(300, 20, 0)
	game.add_child(strip)
	game.actor.position = strip.position + Vector3(-80, 0.4, 0)
	game.actor.velocity = Vector3.ZERO
	for frame in range(40):
		await physics_frame
	assert(game.actor.is_on_floor())
	var floor_y: float = strip.position.y + 0.25
	var rest_foot: float = minf(_foot(legs[0]).y, _foot(legs[1]).y)
	print("[LumoGait] rest foot height above floor=%.3f m" % (rest_foot - floor_y))
	if not baseline:
		assert(absf(rest_foot - floor_y) < 0.03, "feet must stand on the floor, not be buried")
	var walk: Dictionary = await _measure(game, Vector2(0.35, 0.0), 150)
	var run: Dictionary = await _measure(game, Vector2(1.0, 0.0), 150)
	print(
		(
			"[LumoGait] walk speed=%.2f m/s slip_ratio=%.3f planted_frames=%d"
			% [walk.speed, walk.ratio, walk.planted_frames]
		)
	)
	print(
		(
			"[LumoGait] run  speed=%.2f m/s slip_ratio=%.3f planted_frames=%d"
			% [run.speed, run.ratio, run.planted_frames]
		)
	)
	if baseline:
		print("[LumoGait] baseline mode: metrics only")
		quit(0)
		return
	var gait = game.gait
	assert(
		walk.planted_frames > 40 and run.planted_frames > 20,
		"feet must touch the ground while moving"
	)
	assert(walk.ratio < 0.08, "walk foot slip ratio %.3f too high" % walk.ratio)
	assert(run.ratio < 0.08, "run foot slip ratio %.3f too high" % run.ratio)
	# Cadence follows speed: running has longer strides and shorter contact.
	assert(walk.speed < 2.5 and run.speed > 4.5)
	# Standing still: legs return to rest, idle bounce resumes.
	for frame in range(90):
		await physics_frame
	assert(not gait.moving)
	assert(
		absf(gait.hips[0].rotation.x) < 0.03 and absf(gait.hips[1].rotation.x) < 0.03,
		"legs settle when idle"
	)
	var behavior: Node = (
		game.actor.get_node("LumoCharacter/BehaviorController")
		if game.actor.has_node("LumoCharacter/BehaviorController")
		else null
	)
	if behavior == null:
		for child in game.actor.get_children():
			if child.has_node("BehaviorController"):
				behavior = child.get_node("BehaviorController")
	assert(behavior.get_current_behavior() == "idle_bounce")
	# Teleport (respawn) must not advance the stride.
	var phase_before: float = gait.phase
	game.actor.position = strip.position + Vector3(40, 0.4, 0)
	await physics_frame
	assert(absf(gait.phase - phase_before) < 0.02, "teleport must not spin the legs")
	# Jump: airborne tuck pose.
	for frame in range(30):
		await physics_frame
	game.jump_buffer = 0.15
	for frame in range(8):
		await physics_frame
	assert(gait.airborne and gait.legs[0].scale.y < 0.9, "airborne tuck")
	print("[LumoGait] PASS walk/run foot planting, idle settle, teleport, airborne")
	quit(0)
