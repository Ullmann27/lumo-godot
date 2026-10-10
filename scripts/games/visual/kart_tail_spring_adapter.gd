extends Node
## Optional visual-only secondary motion for the existing "TailJoint" in kart_vehicle.gd.
## DO NOT connect alongside existing procedural tail rotation: select ONE animation owner.
## No change to vehicle heading, traction, jumping, multiplayer or physics saves.
@export var stiffness: float = 18.0
@export var damping: float = 8.0
@export var amplitude: float = 0.13
var joint: Node3D
var base_y: float = 0.0
var velocity: float = 0.0
var displacement: float = 0.0
var steering: float = 0.0
var reduced_motion: bool = false


func bind_tail(new_joint: Node3D) -> void:
    joint = new_joint
    if is_instance_valid(joint):
        base_y = joint.rotation.y
    velocity = 0.0
    displacement = 0.0


func set_steering(value: float) -> void:
    steering = clampf(value, -1.0, 1.0)


func _physics_process(delta: float) -> void:
    if not is_instance_valid(joint):
        return
    if reduced_motion:
        joint.rotation.y = base_y
        velocity = 0.0
        displacement = 0.0
        return
    var step: float = minf(delta, 0.04)
    var target: float = -steering * amplitude
    velocity += (target - displacement) * stiffness * step
    velocity *= exp(-damping * step)
    displacement += velocity * step
    joint.rotation.y = base_y + displacement
