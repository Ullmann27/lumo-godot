extends RefCounted
## Shared straight-line drivetrain used by the race and the workshop simulation.
## Workshop figures use Abenteuer difficulty, level asphalt, no items or rivals.


static func top_speed(factors: Dictionary, difficulty_speed: float = 1.0) -> float:
	return 20.5 * float(factors.get("speed", 1.0)) * difficulty_speed


static func acceleration(factors: Dictionary, braking: bool) -> float:
	return (
		20.0 * float(factors.get("brake", 1.0))
		if braking
		else 10.0 * float(factors.get("accel", 1.0))
	)


static func report(factors: Dictionary) -> Dictionary:
	var maximum: float = top_speed(factors)
	var target: float = 50.0 / 3.6
	var thrust: float = acceleration(factors, false)
	var brake: float = acceleration(factors, true)
	# The race integrates speed with move_toward, i.e. a constant acceleration ramp.
	return {
		"top_kmh": maximum * 3.6,
		"zero_fifty": target / thrust if maximum >= target else -1.0,
		"brake_metres": target * target / (2.0 * brake),
		"boost_seconds": 3.2 * float(factors.get("boost_time", 1.0)),
	}
