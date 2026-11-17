extends RefCounted
## Sonnenhafen stunt sequence in front of the crystal tunnel (dark ride at
## 69 % of the lap). Position A, about 100 m before the tunnel mouth, gets a
## real, drivable 360° loop on the right lane:
## - the kart follows the same 3D path that is rendered (kart_physical_loop),
##   gravity slows the climb and a too-slow kart is set back to the main lane;
## - a boost pad on the loop lane gives the needed speed;
## - the loop entry stands 100 m before the precision ramp (was 28 m), so the
##   kart leaves the loop, settles and has a straight run-up to the ramp;
## - gold stars on the riding line are collected while looping.
## Everything else (main lane, rails, checkpoints, lap length) stays unchanged.

const LOOP = preload("res://scripts/games/kart_physical_loop.gd")
const SHAPES = preload("res://scripts/games/kart_world_meshes.gd")
const DECK_SHADER = preload("res://assets/shaders/kart_stunt_loop.gdshader")
const BALLOON_SHADER = preload("res://assets/shaders/kart_balloon.gdshader")
const EMBLEM = preload("res://assets/kart/stunt/lumo_balloon_emblem.png")
const PRECISION = preload("res://scripts/games/kart_precision_jump.gd")

const TUNNEL_FRACTION: float = 0.690
## Loop entry this many metres before the tunnel mouth (Position A).
const LOOP_LEAD_M: float = 180.0
const LOOP_LANE: float = 2.9
const LOOP_RADIUS: float = 8.0
const DECK_HALF_WIDTH: float = 2.4
## Half width of the precision ramp deck (old kicker slabs were 9.2 m wide).
const RAMP_HALF_WIDTH: float = 4.6
const WALL_HEIGHT: float = 0.55
const DECK_SEGMENTS: int = 160
## Boost pad on the loop lane, ending this far before the loop entry.
const PAD_GAP_M: float = 16.0
const PAD_LENGTH: float = 6.0
const STAR_FRACTIONS: Array[float] = [0.14, 0.27, 0.40, 0.5, 0.60, 0.73, 0.86]

## Position B, 80 m before the tunnel: a full-width precision stunt ramp about
## 80 m after the loop exit. Unlike the 55 % panorama kicker it has no lift
## bonus and no lift cap: flight distance follows from speed alone
## (kart_precision_jump.gd), over a genuine open gap in the road.
const JUMP_LEAD_M: float = 80.0
const JUMP_RAMP_LENGTH: float = 12.0
## 14 degrees: steep enough for a visible arc, gentle enough to read for kids.
const JUMP_RAMP_HEIGHT: float = 3.0
const PRECISION_GRAVITY: float = 14.0
## Open air starts just behind the lip; the road (and the landing zone) begins
## PRECISION_LANDING_START_M after take-off. Undershooting falls into the gap.
const PRECISION_GAP_START_M: float = 0.5
## Landing zone after take-off. At the doubled road pace the driver brakes
## toward the green landing-speed hint. Full throttle overshoots, too little
## momentum falls short; the airborne controller never fabricates a landing.
const PRECISION_LANDING_START_M: float = 14.5
const PRECISION_LANDING_END_M: float = 31.0
## Stars follow the computed arc of the controlled precision approach speed.
const ARC_REFERENCE_SPEED: float = 20.5
const ARC_STARS: Array[float] = [4.0, 8.0, 12.0, 16.0]

## Tunnel portal at the dark-ride mouth (lateral legs outside the rails).
const PORTAL_SETBACK_M: float = 1.5
const PORTAL_RADIUS: float = 9.2
const PORTAL_BASE_HEIGHT: float = 0.9
## Hot-air balloons with the original Lumo emblem over the stunt zone:
## [metres relative to the loop entry, lateral offset, height above road, size].
const BALLOONS: Array = [
	[-60.0, -26.0, 11.0, 0.9],
	[-5.0, -40.0, 15.0, 1.2],
	[40.0, -24.0, 9.5, 0.8],
	[70.0, 30.0, 13.0, 1.0]
]
const NAVY: Color = Color("12233f")
const CYAN: Color = Color("41dcff")
const ORANGE: Color = Color("ff9a2e")
const GOLD: Color = Color("ffc94a")
const WHITE: Color = Color("f4f7ef")


static func applies(world) -> bool:
	return str(world.track_id) == "sonnenhafen"


static func tunnel_start(world) -> float:
	return float(world.length) * TUNNEL_FRACTION


static func loop_start(world) -> float:
	return tunnel_start(world) - LOOP_LEAD_M


