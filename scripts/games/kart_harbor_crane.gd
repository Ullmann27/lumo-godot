extends RefCounted
## Sonnenhafen container terminal: one original ship-to-shore gantry crane on a
## concrete pier, a moored feeder ship and container stacks. Authored geometry
## only (no external assets), built into the world's instanced GPU batches.
## The whole site stands in open water well away from the road: it never
## affects collision, lap timing, steering, checkpoints, AI or the race camera.
## Only the trolley travels slowly along the boom (one small node, high detail).
const HARBOR = preload("res://scripts/games/kart_harbor_dressing.gd")
const VISUAL_FINISH = preload("res://scripts/games/kart_harbor_visual_finish.gd")
# Authored candidates north of the marina; the first one that passes the
# water and road checks below is used. Each faces away from the island.
const SITES: Array[Vector3] = [Vector3(114, 0, 54), Vector3(108, 0, 54), Vector3(114, 0, 48)]
const ROAD_CLEARANCE: float = 14.0
const PORTAL_HEIGHT: float = 19.0
const BOOM_BACK: float = -14.0
const BOOM_TIP: float = 30.0
const LAND_LEGS: float = -4.0
const SEA_LEGS: float = 6.0
const LEG_SPREAD: float = 6.0
const BOOM_HALF: float = 2.6
const TROLLEY_FROM: float = 9.0
const TROLLEY_TO: float = 25.0

const NAVY := Color("16385a")
const STEEL := Color("9fbfcc")
const WHITE := Color("eef5f4")
const CONCRETE := Color("c8c1b2")
const RUBBER := Color("2b2f36")
const CYAN := Color("5ce9f5")
const SUN := Color("ffc84a")
const CORAL := Color("e8735a")
const WARNING := Color("ff5146")
const FLOOD := Color("fff1c6")
const HULL := Color("23324a")
const HULL_RED := Color("a8403a")
const GLASS := Color("3b86a8")
const CONTAINERS: Array[Color] = [
	Color("e8735a"), Color("2f7fb2"), Color("ffc84a"), Color("2c9c8a"), Color("eef5f4"), Color("8a5bb5")
]


static func build(world) -> void:
	if world.track_id != "sonnenhafen":
		return
	var before: int = world.decoration_count
	for site in SITES:
		var frame := _frame(site)
		if _clear(world, frame):
			_build_site(world, frame)
			world.set_meta("sonnenhafen_crane_site", frame.origin)
			world.set_meta("sonnenhafen_crane_frame", frame)
			break
	world.set_meta("sonnenhafen_crane_parts", world.decoration_count - before)


## Local frame: x = along the quay (crane travel), y = up, z = boom (outward).
static func _frame(site: Vector3) -> Transform3D:
	var outward := Vector3(site.x, 0, site.z).normalized()
	var along := Vector3.UP.cross(outward).normalized()
	var origin := Vector3(site.x, HARBOR.DECK_Y, site.z)
	return Transform3D(Basis(along, Vector3.UP, outward), origin)


static func _p(frame: Transform3D, f: float, y: float, s: float) -> Vector3:
	return frame.origin + frame.basis.z * f + Vector3.UP * y + frame.basis.x * s


static func _clear(world, frame: Transform3D) -> bool:
	# Pier, ship hull and the boom's footprint must all be open water, far from the road.
	for f in [-12.0, -6.0, 0.0, 8.0, 14.0, 20.0, BOOM_TIP]:
		for s in [-15.0, -7.5, 0.0, 7.5, 15.0]:
			var p: Vector3 = _p(frame, f, 0.0, s)
			if world._ground_height(p.x, p.z) > HARBOR.WATER_Y - 0.65:
				return false
			if world._near_road(p, ROAD_CLEARANCE):
				return false
	return true


