extends RefCounted
## Dschungelherz as a hand-built adventure path: geometry (legs of path with
## turns, climbs, widths and surfaces, holes, cave ceilings) and everything that
## lies on it (stars, letters, enemies, barrels, vines, platforms, mushrooms,
## checkpoints, rescue points, the chase and the mine cart ride).
##
## Road space as everywhere in Lumo Lauf: `s` metres along the path, `lat`
## metres to the right, `h` metres above the path surface. The builder below
## reads like the level: a cursor walks along the path and each piece adds its
## stretch of path and what lies on it. Same input, same level, every time.

const TUNING = preload("res://scripts/games/run/run_tuning.gd")

## Where the bonus room lies in road space: before the start, never on the way.
const BONUS_S0: float = -300.0
const SECTION_NAMES: Array[String] = [
	"Lichtung", "Wurzelpfad", "Kronenwege", "Tempelruinen", "Wasserfallhöhle", "Lorenfahrt"
]

var legs: Array[Dictionary] = []
var bonus_legs: Array[Dictionary] = []
var gaps: Array[Vector2] = []
var surfaces: Array[Dictionary] = []
var ceilings: Array[Vector3] = []
var sections: Array[Dictionary] = []
var stars: Array[Dictionary] = []
var hurdles: Array[Dictionary] = []
var blockers: Array[Dictionary] = []
var enemies: Array[Dictionary] = []
var rides: Array[Dictionary] = []
var platforms: Array[Dictionary] = []
var bounces: Array[Dictionary] = []
var letters: Array[Dictionary] = []
var checkpoints: Array[Dictionary] = []
var respawns: Array[Dictionary] = []
var waits: Array[Dictionary] = []
var coaches: Array[Dictionary] = []
var decor: Array[Dictionary] = []
var branches: Array[Dictionary] = []
## The three adventure passages (see _passage): where they are, their two lines
## and the numbers they were built with (gaps in metres).
var passages: Array[Dictionary] = []
var chase: Dictionary = {}
var cart: Dictionary = {}
var bonus: Dictionary = {}
var start_s: float = 6.0
var intro_end: float = 0.0
var finish_s: float = 0.0
var length: float = 0.0
var s: float = 0.0
var _half: float = 2.2
var _ground: float = 0.0
var _surface: String = "dirt"


static func make() -> RefCounted:
	var level = new()
	level._build()
	return level


# ------------------------------------------------------------------ builder primitives

## One stretch of path. `turn` in degrees over the stretch (positive = right),
## `rise` in metres, `half` the half width, `ground` the forest floor relative
## to the path (negative when the path runs high above it).
func _leg(length_m: float, turn: float, rise: float, half: float, surface: String, ground: float = 0.0) -> float:
	var from: float = s
	legs.append(
		{"s0": from, "length": length_m, "turn": turn, "rise": rise, "half": half, "surface": surface, "ground": ground}
	)
	surfaces.append({"s0": from, "s1": from + length_m, "kind": surface, "half": half, "ground": ground})
	s += length_m
	_half = half
	if surface != "gap":
		_ground = ground
		_surface = surface
	return from


## A hole in the path: falling in means a short trip back to the last rescue point.
func _hole(length_m: float, rise: float = 0.0, turn: float = 0.0) -> float:
	# Holes in the forest floor are shallow streams; up in the trees it is a long way down.
	var floor_depth: float = -2.6 if _ground > -1.0 and _surface in ["dirt", "roots", "cave", "slide"] else minf(_ground, -9.0)
	var from: float = _leg(length_m, turn, rise, _half, "gap", floor_depth)
	gaps.append(Vector2(from, from + length_m))
	return from


func _safe(at: float, lat: float = 0.0, in_cart: bool = false) -> void:
	respawns.append({"s": at, "lat": lat, "cart": in_cart})


func _star(at: float, lat: float, h: float = 1.0, value: int = 1, route: String = "main") -> void:
	stars.append({"s": at, "lat": lat, "h": h, "value": value, "route": route})


func _line(from: float, to: float, lat0: float, lat1: float, h: float = 1.0, spacing: float = 2.6, route: String = "main") -> void:
	if to <= from:
		return
	var at: float = from
	while at <= to + 0.01:
		var u: float = (at - from) / (to - from)
		_star(at, lerpf(lat0, lat1, smoothstep(0.0, 1.0, u)), h, 1, route)
		at += spacing
	return


## Star arc that follows the flight of a held jump started at `from`.
func _arc(from: float, to: float, lat: float, peak: float, count: int, base: float = 1.0, route: String = "main") -> void:
	for step in range(count):
		var u: float = float(step) / float(maxi(1, count - 1))
		_star(lerpf(from, to, u), lat, base + (peak - base) * 4.0 * u * (1.0 - u), 1, route)


func _gold(at: float, lat: float, h: float, route: String = "main") -> void:
	_star(at, lat, h, TUNING.GOLD_STAR_VALUE, route)


func _platform(s0: float, s1: float, lat: float, half: float, top: float, look: String, extra: Dictionary = {}) -> void:
	var entry: Dictionary = {
		"s0": s0, "s1": s1, "lat": lat, "half": half, "top": top, "look": look,
		"axis": "", "amp": 0.0, "rate": 0.0, "phase": 0.0, "crumble": false,
	}
	entry.merge(extra, true)
	platforms.append(entry)


