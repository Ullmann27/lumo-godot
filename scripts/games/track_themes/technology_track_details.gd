extends RefCounted
## Deterministic roadside assemblies. Geometry is submitted to the world's prop batches.

const GEO = preload("res://scripts/games/track_themes/track_theme_geometry.gd")

const PEARL = Color("#edf2fa")
const NAVY = Color("#152b52")
const GOLD = Color("#d6ab58")
const GLASS = Color("#397db4")
const CYAN = Color("#6ddcec")
const VIOLET = Color("#8c71c1")
const GREEN = Color("#70a66c")
const PINK = Color("#cc8fbb")
const BASALT = Color("#242a3d")
const OBSIDIAN = Color("#171c2d")
const ASH = Color("#4c4b61")
const EMBER = Color("#ee9548")


static func build(world, at: Vector3, basis: Basis, large: bool, marker: bool) -> bool:
	match String(world.track_id):
		"holo_city":
			if large:
				_holo_landmark(world, at, basis)
			elif marker:
				_holo_marker(world, at, basis)
			else:
				_holo_garden(world, at, basis)
		"volcano_night":
			if large:
				_volcano_landmark(world, at, basis)
			elif marker:
				_volcano_marker(world, at, basis)
			else:
				_volcano_outcrop(world, at, basis)
		"galaxy_ringway":
			if large:
				_galaxy_landmark(world, at, basis)
			elif marker:
				_galaxy_marker(world, at, basis)
			else:
				_galaxy_garden(world, at, basis)
		"learning_lab":
			if large:
				_lab_landmark(world, at, basis)
			elif marker:
				_lab_marker(world, at, basis)
			else:
				_lab_garden(world, at, basis)
		_:
			return false
	return true


static func _holo_landmark(world, at: Vector3, basis: Basis) -> void:
	GEO.put(world, "box", at, basis, Vector3(0, 0.16, 0), Vector3(6.2, 0.32, 4.6), PEARL)
	GEO.put(world, "box", at, basis, Vector3(0, 0.36, 0), Vector3(6.3, 0.08, 4.7), GOLD)
	GEO.put(
		world, "glass_tower", at, basis, Vector3(-0.8, 2.18, 0.65), Vector3(3.3, 3.5, 2.1), NAVY
	)
	GEO.put(
		world, "glass_tower", at, basis, Vector3(1.75, 1.66, 0.8), Vector3(1.5, 2.45, 1.8), GLASS
	)
	GEO.put(world, "box", at, basis, Vector3(-0.8, 3.95, 0.65), Vector3(3.5, 0.14, 2.3), GOLD)
	GEO.put(world, "box", at, basis, Vector3(1.75, 2.94, 0.8), Vector3(1.7, 0.12, 2.0), PEARL)
	for x in [-2.38, 0.78]:
		GEO.put(world, "box", at, basis, Vector3(x, 2.18, -0.43), Vector3(0.1, 3.4, 0.1), GOLD)
	for y in [1.18, 2.17, 3.15]:
		GEO.put(world, "box", at, basis, Vector3(-0.8, y, -0.43), Vector3(2.9, 0.12, 0.09), GLASS)
	GEO.put(world, "box", at, basis, Vector3(-1.55, 1.01, -0.48), Vector3(0.72, 1.12, 0.12), CYAN)
	GEO.put(
		world,
		"box",
		at,
		basis,
		Vector3(0.0, 1.92, -1.25),
		Vector3(4.3, 0.16, 1.5),
		GLASS,
		false,
		Quaternion(Vector3.RIGHT, -0.17)
	)
	for x in [-1.9, 1.9]:
		GEO.beam(world, at, basis, Vector3(x, 0.42, -1.5), Vector3(x, 1.86, -1.5), 0.06, GOLD)
	GEO.put(world, "box", at, basis, Vector3(-0.75, 4.12, 0.73), Vector3(2.45, 0.24, 1.42), PEARL)
	GEO.put(world, "box", at, basis, Vector3(-0.75, 4.27, 0.73), Vector3(2.26, 0.09, 1.24), GREEN)
	GEO.put(world, "cylinder", at, basis, Vector3(-1.3, 4.55, 0.75), Vector3(0.1, 0.6, 0.1), GOLD)
	GEO.put(world, "crown", at, basis, Vector3(-1.3, 4.98, 0.75), Vector3(0.67, 0.52, 0.62), PINK)
	GEO.put(world, "crown", at, basis, Vector3(0.0, 4.48, 0.8), Vector3(0.48, 0.3, 0.45), GREEN)
	GEO.put(world, "box", at, basis, Vector3(0, 0.45, -2.12), Vector3(4.8, 0.05, 0.08), CYAN, true)
	if not world.low_detail:
		for x in [-1.86, -0.83, 0.2]:
			for y in [1.68, 2.67, 3.57]:
				GEO.put(
					world, "box", at, basis, Vector3(x, y, -0.44), Vector3(0.39, 0.31, 0.07), GOLD
				)
		for x in [-1.45, -0.48, 0.49, 1.46]:
			GEO.put(
				world,
				"box",
				at,
				basis,
				Vector3(x, 2.02, -1.25),
				Vector3(0.04, 0.03, 1.36),
				PEARL,
				false,
				Quaternion(Vector3.RIGHT, -0.17)
			)
		GEO.put(
			world,
			"box",
			at,
			basis,
			Vector3(1.75, 2.29, -0.13),
			Vector3(1.13, 0.08, 0.05),
			VIOLET,
			true
		)


