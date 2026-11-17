extends RefCounted
## Compact roadside places authored from the four world reference boards.
## Geometry is submitted to the world's shared MultiMesh batching path only.

const GEO = preload("res://scripts/games/track_themes/track_theme_geometry.gd")

const SKY_STONE := Color("c6c4b0")
const SKY_GOLD := Color("d7a646")
const SKY_NAVY := Color("263855")
const SKY_ROCK := Color("626582")
const SKY_GREEN := Color("38694f")
const SKY_LIGHT := Color("ffd17a")

const CANYON_DARK := Color("65516d")
const CANYON_MID := Color("977b94")
const CANYON_EDGE := Color("c0a1b4")
const CANYON_BRASS := Color("bd9251")
const CRYSTAL_BLUE := Color("60c5dc")
const CRYSTAL_VIOLET := Color("ae7edd")
const CRYSTAL_GLASS := Color("46768e")

const CANDY_CREAM := Color("fff0d5")
const CANDY_PINK := Color("ed94b4")
const CANDY_PEACH := Color("efa878")
const CANDY_LILAC := Color("b69bdc")
const CANDY_GOLD := Color("e4b657")
const CANDY_PLUM := Color("634b75")
const CANDY_WINDOW := Color("ffd17e")

const WINTER_WOOD := Color("674c3c")
const WINTER_TIMBER := Color("342e33")
const WINTER_BLUE := Color("344d7e")
const WINTER_SNOW := Color("cbdced")
const WINTER_STONE := Color("6d7a8d")
const WINTER_FIR := Color("245650")
const WINTER_LIGHT := Color("ffc570")


static func build(world, at: Vector3, basis: Basis, large: bool, marker: bool) -> bool:
	match world.track_id:
		"bergwelt":
			_sky(world, at, basis, large, marker)
		"crystal_canyon":
			_canyon(world, at, basis, large, marker)
		"candy_cloud":
			_candy(world, at, basis, large, marker)
		"winter_sprint":
			_winter(world, at, basis, large, marker)
		_:
			return false
	return true


static func _sky(world, at: Vector3, basis: Basis, large: bool, marker: bool) -> void:
	if large:
		_sky_terrace(world, at, basis)
	elif marker:
		_sky_beacon(world, at, basis)
	else:
		_sky_islet(world, at, basis)


static func _sky_terrace(world, at: Vector3, basis: Basis) -> void:
	GEO.put(world, "rock", at, basis, Vector3(0, 0.12, 0.12), Vector3(2.34, 0.62, 1.83), SKY_ROCK)
	GEO.put(
		world, "cylinder", at, basis, Vector3(0, 0.47, 0.12), Vector3(2.43, 0.26, 1.94), SKY_STONE
	)
	GEO.put(
		world, "cylinder", at, basis, Vector3(0, 0.63, 0.12), Vector3(2.48, 0.07, 1.99), SKY_GOLD
	)
	GEO.put(
		world, "cylinder", at, basis, Vector3(0, 0.70, 0.12), Vector3(2.35, 0.09, 1.86), SKY_GREEN
	)
	for step in range(3):
		GEO.put(
			world,
			"box",
			at,
			basis,
			Vector3(0, 0.18 + step * 0.18, -1.96 + step * 0.26),
			Vector3(1.50, 0.22, 0.49),
			SKY_STONE
		)
	GEO.put(
		world, "cylinder", at, basis, Vector3(0, 0.83, 0.30), Vector3(1.61, 0.20, 1.36), SKY_STONE
	)
	GEO.put(
		world, "cylinder", at, basis, Vector3(0, 2.04, 0.65), Vector3(0.87, 2.20, 0.51), SKY_NAVY
	)
	for side in [-1.0, 1.0]:
		for row in range(3):
			var p := Vector3(side * 1.21, 1.85, -0.61 + row * 0.82)
			GEO.put(world, "cylinder", at, basis, p, Vector3(0.14, 1.90, 0.14), SKY_STONE)
			GEO.put(
				world,
				"cylinder",
				at,
				basis,
				p + Vector3(0, 0.98, 0),
				Vector3(0.23, 0.16, 0.23),
				SKY_GOLD
			)
			if not world.low_detail:
				GEO.put(
					world,
					"cylinder",
					at,
					basis,
					p - Vector3(0, 0.94, 0),
					Vector3(0.23, 0.14, 0.23),
					SKY_STONE
				)
	GEO.put(
		world, "cylinder", at, basis, Vector3(0, 2.99, 0.30), Vector3(1.66, 0.24, 1.44), SKY_STONE
	)
	GEO.put(
		world, "cylinder", at, basis, Vector3(0, 3.13, 0.30), Vector3(1.70, 0.07, 1.48), SKY_GOLD
	)
	GEO.put(world, "ball", at, basis, Vector3(0, 3.25, 0.30), Vector3(1.49, 0.86, 1.27), SKY_NAVY)
	GEO.put(world, "cone", at, basis, Vector3(0, 4.28, 0.30), Vector3(0.14, 0.54, 0.14), SKY_GOLD)
	GEO.put(
		world, "star", at, basis, Vector3(0, 4.65, 0.30), Vector3(0.24, 0.24, 0.20), SKY_LIGHT, true
	)
	GEO.put(
		world, "box", at, basis, Vector3(0, 1.93, 0.12), Vector3(0.47, 1.18, 0.08), SKY_LIGHT, true
	)
	for side in [-1.0, 1.0]:
		GEO.beam(
			world,
			at,
			basis,
			Vector3(side * 1.90, 1.22, -0.96),
			Vector3(side * 1.90, 1.22, 0.92),
			0.055,
			SKY_GOLD
		)
		for row in range(3):
			GEO.put(
				world,
				"cylinder",
				at,
				basis,
				Vector3(side * 1.90, 0.98, -0.96 + row * 0.94),
				Vector3(0.06, 0.49, 0.06),
				SKY_STONE
			)
	GEO.put(
		world,
		"cylinder",
		at,
		basis,
		Vector3(-1.96, 1.14, 0.69),
		Vector3(0.08, 0.79, 0.08),
		Color("63584c")
	)
	GEO.put(
		world, "crown", at, basis, Vector3(-1.96, 1.77, 0.69), Vector3(0.30, 0.92, 0.30), SKY_GREEN
	)
	if not world.low_detail:
		for side in [-1.0, 1.0]:
			GEO.put(
				world,
				"box",
				at,
				basis,
				Vector3(side * 0.46, 1.95, 0.08),
				Vector3(0.06, 1.34, 0.08),
				SKY_GOLD
			)
			GEO.put(
				world,
				"star",
				at,
				basis,
				Vector3(side * 0.74, 3.00, -1.15),
				Vector3(0.13, 0.13, 0.12),
				SKY_GOLD
			)