## Called before the road is built, so the action course keeps its distance.
static func prepare(world) -> void:
	if not applies(world):
		return
	world.loop_layout = {
		"start": loop_start(world),
		"lane": LOOP_LANE,
		"radius": LOOP_RADIUS,
		"lateral_limit": DECK_HALF_WIDTH - 0.65,
		"entry_window": 1.6,
		"lane_tolerance": 1.5,
		"min_entry_speed": 13.0,
		"fail_lane": 0.0,
		"stunt": true,
	}


## Real boost pad(s) for the action course (same rules as every Turbo-Feld).
static func pads(world) -> Array:
	if not applies(world):
		return []
	var end: float = loop_start(world) - PAD_GAP_M
	return [{"start": end - PAD_LENGTH, "end": end, "lateral": LOOP_LANE}]


static func jump_take_off(world) -> float:
	return tunnel_start(world) - JUMP_LEAD_M


static func kickers(world) -> Array:
	if not applies(world):
		return []
	var take_off: float = jump_take_off(world)
	# The landing road climbs a little; the model needs that rise to be exact.
	var rise: float = (
		world.position_at(take_off + PRECISION_LANDING_START_M).y - world.position_at(take_off).y
	)
	var kicker: Dictionary = {
		"start": take_off - JUMP_RAMP_LENGTH,
		"take_off": take_off,
		"length": JUMP_RAMP_LENGTH,
		"height": JUMP_RAMP_HEIGHT,
		"angle": atan2(JUMP_RAMP_HEIGHT, JUMP_RAMP_LENGTH),
		"flight_gravity": PRECISION_GRAVITY,
		"lift_bonus": 0.0,
		"max_lift": 1000.0,  # effectively uncapped; JSON-safe
		"precision_jump": true,
		"landing_min": PRECISION_LANDING_START_M,
		"landing_max": PRECISION_LANDING_END_M,
		"landing_slope": rise / PRECISION_LANDING_START_M,
		"gap_start": take_off + PRECISION_GAP_START_M,
		"gap_end": take_off + PRECISION_LANDING_START_M,
		"hero_flight": true,
		"stunt": true,
	}
	# Computer rivals fly the arc of a clean landing in the middle of the zone.
	kicker["rival_speed"] = PRECISION.speed_for_distance(
		(PRECISION_LANDING_START_M + PRECISION_LANDING_END_M) * 0.5, kicker
	)
	return [kicker]


## Collectible stars on the riding line through the loop and over the pad.
static func star_positions(world) -> Array[Vector3]:
	var result: Array[Vector3] = []
	if not applies(world) or world.loop_layout.is_empty():
		return result
	var layout: Dictionary = world.loop_layout
	for u in STAR_FRACTIONS:
		var basis: Basis = LOOP.frame_at(world, layout, u)
		result.append(LOOP.point(world, layout, u) + basis.y * 0.95)
	var start: float = loop_start(world)
	for i in range(4):
		var d: float = start - PAD_GAP_M - PAD_LENGTH - 2.0 + float(i) * 4.5
		result.append(world.position_at(d, LOOP_LANE) + world.frame(d).y * 0.95)
	var take_off: float = jump_take_off(world)
	var kicker: Dictionary = kickers(world)[0]
	for along in ARC_STARS:
		var height: float = PRECISION.height_at(ARC_REFERENCE_SPEED, kicker, along)
		var base: Vector3 = world.position_at(take_off, 0.0)
		var d: float = take_off + along
		var ground: Vector3 = world.position_at(d, 0.0)
		result.append(Vector3(ground.x, base.y + height + 0.95, ground.z))
	return result


static func build(world) -> void:
	if not applies(world) or world.loop_layout.is_empty():
		return
	var layout: Dictionary = world.loop_layout
	_deck(world, layout)
	_supports(world, layout)
	_inner_stars(world, layout)
	_entry_guidance(world, layout)
	_beacons(world, layout)
	_tunnel_portal(world)
	_balloons(world)