func _mushroom(at: float, lat: float, power: float = TUNING.BOUNCE_SPEED, top: float = 0.0) -> void:
	bounces.append({"s": at, "lat": lat, "radius": 1.1, "half": 1.15, "power": power, "top": top, "look": "mushroom"})


func _enemy(kind: String, at: float, lat: float, amp: float, rate: float, phase: float = 0.0, span: float = 0.0) -> void:
	var radius: float = {"crab": 0.62, "beetle": 0.58, "coconut": 0.45}.get(kind, 0.6)
	var top: float = {"crab": 0.8, "beetle": 0.75, "coconut": 0.7}.get(kind, 0.8)
	enemies.append(
		{"kind": kind, "s": at, "lat": lat, "amp": amp, "rate": rate, "phase": phase, "span": span, "radius": radius, "top": top}
	)


func _log(at: float, lat: float = 0.0, half: float = 30.0) -> void:
	hurdles.append({"s": at, "lat": lat, "half": half, "height": 0.6})


func _barrel(at: float, lat: float, h: float, target_s: float, target_lat: float, target_h: float, arc: float, wait: float = 1.0) -> void:
	var distance: float = Vector2(target_s - at, target_h - h).length()
	rides.append(
		{
			"kind": "barrel", "s": at, "lat": lat, "h": h, "ts": target_s, "tlat": target_lat, "th": target_h,
			"arc": arc, "wait": wait, "time": clampf(distance / 17.0, 0.55, 1.6),
		}
	)


func _vine(handle: float, lat: float, rope: float, swing: float) -> void:
	# The pivot hangs above and ahead of the handle; Lumo swings from -swing to +swing.
	var pivot_s: float = handle + rope * sin(swing)
	var pivot_h: float = 1.9 + rope * cos(swing)
	rides.append(
		{
			"kind": "vine", "s": handle, "lat": lat, "h": 1.9, "ps": pivot_s, "ph": pivot_h, "rope": rope,
			"a0": -swing, "a1": swing * 1.15, "time": 1.25,
		}
	)


func _zip(from: float, lat: float, h0: float, to: float, h1: float) -> void:
	rides.append({"kind": "zip", "s": from, "lat": lat, "h": h0, "ts": to, "th": h1, "sag": 1.4, "speed": 13.0})


## Height of Lumo's body centre on a zip line (see run_player.gd, ride "zip").
func _zip_body(from: float, h0: float, to: float, h1: float, at: float) -> float:
	var u: float = clampf((at - from) / (to - from), 0.0, 1.0)
	return lerpf(h0, h1, u) - 1.4 * 4.0 * u * (1.0 - u) - 1.6 + TUNING.BODY_CENTRE


func _letter(character: String, at: float, lat: float, h: float) -> void:
	letters.append({"char": character, "s": at, "lat": lat, "h": h})


func _checkpoint(at: float, question: bool = false) -> void:
	checkpoints.append({"s": at, "question": question, "index": checkpoints.size()})
	_safe(at + 2.0)


func _decor(kind: String, at: float, lat: float, extra: Dictionary = {}) -> void:
	var entry: Dictionary = {"kind": kind, "s": at, "lat": lat}
	entry.merge(extra, true)
	decor.append(entry)


## Registers an adventure passage: announced `lead` metres before its hole,
## with a safe line (shorter jump, more time) and a brave line (longer jump,
## gold stars). Both are branches for the scripted player as well.
func _passage(name: String, hole: float, length_m: float, safe: Dictionary, brave: Dictionary, say: String,
		brave_speed: float, lead: float = 46.0) -> void:
	passages.append({
		"name": name, "s0": hole, "s1": hole + length_m, "announce": hole - lead, "say": say,
		"safe_lat": float(safe.lat), "safe_gap": float(safe.gap), "brave_lat": float(brave.lat), "brave_gap": float(brave.gap),
		"safe_hold": float(safe.get("hold", 0.0)), "brave_hold": float(brave.get("hold", 0.0)),
		"plank": float(safe.get("plank", 0.0)), "brave_speed": brave_speed, "downhill": float(brave.get("downhill", 1.0)),
	})
	branches.append({
		"s0": hole - 24.0, "s1": hole + length_m + 1.0, "upper_lat": float(brave.lat), "lower_lat": float(safe.lat),
		"name": name, "brave_speed": brave_speed,
	})
	_decor("sign", hole - lead, -(_half + 0.6), {"icon": "passage"})
	coaches.append({"s0": hole - 14.0, "s1": hole + 1.0, "icon": "jump"})


func _section(index: int, mood: String) -> void:
	if not sections.is_empty():
		sections[sections.size() - 1]["s1"] = s
	sections.append({"index": index, "name": SECTION_NAMES[index], "s0": s, "s1": s, "mood": mood})


# ------------------------------------------------------------------ the level

func _build() -> void:
	_intro()
	_root_path()
	_canopy_walk()
	_temple()
	_waterfall_cave()
	_mine_ride()
	sections[sections.size() - 1]["s1"] = s
	length = s
	_bonus_room()
	stars.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.s) < float(b.s))
	respawns.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.s) < float(b.s))