static func _holo_marker(world, at: Vector3, basis: Basis) -> void:
	GEO.put(world, "box", at, basis, Vector3(0, 0.12, 0), Vector3(1.9, 0.24, 1.5), PEARL)
	GEO.put(world, "box", at, basis, Vector3(0, 0.29, 0), Vector3(1.6, 0.1, 1.2), GOLD)
	GEO.put(
		world, "glass_tower", at, basis, Vector3(-0.3, 1.35, 0), Vector3(0.74, 2.05, 0.64), NAVY
	)
	GEO.put(
		world, "glass_tower", at, basis, Vector3(0.5, 0.94, 0.12), Vector3(0.46, 1.24, 0.5), GLASS
	)
	GEO.put(world, "box", at, basis, Vector3(-0.3, 1.48, -0.34), Vector3(0.5, 1.05, 0.06), GLASS)
	GEO.put(world, "box", at, basis, Vector3(-0.3, 2.42, 0), Vector3(0.91, 0.12, 0.81), GOLD)
	GEO.put(world, "ball", at, basis, Vector3(-0.3, 2.73, 0), Vector3(0.22, 0.22, 0.22), CYAN, true)
	GEO.put(
		world, "box", at, basis, Vector3(-0.3, 1.3, -0.39), Vector3(0.31, 0.05, 0.04), CYAN, true
	)
	if not world.low_detail:
		for y in [0.82, 1.08, 1.8]:
			GEO.put(
				world, "box", at, basis, Vector3(-0.3, y, -0.39), Vector3(0.3, 0.04, 0.04), GOLD
			)
		GEO.put(world, "box", at, basis, Vector3(0.5, 1.6, 0.12), Vector3(0.56, 0.1, 0.6), VIOLET)


static func _holo_garden(world, at: Vector3, basis: Basis) -> void:
	GEO.put(world, "box", at, basis, Vector3(0, 0.15, 0), Vector3(2.1, 0.3, 1.7), PEARL)
	GEO.put(world, "box", at, basis, Vector3(0, 0.33, 0), Vector3(1.95, 0.08, 1.55), GOLD)
	GEO.put(world, "box", at, basis, Vector3(-0.46, 0.41, 0.18), Vector3(0.85, 0.08, 1.05), GREEN)
	GEO.put(
		world, "cylinder", at, basis, Vector3(-0.46, 0.73, 0.2), Vector3(0.07, 0.64, 0.07), NAVY
	)
	GEO.put(world, "crown", at, basis, Vector3(-0.46, 1.14, 0.2), Vector3(0.5, 0.46, 0.46), PINK)
	GEO.beam(world, at, basis, Vector3(0.48, 0.4, 0.08), Vector3(0.48, 1.05, 0.08), 0.07, GOLD)
	GEO.put(
		world,
		"box",
		at,
		basis,
		Vector3(0.48, 1.09, 0.08),
		Vector3(0.88, 0.1, 1.09),
		NAVY,
		false,
		Quaternion(Vector3.RIGHT, -0.28)
	)
	GEO.put(
		world,
		"box",
		at,
		basis,
		Vector3(0.48, 1.15, 0.08),
		Vector3(0.74, 0.03, 0.95),
		GLASS,
		false,
		Quaternion(Vector3.RIGHT, -0.28)
	)
	if not world.low_detail:
		GEO.put(
			world,
			"box",
			at,
			basis,
			Vector3(0.48, 1.18, 0.08),
			Vector3(0.03, 0.02, 0.91),
			CYAN,
			false,
			Quaternion(Vector3.RIGHT, -0.28)
		)
		GEO.put(
			world, "crown", at, basis, Vector3(-0.78, 0.57, -0.39), Vector3(0.22, 0.16, 0.2), GREEN
		)
		GEO.put(
			world, "box", at, basis, Vector3(0, 0.21, -0.87), Vector3(0.82, 0.04, 0.04), CYAN, true
		)


