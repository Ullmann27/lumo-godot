extends RefCounted
## Höhenkarte der Dorfwelt (Daten aus tools/lumo_village_art/make_terrain.py).
## Reine, deterministische Abfragen: Geländehöhe, Neigung, Fluss und welche
## Grundstücke bebaubar sind. Spielregeln und Darstellung lesen dieselbe Quelle.
const DATA_PATH := "res://assets/creative/village3d/terrain/village_heightmap.tres"
const WATER_LEVEL := -1.1
static var _loaded := false
static var _heights := PackedFloat32Array()
static var _origin := Vector2(-320, -240)
static var _step := 2.0
static var _width := 0
static var _depth := 0
static var _blocked := {false: {}, true: {}}
## Warum ein Feld des Kindes gesperrt ist: "water", "mountain", "slope",
## "foreign" (fremdes Stadtgebiet), "reserved" (Höhle, Lager, Hain), "outside".
static var _reason := {}
## Bebaubare Felder am anderen Flussufer: erst über die Lieferbrücke erreichbar.
static var _far_bank := {}
## Gesperrte Felder je Nachbarstadt (eigene Gebiete, eigene Raster).
static var _site_blocked := {}
const REASONS := ["water", "mountain", "slope", "foreign", "reserved", "outside"]
const NEIGHBOR_IDS := ["leo", "ella", "flitz"]
## Eigene Stadtgebiete der Nachbarn am Ostufer (Mitte, 19 × 19 Bauplätze).
## Gleiche Werte wie NEIGHBOR_SITES in tools/lumo_village_art/make_terrain.py.
const NEIGHBOR_SITES := {"leo": Vector2(190.0, -5.0), "ella": Vector2(165.0, -125.0), "flitz": Vector2(170.0, 120.0)}
const NEIGHBOR_RING := 9
const NEIGHBOR_HALF := 9.5 * 5.3


## Welche Nachbarstadt besitzt diesen Ort? "" = niemand.
static func territory_at(x: float, z: float) -> String:
	for id in NEIGHBOR_SITES:
		var site: Vector2 = NEIGHBOR_SITES[id]
		if absf(x - site.x) <= NEIGHBOR_HALF + 2.65 and absf(z - site.y) <= NEIGHBOR_HALF + 2.65:
			return str(id)
	return ""


static func ensure() -> bool:
	if _loaded:
		return not _heights.is_empty()
	_loaded = true
	if not ResourceLoader.exists(DATA_PATH):
		push_warning("[VillageTerrain] Höhenkarte fehlt; flaches Gelände")
		return false
	var data: Resource = load(DATA_PATH)
	if data == null or not data.has_meta("heights"):
		push_warning("[VillageTerrain] Höhenkarte unlesbar; flaches Gelände")
		return false
	_origin = data.get_meta("origin", _origin)
	_step = float(data.get_meta("step", 2.0))
	_width = int(data.get_meta("width", 0))
	_depth = int(data.get_meta("depth", 0))
	var heights: PackedFloat32Array = data.get_meta("heights")
	if heights.size() != _width * _depth or _width < 2 or _depth < 2:
		push_warning("[VillageTerrain] Höhenkarte hat falsche Größe")
		return false
	_heights = heights
	for opponent in [false, true]:
		var key := "blocked_neighbor" if opponent else "blocked_player"
		var lookup: Dictionary = {}
		for index in data.get_meta(key, PackedInt32Array()):
			lookup[int(index)] = true
		_blocked[opponent] = lookup
	for key in REASONS:
		for index in data.get_meta("reason_" + key, PackedInt32Array()):
			_reason[int(index)] = key
	for index in data.get_meta("reason_far_bank", PackedInt32Array()):
		_far_bank[int(index)] = true
	for id in NEIGHBOR_IDS:
		var lookup: Dictionary = {}
		for index in data.get_meta("blocked_site_" + id, PackedInt32Array()):
			lookup[int(index)] = true
		_site_blocked[id] = lookup
	return true


static func available() -> bool:
	return ensure()


static func origin() -> Vector2:
	ensure()
	return _origin


static func step() -> float:
	ensure()
	return _step


static func grid_size() -> Vector2i:
	ensure()
	return Vector2i(_width, _depth)


static func size() -> Vector2:
	ensure()
	return Vector2(float(_width - 1) * _step, float(_depth - 1) * _step)


## Rohwert eines Gitterpunkts (für Netz- und Kollisionsaufbau).
static func grid_height(ix: int, iz: int) -> float:
	if _heights.is_empty():
		return 0.0
	return _heights[clampi(iz, 0, _depth - 1) * _width + clampi(ix, 0, _width - 1)]


static func height(x: float, z: float) -> float:
	if not ensure():
		return 0.0
	var gx := clampf((x - _origin.x) / _step, 0.0, float(_width) - 1.001)
	var gz := clampf((z - _origin.y) / _step, 0.0, float(_depth) - 1.001)
	var ix := int(gx)
	var iz := int(gz)
	var fx := gx - float(ix)
	var fz := gz - float(iz)
	var row := iz * _width + ix
	var a := _heights[row]
	var b := _heights[row + 1]
	var c := _heights[row + _width]
	var d := _heights[row + _width + 1]
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fz)


static func normal(x: float, z: float) -> Vector3:
	var e := 1.0
	var dx := height(x + e, z) - height(x - e, z)
	var dz := height(x, z + e) - height(x, z - e)
	return Vector3(-dx, 2.0 * e, -dz).normalized()


## 0 = flach, 1 = senkrecht.
static func steepness(x: float, z: float) -> float:
	return 1.0 - normal(x, z).y


static func river_center(z: float) -> float:
	return 2.4 * sin(z * 0.021) + 1.5 * sin(z * 0.057 + 1.3)


static func is_water(x: float, z: float) -> bool:
	return height(x, z) < WATER_LEVEL


## Grundstücke auf Fels, Hang, Ufer oder im Wasser sind nicht bebaubar.
## Ohne Höhenkarte gilt das alte, flache Verhalten (alles bebaubar).
static func plot_blocked(index: int, opponent := false) -> bool:
	if not ensure():
		return false
	return _blocked[opponent].has(index)


## Grund der Sperre eines Felds des Kindes ("" = bebaubar).
static func plot_reason(index: int) -> String:
	if not ensure():
		return ""
	if _blocked[false].has(index):
		return str(_reason.get(index, "slope"))
	return ""


## Liegt das (bebaubare) Feld am anderen Flussufer?
static func plot_far_bank(index: int) -> bool:
	return ensure() and _far_bank.has(index)


static func far_bank_count() -> int:
	return _far_bank.size() if ensure() else 0


## Gesperrte Bauplätze einer Nachbarstadt in ihrem eigenen Gebiet.
static func site_blocked(id: String, index: int) -> bool:
	if not ensure():
		return false
	return (_site_blocked.get(id, {}) as Dictionary).has(index)


static func reason_count(key: String) -> int:
	if not ensure():
		return 0
	var total := 0
	for index in _reason:
		if _reason[index] == key:
			total += 1
	return total


static func blocked_count(opponent := false) -> int:
	if not ensure():
		return 0
	return _blocked[opponent].size()