## Deck, side walls and the chunky outer spine as three real meshes that use
## exactly the riding path of kart_physical_loop.
static func _deck(world, layout: Dictionary) -> void:
	var deck := SurfaceTool.new()
	deck.begin(Mesh.PRIMITIVE_TRIANGLES)
	var walls := SurfaceTool.new()
	walls.begin(Mesh.PRIMITIVE_TRIANGLES)
	var spine := SurfaceTool.new()
	spine.begin(Mesh.PRIMITIVE_TRIANGLES)
	var along: float = 0.0
	var previous_center: Vector3 = LOOP.point(world, layout, 0.0)
	var rows: Array = []
	for i in range(DECK_SEGMENTS + 1):
		var u: float = float(i) / float(DECK_SEGMENTS)
		var basis: Basis = LOOP.frame_at(world, layout, u)
		var center: Vector3 = LOOP.point(world, layout, u)
		along += center.distance_to(previous_center)
		previous_center = center
		var left: Vector3 = LOOP.point(world, layout, u, -DECK_HALF_WIDTH)
		var right: Vector3 = LOOP.point(world, layout, u, DECK_HALF_WIDTH)
		rows.append({"left": left, "right": right, "up": basis.y, "v": along})
	for i in range(DECK_SEGMENTS):
		var a: Dictionary = rows[i]
		var b: Dictionary = rows[i + 1]
		_quad(deck, a.left, a.right, b.right, b.left, a.up, b.up, a.v, b.v)
		for side in ["left", "right"]:
			var lift_a: Vector3 = a.up * WALL_HEIGHT
			var lift_b: Vector3 = b.up * WALL_HEIGHT
			var inward: float = 1.0 if side == "left" else -1.0
			var across_a: Vector3 = (a.right - a.left).normalized() * inward
			var across_b: Vector3 = (b.right - b.left).normalized() * inward
			_quad(
				walls,
				a[side],
				a[side] + lift_a,
				b[side] + lift_b,
				b[side],
				across_a,
				across_b,
				0,
				1
			)
			_quad(
				walls,
				a[side] + lift_a,
				a[side] + lift_a - across_a * 0.22,
				b[side] + lift_b - across_b * 0.22,
				b[side] + lift_b,
				a.up,
				b.up,
				0,
				1
			)
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
		_quad(
			spine,
			a.left,
			b.left,
			b.left + inset_b + drop_b,
			a.left + inset_a + drop_a,
			-a.up,
			-b.up,
			0,
			1
		)
		_quad(
			spine,
			a.right - inset_a + drop_a,
			b.right - inset_b + drop_b,
			b.right,
			a.right,
			-a.up,
			-b.up,
			0,
			1
		)
	var deck_material := ShaderMaterial.new()
	deck_material.shader = DECK_SHADER
	_add_mesh(world, "StuntLoopDeck", deck, deck_material)
	var wall_material := StandardMaterial3D.new()
	wall_material.albedo_color = WHITE
	wall_material.roughness = 0.35
	wall_material.emission_enabled = true
	wall_material.emission = ORANGE
	wall_material.emission_energy_multiplier = 0.35
	wall_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_add_mesh(world, "StuntLoopWalls", walls, wall_material)
	var spine_material := StandardMaterial3D.new()
	spine_material.albedo_color = Color("2b3c5c")
	spine_material.metallic = 0.55
	spine_material.roughness = 0.38
	spine_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_add_mesh(world, "StuntLoopSpine", spine, spine_material)
	# Running lights on the outside of the ring, like the reference loops.
	for i in range(0, DECK_SEGMENTS, 4):
		var u: float = float(i) / float(DECK_SEGMENTS)
		var basis: Basis = LOOP.frame_at(world, layout, u)
		world._prop(
			"ball",
			LOOP.point(world, layout, u) - basis.y * 0.48,
			Vector3.ONE * 0.22,
			GOLD if (i / 4) % 2 == 0 else CYAN,
			Basis.IDENTITY,
			true
		)
	# Cyan light strip on top of both walls, visible from far away.
	for i in range(0, DECK_SEGMENTS, 2):
		var u: float = (float(i) + 1.0) / float(DECK_SEGMENTS)
		var basis: Basis = LOOP.frame_at(world, layout, u)
		var a: Vector3 = LOOP.point(world, layout, float(i) / float(DECK_SEGMENTS))
		var b: Vector3 = LOOP.point(world, layout, float(i + 2) / float(DECK_SEGMENTS))
		for side in [-1.0, 1.0]:
			var at: Vector3 = LOOP.point(world, layout, u, side * (DECK_HALF_WIDTH - 0.11))
			world._prop(
				"box",
				at + basis.y * (WALL_HEIGHT + 0.03),
				Vector3(0.12, 0.06, a.distance_to(b) + 0.05),
				CYAN if (i / 2) % 3 != 0 else GOLD,
				basis,
				true
			)


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
		Vector2(0, v_a),
		Vector2(1, v_a),
		Vector2(1, v_b),
		Vector2(0, v_a),
		Vector2(1, v_b),
		Vector2(0, v_b)
	]
	for i in range(6):
		tool.set_normal(normals[i])
		tool.set_uv(uvs[i])
		tool.add_vertex(corners[i])