static func _volcano_landmark(world, at: Vector3, basis: Basis) -> void:
	GEO.put(world, "box", at, basis, Vector3(0, 0.19, 0), Vector3(6.1, 0.38, 4.5), OBSIDIAN)
	GEO.put(world, "box", at, basis, Vector3(0, 0.43, 0.15), Vector3(5.45, 0.1, 3.8), ASH)
	GEO.put(world, "box", at, basis, Vector3(0, 1.49, 0.7), Vector3(2.65, 2.05, 1.8), BASALT)
	GEO.put(world, "roof", at, basis, Vector3(0, 2.77, 0.7), Vector3(3.2, 0.65, 2.15), OBSIDIAN)
	GEO.put(world, "box", at, basis, Vector3(0, 1.23, -0.23), Vector3(1.17, 1.5, 0.12), OBSIDIAN)
	GEO.put(
		world, "box", at, basis, Vector3(0, 1.27, -0.31), Vector3(0.18, 1.13, 0.04), EMBER, true
	)
	for x in [-1.65, 1.65]:
		GEO.put(world, "box", at, basis, Vector3(x, 1.21, 0.7), Vector3(0.58, 1.52, 1.92), ASH)
		GEO.put(world, "roof", at, basis, Vector3(x, 2.12, 0.7), Vector3(0.8, 0.38, 2.1), BASALT)
		GEO.put(world, "box", at, basis, Vector3(x, 1.22, -0.3), Vector3(0.11, 1.35, 0.05), GOLD)
	GEO.put(
		world, "crystal", at, basis, Vector3(-2.25, 0.44, 1.0), Vector3(0.75, 1.73, 0.73), BASALT
	)
	GEO.put(
		world, "crystal", at, basis, Vector3(2.25, 0.44, 0.94), Vector3(0.66, 1.13, 0.7), OBSIDIAN
	)
	GEO.put(world, "box", at, basis, Vector3(0, 0.6, -0.93), Vector3(2.55, 0.25, 0.68), BASALT)
	GEO.put(world, "box", at, basis, Vector3(0, 0.48, -1.5), Vector3(3.08, 0.16, 0.58), ASH)
	GEO.put(world, "box", at, basis, Vector3(0, 0.4, -1.93), Vector3(3.58, 0.08, 0.33), BASALT)
	for x in [-2.35, 2.35]:
		GEO.put(
			world, "rock", at, basis, Vector3(x, 0.63, -1.34), Vector3(0.48, 0.48, 0.46), OBSIDIAN
		)
		GEO.put(
			world, "crystal", at, basis, Vector3(x, 0.65, -1.34), Vector3(0.18, 0.43, 0.18), CYAN
		)
	GEO.beam(world, at, basis, Vector3(-0.57, 2.53, -0.24), Vector3(0.57, 2.53, -0.24), 0.04, GOLD)
	if not world.low_detail:
		for x in [-0.81, 0.81]:
			GEO.put(
				world, "box", at, basis, Vector3(x, 1.72, -0.23), Vector3(0.19, 0.55, 0.05), EMBER
			)
		for x in [-2.73, 2.73]:
			GEO.beam(world, at, basis, Vector3(x, 0.46, -0.5), Vector3(x, 1.18, -0.5), 0.04, GOLD)
			GEO.beam(world, at, basis, Vector3(x, 0.46, 0.43), Vector3(x, 1.18, 0.43), 0.04, GOLD)
			GEO.beam(world, at, basis, Vector3(x, 1.18, -0.5), Vector3(x, 1.18, 0.43), 0.035, CYAN)
		GEO.beam(
			world,
			at,
			basis,
			Vector3(-2.0, 0.49, 0.14),
			Vector3(-2.37, 0.49, 0.43),
			0.025,
			EMBER,
			true
		)
		GEO.beam(
			world,
			at,
			basis,
			Vector3(1.9, 0.49, 0.27),
			Vector3(2.14, 0.49, 0.58),
			0.025,
			EMBER,
			true
		)


