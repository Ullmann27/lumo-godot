extends RefCounted
## Authored roadside assemblies, spatially batched by the world renderer.
## Every footprint clears all nearby lanes, including parallel course sections.
const NAVY := Color("18314d")
const WHITE := Color("dce9e8")
const CYAN := Color("66ddef")
const GOLD := Color("dfa45b")


static func build(world) -> void:
	var before: int = world.decoration_count
	var sites: Array[Dictionary] = []
	var count: int = 8 if world.low_detail else 20
	for i in range(count):
		var d: float = world.length * (float(i) + 0.7) / count
		if world.in_gap(d) or world.ramp_height(d) > 0.0:
			continue
		if world.track_id in ["sonnenhafen", "zauberwald", "bergwelt"] and world._is_bridge(d):
			continue
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var large: bool = i % 5 == 0
		var radius: float = 4.3 if large else 1.8
		var at: Vector3 = world.position_at(d, side * (17.0 if large else 12.0))
		if world._near_road(at, 8.5 + radius):
			continue
		at.y = world.position_at(d).y - 0.8
		if world.track_id in ["sonnenhafen", "zauberwald", "holo_city"]:
			at.y = world._ground_height(at.x, at.z)
			if at.y < -1.8:
				continue
		var basis := Basis(Vector3.UP, world.frame(d).get_euler().y)
		var accent: Color = _accent(world.track_id)
		sites.append({"position": at, "radius": radius, "distance": d})
		if large:
			_service_deck(world, at, basis, accent)
		elif i % 3 == 1:
			_marshals(world, at, basis, accent)
		else:
			_garden(world, at, basis, accent)
	world.set_meta("reference_detail_sites", sites)
	world.set_meta("reference_detail_count", world.decoration_count - before)


static func _accent(track: String) -> Color:
	match track:
		"candy_cloud":
			return Color("c99ade")
		"volcano_night":
			return Color("ed9156")
		"desert_drift":
			return Color("75cbbe")
		"zauberwald":
			return Color("91d8ac")
		_:
			return CYAN


static func _put(
	world,
	shape: String,
	at: Vector3,
	basis: Basis,
	local: Vector3,
	size: Vector3,
	color: Color,
	glow: bool = false
) -> void:
	world._prop(shape, at + basis * local, size, color, basis, glow)


static func _service_deck(world, at: Vector3, basis: Basis, accent: Color) -> void:
	_put(world, "box", at, basis, Vector3(0, 0.1, 0), Vector3(6.4, 0.2, 4.5), NAVY)
	for side in [-1.0, 1.0]:
		for z in [-1.8, 1.8]:
			_put(
				world,
				"box",
				at,
				basis,
				Vector3(side * 2.9, 1.9, z),
				Vector3(0.16, 3.8, 0.16),
				WHITE
			)
		_put(
			world, "box", at, basis, Vector3(side * 2.8, 0.85, 1.7), Vector3(0.25, 1.5, 0.65), NAVY
		)
	_put(world, "roof", at, basis, Vector3(0, 3.9, 0), Vector3(6.7, 0.6, 4.8), NAVY)
	_put(world, "box", at, basis, Vector3(0, 3.65, -2.35), Vector3(6.2, 0.09, 0.08), accent, true)
	for i in range(6):
		_put(
			world,
			"box",
			at,
			basis,
			Vector3(-2.35 + i * 0.93, 2.75, 1.85),
			Vector3(0.58, 0.75, 0.08),
			accent
		)
		_put(
			world,
			"box",
			at,
			basis,
			Vector3(-2.35 + i * 0.93, 2.75, 1.79),
			Vector3(0.43, 0.55, 0.02),
			NAVY
		)
	for i in range(3):
		_put(
			world,
			"box",
			at,
			basis,
			Vector3(-1.9 + i * 1.8, 0.8, 1.0),
			Vector3(1.35, 1.25, 0.75),
			WHITE
		)
		for row in range(4):
			_put(
				world,
				"box",
				at,
				basis,
				Vector3(-1.9 + i * 1.8, 0.38 + row * 0.25, 0.60),
				Vector3(1.13, 0.035, 0.035),
				NAVY
			)
		_put(
			world,
			"box",
			at,
			basis,
			Vector3(-1.9 + i * 1.8, 1.47, 0.98),
			Vector3(1.4, 0.08, 0.8),
			accent
		)
	for i in range(5):
		_person(
			world, at, basis, Vector3(-2.3 + i * 1.12, 0.22, -1.0), accent if i % 2 == 0 else GOLD
		)


