extends RefCounted
## Bounded, static roadside assemblies for the three nature destinations.

const GEO = preload("res://scripts/games/track_themes/track_theme_geometry.gd")
const BARK = Color("#553725")
const WOOD = Color("#956444")
const BRASS = Color("#cba75c")
const PAPER = Color("#efdbae")
const FOREST = Color("#245e49")
const LEAF = Color("#438b59")
const MINT = Color("#7ad7c5")
const SANDSTONE = Color("#cbab70")
const STONE_LIGHT = Color("#e5c88e")
const STONE_DARK = Color("#806945")
const JADE = Color("#298e83")
const MOSS = Color("#507742")
const ORCHID = Color("#ac5f91")
const DESERT_STONE = Color("#d9a65d")
const DESERT_LIGHT = Color("#edc681")
const COBALT = Color("#245a9b")
const WATER = Color("#39b8ba")
const CLOTH = Color("#9b4246")
const PALM = Color("#789847")


static func build(world, at: Vector3, basis: Basis, large: bool, marker: bool) -> bool:
	match String(world.track_id):
		"zauberwald":
			if large:
				_tree_library(world, at, basis)
			elif marker:
				_seed_lantern(world, at, basis)
			else:
				_mushroom_garden(world, at, basis)
		"jungle_temple":
			if large:
				_knowledge_ruin(world, at, basis)
			elif marker:
				_temple_beacon(world, at, basis)
			else:
				_overgrown_lintel(world, at, basis)
		"desert_drift":
			if large:
				_oasis_pavilion(world, at, basis)
			elif marker:
				_sun_banner(world, at, basis)
			else:
				_palm_pool(world, at, basis)
		_:
			return false
	return true


static func _book(world, at: Vector3, basis: Basis, center: Vector3, scale: float) -> void:
	for side in [-1.0, 1.0]:
		var tilt := Quaternion(Vector3.FORWARD, side * 0.13)
		var offset := Vector3(side * 0.235, 0.015, 0.0) * scale
		GEO.put(
			world,
			"box",
			at,
			basis,
			center + offset,
			Vector3(0.47, 0.58, 0.10) * scale,
			BRASS,
			false,
			tilt
		)
		GEO.put(
			world,
			"box",
			at,
			basis,
			center + offset + Vector3(0.0, 0.015, -0.066) * scale,
			Vector3(0.39, 0.48, 0.035) * scale,
			PAPER,
			false,
			tilt
		)
	GEO.put(world, "cylinder", at, basis, center, Vector3(0.036, 0.55, 0.036) * scale, BRASS)


static func _leaf(
	world, at: Vector3, basis: Basis, start: Vector3, tip: Vector3, width: float, color: Color
) -> void:
	var delta := tip - start
	var span := delta.length()
	if span <= 0.0001:
		return
	GEO.put(
		world,
		"cone",
		at,
		basis,
		(start + tip) * 0.5,
		Vector3(width, span, width * 0.32),
		color,
		false,
		Quaternion(Vector3.UP, delta / span)
	)


static func _mushroom(
	world, at: Vector3, basis: Basis, root: Vector3, height: float, radius: float, luminous: bool
) -> void:
	GEO.put(
		world,
		"cylinder",
		at,
		basis,
		root + Vector3(0.0, height * 0.5, 0.0),
		Vector3(radius * 0.22, height, radius * 0.22),
		PAPER
	)
	GEO.put(
		world,
		"ball",
		at,
		basis,
		root + Vector3(0.0, height, 0.0),
		Vector3(radius, radius * 0.43, radius),
		MINT,
		luminous
	)
	GEO.put(
		world,
		"cylinder",
		at,
		basis,
		root + Vector3(0.0, height - radius * 0.13, 0.0),
		Vector3(radius * 0.76, 0.025, radius * 0.76),
		FOREST
	)


