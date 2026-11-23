extends RefCounted
## Optional arcade loop. Rendering and contact use the same continuous 3D path.
## Gravity slows the ascent; low momentum or heavy braking returns to the entry road.
## A layout may set "radius", "lateral_limit", "fail_lane", "exit_shift" and
## "deck_half_width" (see Sonnenhafen stunt sequence and expansion tracks).
##
## Seamless road integration: optional side-road approaches carry the ring outside
## the main racing corridor. Legacy layouts can still join side by side on the road
## ("exit_shift"), so the climbing and the descending track never cross. The
## shift follows u - sin(2 pi u) / (2 pi): zero slope at both road joins, the
## whole sideways move happens high up in the ring. At u = 0 and u = 1 every
## deck vertex is the road surface point at the same lateral offset, the
## tangent is the road tangent and the banking is the road banking.
const ROAD_SURFACES = preload("res://scripts/games/kart_road_surfaces.gd")
const RADIUS: float = 6.5
const ADVANCE: float = 7.0
const LENGTH: float = TAU * RADIUS + ADVANCE * 0.2
const GRAVITY: float = 6.0
const LATERAL_LIMIT: float = 0.7
const ARC_SEGMENTS: int = 256
const DECK_HALF_WIDTH: float = 1.2
## The deck floats this far above the asphalt: no depth fighting, no visible step.
const DECK_LIFT: float = 0.012
## Flush road plates before the entry and after the exit; walls grow out of them.
const APRON_M: float = 6.0
const WALL_HEIGHT: float = 0.55
const WALL_THICKNESS: float = 0.22
const DECK_SEGMENTS: int = 160
const APRON_SEGMENTS: int = 12
## Lateral steering offsets beyond the limit are eased back, never snapped.
const LATERAL_EASE: float = 2.5
var active: bool = false
var progress: float = 0.0
var speed: float = 0.0
var lateral: float = 0.0
var entry_progress: float = 0.0
var layout: Dictionary = {}
var failed: bool = false
var _arc_lengths: PackedFloat32Array = PackedFloat32Array()
var _distance_along: float = 0.0


static func radius_of(data: Dictionary) -> float:
	return float(data.get("radius", RADIUS))


static func exit_shift_of(data: Dictionary) -> float:
	return float(data.get("exit_shift", 0.0))


static func half_width_of(data: Dictionary) -> float:
	return float(data.get("deck_half_width", DECK_HALF_WIDTH))


## Road lane where the loop sets the kart down again (steering offset excluded).
static func exit_lane(data: Dictionary) -> float:
	return float(data.lane) + exit_shift_of(data)


## Fraction of the sideways shift done at u; flat at both road joins.
static func shift_fraction(u: float) -> float:
	var t: float = clampf(u, 0.0, 1.0)
	return t - sin(TAU * t) / TAU


## Approximate design length only; driving uses the measured distance table.
static func path_length(data: Dictionary) -> float:
	return TAU * radius_of(data) + advance_of(data) - ADVANCE * 0.8


## Route metres consumed by this optional branch, including actual approach and return.
static func advance_of(data: Dictionary) -> float:
	if not bool(data.get("branch", false)):
		return ADVANCE
	return float(data.get("approach_m", 26.0)) + ADVANCE + float(data.get("return_m", 30.0))


static func road_distance_at(data: Dictionary, u: float) -> float:
	var t: float = clampf(u, 0.0, 1.0)
	if not bool(data.get("branch", false)):
		return float(data.start) + t * ADVANCE
	var approach: float = float(data.get("approach_m", 26.0))
	if t < 0.25:
		return float(data.start) + approach * t * 4.0
	if t <= 0.75:
		return float(data.start) + approach + ADVANCE * (t - 0.25) * 2.0
	return float(data.start) + approach + ADVANCE + float(data.get("return_m", 30.0)) * (t - 0.75) * 4.0


