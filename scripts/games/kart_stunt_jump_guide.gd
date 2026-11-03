extends RefCounted
## Deterministic speed-only stunt-jump advisor. The impact estimate assumes the
## next roadway is at the take-off road's height; real physics still chooses the
## actual contact frame. This class never accelerates, brakes or lands a kart.

const APPROACH_M: float = 62.0

static func predicted_distance(kicker: Dictionary, speed_mps: float) -> float:
	var gravity: float = float(kicker.get("flight_gravity", 9.8))
	var height: float = float(kicker.get("height", 0.0))
	var angle: float = float(kicker.get("angle", 0.0))
	if gravity <= 0.0 or not is_finite(gravity) or not is_finite(speed_mps):
		return 0.0
	var velocity: float = maxf(0.0, speed_mps)
	var vertical: float = velocity * sin(angle)
	var horizontal: float = velocity * cos(angle)
	var flight_time: float = (vertical + sqrt(maxf(0.0, vertical * vertical + 2.0 * gravity * height))) / gravity
	return maxf(0.0, horizontal * flight_time)


static func advisory(kicker: Dictionary, track_distance: float, speed_mps: float) -> Dictionary:
	if not bool(kicker.get("skill_flight", false)):
		return {}
	var distance_left: float = float(kicker.get("take_off", 0.0)) - track_distance
	if distance_left <= 0.0 or distance_left > APPROACH_M + float(kicker.get("length", 0.0)):
		return {}
	var projected: float = predicted_distance(kicker, speed_mps)
	var earliest: float = float(kicker.get("landing_min_m", 28.0))
	var latest: float = float(kicker.get("landing_max_m", 36.0))
	var band: String = "green"
	var text: String = "GUTES TEMPO"
	var tint: Color = Color("57e69f")
	if projected < earliest:
		band = "red"
		text = "GIB GAS"
		tint = Color("ff687c")
	elif projected > latest:
		band = "orange"
		text = "BREMSEN"
		tint = Color("ffbe67")
	return {
		"band": band,
		"hint": text,
		"color": tint,
		"speed_kmh": roundi(maxf(0.0, speed_mps) * 3.6),
		"projected_m": projected,
		"distance_left_m": distance_left,
	}