## Section 0, the clearing: a playable introduction without words.
func _intro() -> void:
	_section(0, "calm")
	_leg(26.0, 0.0, 0.0, 2.4, "dirt")
	_safe(start_s)
	_line(10.0, 22.0, 0.0, 0.0)
	_decor("sign", 4.0, -2.9, {"icon": "run"})
	# 1. Jump: a small stream, Lumo waits at the edge until SPRINGEN is pressed.
	var edge: float = _hole(2.8)
	waits.append({"s": edge - 0.8, "action": "jump", "auto": 4.0})
	coaches.append({"s0": edge - 9.0, "s1": edge + 3.0, "icon": "jump"})
	_arc(edge - 1.6, edge + 4.4, 0.0, 1.9, 4)
	_leg(22.0, 12.0, 0.6, 2.4, "dirt")
	_safe(edge + 4.0)
	# 2. Bounce: a jungle mushroom throws Lumo onto a mossy ledge.
	var ledge_at: float = _leg(30.0, -8.0, 0.0, 2.6, "dirt")
	_mushroom(ledge_at + 5.0, 0.0)
	coaches.append({"s0": ledge_at - 4.0, "s1": ledge_at + 7.0, "icon": "bounce"})
	_platform(ledge_at + 9.0, ledge_at + 24.0, 0.0, 1.9, 2.8, "moss")
	_arc(ledge_at + 5.5, ledge_at + 11.5, 0.0, 4.2, 4)
	_line(ledge_at + 13.0, ledge_at + 23.0, 0.0, 0.0, 3.8)
	# 3. Stomp: a crab ambles across; jump onto it.
	var crab_at: float = _leg(22.0, 6.0, 0.0, 2.4, "dirt")
	_enemy("crab", crab_at + 12.0, 0.0, 1.6, 1.4)
	coaches.append({"s0": crab_at + 2.0, "s1": crab_at + 13.0, "icon": "stomp"})
	_safe(crab_at + 3.0)
	# 4. Barrel: Lumo climbs in and is shot across a gully.
	var barrel_at: float = _leg(14.0, 0.0, 0.0, 2.4, "dirt")
	coaches.append({"s0": barrel_at + 2.0, "s1": barrel_at + 14.0, "icon": "barrel"})
	var gully: float = _hole(13.0)
	_barrel(gully - 2.0, 0.0, 1.1, gully + 17.0, 0.0, 1.4, 4.0, 1.4)
	_arc(gully + 1.0, gully + 12.0, 0.0, 5.0, 5, 2.0)
	_leg(16.0, 0.0, 0.0, 2.6, "dirt")
	_safe(gully + 16.0)
	intro_end = s - 4.0
	_decor("arch", intro_end, 0.0, {"look": "start"})


## Section 1, the root path: earth, roots, logs, crabs, a rope bridge, first branch.
func _root_path() -> void:
	_section(1, "calm")
	var a: float = _leg(30.0, 22.0, 2.0, 2.2, "dirt")
	_line(a + 4.0, a + 28.0, 0.0, 1.2)
	_decor("torch", a + 6.0, -2.6)
	var gap: float = _hole(3.2)
	_arc(gap - 2.0, gap + 5.0, 1.2, 2.0, 5)
	var b: float = _leg(26.0, -18.0, 0.0, 2.2, "dirt")
	_safe(b + 2.0)
	_enemy("crab", b + 12.0, 0.0, 1.5, 1.6, 0.6)
	_log(b + 21.0)
	_arc(b + 18.0, b + 24.0, 0.0, 2.0, 4)
	# Root climb with the first branch: mushrooms up to the canopy ledges (harder, more stars).
	var c: float = _leg(24.0, 15.0, 3.0, 2.4, "roots")
	_line(c + 3.0, c + 20.0, 0.0, -1.6)
	var fork: float = _leg(62.0, -10.0, 0.5, 4.6, "roots")
	branches.append({"s0": fork, "s1": fork + 62.0, "upper_lat": 2.6, "lower_lat": -2.0, "name": "Wurzelkrone"})
	_mushroom(fork + 6.0, 2.6, 15.0)
	_platform(fork + 10.0, fork + 19.0, 2.6, 1.3, 3.4, "branch")
	_platform(fork + 22.5, fork + 30.0, 2.6, 1.3, 3.8, "branch")
	_platform(fork + 34.5, fork + 44.0, 2.6, 1.3, 3.6, "branch", {"crumble": true})
	_platform(fork + 47.5, fork + 56.0, 2.6, 1.3, 3.4, "branch")
	_line(fork + 11.0, fork + 18.0, 2.6, 2.6, 4.6, 2.3, "upper")
	_arc(fork + 18.5, fork + 23.5, 2.6, 6.2, 3, 4.6, "upper")
	_line(fork + 24.0, fork + 29.0, 2.6, 2.6, 5.0, 2.3, "upper")
	_arc(fork + 30.0, fork + 35.5, 2.6, 6.4, 3, 5.0, "upper")
	_line(fork + 36.0, fork + 43.0, 2.6, 2.6, 4.8, 2.3, "upper")
	_letter("L", fork + 52.0, 2.6, 4.9)
	_gold(fork + 55.0, 2.6, 4.7, "upper")
	_line(fork + 8.0, fork + 56.0, -2.0, -2.0, 1.0, 4.0, "lower")
	_enemy("crab", fork + 26.0, -2.0, 1.3, 1.8)
	_log(fork + 40.0, -2.0, 2.0)
	_safe(fork + 4.0, -2.0)
	_safe(fork + 60.0)
	# The rope bridge over the ravine sags in the middle; a beetle trundles along it.
	var bridge: float = _leg(20.0, 0.0, -1.4, 1.3, "bridge", -16.0)
	_leg(20.0, 0.0, 1.4, 1.3, "bridge", -16.0)
	_enemy("beetle", bridge + 22.0, 0.0, 4.0, 0.9)
	_line(bridge + 3.0, bridge + 16.0, 0.0, 0.0)
	_line(bridge + 28.0, bridge + 37.0, 0.0, 0.0)
	_safe(bridge + 1.0)
	var d: float = _leg(26.0, 25.0, 1.0, 2.2, "dirt")
	_checkpoint(d + 8.0)
	_decor("torch", d + 6.0, 2.6)
	_decor("torch", d + 6.0, -2.6)
	# Stream with stepping stones.
	var e: float = _leg(14.0, 0.0, 0.0, 2.2, "dirt")
	_line(e + 2.0, e + 12.0, 0.0, 0.0)
	var stream: float = _hole(11.0)
	_platform(stream + 2.6, stream + 4.6, 0.0, 1.1, 0.0, "stone")
	_platform(stream + 6.8, stream + 8.6, 0.3, 1.1, 0.0, "stone")
	_arc(stream - 1.6, stream + 3.6, 0.0, 1.9, 3)
	_arc(stream + 4.4, stream + 7.6, 0.2, 1.9, 3)
	_arc(stream + 8.4, stream + 12.4, 0.0, 1.9, 3)
	_decor("waterfall", stream + 5.5, -9.0, {"height": 9.0, "width": 6.0})
	var f: float = _leg(30.0, -20.0, 0.0, 2.2, "dirt")
	_safe(f + 2.0)
	_enemy("crab", f + 10.0, 0.0, 1.5, 1.5, 1.2)
	_enemy("crab", f + 20.0, 0.0, 1.5, 1.5, 2.6)
	_line(f + 4.0, f + 26.0, 0.0, 0.0, 1.0, 3.0)
	# Hidden niche on the left, behind ferns: a gold star for the curious.
	var niche: float = _leg(22.0, 0.0, 0.0, 4.4, "dirt")
	_decor("niche", niche + 11.0, -3.6, {"length": 14.0})
	_gold(niche + 11.0, -3.6, 1.0, "niche")
	_line(niche + 6.0, niche + 16.0, -3.6, -3.6, 1.0, 2.5, "niche")
	var g: float = _hole(4.6)
	_arc(g - 2.0, g + 6.6, 0.0, 2.8, 5)
	var gate: float = _leg(30.0, 10.0, 0.0, 2.4, "dirt")
	_safe(gate + 2.0)
	_line(gate + 2.0, gate + 10.0, 0.0, 0.0)
	_checkpoint(gate + 18.0, true)
	_decor("puzzle_gate", gate + 19.8, 0.0)