static func lane_at(data: Dictionary, u: float) -> float:
	var t: float = clampf(u, 0.0, 1.0)
	if not bool(data.get("branch", false)):
		return float(data.lane) + exit_shift_of(data) * shift_fraction(t)
	var outer: float = float(data.get("outer_lane", 20.0))
	var ring_shift: float = float(data.get("ring_shift", 3.0))
	if t < 0.25:
		return lerpf(float(data.lane), outer, smoothstep(0.0, 1.0, t * 4.0))
	if t <= 0.75:
		return outer + ring_shift * shift_fraction((t - 0.25) * 2.0)
	return lerpf(outer + ring_shift, exit_lane(data), smoothstep(0.0, 1.0, (t - 0.75) * 4.0))


static func _center_point(world, data: Dictionary, u: float) -> Vector3:
	var t: float = clampf(u, 0.0, 1.0)
	var branch: bool = bool(data.get("branch", false))
	var ring_t: float = clampf((t - 0.25) * 2.0, 0.0, 1.0) if branch else t
	var ring_start: float = float(data.start) + (float(data.get("approach_m", 26.0)) if branch else 0.0)
	var basis: Basis = world.frame(ring_start)
	var theta: float = ring_t * TAU
	var radius: float = radius_of(data)
	var base: Vector3 = world.position_at(road_distance_at(data, t), lane_at(data, t))
	return base + basis.y * radius * (1.0 - cos(theta)) - basis.z * radius * sin(theta)


static func point(world, data: Dictionary, u: float, offset: float = 0.0) -> Vector3:
	var center: Vector3 = _center_point(world, data, u)
	if is_zero_approx(offset):
		return center
	# Lateral offsets follow the actual branch tangent, including both merging bends.
	var right: Vector3 = frame_at(world, data, u).x if bool(data.get("branch", false)) else world.frame(road_distance_at(data, u)).x
	return center + right * offset


static func frame_at(world, data: Dictionary, u: float) -> Basis:
	if u <= 0.0 or u >= 1.0:
		return world.frame(road_distance_at(data, u))
	var a: float = maxf(0, u - 0.0005)
	var b: float = minf(1, u + 0.0005)
	var forward: Vector3 = (_center_point(world, data, b) - _center_point(world, data, a)).normalized()
	var right: Vector3 = world.frame(road_distance_at(data, u)).x
	var up: Vector3 = right.cross(forward).normalized()
	right = forward.cross(up).normalized()
	return Basis(right, up, -forward).orthonormalized()


static func ring_center(world, data: Dictionary) -> Vector3:
	var ring_start: float = float(data.start) + (float(data.get("approach_m", 26.0)) if bool(data.get("branch", false)) else 0.0)
	return point(world, data, 0.5) - world.frame(ring_start).y * radius_of(data)


## The guardrail opens only where the branch actually crosses it. The normal
## road collision remains protective; a chosen branch uses its contact solver.
static func rail_open(data: Dictionary, distance: float, side: float) -> bool:
	if data.is_empty() or not bool(data.get("branch", false)) or side != signf(float(data.lane)):
		return false
	var d: float = distance - float(data.start)
	var approach: float = float(data.get("approach_m", 26.0))
	var leave: float = advance_of(data)
	return (d >= -1.0 and d <= approach * 0.65) or (d >= leave - float(data.get("return_m", 30.0)) * 0.65 and d <= leave + 1.0)


## Check every nearby primary road, including parallel and stacked sections.
## Keep the entire branch in one checkpoint sector: a failed climb can return
## to its entrance without awarding a checkpoint and then moving behind it.
static func configure_branch(world, data: Dictionary) -> Dictionary:
	var result: Dictionary = data.duplicate(true)
	result.merge({"branch": true, "approach_m": 26.0, "return_m": 30.0,
		"exit_shift": 0.0, "ring_shift": 3.0, "outer_lane": 20.0}, true)
	var sector: float = float(world.length) / 8.0
	var sector_end: float = (floorf(float(data.start) / sector) + 1.0) * sector
	result.start = minf(float(data.start), sector_end - advance_of(result) - 12.0)
	var preferred: float = signf(float(result.lane))
	if is_zero_approx(preferred):
		preferred = 1.0
	for side in [preferred, -preferred]:
		result.lane = side * absf(float(data.lane))
		result.ring_shift = side * 3.0
		for outer in [18.0, 22.0, 26.0, 30.0, 36.0]:
			result.outer_lane = side * outer
			var clear: bool = true
			for i in range(33):
				var u: float = 0.25 + float(i) / 64.0
				if world._near_road(_center_point(world, result, u), float(world.road_width) * 0.5 + half_width_of(result) + 2.5):
					clear = false
					break
			if clear:
				return result
	push_error("[KartLoop] No exterior road corridor for %s" % str(world.track_id))
	return {}