static func _tree_library(world, at: Vector3, basis: Basis) -> void:
	GEO.put(world, "box", at, basis, Vector3(0.0, 0.16, 0.0), Vector3(3.8, 0.32, 2.8), BARK)
	GEO.put(world, "box", at, basis, Vector3(-0.35, 0.28, -1.46), Vector3(2.6, 0.16, 0.38), WOOD)
	GEO.put(world, "cylinder", at, basis, Vector3(1.05, 1.97, 0.60), Vector3(0.45, 3.3, 0.42), BARK)
	GEO.beam(world, at, basis, Vector3(1.05, 2.50, 0.60), Vector3(-0.10, 3.58, 0.55), 0.15, BARK)
	GEO.beam(world, at, basis, Vector3(1.05, 2.95, 0.60), Vector3(1.75, 3.90, 0.48), 0.13, BARK)
	GEO.beam(world, at, basis, Vector3(1.05, 0.70, 0.60), Vector3(1.84, 0.36, -0.24), 0.16, BARK)
	GEO.put(
		world, "crown", at, basis, Vector3(-0.05, 3.89, 0.58), Vector3(0.95, 0.58, 0.75), FOREST
	)
	GEO.put(world, "crown", at, basis, Vector3(1.40, 4.05, 0.55), Vector3(0.83, 0.64, 0.68), LEAF)
	GEO.put(world, "box", at, basis, Vector3(-0.45, 1.50, 0.80), Vector3(2.45, 2.05, 0.22), BARK)
	GEO.put(world, "box", at, basis, Vector3(-0.45, 0.58, 0.40), Vector3(2.55, 0.34, 0.72), WOOD)
	for x in [-1.70, 0.80]:
		GEO.put(
			world, "cylinder", at, basis, Vector3(x, 1.57, 0.12), Vector3(0.10, 2.35, 0.10), WOOD
		)
		GEO.put(
			world, "cylinder", at, basis, Vector3(x, 2.64, 0.12), Vector3(0.14, 0.09, 0.14), BRASS
		)
	for y in [0.83, 1.48, 2.12]:
		GEO.put(world, "box", at, basis, Vector3(-0.45, y, 0.36), Vector3(2.55, 0.09, 0.68), WOOD)
	GEO.put(world, "roof", at, basis, Vector3(-0.45, 2.86, 0.32), Vector3(2.95, 0.76, 1.42), BARK)
	GEO.put(world, "box", at, basis, Vector3(-0.45, 2.48, -0.40), Vector3(3.0, 0.09, 0.08), BRASS)
	_book(world, at, basis, Vector3(-0.45, 3.02, -0.44), 0.85)
	var book_colors := [JADE, COBALT, CLOTH, BRASS, FOREST]
	for i in range(5):
		GEO.put(
			world,
			"box",
			at,
			basis,
			Vector3(-1.37 + float(i) * 0.43, 1.12, 0.35),
			Vector3(0.28, 0.48, 0.36),
			book_colors[i]
		)
	for x in [-1.43, 0.48]:
		GEO.beam(world, at, basis, Vector3(x, 2.48, -0.31), Vector3(x, 2.20, -0.55), 0.026, BRASS)
		GEO.put(
			world,
			"cylinder",
			at,
			basis,
			Vector3(x, 2.03, -0.55),
			Vector3(0.12, 0.27, 0.12),
			PAPER,
			true
		)
		GEO.put(world, "cone", at, basis, Vector3(x, 2.22, -0.55), Vector3(0.18, 0.14, 0.18), BRASS)
	_mushroom(world, at, basis, Vector3(1.33, 0.32, -0.70), 0.38, 0.25, false)
	if not world.low_detail:
		for i in range(5):
			GEO.put(
				world,
				"box",
				at,
				basis,
				Vector3(-1.37 + float(i) * 0.43, 1.77, 0.36),
				Vector3(0.25, 0.48, 0.32),
				book_colors[4 - i]
			)
		GEO.put(
			world, "crown", at, basis, Vector3(0.56, 4.40, 0.55), Vector3(0.75, 0.39, 0.58), FOREST
		)
		GEO.put(
			world, "box", at, basis, Vector3(-0.45, 0.59, 0.025), Vector3(1.84, 0.12, 0.025), BRASS
		)
		GEO.put(
			world, "rock", at, basis, Vector3(1.55, 0.42, 0.84), Vector3(0.24, 0.16, 0.27), MOSS
		)


