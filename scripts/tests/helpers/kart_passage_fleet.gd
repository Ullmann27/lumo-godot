extends RefCounted
## Fleet extremes for the LUMO passage regression (fastest and slowest karts from the stats).
const FLEET = preload("res://scripts/games/kart_fleet.gd")


static func fastest_kart() -> String:
	var best: String = "comet"
	var top: float = 0.0
	for id in FLEET.ids():
		var factors: Dictionary = FLEET.multipliers(FLEET.base_stats(id), FLEET.entry(id).traits)
		if float(factors.speed) > top:
			top = float(factors.speed)
			best = id
	return best


static func slowest_karts() -> Dictionary:
	var by_accel: String = ""
	var by_top: String = ""
	var accel: float = INF
	var top: float = INF
	for id in FLEET.ids():
		var factors: Dictionary = FLEET.multipliers(FLEET.base_stats(id), FLEET.entry(id).traits)
		if float(factors.accel) < accel:
			accel = float(factors.accel)
			by_accel = id
		if float(factors.speed) < top:
			top = float(factors.speed)
			by_top = id
	return {"accel": by_accel, "top": by_top}