static func _person(world, at: Vector3, basis: Basis, local: Vector3, color: Color) -> void:
	for side in [-1.0, 1.0]:
		_put(
			world,
			"cylinder",
			at,
			basis,
			local + Vector3(side * 0.11, 0.28, 0),
			Vector3(0.12, 0.56, 0.12),
			NAVY
		)
	_put(world, "ball", at, basis, local + Vector3(0, 0.83, 0), Vector3(0.25, 0.36, 0.19), color)
	_put(world, "ball", at, basis, local + Vector3(0, 1.27, 0), Vector3.ONE * 0.18, Color("d9a77d"))
	_put(world, "box", at, basis, local + Vector3(0, 1.42, 0), Vector3(0.39, 0.07, 0.37), NAVY)
	_put(
		world,
		"cylinder",
		at,
		basis,
		local + Vector3(-0.31, 0.94, 0),
		Vector3(0.09, 0.34, 0.09),
		color
	)


static func _marshals(world, at: Vector3, basis: Basis, accent: Color) -> void:
	_put(world, "box", at, basis, Vector3(0, 0.15, 0), Vector3(2.3, 0.3, 1.8), WHITE)
	_put(world, "box", at, basis, Vector3(0, 1.0, 0.55), Vector3(2.2, 1.5, 0.18), NAVY)
	_put(world, "box", at, basis, Vector3(0, 1.78, 0.55), Vector3(2.25, 0.08, 0.22), accent)
	_person(world, at, basis, Vector3(-0.42, 0.31, 0), accent)
	_person(world, at, basis, Vector3(0.48, 0.31, 0), GOLD)
	_put(world, "cylinder", at, basis, Vector3(1.05, 1.7, 0.1), Vector3(0.04, 3.4, 0.04), WHITE)
	_put(world, "box", at, basis, Vector3(1.5, 2.9, 0.1), Vector3(0.90, 0.6, 0.035), accent)
	_put(world, "box", at, basis, Vector3(1.12, 2.9, 0.077), Vector3(0.06, 0.44, 0.025), WHITE)
	_put(world, "box", at, basis, Vector3(1.28, 2.71, 0.077), Vector3(0.34, 0.06, 0.025), WHITE)


static func _garden(world, at: Vector3, basis: Basis, accent: Color) -> void:
	_put(world, "box", at, basis, Vector3(0, 0.2, 0), Vector3(2.3, 0.4, 1.3), NAVY)
	_put(world, "box", at, basis, Vector3(0, 0.41, 0), Vector3(2.15, 0.03, 1.15), Color("705538"))
	for i in range(9):
		var x: float = (i % 3 - 1) * 0.67
		var z: float = (i / 3 - 1) * 0.35
		_put(
			world,
			"crown",
			at,
			basis,
			Vector3(x, 0.71, z),
			Vector3(0.34, 0.31, 0.32),
			Color("55a878")
		)
		_put(
			world,
			"flower",
			at,
			basis,
			Vector3(x, 0.94, z),
			Vector3.ONE * 0.48,
			accent if i % 2 == 0 else GOLD
		)
	for side in [-1.0, 1.0]:
		_put(
			world,
			"cylinder",
			at,
			basis,
			Vector3(side * 1.2, 1.35, 0.6),
			Vector3(0.05, 2.7, 0.05),
			WHITE
		)
		_put(
			world,
			"box",
			at,
			basis,
			Vector3(side * 1.2, 2.75, 0.6),
			Vector3(0.25, 0.13, 0.25),
			accent,
			true
		)