static func _sky_beacon(world, at: Vector3, basis: Basis) -> void:
	GEO.put(world, "cylinder", at, basis, Vector3(0, 0.12, 0), Vector3(0.70, 0.24, 0.61), SKY_ROCK)
	GEO.put(world, "cylinder", at, basis, Vector3(0, 0.29, 0), Vector3(0.65, 0.13, 0.56), SKY_GOLD)
	GEO.put(world, "box", at, basis, Vector3(0, 1.10, 0), Vector3(0.35, 1.55, 0.35), SKY_STONE)
	GEO.put(world, "cylinder", at, basis, Vector3(0, 1.89, 0), Vector3(0.48, 0.14, 0.48), SKY_GOLD)
	GEO.put(world, "cylinder", at, basis, Vector3(0, 2.20, 0), Vector3(0.35, 0.53, 0.35), SKY_NAVY)
	GEO.put(world, "cone", at, basis, Vector3(0, 2.61, 0), Vector3(0.56, 0.40, 0.56), SKY_STONE)
	GEO.put(
		world,
		"star",
		at,
		basis,
		Vector3(0, 2.20, -0.37),
		Vector3(0.22, 0.22, 0.16),
		SKY_LIGHT,
		true
	)
	GEO.beam(world, at, basis, Vector3(-0.66, 2.94, 0), Vector3(0.66, 2.94, 0), 0.035, SKY_GOLD)
	GEO.beam(world, at, basis, Vector3(0, 2.77, 0), Vector3(0, 3.14, 0), 0.035, SKY_GOLD)
	if not world.low_detail:
		for side in [-1.0, 1.0]:
			GEO.put(
				world,
				"ball",
				at,
				basis,
				Vector3(side * 0.67, 2.94, 0),
				Vector3(0.09, 0.09, 0.09),
				SKY_GOLD
			)
		GEO.put(
			world, "box", at, basis, Vector3(0, 1.18, -0.19), Vector3(0.08, 0.85, 0.03), SKY_GOLD
		)


static func _sky_islet(world, at: Vector3, basis: Basis) -> void:
	GEO.put(world, "rock", at, basis, Vector3(0, 0.25, 0), Vector3(0.97, 0.55, 0.77), SKY_ROCK)
	GEO.put(world, "cylinder", at, basis, Vector3(0, 0.60, 0), Vector3(0.88, 0.14, 0.69), SKY_GREEN)
	GEO.put(
		world,
		"cylinder",
		at,
		basis,
		Vector3(-0.32, 0.98, 0.08),
		Vector3(0.07, 0.70, 0.07),
		Color("6d6060")
	)
	GEO.put(
		world,
		"crown",
		at,
		basis,
		Vector3(-0.32, 1.43, 0.08),
		Vector3(0.32, 0.72, 0.32),
		Color("497a63")
	)
	GEO.put(
		world,
		"box",
		at,
		basis,
		Vector3(0.51, 0.30, -0.53),
		Vector3(0.29, 0.72, 0.06),
		Color("70b4d5")
	)
	GEO.put(
		world,
		"ball",
		at,
		basis,
		Vector3(0.48, 0.03, -0.49),
		Vector3(0.44, 0.13, 0.25),
		Color("aebed7")
	)
	if not world.low_detail:
		GEO.put(
			world,
			"cylinder",
			at,
			basis,
			Vector3(0.38, 0.84, 0.19),
			Vector3(0.06, 0.38, 0.06),
			Color("6d6060")
		)
		GEO.put(
			world,
			"crown",
			at,
			basis,
			Vector3(0.38, 1.12, 0.19),
			Vector3(0.28, 0.39, 0.28),
			Color("a88ab3")
		)
		GEO.put(
			world,
			"box",
			at,
			basis,
			Vector3(0.49, 0.31, -0.57),
			Vector3(0.05, 0.64, 0.02),
			Color("a6deed")
		)


