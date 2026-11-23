extends RefCounted
## Lumo's motion in road space. He runs forward on his own, builds up speed and
## is steered freely across the road; this model owns jump, dash and momentum.
## On the adventure path he can also stop, dash once in the air, ride barrels,
## vines and zip lines, sit in the mine cart and tumble after a bump.
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
## Feel of the course: the kart roads use the defaults, the adventure path its own.
var cruise: float = TUNING.CRUISE
var lateral_speed: float = TUNING.LATERAL_SPEED
var slow_factor: float = TUNING.SLOW_FACTOR
var air_dash: bool = false
var air_dash_ready: bool = true
## Momentum 0..1 (path only): builds while Lumo runs on freely, adds flow_bonus.
var flow: float = 0.0
var flow_bonus: float = 0.0
## Second flow stage 0..1 (path only): builds after flow is full, see run_tuning.
var flow2: float = 0.0
var acceleration: float = TUNING.ACCELERATION
var coyote_window: float = TUNING.COYOTE_SECONDS * TUNING.ROAD_TIME_SCALE
var buffer_window: float = TUNING.JUMP_BUFFER_SECONDS * TUNING.ROAD_TIME_SCALE
## A barrel, vine, zip line or warp Lumo is riding (empty when he runs).
var ride: Dictionary = {}
var ride_index: int = -1
var ride_t: float = 0.0
var ride_fired: bool = false
var in_cart: bool = false
var cart_lat: float = 0.0
## Short somersault after a bump; when it ends the track sets Lumo back.
var tumble_time: float = 0.0
var tumbled: bool = false
## What happened in the last step: jump, land, dash, air_dash, loop_start, loop_end,
## ride_barrel, ride_vine, ride_zip, ride_warp, shoot, warp, ride_end.
var events: Array[StringName] = []


func use_path_feel() -> void:
	cruise = TUNING.PATH_CRUISE
	lateral_speed = TUNING.PATH_LATERAL_SPEED
	slow_factor = TUNING.PATH_SLOW_FACTOR
	air_dash = true
	flow_bonus = TUNING.PATH_FLOW_BONUS
	acceleration = TUNING.PATH_ACCELERATION
	coyote_window = TUNING.PATH_COYOTE_SECONDS
	buffer_window = TUNING.PATH_JUMP_BUFFER_SECONDS


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
	air_dash_ready = true
	ride = {}
	ride_index = -1
	tumble_time = 0.0
	tumbled = false
	flow = 0.0
	flow2 = 0.0


func press_jump() -> void:
	jump_held = true
	jump_buffer = buffer_window


func release_jump() -> void:
	jump_held = false


func press_dash() -> bool:
	if dash_cooldown > 0.0 or loop_u >= 0.0 or stumble_time > 0.0 or is_riding() or tumble_time > 0.0:
		return false
	if not grounded and air_dash:
		if not air_dash_ready:
			return false
		air_dash_ready = false
		vy = maxf(vy, TUNING.AIR_DASH_LIFT)
		dash_time = TUNING.DASH_SECONDS
		dash_cooldown = TUNING.DASH_COOLDOWN * 0.5
		events.append(&"air_dash")
		return true
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
	air_dash_ready = true


func boost(seconds: float) -> bool:
	var fresh: bool = boost_time <= 0.25
	boost_time = maxf(boost_time, seconds)
	return fresh


## A bump: Lumo loses pace for a moment and cannot be bumped again right away.
func stumble() -> bool:
	if invulnerable > 0.0:
		return false
	speed = maxf(TUNING.MIN_SPEED if not air_dash else 2.0, speed * TUNING.STUMBLE_SPEED_FACTOR)
	stumble_time = TUNING.STUMBLE_SECONDS
	invulnerable = TUNING.INVULNERABLE_SECONDS
	boost_time = 0.0
	dash_time = 0.0
	flow = 0.0
	flow2 = 0.0
	return true


## Touched by an enemy: a short somersault backwards, then back to the rescue point.
func tumble() -> bool:
	if invulnerable > 0.0 or tumble_time > 0.0 or is_riding():
		return false
	tumble_time = TUNING.TUMBLE_SECONDS
	tumbled = true
	flow = 0.0
	flow2 = 0.0
	vy = 6.0
	grounded = false
	jumping = false
	speed = -2.5
	dash_time = 0.0
	boost_time = 0.0
	release_inputs()
	events.append(&"tumble")
	return true


func respawn(distance: float, lateral: float) -> void:
	var cooldown: float = dash_cooldown
	place(distance, lateral, TUNING.RESPAWN_SPEED if not air_dash else 3.0)
	dash_cooldown = cooldown
	invulnerable = TUNING.INVULNERABLE_SECONDS + 0.4
	stumble_time = 0.2


