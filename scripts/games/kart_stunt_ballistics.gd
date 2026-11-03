extends RefCounted
## Honest free-flight forecast for Sonnenhafen. Units are metres, seconds,
## radians, m/s. The game stores *horizontal* speed; ramp slope gives
## vertical launch velocity v_y = speed * tan(angle). Thus the same motion
## equations drive both the forecast and the real Godot physics integration.
## No auto-speed, magnet landing or hidden take-off impulse.
## Steering can still change the actual trajectory during the airborne phase.


static func flight_time(speed: float, angle: float, height: float, gravity: float) -> float:
	if speed <= 0.0 or gravity <= 0.0 or height < 0.0:
		return 0.0
	var rising: float = speed * tan(angle)
	return (rising + sqrt(rising * rising + 2.0 * gravity * height)) / gravity


static func landing_range(speed: float, angle: float, height: float, gravity: float) -> float:
	return speed * flight_time(speed, angle, height, gravity)


static func required_speed(gap: float, angle: float, height: float, gravity: float) -> float:
	if gap <= 0.0 or gravity <= 0.0 or height < 0.0 or cos(angle) <= 0.0:
		return 0.0
	var denominator: float = 2.0 * (height + gap * tan(angle))
	if denominator <= 0.0:
		return 0.0
	return sqrt(gravity * gap * gap / denominator)


static func forecast(speed: float, kicker: Dictionary) -> Dictionary:
	var angle: float = float(kicker.get("angle", 0.0))
	var height: float = float(kicker.get("height", 0.0))
	var gravity: float = float(kicker.get("flight_gravity", 14.0))
	var gap: float = float(kicker.get("gap_end", 0.0)) - float(kicker.get("take_off", 0.0))
	var band: float = float(kicker.get("landing_band", 8.0))
	var metres: float = landing_range(speed, angle, height, gravity)
	var minimum: float = required_speed(gap, angle, height, gravity)
	var maximum: float = required_speed(gap + band, angle, height, gravity)
	var state: String = "good"
	if metres < gap:
		state = "slow"
	elif metres > gap + band:
		state = "fast"
	return {
		"state": state,
		"range": metres,
		"minimum_speed": minimum,
		"maximum_speed": maximum,
		"gap": gap,
		"landing_band": band,
		"speed_kmh": int(round(speed * 3.6))
	}
