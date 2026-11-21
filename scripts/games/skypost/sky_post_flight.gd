extends RefCounted
## Lumo's glider as motion only: always flies forward, climbs and dives with the
## stick, banks into turns, trades height for speed and back, rides updrafts and
## can never crash (islands, buildings and the cloud cushion push it back softly).
## The child steers with one thumb; SCHWUNG gives a short burst of speed.

const TUNING = preload("res://scripts/games/skypost/sky_post_tuning.gd")

var layout
var stage: String = "entdecken"
var pos := Vector3.ZERO
## Heading around Y; 0 looks along -Z. Turning right lowers it.
var yaw: float = 0.0
## Flight path angle; positive climbs.
var pitch: float = 0.0
var bank: float = 0.0
var speed: float = 0.0
var rise: float = 0.0
var yaw_rate: float = 0.0
var cruise: float = 14.0
var boost_time: float = 0.0
var boost_cooldown: float = 0.0
var launch_left: float = 0.0
var launch_from := Vector3.ZERO
var clock: float = 0.0
var lift_now: float = 0.0
var velocity := Vector3.ZERO
var bump_cooldown: float = 0.0
## Goal for the Entdecken assist (null when none).
var assist_target: Variant = null
var events: Array[Dictionary] = []
## Last stick (x right, y up) as applied this step, for the visuals.
var input := Vector2.ZERO


func setup(world_layout, stage_id: String) -> void:
	layout = world_layout
	stage = stage_id
	cruise = float(TUNING.CRUISE.get(stage, 14.0))


func place(at: Vector3, heading: float, start_speed: float) -> void:
	pos = at
	yaw = heading
	pitch = 0.0
	bank = 0.0
	rise = 0.0
	yaw_rate = 0.0
	speed = start_speed
	boost_time = 0.0
	velocity = forward() * speed


## Rolls along the post office deck first, then lifts off.
func begin_launch(at: Vector3, heading: float) -> void:
	place(at, heading, 0.0)
	launch_from = at
	launch_left = TUNING.LAUNCH_SECONDS


func forward() -> Vector3:
	return Vector3(-sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch))


func flat_forward() -> Vector3:
	return Vector3(-sin(yaw), 0, -cos(yaw))


func basis() -> Basis:
	return Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch) * Basis(Vector3.BACK, bank)


func transform() -> Transform3D:
	return Transform3D(basis(), pos)


func press_boost() -> bool:
	if boost_cooldown > 0.0 or launch_left > 0.0:
		return false
	boost_time = TUNING.BOOST_SECONDS
	boost_cooldown = TUNING.BOOST_COOLDOWN
	events.append({"type": "boost"})
	return true


## Ring boosts do not use the button's cooldown.
func ring_boost() -> void:
	boost_time = maxf(boost_time, TUNING.RING_BOOST_SECONDS)


