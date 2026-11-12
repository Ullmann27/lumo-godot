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
		var remaining: float = float(kicker.take_off) - at
		if remaining < -1.0 or remaining > maxf(30.0, physical_top * 3.2):
			continue
		var landing_speed: float = launch_speed(world, kicker)
		if landing_speed <= 0.0:
			continue
		var desired: float = minf(physical_top, landing_speed)
		var acceleration: float = POWERTRAIN.acceleration(factors, current_speed > desired)
		# Plan with actual stopping distance rather than cruising at ramp speed
		# for hundreds of metres. The final margin leaves time to settle on the
		# ramp; the same envelope also permits a slow racer to accelerate early.
		var change_distance: float = absf(current_speed * current_speed - desired * desired) / (2.0 * acceleration)
		var approach: float = maxf(30.0, change_distance + current_speed * 0.35 + 6.0)
		if remaining > approach:
			continue
		return move_toward(maxf(0.0, current_speed), desired, acceleration * delta)
	return fallback


## Precision gaps target their marked zone. A panorama ramp before a loop must
## land early enough for real road contact and lane alignment; doubling cruise
## speed must not make a computer racer fly over the loop or snap onto its deck.
static func launch_speed(world, kicker: Dictionary) -> float:
	if bool(kicker.get("precision_jump", false)):
		var authored: float = float(kicker.get("rival_speed", 0.0))
		if authored > 0.0:
			return authored
		var middle: float = (float(kicker.landing_min) + float(kicker.landing_max)) * 0.5
		return PRECISION.speed_for_distance(middle, kicker)
	if world.loop_layout.is_empty():
		return 0.0
	var loop_gap: float = float(world.loop_layout.start) - float(kicker.take_off)
	if loop_gap <= 20.0 or loop_gap >= 150.0:
		return 0.0
	# Action dictionaries belong to this built world and are recreated on a
	# track change. Cache the expensive ballistic inversion once per ramp.
	if not kicker.has("planned_loop_launch_speed"):
		kicker["planned_loop_launch_speed"] = PRECISION.speed_for_distance(loop_gap - 18.0, kicker)
	return float(kicker.planned_loop_launch_speed)
