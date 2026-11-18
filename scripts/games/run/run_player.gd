extends RefCounted
## Lumo's motion in road space. He runs forward on his own, builds up speed and
## is steered freely across the road; this model owns jump, dash and momentum.
## It asks the track for ground, side limits and slope and knows nothing about
## meshes, sound or the HUD.

const TUNING = preload("res://scripts/games/run/run_tuning.gd")
const LOOP = preload("res://scripts/games/kart_physical_loop.gd")

var s: float = 0.0
var previous_s: float = 0.0
var lat: float = 0.0
var lat_v: float = 0.0
var h: float = 0.0
var vy: float = 0.0
var speed: float = 0.0
var grounded: bool = true
var jumping: bool = false
var jump_held: bool = false
var jump_hold: float = 0.0
var jump_buffer: float = 0.0
var coyote: float = 0.0
var ground_rate: float = 0.0
var dash_time: float = 0.0
var dash_cooldown: float = 0.0
var boost_time: float = 0.0
var stumble_time: float = 0.0
var invulnerable: float = 0.0
var land_impact: float = 0.0
var air_time: float = 0.0
## 0..1 while Lumo runs the stunt loop, -1 otherwise.
var loop_u: float = -1.0
var loop: Dictionary = {}
## What happened in the last step: jump, land, dash, loop_start, loop_end.
var events: Array[StringName] = []


func place(distance: float, lateral: float, start_speed: float) -> void:
	s = distance
	previous_s = distance
	lat = lateral
	lat_v = 0.0
	h = 0.0
	vy = 0.0
	speed = start_speed
	grounded = true
	jumping = false
	jump_hold = 0.0
	jump_buffer = 0.0
	coyote = 0.0
	ground_rate = 0.0
	dash_time = 0.0
	boost_time = 0.0
	stumble_time = 0.0
	loop_u = -1.0
	air_time = 0.0


func press_jump() -> void:
	jump_held = true
	jump_buffer = TUNING.JUMP_BUFFER_SECONDS


func release_jump() -> void:
	jump_held = false


func press_dash() -> bool:
	if dash_cooldown > 0.0 or loop_u >= 0.0 or stumble_time > 0.0:
		return false
	dash_time = TUNING.DASH_SECONDS
	dash_cooldown = TUNING.DASH_COOLDOWN
	if not grounded:
		vy = maxf(vy, 2.5)
	events.append(&"dash")
	return true


func release_inputs() -> void:
	jump_held = false
	jump_buffer = 0.0


func bounce(power: float) -> void:
	vy = power
	grounded = false
	jumping = false
	coyote = 0.0
	jump_buffer = 0.0
	air_time = 0.0


func boost(seconds: float) -> bool:
	var fresh: bool = boost_time <= 0.25
	boost_time = maxf(boost_time, seconds)
	return fresh


## A bump: Lumo loses pace for a moment and cannot be bumped again right away.
func stumble() -> bool:
	if invulnerable > 0.0:
		return false
	speed = maxf(TUNING.MIN_SPEED, speed * TUNING.STUMBLE_SPEED_FACTOR)
	stumble_time = TUNING.STUMBLE_SECONDS
	invulnerable = TUNING.INVULNERABLE_SECONDS
	boost_time = 0.0
	dash_time = 0.0
	return true


func respawn(distance: float, lateral: float) -> void:
	var cooldown: float = dash_cooldown
	place(distance, lateral, TUNING.RESPAWN_SPEED)
	dash_cooldown = cooldown
	invulnerable = TUNING.INVULNERABLE_SECONDS + 0.4
	stumble_time = 0.2


func begin_loop(data: Dictionary) -> void:
	loop = data
	loop_u = 0.0
	speed = maxf(speed, TUNING.CRUISE)
	grounded = true
	h = 0.0
	vy = 0.0
	lat_v = 0.0
	dash_time = 0.0
	events.append(&"loop_start")


func step(delta: float, steer: Vector2, track) -> void:
	previous_s = s
	dash_time = maxf(0.0, dash_time - delta)
	dash_cooldown = maxf(0.0, dash_cooldown - delta)
	boost_time = maxf(0.0, boost_time - delta)
	stumble_time = maxf(0.0, stumble_time - delta)
	invulnerable = maxf(0.0, invulnerable - delta)
	jump_buffer = maxf(0.0, jump_buffer - delta)
	land_impact = 0.0
	if loop_u >= 0.0:
		_step_loop(delta)
		return
	_step_speed(delta, steer.y, track)
	s += speed * delta
	if track.wants_loop(previous_s, s, lat):
		begin_loop(track.plan.loop)
		return
	var wish: float = clampf(steer.x, -1.0, 1.0) * TUNING.LATERAL_SPEED
	if stumble_time > 0.0:
		wish *= 0.4
	var grip: float = TUNING.LATERAL_ACCELERATION if grounded else TUNING.AIR_LATERAL_ACCELERATION
	lat_v = move_toward(lat_v, wish, grip * delta)
	var wanted: float = lat + lat_v * delta
	lat = track.confine(s, wanted, lat)
	if absf(lat - wanted) > 0.0005:
		lat_v = 0.0
	_step_vertical(delta, track)


