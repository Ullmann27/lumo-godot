class_name LumoSkyIslands
extends RefCounted
## "Himmelsinseln Sprint" (reference k07): floating islands carry the road, stone bridges span
## the gaps, waterfalls fall into a moonlit cloud sea, and the floating town, temple ruins,
## crystal cave and the LUMO KART gate mark the six sections. Everything is procedural and
## original; the reference pictures only guided composition, palette and landmarks.

const NIGHT_SKY = preload("res://assets/shaders/kart_night_sky.gdshader")
const CLOUD_SEA = preload("res://assets/shaders/kart_cloud_sea.gdshader")
const WATERFALL = preload("res://assets/shaders/kart_waterfall.gdshader")
const VISUAL_GRADE = preload("res://scripts/games/kart_visual_grade.gd")

## Course fractions carried by islands (start, floating town, crystal cave, temple ruins).
## Everything between them is bridge.
const ISLANDS: Array[Vector2] = [
	Vector2(-0.07, 0.13), Vector2(0.27, 0.40), Vector2(0.514, 0.60), Vector2(0.68, 0.77)
]
const TOWN: float = 0.335
const CAVE: float = 0.555
const RUINS: float = 0.715
const SUSPENSION: float = 0.635
const STAR_GATE: float = 0.865
## Second physical setpiece: the left lane climbs onto a short elevated "Wolkenweg" while
## the right lane stays on the main deck. Both rejoin before the Sternentor.
const SPLIT_ROUTE: float = 0.800
const SPLIT_SPAN: float = 22.0
const SPLIT_RISE: float = 6.0
const SPLIT_HEIGHT: float = 2.2
const SPLIT_LEFT_LANE: float = -2.8
## Jump (k03 shortcut ramp): ramp on the downhill bridge before the crystal-cave island,
## then open sky until that island begins. Metres along the course.
const RAMP_LENGTH: float = 7.0
const GAP_LENGTH: float = 8.0
const RAMP_HEIGHT: float = 1.8
## Islands extend this far beyond their span (see _road_island).
const ISLAND_PADDING: float = 10.0
const CLOUD_LEVEL: float = -38.0
const MOON_DIRECTION := Vector3(0.32, 0.42, -0.85)
const GRASS := Color("4f9a44")
const GRASS_LIGHT := Color("78c24f")
const MOSS := Color("2f6f52")
const ROCK := Color("8d8396")
const ROCK_DARK := Color("413f5c")
const STONE := Color("a39b8f")
const STONE_DARK := Color("7d7a86")
const ROOF := Color("2f4fb8")
const NAVY := Color("16244f")
const RAIL_BLUE := Color("2c5bd1")
const GOLD := Color("ffc94a")
const CYAN := Color("4fe6ff")
const ORANGE := Color("ff9a3c")
const WINDOW := Color("ffd27a")
const CRYSTAL_VIOLET := Color("b07bff")
const CAVE_PALETTE: Dictionary = {
	"inner": Color("3b3460"),
	"outer": Color("6f6890"),
	"stripes": [Color("5b4f8c"), Color("4a4278")],
	"boulder": Color("5a5478"),
	"lamp": Color("b07bff")
}


static func is_bridge(t: float) -> bool:
	t = fposmod(t, 1.0)
	for span in ISLANDS:
		if span.x < 0.0:
			if t >= fposmod(span.x, 1.0) or t <= span.y:
				return false
		elif t >= span.x and t <= span.y:
			return false
	return true


## Ramp start, ramp end (take-off) and gap end (landing edge) in metres; the gap ends exactly
## where the crystal-cave island begins.
static func jump_layout(length: float) -> Dictionary:
	var gap_end: float = ISLANDS[2].x * length - ISLAND_PADDING
	var take_off: float = gap_end - GAP_LENGTH
	return {
		"ramp_start": take_off - RAMP_LENGTH,
		"take_off": take_off,
		"gap_end": gap_end,
		"height": RAMP_HEIGHT,
		"angle": atan2(RAMP_HEIGHT, RAMP_LENGTH)
	}


static func in_gap(jump: Dictionary, distance: float) -> bool:
	return not jump.is_empty() and distance >= jump.take_off and distance < jump.gap_end


static func split_route_layout(length: float) -> Dictionary:
	var centre: float = SPLIT_ROUTE * length
	return {
		"start": centre - SPLIT_SPAN * 0.5,
		"end": centre + SPLIT_SPAN * 0.5,
		"rise": SPLIT_RISE,
		"height": SPLIT_HEIGHT,
		"lane": SPLIT_LEFT_LANE,
	}


static func split_route_height(length: float, distance: float, lateral: float) -> float:
	var layout: Dictionary = split_route_layout(length)
	var d: float = fposmod(distance, length)
	var start: float = float(layout.start)
	var finish: float = float(layout.end)
	if d < start or d > finish:
		return 0.0
	var longitudinal: float = 1.0
	var rise: float = float(layout.rise)
	if d < start + rise:
		longitudinal = smoothstep(0.0, 1.0, (d - start) / rise)
	elif d > finish - rise:
		longitudinal = smoothstep(0.0, 1.0, (finish - d) / rise)
	# Smoothly blend from the centre divider toward the raised left lane so changing lanes
	# never teleports the kart vertically.
	var lane_mix: float = clampf((-lateral - 0.45) / 1.85, 0.0, 1.0)
	lane_mix = smoothstep(0.0, 1.0, lane_mix)
	return float(layout.height) * longitudinal * lane_mix


static func split_route_pitch(length: float, distance: float, lateral: float) -> float:
	var sample: float = 0.35
	var before: float = split_route_height(length, distance - sample, lateral)
	var after: float = split_route_height(length, distance + sample, lateral)
	return atan2(after - before, sample * 2.0)


