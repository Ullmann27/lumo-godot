extends RefCounted
## A connected offshore marina, authored entirely into the world's spatial GPU batches.
## Hull footprints are tested against the sea floor and the complete road curve.

const NAVY := Color("173650")
const WHITE := Color("edf6f5")
const CYAN := Color("70e5ed")
const GLASS := Color("579cba")
const WOOD := Color("b9926b")
const ROPE := Color("e2d9be")
const WATER_Y: float = -2.35
const DECK_Y: float = -1.65
const ROAD_CLEARANCE: float = 8.5
const HULL_SIZE := Vector3(1.15, 0.85, 1.23)


static func build(world) -> void:
	if world.track_id != "sonnenhafen":
		return
	var before: int = world.decoration_count
	var vessels: Array[Dictionary] = []
	# x=110 lies beyond the island's maximum east shoreline, even between terrain vertices.
	var quay := Vector3(110.0, DECK_Y, 2.0)
	_deck(world, quay, Vector2(2.6, 66.0))
	for i in range(17):
		var z: float = -30.0 + float(i) * 4.0
		_pylon(world, Vector3(109.05, DECK_Y, z))
		_pylon(world, Vector3(110.95, DECK_Y, z))
		_put(
			world,
			"cylinder",
			quay,
			Vector3(-1.10, 0.53, z - 2.0),
			Vector3(0.045, 1.05, 0.045),
			WHITE
		)
	for height in [0.56, 1.02]:
		_put(world, "box", quay, Vector3(-1.10, height, 0), Vector3(0.06, 0.06, 64), WHITE)
	_gangway(world, 34.0)
	for pier in range(4):
		var z: float = 29.0 - float(pier) * 18.0
		var finger := Vector3(117.0, DECK_Y, z)
		_deck(world, finger, Vector2(12.5, 1.65))
		for x in [112.0, 117.0, 122.0]:
			_pylon(world, Vector3(x, DECK_Y, z))
			_bollard(world, Vector3(x, DECK_Y, z - 0.60))
			_bollard(world, Vector3(x, DECK_Y, z + 0.60))
		_dock_light(world, Vector3(123.0, DECK_Y, z))
		var sides: Array = [-1.0] if world.low_detail else [-1.0, 1.0]
		for side in sides:
			var at := Vector3(117.0, WATER_Y + 0.18, z + side * 3.4)
			var basis := Basis(Vector3.UP, PI * 0.5)
			# A grid over the actual scaled hull envelope also checks its bow and stern.
			if not water_footprint(world, at, basis, Vector2(2.65, 6.90)):
				continue
			var sailing: bool = (pier + (1 if side > 0.0 else 0)) % 2 == 0
			_boat(world, at, basis, sailing, CYAN if pier % 2 == 0 else WHITE)
			vessels.append(
				{"transform": Transform3D(basis.scaled_local(HULL_SIZE), at), "sailing": sailing}
			)
			for end in [-1.0, 1.0]:
				var deck_at := Vector3(117.0 + end * 2.0, DECK_Y + 0.28, z + side * 0.60)
				var boat_at: Vector3 = at + basis * Vector3(-side * 1.0, 0.65, end * 1.65)
				world._beam(deck_at, boat_at, 0.035, ROPE)
	for i in range(8 if not world.low_detail else 4):
		var at := Vector3(
			130.0, WATER_Y, -33.0 + float(i) * (10.0 if not world.low_detail else 23.0)
		)
		if water_footprint(world, at, Basis.IDENTITY, Vector2(1.6, 1.6)):
			_buoy(world, at, i % 2 == 0)
	_lighthouse(world)
	_entry_sign(world, Vector3(110.0, DECK_Y, 34.0))
	world.set_meta("harbor_boats", vessels)
	world.set_meta("harbor_detail_count", world.decoration_count - before)
	world.set_meta("harbor_water_height", WATER_Y)