static func _add_mesh(world, mesh_name: String, tool: SurfaceTool, material: Material) -> void:
	var node := MeshInstance3D.new()
	node.name = mesh_name
	node.mesh = tool.commit()
	node.material_override = material
	world.add_child(node)


## Two A-frames from the loop flanks to footings outside the right rail.
static func _supports(world, layout: Dictionary) -> void:
	var start: float = float(layout.start)
	var right: float = float(world.RAIL_LATERAL) + 1.4
	for u in [0.25, 0.75]:
		var flank: Vector3 = LOOP.point(world, layout, u, DECK_HALF_WIDTH + 0.3)
		var d: float = start + u * LOOP.ADVANCE + (LOOP_RADIUS if u < 0.5 else -LOOP_RADIUS)
		var foot: Vector3 = world.position_at(d, right)
		foot.y -= 2.0
		var cap: Vector3 = flank + (flank - foot).normalized() * 0.2
		world._beam(foot, flank, 0.42, Color("e9eef2"))
		world._beam(foot + world.frame(d).z * 2.4, flank, 0.3, Color("e9eef2"))
		world._prop("ball", cap, Vector3.ONE * 0.38, ORANGE, Basis.IDENTITY, true)
		world._prop("box", foot, Vector3(2.0, 0.8, 2.0), NAVY, world.frame(d))
		world._prop(
			"box", foot + Vector3.UP * 0.42, Vector3(2.1, 0.08, 2.1), CYAN, world.frame(d), true
		)
	# Plinth along the loop lane under the entry and exit plates.
	for d in [start - 0.5, start + LOOP.ADVANCE + 0.5]:
		var basis: Basis = world.frame(d)
		world._prop(
			"box",
			world.position_at(d, LOOP_LANE) - basis.y * 0.05,
			Vector3(DECK_HALF_WIDTH * 2.0 + 0.4, 0.12, 2.2),
			Color("1d3150"),
			basis
		)


## Decorative gold stars inside the ring, like the reference loops.
static func _inner_stars(world, layout: Dictionary) -> void:
	var start: float = float(layout.start)
	var center_distance: float = start + LOOP.ADVANCE * 0.5
	var basis: Basis = world.frame(start)
	var center: Vector3 = world.position_at(center_distance, LOOP_LANE) + basis.y * LOOP_RADIUS
	var facing := Basis(-basis.z, basis.y, basis.x)
	for i in range(8):
		var angle: float = TAU * float(i) / 8.0
		var offset: Vector3 = (basis.y * cos(angle) - basis.z * sin(angle)) * LOOP_RADIUS * 0.52
		world._prop("star", center + offset, Vector3.ONE * 0.85, GOLD, facing, true)
	world._prop("star", center, Vector3.ONE * 1.6, GOLD, facing, true)


## Overhead sign on a cantilever outside the right rail plus cyan lane arrows.
static func _entry_guidance(world, layout: Dictionary) -> void:
	var start: float = float(layout.start)
	var sign_distance: float = start - 9.0
	var basis: Basis = world.frame(sign_distance)
	var post: Vector3 = world.position_at(sign_distance, float(world.RAIL_LATERAL) + 1.0)
	world._prop("box", post + basis.y * 3.1, Vector3(0.45, 6.2, 0.45), NAVY, basis)
	var beam_center: Vector3 = world.position_at(sign_distance, LOOP_LANE + 1.6) + basis.y * 6.0
	world._prop("box", beam_center, Vector3(5.4, 1.5, 0.35), NAVY, basis)
	world._prop("box", beam_center + basis.y * 0.82, Vector3(5.6, 0.12, 0.42), ORANGE, basis, true)
	world._prop("box", beam_center - basis.y * 0.82, Vector3(5.6, 0.12, 0.42), CYAN, basis, true)
	world._sign(beam_center + basis.z * 0.2, basis, "LUMO-LOOPING\nSchwung holen!", 0.016)
	# Arrows on the loop lane, starting before the boost pad.
	var pad_start: float = start - PAD_GAP_M - PAD_LENGTH
	for i in range(7):
		var d: float = pad_start - 26.0 + float(i) * 4.0
		var arrow_basis: Basis = world.frame(d)
		for side in [-1.0, 1.0]:
			var tilted: Basis = arrow_basis.rotated(arrow_basis.y, side * 0.70)
			var at: Vector3 = world.position_at(d, LOOP_LANE + side * 0.48) + arrow_basis.y * 0.03
			world._prop("box", at, Vector3(0.3, 0.03, 1.3), CYAN, tilted, true)
	# Dashed divider between main lane and loop lane.
	for i in range(14):
		var d: float = pad_start - 26.0 + float(i) * 3.0
		var divider_basis: Basis = world.frame(d)
		world._prop(
			"box",
			world.position_at(d, LOOP_LANE - DECK_HALF_WIDTH - 0.2) + divider_basis.y * 0.025,
			Vector3(0.14, 0.02, 1.6),
			WHITE,
			divider_basis
		)