static func _build_site(world, frame: Transform3D) -> void:
	var b: Basis = frame.basis
	var detail: bool = not world.low_detail
	_pier(world, frame, detail)
	var h: float = PORTAL_HEIGHT
	# Four legs on wheel bogies that ride the two crane rails.
	for f in [LAND_LEGS, SEA_LEGS]:
		for s in [-LEG_SPREAD, LEG_SPREAD]:
			world._prop("box", _p(frame, f, 0.85, s), Vector3(3.4, 1.1, 1.5), NAVY, b)
			if detail:
				for w in [-1.1, 0.0, 1.1]:
					# Wheels turn about the boom axis, so they roll along the rails.
					world._prop("cylinder", _p(frame, f, 0.45, s + w),
						Vector3(0.42, 0.34, 0.42), RUBBER, _axis_basis(b.z))
			world._beam(_p(frame, f, 1.3, s), _p(frame, f, h, s), 1.05, NAVY)
	for s in [-LEG_SPREAD, LEG_SPREAD]:
		# Side frames: sill beam, portal beam and cross bracing.
		world._beam(_p(frame, LAND_LEGS, 5.0, s), _p(frame, SEA_LEGS, 5.0, s), 0.7, NAVY)
		world._beam(_p(frame, LAND_LEGS - 0.6, h, s), _p(frame, SEA_LEGS + 0.6, h, s), 1.25, WHITE)
		world._beam(_p(frame, LAND_LEGS, 5.2, s), _p(frame, SEA_LEGS, h - 0.8, s), 0.38, STEEL)
		if detail:
			world._beam(_p(frame, SEA_LEGS, 5.2, s), _p(frame, LAND_LEGS, h - 0.8, s), 0.38, STEEL)
	for f in [LAND_LEGS, SEA_LEGS]:
		world._beam(_p(frame, f, h, -LEG_SPREAD - 0.6), _p(frame, f, h, LEG_SPREAD + 0.6), 1.25, WHITE)
	_boom(world, frame, detail)
	_apex(world, frame, detail)
	_machinery(world, frame, detail)
	_ship(world, frame, detail)
	_stacks(world, frame, detail)
	# Optional presentation-only geometry; leaves physics and hoist untouched.
	VISUAL_FINISH.decorate(world, frame, detail, CONTAINERS, HARBOR.WATER_Y - HARBOR.DECK_Y)
	if detail:
		_stairs(world, frame)
		_trolley_node(world, frame)
	else:
		# Reduced detail keeps the trolley silhouette as static geometry.
		_trolley_props(world, frame, (TROLLEY_FROM + TROLLEY_TO) * 0.5)


static func _axis_basis(axis: Vector3) -> Basis:
	# Basis whose local Y (the cylinder axis) points along the given direction.
	var y: Vector3 = axis.normalized()
	var x: Vector3 = Vector3.UP.cross(y).normalized()
	if x.length() < 0.5:
		x = Vector3.RIGHT
	return Basis(x, y, x.cross(y))


static func _pier(world, frame: Transform3D, detail: bool) -> void:
	var b: Basis = frame.basis
	# A solid concrete berth; its slab reaches below the waterline.
	world._prop("box", _p(frame, -2.0, -0.55, 0.0), Vector3(26.0, 1.2, 20.0), CONCRETE, b)
	world._prop("box", _p(frame, 7.75, 0.12, 0.0), Vector3(26.0, 0.18, 0.5), CONCRETE.darkened(0.18), b)
	# Short causeway onto the north end of the marina quay (authored at x=110, z<=35).
	world._prop("box", _p(frame, -10.0, -0.2, 14.4), Vector3(3.0, 0.5, 3.0), CONCRETE, b)
	# Crane rails along the quay with buffer stops.
	for f in [LAND_LEGS, SEA_LEGS]:
		world._prop("box", _p(frame, f, 0.1, 0.0), Vector3(25.0, 0.18, 0.35), STEEL, b)
		for end in [-12.4, 12.4]:
			world._prop("box", _p(frame, f, 0.45, end), Vector3(0.5, 0.7, 0.9), SUN, b)
	# Fender line and bollards on the berth edge.
	world._prop("box", _p(frame, 8.25, -0.35, 0.0), Vector3(25.0, 0.8, 0.5), RUBBER, b)
	for s in [-10.0, -3.5, 3.5, 10.0]:
		world._prop("cylinder", _p(frame, 7.3, 0.35, s), Vector3(0.28, 0.7, 0.28), NAVY)
		if detail:
			world._prop("ball", _p(frame, 7.3, 0.72, s), Vector3(0.34, 0.2, 0.34), NAVY)
	# Yellow safety lane markings under the portal.
	for s in [-8.6, 8.6]:
		world._prop("box", _p(frame, 1.0, 0.07, s), Vector3(0.25, 0.04, 9.0), SUN, b)


