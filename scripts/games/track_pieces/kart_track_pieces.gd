extends RefCounted
## Reusable Lumo Kart track pieces, placed in track metres by markers.
## Interface and marker convention: docs/kart_track_pieces.md.
##
## Sources of markers (merged, in this order):
## 1. Node3D children named PieceMarker_<type>_<n> under a "TrackPieceMarkers"
##    node of the kart world (collected before the world rebuilds itself),
## 2. track definition key "track_pieces" (Array of Dictionaries),
## 3. world meta "track_piece_markers" (same Dictionary format).
## Dictionary format: {"type", "distance", "lane" (optional), "params" (optional)}.
##
## Pieces:
## - gap_ramp:    ramp over a real gap with a marked landing zone (precision
##                flight model, same speed hint, cloud rescue when short),
## - narrow:      symmetric bottleneck with physical walls, tapered in and out,
##                hazard stripes, floor chevrons and a warning sign,
## - hazard_zone: lava (slows down) or ice (low grip) on part of the road,
##                never the full width, always with a glowing border and sign.

const PRECISION = preload("res://scripts/games/kart_precision_jump.gd")
const ACTION = preload("res://scripts/games/kart_action_course.gd")
const MARKER_ROOT: String = "TrackPieceMarkers"
const MARKER_PREFIX: String = "PieceMarker_"
const META_KEY: String = "track_piece_markers"
const PIECES_META: String = "track_pieces"
const TYPES: Array[String] = ["gap_ramp", "narrow", "hazard_zone"]
const DEFAULTS: Dictionary = {
	"gap_ramp":
	{
		"ramp_length": 12.0, "height": 2.6, "gap_length": 10.0, "landing_length": 18.0,
		"gravity": 14.0
	},
	"narrow": {"length": 26.0, "open_width": 6.0, "taper": 8.0},
	"hazard_zone": {"length": 36.0, "width": 4.2, "kind": "lava"},
}
## Children must always have a safe way through.
const MIN_OPEN_WIDTH: float = 5.0
const MAX_ZONE_WIDTH_SHARE: float = 0.6
const WARNING_LEAD_M: float = 32.0
const CLEARANCE: float = 14.0
## Lava: speed is pulled towards this share of the entry speed (no stop).
const LAVA_SPEED_SHARE: float = 0.62
const LAVA_DECELERATION: float = 9.0
## Ice: share of the new velocity direction adopted per tick (rest slides on).
const ICE_GRIP: float = 0.18
const LAVA_COLOR: Color = Color("ff5a1f")
const ICE_COLOR: Color = Color("9fe8ff")
const WARN_YELLOW: Color = Color("ffd23a")
const WARN_DARK: Color = Color("1b1d26")


## Reads marker nodes before KartWorld.build() frees its children.
static func collect_markers(world) -> Array:
	var result: Array = []
	var holder: Node = world.get_node_or_null(MARKER_ROOT)
	if holder != null:
		for child in holder.get_children():
			if not str(child.name).begins_with(MARKER_PREFIX):
				continue
			var type: String = str(child.name).trim_prefix(MARKER_PREFIX).rsplit("_", true, 1)[0]
			result.append(
				{
					"type": type,
					"distance": float(child.get_meta("piece_distance", -1.0)),
					"lane": float(child.get_meta("piece_lane", 0.0)),
					"params": child.get_meta("piece_params", {}),
					"name": str(child.name),
				}
			)
	return result


## Resolves markers into pieces, merges their contact data into the world
## (precision kickers, wall limits) and stores them as world meta.
static func plan(world, node_markers: Array) -> Array:
	var markers: Array = node_markers.duplicate()
	markers.append_array(world.definition.get("track_pieces", []))
	markers.append_array(world.get_meta(META_KEY, []))
	var pieces: Array = []
	var blocked: Array = blocked_ranges(world)
	for marker in markers:
		var piece: Dictionary = resolve(world, marker)
		if piece.is_empty():
			continue
		var span := Vector2(float(piece.start) - WARNING_LEAD_M, float(piece.end))
		var conflict: bool = false
		for range_value in blocked:
			if span.x < range_value.y and span.y > range_value.x:
				conflict = true
		if conflict:
			push_warning("[TrackPieces] %s at %.0f m overlaps another element; skipped" % [piece.type, piece.start])
			continue
		blocked.append(span)
		pieces.append(piece)
		if piece.type == "gap_ramp":
			world.action.kickers.append(piece.kicker)
	world.set_meta(PIECES_META, pieces)
	return pieces