func enter(
	data: Dictionary,
	momentum: float,
	cumulative: float,
	lane_offset: float = 0.0,
	entry_offset: float = 0.0
) -> void:
	layout = data.duplicate()
	progress = 0
	speed = momentum
	entry_progress = cumulative
	# Keep the real entry offset; advance() eases it inside the limit so the
	# kart never jumps sideways at the lip.
	var tolerance: float = float(data.get("lane_tolerance", 0.9))
	lateral = clampf(lane_offset, -tolerance, tolerance)
	_arc_lengths = PackedFloat32Array()
	_distance_along = maxf(0.0, entry_offset)
	failed = false
	active = true


func advance(world, delta: float, steering: float, braking: float, throttle: bool) -> Transform3D:
	# The circle advances along a curved road as well. Uniform angle steps are
	# therefore not uniform metres (the previous approximation varied by 20%).
	# Build one distance table at entry and invert it without allocations per tick.
	if _arc_lengths.is_empty():
		_arc_lengths.resize(ARC_SEGMENTS + 1)
		_arc_lengths[0] = 0.0
		var previous: Vector3 = point(world, layout, 0.0)
		for index in range(1, ARC_SEGMENTS + 1):
			var current: Vector3 = point(world, layout, float(index) / ARC_SEGMENTS)
			_arc_lengths[index] = _arc_lengths[index - 1] + previous.distance_to(current)
			previous = current
		progress = _progress_at_distance(_distance_along)
	var basis := frame_at(world, layout, progress)
	var slope: float = (-basis.z).y
	speed += (-GRAVITY * slope - braking * 13.0 + (0.9 if throttle else -0.2)) * delta
	var limit: float = float(layout.get("lateral_limit", LATERAL_LIMIT))
	lateral += steering * delta * 1.5
	if absf(lateral) > limit:
		lateral = move_toward(lateral, signf(lateral) * limit, LATERAL_EASE * delta)
	if speed < 4:
		failed = true
		active = false
		return world.reset_transform(
			float(layout.start), float(layout.get("fail_lane", layout.lane))
		)
	_distance_along = minf(_arc_lengths[ARC_SEGMENTS], _distance_along + speed * delta)
	progress = _progress_at_distance(_distance_along)
	basis = frame_at(world, layout, progress)
	if progress >= 1:
		active = false
	return Transform3D(basis, point(world, layout, progress, lateral) + basis.y * 0.045)


func _progress_at_distance(metres: float) -> float:
	if metres >= _arc_lengths[ARC_SEGMENTS]:
		return 1.0
	var low: int = 0
	var high: int = ARC_SEGMENTS
	while high - low > 1:
		var middle: int = (low + high) / 2
		if _arc_lengths[middle] <= metres:
			low = middle
		else:
			high = middle
	var span: float = _arc_lengths[high] - _arc_lengths[low]
	return (float(low) + (metres - _arc_lengths[low]) / maxf(span, 0.0001)) / ARC_SEGMENTS


