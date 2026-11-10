extends RefCounted
## A mandatory precision jump uses the actual kart's available acceleration,
## not the easier difficulty's cruising handicap or a fabricated turbo.
const CRAFT = preload("res://scripts/games/kart_rival_racecraft.gd")
const POWERTRAIN = preload("res://scripts/games/kart_powertrain.gd")
const PRECISION = preload("res://scripts/games/kart_precision_jump.gd")


static func target_speed(
	world,
	at: float,
	kart_id: String,
	difficulty_speed: float,
	current_speed: float,
	fallback: float,
	boosted: bool,
	delta: float
) -> float:
	var factors: Dictionary = CRAFT.factors(kart_id)
	var physical_top: float = POWERTRAIN.top_speed(factors, difficulty_speed)
	if boosted:
		physical_top *= 1.32
	for kicker in world.action.get("kickers", []):
		if not bool(kicker.get("precision_jump", false)):
			continue
		var remaining: float = float(kicker.take_off) - at
		if remaining < -1.0 or remaining > maxf(30.0, physical_top * 3.2):
			continue
		var middle: float = (float(kicker.landing_min) + float(kicker.landing_max)) * 0.5
		var landing_speed: float = float(kicker.get("rival_speed", 0.0))
		if landing_speed <= 0.0:
			landing_speed = PRECISION.speed_for_distance(middle, kicker)
		var desired: float = minf(physical_top, landing_speed)
		var acceleration: float = POWERTRAIN.acceleration(factors, current_speed > desired)
		return move_toward(maxf(0.0, current_speed), desired, acceleration * delta)
	return fallback