static func _seed_lantern(world, at: Vector3, basis: Basis) -> void:
	GEO.put(world, "rock", at, basis, Vector3(0.0, 0.18, 0.0), Vector3(0.50, 0.27, 0.46), BARK)
	GEO.put(
		world, "cylinder", at, basis, Vector3(0.0, 1.05, 0.0), Vector3(0.105, 1.75, 0.105), WOOD
	)
	GEO.beam(world, at, basis, Vector3(0.0, 1.80, 0.0), Vector3(0.42, 2.14, 0.0), 0.065, BARK)
	GEO.beam(world, at, basis, Vector3(0.42, 2.14, 0.0), Vector3(0.42, 1.98, 0.0), 0.025, BRASS)
	GEO.put(
		world, "ball", at, basis, Vector3(0.42, 1.77, 0.0), Vector3(0.17, 0.23, 0.17), PAPER, true
	)
	GEO.put(world, "cone", at, basis, Vector3(0.42, 2.02, 0.0), Vector3(0.23, 0.16, 0.23), BRASS)
	GEO.put(
		world, "cylinder", at, basis, Vector3(0.42, 1.53, 0.0), Vector3(0.18, 0.07, 0.18), BRASS
	)
	GEO.put(
		world,
		"box",
		at,
		basis,
		Vector3(-0.22, 1.26, 0.0),
		Vector3(0.39, 0.45, 0.055),
		FOREST,
		false,
		Quaternion(Vector3.FORWARD, -0.13)
	)
	_mushroom(world, at, basis, Vector3(-0.40, 0.16, 0.17), 0.25, 0.22, false)
	if not world.low_detail:
		for x in [0.30, 0.54]:
			GEO.beam(
				world, at, basis, Vector3(x, 1.57, -0.10), Vector3(x, 1.94, -0.10), 0.018, BRASS
			)
		_leaf(world, at, basis, Vector3(-0.14, 0.26, 0.24), Vector3(-0.62, 0.67, 0.43), 0.11, LEAF)


static func _mushroom_garden(world, at: Vector3, basis: Basis) -> void:
	GEO.put(world, "rock", at, basis, Vector3(0.0, 0.10, 0.0), Vector3(0.65, 0.17, 0.54), MOSS)
	_mushroom(world, at, basis, Vector3(-0.44, 0.17, -0.14), 0.37, 0.26, false)
	_mushroom(world, at, basis, Vector3(0.10, 0.17, 0.22), 0.66, 0.34, true)
	_mushroom(world, at, basis, Vector3(0.45, 0.15, -0.24), 0.30, 0.24, false)
	_leaf(world, at, basis, Vector3(-0.31, 0.18, 0.35), Vector3(-0.87, 0.61, 0.40), 0.11, FOREST)
	_leaf(world, at, basis, Vector3(-0.31, 0.18, 0.35), Vector3(-0.40, 0.86, 0.72), 0.12, LEAF)
	_leaf(world, at, basis, Vector3(-0.31, 0.18, 0.35), Vector3(0.04, 0.57, 0.73), 0.10, FOREST)
	if not world.low_detail:
		GEO.put(
			world, "crystal", at, basis, Vector3(0.48, 0.12, 0.41), Vector3(0.13, 0.30, 0.13), JADE
		)
		GEO.put(
			world, "rock", at, basis, Vector3(-0.55, 0.08, -0.40), Vector3(0.20, 0.13, 0.15), BARK
		)