static func _canyon(world, at: Vector3, basis: Basis, large: bool, marker: bool) -> void:
	if large:
		_canyon_observatory(world, at, basis)
	elif marker:
		_canyon_survey_beacon(world, at, basis)
	else:
		_canyon_outcrop(world, at, basis)


static func _canyon_observatory(world, at: Vector3, basis: Basis) -> void:
	GEO.put(world, "rock", at, basis, Vector3(0, 0.10, 0), Vector3(2.27, 0.45, 1.65), CANYON_DARK)
	GEO.put(world, "box", at, basis, Vector3(0, 0.35, 0), Vector3(4.91, 0.21, 3.14), CANYON_MID)
	GEO.put(
		world, "box", at, basis, Vector3(-0.12, 0.52, 0.04), Vector3(4.55, 0.13, 2.96), CANYON_EDGE
	)
	GEO.put(
		world, "box", at, basis, Vector3(-0.18, 0.66, 0.06), Vector3(4.18, 0.19, 2.74), CANYON_MID
	)
	GEO.put(
		world,
		"cylinder",
		at,
		basis,
		Vector3(-0.60, 1.39, 0.20),
		Vector3(1.15, 1.33, 1.06),
		CANYON_DARK
	)
	GEO.put(
		world,
		"cylinder",
		at,
		basis,
		Vector3(-0.60, 0.85, 0.20),
		Vector3(1.21, 0.19, 1.12),
		CANYON_EDGE
	)
	GEO.put(
		world,
		"cylinder",
		at,
		basis,
		Vector3(-0.60, 2.10, 0.20),
		Vector3(1.26, 0.15, 1.17),
		CANYON_BRASS
	)
	GEO.put(
		world,
		"ball",
		at,
		basis,
		Vector3(-0.60, 2.18, 0.20),
		Vector3(1.13, 0.69, 1.04),
		CRYSTAL_GLASS
	)
	for side in [-1.0, 1.0]:
		GEO.beam(
			world,
			at,
			basis,
			Vector3(-0.60 + side * 1.08, 2.18, 0.20),
			Vector3(-0.60, 2.86, 0.20),
			0.035,
			CANYON_BRASS
		)
		GEO.beam(
			world,
			at,
			basis,
			Vector3(-0.60, 2.18, 0.20 + side * 0.99),
			Vector3(-0.60, 2.86, 0.20),
			0.035,
			CANYON_BRASS
		)
	GEO.put(
		world,
		"box",
		at,
		basis,
		Vector3(-0.60, 1.28, -0.89),
		Vector3(0.46, 0.82, 0.05),
		Color("263548")
	)
	GEO.put(
		world,
		"box",
		at,
		basis,
		Vector3(-0.60, 1.75, -0.90),
		Vector3(0.62, 0.10, 0.10),
		CANYON_BRASS
	)
	GEO.put(
		world,
		"cylinder",
		at,
		basis,
		Vector3(-0.60, 3.00, 0.20),
		Vector3(0.13, 0.40, 0.13),
		CANYON_BRASS
	)
	GEO.beam(
		world,
		at,
		basis,
		Vector3(-0.88, 2.94, 0.53),
		Vector3(0.22, 3.78, -0.75),
		0.16,
		Color("35485d")
	)
	GEO.beam(
		world, at, basis, Vector3(0.07, 3.67, -0.57), Vector3(0.30, 3.84, -0.84), 0.22, CANYON_BRASS
	)
	GEO.put(
		world,
		"ball",
		at,
		basis,
		Vector3(0.31, 3.85, -0.85),
		Vector3(0.16, 0.16, 0.16),
		CRYSTAL_BLUE
	)
	GEO.put(
		world,
		"crystal",
		at,
		basis,
		Vector3(1.57, 0.75, -0.12),
		Vector3(0.66, 1.63, 0.57),
		CRYSTAL_BLUE,
		false,
		Quaternion(Vector3.FORWARD, 0.13)
	)
	GEO.put(
		world,
		"crystal",
		at,
		basis,
		Vector3(2.03, 0.68, 0.65),
		Vector3(0.48, 1.13, 0.43),
		CRYSTAL_VIOLET,
		false,
		Quaternion(Vector3.FORWARD, -0.13)
	)
	GEO.put(
		world,
		"crystal",
		at,
		basis,
		Vector3(1.07, 0.73, 0.73),
		Vector3(0.39, 0.81, 0.36),
		Color("7e67b1")
	)
	GEO.put(
		world,
		"crystal",
		at,
		basis,
		Vector3(1.58, 0.90, -0.13),
		Vector3(0.13, 1.19, 0.11),
		Color("95dce6"),
		true,
		Quaternion(Vector3.FORWARD, 0.13)
	)
	for step in range(2):
		GEO.put(
			world,
			"box",
			at,
			basis,
			Vector3(-0.60, 0.18 + step * 0.24, -1.64 + step * 0.28),
			Vector3(0.98, 0.24, 0.51),
			CANYON_EDGE
		)
	if not world.low_detail:
		for side in [-1.0, 1.0]:
			GEO.put(
				world,
				"box",
				at,
				basis,
				Vector3(-0.60 + side * 0.72, 1.47, -0.63),
				Vector3(0.30, 0.46, 0.12),
				Color("e9ba76"),
				true
			)
			GEO.put(
				world,
				"box",
				at,
				basis,
				Vector3(-0.60 + side * 0.72, 1.73, -0.64),
				Vector3(0.38, 0.07, 0.16),
				CANYON_BRASS
			)
		GEO.put(
			world,
			"rock",
			at,
			basis,
			Vector3(1.79, 0.79, -1.03),
			Vector3(0.41, 0.23, 0.32),
			CANYON_DARK
		)
		GEO.put(
			world,
			"crystal",
			at,
			basis,
			Vector3(1.94, 0.82, -0.99),
			Vector3(0.23, 0.55, 0.22),
			CRYSTAL_VIOLET,
			false,
			Quaternion(Vector3.RIGHT, -0.20)
		)
		GEO.beam(
			world,
			at,
			basis,
			Vector3(-1.90, 1.15, 0.95),
			Vector3(-1.90, 1.15, -0.63),
			0.055,
			CANYON_BRASS
		)
		for row in range(3):
			GEO.put(
				world,
				"cylinder",
				at,
				basis,
				Vector3(-1.90, 0.92, 0.95 - row * 0.79),
				Vector3(0.045, 0.47, 0.045),
				CANYON_BRASS
			)


