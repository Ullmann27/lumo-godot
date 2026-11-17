extends RefCounted
## Deterministic projectile model of the Sonnenhafen precision jump.
##
## It mirrors exactly what kart_island._move_vertically does at the lip:
## - horizontal speed stays the kart speed (no hidden boost or brake in the air),
## - vertical take-off speed = speed * sin(ramp angle) + lift_bonus, capped by
##   max_lift (the precision ramp uses lift_bonus 0 and an uncapped max_lift),
## - launch height = ramp height above the road, gravity = flight_gravity,
## - the landing road rises by landing_slope metres per metre.
## The speed hint uses the same numbers, so advice and flight never disagree.
## Nothing here changes the kart: too slow undershoots, too fast overshoots.
## Lengths in metres, speeds in m/s, gravity in m/s^2.

const STATUS_SLOW: String = "langsam"
const STATUS_GOOD: String = "passend"
const STATUS_FAST: String = "schnell"
const LANDING_SHORT: String = "zu_kurz"
const LANDING_ZONE: String = "ziel"
const LANDING_LONG: String = "zu_weit"


static func launch_vertical(speed: float, kicker: Dictionary) -> float:
	var lift: float = speed * sin(float(kicker.angle)) + float(kicker.get("lift_bonus", 0.0))
	return minf(lift, float(kicker.get("max_lift", INF)))


## Time until the kart meets the (sloped) landing road again.
static func flight_time(speed: float, kicker: Dictionary) -> float:
	var gravity: float = float(kicker.flight_gravity)
	var height: float = float(kicker.height)
	if speed <= 0.0 or gravity <= 0.0 or height < 0.0:
		return 0.0
	# height + v0 t - g t^2 / 2 = slope * speed * t
	var b: float = launch_vertical(speed, kicker) - float(kicker.get("landing_slope", 0.0)) * speed
	return (b + sqrt(b * b + 2.0 * gravity * height)) / gravity


static func landing_distance(speed: float, kicker: Dictionary) -> float:
	return maxf(0.0, speed) * flight_time(speed, kicker)


## Height above the take-off road at a horizontal distance, for the arc stars.
static func height_at(speed: float, kicker: Dictionary, along: float) -> float:
	if speed <= 0.0:
		return float(kicker.height)
	var t: float = along / speed
	return (
		float(kicker.height)
		+ launch_vertical(speed, kicker) * t
		- 0.5 * float(kicker.flight_gravity) * t * t
	)


## Inverse by bisection: landing distance grows monotonically with speed.
static func speed_for_distance(distance: float, kicker: Dictionary) -> float:
	if distance <= 0.0:
		return 0.0
	var low: float = 0.0
	var high: float = 80.0
	if landing_distance(high, kicker) < distance:
		return high
	for _i in range(60):
		var middle: float = (low + high) * 0.5
		if landing_distance(middle, kicker) < distance:
			low = middle
		else:
			high = middle
	return (low + high) * 0.5


static func classify_landing(flown: float, kicker: Dictionary) -> String:
	if flown < float(kicker.landing_min):
		return LANDING_SHORT
	if flown > float(kicker.landing_max):
		return LANDING_LONG
	return LANDING_ZONE


static func prediction(speed: float, kicker: Dictionary) -> Dictionary:
	var projected: float = landing_distance(speed, kicker)
	var status: String = STATUS_GOOD
	if projected < float(kicker.landing_min):
		status = STATUS_SLOW
	elif projected > float(kicker.landing_max):
		status = STATUS_FAST
	return {
		"status": status,
		"predicted_distance": projected,
		"min_speed": speed_for_distance(float(kicker.landing_min), kicker),
		"max_speed": speed_for_distance(float(kicker.landing_max), kicker),
	}


## Child-facing hint: text and colour (red = too slow, green = fits, orange = too fast).
static func hint(status: String) -> Dictionary:
	match status:
		STATUS_SLOW:
			return {"text": "Gib Gas!", "color": Color("ff4d4d")}
		STATUS_FAST:
			return {"text": "Etwas bremsen!", "color": Color("ffa126")}
	return {"text": "Tempo passt!", "color": Color("45e07a")}
