extends RefCounted
## Original harbor storefronts derived from reference-book pages 16 and 17.
## All pieces reuse the world's opaque spatial MultiMesh batches.
const CREAM := Color("f6edd8")
const BLUE := Color("286baf")
const GOLD := Color("e9b363")
const GLASS := Color("305b77")


static func build(world, at: Vector3, basis: Basis, width: float, depth: float) -> void:
	var front: float = depth * 0.5
	# One continuous striped fabric canopy, with a separate hanging valance.
	var awning_basis := basis * Basis(Vector3.RIGHT, -0.18)
	var stripe_count: int = 7 if world.low_detail else 11
	var span: float = width * 0.88
	for i in range(stripe_count):
		var x: float = (float(i) + 0.5) * span / float(stripe_count) - span * 0.5
		var color: Color = BLUE if i % 2 == 0 else CREAM
		world._prop(
			"box",
			at + basis * Vector3(x, 2.68, front + 0.72),
			Vector3(span / float(stripe_count) + 0.015, 0.10, 1.65),
			color,
			awning_basis
		)
		world._prop(
			"box",
			at + basis * Vector3(x, 2.48, front + 1.52),
			Vector3(span / float(stripe_count) + 0.015, 0.30, 0.10),
			color,
			basis
		)
	# Tall shop door, cornice and original geometric L emblem.
	world._prop(
		"box", at + basis * Vector3(0, 1.05, front + 0.10), Vector3(1.35, 2.10, 0.16), CREAM, basis
	)
	world._prop(
		"box", at + basis * Vector3(0, 1.02, front + 0.20), Vector3(1.08, 1.92, 0.08), GLASS, basis
	)
	world._prop(
		"box",
		at + basis * Vector3(0.35, 1.02, front + 0.27),
		Vector3(0.06, 0.30, 0.06),
		GOLD,
		basis
	)
	var sign := Vector3(width * 0.38, 3.70, front + 0.20)
	world._prop("box", at + basis * sign, Vector3(1.10, 1.25, 0.14), BLUE, basis)
	world._prop(
		"box",
		at + basis * (sign + Vector3(-0.20, 0.05, 0.10)),
		Vector3(0.13, 0.72, 0.06),
		GOLD,
		basis
	)
	world._prop(
		"box",
		at + basis * (sign + Vector3(0.02, -0.25, 0.10)),
		Vector3(0.56, 0.13, 0.06),
		GOLD,
		basis
	)
	if not world.low_detail:
		for side in [-1.0, 1.0]:
			var planter := Vector3(side * width * 0.34, 0.30, front + 0.55)
			world._prop(
				"box", at + basis * planter, Vector3(1.15, 0.60, 0.72), Color("cbb89a"), basis
			)
			world._prop(
				"crown",
				at + basis * (planter + Vector3(0, 0.48, 0)),
				Vector3(0.66, 0.36, 0.40),
				Color("4c9761"),
				basis
			)
			world._prop(
				"ball",
				at + basis * (planter + Vector3(0.18, 0.68, 0.06)),
				Vector3.ONE * 0.22,
				Color("e28bb8"),
				basis
			)
			var lamp := Vector3(side * width * 0.45, 2.15, front + 0.34)
			world._prop("box", at + basis * lamp, Vector3(0.28, 0.46, 0.30), GOLD, basis)
			world._prop(
				"box",
				at + basis * (lamp + Vector3(0, 0, 0.17)),
				Vector3(0.17, 0.30, 0.06),
				Color("fff1c2"),
				basis,
				true
			)