static func _canyon_survey_beacon(world, at: Vector3, basis: Basis) -> void:
	GEO.put(world, "box", at, basis, Vector3(0, 0.12, 0), Vector3(1.48, 0.24, 1.14), CANYON_DARK)
	GEO.put(
		world, "box", at, basis, Vector3(-0.05, 0.31, 0), Vector3(1.30, 0.14, 1.01), CANYON_EDGE
	)
	GEO.put(
		world, "cylinder", at, basis, Vector3(0, 0.64, 0), Vector3(0.46, 0.56, 0.46), CANYON_MID
	)
	GEO.put(
		world, "cylinder", at, basis, Vector3(0, 0.93, 0), Vector3(0.57, 0.12, 0.57), CANYON_BRASS
	)
	GEO.put(
		world,
		"crystal",
		at,
		basis,
		Vector3(0, 0.99, 0),
		Vector3(0.61, 1.11, 0.51),
		CRYSTAL_BLUE,
		false,
		Quaternion(Vector3.FORWARD, 0.10)
	)
	GEO.put(
		world,
		"crystal",
		at,
		basis,
		Vector3(0, 1.13, 0),
		Vector3(0.15, 0.86, 0.13),
		Color("9fdbdf"),
		true,
		Quaternion(Vector3.FORWARD, 0.10)
	)
	GEO.put(
		world, "box", at, basis, Vector3(0, 0.67, -0.47), Vector3(0.45, 0.28, 0.06), Color("344960")
	)
	if not world.low_detail:
		for side in [-1.0, 1.0]:
			GEO.beam(
				world,
				at,
				basis,
				Vector3(side * 0.57, 0.99, 0),
				Vector3(side * 0.72, 1.37, 0),
				0.035,
				CANYON_BRASS
			)
			GEO.put(
				world,
				"ball",
				at,
				basis,
				Vector3(side * 0.72, 1.38, 0),
				Vector3(0.08, 0.08, 0.08),
				CANYON_BRASS
			)


static func _canyon_outcrop(world, at: Vector3, basis: Basis) -> void:
	GEO.put(world, "rock", at, basis, Vector3(0, 0.15, 0), Vector3(0.99, 0.30, 0.73), CANYON_DARK)
	GEO.put(
		world, "box", at, basis, Vector3(-0.08, 0.36, 0.03), Vector3(1.94, 0.12, 1.28), CANYON_EDGE
	)
	GEO.put(
		world, "box", at, basis, Vector3(0.04, 0.48, 0.06), Vector3(1.72, 0.13, 1.12), CANYON_MID
	)
	GEO.put(
		world,
		"crystal",
		at,
		basis,
		Vector3(0.34, 0.54, 0.18),
		Vector3(0.48, 0.95, 0.42),
		CRYSTAL_VIOLET,
		false,
		Quaternion(Vector3.FORWARD, -0.15)
	)
	GEO.put(
		world,
		"crystal",
		at,
		basis,
		Vector3(-0.39, 0.52, -0.18),
		Vector3(0.42, 0.69, 0.37),
		CRYSTAL_BLUE,
		false,
		Quaternion(Vector3.RIGHT, -0.16)
	)
	if not world.low_detail:
		GEO.put(
			world,
			"crystal",
			at,
			basis,
			Vector3(0.67, 0.51, -0.32),
			Vector3(0.25, 0.43, 0.24),
			Color("a8a1df"),
			false,
			Quaternion(Vector3.FORWARD, -0.20)
		)
		GEO.put(
			world,
			"rock",
			at,
			basis,
			Vector3(-0.64, 0.55, 0.38),
			Vector3(0.27, 0.16, 0.23),
			CANYON_DARK
		)
		GEO.put(
			world,
			"box",
			at,
			basis,
			Vector3(-0.08, 0.38, -0.63),
			Vector3(1.29, 0.035, 0.025),
			Color("dfbfd0")
		)