## Full piece description with defaults applied; empty when invalid.
static func resolve(world, marker: Dictionary) -> Dictionary:
	var type: String = str(marker.get("type", ""))
	if not type in TYPES:
		push_warning("[TrackPieces] unknown piece type '%s'" % type)
		return {}
	var start: float = float(marker.get("distance", -1.0))
	if start < 0.0 or start >= float(world.length):
		push_warning("[TrackPieces] %s needs a distance inside the lap" % type)
		return {}
	var params: Dictionary = DEFAULTS[type].duplicate()
	params.merge(marker.get("params", {}), true)
	var piece: Dictionary = {
		"type": type, "start": start, "lane": float(marker.get("lane", 0.0)), "params": params
	}
	match type:
		"gap_ramp":
			piece.kicker = _gap_kicker(world, start, params)
			piece.end = float(piece.kicker.take_off) + float(params.gap_length) + float(params.landing_length)
		"narrow":
			params.open_width = maxf(MIN_OPEN_WIDTH, float(params.open_width))
			piece.end = start + float(params.length)
		"hazard_zone":
			var limit: float = float(world.road_width) * MAX_ZONE_WIDTH_SHARE
			params.width = minf(float(params.width), limit)
			var half_road: float = float(world.road_width) * 0.5
			var half: float = float(params.width) * 0.5
			piece.lane = clampf(piece.lane, -half_road + half, half_road - half)
			piece.end = start + float(params.length)
	return piece


static func _gap_kicker(world, start: float, params: Dictionary) -> Dictionary:
	var ramp_length: float = float(params.ramp_length)
	var height: float = float(params.height)
	var gap: float = float(params.gap_length)
	var take_off: float = start + ramp_length
	var rise: float = world.position_at(take_off + gap).y - world.position_at(take_off).y
	var kicker: Dictionary = {
		"start": start,
		"take_off": take_off,
		"length": ramp_length,
		"height": height,
		"angle": atan2(height, ramp_length),
		"flight_gravity": float(params.gravity),
		"lift_bonus": 0.0,
		"max_lift": 1000.0,
		"precision_jump": true,
		"landing_min": gap,
		"landing_max": gap + float(params.landing_length),
		"landing_slope": rise / gap,
		"gap_start": take_off + 0.5,
		"gap_end": take_off + gap,
		"stunt": true,
		"track_piece": true,
	}
	kicker["rival_speed"] = PRECISION.speed_for_distance(gap + float(params.landing_length) * 0.5, kicker)
	return kicker


## Every range a new piece must avoid (start/finish, tunnel, jump, loop,
## action-course elements and already planned pieces incl. warning lead).
static func blocked_ranges(world) -> Array:
	var blocked: Array = ACTION._blocked_ranges(world, float(world.length))
	for kicker in world.action.get("kickers", []):
		blocked.append(Vector2(float(kicker.start) - WARNING_LEAD_M, float(kicker.take_off) + 34.0))
	for key in ["pads", "dives", "edges"]:
		for entry in world.action.get(key, []):
			blocked.append(Vector2(float(entry.start), float(entry.end)))
	for gate in world.action.get("gates", []):
		blocked.append(Vector2(float(gate.distance) - 8.0, float(gate.distance) + 8.0))
	for piece in pieces_of(world):
		blocked.append(Vector2(float(piece.start) - WARNING_LEAD_M, float(piece.end)))
	return blocked


## First free start at or after wish (2 m steps) for a piece of this span
## (warning lead included); -1 when the lap has no room. Helps marker authors.
static func free_distance(world, wish: float, span: float, avoid: Array = []) -> float:
	var blocked: Array = blocked_ranges(world)
	blocked.append_array(avoid)
	var length: float = float(world.length)
	var start: float = maxf(wish, WARNING_LEAD_M + 40.0)
	while start + span < length - 40.0:
		var free: bool = true
		for range_value in blocked:
			if start - WARNING_LEAD_M < range_value.y + CLEARANCE and start + span > range_value.x - CLEARANCE:
				free = false
				break
		if free:
			return start
		start += 2.0
	return -1.0


