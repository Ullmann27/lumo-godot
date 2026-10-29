extends RefCounted
## Sonnenhafen stunt sequence in front of the crystal tunnel (dark ride at
## 69 % of the lap). Position A, about 100 m before the tunnel mouth, gets a
## real, drivable 360° loop on the right lane:
## - the kart follows the same 3D path that is rendered (kart_physical_loop),
##   gravity slows the climb and a too-slow kart is set back to the main lane;
## - a boost pad on the loop lane gives the needed speed;
## - gold stars on the riding line are collected while looping.
## Everything else (main lane, rails, checkpoints, lap length) stays unchanged.

const LOOP = preload("res://scripts/games/kart_physical_loop.gd")
const SHAPES = preload("res://scripts/games/kart_world_meshes.gd")
const DECK_SHADER = preload("res://assets/shaders/kart_stunt_loop.gdshader")

const TUNNEL_FRACTION: float = 0.690
## Loop entry this many metres before the tunnel mouth (Position A).
const LOOP_LEAD_M: float = 108.0
const LOOP_LANE: float = 2.9
const LOOP_RADIUS: float = 8.0
const DECK_HALF_WIDTH: float = 2.4
const WALL_HEIGHT: float = 0.55
const DECK_SEGMENTS: int = 160
## Boost pad on the loop lane, ending this far before the loop entry.
const PAD_GAP_M: float = 16.0
const PAD_LENGTH: float = 6.0
const STAR_FRACTIONS: Array[float] = [0.14, 0.27, 0.40, 0.5, 0.60, 0.73, 0.86]

## Position B, 80 m before the tunnel: a full-width panorama kicker right after
## the loop exit. Same flight model as the 55 % panorama jump.
const JUMP_LEAD_M: float = 80.0
const JUMP_RAMP_LENGTH: float = 12.0
const JUMP_RAMP_HEIGHT: float = 2.2
## Stars along the measured flight arc (metres after take-off, height above road).
const ARC_STARS: Array = [[5.0, 2.6], [10.0, 3.7], [15.0, 4.1], [20.0, 3.6]]

## Tunnel portal at the dark-ride mouth (lateral legs outside the rails).
const PORTAL_SETBACK_M: float = 1.5
const PORTAL_RADIUS: float = 9.2
const PORTAL_BASE_HEIGHT: float = 0.9
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
	return [
		{
			"start": take_off - JUMP_RAMP_LENGTH,
			"take_off": take_off,
			"length": JUMP_RAMP_LENGTH,
			"height": JUMP_RAMP_HEIGHT,
			"angle": atan2(JUMP_RAMP_HEIGHT, JUMP_RAMP_LENGTH),
			"flight_gravity": 14.0,
			"lift_bonus": 5.0,
			"max_lift": 11.0,
			"hero_flight": true,
			"stunt": true,
		}
	]


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
	for entry in ARC_STARS:
		var d: float = take_off + float(entry[0])
		result.append(world.position_at(d, 0.0) + Vector3.UP * (float(entry[1]) + 0.95))
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