## The orange shortcut ramp with yellow chevrons, light barriers across the gap and a glowing
## landing edge.
static func jump_dressing(world) -> void:
	var jump: Dictionary = world.jump
	var steps: int = 10
	for i in range(steps):
		var d0: float = jump.ramp_start + float(i) * RAMP_LENGTH / steps
		var d1: float = d0 + RAMP_LENGTH / steps
		var basis: Basis = world.frame((d0 + d1) * 0.5)
		var rise: float = (float(i) + 0.5) / steps * RAMP_HEIGHT
		var at: Vector3 = world.position_at((d0 + d1) * 0.5) + basis.y * (rise * 0.5)
		world._prop("box", at, Vector3(10.6, rise + 0.08, d1 - d0 + 0.02), Color("8a4b1c"), basis)
	# Smooth driving surface on top of the stepped body, with glowing chevrons.
	var middle: float = jump.ramp_start + RAMP_LENGTH * 0.5
	var mid_basis: Basis = world.frame(middle)
	var slope: Basis = mid_basis.rotated(mid_basis.x, float(jump.angle))
	var slab_at: Vector3 = world.position_at(middle) + mid_basis.y * (RAMP_HEIGHT * 0.5 + 0.04)
	var slab_length: float = sqrt(RAMP_LENGTH * RAMP_LENGTH + RAMP_HEIGHT * RAMP_HEIGHT)
	world._prop("box", slab_at, Vector3(10.6, 0.12, slab_length), Color("ff9d3c"), slope)
	for chevron in range(3):
		var along: float = (float(chevron) - 1.0) * 2.1
		var tip: Vector3 = slab_at - slope.z * along + slope.y * 0.08
		for arm in [-1.0, 1.0]:
			var arm_basis: Basis = slope * Basis(Vector3.UP, arm * 0.62)
			var arm_at: Vector3 = tip + slope.x * arm * 0.9 + slope.z * 0.4
			world._prop("box", arm_at, Vector3(2.2, 0.03, 0.32), Color("ffe36b"), arm_basis, true)
	for side in [-1.0, 1.0]:
		var a: Vector3 = world.position_at(jump.take_off, side * world.RAIL_LATERAL) + Vector3.UP
		var b: Vector3 = world.position_at(jump.gap_end, side * world.RAIL_LATERAL) + Vector3.UP
		world._beam(a, b, 0.08, CYAN, true)
		world._beam(a - Vector3.UP * 0.45, b - Vector3.UP * 0.45, 0.06, CYAN, true)
		for end in [jump.take_off, jump.gap_end]:
			var post: Vector3 = world.position_at(end, side * world.RAIL_LATERAL)
			world._prop("box", post + Vector3.UP * 1.2, Vector3(0.35, 2.4, 0.35), NAVY)
			world._prop(
				"ball", post + Vector3.UP * 2.5, Vector3.ONE * 0.3, ORANGE, Basis.IDENTITY, true
			)
	var landing: Basis = world.frame(jump.gap_end + 0.6)
	world._prop(
		"box",
		world.position_at(jump.gap_end + 0.6) + landing.y * 0.04,
		Vector3(10.6, 0.05, 0.5),
		ORANGE,
		landing,
		true
	)
	var sign_basis: Basis = world.frame(jump.ramp_start - 14.0)
	var sign_at: Vector3 = world.position_at(jump.ramp_start - 14.0, 7.6)
	world._prop("box", sign_at + Vector3.UP * 1.4, Vector3(0.14, 2.8, 0.14), NAVY)
	world._prop(
		"box", sign_at + Vector3.UP * 2.6, Vector3(3.2, 1.2, 0.16), Color("1c3aa6"), sign_basis
	)
	world._sign(
		sign_at + Vector3.UP * 2.6 + sign_basis.z * 0.1, sign_basis, "SPRUNG!\nSchwung holen", 0.012
	)


## Einmal angelegt und wiederverwendet: Ein schon gezeichneter Himmel, der freigegeben wird, lässt im
## Kompatibilitäts-Renderer (Godot 4.6.3) zwei Spiegelungstexturen bis zum Beenden liegen.
static var _sky: Sky


static func _night_sky() -> Sky:
	if _sky == null:
		_sky = Sky.new()
		var sky_material := ShaderMaterial.new()
		sky_material.shader = NIGHT_SKY
		sky_material.set_shader_parameter("moon_direction", MOON_DIRECTION)
		_sky.sky_material = sky_material
	return _sky


static func environment(world) -> void:
	var visual: Dictionary = VISUAL_GRADE.environment_profile("bergwelt", world.low_detail)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = _night_sky()
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("8597dd")
	environment.ambient_light_energy = 0.48 if not world.low_detail else 0.36
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = float(visual.exposure)
	environment.glow_enabled = bool(visual.glow)
	environment.glow_intensity = float(visual.glow_intensity)
	environment.glow_bloom = float(visual.glow_bloom)
	environment.glow_hdr_threshold = float(visual.glow_threshold)
	environment.adjustment_enabled = not world.low_detail
	environment.adjustment_brightness = float(visual.brightness)
	environment.adjustment_contrast = float(visual.contrast)
	environment.adjustment_saturation = float(visual.saturation)
	environment.fog_enabled = true
	environment.fog_light_color = Color("3a4c98")
	environment.fog_density = 0.0014
	environment.fog_aerial_perspective = 0.4
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	world.add_child(world_environment)
	var moon := DirectionalLight3D.new()
	moon.name = "Moonlight"
	moon.basis = Basis.looking_at(-MOON_DIRECTION.normalized(), Vector3.UP)
	moon.light_color = Color("c3d0ff")
	moon.light_energy = 0.95
	moon.shadow_enabled = not world.low_detail
	moon.directional_shadow_max_distance = 85.0
	moon.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	moon.shadow_bias = 0.13
	moon.shadow_normal_bias = 1.3
	world.add_child(moon)
	var warm := DirectionalLight3D.new()
	warm.name = "TownGlow"
	warm.rotation_degrees = Vector3(-18, 150, 0)
	warm.light_color = Color("ffb36b")
	warm.light_energy = 0.32
	warm.shadow_enabled = false
	world.add_child(warm)


static func build(world) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(world.definition.seed)
	_cloud_sea(world)
	for index in range(ISLANDS.size()):
		_road_island(world, ISLANDS[index], 7100 + index * 37, rng)
	_bridges(world, rng)
	_waterfall_islands(world, rng)
	_floating_town(world, TOWN * world.length, rng)
	_temple_ruins(world, RUINS * world.length, rng)
	_split_sky_bridge(world, SPLIT_ROUTE * world.length)
	_star_gate_run(world, STAR_GATE * world.length)
	_backdrop(world, rng)
	_blimp(world)


static func _cloud_sea(world) -> void:
	var sea := MeshInstance3D.new()
	sea.name = "MoonlitCloudSea"
	var plane := PlaneMesh.new()
	plane.size = Vector2(1400, 1400)
	sea.mesh = plane
	sea.position.y = CLOUD_LEVEL
	var material := ShaderMaterial.new()
	material.shader = CLOUD_SEA
	sea.material_override = material
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(sea)
	var puffs := RandomNumberGenerator.new()
	puffs.seed = 4411
	for i in range(26):
		var angle: float = float(i) * TAU / 26.0 + puffs.randf_range(-0.1, 0.1)
		var radius: float = puffs.randf_range(95, 210)
		var at := Vector3(cos(angle) * radius, puffs.randf_range(-33, -27), sin(angle) * radius)
		for part in range(3):
			world._prop(
				"crown",
				at + Vector3(part * 7.0, sin(float(part)) * 0.8, part * 2.5),
				Vector3(13, 2.6, 9) * puffs.randf_range(0.8, 1.3),
				Color("aab4ea")
			)