static func _boom(world, frame: Transform3D, detail: bool) -> void:
	var h: float = PORTAL_HEIGHT
	var bottom: float = h + 1.2
	var top: float = h + 3.4
	for s in [-BOOM_HALF, BOOM_HALF]:
		# Each side is a real truss: bottom chord (trolley rail), top chord, lacing.
		world._beam(_p(frame, BOOM_BACK, bottom, s), _p(frame, BOOM_TIP, bottom, s), 0.62, WHITE)
		world._beam(_p(frame, BOOM_BACK, top, s), _p(frame, BOOM_TIP - 1.5, top, s), 0.42, WHITE)
		var step: float = 3.0 if detail else 6.0
		var f: float = BOOM_BACK
		var even: bool = true
		while f < BOOM_TIP - 1.5:
			world._beam(_p(frame, f, bottom, s), _p(frame, f, top, s), 0.2, STEEL)
			var next: float = minf(f + step, BOOM_TIP - 1.5)
			if detail:
				var a: float = bottom if even else top
				var c: float = top if even else bottom
				world._beam(_p(frame, f, a, s), _p(frame, next, c, s), 0.16, STEEL)
			even = not even
			f = next
		world._beam(_p(frame, BOOM_TIP - 1.5, top, s), _p(frame, BOOM_TIP, bottom, s), 0.3, WHITE)
	var tie: float = BOOM_BACK
	while tie <= BOOM_TIP:
		world._beam(_p(frame, tie, bottom, -BOOM_HALF), _p(frame, tie, bottom, BOOM_HALF), 0.26, STEEL)
		if detail and tie < BOOM_TIP - 1.5:
			world._beam(_p(frame, tie, top, -BOOM_HALF), _p(frame, tie, top, BOOM_HALF), 0.2, STEEL)
		tie += 6.0 if detail else 11.0
	# Tip warning light and floodlights that light the berth below.
	world._prop("ball", _p(frame, BOOM_TIP + 0.2, bottom + 0.5, 0.0), Vector3(0.38, 0.38, 0.38), WARNING, Basis.IDENTITY, true)
	for f in [10.0, 18.0, 26.0]:
		world._prop("box", _p(frame, f, bottom - 0.55, 0.0), Vector3(1.4, 0.25, 0.5), FLOOD, frame.basis, true)


static func _apex(world, frame: Transform3D, detail: bool) -> void:
	var h: float = PORTAL_HEIGHT
	var peak: float = h + 15.0
	for s in [-BOOM_HALF, BOOM_HALF]:
		var crown: Vector3 = _p(frame, 2.0, peak, s)
		var side: float = signf(s) * 4.6
		var land_foot: Vector3 = _p(frame, LAND_LEGS - 1.0, h + 0.6, side)
		var sea_foot: Vector3 = _p(frame, SEA_LEGS + 0.5, h + 0.6, side)
		world._beam(land_foot, crown, 0.72, NAVY)
		world._beam(sea_foot, crown, 0.72, NAVY)
		# Mid-height tie exactly between the two inclined struts.
		var t: float = (7.0 - 0.6) / (15.0 - 0.6)
		world._beam(land_foot.lerp(crown, t), sea_foot.lerp(crown, t), 0.34, STEEL)
		# Forestays carry the outreach, backstays balance the machinery house.
		for f in [16.0, BOOM_TIP - 1.5]:
			world._beam(crown, _p(frame, f, h + 3.4, s), 0.17, STEEL)
		world._beam(crown, _p(frame, BOOM_BACK + 0.5, h + 3.4, s), 0.2, STEEL)
	world._beam(_p(frame, 2.0, peak, -BOOM_HALF - 0.4), _p(frame, 2.0, peak, BOOM_HALF + 0.4), 0.8, WHITE)
	world._prop("ball", _p(frame, 2.0, peak + 0.7, 0.0), Vector3(0.45, 0.45, 0.45), WARNING, Basis.IDENTITY, true)
	if detail:
		world._beam(_p(frame, 2.0, peak - 6.0, -BOOM_HALF), _p(frame, 2.0, peak - 6.0, BOOM_HALF), 0.3, STEEL)


