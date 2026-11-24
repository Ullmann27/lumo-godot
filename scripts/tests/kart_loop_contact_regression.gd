extends SceneTree
## The loop must move at its reported speed, including entry/exit and steering.
const LOOP = preload("res://scripts/games/kart_physical_loop.gd")
const STEP: float = 1.0 / 120.0


class StraightRoad:
	func frame(_distance: float) -> Basis:
		return Basis.IDENTITY

	func position_at(distance: float, lateral: float = 0.0) -> Vector3:
		return Vector3(lateral, 0.0, -distance)

	func reset_transform(distance: float, lateral: float = 0.0) -> Transform3D:
		return Transform3D(Basis.IDENTITY, position_at(distance, lateral))


func _initialize() -> void:
	var world := StraightRoad.new()
	var completed: int = 0
	for radius in [6.5, 8.0]:
		var layout: Dictionary = {"start": 120.0, "lane": 2.9, "radius": radius}
		var loop = LOOP.new()
		loop.enter(layout, 24.0, 120.0)
		var previous: Vector3 = LOOP.point(world, layout, 0.0) + Vector3.UP * 0.045
		var max_error: float = 0.0
		var reached_top: bool = false
		for frame in range(1000):
			var transform: Transform3D = loop.advance(world, STEP, 0.0, 0.0, true)
			if loop.active:
				var error: float = absf(
					previous.distance_to(transform.origin) / (loop.speed * STEP) - 1.0
				)
				max_error = maxf(max_error, error)
				reached_top = reached_top or transform.basis.y.dot(Vector3.UP) < -0.99
			previous = transform.origin
			if not loop.active:
				break
		assert(not loop.failed and loop.progress == 1.0, "Full loop completes")
		assert(reached_top, "The kart actually becomes inverted")
		assert(
			max_error < 0.015,
			"Reported speed matches real loop travel: radius %.1f error %.3f" % [radius, max_error]
		)
		assert(
			previous.distance_to(world.position_at(127.0, 2.9) + Vector3.UP * 0.045) < 0.002,
			"Exit joins road"
		)
		completed += 1
		print("[LoopContact] radius %.1f: maximum physical speed error %.4f" % [radius, max_error])
	if completed != 2:
		quit(1)
		return
	print("[LoopContact] PASS: uniform physical travel, inversion and continuous road joins")
	quit(0)