static func pieces_of(world) -> Array:
	return world.get_meta(PIECES_META, []) if world.has_meta(PIECES_META) else []


## Distance from the centre line to the wall: narrowed inside a bottleneck.
static func wall_lateral(world, distance: float, base: float) -> float:
	var result: float = base
	for piece in pieces_of(world):
		if piece.type != "narrow":
			continue
		var into: float = distance - float(piece.start)
		var length: float = float(piece.params.length)
		if into < 0.0 or into > length:
			continue
		var taper: float = minf(float(piece.params.taper), length * 0.5)
		var t: float = clampf(minf(into, length - into) / maxf(taper, 0.001), 0.0, 1.0)
		var narrowed: float = float(piece.params.open_width) * 0.5
		result = minf(result, lerpf(base, narrowed, t * t * (3.0 - 2.0 * t)))
	return result


## The hazard zone under a road position, or {}.
static func zone_at(world, distance: float, lateral: float) -> Dictionary:
	for piece in pieces_of(world):
		if piece.type != "hazard_zone":
			continue
		if distance < float(piece.start) or distance > float(piece.end):
			continue
		if absf(lateral - float(piece.lane)) <= float(piece.params.width) * 0.5:
			return piece
	return {}


## Player effect per physics step; called by the race after its own events.
## Returns the active zone kind ("" outside zones) for HUD/tests.
static func race_tick(game, delta: float) -> String:
	if not is_instance_valid(game.world) or game.airborne:
		return ""
	var at: float = fposmod(game.previous_road_distance, game.track_length)
	var zone: Dictionary = zone_at(game.world, at, game.lane)
	var kind: String = str(zone.get("params", {}).get("kind", "")) if not zone.is_empty() else ""
	var previous: Vector3 = game.get_meta(&"track_piece_velocity", game.physical_velocity)
	match kind:
		"lava":
			if game.shield_time <= 0.0:
				# Smoothly down to a share of the entry speed and held there:
				# slower, never stopped, never thrown back.
				var entry: float = float(game.get_meta(&"track_piece_entry_speed", game.speed))
				var limit: float = float(game.get_meta(&"track_piece_lava_limit", entry))
				limit = move_toward(limit, entry * LAVA_SPEED_SHARE, LAVA_DECELERATION * delta)
				game.set_meta(&"track_piece_lava_limit", limit)
				game.speed = minf(game.speed, limit)
				game.message.text = "Heiße Lava! Fahr auf den hellen Weg."
		"ice":
			var target: Vector3 = game.physical_velocity
			game.physical_velocity = previous.lerp(target, ICE_GRIP).limit_length(target.length())
			game.message.text = "Rutschiges Eis! Sanft lenken."
	if kind != "lava":
		game.set_meta(&"track_piece_entry_speed", game.speed)
		game.set_meta(&"track_piece_lava_limit", game.speed)
	game.set_meta(&"track_piece_velocity", game.physical_velocity)
	return kind


## Geometry and warning signals for every planned piece.
static func build(world) -> void:
	for piece in pieces_of(world):
		match piece.type:
			"gap_ramp":
				_warning_sign(world, float(piece.start) - WARNING_LEAD_M, "SPRUNG!\nTempo halten", Color("41dcff"))
			"narrow":
				_build_narrow(world, piece)
			"hazard_zone":
				_build_zone(world, piece)