## Continuous swept geometry of one loop: deck, side walls and the closed
## underside as three meshes (three draw calls), plus flush road plates before
## the entry and after the exit. Style keys (all optional): deck_color,
## chevron_color, edge_color, wall_color, wall_glow, spine_color, chevron_spacing.
## Returns {"deck", "walls", "spine"} MeshInstance3D nodes, already in world.
static func build_track(world, data: Dictionary, style: Dictionary) -> Dictionary:
	var rows: Array = deck_rows(world, data)
	var deck := SurfaceTool.new()
	deck.begin(Mesh.PRIMITIVE_TRIANGLES)
	var walls := SurfaceTool.new()
	walls.begin(Mesh.PRIMITIVE_TRIANGLES)
	var spine := SurfaceTool.new()
	spine.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(rows.size() - 1):
		var a: Dictionary = rows[i]
		var b: Dictionary = rows[i + 1]
		_quad(deck, a.left, a.right, b.right, b.left, a.up, b.up, a.v, b.v)
		for side in ["left", "right"]:
			var inward: float = 1.0 if side == "left" else -1.0
			var across_a: Vector3 = (a.right - a.left).normalized() * inward
			var across_b: Vector3 = (b.right - b.left).normalized() * inward
			var top_a: Vector3 = a[side] + a.up * WALL_HEIGHT * float(a.wall)
			var top_b: Vector3 = b[side] + b.up * WALL_HEIGHT * float(b.wall)
			var thick_a: Vector3 = across_a * WALL_THICKNESS * float(a.wall)
			var thick_b: Vector3 = across_b * WALL_THICKNESS * float(b.wall)
			# Outer face, rounded-off top and inner face: a closed rail profile.
			_quad(walls, a[side], top_a, top_b, b[side], -across_a, -across_b, a.v, b.v)
			_quad(walls, top_a, top_a + thick_a, top_b + thick_b, top_b, a.up, b.up, a.v, b.v)
			_quad(
				walls,
				top_a + thick_a,
				a[side] + thick_a,
				b[side] + thick_b,
				top_b + thick_b,
				across_a,
				across_b,
				a.v,
				b.v
			)
		if not bool(a.on_road) or not bool(b.on_road):
			# Underside box girder; skipped on the flush road plates.
			var drop_a: Vector3 = -a.up * 0.42
			var drop_b: Vector3 = -b.up * 0.42
			var inset_a: Vector3 = (a.right - a.left) * 0.18
			var inset_b: Vector3 = (b.right - b.left) * 0.18
			_quad(
				spine,
				a.left + inset_a + drop_a,
				b.left + inset_b + drop_b,
				b.right - inset_b + drop_b,
				a.right - inset_a + drop_a,
				-a.up,
				-b.up,
				0,
				1
			)
			_quad(spine, a.left, b.left, b.left + inset_b + drop_b, a.left + inset_a + drop_a, -a.up, -b.up, 0, 1)
			_quad(spine, a.right - inset_a + drop_a, b.right - inset_b + drop_b, b.right, a.right, -a.up, -b.up, 0, 1)
	var deck_material := ShaderMaterial.new()
	deck_material.shader = preload("res://assets/shaders/kart_stunt_loop.gdshader")
	for key in ["deck_color", "chevron_color", "edge_color", "chevron_spacing"]:
		if style.has(key):
			deck_material.set_shader_parameter(key, style[key])
	var wall_material := StandardMaterial3D.new()
	wall_material.albedo_color = style.get("wall_color", Color("f4f7ef"))
	wall_material.roughness = 0.35
	wall_material.emission_enabled = true
	wall_material.emission = style.get("wall_glow", Color("ff9a2e"))
	wall_material.emission_energy_multiplier = 0.35
	wall_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var spine_material := StandardMaterial3D.new()
	spine_material.albedo_color = style.get("spine_color", Color("2b3c5c"))
	spine_material.metallic = 0.55
	spine_material.roughness = 0.38
	spine_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return {
		"deck": _add_mesh(world, "LoopDeck", deck, deck_material),
		"walls": _add_mesh(world, "LoopWalls", walls, wall_material),
		"spine": _add_mesh(world, "LoopSpine", spine, spine_material),
	}