static func _knowledge_ruin(world, at: Vector3, basis: Basis) -> void:
	GEO.put(world, "box", at, basis, Vector3(0.0, 0.14, 0.0), Vector3(3.9, 0.28, 3.0), STONE_DARK)
	GEO.put(world, "box", at, basis, Vector3(0.0, 0.42, 0.0), Vector3(3.3, 0.28, 2.6), SANDSTONE)
	GEO.put(
		world, "box", at, basis, Vector3(0.0, 0.68, 0.0), Vector3(2.75, 0.24, 2.15), STONE_LIGHT
	)
	GEO.put(
		world, "box", at, basis, Vector3(0.0, 0.34, -1.49), Vector3(2.05, 0.14, 0.40), SANDSTONE
	)
	GEO.put(
		world, "box", at, basis, Vector3(0.0, 0.53, -1.27), Vector3(1.65, 0.14, 0.34), STONE_LIGHT
	)
	GEO.put(world, "box", at, basis, Vector3(0.0, 1.60, 0.62), Vector3(2.25, 1.60, 0.34), SANDSTONE)
	GEO.put(
		world, "box", at, basis, Vector3(0.0, 1.42, 0.43), Vector3(0.82, 1.24, 0.06), STONE_DARK
	)
	for x in [-0.89, 0.89]:
		GEO.put(
			world, "box", at, basis, Vector3(x, 1.57, -0.22), Vector3(0.36, 1.54, 0.46), SANDSTONE
		)
		GEO.put(
			world, "box", at, basis, Vector3(x, 2.39, -0.22), Vector3(0.59, 0.18, 0.65), STONE_LIGHT
		)
		GEO.put(world, "box", at, basis, Vector3(x, 1.58, -0.47), Vector3(0.19, 0.91, 0.04), JADE)
	GEO.put(
		world, "box", at, basis, Vector3(0.0, 2.62, -0.22), Vector3(2.35, 0.28, 0.64), STONE_LIGHT
	)
	GEO.put(world, "box", at, basis, Vector3(0.0, 2.91, 0.19), Vector3(2.94, 0.22, 1.65), SANDSTONE)
	GEO.put(world, "box", at, basis, Vector3(0.0, 2.64, -0.56), Vector3(1.82, 0.07, 0.035), JADE)
	_book(world, at, basis, Vector3(0.0, 3.30, -0.24), 1.15)
	GEO.put(
		world, "box", at, basis, Vector3(1.43, 1.16, 0.82), Vector3(0.43, 1.20, 0.43), STONE_DARK
	)
	GEO.put(
		world,
		"box",
		at,
		basis,
		Vector3(1.43, 1.84, 0.82),
		Vector3(0.58, 0.16, 0.57),
		SANDSTONE,
		false,
		Quaternion(Vector3.UP, 0.13)
	)
	GEO.beam(world, at, basis, Vector3(1.20, 3.02, 0.48), Vector3(1.29, 2.47, 0.20), 0.055, MOSS)
	GEO.beam(world, at, basis, Vector3(1.29, 2.47, 0.20), Vector3(1.18, 1.89, 0.16), 0.045, MOSS)
	_leaf(world, at, basis, Vector3(1.26, 2.64, 0.24), Vector3(1.63, 2.86, 0.11), 0.15, MOSS)
	_leaf(world, at, basis, Vector3(1.23, 2.21, 0.18), Vector3(0.95, 2.38, -0.02), 0.13, LEAF)
	GEO.put(world, "crown", at, basis, Vector3(-1.52, 0.46, 0.72), Vector3(0.32, 0.15, 0.37), MOSS)
	GEO.put(world, "crown", at, basis, Vector3(1.36, 0.39, -0.75), Vector3(0.27, 0.15, 0.33), MOSS)
	if not world.low_detail:
		for x in [-0.58, 0.0, 0.58]:
			GEO.put(
				world, "box", at, basis, Vector3(x, 0.44, -1.32), Vector3(0.38, 0.10, 0.035), JADE
			)
		for x in [-0.52, 0.52]:
			GEO.put(
				world,
				"box",
				at,
				basis,
				Vector3(x, 1.69, 0.425),
				Vector3(0.045, 1.12, 0.04),
				STONE_LIGHT
			)
		_leaf(world, at, basis, Vector3(-1.48, 0.45, 0.73), Vector3(-1.97, 1.06, 0.64), 0.18, LEAF)
		_leaf(
			world, at, basis, Vector3(-1.48, 0.45, 0.73), Vector3(-1.34, 1.24, 1.12), 0.16, FOREST
		)
		GEO.put(
			world, "ball", at, basis, Vector3(-1.65, 0.80, 0.58), Vector3(0.12, 0.09, 0.12), ORCHID
		)