## A long island following the road: grass top, mossy rim, rocky keel, closed ends.
static func _road_island(world, span: Vector2, seed: int, rng: RandomNumberGenerator) -> void:
	var noise := RandomNumberGenerator.new()
	noise.seed = seed
	var length: float = world.length
	var start: float = span.x * length - 10.0
	var finish: float = span.y * length + 10.0
	var count: int = ceili((finish - start) / 2.5)
	var wobble: Array[float] = []
	for i in range(count + 1):
		wobble.append(noise.randf_range(-1.0, 1.0))
	var rings: Array = []
	var colors: Array = []
	for i in range(count + 1):
		var d: float = start + float(i) * (finish - start) / count
		var u: float = float(i) / count
		var taper: float = pow(sin(u * PI), 0.6)
		var basis: Basis = world.frame(d)
		var centre: Vector3 = world.position_at(d)
		var right := Vector3(basis.x.x, 0.0, basis.x.z).normalized()
		var edge_y: float = minf(world.position_at(d, -6.3).y, world.position_at(d, 6.3).y) - 0.55
		var smooth_wobble: float = (
			(wobble[maxi(i - 1, 0)] + wobble[i] * 2.0 + wobble[mini(i + 1, count)]) * 0.25
		)
		var left_width: float = 7.2 + (9.0 + smooth_wobble * 3.0) * taper
		var right_width: float = 7.2 + (9.0 - smooth_wobble * 3.0) * taper
		if absf(d / length - TOWN) < 0.07:
			left_width += 9.0 * taper
		if absf(d / length - RUINS) < 0.05:
			right_width += 7.0 * taper
		var depth: float = 4.0 + (11.0 + absf(smooth_wobble) * 6.0) * taper
		var ring: Array[Vector3] = []
		var tint: Array[Color] = []
		var left_rim: Vector3 = centre - right * left_width
		left_rim.y = edge_y - 0.9
		var right_rim: Vector3 = centre + right * right_width
		right_rim.y = edge_y - 0.9
		var left_mid: Vector3 = centre - right * (6.3 + (left_width - 6.3) * 0.5)
		left_mid.y = edge_y - 0.25
		var right_mid: Vector3 = centre + right * (6.3 + (right_width - 6.3) * 0.5)
		right_mid.y = edge_y - 0.25
		var left_edge: Vector3 = centre - right * 6.3
		left_edge.y = edge_y
		var right_edge: Vector3 = centre + right * 6.3
		right_edge.y = edge_y
		var deck: Vector3 = centre
		deck.y = centre.y - 0.9
		ring = [
			left_rim,
			left_mid,
			left_edge,
			deck,
			right_edge,
			right_mid,
			right_rim,
			_at_height(centre + right * right_width * 0.97, right_rim.y - 1.7),
			_at_height(centre + right * right_width * 0.55, right_rim.y - depth * 0.55),
			Vector3(centre.x, right_rim.y - depth, centre.z),
			_at_height(centre - right * left_width * 0.55, left_rim.y - depth * 0.55),
			_at_height(centre - right * left_width * 0.97, left_rim.y - 1.7)
		]
		var grass: Color = GRASS.lerp(GRASS_LIGHT, 0.5 + smooth_wobble * 0.5)
		tint = [
			MOSS,
			grass,
			grass,
			ROCK_DARK,
			grass,
			grass,
			MOSS,
			ROCK,
			ROCK.lerp(ROCK_DARK, 0.5),
			ROCK_DARK,
			ROCK.lerp(ROCK_DARK, 0.5),
			ROCK
		]
		rings.append(ring)
		colors.append(tint)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var size: int = rings[0].size()
	for i in range(count):
		for k in range(size):
			var a: Vector3 = rings[i][k]
			var b: Vector3 = rings[i][(k + 1) % size]
			var c: Vector3 = rings[i + 1][k]
			var e: Vector3 = rings[i + 1][(k + 1) % size]
			var ca: Color = colors[i][k]
			var cb: Color = colors[i][(k + 1) % size]
			var cc: Color = colors[i + 1][k]
			var ce: Color = colors[i + 1][(k + 1) % size]
			for pair in [[a, ca], [c, cc], [b, cb], [b, cb], [c, cc], [e, ce]]:
				surface.set_color(pair[1])
				surface.add_vertex(pair[0])
	for cap in [0, count]:
		var ring: Array = rings[cap]
		var middle := Vector3.ZERO
		for p in ring:
			middle += p
		middle /= float(ring.size())
		for k in range(size):
			for pair in [
				[middle, ROCK],
				[ring[k], colors[cap][k]],
				[ring[(k + 1) % size], colors[cap][(k + 1) % size]]
			]:
				surface.set_color(pair[1])
				surface.add_vertex(pair[0])
	surface.generate_normals()
	var island := MeshInstance3D.new()
	island.name = "FloatingRoadIsland"
	island.mesh = surface.commit()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.9
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	island.material_override = material
	world.add_child(island)
	_island_dressing(world, rings, rng, seed)


static func _at_height(point: Vector3, height: float) -> Vector3:
	return Vector3(point.x, height, point.z)


## Trees, bushes, rocks, lanterns and hanging rocks on and under a road island.
static func _island_dressing(
	world, rings: Array, rng: RandomNumberGenerator, seed: int
) -> void:
	var detail_rng := RandomNumberGenerator.new()
	detail_rng.seed = seed + 0x51A1
	for i in range(2, rings.size() - 2, 2):
		var ring: Array = rings[i]
		for side in [0, 6]:
			var rim: Vector3 = ring[side]
			var inner: Vector3 = ring[2 if side == 0 else 4]
			var span: float = Vector2(rim.x - inner.x, rim.z - inner.z).length()
			if span < 4.0:
				continue
			var t: float = rng.randf_range(0.35, 0.85)
			var at: Vector3 = inner.lerp(rim, t)
			at.y = lerpf(inner.y, rim.y, t) - 0.1
			var roll: float = rng.randf()
			if roll < 0.32 and not world.low_detail:
				world._tree(at, rng.randf_range(0.7, 1.15), rng)
			elif roll < 0.62:
				world._prop(
					"crown",
					at + Vector3.UP * 0.4,
					Vector3(1.4, 0.9, 1.2) * rng.randf_range(0.8, 1.4),
					MOSS.lightened(0.15)
				)
				for flower in range(3):
					var bloom: Vector3 = (
						at + Vector3(rng.randf_range(-1.2, 1.2), 0.2, rng.randf_range(-1.2, 1.2))
					)
					world._prop(
						"flower",
						bloom,
						Vector3.ONE * rng.randf_range(0.8, 1.2),
						[Color("ffb0d0"), Color("fff1a8"), Color("b9d4ff")][flower]
					)
			elif roll < 0.8:
				world._prop(
					"rock",
					at,
					Vector3(1.3, 1.0, 1.2) * rng.randf_range(0.8, 1.6),
					ROCK,
					Basis(Vector3.UP, rng.randf() * TAU)
				)
			if i % 4 == 0:
				var cluster_t: float = detail_rng.randf_range(0.68, 0.96)
				var cluster_at: Vector3 = inner.lerp(rim, cluster_t)
				cluster_at.y = lerpf(inner.y, rim.y, cluster_t) + 0.12
				if detail_rng.randf() < 0.72:
					var crystal_color: Color = CRYSTAL_VIOLET if detail_rng.randf() < 0.55 else CYAN
					world._prop(
						"crystal",
						cluster_at,
						Vector3(0.8, 1.45, 0.8) * detail_rng.randf_range(0.8, 1.35),
						crystal_color,
						Basis(Vector3.UP, detail_rng.randf() * TAU),
						true
					)
				if detail_rng.randf() < 0.6:
					world._prop(
						"rock",
						cluster_at
						+ Vector3(detail_rng.randf_range(-1.3, 1.3), -0.2, detail_rng.randf_range(-1.3, 1.3)),
						Vector3(1.6, 1.0, 1.5) * detail_rng.randf_range(0.7, 1.15),
						ROCK_DARK,
						Basis(Vector3.UP, detail_rng.randf() * TAU)
					)
		if i % 6 == 0:
			var keel: Vector3 = ring[9]
			world._prop(
				"rock",
				(
					keel
					+ Vector3(
						rng.randf_range(-3, 3), -rng.randf_range(2, 5), rng.randf_range(-3, 3)
					)
				),
				Vector3(2.2, 1.8, 2.0) * rng.randf_range(0.6, 1.3),
				ROCK_DARK,
				Basis(Vector3.UP, rng.randf() * TAU)
			)