static func water_footprint(world, at: Vector3, basis: Basis, size: Vector2) -> bool:
	for row in range(5):
		for column in range(5):
			var local := Vector3(
				(float(column) / 4.0 - 0.5) * size.x, 0, (float(row) / 4.0 - 0.5) * size.y
			)
			var p: Vector3 = at + basis * local
			if world._ground_height(p.x, p.z) > WATER_Y - 0.65:
				return false
			if world._near_road(p, ROAD_CLEARANCE):
				return false
	return true


static func _deck(world, at: Vector3, size: Vector2) -> void:
	assert(water_footprint(world, at, Basis.IDENTITY, size))
	world._prop("box", at, Vector3(size.x, 0.24, size.y), WOOD)
	var long_x: bool = size.x > size.y
	var run: float = size.x if long_x else size.y
	var count: int = ceili(run / (1.45 if world.low_detail else 0.72))
	for i in range(count):
		var offset: float = (float(i) + 0.5) * run / float(count) - run * 0.5
		var p: Vector3 = at + Vector3(offset if long_x else 0.0, 0.125, 0.0 if long_x else offset)
		world._prop(
			"box",
			p,
			Vector3(0.025 if long_x else size.x - 0.05, 0.015, size.y - 0.05 if long_x else 0.025),
			NAVY
		)
	for side in [-1.0, 1.0]:
		var local := Vector3(
			0 if long_x else side * size.x * 0.5, -0.01, side * size.y * 0.5 if long_x else 0
		)
		_put(
			world,
			"box",
			at,
			local,
			Vector3(size.x if long_x else 0.10, 0.32, 0.10 if long_x else size.y),
			NAVY
		)


static func _pylon(world, at: Vector3) -> void:
	var bottom: float = world._ground_height(at.x, at.z) - 0.20
	var height: float = DECK_Y + 0.22 - bottom
	world._prop(
		"cylinder", Vector3(at.x, bottom + height * 0.5, at.z), Vector3(0.16, height, 0.16), NAVY
	)
	world._prop("cylinder", at + Vector3.UP * 0.18, Vector3(0.21, 0.16, 0.21), WHITE)


static func _bollard(world, at: Vector3) -> void:
	_put(world, "cylinder", at, Vector3(0, 0.36, 0), Vector3(0.12, 0.48, 0.12), WHITE)
	_put(world, "cylinder", at, Vector3(0, 0.60, 0), Vector3(0.18, 0.09, 0.18), NAVY)


static func _gangway(world, z: float) -> void:
	var shore_x: float = 106.0
	while shore_x > 84.0 and world._ground_height(shore_x, z) < -1.25:
		shore_x -= 0.25
	var start := Vector3(shore_x, world._ground_height(shore_x, z) + 0.20, z)
	var end := Vector3(109.1, DECK_Y + 0.12, z)
	var delta: Vector3 = end - start
	var basis: Basis = Basis.looking_at(delta.normalized(), Vector3.UP)
	for i in range(9):
		var p: Vector3 = start.lerp(end, float(i) / 8.0)
		if world._near_road(p, ROAD_CLEARANCE + 1.2):
			return
	world._prop("box", (start + end) * 0.5, Vector3(2.0, 0.20, delta.length()), WHITE, basis)
	for side in [-1.0, 1.0]:
		var a: Vector3 = start + basis.x * side * 0.9 + Vector3.UP * 1.05
		var b: Vector3 = end + basis.x * side * 0.9 + Vector3.UP * 1.05
		world._beam(a, b, 0.07, CYAN)
		for i in range(5):
			var p: Vector3 = start.lerp(end, float(i) / 4.0) + basis.x * side * 0.9
			world._prop("box", p + Vector3.UP * 0.53, Vector3(0.055, 1.06, 0.055), NAVY)
	world.set_meta("harbor_gangway", {"start": start, "end": end})