static func _temple_beacon(world, at: Vector3, basis: Basis) -> void:
	GEO.put(world, "box", at, basis, Vector3(0.0, 0.10, 0.0), Vector3(0.91, 0.20, 0.84), STONE_DARK)
	GEO.put(world, "box", at, basis, Vector3(0.0, 0.88, 0.0), Vector3(0.50, 1.36, 0.50), SANDSTONE)
	GEO.put(
		world, "box", at, basis, Vector3(0.0, 1.64, 0.0), Vector3(0.82, 0.16, 0.76), STONE_LIGHT
	)
	GEO.put(world, "box", at, basis, Vector3(0.0, 1.78, 0.0), Vector3(0.64, 0.12, 0.60), SANDSTONE)
	GEO.put(
		world, "crystal", at, basis, Vector3(0.0, 1.84, 0.0), Vector3(0.18, 0.28, 0.18), PAPER, true
	)
	GEO.put(world, "box", at, basis, Vector3(0.0, 0.97, -0.27), Vector3(0.30, 0.76, 0.035), JADE)
	_book(world, at, basis, Vector3(0.0, 1.04, -0.32), 0.36)
	GEO.put(world, "crown", at, basis, Vector3(0.26, 0.24, 0.16), Vector3(0.23, 0.11, 0.24), MOSS)
	_leaf(world, at, basis, Vector3(-0.21, 0.15, 0.18), Vector3(-0.65, 0.68, 0.33), 0.12, LEAF)
	if not world.low_detail:
		GEO.put(
			world,
			"box",
			at,
			basis,
			Vector3(0.0, 0.42, -0.26),
			Vector3(0.39, 0.05, 0.025),
			STONE_DARK
		)
		_leaf(world, at, basis, Vector3(-0.21, 0.15, 0.18), Vector3(-0.29, 0.77, 0.57), 0.11, MOSS)


static func _overgrown_lintel(world, at: Vector3, basis: Basis) -> void:
	var fallen := Quaternion(Vector3.UP, 0.18)
	GEO.put(
		world,
		"box",
		at,
		basis,
		Vector3(0.0, 0.28, 0.0),
		Vector3(1.24, 0.30, 0.49),
		SANDSTONE,
		false,
		fallen
	)
	GEO.put(
		world,
		"box",
		at,
		basis,
		Vector3(-0.38, 0.36, 0.16),
		Vector3(0.40, 0.68, 0.39),
		STONE_DARK,
		false,
		Quaternion(Vector3.FORWARD, 0.16)
	)
	GEO.put(world, "crown", at, basis, Vector3(0.05, 0.46, 0.06), Vector3(0.51, 0.13, 0.28), MOSS)
	GEO.put(
		world,
		"box",
		at,
		basis,
		Vector3(0.0, 0.36, -0.27),
		Vector3(1.02, 0.05, 0.035),
		JADE,
		false,
		fallen
	)
	GEO.put(
		world, "rock", at, basis, Vector3(0.45, 0.14, 0.41), Vector3(0.24, 0.19, 0.22), STONE_LIGHT
	)
	for tip in [
		Vector3(0.83, 0.64, 0.39),
		Vector3(0.48, 0.86, 0.75),
		Vector3(-0.03, 0.71, 0.77),
		Vector3(-0.22, 0.48, 0.46)
	]:
		_leaf(world, at, basis, Vector3(0.24, 0.18, 0.35), tip, 0.13, LEAF)
	GEO.beam(
		world, at, basis, Vector3(-0.22, 0.41, -0.22), Vector3(-0.19, 0.84, -0.24), 0.021, MOSS
	)
	for offset in [
		Vector3(-0.08, 0.0, 0.0),
		Vector3(0.08, 0.0, 0.0),
		Vector3(0.0, 0.07, 0.0),
		Vector3(0.0, -0.07, 0.0)
	]:
		GEO.put(
			world,
			"ball",
			at,
			basis,
			Vector3(-0.19, 0.84, -0.26) + offset,
			Vector3(0.09, 0.066, 0.035),
			ORCHID
		)
	GEO.put(
		world, "ball", at, basis, Vector3(-0.19, 0.84, -0.30), Vector3(0.033, 0.033, 0.025), BRASS
	)
	if not world.low_detail:
		GEO.put(
			world,
			"box",
			at,
			basis,
			Vector3(0.30, 0.45, -0.09),
			Vector3(0.025, 0.018, 0.31),
			STONE_DARK,
			false,
			fallen
		)
		_leaf(world, at, basis, Vector3(0.24, 0.18, 0.35), Vector3(0.72, 0.44, -0.03), 0.11, MOSS)