static func _candy(world, at: Vector3, basis: Basis, large: bool, marker: bool) -> void:
	if large:
		_candy_patisserie(world, at, basis)
	elif marker:
		_candy_donut(world, at, basis)
	else:
		_candy_cloud_garden(world, at, basis)


static func _candy_patisserie(world, at: Vector3, basis: Basis) -> void:
	GEO.put(
		world, "cylinder", at, basis, Vector3(0, 0.14, 0.13), Vector3(2.46, 0.28, 1.85), CANDY_LILAC
	)
	GEO.put(
		world, "cylinder", at, basis, Vector3(0, 0.34, 0.13), Vector3(2.29, 0.20, 1.69), CANDY_PEACH
	)
	GEO.put(
		world, "cylinder", at, basis, Vector3(0, 0.47, 0.13), Vector3(2.32, 0.07, 1.72), CANDY_GOLD
	)
	GEO.put(world, "box", at, basis, Vector3(0, 1.34, 0.18), Vector3(2.95, 1.72, 2.20), CANDY_CREAM)
	GEO.put(world, "box", at, basis, Vector3(0, 0.67, 0.18), Vector3(3.07, 0.21, 2.28), CANDY_PINK)
	GEO.put(
		world, "cylinder", at, basis, Vector3(0, 2.21, 0.18), Vector3(1.74, 0.20, 1.36), CANDY_PINK
	)
	GEO.put(
		world, "ball", at, basis, Vector3(0, 2.48, 0.18), Vector3(1.57, 0.45, 1.20), CANDY_CREAM
	)
	GEO.put(
		world, "ball", at, basis, Vector3(0.13, 2.99, 0.18), Vector3(1.04, 0.43, 0.86), CANDY_CREAM
	)
	GEO.put(
		world, "ball", at, basis, Vector3(0.24, 3.43, 0.18), Vector3(0.64, 0.35, 0.56), CANDY_CREAM
	)
	GEO.put(
		world,
		"cone",
		at,
		basis,
		Vector3(0.29, 3.89, 0.18),
		Vector3(0.31, 0.64, 0.30),
		CANDY_CREAM,
		false,
		Quaternion(Vector3.FORWARD, 0.18)
	)
	GEO.put(
		world, "ball", at, basis, Vector3(0.34, 4.23, 0.18), Vector3(0.12, 0.12, 0.12), CANDY_GOLD
	)
	GEO.put(world, "box", at, basis, Vector3(0, 1.16, -0.95), Vector3(0.62, 1.10, 0.09), CANDY_PLUM)
	GEO.put(world, "box", at, basis, Vector3(0, 1.75, -1.00), Vector3(0.80, 0.13, 0.12), CANDY_GOLD)
	for side in [-1.0, 1.0]:
		GEO.put(
			world,
			"box",
			at,
			basis,
			Vector3(side * 0.38, 1.18, -1.00),
			Vector3(0.10, 1.14, 0.12),
			CANDY_GOLD
		)
		GEO.put(
			world,
			"box",
			at,
			basis,
			Vector3(side * 0.99, 1.43, -0.96),
			Vector3(0.48, 0.67, 0.10),
			CANDY_GOLD
		)
		GEO.put(
			world,
			"box",
			at,
			basis,
			Vector3(side * 0.99, 1.43, -1.02),
			Vector3(0.34, 0.51, 0.04),
			CANDY_WINDOW,
			true
		)
		GEO.put(
			world,
			"cylinder",
			at,
			basis,
			Vector3(side * 1.87, 1.25, 0.51),
			Vector3(0.45, 1.49, 0.45),
			CANDY_PEACH
		)
		GEO.put(
			world,
			"cylinder",
			at,
			basis,
			Vector3(side * 1.87, 1.92, 0.51),
			Vector3(0.55, 0.16, 0.55),
			CANDY_GOLD
		)
		GEO.put(
			world,
			"cone",
			at,
			basis,
			Vector3(side * 1.87, 2.40, 0.51),
			Vector3(0.61, 0.86, 0.61),
			CANDY_PINK
		)
		GEO.put(
			world,
			"ball",
			at,
			basis,
			Vector3(side * 1.87, 2.89, 0.51),
			Vector3(0.12, 0.12, 0.12),
			CANDY_GOLD
		)
	GEO.put(
		world, "box", at, basis, Vector3(0, 0.29, -1.59), Vector3(1.38, 0.28, 0.58), CANDY_CREAM
	)
	GEO.put(world, "box", at, basis, Vector3(0, 0.45, -1.39), Vector3(1.20, 0.10, 0.40), CANDY_PINK)
	if not world.low_detail:
		for side in [-1.0, 1.0]:
			for stripe in range(3):
				GEO.put(
					world,
					"cylinder",
					at,
					basis,
					Vector3(side * 1.87, 0.85 + stripe * 0.35, 0.51),
					Vector3(0.463, 0.13, 0.463),
					CANDY_CREAM
				)
			GEO.put(
				world,
				"box",
				at,
				basis,
				Vector3(side * 0.99, 1.43, -1.05),
				Vector3(0.035, 0.51, 0.025),
				CANDY_GOLD
			)
			GEO.put(
				world,
				"ball",
				at,
				basis,
				Vector3(side * 1.31, 2.35, -0.62),
				Vector3(0.27, 0.24, 0.25),
				CANDY_CREAM
			)
		GEO.put(
			world, "star", at, basis, Vector3(0, 2.23, -1.20), Vector3(0.19, 0.19, 0.16), CANDY_GOLD
		)
		GEO.put(
			world,
			"ball",
			at,
			basis,
			Vector3(-1.91, 0.63, -0.79),
			Vector3(0.29, 0.20, 0.26),
			CANDY_LILAC
		)
		GEO.put(
			world,
			"ball",
			at,
			basis,
			Vector3(1.91, 0.63, -0.79),
			Vector3(0.29, 0.20, 0.26),
			CANDY_PINK
		)


