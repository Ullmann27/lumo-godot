extends RefCounted
## What is under one kart's tyres right now, beyond the course-wide road style
## (kart_fx_surface_styles): the red-white kerbs at the road edge, puddles laid
## by the detail layer, and loose verge beyond the asphalt where a section has
## no rail. Read-only geometry queries; the race owns position and rules.
##
## kind: "road" | "curb" | "puddle" | "verge"
## side: -1 / +1 the touching side (curb, verge), 0 on the road or in a puddle
## depth: 0..1 how far onto the kerb / verge the outer tyre is
## wet: 0..1 how many rear tyres stand in water (puddle)

const ACTION = preload("res://scripts/games/kart_action_course.gd")
const PASSAGES = preload("res://scripts/games/kart_passages.gd")
const THRILLS = preload("res://scripts/games/kart_track_thrills.gd")
const LOOP = preload("res://scripts/games/kart_physical_loop.gd")

## Kerb boxes of kart_world._road(): 0.48 m wide, centred at lateral 5.5.
const CURB_INNER := 5.26
const CURB_OUTER := 5.74
## The classic road ribbon (kart_world.WIDTH); decks and custom roads differ.
const CLASSIC_WIDTH := 10.8
## Rear tyre centre to kart centre (production karts, kart_rail_gap_probe ~0.98 outer edge).
const TYRE_HALF := 0.72
const TYRE_RADIUS := 0.26
## Courses with their own road geometry (no classic kerbs).
const NO_CURB_TRACKS: Array[String] = [
	"bergwelt", "jungle_emerald_3600", "riesengarten_2400", "windwerk_3000"
]
## World meta written by the detail layer: Array of Vector4(distance, lateral,
## half length along, half width across) per puddle decal (a centred square).
const WET_META := &"kart_wet_spots"

const ROAD := {"kind": "road", "side": 0.0, "depth": 0.0, "wet": 0.0}


## Ground under a kart at road [param distance] and [param lateral] (metres).
static func sample(world, distance: float, lateral: float, airborne: bool) -> Dictionary:
	if world == null or airborne or world.get("curve") == null:
		return ROAD
	var length: float = float(world.length)
	var d: float = fposmod(distance, maxf(length, 1.0))
	var wet: float = wet_share(world, d, lateral)
	if wet > 0.0:
		return {"kind": "puddle", "side": 0.0, "depth": wet, "wet": wet}
	var side: float = signf(lateral)
	var outer: float = absf(lateral) + TYRE_HALF + TYRE_RADIUS * 0.5
	var width: float = float(world.road_width_at(d))
	if absf(lateral) > width * 0.48 and side != 0.0:
		var past: float = absf(lateral) - width * 0.48
		return {"kind": "verge", "side": side, "depth": clampf(past / 1.2, 0.2, 1.0), "wet": 0.0}
	if outer > CURB_INNER and has_curb(world, d, side):
		var on_curb: float = clampf((outer - CURB_INNER) / (CURB_OUTER - CURB_INNER), 0.0, 1.0)
		return {"kind": "curb", "side": side, "depth": maxf(0.25, on_curb), "wet": 0.0}
	return ROAD


## Does the classic kerb run along [param side] at [param d]? Mirrors the
## conditions under which kart_world._road() places its kerb boxes.
static func has_curb(world, d: float, side: float) -> bool:
	if side == 0.0 or str(world.track_id) in NO_CURB_TRACKS:
		return false
	if absf(float(world.road_width_at(d)) - CLASSIC_WIDTH) > 0.05:
		return false
	if world.in_gap(d) or PASSAGES.void_at(world, d):
		return false
	if ACTION.open_side(world.action, d) == side:
		return false
	if THRILLS.cuts_side(world, d, side):
		return false
	return not LOOP.rail_open(world.loop_layout, d, side)


## 0, 0.5 or 1: share of the two rear tyres inside a puddle decal.
static func wet_share(world, d: float, lateral: float) -> float:
	if not world.has_meta(WET_META):
		return 0.0
	var spots: Array = world.get_meta(WET_META)
	var hits: int = 0
	for tyre in [lateral - TYRE_HALF, lateral + TYRE_HALF]:
		for spot in spots:
			var s: Vector4 = spot
			if absf(d - s.x) <= s.z and absf(tyre - s.y) <= s.w:
				hits += 1
				break
	return float(hits) * 0.5


## Record one puddle decal (called by the detail layer while it builds).
static func add_wet_spot(world, d: float, lateral: float, along: float, across: float) -> void:
	if world == null:
		return
	var spots: Array = world.get_meta(WET_META) if world.has_meta(WET_META) else []
	# The decal is a turned oval: its inscribed circle (inner 80 %) is reliably water.
	var radius: float = minf(along, across) * 0.4
	spots.append(Vector4(fposmod(d, maxf(float(world.length), 1.0)), lateral, radius, radius))
	world.set_meta(WET_META, spots)


static func clear_wet_spots(world) -> void:
	if world != null and world.has_meta(WET_META):
		world.remove_meta(WET_META)