static func _volcano_marker(world, at: Vector3, basis: Basis) -> void:
	GEO.put(world, "box", at, basis, Vector3(0, 0.14, 0), Vector3(1.8, 0.28, 1.5), OBSIDIAN)
	GEO.put(world, "box", at, basis, Vector3(0, 0.34, 0), Vector3(1.42, 0.12, 1.18), ASH)
	GEO.put(world, "crystal", at, basis, Vector3(0, 0.39, 0.12), Vector3(0.64, 1.4, 0.59), BASALT)
	GEO.put(world, "box", at, basis, Vector3(0, 1.32, -0.3), Vector3(0.13, 1.37, 0.06), GOLD)
	GEO.put(
		world, "box", at, basis, Vector3(0, 1.32, -0.35), Vector3(0.055, 0.7, 0.03), EMBER, true
	)
	GEO.put(world, "rock", at, basis, Vector3(-0.52, 0.48, -0.12), Vector3(0.28, 0.34, 0.3), ASH)
	GEO.put(
		world, "crystal", at, basis, Vector3(0.55, 0.38, -0.05), Vector3(0.19, 0.35, 0.18), CYAN
	)
	if not world.low_detail:
		GEO.put(world, "box", at, basis, Vector3(0, 0.68, -0.35), Vector3(0.39, 0.06, 0.05), GOLD)
		GEO.put(world, "box", at, basis, Vector3(0, 1.98, -0.3), Vector3(0.33, 0.06, 0.05), GOLD)
		GEO.put(
			world, "rock", at, basis, Vector3(0.49, 0.34, 0.5), Vector3(0.29, 0.22, 0.25), OBSIDIAN
		)


static func _volcano_outcrop(world, at: Vector3, basis: Basis) -> void:
	GEO.put(world, "rock", at, basis, Vector3(0, 0.32, 0), Vector3(0.93, 0.58, 0.75), OBSIDIAN)
	GEO.put(world, "crystal", at, basis, Vector3(-0.37, 0.42, 0.12), Vector3(0.41, 0.88, 0.4), ASH)
	GEO.put(world, "crystal", at, basis, Vector3(0.3, 0.4, 0.29), Vector3(0.37, 0.67, 0.34), BASALT)
	GEO.put(world, "crystal", at, basis, Vector3(0.39, 0.39, -0.36), Vector3(0.22, 0.49, 0.2), CYAN)
	GEO.put(
		world, "crystal", at, basis, Vector3(-0.22, 0.38, -0.43), Vector3(0.14, 0.31, 0.14), GLASS
	)
	GEO.beam(
		world, at, basis, Vector3(-0.15, 0.52, -0.6), Vector3(0.22, 0.63, -0.48), 0.025, EMBER, true
	)
	if not world.low_detail:
		GEO.put(
			world, "rock", at, basis, Vector3(-0.78, 0.22, -0.24), Vector3(0.24, 0.28, 0.31), ASH
		)
		GEO.put(
			world, "rock", at, basis, Vector3(0.73, 0.24, 0.03), Vector3(0.28, 0.25, 0.28), BASALT
		)
		GEO.put(
			world,
			"crystal",
			at,
			basis,
			Vector3(0.02, 0.5, -0.37),
			Vector3(0.12, 0.24, 0.12),
			VIOLET
		)