func begin_loop(data: Dictionary) -> void:
	loop = data
	loop_u = 0.0
	speed = maxf(speed, cruise)
	grounded = true
	h = 0.0
	vy = 0.0
	lat_v = 0.0
	dash_time = 0.0
	events.append(&"loop_start")


func is_riding() -> bool:
	return not ride.is_empty()


func begin_ride(index: int, data: Dictionary) -> void:
	ride = data
	ride_index = index
	ride_t = 0.0
	ride_fired = false
	grounded = false
	jumping = false
	vy = 0.0
	lat_v = 0.0
	dash_time = 0.0
	stumble_time = 0.0
	jump_buffer = 0.0
	events.append(StringName("ride_" + str(data.kind)))


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
	if is_riding():
		_step_ride(delta)
		return
	if tumble_time > 0.0:
		_step_tumble(delta, track)
		return
	_step_speed(delta, steer.y, track)
	s += speed * delta
	if track.wants_loop(previous_s, s, lat):
		begin_loop(track.plan.loop)
		return
	var wish: float = clampf(steer.x, -1.0, 1.0) * lateral_speed
	if stumble_time > 0.0:
		wish *= 0.4
	var grip: float = TUNING.LATERAL_ACCELERATION if grounded else TUNING.AIR_LATERAL_ACCELERATION
	lat_v = move_toward(lat_v, wish, grip * delta)
	var wanted: float = lat + lat_v * delta
	if in_cart:
		wanted = move_toward(lat, cart_lat, 6.0 * delta)
		lat_v = 0.0
	lat = track.confine(s, wanted, lat)
	if absf(lat - wanted) > 0.0005:
		lat_v = 0.0
	_step_vertical(delta, track)


func _step_speed(delta: float, pull_back: float, track) -> void:
	var target: float = cruise * clampf(
		1.0 - track.grade_at(s) * TUNING.GRADE_GAIN, TUNING.GRADE_MIN, TUNING.GRADE_MAX
	)
	if pull_back > 0.3 and not in_cart:
		target *= lerpf(1.0, slow_factor, clampf((pull_back - 0.3) / 0.6, 0.0, 1.0))
	var burst: bool = false
	if boost_time > 0.0:
		target += TUNING.BOOST_BONUS
		burst = true
	if dash_time > 0.0:
		target += TUNING.DASH_BONUS
		burst = true
	# Momentum: running on freely builds flow (a sprint); braking or a bump loses it.
	if flow_bonus > 0.0:
		var free_run: bool = grounded and pull_back <= 0.3 and stumble_time <= 0.0 and not in_cart and speed >= cruise * 0.85
		var stage_two: bool = track.flow_cap(s) >= 2 if track.has_method("flow_cap") else true
		if free_run:
			flow = minf(1.0, flow + delta / TUNING.PATH_FLOW_SECONDS)
			if flow >= 1.0 and stage_two:
				flow2 = minf(1.0, flow2 + delta / TUNING.PATH_FLOW2_SECONDS)
		elif pull_back > 0.3 or stumble_time > 0.0:
			flow = maxf(0.0, flow - delta * 2.5)
			flow2 = 0.0
		if not stage_two:
			# Before a precise spot the top stage pauses (it comes back right after).
			flow2 = maxf(0.0, flow2 - delta * 1.5)
		target += flow * flow_bonus + flow2 * TUNING.PATH_FLOW2_BONUS
	if stumble_time > 0.0:
		target = minf(target, cruise * 0.45)
	if in_cart:
		target = TUNING.CART_SPEED
	if grounded:
		target = minf(target, track.speed_cap(s, lat))
	var rate: float = TUNING.DECELERATION if not air_dash else TUNING.DECELERATION * 3.0
	if speed < target:
		rate = TUNING.BURST_ACCELERATION if burst else acceleration
	speed = move_toward(speed, target, rate * delta)


func _step_vertical(delta: float, track) -> void:
	var ground: float = track.ground_at(s, lat, h)
	if grounded:
		if ground < h - 0.3:
			# Ran over a lip or off a platform: keep the upward motion of the ramp.
			grounded = false
			jumping = false
			vy = clampf(ground_rate, 0.0, 8.0)
			coyote = coyote_window
			air_time = 0.0
		else:
			ground_rate = clampf((ground - h) / delta, -12.0, 12.0)
			h = ground
			coyote = coyote_window
	else:
		coyote = maxf(0.0, coyote - delta)
	if jump_buffer > 0.0 and coyote > 0.0 and stumble_time < TUNING.STUMBLE_SECONDS * 0.5:
		vy = TUNING.JUMP_SPEED + maxf(0.0, ground_rate) * 0.5
		if air_dash and track.speed_cap(s, lat) < cruise:
			# Waiting at the edge in the introduction: the jump takes him across.
			speed = cruise
		grounded = false
		jumping = true
		jump_hold = 0.0
		jump_buffer = 0.0
		coyote = 0.0
		air_time = 0.0
		air_dash_ready = true
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
		coyote = coyote_window
		air_dash_ready = true
		events.append(&"land")