## Section 2, the canopy walks: wooden stairs into the treetops, platforms, vines.
func _canopy_walk() -> void:
	_section(2, "action")
	var a: float = _leg(22.0, 0.0, 6.0, 1.6, "plank", -3.0)
	_line(a + 2.0, a + 20.0, 0.0, 0.0, 1.0, 2.2)
	var b: float = _leg(12.0, 30.0, 0.0, 2.0, "canopy", -18.0)
	_decor("torch", b + 2.0, 2.2)
	var hole1: float = _hole(4.4)
	_arc(hole1 - 2.0, hole1 + 6.4, 0.0, 2.8, 5)
	var c: float = _leg(10.0, 0.0, 0.0, 2.0, "canopy", -18.0)
	_safe(c + 1.5)
	# A leaf platform drifts sideways across the gap: wait, then go.
	var hole2: float = _hole(8.0)
	_platform(hole2 + 2.5, hole2 + 5.5, 0.0, 1.2, 0.0, "leaf", {"axis": "lat", "amp": 2.6, "rate": 1.2})
	_star(hole2 + 4.0, 0.0, 1.2)
	var d: float = _leg(12.0, -25.0, 0.0, 2.0, "canopy", -18.0)
	_safe(d + 2.0)
	_line(d + 2.0, d + 10.0, 0.0, 0.0)
	# The first vine over a wide gap.
	var swing: float = _hole(10.0)
	_vine(swing - 0.6, 0.0, 5.0, 0.8)
	_arc(swing + 1.0, swing + 9.0, 0.0, 2.6, 5, 1.6)
	var e: float = _leg(30.0, 0.0, 0.0, 1.5, "plank", -16.0)
	_safe(e + 2.0)
	_enemy("beetle", e + 15.0, 0.0, 6.0, 1.0)
	_line(e + 3.0, e + 27.0, 0.0, 0.0, 1.0, 3.0)
	# Crumbling planks: keep running!
	var crumble: float = _hole(14.0)
	for index in range(3):
		var from: float = crumble + 1.2 + float(index) * 4.3
		_platform(from, from + 3.1, 0.0, 1.2, 0.0, "plank", {"crumble": true})
		_star(from + 1.5, 0.0, 1.0)
	var f: float = _leg(16.0, 20.0, -1.0, 2.0, "canopy", -18.0)
	_safe(f + 2.0)
	_checkpoint(f + 10.0)
	# Second branch: a mushroom up to a perch and a zip line over the lower walk.
	var fork: float = _leg(70.0, -15.0, -2.0, 4.6, "canopy", -18.0)
	branches.append({"s0": fork, "s1": fork + 70.0, "upper_lat": 2.6, "lower_lat": -2.0, "name": "Seilrutsche"})
	_mushroom(fork + 5.0, 2.6, 15.0)
	_platform(fork + 9.0, fork + 16.0, 2.6, 1.4, 3.6, "branch")
	_zip(fork + 15.4, 2.6, 4.9, fork + 58.0, 2.6)
	# Stars and the U hang where Lumo's body passes on the zip line.
	var along: float = fork + 19.0
	while along < fork + 56.0:
		if absf(along - (fork + 37.0)) > 1.5:
			_star(along, 2.6, _zip_body(fork + 15.4, 4.9, fork + 58.0, 2.6, along), 1, "upper")
		along += 2.4
	_letter("U", fork + 37.0, 2.6, _zip_body(fork + 15.4, 4.9, fork + 58.0, 2.6, fork + 37.0))
	_line(fork + 6.0, fork + 64.0, -2.0, -2.0, 1.0, 4.2, "lower")
	_enemy("beetle", fork + 25.0, -2.0, 3.0, 1.1)
	_log(fork + 44.0, -2.0, 2.0)
	_enemy("crab", fork + 54.0, -2.0, 1.2, 1.7)
	_safe(fork + 3.0, -2.0)
	_safe(fork + 66.0)
	# The hidden bonus barrel waits in a hollow trunk on the right.
	var hollow: float = _leg(26.0, 10.0, 0.0, 4.2, "canopy", -18.0)
	_decor("niche", hollow + 13.0, 3.4, {"length": 12.0, "look": "trunk"})
	rides.append({"kind": "warp", "s": hollow + 14.0, "lat": 3.4, "h": 1.1, "ts": BONUS_S0 + 6.0, "tlat": 0.0, "th": 0.0, "bonus": true})
	_star(hollow + 9.0, 3.4, 1.0, 1, "niche")
	bonus["entry_s"] = hollow + 14.0
	bonus["return_s"] = hollow + 36.0
	_line(hollow + 3.0, hollow + 24.0, 0.0, -0.6)
	var hole3: float = _hole(6.2)
	_arc(hole3 - 2.4, hole3 + 8.0, -0.6, 3.0, 5)
	var g: float = _leg(18.0, 0.0, 0.0, 2.0, "canopy", -18.0)
	_safe(g + 2.0)
	_collapsing_bridge()
	# Second vine, then down the wooden stairs to the temple.
	var swing2: float = _hole(10.5)
	_vine(swing2 - 0.6, 0.0, 5.2, 0.82)
	_gold(swing2 + 5.5, 0.0, 3.4)
	var h: float = _leg(22.0, 25.0, -6.0, 1.6, "plank", -6.0)
	_safe(h + 2.0)
	_line(h + 3.0, h + 20.0, 0.0, 0.0, 1.0, 2.6)
	var i: float = _leg(24.0, -10.0, -2.0, 2.4, "dirt")
	_line(i + 2.0, i + 14.0, 0.0, 0.0)
	_checkpoint(i + 18.0)