static func _galaxy_landmark(world, at: Vector3, basis: Basis) -> void:
	GEO.put(world, "cylinder", at, basis, Vector3(0, 0.18, 0), Vector3(2.58, 0.36, 2.58), NAVY)
	GEO.put(world, "cylinder", at, basis, Vector3(0, 0.41, 0), Vector3(2.46, 0.1, 2.46), GOLD)
	GEO.put(world, "cylinder", at, basis, Vector3(0, 0.56, 0), Vector3(2.29, 0.2, 2.29), PEARL)
	GEO.put(world, "cylinder", at, basis, Vector3(0.35, 1.0, 0.55), Vector3(1.21, 0.7, 1.21), NAVY)
	GEO.put(world, "ball", at, basis, Vector3(0.35, 1.36, 0.55), Vector3(1.2, 0.75, 1.2), GLASS)
	GEO.put(world, "torus", at, basis, Vector3(0.35, 1.32, 0.55), Vector3(2.5, 0.16, 2.5), GOLD)
	GEO.put(world, "box", at, basis, Vector3(-0.8, 0.94, -0.86), Vector3(0.72, 0.58, 0.7), NAVY)
	GEO.put(
		world, "cylinder", at, basis, Vector3(-0.8, 1.49, -0.86), Vector3(0.17, 0.64, 0.17), GOLD
	)
	GEO.beam(world, at, basis, Vector3(-0.65, 1.83, -0.64), Vector3(-1.22, 2.46, -1.39), 0.33, NAVY)
	GEO.beam(world, at, basis, Vector3(-1.17, 2.4, -1.33), Vector3(-1.27, 2.51, -1.46), 0.4, GOLD)
	GEO.beam(world, at, basis, Vector3(-1.27, 2.51, -1.46), Vector3(-1.3, 2.54, -1.5), 0.3, GLASS)
	GEO.put(
		world, "cylinder", at, basis, Vector3(1.66, 1.42, -0.83), Vector3(0.07, 1.5, 0.07), GOLD
	)
	GEO.put(
		world, "cylinder", at, basis, Vector3(1.66, 2.21, -0.83), Vector3(0.57, 0.12, 0.57), NAVY
	)
	GEO.put(
		world, "ball", at, basis, Vector3(1.66, 2.42, -0.83), Vector3(0.2, 0.2, 0.2), CYAN, true
	)
	GEO.put(world, "box", at, basis, Vector3(0, 0.35, -2.67), Vector3(1.7, 0.2, 0.46), PEARL)
	GEO.put(world, "box", at, basis, Vector3(0, 0.5, -2.3), Vector3(1.4, 0.1, 0.38), GOLD)
	GEO.put(world, "box", at, basis, Vector3(0.35, 1.83, 0.55), Vector3(0.08, 0.08, 1.66), GOLD)
	if not world.low_detail:
		for angle in [0.0, 0.7, 1.4, 2.1, 2.8]:
			var foot := Vector3(sin(angle) * 2.1, 0.67, cos(angle) * 2.1)
			var top := foot + Vector3(0, 0.7, 0)
			GEO.beam(world, at, basis, foot, top, 0.035, GOLD)
		GEO.beam(world, at, basis, Vector3(0, 1.37, 2.1), Vector3(1.35, 1.37, 1.61), 0.025, CYAN)
		GEO.beam(
			world, at, basis, Vector3(1.35, 1.37, 1.61), Vector3(2.07, 1.37, 0.36), 0.025, CYAN
		)
		GEO.put(
			world,
			"box",
			at,
			basis,
			Vector3(-1.55, 0.85, 1.25),
			Vector3(0.76, 0.12, 0.72),
			NAVY,
			false,
			Quaternion(Vector3.RIGHT, 0.24)
		)
		GEO.put(
			world,
			"box",
			at,
			basis,
			Vector3(-1.55, 0.92, 1.25),
			Vector3(0.64, 0.04, 0.61),
			GLASS,
			false,
			Quaternion(Vector3.RIGHT, 0.24)
		)