static func _build_narrow(world, piece: Dictionary) -> void:
	var start: float = float(piece.start)
	var length: float = float(piece.params.length)
	var along: float = start
	var index: int = 0
	while along <= start + length:
		var basis: Basis = world.frame(along)
		var wall: float = wall_lateral(world, along, float(world.WALL_LATERAL))
		var outer: float = float(world.road_width_at(along)) * 0.5 + 0.65
		for side in [-1.0, 1.0]:
			var width: float = maxf(0.2, outer - wall)
			var center: float = side * (wall + width * 0.5)
			var stripe: Color = WARN_YELLOW if index % 2 == 0 else WARN_DARK
			world._prop("box", world.position_at(along, center) + basis.y * 0.45, Vector3(width, 0.9, 1.02), Color("e9eef2"), basis)
			world._prop("box", world.position_at(along, side * (wall + 0.03)) + basis.y * 0.45, Vector3(0.08, 0.92, 1.02), stripe, basis, index % 2 == 0)
			world._prop("box", world.position_at(along, center) + basis.y * 0.93, Vector3(width, 0.06, 1.02), Color("ff4a3c"), basis, true)
		along += 1.0
		index += 1
	# Floor chevrons pointing into the gap.
	for i in range(5):
		var d: float = start - 18.0 + float(i) * 3.5
		var basis: Basis = world.frame(d)
		for side in [-1.0, 1.0]:
			var tilted: Basis = basis.rotated(basis.y, -side * 0.6)
			world._prop("box", world.position_at(d, side * 3.6) + basis.y * 0.03, Vector3(0.32, 0.03, 1.6), WARN_YELLOW, tilted, true)
	_warning_sign(world, start - WARNING_LEAD_M, "ENGSTELLE\nMitte halten", WARN_YELLOW)


static func _build_zone(world, piece: Dictionary) -> void:
	var lava: bool = str(piece.params.kind) == "lava"
	var color: Color = LAVA_COLOR if lava else ICE_COLOR
	var half: float = float(piece.params.width) * 0.5
	var lane: float = float(piece.lane)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps: int = maxi(4, ceili((float(piece.end) - float(piece.start)) * 2.0))
	for i in range(steps):
		var a: float = lerpf(float(piece.start), float(piece.end), float(i) / steps)
		var b: float = lerpf(float(piece.start), float(piece.end), float(i + 1) / steps)
		var up_a: Vector3 = world.frame(a).y * 0.014
		var up_b: Vector3 = world.frame(b).y * 0.014
		var corners: Array = [
			world.position_at(a, lane - half) + up_a, world.position_at(a, lane + half) + up_a,
			world.position_at(b, lane + half) + up_b, world.position_at(b, lane - half) + up_b
		]
		for corner in [corners[0], corners[1], corners[2], corners[0], corners[2], corners[3]]:
			tool.set_normal(world.frame(a).y)
			tool.set_uv(Vector2((corner - corners[0]).length(), a))
			tool.add_vertex(corner)
	var material := StandardMaterial3D.new()
	material.albedo_color = color.darkened(0.25) if lava else color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.4 if lava else 0.35
	material.roughness = 0.9 if lava else 0.06
	material.metallic = 0.0 if lava else 0.35
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var node := MeshInstance3D.new()
	node.name = "HazardZone_%s_%d" % [piece.params.kind, int(piece.start)]
	node.mesh = tool.commit()
	node.material_override = material
	world.add_child(node)
	# Glowing striped border on both sides, so the edge reads from far away.
	var along: float = float(piece.start)
	var index: int = 0
	while along <= float(piece.end):
		var basis: Basis = world.frame(along)
		for side in [-1.0, 1.0]:
			var stripe: Color = WARN_YELLOW if index % 2 == 0 else color
			world._prop("box", world.position_at(along, lane + side * (half + 0.12)) + basis.y * 0.04, Vector3(0.24, 0.06, 1.0), stripe, basis, true)
		along += 1.0
		index += 1
	_warning_sign(world, float(piece.start) - WARNING_LEAD_M, "LAVA!\nAusweichen" if lava else "EIS!\nSanft lenken", color)


static func _warning_sign(world, distance: float, text: String, color: Color) -> void:
	var basis: Basis = world.frame(distance)
	var post: Vector3 = world.position_at(distance, float(world.RAIL_LATERAL) + 0.9)
	world._prop("box", post + basis.y * 1.4, Vector3(0.16, 2.8, 0.16), Color("dfe6ee"), basis)
	world._prop("box", post + basis.y * 3.1, Vector3(2.4, 1.3, 0.08), color, basis, true)
	world._prop("box", post + basis.y * 3.1 + basis.z * 0.05, Vector3(2.2, 1.1, 0.04), WARN_DARK, basis)
	world._sign(post + basis.y * 3.1 + basis.z * 0.09, basis, text, 0.012)