static func _oasis_pavilion(world, at: Vector3, basis: Basis) -> void:
	GEO.put(
		world,
		"cylinder",
		at,
		basis,
		Vector3(0.0, 0.13, 0.0),
		Vector3(1.97, 0.26, 1.68),
		DESERT_STONE
	)
	GEO.put(
		world, "box", at, basis, Vector3(0.0, 0.20, -1.56), Vector3(2.42, 0.14, 0.43), DESERT_LIGHT
	)
	for x in [-1.12, 1.12]:
		for z in [-0.85, 0.85]:
			GEO.put(
				world,
				"cylinder",
				at,
				basis,
				Vector3(x, 0.34, z),
				Vector3(0.26, 0.16, 0.26),
				DESERT_LIGHT
			)
			GEO.put(
				world,
				"cylinder",
				at,
				basis,
				Vector3(x, 1.29, z),
				Vector3(0.17, 1.76, 0.17),
				DESERT_STONE
			)
			GEO.put(
				world,
				"cylinder",
				at,
				basis,
				Vector3(x, 2.24, z),
				Vector3(0.29, 0.18, 0.29),
				DESERT_LIGHT
			)
	for z in [-0.85, 0.85]:
		GEO.put(
			world, "box", at, basis, Vector3(0.0, 2.45, z), Vector3(2.81, 0.24, 0.40), DESERT_LIGHT
		)
	for x in [-1.12, 1.12]:
		GEO.put(
			world, "box", at, basis, Vector3(x, 2.45, 0.0), Vector3(0.40, 0.24, 2.10), DESERT_LIGHT
		)
	GEO.put(world, "ball", at, basis, Vector3(0.0, 2.80, 0.0), Vector3(1.48, 0.56, 1.23), COBALT)
	GEO.put(world, "cylinder", at, basis, Vector3(0.0, 2.52, 0.0), Vector3(1.52, 0.09, 1.27), BRASS)
	GEO.put(
		world, "cylinder", at, basis, Vector3(0.0, 3.47, 0.0), Vector3(0.045, 0.31, 0.045), BRASS
	)
	GEO.put(
		world,
		"torus",
		at,
		basis,
		Vector3(0.0, 3.84, 0.0),
		Vector3(0.73, 0.73, 0.73),
		BRASS,
		false,
		Quaternion(Vector3.RIGHT, PI * 0.5)
	)
	GEO.put(
		world, "ball", at, basis, Vector3(0.0, 3.84, 0.0), Vector3(0.09, 0.09, 0.09), DESERT_LIGHT
	)
	GEO.beam(world, at, basis, Vector3(-0.28, 3.66, 0.0), Vector3(0.28, 4.02, 0.0), 0.021, BRASS)
	GEO.put(world, "box", at, basis, Vector3(0.0, 2.18, -1.075), Vector3(2.19, 0.39, 0.045), CLOTH)
	GEO.put(world, "box", at, basis, Vector3(0.0, 1.97, -1.11), Vector3(2.21, 0.05, 0.035), BRASS)
	GEO.put(
		world,
		"cylinder",
		at,
		basis,
		Vector3(0.0, 0.34, 0.0),
		Vector3(0.72, 0.15, 0.65),
		DESERT_LIGHT
	)
	GEO.put(
		world, "cylinder", at, basis, Vector3(0.0, 0.425, 0.0), Vector3(0.60, 0.035, 0.54), WATER
	)
	GEO.put(
		world, "box", at, basis, Vector3(0.0, 0.55, 0.84), Vector3(1.55, 0.22, 0.35), DESERT_STONE
	)
	if not world.low_detail:
		GEO.put(
			world,
			"torus",
			at,
			basis,
			Vector3(0.0, 3.84, 0.0),
			Vector3(0.66, 0.66, 0.66),
			BRASS,
			false,
			Quaternion(Vector3.FORWARD, PI * 0.34)
		)
		for x in [-0.74, 0.0, 0.74]:
			GEO.put(
				world,
				"box",
				at,
				basis,
				Vector3(x, 2.18, -1.103),
				Vector3(0.035, 0.32, 0.018),
				PAPER
			)
		for x in [-1.12, 1.12]:
			GEO.put(
				world,
				"cylinder",
				at,
				basis,
				Vector3(x, 1.71, -0.85),
				Vector3(0.176, 0.075, 0.176),
				COBALT
			)
		GEO.put(
			world,
			"ball",
			at,
			basis,
			Vector3(0.0, 1.76, 0.0),
			Vector3(0.09, 0.15, 0.09),
			PAPER,
			true
		)
		GEO.beam(world, at, basis, Vector3(0.0, 2.38, 0.0), Vector3(0.0, 1.91, 0.0), 0.018, BRASS)