## Tall light beacons beside the loop: the setpiece reads from far away.
static func _beacons(world, layout: Dictionary) -> void:
	var start: float = float(layout.start)
	for entry in [
		[start - 4.0, float(world.RAIL_LATERAL) + 3.5],
		[start + 12.0, float(world.RAIL_LATERAL) + 3.5]
	]:
		var d: float = float(entry[0])
		var basis: Basis = world.frame(d)
		var foot: Vector3 = world.position_at(d, float(entry[1]))
		world._prop(
			"cylinder",
			foot + Vector3.UP * 9.0,
			Vector3(0.35, 18.0, 0.35),
			Color("9eb3c4"),
			Basis.IDENTITY
		)
		world._prop("ball", foot + Vector3.UP * 18.6, Vector3.ONE * 0.9, CYAN, Basis.IDENTITY, true)
		world._prop("box", foot + Vector3.UP * 14.0, Vector3(1.4, 2.6, 0.12), ORANGE, basis, true)


## Glowing portal around the crystal-tunnel mouth: chevron arch, bulb ring and a
## LUMO KART sign, all outside the rail corridor and above the tunnel shell.
static func _tunnel_portal(world) -> void:
	var d: float = tunnel_start(world) - PORTAL_SETBACK_M
	var basis: Basis = world.frame(d)
	var center: Vector3 = world.position_at(d) + basis.y * PORTAL_BASE_HEIGHT
	var steps: int = 26
	for i in range(steps + 1):
		var angle: float = PI * float(i) / float(steps)
		var dir: Vector3 = basis.x * cos(angle) + basis.y * sin(angle)
		var tangent: Vector3 = (-basis.x * sin(angle) + basis.y * cos(angle)).normalized()
		var segment := (
			Basis(tangent, basis.z.cross(tangent).normalized(), basis.z).orthonormalized()
		)
		var at: Vector3 = center + dir * PORTAL_RADIUS
		world._prop("box", at, Vector3(1.25, 1.1, 1.6), NAVY, segment)
		# Cyan light bar on the front face, facing the approaching driver.
		world._prop(
			"box", at - dir * 0.2 + basis.z * 0.82, Vector3(0.72, 0.16, 0.08), CYAN, segment, true
		)
		# Bulbs on the outer rim.
		world._prop(
			"ball", at + dir * 0.62 + basis.z * 0.6, Vector3.ONE * 0.32, GOLD, Basis.IDENTITY, true
		)
	for side in [-1.0, 1.0]:
		var foot: Vector3 = center + basis.x * side * PORTAL_RADIUS
		var ground: Vector3 = world.position_at(d, side * PORTAL_RADIUS)
		world._prop(
			"box",
			(foot + ground) * 0.5 - basis.y * 0.3,
			Vector3(1.4, foot.distance_to(ground) + 0.8, 1.8),
			NAVY,
			basis
		)
	# Sign hangs in front of the arch crown, low enough to read under the HUD.
	var top: Vector3 = center + basis.y * (PORTAL_RADIUS - 1.3) + basis.z * 1.1
	world._prop("box", top, Vector3(8.6, 2.2, 0.5), Color("173a63"), basis)
	world._prop("box", top + basis.y * 1.18, Vector3(8.9, 0.16, 0.6), ORANGE, basis, true)
	world._prop("box", top - basis.y * 1.18, Vector3(8.9, 0.16, 0.6), CYAN, basis, true)
	world._sign(top + basis.z * 0.28, basis, "LUMO KART", 0.05)
	world._sign(top + basis.z * 0.28 - basis.y * 0.75, basis, "Kristalltunnel", 0.02)


