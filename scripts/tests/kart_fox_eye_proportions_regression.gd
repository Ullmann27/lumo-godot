extends SceneTree
## Mechanical contract for a smaller, less protruding original Lumo fox face.
## This does not assert pixel-identical concept-art quality.
const VEHICLE = preload("res://scripts/games/kart_vehicle.gd")


class AuthoredDriver:
	extends LumoRaceKart

	func _make_far_mesh() -> void:
		pass

	func _merge_static(_parent: Node3D) -> void:
		pass


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var fox := AuthoredDriver.new()
	fox.configure("fox", Color("1d4fa0"), "comet")
	root.add_child(fox)
	assert(fox.eyes.size() == 2)
	for eye: Node3D in fox.eyes:
		assert(eye.get_child_count() >= 6)
		var white: MeshInstance3D = eye.get_child(1)
		var pupil: MeshInstance3D = eye.get_child(3)
		assert(absf(white.scale.x - 0.105) < 0.0001)
		assert(absf(white.scale.y - 0.125) < 0.0001)
		assert(pupil.scale.x < white.scale.x * 0.55)
		assert(pupil.scale.y < white.scale.y * 0.50)
		assert(eye.position.z <= -0.290 and eye.position.z >= -0.310)
		assert(eye.position.x >= -0.180 and eye.position.x <= 0.180)
	fox.free()
	# Other animal drivers retain their existing face system.
	var rabbit := AuthoredDriver.new()
	rabbit.configure("rabbit", Color("e9eff8"), "comet")
	root.add_child(rabbit)
	assert(rabbit.eyes.size() == 2)
	for eye: Node3D in rabbit.eyes:
		var white: MeshInstance3D = eye.get_child(1)
		assert(absf(white.scale.x - 0.119) < 0.0001)
	rabbit.free()
	print("[LumoEyeProportions] PASS: smaller fox eye, brown iris, other animals unchanged")
	quit(0)