static func _bridges(world, _rng: RandomNumberGenerator) -> void:
	var length: float = world.length
	var step: float = 2.0
	var count: int = ceili(length / step)
	for i in range(count):
		var d: float = (float(i) + 0.5) * step
		var t: float = d / length
		if not is_bridge(t) or absf(t - SUSPENSION) < 0.035 or in_gap(world.jump, d):
			continue
		var basis: Basis = world.frame(d)
		var at: Vector3 = world.position_at(d)
		world._prop("box", at - basis.y * 1.05, Vector3(13.4, 1.25, step + 0.05), STONE, basis)
		world._prop("box", at - basis.y * 1.72, Vector3(12.2, 0.25, step + 0.05), STONE_DARK, basis)
		if i % 6 == 0:
			for side in [-1.0, 1.0]:
				var pier: Vector3 = world.position_at(d, side * 4.6) - Vector3.UP * 5.2
				world._prop("box", pier, Vector3(1.5, 7.4, 1.7), STONE, basis)
				world._prop(
					"rock",
					pier - Vector3.UP * 4.6,
					Vector3(2.1, 2.0, 2.1),
					ROCK,
					Basis(Vector3.UP, float(i))
				)
		if i % 6 == 3:
			# A stone arch between two piers, built from short beam segments.
			var a: Vector3 = world.position_at(d - 6.0) - Vector3.UP * 1.9
			var b: Vector3 = world.position_at(d + 6.0) - Vector3.UP * 1.9
			var previous: Vector3 = a
			for segment in range(1, 7):
				var s: float = float(segment) / 6.0
				var p: Vector3 = a.lerp(b, s) - Vector3.UP * sin(s * PI) * 3.6
				world._beam(previous, p, 0.9, STONE_DARK)
				previous = p
		if i % 5 == 0:
			for side in [-1.0, 1.0]:
				var post: Vector3 = world.position_at(d, side * 6.75)
				world._prop("cylinder", post + Vector3.UP * 1.7, Vector3(0.09, 3.4, 0.09), NAVY)
				world._prop(
					"ball",
					post + Vector3.UP * 3.5,
					Vector3.ONE * 0.28,
					WINDOW,
					Basis.IDENTITY,
					true
				)
	world._suspension_bridge(
		SUSPENSION * length,
		30.0,
		{
			"tower": STONE_DARK,
			"cap": GOLD,
			"crossbeam": Color("1d3a9a"),
			"cable": GOLD.darkened(0.25),
			"hanger": Color("c9d3ff")
		}
	)


## Round floating islands beside the bridges, each with waterfalls into the clouds.
static func _waterfall_islands(world, rng: RandomNumberGenerator) -> void:
	var spots: Array[Vector3] = [
		Vector3(0.18, -1.0, 30.0),
		Vector3(0.22, 1.0, 34.0),
		Vector3(0.43, 1.0, 27.0),
		Vector3(0.62, -1.0, 36.0),
		Vector3(0.82, 1.0, 30.0),
		Vector3(0.88, -1.0, 33.0)
	]
	for spot in spots:
		var d: float = spot.x * world.length
		var basis: Basis = world.frame(d)
		var outward := Vector3(basis.x.x, 0, basis.x.z).normalized() * spot.y
		var centre: Vector3 = world.position_at(d) + outward * spot.z
		centre.y = world.position_at(d).y + rng.randf_range(-6.0, 3.0)
		var radius: float = rng.randf_range(9.0, 14.0)
		_round_island(world, centre, radius, radius * 1.4, rng)
		for fall in range(2):
			var angle: float = atan2(-outward.z, -outward.x) + (float(fall) - 0.5) * 0.9
			var lip := Vector3(cos(angle), 0, sin(angle))
			_waterfall(
				world,
				centre + lip * (radius - 0.4) + Vector3.UP * 0.2,
				lip,
				rng.randf_range(3.0, 4.6)
			)
		if rng.randf() > 0.4 and not world.low_detail:
			world._tree(centre + Vector3.UP * 0.6, 1.2, rng)


static func _round_island(
	world, centre: Vector3, radius: float, depth: float, rng: RandomNumberGenerator
) -> void:
	var sides: int = 20
	var profile: Array[Vector2] = [
		Vector2(0.0, 0.6),
		Vector2(0.55, 0.45),
		Vector2(0.97, 0.0),
		Vector2(0.94, -0.12),
		Vector2(0.62, -0.5),
		Vector2(0.28, -0.82),
		Vector2(0.0, -1.0)
	]
	var tints: Array[Color] = [
		GRASS_LIGHT, GRASS, MOSS, ROCK, ROCK.lerp(ROCK_DARK, 0.4), ROCK_DARK, ROCK_DARK
	]
	var jitter: Array[float] = []
	for side in range(sides):
		jitter.append(rng.randf_range(0.86, 1.12))
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in range(profile.size() - 1):
		for side in range(sides):
			var corners: Array = []
			for corner in [[ring, side], [ring, side + 1], [ring + 1, side], [ring + 1, side + 1]]:
				var angle: float = float(corner[1]) * TAU / sides
				var p: Vector2 = profile[corner[0]]
				var scale: float = jitter[corner[1] % sides] if corner[0] > 0 else 1.0
				var height: float = p.y * (depth if p.y < 0.0 else 1.0)
				corners.append(
					[
						(
							centre
							+ Vector3(
								cos(angle) * p.x * radius * scale,
								height,
								sin(angle) * p.x * radius * scale
							)
						),
						tints[corner[0]]
					]
				)
			for index in [0, 2, 1, 1, 2, 3]:
				surface.set_color(corners[index][1])
				surface.add_vertex(corners[index][0])
	surface.generate_normals()
	var island := MeshInstance3D.new()
	island.name = "FloatingWaterfallIsland"
	island.mesh = surface.commit()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.9
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	island.material_override = material
	world.add_child(island)


static func _waterfall(world, lip: Vector3, outward: Vector3, width: float) -> void:
	var along := Vector3(-outward.z, 0, outward.x)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bottom: float = CLOUD_LEVEL + 4.0
	var rows: int = 10
	for row in range(rows):
		var v0: float = float(row) / rows
		var v1: float = float(row + 1) / rows
		var p0: Vector3 = lip + outward * (sqrt(v0) * 2.6) + Vector3.UP * (bottom - lip.y) * v0
		var p1: Vector3 = lip + outward * (sqrt(v1) * 2.6) + Vector3.UP * (bottom - lip.y) * v1
		var w0: float = width * (1.0 + v0 * 0.5)
		var w1: float = width * (1.0 + v1 * 0.5)
		var quad: Array = [
			[p0 - along * w0 * 0.5, Vector2(0, v0)],
			[p0 + along * w0 * 0.5, Vector2(1, v0)],
			[p1 - along * w1 * 0.5, Vector2(0, v1)],
			[p1 + along * w1 * 0.5, Vector2(1, v1)]
		]
		for index in [0, 2, 1, 1, 2, 3]:
			surface.set_uv(quad[index][1])
			surface.add_vertex(quad[index][0])
	surface.generate_normals()
	var fall := MeshInstance3D.new()
	fall.name = "Waterfall"
	fall.mesh = surface.commit()
	var material := ShaderMaterial.new()
	material.shader = WATERFALL
	fall.material_override = material
	fall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(fall)
	var lip_basis := Basis.looking_at(outward, Vector3.UP)
	world._prop(
		"box",
		lip + outward * 0.55 + Vector3.UP * 0.12,
		Vector3(width + 0.8, 0.18, 1.1),
		Color("c9f5ff"),
		lip_basis,
		true
	)
	world._prop(
		"rock",
		lip + outward * 0.45 - Vector3.UP * 0.38,
		Vector3(width * 1.35, 0.72, 1.25),
		ROCK,
		lip_basis
	)
	var splash: Vector3 = lip + outward * 3.8 + Vector3.UP * (bottom - lip.y + 1.8)
	for puff in range(1 if world.low_detail else 3):
		var offset: Vector3 = along * (float(puff) - 1.0) * width * 0.3
		world._prop(
			"ball",
			splash + offset,
			Vector3(width * 0.42, 0.7, 1.2),
			Color("d7f4ff")
		)
	world._prop(
		"crown",
		splash + Vector3.UP * 0.1,
		Vector3(width * 1.1, 2.0, width),
		Color("eef3ff")
	)


