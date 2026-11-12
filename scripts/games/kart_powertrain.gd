extends RefCounted
## Shared straight-line drivetrain used by the race and the workshop simulation.
## Workshop figures use Abenteuer difficulty, level asphalt, no items or rivals.
## A single pace scale is shared by the physical drive and the workshop. Lateral
## response scales linearly; acceleration/braking scale quadratically so doubling
## road speed does not double turning radius or quadruple the braking distance.
const PACE_SCALE: float = 2.0
const DYNAMICS_SCALE: float = PACE_SCALE * PACE_SCALE


static func top_speed(factors: Dictionary, difficulty_speed: float = 1.0) -> float:
	return 20.5 * PACE_SCALE * float(factors.get("speed", 1.0)) * difficulty_speed


static func acceleration(factors: Dictionary, braking: bool) -> float:
	return (
		20.0 * DYNAMICS_SCALE * float(factors.get("brake", 1.0))
		if braking
		else 10.0 * DYNAMICS_SCALE * float(factors.get("accel", 1.0))
	)


## Straight asphalt stop using the same 60 Hz velocity response as _drive_player.
## The old workshop added a fixed 1.5 m lag, which became wrong at the new pace.
static func stopping_distance(factors: Dictionary, initial_speed: float = 20.0) -> float:
	if initial_speed <= 0.0:
		return 0.0
	var step: float = 1.0 / 60.0
	var brake: float = acceleration(factors, true)
	if brake <= 0.0:
		return INF
	var grip: float = clampf(9.0 * float(factors.get("grip", 1.0)) * PACE_SCALE * step, 0.0, 1.0)
	var scalar_speed: float = initial_speed
	var velocity: float = initial_speed
	var distance: float = 0.0
	while scalar_speed >= 0.5:
		scalar_speed = move_toward(scalar_speed, 0.0, brake * step)
		velocity = lerpf(velocity, scalar_speed, grip)
		distance += velocity * step
	return distance


static func report(factors: Dictionary) -> Dictionary:
	var maximum: float = top_speed(factors)
	var target: float = 50.0 / 3.6
	var thrust: float = acceleration(factors, false)
	# The race integrates speed with move_toward, i.e. a constant acceleration ramp.
	return {
		"top_kmh": maximum * 3.6,
		"zero_fifty": target / thrust if maximum >= target else -1.0,
		"brake_metres": stopping_distance(factors, target),
		"boost_seconds": 3.2 * float(factors.get("boost_time", 1.0)),
	}