static func _candy_donut(world, at: Vector3, basis: Basis) -> void:
	GEO.put(world, "box", at, basis, Vector3(0, 0.14, 0), Vector3(2.08, 0.28, 0.80), CANDY_PEACH)
	GEO.put(world, "box", at, basis, Vector3(0, 0.31, 0), Vector3(1.92, 0.08, 0.74), CANDY_CREAM)
	for side in [-1.0, 1.0]:
		GEO.put(
			world,
			"cylinder",
			at,
			basis,
			Vector3(side * 0.71, 0.84, 0),
			Vector3(0.09, 1.05, 0.09),
			CANDY_GOLD
		)
	GEO.put(
		world,
		"torus",
		at,
		basis,
		Vector3(0, 1.61, 0),
		Vector3(2.17, 0.83, 2.17),
		CANDY_PEACH,
		false,
		Quaternion(Vector3.RIGHT, PI * 0.5)
	)
	GEO.put(
		world,
		"torus",
		at,
		basis,
		Vector3(0, 1.61, -0.11),
		Vector3(2.22, 0.28, 2.22),
		CANDY_PINK,
		false,
		Quaternion(Vector3.RIGHT, PI * 0.5)
	)
	if not world.low_detail:
		for index in range(7):
			var angle: float = float(index) * TAU / 7.0
			var sprinkle := Vector3(cos(angle) * 0.87, 1.61 + sin(angle) * 0.87, -0.18)
			var color: Color = CANDY_GOLD if index % 2 == 0 else CANDY_CREAM
			GEO.put(
				world,
				"box",
				at,
				basis,
				sprinkle,
				Vector3(0.07, 0.18, 0.04),
				color,
				false,
				Quaternion(Vector3.FORWARD, angle + 0.4)
			)


static func _candy_cloud_garden(world, at: Vector3, basis: Basis) -> void:
	GEO.put(
		world, "cylinder", at, basis, Vector3(0, 0.13, 0), Vector3(0.94, 0.24, 0.73), CANDY_LILAC
	)
	GEO.put(
		world,
		"ball",
		at,
		basis,
		Vector3(-0.53, 0.31, -0.03),
		Vector3(0.49, 0.24, 0.48),
		CANDY_CREAM
	)
	GEO.put(
		world, "ball", at, basis, Vector3(0.12, 0.39, 0.11), Vector3(0.66, 0.29, 0.51), CANDY_CREAM
	)
	GEO.put(
		world, "ball", at, basis, Vector3(0.65, 0.28, -0.19), Vector3(0.36, 0.22, 0.40), CANDY_CREAM
	)
	GEO.put(
		world,
		"cylinder",
		at,
		basis,
		Vector3(-0.28, 0.91, 0.07),
		Vector3(0.09, 1.04, 0.09),
		CANDY_PEACH
	)
	GEO.put(
		world, "crown", at, basis, Vector3(-0.28, 1.60, 0.07), Vector3(0.46, 0.56, 0.44), CANDY_PINK
	)
	if not world.low_detail:
		GEO.put(
			world,
			"ball",
			at,
			basis,
			Vector3(-0.52, 1.51, -0.10),
			Vector3(0.29, 0.32, 0.29),
			CANDY_LILAC
		)
		GEO.put(
			world,
			"ball",
			at,
			basis,
			Vector3(0.71, 0.54, 0.30),
			Vector3(0.19, 0.26, 0.18),
			CANDY_PINK
		)
		GEO.put(
			world,
			"ball",
			at,
			basis,
			Vector3(0.43, 0.62, 0.30),
			Vector3(0.15, 0.20, 0.15),
			CANDY_GOLD
		)
		for stripe in range(3):
			GEO.put(
				world,
				"cylinder",
				at,
				basis,
				Vector3(-0.28, 0.66 + stripe * 0.25, 0.07),
				Vector3(0.095, 0.09, 0.095),
				CANDY_CREAM
			)


static func _winter(world, at: Vector3, basis: Basis, large: bool, marker: bool) -> void:
	if large:
		_winter_chalet(world, at, basis)
	elif marker:
		_winter_lantern(world, at, basis)
	else:
		_winter_fir_bank(world, at, basis)