## One step. [param stick]: x right, y up (both -1..1).
func step(delta: float, stick: Vector2) -> void:
	clock += delta
	bump_cooldown = maxf(0.0, bump_cooldown - delta)
	boost_cooldown = maxf(0.0, boost_cooldown - delta)
	if launch_left > 0.0:
		_launch(delta)
		return
	input = stick.limit_length(1.0)
	var steer: float = input.x
	var assist_strength: float = float(TUNING.ASSIST.get(stage, 0.0))
	if assist_strength > 0.0 and assist_target is Vector3 and absf(steer) < 0.15:
		var to: Vector3 = (assist_target as Vector3) - pos
		var wanted: float = atan2(-to.x, -to.z)
		var error: float = wrapf(wanted - yaw, -PI, PI)
		steer = clampf(-error * 1.4, -1.0, 1.0) * assist_strength
	# Turning: the rate follows the stick, the glider banks with it.
	var target_rate: float = -steer * TUNING.TURN_RATE
	yaw_rate = lerpf(yaw_rate, target_rate, 1.0 - exp(-4.5 * delta))
	yaw = wrapf(yaw + yaw_rate * delta, -PI, PI)
	var bank_target: float = -steer * TUNING.BANK_ANGLE
	bank = lerpf(bank, bank_target, 1.0 - exp(-5.0 * delta))
	var pitch_target: float = input.y * TUNING.CLIMB_ANGLE
	pitch = lerpf(pitch, pitch_target, 1.0 - exp(-2.8 * delta))
	# Height for speed: diving speeds up, climbing slows down; cruise returns.
	speed += -sin(pitch) * TUNING.GRAVITY_PULL * delta
	speed += (cruise - speed) * TUNING.SPEED_RETURN * delta
	if boost_time > 0.0:
		boost_time -= delta
		speed = minf(speed + TUNING.BOOST_SPEED * 3.0 * delta, cruise + TUNING.BOOST_SPEED)
	speed = clampf(speed, TUNING.MIN_SPEED, TUNING.MAX_SPEED)
	# Updrafts carry the glider up and give a little speed.
	lift_now = layout.updraft_lift(pos) if layout != null else 0.0
	rise = lerpf(rise, lift_now * TUNING.UPDRAFT_RISE, 1.0 - exp(-2.2 * delta))
	if lift_now > 0.05:
		speed = minf(speed + lift_now * 1.5 * delta, TUNING.MAX_SPEED)
	var wind := Vector3.ZERO
	var gust: float = float(TUNING.GUST.get(stage, 0.0))
	if gust > 0.0:
		wind = (
			Vector3(sin(clock * 0.37) + 0.4 * sin(clock * 1.3), 0, cos(clock * 0.29)) * gust * 0.6
		)
	velocity = forward() * speed + Vector3(0, rise, 0) + wind
	pos += velocity * delta
	_collide()


func _launch(delta: float) -> void:
	launch_left = maxf(0.0, launch_left - delta)
	var done: float = 1.0 - launch_left / TUNING.LAUNCH_SECONDS
	speed = cruise * clampf(done * 1.1, 0.0, 1.0)
	pitch = lerpf(0.0, 0.12, smoothstep(0.6, 1.0, done))
	velocity = forward() * speed
	pos += velocity * delta
	if launch_left <= 0.0:
		events.append({"type": "liftoff"})


func _collide() -> void:
	if layout == null:
		return
	var result: Dictionary = layout.resolve(pos)
	var kind: String = str(result.kind)
	if kind.is_empty():
		return
	pos = result.pos
	var normal: Vector3 = result.normal
	match kind:
		"cushion":
			pitch = maxf(pitch, 0.32)
			rise = maxf(rise, 7.0)
			_event("cushion")
		"ceiling":
			pitch = minf(pitch, -0.05)
		"wall":
			# Turn back towards Wolkenhafen.
			var inward: float = atan2(-normal.x, -normal.z)
			yaw = lerp_angle(yaw, inward, 0.08)
			_event("wall")
		_:
			if normal == Vector3.UP:
				pitch = maxf(pitch, 0.12)
				rise = maxf(rise, 3.0)
			else:
				# Slide along the obstacle: the heading turns away from it.
				var away: float = atan2(-normal.x, -normal.z)
				var along: float = wrapf(away - yaw, -PI, PI)
				yaw = wrapf(yaw + clampf(along, -0.5, 0.5) * 0.35, -PI, PI)
				speed = maxf(TUNING.MIN_SPEED, speed * 0.97)
			_event("bump")


func _event(kind: String) -> void:
	if bump_cooldown > 0.0:
		return
	bump_cooldown = 0.8
	events.append({"type": kind})


func snapshot() -> Dictionary:
	return {"pos": pos, "yaw": yaw}


# ------------------------------------------------------------------ autopilot (tests, demo)


## Stick values that steer towards [param target]. Used by the flight bot.
func steer_towards(target: Vector3, climb_gain: float = 0.12) -> Vector2:
	var to: Vector3 = target - pos
	var wanted: float = atan2(-to.x, -to.z)
	var error: float = wrapf(wanted - yaw, -PI, PI)
	var horizontal: float = Vector2(to.x, to.z).length()
	var climb: float = clampf((to.y - horizontal * tan(pitch) * 0.0) * climb_gain, -1.0, 1.0)
	return Vector2(clampf(-error * 2.2, -1.0, 1.0), climb)