static func _floating_town(world, distance: float, rng: RandomNumberGenerator) -> void:
	var basis: Basis = world.frame(distance)
	var outward := -Vector3(basis.x.x, 0, basis.x.z).normalized()
	var ahead := Vector3(-outward.z, 0, outward.x)
	var ground: float = (
		minf(world.position_at(distance, -6.3).y, world.position_at(distance, 6.3).y) - 0.9
	)
	var base: Vector3 = world.position_at(distance) + outward * 18.0
	base.y = ground
	var towers: Array[Vector4] = [
		Vector4(0.0, 0.0, 2.6, 15.0),
		Vector4(-7.0, 2.5, 1.8, 10.0),
		Vector4(7.5, 1.5, 2.0, 11.5),
		Vector4(3.5, 5.5, 1.5, 8.0),
		Vector4(-3.5, 6.0, 1.6, 9.0)
	]
	for tower in towers:
		var at: Vector3 = base + ahead * tower.x + outward * tower.y
		world._prop(
			"cylinder", at + Vector3.UP * tower.w * 0.5, Vector3(tower.z, tower.w, tower.z), STONE
		)
		world._prop(
			"cylinder",
			at + Vector3.UP * (tower.w + 0.2),
			Vector3(tower.z * 1.12, 0.4, tower.z * 1.12),
			STONE_DARK
		)
		world._prop(
			"cone",
			at + Vector3.UP * (tower.w + 0.4 + tower.z * 1.1),
			Vector3(tower.z * 1.15, tower.z * 2.2, tower.z * 1.15),
			ROOF
		)
		world._prop(
			"ball",
			at + Vector3.UP * (tower.w + 0.5 + tower.z * 2.25),
			Vector3.ONE * 0.25,
			GOLD,
			Basis.IDENTITY,
			true
		)
		for level in range(1, int(tower.w / 3.0)):
			for window_side in range(4):
				var angle: float = float(window_side) * PI / 2.0 + float(level) * 0.4
				var facing := Vector3(cos(angle), 0, sin(angle))
				var window_basis := Basis.looking_at(facing, Vector3.UP)
				world._prop(
					"box",
					at + facing * (tower.z * 0.98) + Vector3.UP * level * 3.0,
					Vector3(0.55, 0.9, 0.06),
					WINDOW,
					window_basis,
					true
				)
	for house in range(6):
		var offset: float = -10.0 + float(house) * 4.2
		var at: Vector3 = (
			base + ahead * offset - outward * 3.6 + outward * rng.randf_range(-0.5, 0.5)
		)
		var house_basis := Basis.looking_at(-outward, Vector3.UP)
		var height: float = rng.randf_range(3.2, 4.4)
		world._prop(
			"box",
			at + Vector3.UP * height * 0.5,
			Vector3(3.4, height, 3.0),
			Color("e8dcc4"),
			house_basis
		)
		world._prop(
			"roof", at + Vector3.UP * (height + 0.9), Vector3(3.8, 1.8, 3.4), ROOF, house_basis
		)
		for window_x in [-0.8, 0.8]:
			world._prop(
				"box",
				at + house_basis * Vector3(window_x, height * 0.55, -1.52),
				Vector3(0.6, 0.8, 0.05),
				WINDOW,
				house_basis,
				true
			)
	var sign_basis := Basis.looking_at(outward, Vector3.UP)
	world._prop(
		"box", base + Vector3.UP * 11.2 - outward * 2.7, Vector3(5.2, 1.6, 0.25), NAVY, sign_basis
	)
	world._prop(
		"box",
		base + Vector3.UP * 11.2 - outward * 2.85,
		Vector3(5.5, 1.85, 0.08),
		CYAN,
		sign_basis,
		true
	)
	world._sign(base + Vector3.UP * 11.2 - outward * 2.95, sign_basis, "LUMO", 0.05)
	_banner(
		world, world.position_at(distance - 22.0, -9.0), basis, "KLEINE SCHRITTE\nGROSSE ZIELE!"
	)


static func _temple_ruins(world, distance: float, rng: RandomNumberGenerator) -> void:
	var basis: Basis = world.frame(distance)
	var detail_rng := RandomNumberGenerator.new()
	detail_rng.seed = int(round(distance * 10.0)) + 0x7E4A
	var outward := Vector3(basis.x.x, 0, basis.x.z).normalized()
	var ahead := Vector3(-outward.z, 0, outward.x)
	var ground: float = (
		minf(world.position_at(distance, -6.3).y, world.position_at(distance, 6.3).y) - 0.9
	)
	var base: Vector3 = world.position_at(distance) + outward * 13.5
	base.y = ground
	var temple_basis := Basis.looking_at(-outward, Vector3.UP)
	world._prop("box", base + Vector3.UP * 0.4, Vector3(11.0, 0.8, 7.5), STONE_DARK, temple_basis)
	world._prop(
		"box", base + Vector3.UP * 0.95 - outward * 3.2, Vector3(9.0, 0.3, 1.4), STONE, temple_basis
	)
	for column in range(6):
		var x: float = -4.5 + float(column) * 1.8
		var height: float = 6.0 if column % 3 != 1 else rng.randf_range(2.5, 4.0)
		var at: Vector3 = base + ahead * x + Vector3.UP * (0.8 + height * 0.5)
		world._prop("cylinder", at, Vector3(0.55, height, 0.55), STONE)
		if height > 5.0 and column < 5:
			world._prop(
				"box",
				base + ahead * (x + 0.9) + Vector3.UP * (0.8 + height + 0.3),
				Vector3(2.3, 0.6, 0.9),
				STONE,
				Basis.looking_at(-outward, Vector3.UP)
			)
	world._prop("roof", base + Vector3.UP * 8.3, Vector3(6.0, 1.8, 2.0), STONE, temple_basis)
	world._prop(
		"star",
		base + Vector3.UP * 8.6 - outward * 1.05,
		Vector3.ONE * 0.9,
		GOLD,
		temple_basis,
		true
	)
	for side in [-1.0, 1.0]:
		var bowl: Vector3 = base + ahead * side * 6.2 - outward * 3.0
		world._prop("cylinder", bowl + Vector3.UP * 0.9, Vector3(0.45, 1.8, 0.45), STONE_DARK)
		world._prop(
			"ball",
			bowl + Vector3.UP * 2.05,
			Vector3(0.55, 0.45, 0.55),
			ORANGE,
			Basis.IDENTITY,
			true
		)
	for support in range(4):
		var side: float = -1.0 if support < 2 else 1.0
		var along: float = -7.5 if support % 2 == 0 else 7.5
		var at: Vector3 = base + ahead * along + outward * side * 3.5
		var height: float = 3.8 if support % 2 == 0 else 2.9
		world._prop(
			"cylinder",
			at + Vector3.UP * height * 0.5,
			Vector3(0.62, height, 0.62),
			STONE_DARK,
			temple_basis
		)
		world._prop(
			"box",
			at + Vector3.UP * height,
			Vector3(1.2, 0.32, 1.2),
			STONE,
			temple_basis
		)
	for vine in range(5):
		world._prop(
			"crown",
			base + ahead * rng.randf_range(-5, 5) + Vector3.UP * rng.randf_range(1, 6),
			Vector3(0.9, 0.6, 0.8),
			MOSS
		)
	for cluster in range(8):
		var side: float = -1.0 if cluster % 2 == 0 else 1.0
		var at: Vector3 = (
			base
			+ ahead * detail_rng.randf_range(-9.0, 9.0)
			+ outward * side * detail_rng.randf_range(3.0, 6.5)
		)
		var rubble_basis := temple_basis.rotated(Vector3.UP, detail_rng.randf_range(-0.3, 0.3))
		world._prop(
			"box",
			at + Vector3.UP * detail_rng.randf_range(0.35, 0.8),
			Vector3(
				detail_rng.randf_range(1.2, 2.4),
				detail_rng.randf_range(0.5, 1.2),
				detail_rng.randf_range(1.0, 2.0)
			),
			STONE_DARK if cluster % 3 == 0 else STONE,
			rubble_basis
		)
		if cluster % 2 == 0:
			world._prop(
				"crown",
				at + Vector3.UP * 0.8 + ahead * 0.65,
				Vector3(1.4, 0.6, 1.1),
				MOSS
			)
		if cluster % 4 == 1:
			world._prop(
				"rock",
				at - ahead * 0.8,
				Vector3(1.5, 1.2, 1.4),
				ROCK,
				Basis(Vector3.UP, detail_rng.randf() * TAU)
			)