static func _boat(world, at: Vector3, basis: Basis, sailing: bool, accent: Color) -> void:
	_put(world, "hull", at, Vector3.ZERO, HULL_SIZE, NAVY, basis)
	_put(world, "hull", at, Vector3(0, 0.12, 0), Vector3(1.13, 0.58, 1.21), WHITE, basis)
	_put(world, "box", at, Vector3(0, 0.48, 0.50), Vector3(1.95, 0.09, 3.70), WOOD, basis)
	for side in [-1.0, 1.0]:
		var bow := Vector3(side * 0.67, 0.91, -1.47)
		var aft := Vector3(side * 1.06, 0.78, 1.75)
		world._beam(at + basis * bow, at + basis * aft, 0.045, WHITE)
		for local in [bow, aft]:
			_put(
				world,
				"cylinder",
				at,
				local - Vector3.UP * 0.19,
				Vector3(0.025, 0.40, 0.025),
				WHITE,
				basis
			)
		_put(
			world,
			"ball",
			at,
			Vector3(side * 1.22, 0.26, 0.9),
			Vector3(0.12, 0.32, 0.12),
			NAVY,
			basis
		)
	var ring_basis: Basis = basis * Basis(Vector3.RIGHT, PI * 0.5)
	world._prop("torus", at + basis * Vector3(0, 0.98, 2.12), Vector3.ONE * 0.52, CYAN, ring_basis)
	if sailing:
		_put(
			world, "cylinder", at, Vector3(0, 3.58, -0.68), Vector3(0.055, 6.1, 0.055), WHITE, basis
		)
		_put(world, "sail", at, Vector3(0, 0.91, -0.68), Vector3(1, 1.10, 0.96), WHITE, basis)
		_put(world, "sail", at, Vector3(0.025, 0.92, -0.73), Vector3(1, 0.88, -0.63), accent, basis)
		world._beam(
			at + basis * Vector3(0, 1.43, -0.70), at + basis * Vector3(0, 1.43, 2.0), 0.055, NAVY
		)
		for z in [-2.55, 2.0]:
			world._beam(
				at + basis * Vector3(0, 6.45, -0.68), at + basis * Vector3(0, 0.67, z), 0.025, ROPE
			)
		_put(world, "box", at, Vector3(0, 0.78, 0.8), Vector3(1.14, 0.56, 1.7), WHITE, basis)
		for side in [-1.0, 1.0]:
			_put(
				world,
				"box",
				at,
				Vector3(side * 0.58, 0.95, 0.7),
				Vector3(0.02, 0.20, 0.72),
				GLASS,
				basis
			)
	else:
		_put(world, "box", at, Vector3(0, 1.15, 0.62), Vector3(1.45, 1.13, 1.8), WHITE, basis)
		_put(world, "box", at, Vector3(0, 1.25, -0.31), Vector3(1.31, 0.55, 0.06), GLASS, basis)
		for side in [-1.0, 1.0]:
			_put(
				world,
				"box",
				at,
				Vector3(side * 0.74, 1.26, 0.52),
				Vector3(0.035, 0.47, 1.42),
				GLASS,
				basis
			)
		_put(world, "box", at, Vector3(0, 1.76, 0.57), Vector3(1.72, 0.15, 2.10), accent, basis)
		_put(world, "box", at, Vector3(0, 0.70, -1.62), Vector3(0.88, 0.14, 0.68), WHITE, basis)
		_put(
			world, "cylinder", at, Vector3(0, 2.07, 1.08), Vector3(0.025, 0.65, 0.025), NAVY, basis
		)
		_put(world, "sail", at, Vector3(0, 2.1, 1.08), Vector3(1, 0.09, 0.22), CYAN, basis)


static func _dock_light(world, at: Vector3) -> void:
	_put(world, "cylinder", at, Vector3(0, 0.81, 0), Vector3(0.075, 1.4, 0.075), NAVY)
	_put(
		world,
		"cylinder",
		at,
		Vector3(0, 1.41, 0),
		Vector3(0.15, 0.22, 0.15),
		CYAN,
		Basis.IDENTITY,
		true
	)
	_put(world, "cylinder", at, Vector3(0, 1.57, 0), Vector3(0.19, 0.08, 0.19), WHITE)


