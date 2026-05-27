## LumoEyeSystem
##
## Steuert Augen + Augenbrauen. Augen werden als 2 Sphere-Meshes
## modelliert; Brauen als 2 Box-Meshes ueber den Augen. State-Wechsel
## passieren ueber Skalierung (Blink), Verschiebung (Wink) und
## Rotation (Brauen).
##
## Auto-Blink: alle 3-6 s zufaellig wenn `auto_blink_enabled = true`.
class_name LumoEyeSystem
extends Node3D

const EYE_STATES: Array[String] = [
	"open_neutral",
	"happy_squint",
	"blink_closed",
	"half_blink",
	"wink_left",
	"wink_right",
	"surprised_wide",
	"sleepy_half_lid",
]

const BROW_STATES: Array[String] = [
	"neutral",
	"curious",
	"sad",
	"determined",
	"happy",
]

@export var eye_left_path: NodePath
@export var eye_right_path: NodePath
@export var brow_left_path: NodePath
@export var brow_right_path: NodePath
@export var auto_blink_enabled: bool = true
@export var blink_interval_min: float = 3.0
@export var blink_interval_max: float = 6.0

var _eye_left: Node3D
var _eye_right: Node3D
var _brow_left: Node3D
var _brow_right: Node3D
var _current_eye_state: String = "open_neutral"
var _current_brow_state: String = "neutral"
var _next_blink_t: float = 4.0
var _time: float = 0.0
var _blink_active: bool = false


func _ready() -> void:
	_eye_left = get_node_or_null(eye_left_path) as Node3D
	_eye_right = get_node_or_null(eye_right_path) as Node3D
	_brow_left = get_node_or_null(brow_left_path) as Node3D
	_brow_right = get_node_or_null(brow_right_path) as Node3D
	set_eye_state("open_neutral")
	set_brow_state("neutral")
	_schedule_next_blink()


func _process(delta: float) -> void:
	if not auto_blink_enabled:
		return
	_time += delta
	if _time >= _next_blink_t and not _blink_active:
		blink()
		_schedule_next_blink()


## Erzwingt einen einmaligen Blink (sofort).
func blink() -> void:
	if _blink_active:
		return
	_blink_active = true
	var tw: Tween = create_tween()
	tw.tween_callback(func(): _scale_eyes(Vector3(1.0, 0.08, 1.0)))
	tw.tween_interval(0.10)
	tw.tween_callback(func(): _scale_eyes(Vector3.ONE))
	tw.tween_callback(func(): _blink_active = false)


## Setzt einen Eye-State. Aktualisiert beide Augen.
func set_eye_state(state_name: String) -> void:
	if not EYE_STATES.has(state_name):
		push_warning("[LumoEyes] unknown state: %s" % state_name)
		return
	_current_eye_state = state_name
	if _eye_left == null or _eye_right == null:
		return
	var l_scale: Vector3 = Vector3.ONE
	var r_scale: Vector3 = Vector3.ONE
	match state_name:
		"open_neutral":
			l_scale = Vector3.ONE
			r_scale = Vector3.ONE
		"happy_squint":
			l_scale = Vector3(1.0, 0.45, 1.0)
			r_scale = Vector3(1.0, 0.45, 1.0)
		"blink_closed":
			l_scale = Vector3(1.0, 0.05, 1.0)
			r_scale = Vector3(1.0, 0.05, 1.0)
		"half_blink":
			l_scale = Vector3(1.0, 0.50, 1.0)
			r_scale = Vector3(1.0, 0.50, 1.0)
		"wink_left":
			l_scale = Vector3(1.0, 0.05, 1.0)
			r_scale = Vector3.ONE
		"wink_right":
			l_scale = Vector3.ONE
			r_scale = Vector3(1.0, 0.05, 1.0)
		"surprised_wide":
			l_scale = Vector3(1.2, 1.3, 1.2)
			r_scale = Vector3(1.2, 1.3, 1.2)
		"sleepy_half_lid":
			l_scale = Vector3(1.0, 0.35, 1.0)
			r_scale = Vector3(1.0, 0.35, 1.0)
	_eye_left.scale = l_scale
	_eye_right.scale = r_scale
	EventBus.lumo_eye_state_changed.emit(state_name)


## Setzt einen Brow-State. Aendert Rotation + leichte Translation.
func set_brow_state(state_name: String) -> void:
	if not BROW_STATES.has(state_name):
		push_warning("[LumoBrows] unknown state: %s" % state_name)
		return
	_current_brow_state = state_name
	if _brow_left == null or _brow_right == null:
		return
	# (rotation_z links, rotation_z rechts, y_offset)
	var cfg: Vector3 = Vector3.ZERO
	match state_name:
		"neutral":
			cfg = Vector3(0.0, 0.0, 0.0)
		"curious":
			cfg = Vector3(0.0, -0.25, 0.04)
		"sad":
			cfg = Vector3(-0.25, 0.25, -0.02)
		"determined":
			cfg = Vector3(0.25, -0.25, -0.03)
		"happy":
			cfg = Vector3(0.15, -0.15, 0.02)
	_brow_left.rotation.z = cfg.x
	_brow_right.rotation.z = cfg.y
	# Y-Offset nur additiv auf einer Basis-Position
	_brow_left.position.y = 0.20 + cfg.z
	_brow_right.position.y = 0.20 + cfg.z


func get_eye_state() -> String:
	return _current_eye_state


func get_brow_state() -> String:
	return _current_brow_state


func _scale_eyes(s: Vector3) -> void:
	if _eye_left != null:
		_eye_left.scale = s
	if _eye_right != null:
		_eye_right.scale = s


func _schedule_next_blink() -> void:
	_time = 0.0
	_next_blink_t = randf_range(blink_interval_min, blink_interval_max)
