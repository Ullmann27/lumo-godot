extends Node3D
## Messattrappe für sky_post_seat_probe.gd: Steuerhorn mit zwei Griffen.

var steering_wheel: Node3D
var wheel_rest_grips: Array = [Vector3(-0.17, 0.0, 0.0), Vector3(0.17, 0.0, 0.0)]


func _init() -> void:
	steering_wheel = Node3D.new()
	steering_wheel.name = "Yoke"
	steering_wheel.position = Vector3(0, 1.02, -0.36)
	add_child(steering_wheel)