static func _galaxy_marker(world, at: Vector3, basis: Basis) -> void:
	GEO.put(world, "cylinder", at, basis, Vector3(0, 0.15, 0), Vector3(0.95, 0.3, 0.95), NAVY)
	GEO.put(world, "cylinder", at, basis, Vector3(0, 0.34, 0), Vector3(0.82, 0.08, 0.82), GOLD)
	GEO.put(world, "cylinder", at, basis, Vector3(0, 1.17, 0), Vector3(0.16, 1.6, 0.16), PEARL)
	GEO.put(world, "cylinder", at, basis, Vector3(0, 1.91, 0), Vector3(0.66, 0.12, 0.66), NAVY)
	GEO.put(world, "torus", at, basis, Vector3(0, 1.94, 0), Vector3(1.43, 0.18, 1.43), GOLD)
	GEO.put(world, "ball", at, basis, Vector3(0, 2.25, 0), Vector3(0.24, 0.24, 0.24), CYAN, true)
	GEO.put(
		world,
		"box",
		at,
		basis,
		Vector3(-0.66, 1.27, 0),
		Vector3(0.81, 0.07, 0.63),
		GLASS,
		false,
		Quaternion(Vector3.FORWARD, -0.2)
	)
	GEO.put(
		world,
		"box",
		at,
		basis,
		Vector3(0.66, 1.27, 0),
		Vector3(0.81, 0.07, 0.63),
		GLASS,
		false,
		Quaternion(Vector3.FORWARD, 0.2)
	)
	if not world.low_detail:
		GEO.beam(world, at, basis, Vector3(-1.02, 1.2, 0), Vector3(1.02, 1.2, 0), 0.025, GOLD)
		GEO.put(world, "box", at, basis, Vector3(0, 0.87, -0.17), Vector3(0.12, 0.3, 0.04), VIOLET)


static func _galaxy_garden(world, at: Vector3, basis: Basis) -> void:
	GEO.put(world, "rock", at, basis, Vector3(0, 0.36, 0), Vector3(0.99, 0.64, 0.91), ASH)
	GEO.put(world, "cylinder", at, basis, Vector3(0, 0.82, 0.04), Vector3(0.68, 0.13, 0.64), GOLD)
	GEO.put(world, "cylinder", at, basis, Vector3(0, 0.91, 0.04), Vector3(0.6, 0.07, 0.56), GREEN)
	GEO.put(world, "ball", at, basis, Vector3(0.07, 1.2, 0.12), Vector3(0.53, 0.35, 0.48), GLASS)
	GEO.put(world, "torus", at, basis, Vector3(0.07, 1.04, 0.12), Vector3(1.14, 0.13, 1.04), PEARL)
	GEO.put(world, "crystal", at, basis, Vector3(-0.66, 0.5, -0.26), Vector3(0.18, 0.4, 0.16), CYAN)
	GEO.put(world, "crown", at, basis, Vector3(0.54, 0.97, -0.38), Vector3(0.24, 0.19, 0.23), PINK)
	if not world.low_detail:
		GEO.beam(
			world,
			at,
			basis,
			Vector3(-0.45, 0.37, -0.67),
			Vector3(-0.12, 0.61, -0.64),
			0.025,
			EMBER,
			true
		)
		GEO.put(
			world, "rock", at, basis, Vector3(0.84, 0.2, -0.16), Vector3(0.18, 0.21, 0.22), NAVY
		)
		GEO.put(
			world,
			"crystal",
			at,
			basis,
			Vector3(-0.53, 0.49, -0.51),
			Vector3(0.1, 0.24, 0.11),
			VIOLET
		)