## Precision stunt ramp in the loop's design language instead of the yellow /
## navy construction stripes: a real deck mesh with the loop's glowing cyan
## chevrons and orange edge lines, white side walls with an orange glow, a
## cyan lip, arrows on the run-up, and a clearly marked landing zone behind
## the open gap (green start bar, orange end bar, matching gates).
## Geometry follows exactly kicker_height(), so what you see is what you ride.
static func build_precision_ramp(world, kicker: Dictionary) -> void:
	var start: float = float(kicker.start)
	var take_off: float = float(kicker.take_off)
	var height: float = float(kicker.height)
	var deck := SurfaceTool.new()
	deck.begin(Mesh.PRIMITIVE_TRIANGLES)
	var body := SurfaceTool.new()
	body.begin(Mesh.PRIMITIVE_TRIANGLES)
	var walls := SurfaceTool.new()
	walls.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half: float = RAMP_HALF_WIDTH
	var steps: int = 24
	var rows: Array = []
	for i in range(steps + 1):
		var d: float = start + (take_off - start) * float(i) / float(steps)
		var basis: Basis = world.frame(d)
		var rise: float = float(i) / float(steps) * height
		var lift: Vector3 = basis.y * (rise + 0.02)
		(
			rows
			. append(
				{
					"left": world.position_at(d, -half) + lift,
					"right": world.position_at(d, half) + lift,
					"left_foot": world.position_at(d, -half) - basis.y * 0.05,
					"right_foot": world.position_at(d, half) - basis.y * 0.05,
					# The deck shader draws chevron tips towards decreasing v; running v
					# backwards makes the arrows point up the ramp, in driving direction.
					"up": basis.y,
					"side": basis.x,
					"v": take_off - d,
				}
			)
		)
	for i in range(steps):
		var a: Dictionary = rows[i]
		var b: Dictionary = rows[i + 1]
		_quad(deck, a.left, a.right, b.right, b.left, a.up, b.up, a.v, b.v)
		# Closed wedge sides so the ramp reads as a solid, built object.
		_quad(body, a.left_foot, a.left, b.left, b.left_foot, -a.side, -b.side, 0, 1)
		_quad(body, a.right, a.right_foot, b.right_foot, b.right, a.side, b.side, 0, 1)
		for side in ["left", "right"]:
			var out: Vector3 = (a.side if side == "right" else -a.side) * 0.24
			var top_a: Vector3 = a[side] + a.up * WALL_HEIGHT
			var top_b: Vector3 = b[side] + b.up * WALL_HEIGHT
			_quad(walls, a[side], top_a, top_b, b[side], -out, -out, 0, 1)
			_quad(walls, top_a, top_a + out, top_b + out, top_b, a.up, b.up, 0, 1)
	# Back face of the wedge under the lip.
	var last: Dictionary = rows[steps]
	_quad(
		body,
		last.left_foot,
		last.right_foot,
		last.right,
		last.left,
		-world.forward(take_off),
		-world.forward(take_off),
		0,
		1
	)
	var deck_material := ShaderMaterial.new()
	deck_material.shader = DECK_SHADER
	deck_material.set_shader_parameter("chevron_spacing", 2.0)
	_add_mesh(world, "PrecisionRampDeck", deck, deck_material)
	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = Color("2b3c5c")
	body_material.metallic = 0.55
	body_material.roughness = 0.38
	body_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_add_mesh(world, "PrecisionRampBody", body, body_material)
	var wall_material := StandardMaterial3D.new()
	wall_material.albedo_color = WHITE
	wall_material.roughness = 0.35
	wall_material.emission_enabled = true
	wall_material.emission = ORANGE
	wall_material.emission_energy_multiplier = 0.35
	wall_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_add_mesh(world, "PrecisionRampWalls", walls, wall_material)
	# Glowing lip and a cyan edge where the open gap begins.
	var lip_basis: Basis = world.frame(take_off - 0.15)
	world._prop(
		"box",
		world.position_at(take_off - 0.15) + lip_basis.y * (height + 0.06),
		Vector3(half * 2.0 + 0.3, 0.1, 0.3),
		CYAN,
		lip_basis,
		true
	)
	# Run-up arrows (same V arrows as the loop lane), centre and both lanes.
	for i in range(6):
		var d: float = start - 30.0 + float(i) * 4.5
		var arrow_basis: Basis = world.frame(d)
		for lane in [-2.6, 0.0, 2.6]:
			for side in [-1.0, 1.0]:
				var tilted: Basis = arrow_basis.rotated(arrow_basis.y, side * 0.70)
				var at: Vector3 = world.position_at(d, lane + side * 0.48) + arrow_basis.y * 0.03
				world._prop(
					"box", at, Vector3(0.3, 0.03, 1.3), ORANGE if i % 2 == 0 else CYAN, tilted, true
				)
	# Sign gantry: tells the child what this ramp is about.
	var sign_distance: float = start - 34.0
	var sign_basis: Basis = world.frame(sign_distance)
	var beam: Vector3 = world.position_at(sign_distance, 0.0) + sign_basis.y * 6.2
	for side in [-1.0, 1.0]:
		var post: Vector3 = world.position_at(
			sign_distance, side * (float(world.RAIL_LATERAL) + 0.9)
		)
		world._prop("box", post + sign_basis.y * 3.2, Vector3(0.45, 6.4, 0.45), NAVY, sign_basis)
	world._prop(
		"box", beam, Vector3(float(world.RAIL_LATERAL) * 2.0 + 2.2, 1.5, 0.35), NAVY, sign_basis
	)
	world._prop(
		"box",
		beam + sign_basis.y * 0.82,
		Vector3(float(world.RAIL_LATERAL) * 2.0 + 2.4, 0.12, 0.42),
		ORANGE,
		sign_basis,
		true
	)
	world._prop(
		"box",
		beam - sign_basis.y * 0.82,
		Vector3(float(world.RAIL_LATERAL) * 2.0 + 2.4, 0.12, 0.42),
		CYAN,
		sign_basis,
		true
	)
	world._sign(beam + sign_basis.z * 0.2, sign_basis, "STUNT-SPRUNG\nAuf das Tempo achten!", 0.016)
	# Solid abutments on both sides of the open gap, so it reads as a built
	# chasm in the road and not as a missing texture.
	for edge in [float(kicker.gap_start), float(kicker.gap_end)]:
		var edge_basis: Basis = world.frame(edge)
		var toward_gap: float = 0.25 if edge == float(kicker.gap_start) else -0.25
		var face: Vector3 = world.position_at(edge - toward_gap) - edge_basis.y * 0.9
		world._prop("box", face, Vector3(half * 2.0 + 1.6, 1.8, 0.5), NAVY, edge_basis)
		world._prop(
			"box",
			world.position_at(edge - toward_gap) + edge_basis.y * 0.04,
			Vector3(half * 2.0 + 1.6, 0.08, 0.5),
			CYAN,
			edge_basis,
			true
		)
	# Landing zone: green bar where the road begins again, orange bar at its end,
	# side gates at both ends and soft green strips along the zone edges.
	var zone_start: float = take_off + float(kicker.landing_min)
	var zone_end: float = take_off + float(kicker.landing_max)
	var green := Color("45e07a")
	for entry in [[zone_start + 0.2, green], [zone_end, ORANGE]]:
		var d: float = float(entry[0])
		var basis: Basis = world.frame(d)
		world._prop(
			"box",
			world.position_at(d) + basis.y * 0.03,
			Vector3(half * 2.0, 0.03, 0.5),
			entry[1],
			basis,
			true
		)
		for side in [-1.0, 1.0]:
			var post: Vector3 = world.position_at(d, side * 6.4)
			world._prop(
				"box", post + basis.y * 1.5, Vector3(0.28, 3.0, 0.28), entry[1], basis, true
			)
		world._prop(
			"box",
			world.position_at(d) + basis.y * 3.05,
			Vector3(13.1, 0.24, 0.28),
			entry[1],
			basis,
			true
		)
	var along: float = zone_start + 1.0
	while along < zone_end - 0.5:
		var basis: Basis = world.frame(along)
		for side in [-1.0, 1.0]:
			world._prop(
				"box",
				world.position_at(along, side * (half - 0.25)) + basis.y * 0.025,
				Vector3(0.22, 0.02, 1.6),
				green,
				basis,
				true
			)
		along += 2.5
	_build_crystal_gorge(world, kicker)