static func _sun_banner(world, at: Vector3, basis: Basis) -> void:
	GEO.put(
		world,
		"cylinder",
		at,
		basis,
		Vector3(0.0, 0.10, 0.0),
		Vector3(0.38, 0.20, 0.38),
		DESERT_LIGHT
	)
	GEO.put(
		world,
		"cylinder",
		at,
		basis,
		Vector3(0.0, 0.98, 0.0),
		Vector3(0.15, 1.56, 0.15),
		DESERT_STONE
	)
	GEO.put(world, "cylinder", at, basis, Vector3(0.0, 1.81, 0.0), Vector3(0.21, 0.10, 0.21), BRASS)
	GEO.beam(world, at, basis, Vector3(0.0, 1.81, 0.0), Vector3(0.0, 2.81, 0.0), 0.027, BRASS)
	GEO.beam(world, at, basis, Vector3(-0.08, 2.72, 0.0), Vector3(0.68, 2.72, 0.0), 0.024, BRASS)
	GEO.put(world, "box", at, basis, Vector3(0.31, 2.33, 0.0), Vector3(0.61, 0.74, 0.035), COBALT)
	GEO.put(
		world, "box", at, basis, Vector3(0.31, 1.95, -0.025), Vector3(0.61, 0.045, 0.018), BRASS
	)
	GEO.put(
		world, "ball", at, basis, Vector3(0.31, 2.33, -0.035), Vector3(0.115, 0.115, 0.018), BRASS
	)
	GEO.put(
		world,
		"rock",
		at,
		basis,
		Vector3(-0.36, 0.11, 0.21),
		Vector3(0.25, 0.17, 0.22),
		DESERT_STONE
	)
	if not world.low_detail:
		for direction in [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN]:
			var center := Vector3(0.31, 2.33, -0.04)
			GEO.beam(
				world, at, basis, center + direction * 0.15, center + direction * 0.22, 0.013, BRASS
			)
		GEO.put(
			world, "ball", at, basis, Vector3(0.0, 2.84, 0.0), Vector3(0.065, 0.065, 0.065), BRASS
		)


static func _palm_pool(world, at: Vector3, basis: Basis) -> void:
	GEO.put(
		world,
		"cylinder",
		at,
		basis,
		Vector3(0.0, 0.08, 0.0),
		Vector3(0.72, 0.16, 0.63),
		DESERT_STONE
	)
	GEO.put(
		world, "cylinder", at, basis, Vector3(0.0, 0.17, -0.08), Vector3(0.59, 0.035, 0.49), WATER
	)
	GEO.beam(world, at, basis, Vector3(-0.22, 0.17, 0.22), Vector3(-0.16, 0.94, 0.26), 0.095, WOOD)
	GEO.beam(world, at, basis, Vector3(-0.16, 0.94, 0.26), Vector3(0.0, 1.62, 0.24), 0.069, WOOD)
	var crown := Vector3(0.0, 1.62, 0.24)
	GEO.put(world, "ball", at, basis, crown, Vector3(0.15, 0.15, 0.15), PALM)
	for tip in [
		Vector3(-0.86, 1.40, 0.22),
		Vector3(0.86, 1.40, 0.22),
		Vector3(-0.12, 1.43, -0.69),
		Vector3(0.12, 1.42, 0.99)
	]:
		_leaf(world, at, basis, crown, tip, 0.13, PALM)
	GEO.put(
		world,
		"rock",
		at,
		basis,
		Vector3(0.44, 0.18, -0.34),
		Vector3(0.23, 0.19, 0.19),
		DESERT_LIGHT
	)
	if not world.low_detail:
		_leaf(world, at, basis, crown, Vector3(-0.65, 1.71, -0.31), 0.12, LEAF)
		_leaf(world, at, basis, crown, Vector3(0.60, 1.65, 0.75), 0.12, PALM)
		GEO.put(
			world, "ball", at, basis, Vector3(-0.10, 1.51, 0.21), Vector3(0.075, 0.09, 0.075), BARK
		)
		GEO.put(
			world, "ball", at, basis, Vector3(0.09, 1.49, 0.28), Vector3(0.07, 0.09, 0.07), BARK
		)