static func _lab_landmark(world, at: Vector3, basis: Basis) -> void:
	GEO.put(world, "box", at, basis, Vector3(0, 0.18, 0), Vector3(6.2, 0.36, 4.6), PEARL)
	GEO.put(world, "box", at, basis, Vector3(0, 0.41, 0), Vector3(6.3, 0.1, 4.7), GOLD)
	GEO.put(world, "box", at, basis, Vector3(-1.67, 1.46, 0.55), Vector3(1.94, 2.0, 2.45), PEARL)
	GEO.put(world, "box", at, basis, Vector3(1.67, 1.46, 0.55), Vector3(1.94, 2.0, 2.45), PEARL)
	GEO.put(world, "box", at, basis, Vector3(0, 1.24, 1.38), Vector3(1.45, 1.55, 0.3), NAVY)
	GEO.put(world, "box", at, basis, Vector3(-1.67, 2.51, 0.55), Vector3(2.12, 0.12, 2.63), NAVY)
	GEO.put(world, "box", at, basis, Vector3(1.67, 2.51, 0.55), Vector3(2.12, 0.12, 2.63), NAVY)
	GEO.put(world, "roof", at, basis, Vector3(0, 2.66, 0.56), Vector3(2.0, 0.64, 2.74), GLASS)
	for x in [-0.84, 0.84]:
		GEO.beam(world, at, basis, Vector3(x, 0.47, -0.76), Vector3(x, 2.43, -0.76), 0.055, GOLD)
	GEO.put(world, "cylinder", at, basis, Vector3(0, 0.65, 0.06), Vector3(0.46, 0.37, 0.46), NAVY)
	GEO.put(world, "crystal", at, basis, Vector3(0, 0.84, 0.06), Vector3(0.34, 0.6, 0.34), CYAN)
	GEO.put(world, "ball", at, basis, Vector3(0, 1.89, 0.06), Vector3(0.12, 0.12, 0.12), PINK, true)
	for x in [-1.67, 1.67]:
		GEO.put(world, "box", at, basis, Vector3(x, 1.52, -0.71), Vector3(1.38, 0.81, 0.08), GLASS)
		GEO.put(world, "box", at, basis, Vector3(x, 2.11, -0.72), Vector3(1.54, 0.07, 0.08), GOLD)
	GEO.put(world, "box", at, basis, Vector3(0, 0.53, -1.59), Vector3(2.06, 0.14, 0.87), NAVY)
	GEO.put(world, "box", at, basis, Vector3(0, 0.62, -1.98), Vector3(1.43, 0.04, 0.06), CYAN, true)
	var atoms := [Vector3(-1.92, 3.2, 0.35), Vector3(-1.18, 3.67, 0.54), Vector3(-0.88, 3.08, 0.11)]
	GEO.beam(world, at, basis, atoms[0], atoms[1], 0.055, GOLD)
	GEO.beam(world, at, basis, atoms[1], atoms[2], 0.055, GOLD)
	GEO.put(world, "ball", at, basis, atoms[0], Vector3(0.25, 0.25, 0.25), CYAN)
	GEO.put(world, "ball", at, basis, atoms[1], Vector3(0.31, 0.31, 0.31), VIOLET)
	GEO.put(world, "ball", at, basis, atoms[2], Vector3(0.21, 0.21, 0.21), EMBER)
	if not world.low_detail:
		GEO.beam(world, at, basis, atoms[0], Vector3(-2.12, 2.6, 0.52), 0.04, NAVY)
		GEO.beam(world, at, basis, atoms[2], Vector3(-1.1, 2.6, 0.25), 0.04, NAVY)
		for x in [-1.96, -1.38, 1.38, 1.96]:
			GEO.put(
				world, "box", at, basis, Vector3(x, 1.52, -0.77), Vector3(0.045, 0.72, 0.035), PEARL
			)
		GEO.put(world, "box", at, basis, Vector3(1.7, 2.7, 0.5), Vector3(1.23, 0.23, 1.38), GOLD)
		GEO.put(world, "box", at, basis, Vector3(1.7, 2.86, 0.5), Vector3(1.07, 0.07, 1.21), GREEN)
		GEO.put(
			world, "crown", at, basis, Vector3(1.7, 3.05, 0.5), Vector3(0.43, 0.26, 0.42), VIOLET
		)