static func _banner(world, at: Vector3, basis: Basis, text: String) -> void:
	var facing: Basis = basis.rotated(Vector3.UP, PI * 0.15)
	world._prop("cylinder", at + Vector3.UP * 3.5, Vector3(0.12, 7.0, 0.12), GOLD)
	world._prop(
		"box",
		at + Vector3.UP * 4.6 + facing.x * 0.9,
		Vector3(1.8, 4.2, 0.08),
		Color("2440a8"),
		facing
	)
	world._prop(
		"box",
		at + Vector3.UP * 4.6 + facing.x * 0.9 - facing.z * 0.02,
		Vector3(1.95, 4.35, 0.04),
		GOLD,
		facing,
		true
	)
	world._sign(at + Vector3.UP * 4.9 + facing.x * 0.9 + facing.z * 0.06, facing, text, 0.012)


## Choice setpiece between the ruins and Sternentor. The raised left lane is backed by
## split_route_height(), so this is not a PNG/visual fake: the kart and rivals actually climb it.
## It stays inside the existing rail envelope and rejoins before the next landmark.
static func _split_sky_bridge(world, _distance: float) -> void:
	var layout: Dictionary = split_route_layout(world.length)
	var start: float = float(layout.start)
	var finish: float = float(layout.end)
	var step: float = 1.2
	var count: int = ceili((finish - start) / step)
	for i in range(count):
		var d: float = start + (float(i) + 0.5) * (finish - start) / float(count)
		var height: float = split_route_height(world.length, d, SPLIT_LEFT_LANE)
		var pitch: float = split_route_pitch(world.length, d, SPLIT_LEFT_LANE)
		var basis: Basis = world.frame(d)
		var slope: Basis = basis.rotated(basis.x, pitch)
		var centre: Vector3 = world.position_at(d, SPLIT_LEFT_LANE) + basis.y * (height - 0.10)
		world._prop(
			"box",
			centre,
			Vector3(4.65, 0.20, (finish - start) / float(count) + 0.06),
			Color("243f9e"),
			slope
		)
		for edge in [-5.05, -0.55]:
			var edge_at: Vector3 = world.position_at(d, edge) + basis.y * (height + 0.045)
			world._prop(
				"box",
				edge_at,
				Vector3(0.13, 0.055, (finish - start) / float(count) * 0.88),
				CYAN if edge < -2.0 else CRYSTAL_VIOLET,
				slope,
				true
			)
		if i % 4 == 0 and height > 0.35:
			var support: Vector3 = world.position_at(d, SPLIT_LEFT_LANE)
			world._prop(
				"box",
				support + basis.y * (height * 0.5 - 0.14),
				Vector3(0.34, maxf(0.45, height), 0.34),
				STONE_DARK,
				basis
			)
		if i % 5 == 2 and height > 1.0:
			world._prop(
				"star",
				centre + basis.y * 1.0,
				Vector3.ONE * 0.34,
				GOLD,
				basis,
				true
			)
	var entry_d: float = start - 3.0
	var entry_basis: Basis = world.frame(entry_d)
	for lane_marker in [
		{"lane": -3.0, "text": "WOLKENWEG", "color": CYAN},
		{"lane": 3.0, "text": "HAUPTWEG", "color": ORANGE},
	]:
		var marker_at: Vector3 = world.position_at(entry_d, float(lane_marker.lane))
		var marker_color: Color = lane_marker["color"]
		world._prop(
			"box",
			marker_at + Vector3.UP * 1.5,
			Vector3(0.14, 3.0, 0.14),
			NAVY,
			entry_basis
		)
		world._prop(
			"box",
			marker_at + Vector3.UP * 2.75,
			Vector3(3.1, 1.05, 0.16),
			Color("173c8d"),
			entry_basis
		)
		world._prop(
			"box",
			marker_at + Vector3.UP * 2.75 + entry_basis.z * 0.09,
			Vector3(2.85, 0.82, 0.04),
			marker_color,
			entry_basis,
			true
		)
		world._sign(
			marker_at + Vector3.UP * 2.75 + entry_basis.z * 0.11,
			entry_basis,
			str(lane_marker.text),
			0.010
		)