func _step_tumble(delta: float, track) -> void:
	tumble_time = maxf(0.0, tumble_time - delta)
	s += speed * delta
	speed = move_toward(speed, 0.0, 4.0 * delta)
	vy -= TUNING.GRAVITY_FALL * delta
	h += vy * delta
	var ground: float = track.ground_at(s, lat, h + 0.5)
	if h <= ground:
		h = ground
		vy = 0.0
		grounded = true
	if is_inf(ground) and h < -TUNING.FALL_DEPTH:
		h = -TUNING.FALL_DEPTH


func _step_ride(delta: float) -> void:
	ride_t += delta
	invulnerable = maxf(invulnerable, 0.3)
	var before := Vector2(s, h)
	match str(ride.kind):
		"barrel", "warp":
			if not ride_fired:
				s = float(ride.s)
				lat = float(ride.lat)
				h = float(ride.h) - TUNING.BODY_CENTRE
				speed = 0.0
				var wait: float = float(ride.get("wait", 0.8))
				if ride_t >= wait or (jump_buffer > 0.0 and ride_t >= 0.3):
					ride_fired = true
					ride_t = 0.0
					jump_buffer = 0.0
					events.append(&"shoot")
				return
			if str(ride.kind) == "warp":
				h += 22.0 * delta
				if ride_t >= 0.45:
					s = float(ride.ts)
					lat = float(ride.tlat)
					h = float(ride.th) + 0.6
					speed = cruise * 0.6
					events.append(&"warp")
					_end_ride(-1.0)
				return
			var u: float = clampf(ride_t / float(ride.time), 0.0, 1.0)
			s = lerpf(float(ride.s), float(ride.ts), u)
			lat = lerpf(float(ride.lat), float(ride.tlat), u)
			h = lerpf(float(ride.h), float(ride.th), u) + float(ride.arc) * 4.0 * u * (1.0 - u) - TUNING.BODY_CENTRE
			speed = (float(ride.ts) - float(ride.s)) / float(ride.time)
			if u >= 1.0:
				speed = cruise
				_end_ride(-1.0)
		"vine":
			var total: float = float(ride.time)
			var u: float = clampf(ride_t / total, 0.0, 1.0)
			var angle: float = lerpf(float(ride.a0), float(ride.a1), 0.5 - 0.5 * cos(PI * u))
			var rope: float = float(ride.rope)
			s = float(ride.ps) + rope * sin(angle)
			h = float(ride.ph) - rope * cos(angle) - TUNING.BODY_CENTRE - 0.9
			lat = float(ride.lat)
			speed = (s - before.x) / maxf(delta, 0.0001)
			var early: bool = jump_buffer > 0.0 and angle > 0.2
			if u >= 1.0 or early:
				speed = maxf(cruise, speed)
				_end_ride(clampf((h - before.y) / maxf(delta, 0.0001), 2.0, 7.0) + 2.0)
		"zip":
			var span: float = float(ride.ts) - float(ride.s)
			var u: float = clampf(ride_t * float(ride.speed) / span, 0.0, 1.0)
			s = float(ride.s) + span * u
			lat = float(ride.lat)
			h = lerpf(float(ride.h), float(ride.th), u) - float(ride.sag) * 4.0 * u * (1.0 - u) - 1.6
			speed = float(ride.speed)
			if u >= 1.0 or (jump_buffer > 0.0 and u > 0.25):
				speed = cruise
				_end_ride(4.0)


func _end_ride(release_vy: float) -> void:
	ride = {}
	grounded = false
	jumping = false
	vy = release_vy
	coyote = 0.0
	air_time = 0.0
	air_dash_ready = true
	jump_buffer = 0.0
	invulnerable = maxf(invulnerable, 0.5)
	events.append(&"ride_end")


func _step_loop(delta: float) -> void:
	var layout: Dictionary = loop.layout
	speed = move_toward(speed, TUNING.CRUISE + 2.0, TUNING.ACCELERATION * delta)
	loop_u += speed * delta / LOOP.path_length(layout)
	var u: float = clampf(loop_u, 0.0, 1.0)
	# Follow the same physical road-space geometry as the rendered Kart loop,
	# including the exterior approach and its return (not a seven-metre hop).
	s = LOOP.road_distance_at(layout, u)
	lat = LOOP.lane_at(layout, u)
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
