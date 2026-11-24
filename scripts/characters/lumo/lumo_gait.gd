class_name LumoGait
extends Node
## Distance-driven walk/run cycle for the Lumo character (lumo_character.tscn).
##
## The stride phase advances from the distance the character ACTUALLY moved
## (global position delta), not from time. During stance the planted foot's
## horizontal offset to the hip changes exactly as fast as the body moves, so
## the foot stays on the ground instead of gliding. Walking at low speed blends
## into running (shorter ground contact, longer stride) at higher speed.
## Arms swing opposite to the legs, the body follows the inverted-pendulum
## height of the stance leg, head and tail counter-move, and the swing leg
## lifts via a stylised knee (shortened capsule leg) so it clears the ground.
## No physics is changed: this is a pure visual layer for any game that moves
## a Lumo character (3D Jump today; Bauwelt or a hub tomorrow).

const LEG_LENGTH: float = 0.55  # capsule limb height in model units
const BODY_REST_Y: float = 0.55  # Body node height in lumo_character.tscn
const HIP_OFFSET_Y: float = -0.305  # hip pivot below Body origin (model units)
const MAX_SWING: float = 0.62  # sin of the largest leg angle (~38 deg)
const WALK_DUTY: float = 0.62  # ground-contact share of a cycle when walking
const RUN_DUTY: float = 0.36  # ... when running
const RUN_SPEED: float = 4.5  # m/s (world) at which the gait is a full run
const MOVE_THRESHOLD: float = 0.25  # m/s below which Lumo stands still
const SWING_LIFT: float = 0.12  # swing foot clearance (model units)
const TELEPORT_DISTANCE: float = 1.5  # m per frame treated as a teleport

@export var character_path: NodePath = NodePath("..")

var character: Node3D
var body: Node3D
var head: Node3D
var arm_left: Node3D
var arm_right: Node3D
var tail: Node3D
var hips: Array[Node3D] = []  # [left, right] pivots created at runtime
var legs: Array[MeshInstance3D] = []
var phase: float = 0.0  # 0..1 per full cycle (two steps)
var speed: float = 0.0  # measured horizontal speed, m/s
var moving: bool = false
var airborne: bool = false
var _previous: Vector3
var _has_previous: bool = false
var _body_rest: Vector3
var _head_rest: Vector3
var _tail_rest: Basis
var _arm_rest: Array[Basis] = []
var _ready_ok: bool = false


func _ready() -> void:
	character = get_node_or_null(character_path) as Node3D
	if character == null:
		return
	body = character.get_node_or_null("VisualRoot/Body") as Node3D
	head = character.get_node_or_null("VisualRoot/Head") as Node3D
	arm_left = character.get_node_or_null("VisualRoot/Body/ArmLeft") as Node3D
	arm_right = character.get_node_or_null("VisualRoot/Body/ArmRight") as Node3D
	tail = character.get_node_or_null("VisualRoot/Body/Tail") as Node3D
	if body == null:
		return
	for leg_name in ["LegLeft", "LegRight"]:
		var leg := body.get_node_or_null(leg_name) as MeshInstance3D
		if leg == null:
			return
		# Re-parent the leg under a hip pivot so it rotates about the hip,
		# not about its own centre. The visible leg does not move at rest.
		var hip := Node3D.new()
		hip.name = leg_name + "Hip"
		hip.position = Vector3(leg.position.x, HIP_OFFSET_Y, leg.position.z)
		body.add_child(hip)
		var rest: Vector3 = leg.position
		body.remove_child(leg)
		hip.add_child(leg)
		leg.position = rest - hip.position
		hips.append(hip)
		legs.append(leg)
	_body_rest = body.position
	_head_rest = head.position if head != null else Vector3.ZERO
	_tail_rest = tail.basis if tail != null else Basis.IDENTITY
	_arm_rest = [
		arm_left.basis if arm_left != null else Basis.IDENTITY,
		arm_right.basis if arm_right != null else Basis.IDENTITY,
	]
	_ready_ok = true


## Height (model units) of the rest foot below the character origin. Scenes
## that put the origin on the floor must lift the character by this amount,
## otherwise the legs are buried and only the body is visible.
static func rest_foot_depth() -> float:
	return -(BODY_REST_Y + HIP_OFFSET_Y - LEG_LENGTH)


## World units per model unit (the jump game scales Lumo by 0.7).
func model_scale() -> float:
	return character.global_basis.get_scale().y if character != null else 1.0


func duty() -> float:
	return lerpf(WALK_DUTY, RUN_DUTY, clampf(speed / RUN_SPEED, 0.0, 1.0))


## Horizontal distance (world metres) covered by one full cycle at this speed.
## In stance the foot sweeps 2 * LEG * MAX_SWING while the body moves the same
## distance, which is duty * cycle_length.
func cycle_length() -> float:
	var sweep: float = 2.0 * LEG_LENGTH * MAX_SWING * model_scale()
	return sweep / duty()