static func _buoy(world, at: Vector3, cyan: bool) -> void:
	_put(world, "cylinder", at, Vector3(0, 0.16, 0), Vector3(0.38, 0.48, 0.38), NAVY)
	_put(world, "cylinder", at, Vector3(0, 0.43, 0), Vector3(0.32, 0.18, 0.32), WHITE)
	_put(world, "cone", at, Vector3(0, 0.74, 0), Vector3(0.29, 0.47, 0.29), CYAN if cyan else WHITE)
	_put(world, "cylinder", at, Vector3(0, 1.19, 0), Vector3(0.023, 0.68, 0.023), NAVY)
	_put(world, "ball", at, Vector3(0, 1.54, 0), Vector3.ONE * 0.085, CYAN, Basis.IDENTITY, true)


static func _lighthouse(world) -> void:
	var at := Vector3(110.0, DECK_Y, -41.0)
	assert(water_footprint(world, at, Basis.IDENTITY, Vector2(9, 9)))
	_deck(world, Vector3(110.0, DECK_Y, -34.5), Vector2(2.6, 7))
	var floor_y: float = world._ground_height(at.x, at.z) - 0.3
	world._prop(
		"cylinder",
		Vector3(at.x, (floor_y + DECK_Y) * 0.5, at.z),
		Vector3(4.4, DECK_Y - floor_y, 4.4),
		NAVY
	)
	world._lighthouse(at)
	for i in range(8):
		var angle: float = (float(i) + 0.5) * TAU / 8.0
		var radial := Vector3(cos(angle), 0, sin(angle))
		var window_basis: Basis = Basis.looking_at(-radial, Vector3.UP)
		world._prop(
			"box",
			at + radial * 1.565 + Vector3.UP * 15.60,
			Vector3(1.02, 1.38, 0.035),
			CYAN,
			window_basis,
			true
		)
	for i in range(12):
		var angle: float = float(i) * TAU / 12.0
		var p: Vector3 = at + Vector3(cos(angle) * 2.1, 14.99, sin(angle) * 2.1)
		world._prop("cylinder", p, Vector3(0.035, 0.83, 0.035), WHITE)
	for height in [14.66, 15.34]:
		world._prop("torus", at + Vector3.UP * height, Vector3(4.30, 0.13, 4.30), CYAN)
	world.set_meta("harbor_lighthouse", at)


static func _entry_sign(world, at: Vector3) -> void:
	for side in [-1.0, 1.0]:
		_put(
			world, "cylinder", at, Vector3(side * 1.06, 2.26, 0), Vector3(0.055, 4.2, 0.055), WHITE
		)
		_put(world, "box", at, Vector3(side * 1.34, 3.02, 0), Vector3(0.46, 1.24, 0.045), NAVY)
		world._prop(
			"sail",
			at + Vector3(side * 1.34 - 0.03, 2.55, 0),
			Vector3(1, 0.15, 0.13),
			CYAN,
			Basis(Vector3.UP, PI * 0.5)
		)
	_put(world, "box", at, Vector3(0, 3.82, 0), Vector3(2.32, 0.50, 0.18), NAVY)
	_put(
		world,
		"box",
		at,
		Vector3(0, 4.09, 0),
		Vector3(2.40, 0.045, 0.22),
		CYAN,
		Basis.IDENTITY,
		true
	)
	# Geometric marina pictogram keeps the module legible without extra Label3D nodes.
	world._prop(
		"hull",
		at + Vector3(0, 3.56, 0.13),
		Vector3(0.20, 0.23, 0.20),
		WHITE,
		Basis(Vector3.RIGHT, PI * 0.5)
	)
	world._prop(
		"sail",
		at + Vector3(-0.04, 3.68, 0.12),
		Vector3(1, 0.055, 0.09),
		CYAN,
		Basis(Vector3.UP, PI * 0.5)
	)


static func _put(
	world,
	shape: String,
	at: Vector3,
	local: Vector3,
	size: Vector3,
	color: Color,
	basis: Basis = Basis.IDENTITY,
	glow: bool = false
) -> void:
	world._prop(shape, at + basis * local, size, color, basis, glow)