## Final high-speed setpiece: a sequence of luminous sky arches after the ruins.
## The roadway stays continuous; this is a visual/reading landmark, not a fake collision tunnel.
static func _star_gate_run(world, distance: float) -> void:
	var span: float = 34.0
	var arches: int = 7
	for index in range(arches):
		var d: float = distance - span * 0.5 + float(index) * span / float(arches - 1)
		var basis: Basis = world.frame(d)
		var centre: Vector3 = world.position_at(d)
		var pulse: Color = CYAN if index % 2 == 0 else CRYSTAL_VIOLET
		for side in [-1.0, 1.0]:
			var foot: Vector3 = world.position_at(d, side * 6.45)
			world._prop("box", foot + basis.y * 2.6, Vector3(0.34, 5.2, 0.34), NAVY, basis)
			world._prop(
				"box",
				foot + basis.y * 5.1,
				Vector3(0.50, 0.20, 0.50),
				pulse,
				basis,
				true
			)
		world._prop(
			"box",
			centre + basis.y * 5.25,
			Vector3(13.2, 0.28, 0.34),
			pulse,
			basis,
			true
		)
		for star_side in [-1.0, 1.0]:
			world._prop(
				"star",
				centre + basis.y * 6.1 + basis.x * star_side * 3.4,
				Vector3.ONE * (0.50 if index % 2 == 0 else 0.38),
				GOLD,
				basis,
				true
			)
	# Aurora crown: rounded luminous ribs and cloud banks create the layered,
	# high-altitude depth requested by the gameplay references. Decorative only.
	var aurora_colors: Array[Color]=[CYAN,CRYSTAL_VIOLET,GOLD,CYAN]
	for arch_index in range(4):
		var arch_d: float=distance-12.0+float(arch_index)*8.0
		var arch_basis: Basis=world.frame(arch_d)
		var arch_centre: Vector3=world.position_at(arch_d)
		var arch_color: Color=aurora_colors[arch_index]
		for segment in range(18):
			var a: float=PI-float(segment)*PI/18.0
			var b: float=PI-float(segment+1)*PI/18.0
			var p: Vector3=(
				arch_centre
				+arch_basis.x*cos(a)*7.1
				+arch_basis.y*(1.25+sin(a)*6.0)
			)
			var q: Vector3=(
				arch_centre
				+arch_basis.x*cos(b)*7.1
				+arch_basis.y*(1.25+sin(b)*6.0)
			)
			world._beam(p,q,0.10,arch_color,true)
	# Puffy side clouds sit well beyond the guardrail and never affect driving.
	for cloud_index in range(12):
		var cloud_d: float=distance-24.0+float(cloud_index)*4.4
		var side: float=-1.0 if cloud_index%2==0 else 1.0
		var cloud_basis: Basis=world.frame(cloud_d)
		var cloud_at: Vector3=world.position_at(cloud_d,side*(12.5+float(cloud_index%3)*2.2))
		cloud_at+=cloud_basis.y*(1.4+float(cloud_index%2)*0.7)
		for puff in range(3):
			world._prop(
				"ball",
				cloud_at+cloud_basis.x*side*(float(puff)-1.0)*1.5+Vector3.UP*sin(float(puff))*0.45,
				Vector3(2.5+float(puff)*0.35,1.05+float(puff%2)*0.35,1.8+float(puff)*0.25),
				Color("cbd8ff") if cloud_index%3 else Color("eed8ff")
			)
	# A readable entry marker makes the section recognizable at speed.
	var entry_basis: Basis = world.frame(distance - span * 0.5 - 4.0)
	var entry_at: Vector3 = world.position_at(distance - span * 0.5 - 4.0, -7.4)
	world._prop("box", entry_at + Vector3.UP * 1.6, Vector3(0.16, 3.2, 0.16), NAVY, entry_basis)
	world._prop(
		"box",
		entry_at + Vector3.UP * 3.0,
		Vector3(3.6, 1.25, 0.18),
		Color("173c8d"),
		entry_basis
	)
	world._sign(
		entry_at + Vector3.UP * 3.0 + entry_basis.z * 0.1,
		entry_basis,
		"STERNENTOR\nVOLLGAS!",
		0.012
	)


static func _backdrop(world, rng: RandomNumberGenerator) -> void:
	for i in range(9):
		var angle: float = float(i) * TAU / 9.0 + rng.randf_range(-0.12, 0.12)
		var radius: float = rng.randf_range(185, 250)
		var centre := Vector3(cos(angle) * radius, rng.randf_range(4, 28), sin(angle) * radius)
		var size: float = rng.randf_range(16, 28)
		_round_island(world, centre, size, size * 1.6, rng)
		var outward := Vector3(cos(angle), 0, sin(angle))
		_waterfall(world, centre - outward * (size - 0.6) + Vector3.UP * 0.2, -outward, size * 0.3)
		if i % 2 == 0:
			for tower in range(3):
				var at: Vector3 = (
					centre
					+ Vector3(
						rng.randf_range(-size * 0.4, size * 0.4),
						0,
						rng.randf_range(-size * 0.4, size * 0.4)
					)
				)
				var height: float = rng.randf_range(8, 16)
				world._prop(
					"cylinder", at + Vector3.UP * height * 0.5, Vector3(2.2, height, 2.2), STONE
				)
				world._prop("cone", at + Vector3.UP * (height + 2.2), Vector3(2.5, 4.4, 2.5), ROOF)
				world._prop(
					"box",
					at + Vector3.UP * height * 0.7 - outward * 1.1,
					Vector3(0.6, 1.0, 0.05),
					WINDOW,
					Basis.looking_at(-outward, Vector3.UP),
					true
				)


static func _blimp(world) -> void:
	var at := Vector3(-28, 48, -40)
	var basis := Basis(Vector3.UP, 0.6)
	world._prop("ball", at, Vector3(9.0, 3.4, 3.4), Color("3b5fd6"), basis)
	world._prop(
		"ball",
		at + basis.x * 0.2 + Vector3.UP * 0.05,
		Vector3(8.2, 3.0, 3.5),
		Color("4f74e8"),
		basis
	)
	world._prop("box", at - Vector3.UP * 3.0, Vector3(3.0, 0.9, 1.2), NAVY, basis)
	for fin in [-1.0, 1.0]:
		world._prop(
			"box", at - basis.x * 8.0 + basis.z * fin * 1.6, Vector3(2.0, 0.15, 1.8), GOLD, basis
		)
	world._prop("box", at - basis.x * 8.2 + Vector3.UP * 1.6, Vector3(2.0, 2.0, 0.15), GOLD, basis)
	world._sign(at + basis.z * 3.45, basis.rotated(Vector3.UP, PI), "LUMO KART", 0.06)
	world._sign(at - basis.z * 3.45, basis, "LUMO KART", 0.06)


## The LUMO KART start and finish gate: blue pillars, gold stars, checkered band, start lights.
static func start_gate(world) -> void:
	var basis: Basis = world.frame(0.0)
	var at: Vector3 = world.position_at(0.0)
	for side in [-1.0, 1.0]:
		var pillar: Vector3 = at + basis.x * side * 7.1
		world._prop(
			"box", pillar + Vector3.UP * 3.9, Vector3(1.4, 7.8, 1.4), Color("1d3a9a"), basis
		)
		world._prop(
			"box",
			pillar + Vector3.UP * 3.9 + basis.z * 0.72,
			Vector3(0.18, 6.6, 0.05),
			CYAN,
			basis,
			true
		)
		world._prop(
			"star", pillar + Vector3.UP * 5.6 + basis.z * 0.78, Vector3.ONE * 0.7, GOLD, basis, true
		)
		world._prop(
			"star",
			pillar + Vector3.UP * 5.6 - basis.z * 0.78,
			Vector3.ONE * 0.7,
			GOLD,
			basis.rotated(Vector3.UP, PI),
			true
		)
		world._prop("box", pillar + Vector3.UP * 0.3, Vector3(1.9, 0.6, 1.9), NAVY, basis)
	world._prop("box", at + Vector3.UP * 8.4, Vector3(15.6, 2.2, 1.1), Color("1d3a9a"), basis)
	for column in range(24):
		for row in range(2):
			var color: Color = Color("f4f8ff") if (column + row) % 2 == 0 else Color("1b2a6b")
			world._prop(
				"box",
				at + basis.x * (-7.2 + column * 0.626) + Vector3.UP * (9.3 + row * 0.5),
				Vector3(0.626, 0.5, 1.15),
				color,
				basis
			)
	world._prop("box", at + Vector3.UP * 9.85, Vector3(15.8, 0.12, 1.2), GOLD, basis, true)
	world._sign(at + Vector3.UP * 8.35 + basis.z * 0.58, basis, "LUMO KART", 0.034)
	world._sign(
		at + Vector3.UP * 8.35 - basis.z * 0.58, basis.rotated(Vector3.UP, PI), "LUMO KART", 0.034
	)
	# Start lights hang from the gate and face the grid.
	var lights: Vector3 = at + Vector3.UP * 6.6 + basis.z * 0.3
	world._prop("box", lights, Vector3(3.6, 1.2, 0.5), NAVY, basis)
	var lamp_colors: Array[Color] = [Color("ff4d4d"), Color("ffd24a"), Color("52f07a")]
	for lamp in range(3):
		world._prop(
			"ball",
			lights + basis.x * (-1.15 + lamp * 1.15) + basis.z * 0.28,
			Vector3(0.42, 0.42, 0.12),
			lamp_colors[lamp],
			basis,
			true
		)
	world._sign(at + Vector3.UP * 5.55 + basis.z * 0.3, basis, "START · ZIEL", 0.012)


