extends SceneTree
## Against exact live Kart sources, not a replacement demo.
const WORLD = preload("res://scripts/games/kart_world.gd")
const VEHICLE = preload("res://scripts/games/kart_vehicle.gd")
const ISLAND = preload("res://scripts/games/kart_island.gd")
const TRACKS = preload("res://scripts/games/kart_tracks.gd")

func _initialize() -> void:
	call_deferred("_run")

func _check_signs() -> void:
	for sign_value in [-1.0, 1.0]:
		var high: Dictionary = WORLD.chevron_stroke_local(sign_value, true)
		var low: Dictionary = WORLD.chevron_stroke_local(sign_value, false)
		for arm: Dictionary in [high, low]:
			var direction: Vector3 = arm.tip - arm.tail
			assert(direction.x * sign_value > 0.8, "Arrow points away from curve")
			assert(absf(float(arm.length) - direction.length()) < 0.001)
			assert(absf(arm.tip.y) < 0.001)
		assert(high.tail.y > 0.40 and low.tail.y < -0.40)
		assert(high.tip.is_equal_approx(low.tip), "Both arrow bars must converge")
		assert(high.angle * low.angle < 0.0 or
			absf(high.angle) > 2.0 and absf(low.angle) > 2.0,
			"Arrow bars must diverge symmetrically")
	var world = WORLD.new()
	root.add_child(world)
	world.build(true, "sonnenhafen", true)
	assert(world.length > 1000)
	for fraction in [0.14, 0.25, 0.39, 0.52, 0.70, 0.84]:
		var d: float = world.length * fraction
		var basis: Basis = world.frame(d)
		var road_forward: Vector3 = world.forward(d)
		assert((-basis.z).dot(road_forward) > 0.99, "Turbo sign points backward")
		for side in [-1.0, 1.0]:
			var geom: Dictionary = ISLAND._chevron_arm_geometry(basis,side)
			assert((geom.forward as Vector3).dot(road_forward) > 0.99)
			assert((geom.direction as Vector3).dot(road_forward) > 0.35)
	world.free()

func _check_tail() -> void:
	for style in ["comet", "terra"]:
		var kart = VEHICLE.new()
		root.add_child(kart)
		kart.configure("fox", Color("55c7eb"), style)
		assert(is_instance_valid(kart.tail), "Fox tail rig missing")
		assert(int(kart.tail.get_meta("kart_tail_clearance_revision", 0)) == 1)
		assert(kart.tail.position.x >= 0.55,
			"Fox tail root still penetrates the side of the cockpit")
		assert(kart.tail.position.y >= 1.09,
			"Fox tail hangs through the lower rear body")
		assert(kart.tail.position.z >= 0.23)
		assert(kart.tail.rotation.y > 0.55)
		assert(kart.wheel_pivots.size() == 4,
			"Tail correction must not change vehicle physics or wheel anchors")
		kart.free()

func _run() -> void:
	_check_signs()
	_check_tail()
	print("[KartArrowTail] PASS two genuine arrow arms, six course directions, two real fox chassis")
	quit(0)