static func _machinery(world, frame: Transform3D, detail: bool) -> void:
	var b: Basis = frame.basis
	var floor_y: float = PORTAL_HEIGHT + 3.6
	world._prop("box", _p(frame, -10.5, floor_y + 1.7, 0.0), Vector3(7.4, 3.4, 6.2), WHITE, b)
	world._prop("box", _p(frame, -10.5, floor_y + 3.55, 0.0), Vector3(7.9, 0.3, 6.6), NAVY, b)
	for s in [-3.73, 3.73]:
		# A cyan identity band on both long walls, readable from the road.
		world._prop("box", _p(frame, -10.5, floor_y + 2.2, s), Vector3(0.06, 0.42, 5.4), CYAN, b, true)
	if detail:
		for f in [-13.2, -11.4, -9.6, -7.8]:
			world._prop("box", _p(frame, f, floor_y + 4.0, 0.0), Vector3(0.9, 0.6, 0.9), STEEL, b)


static func _stairs(world, frame: Transform3D) -> void:
	# Zig-zag access stair beside the landward leg, with landings.
	var s: float = LEG_SPREAD + 1.6
	for flight in range(6):
		var y0: float = 1.0 + float(flight) * 3.0
		var from_f: float = LAND_LEGS - 1.4 if flight % 2 == 0 else LAND_LEGS + 1.4
		var to_f: float = LAND_LEGS + 1.4 if flight % 2 == 0 else LAND_LEGS - 1.4
		world._beam(_p(frame, from_f, y0, s), _p(frame, to_f, y0 + 3.0, s), 0.32, SUN)
		world._prop("box", _p(frame, to_f, y0 + 3.0, s), Vector3(1.2, 0.14, 1.1), STEEL, frame.basis)


static func _ship(world, frame: Transform3D, detail: bool) -> void:
	var b: Basis = frame.basis
	var f: float = 15.0
	var water: float = HARBOR.WATER_Y - HARBOR.DECK_Y
	world._prop("box", _p(frame, f, water + 0.4, 0.0), Vector3(24.4, 1.4, 6.4), HULL_RED, b)
	world._prop("box", _p(frame, f, water + 1.9, 0.0), Vector3(24.4, 1.6, 6.6), HULL, b)
	# Pointed bow: a flattened cone turned to face along the ship.
	world._prop("cone", _p(frame, f, water + 1.4, 13.6), Vector3(3.3, 2.8, 1.5), HULL, _axis_basis(b.x))
	world._prop("box", _p(frame, f, water + 2.75, 0.0), Vector3(24.6, 0.15, 6.8), WHITE, b)
	# Stern deckhouse with bridge windows and funnel.
	world._prop("box", _p(frame, f, water + 4.6, -9.2), Vector3(4.6, 3.6, 5.6), WHITE, b)
	world._prop("box", _p(frame, f, water + 5.6, -9.2), Vector3(4.65, 0.7, 5.65), GLASS, b)
	world._prop("box", _p(frame, f, water + 7.3, -10.2), Vector3(1.3, 2.2, 1.6), NAVY, b)
	world._prop("box", _p(frame, f, water + 7.6, -10.2), Vector3(1.32, 0.35, 1.62), CYAN, b, true)
	# Container bays on deck, two tiers forward of the bridge.
	var bay: int = 0
	for s in [-3.4, 2.75, 8.9]:
		for f_off in [-1.3, 1.3]:
			var tiers: int = 2 if detail or bay % 2 == 0 else 1
			for tier in range(tiers):
				var color: Color = CONTAINERS[(bay + tier * 2) % CONTAINERS.size()]
				_container(world, frame, _p(frame, f + f_off, water + 4.1 + float(tier) * 2.62, s), color, detail)
			bay += 1
	if detail:
		# Mooring lines from the bow and stern to the pier bollards.
		for pair in [[-10.0, -9.5], [10.0, 9.5]]:
			world._beam(_p(frame, 7.3, 0.7, pair[0]), _p(frame, f - 3.1, water + 2.6, pair[1]), 0.06, Color("e2d9be"))


static func _stacks(world, frame: Transform3D, detail: bool) -> void:
	var heights: Array[int] = [2, 1, 1, 1, 2, 1]
	if detail:
		heights = [3, 2, 1, 2, 3, 1]
	var index: int = 0
	for f in [-8.2, -10.75]:
		for s in [-7.0, 0.0, 7.0]:
			for tier in range(heights[index]):
				var color: Color = CONTAINERS[(index * 2 + tier) % CONTAINERS.size()]
				_container(world, frame, _p(frame, f, 1.3 + float(tier) * 2.62, s), color, detail)
			index += 1