## Section 3, the temple ruins: stairs, rolling coconuts, a barrel chain, the chase.
func _temple() -> void:
	_section(3, "calm")
	var a: float = _leg(26.0, 0.0, 6.0, 2.6, "stone")
	_enemy("coconut", a + 25.0, 0.0, 0.0, 6.0, 0.0, 24.0)
	_enemy("coconut", a + 25.0, -1.2, 0.0, 6.0, 12.0, 24.0)
	_line(a + 2.0, a + 22.0, 1.4, 1.4, 1.0, 2.6)
	_decor("statue", a + 13.0, -4.6)
	_decor("torch", a + 2.0, 3.0)
	_decor("torch", a + 2.0, -3.0)
	var terrace: float = _leg(24.0, 18.0, 0.0, 3.4, "stone")
	_safe(terrace + 2.0)
	_line(terrace + 2.0, terrace + 12.0, 0.0, 0.0)
	# Upper ledge with the M, reached from a mushroom on the terrace.
	branches.append({"s0": terrace + 4.0, "s1": terrace + 19.0, "upper_lat": -2.2, "lower_lat": 0.0, "name": "Tempelsims"})
	_mushroom(terrace + 10.0, -2.2, 15.0)
	_platform(terrace + 13.0, terrace + 19.0, -2.2, 1.2, 3.4, "ruin")
	_letter("M", terrace + 17.5, -2.2, 4.7)
	_arc(terrace + 10.5, terrace + 16.5, -2.2, 4.8, 3, 1.4, "upper")
	# The barrel chain over the chasm.
	var chasm: float = _hole(34.0)
	_barrel(chasm - 1.6, 0.0, 1.1, chasm + 11.0, 0.0, 3.4, 3.0, 1.1)
	_barrel(chasm + 11.0, 0.0, 3.4, chasm + 22.0, 0.0, 2.6, 2.6, 1.1)
	_barrel(chasm + 22.0, 0.0, 2.6, chasm + 38.0, 0.0, 1.0, 3.2, 1.1)
	_arc(chasm + 1.0, chasm + 10.0, 0.0, 5.6, 4, 2.4)
	_arc(chasm + 12.0, chasm + 21.0, 0.0, 5.4, 4, 3.6)
	_arc(chasm + 23.0, chasm + 33.0, 0.0, 5.0, 4, 2.6)
	var b: float = _leg(22.0, -20.0, 0.0, 2.6, "stone")
	_safe(b + 4.0)
	_checkpoint(b + 12.0, true)
	_decor("puzzle_gate", b + 13.8, 0.0)
	# Pillar hall: weave between toppled stones.
	var hall: float = _leg(40.0, 12.0, 0.0, 2.8, "stone")
	for index in range(4):
		var rock_lat: float = 1.4 if index % 2 == 0 else -1.4
		blockers.append(
			{"s": hall + 7.0 + float(index) * 8.0, "lat": rock_lat, "radius": 0.9, "height": 1.8, "kind": "rock", "amp": 0.0, "rate": 0.0, "phase": 0.0}
		)
		_line(hall + 4.0 + float(index) * 8.0, hall + 9.0 + float(index) * 8.0, -rock_lat, -rock_lat, 1.0, 2.5)
	_enemy("crab", hall + 38.0, 0.0, 1.8, 1.6)
	_safe(hall + 2.0)
	_ember_leap()
	# The chase: a mossy stone ball rolls after Lumo down the long gallery.
	var gallery: float = _leg(24.0, 0.0, -1.0, 2.4, "stone")
	_safe(gallery + 3.0)
	_leg(26.0, 14.0, -2.0, 2.4, "stone")
	_log(gallery + 22.0)
	_line(gallery + 6.0, gallery + 48.0, 0.0, 0.0, 1.0, 3.0)
	var jump1: float = _hole(3.4, -0.6)
	_arc(jump1 - 2.0, jump1 + 5.4, 0.0, 2.2, 4)
	var g2: float = _leg(26.0, -16.0, -1.5, 2.4, "stone")
	_log(g2 + 13.0)
	_line(g2 + 4.0, g2 + 24.0, 0.0, 0.0, 1.0, 3.0)
	var collapse: float = _hole(4.4, -0.8)
	_arc(collapse - 2.0, collapse + 6.4, 0.0, 2.6, 5)
	var after: float = _leg(18.0, 0.0, 0.0, 2.6, "stone")
	chase = {"s0": gallery + 4.0, "s1": collapse + 2.0, "gap": 14.0, "near": 6.5, "factor": 0.82, "radius": 1.5, "respawn": gallery + 3.0}
	_safe(after + 3.0)
	_checkpoint(after + 10.0)