## Chevron boards on the outside of every tighter bend, facing the approaching driver.
static func chevrons(world) -> void:
	var length: float = world.length
	var d: float = 8.0
	while d < length - 8.0:
		var ahead: Vector3 = world.forward(d)
		var later: Vector3 = world.forward(d + 14.0)
		var bend: float = ahead.cross(later).y
		if absf(bend) > 0.22:
			# A right-hand bend has a negative bend value; its outside is the left (-1).
			var turn: float = 1.0 if bend < 0.0 else -1.0
			var outside: float = -turn
			var at: Vector3 = world.position_at(d + 10.0, outside * 7.3)
			var board_basis: Basis = world.frame(d + 10.0).rotated(Vector3.UP, outside * 0.35)
			world._prop("box", at + Vector3.UP * 1.35, Vector3(0.14, 2.7, 0.14), NAVY)
			world._prop(
				"box", at + Vector3.UP * 2.35, Vector3(3.1, 1.3, 0.16), Color("1c3aa6"), board_basis
			)
			world._prop(
				"box",
				at + Vector3.UP * 2.35 + board_basis.z * 0.02,
				Vector3(3.3, 1.5, 0.08),
				ORANGE,
				board_basis,
				true
			)
			for chevron in range(3):
				var x: float = (-0.85 + chevron * 0.85) * -turn
				for arm in [-1.0, 1.0]:
					var arm_basis: Basis = board_basis.rotated(board_basis.z, arm * 0.75 * -turn)
					world._prop(
						"box",
						(
							at
							+ Vector3.UP * (2.35 + arm * 0.22)
							+ board_basis.x * x
							+ board_basis.z * 0.1
						),
						Vector3(0.62, 0.16, 0.05),
						CYAN,
						arm_basis,
						true
					)
			d += 26.0
		else:
			d += 4.0


## Glowing crystal clusters at the cave mouths and along the vault (reference k07, section 5).
static func cave_crystals(world, distance: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	for i in range(18):
		var d: float = distance - 13.5 + float(i) * 1.6
		var basis: Basis = world.frame(d)
		for side in [-1.0, 1.0]:
			if rng.randf() < 0.35:
				continue
			var at: Vector3 = (
				world.position_at(d, side * rng.randf_range(7.4, 8.4))
				+ Vector3.UP * rng.randf_range(0.0, 3.5)
			)
			var tilt := Basis(basis.z, side * rng.randf_range(0.2, 0.6))
			var tint: Color = CRYSTAL_VIOLET if rng.randf() < 0.6 else CYAN
			world._prop(
				"crystal", at, Vector3(0.5, 0.9, 0.5) * rng.randf_range(0.8, 1.6), tint, tilt, true
			)
			if i % 3 == 0:
				for shard in range(2):
					var shard_tint: Color = CYAN if tint == CRYSTAL_VIOLET else CRYSTAL_VIOLET
					world._prop(
						"crystal",
						at + basis.x * side * (0.45 + float(shard) * 0.3) + Vector3.UP * (0.1 + shard * 0.2),
						Vector3(0.38, 0.78, 0.38) * (1.0 - float(shard) * 0.18),
						shard_tint,
						tilt.rotated(basis.z, -side * 0.24),
						true
					)
	for end in [-1.0, 1.0]:
		var d: float = distance + end * 13.5
		for side in [-1.0, 1.0]:
			var at: Vector3 = world.position_at(d, side * 8.2)
			for shard in range(3):
				var tilt := Basis(world.frame(d).z, side * (0.25 + shard * 0.2))
				world._prop(
					"crystal",
					at + Vector3.UP * shard * 0.6,
					Vector3(0.9, 1.8, 0.9) * (1.0 - shard * 0.2),
					[CRYSTAL_VIOLET, CYAN, CRYSTAL_VIOLET][shard],
					tilt,
					true
				)


## Glowing kerbs and continuous light edges in the reference palette (cyan and orange).
static func road_lights(world) -> void:
	var length: float = world.length
	for side in [-1.0, 1.0]:
		world._ribbon(
			"ContinuousCyanEdge", side * 5.83, side * 5.95, 0.045, world._material(CYAN, true)
		)
	var step: float = 1.4
	var count: int = ceili(length / step)
	for i in range(count):
		var d: float = (float(i) + 0.5) * step
		if in_gap(world.jump, d):
			continue
		var basis: Basis = world.frame(d)
		for side in [-1.0, 1.0]:
			var glow: Color = ORANGE if i % 4 < 2 else CYAN
			world._prop(
				"box",
				world.position_at(d, side * 5.5) + basis.y * 0.035,
				Vector3(0.36, 0.06, step * 0.82),
				glow,
				basis,
				true
			)


## Restrained, batched warning posts sit beyond the rails only on stronger turns.
static func road_surface_details(world) -> void:
	var count: int = ceili(world.length / 8.0)
	for i in range(count):
		var d: float = (float(i) + 0.5) * 8.0
		if in_gap(world.jump, d):
			continue
		var before: Vector3 = -world.frame(d - 3.0).z
		var after: Vector3 = -world.frame(d + 3.0).z
		var turn: float = before.cross(after).y
		if absf(turn) < 0.11:
			continue
		var side: float = 1.0 if turn > 0.0 else -1.0
		var basis: Basis = world.frame(d)
		var at: Vector3 = world.position_at(d, side * 7.15)
		world._prop(
			"box",
			at + basis.y * 1.55,
			Vector3(0.16, 3.1, 0.16),
			NAVY if i % 3 else STONE_DARK,
			basis
		)
		world._prop(
			"box",
			at + basis.y * 2.7,
			Vector3(1.05, 0.88, 0.12),
			Color("e8d58c") if i % 2 == 0 else Color("f1eee5"),
			basis
		)
		world._prop(
			"box",
			at + basis.y * 2.7 - basis.z * 0.075,
			Vector3(0.52, 0.075, 0.035),
			ORANGE if i % 2 == 0 else NAVY,
			basis,
			true
		)

	var lamp_count: int = ceili(world.length / (42.0 if world.low_detail else 32.0))
	for i in range(lamp_count):
		var d: float = (float(i) + 0.5) * world.length / lamp_count
		if in_gap(world.jump, d):
			continue
		var basis: Basis = world.frame(d)
		for side in [-1.0, 1.0]:
			var at: Vector3 = world.position_at(d, side * 7.8)
			var height: float = 3.3 if i % 3 == 0 else 2.8
			var tint: Color = CYAN if (i + int(side)) % 2 == 0 else GOLD
			world._prop(
				"cylinder",
				at + basis.y * height * 0.5,
				Vector3(0.11, height, 0.11),
				NAVY if i % 3 else STONE_DARK,
				basis
			)
			world._prop(
				"ball",
				at + basis.y * (height + 0.15),
				Vector3.ONE * (0.22 if i % 3 else 0.29),
				tint,
				Basis.IDENTITY,
				true
			)