func _step_speed(delta: float, pull_back: float, track) -> void:
	var target: float = TUNING.CRUISE * clampf(
		1.0 - track.grade_at(s) * TUNING.GRADE_GAIN, TUNING.GRADE_MIN, TUNING.GRADE_MAX
	)
	if pull_back > 0.3:
		target *= lerpf(1.0, TUNING.SLOW_FACTOR, clampf((pull_back - 0.3) / 0.6, 0.0, 1.0))
	var burst: bool = false
	if boost_time > 0.0:
		target += TUNING.BOOST_BONUS
		burst = true
	if dash_time > 0.0:
		target += TUNING.DASH_BONUS
		burst = true
	if stumble_time > 0.0:
		target = minf(target, TUNING.CRUISE * 0.45)
	var rate: float = TUNING.DECELERATION
	if speed < target:
		rate = TUNING.BURST_ACCELERATION if burst else TUNING.ACCELERATION
	speed = move_toward(speed, target, rate * delta)


func _step_vertical(delta: float, track) -> void:
	var ground: float = track.ground_at(s, lat, h)
	if grounded:
		if ground < h - 0.3:
			# Ran over a lip or off a platform: keep the upward motion of the ramp.
			grounded = false
			jumping = false
			vy = clampf(ground_rate, 0.0, 8.0)
			coyote = TUNING.COYOTE_SECONDS
			air_time = 0.0
		else:
			ground_rate = clampf((ground - h) / delta, -12.0, 12.0)
			h = ground
			coyote = TUNING.COYOTE_SECONDS
	else:
		coyote = maxf(0.0, coyote - delta)
	if jump_buffer > 0.0 and coyote > 0.0 and stumble_time < TUNING.STUMBLE_SECONDS * 0.5:
		vy = TUNING.JUMP_SPEED + maxf(0.0, ground_rate) * 0.5
		grounded = false
		jumping = true
		jump_hold = 0.0
		jump_buffer = 0.0
		coyote = 0.0
		air_time = 0.0
		events.append(&"jump")
	if grounded:
		return
	air_time += delta
	if jumping:
		if jump_held:
			jump_hold += delta
		elif vy > TUNING.JUMP_CUT_SPEED:
			vy = TUNING.JUMP_CUT_SPEED
	var gravity: float = TUNING.GRAVITY_FALL
	if vy > 0.0:
		var holding: bool = jumping and jump_held and jump_hold < TUNING.JUMP_HOLD_SECONDS
		gravity = TUNING.GRAVITY_HOLD if holding else TUNING.GRAVITY_RISE
	vy -= gravity * delta
	if dash_time > 0.0:
		vy = maxf(vy, -2.0)
	var before: float = h
	h += vy * delta
	ground = track.ground_at(s, lat, before)
	# Only a surface Lumo comes down onto catches him; below the deck he keeps falling.
	if vy <= 0.0 and h <= ground and before >= ground - 0.5:
		land_impact = -vy
		h = ground
		vy = 0.0
		grounded = true
		jumping = false
		ground_rate = 0.0
		coyote = TUNING.COYOTE_SECONDS
		events.append(&"land")


func _step_loop(delta: float) -> void:
	var layout: Dictionary = loop.layout
	speed = move_toward(speed, TUNING.CRUISE + 2.0, TUNING.ACCELERATION * delta)
	loop_u += speed * delta / LOOP.path_length(layout)
	var u: float = clampf(loop_u, 0.0, 1.0)
	s = float(loop.start) + (float(loop.exit_s) - float(loop.start)) * u
	lat = float(loop.lane) + LOOP.exit_shift_of(layout) * LOOP.shift_fraction(u)
	if loop_u >= 1.0:
		loop_u = -1.0
		s = float(loop.exit_s) + 0.3
		lat = float(loop.exit_lane)
		h = 0.0
		vy = 0.0
		grounded = true
		invulnerable = maxf(invulnerable, 0.6)
		events.append(&"loop_end")


## Position on the stunt loop while `loop_u` runs from 0 to 1.
func loop_transform(world) -> Transform3D:
	var layout: Dictionary = loop.layout
	var u: float = clampf(loop_u, 0.0, 1.0)
	return Transform3D(LOOP.frame_at(world, layout, u), LOOP.point(world, layout, u))


func is_dashing() -> bool:
	return dash_time > 0.0