## A stylised chasm below the true, physically empty road gap.
## All features are batched non-collidable meshes; the existing ramp,
## landing plane, checkpoints and child-friendly failure rescue are untouched.
## Low profile produces the same silhouette with fewer glowing props.
static func _build_crystal_gorge(world, kicker: Dictionary) -> void:
	var start: float = float(kicker.gap_start)
	var end: float = float(kicker.gap_end)
	if end <= start:
		return
	var length: float = end - start
	var sections: int = 5 if world.low_detail else 11
	var dark_stone := Color("13243a")
	var cliff_stone := Color("345271")
	var deep_water := Color("103b69")
	var crystal := Color("79ecff")
	var violet := Color("a985f8")
	var slice_length: float = length / float(sections)
	for i in range(sections):
		var d: float = start + (float(i) + 0.5) * slice_length
		var basis: Basis = world.frame(d)
		# The dark riverbed and its thin glowing stream are far below the
		# road; a missed jump remains a real fall, never an invisible bridge.
		var floor: Vector3 = world.position_at(d) - basis.y * 10.4
		world._prop("box", floor, Vector3(14.8, 0.50, slice_length + 0.24), dark_stone, basis)
		world._prop(
			"box",
			floor + basis.y * 0.31,
			Vector3(6.3, 0.08, slice_length + 0.15),
			deep_water,
			basis,
			true
		)
		# Sculpted staggered walls frame the vertical drop. The glowing
		# crevices are on the walls, not on the invisible racing surface.
		for side in [-1.0, 1.0]:
			var left_or_right: float = side * (RAMP_HALF_WIDTH + 4.9)
			# Rock mesh top = centre + 0.81 x height (7.3 m), plus up to 0.5 m from
			# road banking: 9.1 m down keeps every wall top below kart level.
			var rock_pos: Vector3 = world.position_at(d, left_or_right) - basis.y * 9.1
			var shoulder: float = 1.0 + float((i * 3) % 4) * 0.10
			world._prop(
				"rock",
				rock_pos,
				Vector3(5.0 * shoulder, 9.0, slice_length + 2.0),
				cliff_stone if (i + int(side)) % 2 == 0 else dark_stone,
				basis
			)
			# A pair of distinct crystal veins creates readable depth.
			if not world.low_detail or i % 2 == 0:
				var face: Vector3 = (
					world.position_at(d, side * (RAMP_HALF_WIDTH + 1.8))
					- basis.y * (5.0 + float(i % 3) * 0.7)
				)
				world._prop(
					"box",
					face,
					Vector3(0.16, 2.4, maxf(0.8, slice_length * 0.58)),
					crystal if i % 3 != 0 else violet,
					basis,
					true
				)
		if not world.low_detail:
			# Repeating low-cost glimmers read as flowing water at speed.
			for lane in [-2.0, 0.0, 2.0]:
				var ripple: Vector3 = world.position_at(d, lane) - basis.y * 9.95
				world._prop(
					"box",
					ripple,
					Vector3(0.18, 0.08, 0.95),
					crystal if i % 2 == 0 else violet,
					basis,
					true
				)
	# Bright anchor crystals at each canyon mouth help a child read the
	# near and far edges during approach, but never block driving.
	for d in [start + 1.5, end - 1.5]:
		var basis: Basis = world.frame(d)
		for side in [-1.0, 1.0]:
			var p: Vector3 = world.position_at(d, side * (RAMP_HALF_WIDTH + 4.0)) - basis.y * 2.4
			world._prop("rock", p, Vector3(1.5, 3.3, 1.5), violet, basis, true)


