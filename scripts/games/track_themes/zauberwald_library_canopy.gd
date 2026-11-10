extends RefCounted
## Reference p18: layered tree-library crown, visible roots and warm lanterns.
## Bounded roadside scenery. It does not create a tunnel, collision or reward.

const GEO = preload("res://scripts/games/track_themes/track_theme_geometry.gd")
const BARK = Color("#553725")
const WOOD = Color("#956444")
const BRASS = Color("#cba75c")
const LIGHT = Color("#ffe2a0")
const FOREST = Color("#245e49")
const LEAF = Color("#438b59")
const MOSS = Color("#507742")


static func build(world, at: Vector3, basis: Basis) -> void:
	# The same 4.3 m placement envelope also contains every transformed mesh AABB.
	GEO.put(
		world, "cylinder", at, basis, Vector3(1.05, 3.35, 0.60), Vector3(0.66, 6.10, 0.62), BARK
	)
	for tip: Vector3 in [
		Vector3(-1.40, 5.50, 0.60), Vector3(1.70, 6.00, 0.50), Vector3(0.40, 6.80, 0.55)
	]:
		GEO.beam(world, at, basis, Vector3(1.05, 3.80, 0.60), tip, 0.27, BARK)
	for toe: Vector3 in [
		Vector3(2.60, 0.32, 1.30), Vector3(2.40, 0.32, -1.40), Vector3(0.10, 0.32, 1.70)
	]:
		GEO.beam(world, at, basis, Vector3(1.05, 1.45, 0.60), toe, 0.30, BARK)
	# Root arch frames the original books; its opening is not on the race route.
	var roots: Array[Vector3] = [
		Vector3(-2.65, 0.32, -1.0),
		Vector3(-2.10, 2.80, -0.80),
		Vector3(-1.45, 3.90, -0.75),
		Vector3(-0.30, 4.35, -0.70),
		Vector3(0.85, 4.00, -0.70),
		Vector3(1.65, 2.80, -0.80),
		Vector3(2.50, 0.32, -1.0),
	]
	for index in range(roots.size() - 1):
		GEO.beam(world, at, basis, roots[index], roots[index + 1], 0.25, WOOD)
	GEO.put(
		world, "crown", at, basis, Vector3(-1.05, 5.30, 0.65), Vector3(1.50, 0.85, 1.40), FOREST
	)
	GEO.put(world, "crown", at, basis, Vector3(1.0, 5.80, 0.55), Vector3(1.65, 0.95, 1.50), LEAF)
	GEO.put(world, "crown", at, basis, Vector3(0.05, 6.60, 0.55), Vector3(1.80, 1.0, 1.60), MOSS)
	_lantern(world, at, basis, Vector3(-1.75, 4.90, -0.85), 0.92)
	_lantern(world, at, basis, Vector3(1.70, 5.10, -0.45), 1.20)
	if not world.low_detail:
		GEO.put(
			world, "crown", at, basis, Vector3(-0.90, 6.10, 1.0), Vector3(1.20, 0.75, 1.05), LEAF
		)
		# Small gold grain catches light without introducing a new material family.
		GEO.beam(
			world, at, basis, Vector3(-2.10, 0.40, -0.93), Vector3(-1.75, 2.55, -0.91), 0.035, BRASS
		)
		GEO.beam(
			world, at, basis, Vector3(2.10, 0.40, -0.93), Vector3(1.40, 2.55, -0.91), 0.035, BRASS
		)


static func _lantern(world, at: Vector3, basis: Basis, hook: Vector3, drop: float) -> void:
	var center := hook - Vector3.UP * drop
	GEO.beam(world, at, basis, hook, center + Vector3.UP * 0.27, 0.025, BRASS)
	GEO.put(world, "ball", at, basis, center, Vector3(0.20, 0.27, 0.20), LIGHT, true)
	GEO.put(world, "cone", at, basis, center + Vector3.UP * 0.29, Vector3(0.28, 0.16, 0.28), BRASS)
	GEO.put(
		world, "cylinder", at, basis, center - Vector3.UP * 0.28, Vector3(0.21, 0.08, 0.21), BRASS
	)
