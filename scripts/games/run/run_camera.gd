extends Camera3D
## Chase camera behind Lumo. It lives in road space as well: it sits above the
## road a few metres behind him and looks ahead along the course, so it follows
## every bend and climb without ever dipping into the terrain or losing him.

const TUNING = preload("res://scripts/games/run/run_tuning.gd")

var reduced_motion: bool = false
var _look := Vector3.ZERO
var _ready_to_follow: bool = false
var _lag: float = 0.0
var _shake: float = 0.0
var _front: float = 0.0
## Set by the game while the stone ball rolls: the camera rises and pulls back
## so the ball is seen right behind Lumo.
var chase_view: bool = false


func kick(strength: float) -> void:
	if not reduced_motion:
		_shake = maxf(_shake, strength)


## Turns the camera to Lumo's front for the result screen.
func show_front() -> void:
	_front = 1.0


func follow(world, player, feet: Vector3, delta: float, snap: bool = false) -> void:
	var view: Vector2 = get_viewport().get_visible_rect().size
	var portrait: bool = view.y > view.x * 1.15
	var pace: float = clampf((player.speed - TUNING.CRUISE) / (TUNING.BOOST_BONUS + TUNING.DASH_BONUS), -0.6, 1.0)
	if reduced_motion:
		pace = 0.0
	# High enough to see the star line on the road over Lumo's ears.
	var back: float = (6.6 if portrait else 5.6) + pace * 1.1
	var height: float = (4.4 if portrait else 3.7) + pace * 0.2
	var path: bool = world.has_method("ceiling_at")
	var ahead: float = 16.0 if portrait else 13.0
	var swing: float = 0.0
	if path:
		# Closer behind Lumo on the narrow path; nearer still in tight passages.
		var half: float = float(world.half_width_at(player.s))
		var tight: float = clampf((2.4 - half) / 1.0, 0.0, 1.0)
		back = (5.9 if portrait else 5.0) - tight * 0.7 + pace * 0.8
		height = (3.7 if portrait else 2.9) - tight * 0.25
		ahead = 11.0 if portrait else 9.5
		if player.in_cart or player.is_riding():
			back += 1.2
			height += 0.5
		if chase_view:
			back = 14.0 if portrait else 13.0
			height = 6.0 if portrait else 5.0
			ahead = 6.0
		if (player.in_cart or player.tumble_time > 0.0) and not reduced_motion:
			swing = sin(Time.get_ticks_msec() * 0.0011) * 0.9
	var wall: float = float(world.wall_lateral_at(player.s)) - 0.6
	var desired: Vector3
	var look: Vector3
	if player.loop_u >= 0.0:
		# Side view through the open ring, as in Lumo Kart: Lumo stays visible on
		# the inner deck all the way round, also upside down at the top.
		var start: float = float(player.loop.start)
		var lane: float = float(player.loop.lane)
		var radius: float = float(player.loop.layout.get("radius", 6.5))
		var basis: Basis = world.frame(start)
		var hub: Vector3 = (
			world.position_at(
				(start + float(player.loop.exit_s)) * 0.5, (lane + float(player.loop.exit_lane)) * 0.5
			)
			+ basis.y * radius
		)
		desired = hub - basis.x * radius * 2.7 + basis.z * radius * 0.45 - basis.y * radius * 0.15
		look = (feet + Vector3.UP * 0.9).lerp(hub, 0.35)
	elif _front > 0.0:
		desired = world.position_at(player.s + 5.6, clampf(player.lat + 2.2, -wall, wall)) + Vector3.UP * 2.0
		# Leave room for the result card: Lumo stands in the free part of the screen.
		var side: Vector3 = Vector3.UP.cross(desired - feet).normalized()
		look = feet + Vector3.UP * (-1.5 if portrait else 1.1) + side * (0.0 if portrait else 3.1)
	else:
		var above: float = maxf(0.0, player.h)
		var follow_s: float = player.s
		if path and player.s >= 0.0 and player.s - back < 0.0:
			follow_s = back
		desired = (
			world.position_at(follow_s - back, clampf(player.lat * 0.72 + swing, -wall - 0.4, wall + 0.4))
			+ Vector3.UP * (height + above * 0.5)
		)
		# Behind a crest the road falls away: never sink below Lumo's shoulders.
		desired.y = maxf(desired.y, feet.y + 2.6)
		desired = world.clip_tunnel_camera(feet + Vector3.UP, desired)
		if path:
			var roof: float = float(world.ceiling_at(player.s - back))
			if roof < 100.0:
				desired.y = minf(desired.y, world.position_at(player.s - back).y + roof - 1.0)
				desired.y = maxf(desired.y, feet.y + 1.6)
		look = (
			world.position_at(player.s + ahead, player.lat * 0.5)
			+ Vector3.UP * (1.0 + above * 0.4)
		)
		if path and not player.grounded and player.vy > 4.0:
			# A big bounce: look up a little to show where Lumo is going.
			look += Vector3.UP * clampf(player.vy * 0.15, 0.0, 2.0)
		# Keep Lumo himself in the lower middle of the picture on steep ground.
		look.y = clampf(look.y, feet.y - 2.0, feet.y + 4.5)
	if snap or not _ready_to_follow or reduced_motion and _front > 0.0:
		global_position = desired
		_look = look
		_ready_to_follow = true
	else:
		var follow_rate: float = 4.0 if (player.loop_u >= 0.0 or _front > 0.0) else 11.0
		global_position = global_position.lerp(desired, 1.0 - exp(-follow_rate * delta))
		# The lag gives the feeling of speed; it is bounded so Lumo never leaves the frame.
		var offset: Vector3 = global_position - desired
		_lag = offset.length()
		if _lag > 2.6 and _front <= 0.0 and player.loop_u < 0.0:
			global_position = desired + offset * (2.6 / _lag)
		_look = _look.lerp(look, 1.0 - exp(-10.0 * delta))
	var eye: Vector3 = global_position
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 3.5)
		eye += Vector3(sin(_shake * 61.0), cos(_shake * 47.0), 0.0) * _shake * 0.12
	if eye.distance_squared_to(_look) > 0.01:
		look_at_from_position(eye, _look, Vector3.UP)
	var base_fov: float = 80.0 if portrait else 64.0
	var target_fov: float = base_fov + maxf(0.0, pace) * 10.0
	fov = target_fov if snap else lerpf(fov, target_fov, 1.0 - exp(-5.0 * delta))