## Section 4, the waterfall cave: wet stones, bobbing lily pads, vines, crystal ledges.
func _waterfall_cave() -> void:
	_section(4, "calm")
	var a: float = _leg(24.0, 15.0, -3.0, 2.2, "cave")
	ceilings.append(Vector3(a, a + 300.0, 6.4))
	_decor("cave_mouth", a + 1.0, 0.0)
	_line(a + 3.0, a + 22.0, 0.0, 0.0)
	_enemy("beetle", a + 16.0, 0.0, 4.0, 1.1)
	_decor("waterfall", a + 30.0, 0.0, {"height": 8.0, "width": 7.0, "curtain": true})
	var pool: float = _hole(13.0)
	_platform(pool + 2.5, pool + 5.0, 0.0, 1.3, 0.0, "lily", {"axis": "h", "amp": 0.6, "rate": 1.6})
	_platform(pool + 7.5, pool + 10.0, 0.0, 1.3, 0.0, "lily", {"axis": "h", "amp": 0.6, "rate": 1.6, "phase": 2.0})
	_arc(pool - 1.6, pool + 3.8, 0.0, 2.0, 3)
	_arc(pool + 4.4, pool + 8.6, 0.0, 2.0, 3)
	_arc(pool + 9.4, pool + 14.0, 0.0, 2.0, 3)
	var b: float = _leg(22.0, -20.0, 0.0, 2.2, "cave")
	_safe(b + 2.0)
	_line(b + 2.0, b + 18.0, 0.0, 0.0)
	var river: float = _hole(10.0)
	_vine(river - 0.6, 0.0, 5.0, 0.8)
	_arc(river + 1.0, river + 9.0, 0.0, 2.6, 5, 1.6)
	var c: float = _leg(20.0, 18.0, 0.0, 2.2, "cave")
	_safe(c + 2.0)
	_enemy("crab", c + 12.0, 0.0, 1.5, 1.8)
	_checkpoint(c + 18.0, true)
	_decor("puzzle_gate", c + 19.8, 0.0)
	# Crystal ledges above with the O; the lower way has wet stones and beetles.
	var fork: float = _leg(56.0, -12.0, 0.0, 4.4, "cave")
	branches.append({"s0": fork, "s1": fork + 56.0, "upper_lat": -2.4, "lower_lat": 2.0, "name": "Kristallsims"})
	_mushroom(fork + 6.0, -2.4, 15.0)
	_platform(fork + 10.0, fork + 17.0, -2.4, 1.2, 3.2, "crystal")
	_platform(fork + 21.0, fork + 27.0, -2.4, 1.2, 3.6, "crystal", {"axis": "h", "amp": 0.7, "rate": 1.3})
	_platform(fork + 31.0, fork + 40.0, -2.4, 1.2, 3.4, "crystal")
	_letter("O", fork + 38.0, -2.4, 4.7)
	_line(fork + 11.0, fork + 16.0, -2.4, -2.4, 4.4, 2.5, "upper")
	_line(fork + 22.0, fork + 26.0, -2.4, -2.4, 4.8, 2.0, "upper")
	_gold(fork + 34.0, -2.4, 4.6, "upper")
	_line(fork + 6.0, fork + 52.0, 2.0, 2.0, 1.0, 4.0, "lower")
	_enemy("beetle", fork + 22.0, 2.0, 3.0, 1.2)
	_enemy("beetle", fork + 38.0, 2.0, 3.0, 1.2, 1.5)
	_safe(fork + 3.0, 2.0)
	_safe(fork + 54.0)
	_waterfall_slide()
	var d: float = _leg(26.0, 20.0, 1.0, 2.2, "cave")
	_line(d + 2.0, d + 22.0, 0.0, 0.0)
	var hop: float = _hole(5.0)
	_arc(hop - 2.0, hop + 7.0, 0.0, 2.8, 5)
	var station: float = _leg(30.0, 0.0, 0.0, 2.6, "station")
	_safe(station + 2.0)
	_decor("torch", station + 8.0, 2.8)
	_decor("torch", station + 8.0, -2.8)
	_checkpoint(station + 14.0)
	_decor("cart_stop", station + 24.0, 0.0)


