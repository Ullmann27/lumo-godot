extends RefCounted
## Deterministic arcade projectile model shared by speed advice and the actual
## Sonnenhafen stunt launch. Horizontal speed is NOT secretly boosted.
## All lengths are metres, speed metres/second, gravity metres/second^2.

static func flight_time(speed: float, angle: float, launch_height: float, gravity: float) -> float:
	if speed <= 0.0 or gravity <= 0.0 or launch_height < 0.0:
		return 0.0
	var upward: float = speed * sin(angle)
	return (upward + sqrt(upward * upward + 2.0 * gravity * launch_height)) / gravity


static func landing_distance(speed: float, angle: float, launch_height: float, gravity: float) -> float:
	return speed * cos(angle) * flight_time(speed, angle, launch_height, gravity)


## Analytic inverse: target range = v * cos(angle) * time.
## The player may undershoot or overshoot; the warning never changes velocity.
static func speed_for_distance(distance: float, angle: float, launch_height: float, gravity: float) -> float:
	if distance <= 0.0 or gravity <= 0.0 or launch_height < 0.0:
		return 0.0
	var cosine: float = cos(angle)
	var denominator: float = 2.0 * cosine * cosine * (launch_height + distance * tan(angle))
	if denominator <= 0.0001:
		return 0.0
	return sqrt(gravity * distance * distance / denominator)


static func prediction(speed: float, kicker: Dictionary) -> Dictionary:
	var angle: float = float(kicker.angle)
	var gravity: float = float(kicker.flight_gravity)
	var launch_height: float = float(kicker.height)
	var minimum: float = float(kicker.landing_min)
	var maximum: float = float(kicker.landing_max)
	var projected: float = landing_distance(speed, angle, launch_height, gravity)
	var status: String = "passend"
	if projected < minimum:
		status = "langsam"
	elif projected > maximum:
		status = "schnell"
	return {
		"status": status,
		"predicted_distance": projected,
		"min_speed": speed_for_distance(minimum, angle, launch_height, gravity),
		"max_speed": speed_for_distance(maximum, angle, launch_height, gravity)
	}
