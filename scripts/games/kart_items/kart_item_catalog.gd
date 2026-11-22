extends RefCounted
## Data-driven Lumo-Kart item catalog (assets/kart/items/kart_items.json).
## Every item is original: names, looks and rules belong to Lumo. A new item is one
## JSON row plus, if needed, a new behaviour in kart_item_runtime.gd.

const PATH := "res://assets/kart/items/kart_items.json"
## Hook items-neu: weitere Verhalten aus dem Erweiterungsverzeichnis.
const EXT_REGISTRY = preload("res://scripts/games/kart_items/ext/kart_item_ext_registry.gd")
const BEHAVIOURS: Array[String] = [
	"boost", "shield", "pulse", "homing_projectile", "bouncing_projectile",
	"dropped_trap", "magnet", "aurora",
]
const PLACES: int = 6

static var _items: Array[Dictionary] = []
static var _by_id: Dictionary = {}


static func load_catalog(path: String = PATH) -> Array[Dictionary]:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var result: Array[Dictionary] = []
	if not parsed is Dictionary or int(parsed.get("schemaVersion", 0)) != 1:
		push_error("Lumo-Kart item catalog has no valid schema.")
		return result
	var seen: Dictionary = {}
	for row in parsed.get("items", []):
		var problem: String = validate(row)
		if not problem.is_empty():
			push_error("Lumo-Kart item rejected: " + problem)
			continue
		if seen.has(row.id):
			push_error("Duplicate Lumo-Kart item: " + str(row.id))
			continue
		seen[row.id] = true
		result.append(row)
	return result


static func validate(row: Variant) -> String:
	if not row is Dictionary:
		return "row is not an object"
	for key in ["id", "name", "short", "behaviour", "weights", "color"]:
		if not row.has(key):
			return "missing " + key
	if str(row.behaviour) not in BEHAVIOURS and not EXT_REGISTRY.has_behaviour(str(row.behaviour)):
		return "unknown behaviour " + str(row.behaviour)
	if not row.weights is Array or row.weights.size() != PLACES:
		return "weights need %d places" % PLACES
	var player_weights = row.get("player_weights", row.weights)
	if not player_weights is Array or player_weights.size() != PLACES:
		return "player_weights need %d places" % PLACES
	for i in range(PLACES):
		for weight in [row.weights[i], player_weights[i]]:
			if typeof(weight) not in [TYPE_INT, TYPE_FLOAT] or float(weight) < 0.0:
				return "weights must be non-negative numbers"
		if float(row.weights[i]) == 0.0 and float(player_weights[i]) > 0.0:
			return "player_weights must respect the rank restriction"
	return ""


static func all() -> Array[Dictionary]:
	if _items.is_empty():
		_items = load_catalog()
		_by_id.clear()
		for row in _items:
			_by_id[str(row.id)] = row
	return _items


static func ids() -> Array[String]:
	var result: Array[String] = []
	for row in all():
		result.append(str(row.id))
	return result


static func has(id: String) -> bool:
	all()
	return _by_id.has(id)


static func entry(id: String) -> Dictionary:
	all()
	return _by_id.get(id, {})


static func number(id: String, key: String, fallback: float) -> float:
	var row: Dictionary = entry(id)
	return float(row.get(key, fallback))


static func behaviour(id: String) -> String:
	return str(entry(id).get("behaviour", ""))


static func label(id: String) -> String:
	if id.is_empty() or not has(id):
		return "ITEM\n◇"
	var row: Dictionary = entry(id)
	return "%s\n%s" % [row.short, row.get("glyph", "")]


static func color(id: String) -> Color:
	return Color(str(entry(id).get("color", "#a7c5ff")))


static func _weight(row: Dictionary, index: int, for_player: bool) -> float:
	var weights: Array = row.get("player_weights", row.weights) if for_player else row.weights
	return float(weights[index])


## Weighted roll; `place` is 1..6. `catch_up` (0..1) shifts the roll one or two
## places further back so a child who is far behind gets the stronger helpers.
static func roll(place: int, rng: RandomNumberGenerator, catch_up: float = 0.0, for_player: bool = false) -> String:
	var effective: int = clampi(place + int(round(clampf(catch_up, 0.0, 1.0) * 2.0)), 1, PLACES)
	var total: float = 0.0
	for row in all():
		total += _weight(row, effective - 1, for_player)
	if total <= 0.0:
		return ""
	var pick: float = rng.randf() * total
	var last_eligible := ""
	for row in all():
		var weight := _weight(row, effective - 1, for_player)
		if weight <= 0.0:
			continue
		last_eligible = str(row.id)
		pick -= weight
		if pick <= 0.0:
			return last_eligible
	return last_eligible


## Probability of every item at a place (used by tests and the design doc).
static func odds(place: int, for_player: bool = false) -> Dictionary:
	var result: Dictionary = {}
	var total: float = 0.0
	for row in all():
		total += _weight(row, clampi(place, 1, PLACES) - 1, for_player)
	for row in all():
		result[str(row.id)] = _weight(row, clampi(place, 1, PLACES) - 1, for_player) / maxf(total, 0.0001)
	return result