static func _winter_chalet(world, at: Vector3, basis: Basis) -> void:
	GEO.put(
		world, "box", at, basis, Vector3(-0.30, 0.24, 0.15), Vector3(3.58, 0.48, 2.70), WINTER_STONE
	)
	GEO.put(
		world, "box", at, basis, Vector3(-0.30, 1.35, 0.15), Vector3(3.29, 1.76, 2.35), WINTER_WOOD
	)
	GEO.put(
		world, "roof", at, basis, Vector3(-0.30, 2.66, 0.15), Vector3(3.93, 1.36, 3.00), WINTER_BLUE
	)
	GEO.put(
		world, "roof", at, basis, Vector3(-0.30, 2.81, 0.15), Vector3(4.03, 1.36, 3.08), WINTER_SNOW
	)
	GEO.put(
		world, "box", at, basis, Vector3(0.68, 3.16, 0.79), Vector3(0.39, 0.99, 0.43), WINTER_STONE
	)
	GEO.put(
		world, "box", at, basis, Vector3(0.68, 3.71, 0.79), Vector3(0.54, 0.13, 0.58), WINTER_SNOW
	)
	GEO.put(
		world,
		"box",
		at,
		basis,
		Vector3(-0.30, 1.08, -1.06),
		Vector3(0.53, 1.13, 0.10),
		WINTER_TIMBER
	)
	GEO.put(
		world,
		"box",
		at,
		basis,
		Vector3(-0.30, 1.67, -1.12),
		Vector3(0.71, 0.10, 0.12),
		Color("bd925a")
	)
	GEO.put(
		world, "box", at, basis, Vector3(-0.30, 0.47, -1.42), Vector3(0.90, 0.16, 0.69), WINTER_SNOW
	)
	for side in [-1.0, 1.0]:
		var window_x: float = -0.30 + side * 1.00
		GEO.put(
			world,
			"box",
			at,
			basis,
			Vector3(window_x, 1.53, -1.06),
			Vector3(0.67, 0.73, 0.10),
			Color("bd925a")
		)
		GEO.put(
			world,
			"box",
			at,
			basis,
			Vector3(window_x, 1.53, -1.12),
			Vector3(0.51, 0.57, 0.04),
			WINTER_LIGHT,
			true
		)
		GEO.put(
			world,
			"box",
			at,
			basis,
			Vector3(window_x, 1.09, -1.20),
			Vector3(0.79, 0.15, 0.31),
			WINTER_BLUE
		)
		GEO.put(
			world,
			"box",
			at,
			basis,
			Vector3(window_x, 1.20, -1.22),
			Vector3(0.83, 0.09, 0.33),
			WINTER_SNOW
		)
		GEO.put(
			world,
			"box",
			at,
			basis,
			Vector3(-0.30 + side * 1.56, 1.36, -1.06),
			Vector3(0.13, 1.75, 0.12),
			WINTER_TIMBER
		)
	GEO.put(
		world,
		"box",
		at,
		basis,
		Vector3(-0.30, 2.11, -1.07),
		Vector3(3.23, 0.12, 0.12),
		WINTER_TIMBER
	)
	GEO.put(
		world,
		"box",
		at,
		basis,
		Vector3(-0.30, 2.60, -1.17),
		Vector3(0.11, 0.91, 0.11),
		WINTER_TIMBER
	)
	GEO.put(
		world, "box", at, basis, Vector3(-0.30, 2.61, -1.18), Vector3(0.48, 0.46, 0.09), WINTER_BLUE
	)
	GEO.put(
		world,
		"box",
		at,
		basis,
		Vector3(-0.30, 2.61, -1.24),
		Vector3(0.31, 0.31, 0.04),
		WINTER_LIGHT,
		true
	)
	_snow_fir(world, at, basis, Vector3(2.38, 0.04, 0.72), 0.69, 1.0)
	GEO.put(
		world, "ball", at, basis, Vector3(-2.29, 0.20, 0.60), Vector3(0.51, 0.24, 0.72), WINTER_SNOW
	)
	if not world.low_detail:
		for side in [-1.0, 1.0]:
			var window_x: float = -0.30 + side * 1.00
			GEO.put(
				world,
				"box",
				at,
				basis,
				Vector3(window_x, 1.53, -1.15),
				Vector3(0.035, 0.57, 0.025),
				WINTER_TIMBER
			)
			GEO.put(
				world,
				"box",
				at,
				basis,
				Vector3(window_x, 1.53, -1.15),
				Vector3(0.51, 0.035, 0.025),
				WINTER_TIMBER
			)
			GEO.put(
				world,
				"box",
				at,
				basis,
				Vector3(window_x + side * 0.43, 1.53, -1.07),
				Vector3(0.17, 0.67, 0.08),
				WINTER_BLUE
			)
		GEO.put(
			world,
			"cylinder",
			at,
			basis,
			Vector3(-2.17, 0.96, -0.71),
			Vector3(0.055, 1.52, 0.055),
			Color("a88853")
		)
		GEO.put(
			world,
			"ball",
			at,
			basis,
			Vector3(-2.17, 1.82, -0.71),
			Vector3(0.17, 0.22, 0.17),
			WINTER_LIGHT,
			true
		)
		GEO.put(
			world,
			"cone",
			at,
			basis,
			Vector3(-2.17, 2.06, -0.71),
			Vector3(0.25, 0.19, 0.25),
			WINTER_BLUE
		)
		for row in range(3):
			GEO.put(
				world,
				"box",
				at,
				basis,
				Vector3(1.36, 0.81 + row * 0.39, 0.15),
				Vector3(0.06, 0.045, 2.26),
				Color("8a6953")
			)