static func _lab_marker(world, at: Vector3, basis: Basis) -> void:
	GEO.put(world, "cylinder", at, basis, Vector3(0, 0.12, 0), Vector3(0.95, 0.24, 0.87), GOLD)
	GEO.put(world, "cylinder", at, basis, Vector3(0, 0.27, 0), Vector3(0.82, 0.07, 0.74), NAVY)
	for x in [-0.29, 0.29]:
		GEO.put(world, "box", at, basis, Vector3(x, 0.41, -0.02), Vector3(0.35, 0.21, 0.48), NAVY)
		GEO.beam(world, at, basis, Vector3(x, 0.51, 0), Vector3(x, 0.72, 0), 0.09, GOLD)
	GEO.put(world, "ball", at, basis, Vector3(0, 1.0, 0), Vector3(0.48, 0.49, 0.36), PEARL)
	GEO.put(world, "ball", at, basis, Vector3(0, 1.68, 0), Vector3(0.54, 0.41, 0.39), PEARL)
	GEO.put(world, "box", at, basis, Vector3(0, 1.68, -0.36), Vector3(0.72, 0.28, 0.11), NAVY)
	for x in [-0.19, 0.19]:
		GEO.put(
			world,
			"ball",
			at,
			basis,
			Vector3(x, 1.7, -0.43),
			Vector3(0.065, 0.065, 0.04),
			CYAN,
			true
		)
	GEO.beam(world, at, basis, Vector3(0.4, 1.14, 0), Vector3(0.78, 1.47, -0.05), 0.085, NAVY)
	GEO.put(world, "ball", at, basis, Vector3(0.8, 1.49, -0.05), Vector3(0.13, 0.13, 0.13), PEARL)
	GEO.beam(world, at, basis, Vector3(-0.4, 1.14, 0), Vector3(-0.66, 0.9, -0.08), 0.085, NAVY)
	if not world.low_detail:
		GEO.put(
			world, "ball", at, basis, Vector3(-0.67, 0.88, -0.08), Vector3(0.12, 0.12, 0.12), PEARL
		)
		GEO.beam(world, at, basis, Vector3(0, 2.04, 0), Vector3(0, 2.22, 0), 0.03, GOLD)
		GEO.put(world, "ball", at, basis, Vector3(0, 2.25, 0), Vector3(0.075, 0.075, 0.075), VIOLET)
		GEO.put(world, "box", at, basis, Vector3(0, 1.02, -0.36), Vector3(0.22, 0.15, 0.04), GLASS)


static func _lab_garden(world, at: Vector3, basis: Basis) -> void:
	GEO.put(world, "box", at, basis, Vector3(0, 0.15, 0), Vector3(2.1, 0.3, 1.65), PEARL)
	GEO.put(world, "box", at, basis, Vector3(0, 0.34, 0), Vector3(1.95, 0.08, 1.5), GOLD)
	GEO.put(world, "box", at, basis, Vector3(-0.36, 0.43, 0), Vector3(1.02, 0.1, 1.12), GREEN)
	GEO.beam(world, at, basis, Vector3(-0.4, 0.48, 0), Vector3(-0.4, 1.22, 0), 0.04, GREEN)
	GEO.put(world, "crown", at, basis, Vector3(-0.6, 0.93, 0.04), Vector3(0.28, 0.14, 0.19), GREEN)
	GEO.put(world, "crown", at, basis, Vector3(-0.17, 0.82, 0.07), Vector3(0.27, 0.14, 0.18), GREEN)
	GEO.put(world, "ball", at, basis, Vector3(-0.4, 1.3, 0), Vector3(0.21, 0.18, 0.21), VIOLET)
	GEO.put(
		world, "cylinder", at, basis, Vector3(0.55, 0.63, 0.16), Vector3(0.25, 0.48, 0.25), NAVY
	)
	GEO.put(world, "ball", at, basis, Vector3(0.55, 0.98, 0.16), Vector3(0.31, 0.28, 0.31), GLASS)
	GEO.put(world, "torus", at, basis, Vector3(0.55, 0.86, 0.16), Vector3(0.66, 0.12, 0.66), PEARL)
	if not world.low_detail:
		GEO.put(
			world,
			"box",
			at,
			basis,
			Vector3(0.45, 0.65, -0.57),
			Vector3(0.62, 0.41, 0.1),
			NAVY,
			false,
			Quaternion(Vector3.RIGHT, -0.14)
		)
		GEO.put(
			world, "box", at, basis, Vector3(0.45, 0.66, -0.64), Vector3(0.49, 0.26, 0.03), CYAN
		)
		GEO.put(
			world, "ball", at, basis, Vector3(-0.4, 1.32, -0.16), Vector3(0.065, 0.065, 0.065), GOLD
		)
		GEO.put(
			world, "crown", at, basis, Vector3(-0.76, 0.57, -0.4), Vector3(0.16, 0.12, 0.15), PINK
		)