## Feed once per physics frame from the game, after move_and_slide().
func step(on_floor: bool, delta: float) -> void:
	if not _ready_ok or delta <= 0.0:
		return
	var now: Vector3 = character.global_position
	if not _has_previous:
		_previous = now
		_has_previous = true
	var moved := Vector3(now.x - _previous.x, 0.0, now.z - _previous.z)
	_previous = now
	if moved.length() > TELEPORT_DISTANCE:
		# Respawn / checkpoint teleport: no stride for a jump in position.
		moved = Vector3.ZERO
		speed = 0.0
	var measured: float = moved.length() / delta
	speed = lerpf(speed, measured, minf(1.0, delta * 12.0))
	airborne = not on_floor
	var was_moving: bool = moving
	moving = on_floor and speed > MOVE_THRESHOLD
	if moving:
		phase = fposmod(phase + moved.length() / cycle_length(), 1.0)
	elif on_floor:
		# Settle the nearer foot down instead of freezing mid-stride.
		var target: float = 0.0 if fposmod(phase, 0.5) < 0.25 else 0.5
		phase = move_toward(phase, target if target > phase - 0.25 else target + 1.0, delta * 2.0)
		phase = fposmod(phase, 1.0)
	if moving != was_moving:
		_set_behavior("idle" if moving else "idle_bounce")
	apply_pose()


func _set_behavior(name: String) -> void:
	var behavior: Node = character.get_node_or_null("BehaviorController")
	if behavior != null and behavior.has_method("play_behavior"):
		behavior.play_behavior(name)


## Foot target for one leg at its own phase u (0..1), relative to the hip.
## Stance u < duty: offset moves linearly from +A to -A while the foot stays
## on the ground (exact plant). Swing: the foot returns from -A to +A lifted.
func leg_state(u: float) -> Dictionary:
	var d: float = duty()
	var amplitude: float = LEG_LENGTH * MAX_SWING
	if u < d:
		return {"offset": lerpf(amplitude, -amplitude, u / d), "lift": 0.0, "stance": true}
	var s: float = (u - d) / (1.0 - d)
	return {
		"offset": lerpf(-amplitude, amplitude, 0.5 - 0.5 * cos(PI * s)),
		"lift": SWING_LIFT * sin(PI * s),
		"stance": false,
	}


func apply_pose() -> void:
	if not _ready_ok:
		return
	var active: float = 1.0 if (moving or airborne) else 0.0
	var states: Array = [leg_state(phase), leg_state(fposmod(phase + 0.5, 1.0))]
	# Hip height: the most extended planted leg is straight (full length), so
	# the hip rides an inverted-pendulum arc and every planted foot reaches the
	# same ground plane.
	var reach: float = 0.0
	for state in states:
		if state.stance:
			reach = maxf(reach, absf(float(state.offset)) * active)
	var height: float = sqrt(LEG_LENGTH * LEG_LENGTH - reach * reach)
	if airborne:
		height = LEG_LENGTH
	for i in range(2):
		var state: Dictionary = states[i]
		var offset: float = float(state.offset) * active
		var drop: float = height - float(state.lift) * active
		if airborne:
			offset = 0.16 if i == 0 else -0.12
			drop = LEG_LENGTH * 0.8
		# Simple 2-point IK: the capsule leg points from hip to foot and is
		# shortened (stylised knee) when the foot is closer than LEG_LENGTH.
		var angle: float = atan2(offset, drop)
		var length: float = sqrt(offset * offset + drop * drop)
		# Forward is +Z in Body space; rotating about -X swings the foot forward.
		hips[i].rotation = Vector3(-angle, 0.0, 0.0)
		var shin: float = length / LEG_LENGTH
		legs[i].scale = Vector3(1.0, shin, 1.0)
		legs[i].position.y = -LEG_LENGTH * 0.5 * shin
	var bob: float = height - LEG_LENGTH if not airborne else 0.0
	body.position = _body_rest + Vector3(0.0, bob, 0.0)
	if head != null:
		head.position = _head_rest + Vector3(0.0, bob * 0.8, 0.0)
	# Arms counter-swing to the legs; tail sways with the hips.
	var swing: float = asin(clampf(float(states[0].offset) / LEG_LENGTH, -1.0, 1.0)) * active
	if arm_left != null:
		arm_left.basis = _arm_rest[0] * Basis(Vector3.RIGHT, swing * 1.1)
	if arm_right != null:
		arm_right.basis = _arm_rest[1] * Basis(Vector3.RIGHT, -swing * 1.1)
	if tail != null:
		tail.basis = Basis(Vector3.UP, sin(TAU * phase) * 0.35 * active) * _tail_rest


## World-space bottom point of a leg (used by tests to measure foot sliding).
func foot_position(index: int) -> Vector3:
	var leg: MeshInstance3D = legs[index]
	return leg.global_transform * Vector3(0.0, -LEG_LENGTH * 0.5, 0.0)