static func _winter_lantern(world, at: Vector3, basis: Basis) -> void:
	GEO.put(world, "rock", at, basis, Vector3(0, 0.14, 0), Vector3(0.54, 0.28, 0.46), WINTER_STONE)
	GEO.put(
		world, "ball", at, basis, Vector3(-0.06, 0.27, 0), Vector3(0.67, 0.14, 0.55), WINTER_SNOW
	)
	GEO.put(world, "box", at, basis, Vector3(0, 1.30, 0), Vector3(0.15, 2.09, 0.15), WINTER_TIMBER)
	GEO.beam(
		world, at, basis, Vector3(-0.61, 2.27, 0), Vector3(0.62, 2.27, 0), 0.05, Color("b6955e")
	)
	GEO.put(
		world, "box", at, basis, Vector3(-0.39, 1.91, 0), Vector3(0.42, 0.61, 0.07), WINTER_BLUE
	)
	GEO.put(
		world,
		"star",
		at,
		basis,
		Vector3(-0.39, 1.95, -0.05),
		Vector3(0.13, 0.13, 0.10),
		Color("d4b46f")
	)
	GEO.put(
		world,
		"cylinder",
		at,
		basis,
		Vector3(0.46, 1.94, 0),
		Vector3(0.19, 0.38, 0.19),
		WINTER_LIGHT,
		true
	)
	GEO.put(
		world, "cone", at, basis, Vector3(0.46, 2.20, 0), Vector3(0.29, 0.18, 0.29), WINTER_BLUE
	)
	GEO.put(
		world, "cone", at, basis, Vector3(0.46, 2.26, 0), Vector3(0.27, 0.16, 0.27), WINTER_SNOW
	)
	if not world.low_detail:
		for side in [-1.0, 1.0]:
			GEO.put(
				world,
				"cylinder",
				at,
				basis,
				Vector3(0.46 + side * 0.14, 1.94, -0.13),
				Vector3(0.025, 0.43, 0.025),
				Color("b6955e")
			)
		GEO.put(
			world,
			"cylinder",
			at,
			basis,
			Vector3(0.46, 1.70, 0),
			Vector3(0.24, 0.08, 0.24),
			WINTER_BLUE
		)


static func _winter_fir_bank(world, at: Vector3, basis: Basis) -> void:
	GEO.put(
		world, "ball", at, basis, Vector3(-0.10, 0.14, 0.04), Vector3(1.03, 0.22, 0.79), WINTER_SNOW
	)
	_snow_fir(world, at, basis, Vector3(-0.31, 0.22, 0.06), 0.64, 0.87)
	GEO.put(
		world,
		"crystal",
		at,
		basis,
		Vector3(0.58, 0.24, -0.25),
		Vector3(0.27, 0.70, 0.25),
		Color("86b6d7"),
		false,
		Quaternion(Vector3.FORWARD, -0.15)
	)
	if not world.low_detail:
		GEO.put(
			world,
			"crystal",
			at,
			basis,
			Vector3(0.77, 0.22, 0.25),
			Vector3(0.20, 0.45, 0.18),
			Color("accbdf"),
			false,
			Quaternion(Vector3.RIGHT, 0.15)
		)
		GEO.put(
			world,
			"rock",
			at,
			basis,
			Vector3(0.65, 0.24, 0.30),
			Vector3(0.24, 0.18, 0.22),
			WINTER_STONE
		)
		GEO.put(
			world,
			"ball",
			at,
			basis,
			Vector3(0.65, 0.37, 0.30),
			Vector3(0.28, 0.10, 0.24),
			WINTER_SNOW
		)


static func _snow_fir(
	world, at: Vector3, basis: Basis, center: Vector3, radius: float, height_scale: float
) -> void:
	GEO.put(
		world,
		"cylinder",
		at,
		basis,
		center + Vector3(0, 0.40 * height_scale, 0),
		Vector3(0.09, 0.80 * height_scale, 0.09),
		WINTER_TIMBER
	)
	for tier in range(3):
		var tier_radius: float = radius * (1.0 - float(tier) * 0.27)
		var tier_y: float = (0.91 + float(tier) * 0.48) * height_scale
		GEO.put(
			world,
			"cone",
			at,
			basis,
			center + Vector3(0, tier_y, 0),
			Vector3(tier_radius, 0.91 * height_scale, tier_radius),
			WINTER_FIR
		)
		if tier != 1 or not world.low_detail:
			GEO.put(
				world,
				"cone",
				at,
				basis,
				center + Vector3(0, tier_y + 0.11 * height_scale, 0),
				Vector3(tier_radius * 0.93, 0.83 * height_scale, tier_radius * 0.93),
				WINTER_SNOW
			)