## Section 5, the mine cart ride: rails up and down through the mountain and out.
func _mine_ride() -> void:
	_section(5, "action")
	var board: float = s
	cart = {"s0": board + 1.0, "lat": 0.0}
	var pieces: Array = [
		[26.0, 0.0, -4.0, ""], [20.0, 25.0, 0.0, "gap4"], [24.0, -20.0, 4.0, ""], [22.0, 0.0, -6.0, "gap4"],
		[30.0, 35.0, 0.0, "stars"], [20.0, 0.0, 3.0, "gap5"], [24.0, -30.0, -3.0, ""], [26.0, 0.0, -5.0, "gap4"],
		[30.0, 25.0, 2.0, "stars"], [20.0, 0.0, 0.0, "gap5"], [28.0, -20.0, -4.0, ""], [24.0, 10.0, 0.0, "gap4"],
	]
	var count: int = 0
	for piece in pieces:
		var from: float = _leg(float(piece[0]), float(piece[1]), float(piece[2]), 1.3, "rail", -2.0)
		_safe(from + 2.0, 0.0, true)
		_line(from + 3.0, from + float(piece[0]) - 4.0, 0.0, 0.0, 1.2, 3.0)
		var kind: String = str(piece[3])
		if kind.begins_with("gap"):
			var gap_length: float = 4.0 if kind == "gap4" else 5.0
			var hole: float = _hole(gap_length)
			_arc(hole - 3.0, hole + gap_length + 3.0, 0.0, 3.0, 5, 1.2)
		elif kind == "stars":
			_gold(from + float(piece[0]) * 0.5, 0.0, 2.6)
		count += 1
		if count == 6:
			_checkpoint(s - 6.0)
			respawns[respawns.size() - 1]["cart"] = true
	var out: float = _leg(10.0, 0.0, 0.0, 1.3, "rail", -2.0)
	_safe(out + 1.0, 0.0, true)
	cart["s1"] = out + 9.0
	var last: float = _leg(40.0, 0.0, 0.0, 3.0, "stone")
	_line(last + 3.0, last + 20.0, 0.0, 0.0)
	finish_s = last + 26.0
	_decor("finish_temple", finish_s + 6.0, 0.0)


# ------------------------------------------------------------------ adventure passages
# The numbers (course time, before PATH_TIME_SCALE): a held jump flies 0.877 s
# (10 m/s up, hold gravity 20 for 0.45 s, then 30 up / 32 down), an unheld one
# 0.656 s. At Lumo's pace of 8.5 m/s that is 7.5 m held and 5.6 m tapped; a
# really slow runner (40 % = 3.4 m/s) gets 3.0 m. lumo_run_adventure_regression
# measures the same numbers with the real motion model.


## Passage 1 (temple): the glowing ember stream. Left the old slab reaches far
## into the stream (4.2 m to jump), right is the full width (6.6 m, gold stars).
func _ember_leap() -> void:
	var approach: float = _leg(18.0, -8.0, 0.0, 4.2, "stone")
	_line(approach + 2.0, approach + 16.0, 0.0, 0.0, 1.0, 3.0)
	var run_up: float = _leg(28.0, 0.0, 0.0, 4.2, "stone")
	_safe(run_up + 2.0)
	_line(run_up + 6.0, run_up + 25.0, -2.2, -2.2, 1.0, 3.2, "lower")
	_line(run_up + 6.0, run_up + 25.0, 2.2, 2.2, 1.0, 3.2, "upper")
	var ember: float = _hole(6.6)
	_platform(ember + 4.2, ember + 6.6, -2.2, 1.4, 0.0, "ruin", {"tempo": true})
	_arc(ember - 0.6, ember + 4.8, -2.2, 2.4, 3, 1.0, "lower")
	_arc(ember - 0.8, ember + 7.6, 2.2, 3.0, 5, 1.0, "upper")
	_gold(ember + 3.4, 2.2, 2.9, "upper")
	_decor("glut", ember + 3.3, 0.0, {"s0": ember, "s1": ember + 6.6})
	_decor("torch", run_up + 20.0, -5.0)
	_decor("torch", run_up + 20.0, 5.0)
	_passage(
		"Glutbach-Sprung", ember, 6.6, {"lat": -2.2, "gap": 4.2}, {"lat": 2.2, "gap": 6.6},
		"Glutbach! Mit Schwung springen – links ist der Sprung kürzer.", TUNING.PATH_CRUISE + 1.0
	)
	var land: float = _leg(18.0, 10.0, 0.0, 3.0, "stone")
	_line(land + 3.0, land + 15.0, 0.0, 0.0, 1.0, 3.0)
	_safe(land + 4.0)