static func _container(world, frame: Transform3D, at: Vector3, color: Color, detail: bool) -> void:
	# ISO-style box with darker door frames at both ends.
	world._prop("box", at, Vector3(6.05, 2.55, 2.45), color, frame.basis)
	if detail:
		for end in [-3.05, 3.05]:
			world._prop("box", at + frame.basis.x * end, Vector3(0.1, 2.6, 2.5), color.darkened(0.35), frame.basis)


static func _trolley_props(world, frame: Transform3D, f: float) -> void:
	var b: Basis = frame.basis
	var rail: float = PORTAL_HEIGHT + 1.2
	world._prop("box", _p(frame, f, rail + 0.75, 0.0), Vector3(6.4, 0.9, 3.2), NAVY, b)
	world._prop("box", _p(frame, f, rail - 1.4, -1.9), Vector3(2.2, 1.8, 2.2), GLASS, b)
	world._prop("box", _p(frame, f, 9.0, 0.0), Vector3(6.4, 0.5, 2.6), SUN, b)


static func _trolley_node(world, frame: Transform3D) -> void:
	# Two independent movements: trolley travel and a vertically lowering load.
	# Four ropes stay attached to the trolley rail as their length changes.
	var rail: float = PORTAL_HEIGHT + 1.2
	var trolley := Node3D.new()
	trolley.name = "SonnenhafenCraneTrolley"
	trolley.transform = Transform3D(frame.basis, _p(frame, TROLLEY_FROM, 0.0, 0.0))
	world.add_child(trolley)
	_part(trolley, Vector3(0, rail + 0.75, 0), Vector3(6.4, 0.9, 3.2), NAVY, false)
	_part(trolley, Vector3(-1.9, rail - 1.4, 0), Vector3(2.2, 1.8, 2.2), WHITE, false)
	_part(trolley, Vector3(-1.9, rail - 1.25, 1.12), Vector3(2.0, 0.8, 0.05), GLASS, false)
	var spreader_y: float = 10.5
	var top_y: float = rail + 0.3
	var cables: Array[MeshInstance3D] = []
	for x in [-2.6, 2.6]:
		for z in [-0.9, 0.9]:
			var rope: MeshInstance3D = _part(
				trolley, Vector3(x, (top_y + spreader_y) * 0.5, z),
				Vector3(0.07, top_y - spreader_y, 0.07), STEEL, false
			)
			rope.name = "SonnenhafenCraneCable%d" % cables.size()
			cables.append(rope)
	var hoist := Node3D.new()
	hoist.name = "SonnenhafenCraneHoist"
	trolley.add_child(hoist)
	_part(hoist, Vector3(0, spreader_y, 0), Vector3(6.4, 0.5, 2.6), SUN, false)
	_part(hoist, Vector3(0, spreader_y - 1.55, 0), Vector3(6.05, 2.55, 2.45), CORAL, false)
	_part(trolley, Vector3(0, rail - 0.2, 0), Vector3(0.6, 0.25, 0.6), FLOOD, true)
	world.set_meta("sonnenhafen_crane_trolley", trolley.name)
	world.set_meta("sonnenhafen_crane_hoist", hoist.name)
	var start: Vector3 = trolley.position
	var end: Vector3 = _p(frame, TROLLEY_TO, 0.0, 0.0)
	var tween: Tween = trolley.create_tween().set_loops()
	tween.tween_property(trolley, "position", end, 9.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_interval(2.5)
	tween.tween_property(trolley, "position", start, 9.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_interval(2.5)

	# One shared parameter animates the load and four tensioned ropes.
	# No rigid bodies, lights or per-frame mesh allocations are introduced.
	var move_hoist: Callable = func(offset: float) -> void:
		hoist.position.y = offset
		for cable in cables:
			cable.position.y = (top_y + spreader_y + offset) * 0.5
			cable.scale.y = (top_y - spreader_y - offset) / (top_y - spreader_y)
	var lift: Tween = trolley.create_tween().set_loops()
	lift.tween_method(move_hoist, 0.0, -2.4, 3.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	lift.tween_interval(1.0)
	lift.tween_method(move_hoist, -2.4, 0.0, 3.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	lift.tween_interval(2.0)


static func _part(parent: Node3D, at: Vector3, size: Vector3, color: Color, glow: bool) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.5
	material.metallic = 0.25
	if glow:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.6
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	part.position = at
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(part)
	return part