## Cross-section rows of the whole riding surface in driving order:
## entry plate on the road, the ring itself, exit plate on the road.
## Each row: left/right deck edge, up normal, v (metres along), wall (0..1
## height factor) and on_road. The seam regression measures exactly these.
static func deck_rows(world, data: Dictionary) -> Array:
	var half: float = half_width_of(data)
	var start: float = float(data.start)
	var entry: float = float(data.lane)
	var leave: float = exit_lane(data)
	var rows: Array = []
	var along: float = -APRON_M
	for i in range(APRON_SEGMENTS):
		var d: float = start - APRON_M + APRON_M * float(i) / float(APRON_SEGMENTS)
		rows.append(_road_row(world, d, entry, half, along, float(i) / float(APRON_SEGMENTS)))
		along += APRON_M / float(APRON_SEGMENTS)
	var previous: Vector3 = point(world, data, 0.0)
	along = 0.0
	for i in range(DECK_SEGMENTS + 1):
		var u: float = float(i) / float(DECK_SEGMENTS)
		var basis: Basis = frame_at(world, data, u)
		var center: Vector3 = point(world, data, u)
		along += center.distance_to(previous)
		previous = center
		var on_road: bool = i == 0 or i == DECK_SEGMENTS
		var up: Vector3 = world.frame(road_distance_at(data, u)).y if on_road else basis.y
		rows.append(
			{
				"left": point(world, data, u, -half) + up * DECK_LIFT,
				"right": point(world, data, u, half) + up * DECK_LIFT,
				"up": up,
				"v": along,
				"wall": 1.0,
				"on_road": on_road,
				"u": u,
			}
		)
	var exit_start: float = start + advance_of(data)
	for i in range(1, APRON_SEGMENTS + 1):
		var d: float = exit_start + APRON_M * float(i) / float(APRON_SEGMENTS)
		var row: Dictionary = _road_row(
			world, d, leave, half, along + APRON_M * float(i) / float(APRON_SEGMENTS),
			1.0 - float(i) / float(APRON_SEGMENTS)
		)
		rows.append(row)
	return rows


static func _road_row(world, d: float, lane: float, half: float, v: float, rise: float) -> Dictionary:
	var up: Vector3 = world.frame(d).y
	# Smooth rise of the walls out of the asphalt (no hard block on the road).
	var wall: float = rise * rise * (3.0 - 2.0 * rise)
	return {
		"left": world.position_at(d, lane - half) + up * DECK_LIFT,
		"right": world.position_at(d, lane + half) + up * DECK_LIFT,
		"up": up,
		"v": v,
		"wall": wall,
		"on_road": true,
		"u": -1.0,
	}


static func _quad(
	tool: SurfaceTool,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	d: Vector3,
	normal_a: Vector3,
	normal_b: Vector3,
	v_a: float,
	v_b: float
) -> void:
	var corners: Array[Vector3] = [a, b, c, a, c, d]
	var normals: Array[Vector3] = [normal_a, normal_a, normal_b, normal_a, normal_b, normal_b]
	var uvs: Array[Vector2] = [
		Vector2(0, v_a), Vector2(1, v_a), Vector2(1, v_b), Vector2(0, v_a), Vector2(1, v_b), Vector2(0, v_b)
	]
	for i in range(6):
		tool.set_normal(normals[i])
		tool.set_uv(uvs[i])
		tool.add_vertex(corners[i])


static func _add_mesh(world, mesh_name: String, tool: SurfaceTool, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = mesh_name
	node.mesh = tool.commit()
	node.material_override = material
	world.add_child(node)
	return node


## Expansion-track loop: same continuous geometry in the track's own colours.
static func build(world, data: Dictionary, color: Color) -> void:
	var asphalt: Color = ROAD_SURFACES.tint(
		world.track_id, world.definition.get("asphalt", Color("33466c")))
	build_track(
		world,
		data,
		{
			"deck_color": asphalt.lightened(0.08),
			"chevron_color": world.definition.get("accent", color),
			"edge_color": color,
			"wall_glow": color,
		}
	)
	var at: Vector3 = world.position_at(float(data.start) - 7, signf(float(data.lane)) * 7.2)
	var basis: Basis = world.frame(float(data.start))
	world._prop("box", at + Vector3.UP * 2.2, Vector3(3.1, 1.4, 0.1), Color("17354e"), basis)
	world._sign(at + Vector3.UP * 2.2 + basis.z * 0.1, basis, ("LOOP RECHTS" if float(data.lane) > 0.0 else "LOOP LINKS") + "\nAbzweigung", 0.012)