static func _balloons(world) -> void:
	var start: float = loop_start(world)
	for entry in BALLOONS:
		var d: float = start + float(entry[0])
		var size: float = float(entry[3])
		var basis: Basis = world.frame(d)
		var at: Vector3 = world.position_at(d, float(entry[1])) + Vector3.UP * float(entry[2])
		var envelope := MeshInstance3D.new()
		envelope.name = "StuntBalloon"
		var sphere := SphereMesh.new()
		sphere.radius = 4.0
		sphere.height = 9.2
		sphere.radial_segments = 24
		sphere.rings = 12
		envelope.mesh = sphere
		var material := ShaderMaterial.new()
		material.shader = BALLOON_SHADER
		envelope.material_override = material
		envelope.position = at
		envelope.scale = Vector3.ONE * size
		world.add_child(envelope)
		# Emblem faces the road so drivers see Lumo on the balloon.
		var to_road: Vector3 = world.position_at(d) - at
		to_road.y = 0.0
		var facing := Basis.looking_at(-to_road.normalized(), Vector3.UP)
		var emblem := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(4.4, 4.4) * size
		emblem.mesh = quad
		var emblem_material := StandardMaterial3D.new()
		emblem_material.albedo_texture = EMBLEM
		emblem_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		emblem_material.alpha_scissor_threshold = 0.5
		emblem_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		emblem.material_override = emblem_material
		emblem.basis = facing
		emblem.position = at + to_road.normalized() * 4.05 * size + Vector3.UP * 0.6 * size
		world.add_child(emblem)
		var basket: Vector3 = at - Vector3.UP * 6.4 * size
		world._prop("box", basket, Vector3(1.6, 1.1, 1.6) * size, Color("8a5a32"), basis)
		for corner in [
			Vector3(-0.7, 0, -0.7),
			Vector3(0.7, 0, -0.7),
			Vector3(-0.7, 0, 0.7),
			Vector3(0.7, 0, 0.7)
		]:
			world._beam(
				basket + corner * size + Vector3.UP * 0.5 * size,
				at + corner * 2.2 * size - Vector3.UP * 3.4 * size,
				0.06,
				Color("4a3a2a")
			)
