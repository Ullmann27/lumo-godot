extends CharacterBody3D
## Walk through the same construction bodies used by the editor. Rendering never
## changes collision position; the original Lumo rig follows measured velocity.
const ORIGINAL_LUMO = preload("res://scripts/characters/lumo/lumo_rigged_actor.gd")
const SPEED := 4.8
const ACCELERATION := 19.0
const BRAKING := 25.0
const GRAVITY := 21.0
const JUMP_SPEED := 7.6
const JUMP_BUFFER := 0.14
const COYOTE := 0.10
var original_lumo: Node3D
var move_axis := Vector2.ZERO
var camera_yaw := 0.0
var jump_held := false
var active := false
var jump_buffer := 0.0
var coyote := 0.0
var spawn := Vector3(-12, 0.08, 10)
var safe_position := spawn
var rescue_count := 0
var jump_count := 0
var landing_count := 0
var inspection_left := 0.0
var horizontal_limit := Vector2(26.0, 26.0)


func _ready() -> void:
	name = "BuildExplorer"
	floor_snap_length = 0.24
	floor_max_angle = deg_to_rad(48.0)
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.30
	capsule.height = 1.42
	collider.shape = capsule
	collider.position.y = 0.72
	add_child(collider)
	original_lumo = ORIGINAL_LUMO.new()
	original_lumo.name = "OriginalLumo"
	add_child(original_lumo)
	_fit_original()
	set_active(false)


func _fit_original() -> void:
	if not original_lumo.is_usable():
		return
	var skeleton: Skeleton3D = original_lumo.skeleton
	var lowest := INF
	var highest := -INF
	for bone in range(skeleton.get_bone_count()):
		var rest: Vector3 = skeleton.get_bone_global_rest(bone).origin
		lowest = minf(lowest, rest.y)
		highest = maxf(highest, rest.y)
	var span := highest - lowest
	if span > 0.2 and span <= 15.0:
		var factor := clampf(1.38 / span, 0.08, 3.0)
		original_lumo.scale = Vector3.ONE * factor
		original_lumo.position.y = 0.02 - lowest * factor
		original_lumo.rotation.y = PI


func set_active(value: bool) -> void:
	active = value
	visible = value
	move_axis = Vector2.ZERO
	jump_held = false
	jump_buffer = 0.0
	coyote = 0.0
	velocity = Vector3.ZERO
	inspection_left = 0.0
	collision_layer = 2 if value else 0
	collision_mask = 1 if value else 0
	if is_instance_valid(original_lumo):
		original_lumo.set_suspended(not value)


func start_at(at: Vector3) -> void:
	spawn = at
	safe_position = at
	position = at
	set_active(true)


func hold_jump(value: bool) -> void:
	if not active:
		return
	if value and not jump_held:
		jump_buffer = JUMP_BUFFER
	if not value and jump_held and velocity.y > 2.4:
		velocity.y *= 0.46
	jump_held = value


func advance_motion(delta: float) -> void:
	if not active or delta <= 0.0:
		return
	var grounded := is_on_floor()
	coyote = COYOTE if grounded else maxf(0.0, coyote - delta)
	jump_buffer = maxf(0.0, jump_buffer - delta)
	var wish := Vector3(move_axis.x, 0, move_axis.y).rotated(Vector3.UP, camera_yaw)
	var desired := wish.limit_length(1.0) * SPEED
	var rate := ACCELERATION if desired.length_squared() > 0.01 else BRAKING
	velocity.x = move_toward(velocity.x, desired.x, rate * delta)
	velocity.z = move_toward(velocity.z, desired.z, rate * delta)
	velocity.y = -0.4 if grounded else maxf(-24.0, velocity.y - GRAVITY * delta)
	if jump_buffer > 0 and coyote > 0:
		velocity.y = JUMP_SPEED
		jump_buffer = 0
		coyote = 0
		jump_count += 1
	move_and_slide()
	if not grounded and is_on_floor():
		landing_count += 1
	if is_on_floor() and absf(position.x) < horizontal_limit.x - 2.0 and absf(position.z) < horizontal_limit.y - 2.0:
		safe_position = position + Vector3.UP * 0.04
	if position.y < -5.0 or absf(position.x) > horizontal_limit.x or absf(position.z) > horizontal_limit.y:
		position = safe_position
		velocity = Vector3.ZERO
		jump_buffer = 0
		rescue_count += 1
	var speed := Vector2(velocity.x, velocity.z).length()
	if speed > 0.08:
		rotation.y = lerp_angle(rotation.y, atan2(-velocity.x, -velocity.z), 1.0 - exp(-14.0 * delta))
	inspection_left = maxf(0.0, inspection_left - delta)
	if speed > 0.08 or not is_on_floor():
		inspection_left = 0.0
	if is_instance_valid(original_lumo) and inspection_left <= 0.0:
		if original_lumo.has_method("set_platform_motion"):
			original_lumo.set_platform_motion(velocity, is_on_floor(), delta)
		else:
			original_lumo.set_locomotion_speed(speed if is_on_floor() else 0.0)


func point_at_object() -> void:
	if active and original_lumo.is_usable():
		inspection_left = 1.2
		original_lumo.play_behavior("point_portal")