## Passage 2 (treetops): the collapsing rope bridge. Every plank gives way soon
## after Lumo steps on it - keep running! Left planks hold 0.9 s and end 3.5 m
## before the far side; right planks hold only 0.45 s and end 5 m before it.
func _collapsing_bridge() -> void:
	var deck: float = _leg(26.0, 0.0, 0.0, 2.4, "canopy", -18.0)
	_line(deck + 3.0, deck + 24.0, 0.0, 0.0, 1.0, 3.0)
	_safe(deck + 2.0)
	var ravine: float = _hole(24.0)
	for k in range(5):
		var from: float = ravine + float(k) * 4.0
		_platform(from, from + (4.5 if k == 4 else 4.0), -1.1, 1.1, 0.0, "plank", {"crumble": true, "hold": 0.9, "tempo": true})
		_platform(from, from + (3.0 if k == 4 else 4.0), 1.1, 1.1, 0.0, "plank", {"crumble": true, "hold": 0.45, "tempo": true})
	_line(ravine + 1.0, ravine + 19.0, -1.1, -1.1, 1.0, 2.6, "lower")
	_line(ravine + 1.0, ravine + 17.0, 1.1, 1.1, 1.0, 2.0, "upper")
	_arc(ravine + 19.8, ravine + 25.0, -1.1, 2.4, 3, 1.0, "lower")
	_arc(ravine + 18.4, ravine + 25.4, 1.1, 3.0, 4, 1.0, "upper")
	_gold(ravine + 21.5, 1.1, 2.9, "upper")
	_passage(
		"Einsturzbrücke", ravine, 24.0, {"lat": -1.1, "gap": 3.5, "hold": 0.9, "plank": 4.0},
		{"lat": 1.1, "gap": 5.0, "hold": 0.45, "plank": 4.0},
		"Die Brücke stürzt ein! Nicht stehen bleiben – lauf drüber!", TUNING.PATH_CRUISE + 1.5
	)
	var far: float = _leg(16.0, 15.0, 0.0, 2.0, "canopy", -18.0)
	_line(far + 3.0, far + 14.0, 0.0, 0.0)
	_safe(far + 3.0)


## Passage 3 (cave): the waterfall slide with two chutes. Downhill Lumo gets
## faster by himself; at the bottom the pool. Left a lily pad halves the jump
## (3.8 m, then 3.1 m), right one long leap of 8.5 m to the crystal bank.
func _waterfall_slide() -> void:
	var top: float = _leg(22.0, 0.0, 0.0, 4.0, "cave")
	_line(top + 3.0, top + 20.0, 0.0, 0.0)
	_safe(top + 3.0)
	_decor("waterfall", top + 16.0, 6.2, {"height": 10.0, "width": 5.0})
	var chute: float = _leg(30.0, 0.0, -6.5, 4.0, "slide")
	_safe(chute + 2.0)
	_line(chute + 2.0, chute + 28.0, -2.0, -2.0, 1.0, 3.0, "lower")
	_line(chute + 2.0, chute + 28.0, 2.0, 2.0, 1.0, 3.0, "upper")
	var pool: float = _hole(8.5)
	_platform(pool + 3.8, pool + 5.4, -2.0, 1.3, 0.0, "lily", {"axis": "h", "amp": 0.2, "rate": 1.4, "tempo": true})
	_arc(pool - 0.6, pool + 4.4, -2.0, 2.2, 3, 1.0, "lower")
	_arc(pool + 5.2, pool + 9.0, -2.0, 2.0, 3, 1.0, "lower")
	_arc(pool - 0.8, pool + 9.4, 2.0, 3.2, 5, 1.0, "upper")
	_gold(pool + 4.3, 2.0, 3.1, "upper")
	_passage(
		"Wasserfall-Rutsche", pool, 8.5, {"lat": -2.0, "gap": 3.8}, {"lat": 2.0, "gap": 8.5, "downhill": TUNING.GRADE_MAX},
		"Wasserfall-Rutsche! Links mit dem Seerosenblatt, rechts der große Sprung.", TUNING.PATH_CRUISE * 0.95
	)
	var bank: float = _leg(18.0, 12.0, 0.0, 2.6, "cave")
	_line(bank + 3.0, bank + 16.0, 0.0, 0.0)
	_safe(bank + 3.0)


## The golden treasure hall, reached only through the hidden barrel.
func _bonus_room() -> void:
	var saved: float = s
	s = BONUS_S0
	bonus["s0"] = s
	var hall: float = _bonus_leg(80.0)
	for row in range(5):
		var lat: float = -2.0 + float(row)
		_line(hall + 8.0, hall + 34.0, lat, lat, 1.0 + 0.4 * float(row % 2), 3.2, "bonus")
	_mushroom(hall + 40.0, 0.0, 15.5)
	bounces[bounces.size() - 1]["look"] = "gold"
	_arc(hall + 40.5, hall + 50.0, 0.0, 4.6, 6, 1.4, "bonus")
	for lat in [-2.0, 2.0]:
		_gold(hall + 58.0, lat, 1.2, "bonus")
	_line(hall + 60.0, hall + 70.0, 0.0, 0.0, 1.0, 2.5, "bonus")
	rides.append(
		{"kind": "warp", "s": hall + 74.0, "lat": 0.0, "h": 1.1, "ts": float(bonus.return_s), "tlat": 0.0, "th": 0.0, "bonus": false}
	)
	bonus["s1"] = s
	_safe(hall + 2.0)
	s = saved


func _bonus_leg(length_m: float) -> float:
	var from: float = s
	bonus_legs.append({"s0": from, "length": length_m, "turn": 0.0, "rise": 0.0, "half": 3.2, "surface": "gold", "ground": 0.0})
	surfaces.append({"s0": from, "s1": from + length_m, "kind": "gold", "half": 3.2, "ground": 0.0})
	s += length_m
	return from
