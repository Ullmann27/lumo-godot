## LumoBehaviorController
##
## High-Level Verhalten-API. Andere Knoten (Home, Portal, ResultDialog,
## Lernfragen) rufen:
##   lumo.play_behavior("greet")
## Die Implementierung kombiniert AnimationPlayer-Animationen,
## Tween-basierte Bewegungen und Aufrufe an Eye/Mouth-System.
##
## Erlaubte Behaviors entsprechen LumoAnimationState.STATES + kurze
## High-Level Aliase wie "greet", "speak", "explain".
class_name LumoBehaviorController
extends Node3D

const BEHAVIOR_ALIAS: Dictionary = {
	"greet": "greeting_wave",
	"speak": "speak_explain",
	"explain": "speak_explain",
	"point": "point_portal",
	"reward": "reward_star",
	"walk": "walk_loop",
	"jump": "jump_hop",
	"bounce": "idle_bounce",
}

# Welche Eye/Brow/Mouth-Konfiguration zu welchem Behavior gehoert
# (Behavior -> {eye, brow, mouth}).
const BEHAVIOR_FACE: Dictionary = {
	"idle": {"eye": "open_neutral", "brow": "neutral", "mouth": "rest"},
	"idle_bounce": {"eye": "happy_squint", "brow": "happy", "mouth": "closed_smile"},
	"greeting_wave": {"eye": "happy_squint", "brow": "happy", "mouth": "smile"},
	"listen": {"eye": "open_neutral", "brow": "curious", "mouth": "closed_smile"},
	"speak_explain": {"eye": "open_neutral", "brow": "neutral", "mouth": "a"},
	"encourage": {"eye": "happy_squint", "brow": "happy", "mouth": "grin"},
	"celebrate": {"eye": "surprised_wide", "brow": "happy", "mouth": "surprise_open"},
	"walk_loop": {"eye": "open_neutral", "brow": "neutral", "mouth": "closed_smile"},
	"jump_hop": {"eye": "surprised_wide", "brow": "happy", "mouth": "o"},
	"point_portal": {"eye": "open_neutral", "brow": "determined", "mouth": "smile"},
	"reward_star": {"eye": "surprised_wide", "brow": "happy", "mouth": "grin"},
	"turn_left": {"eye": "open_neutral", "brow": "neutral", "mouth": "rest"},
	"turn_right": {"eye": "open_neutral", "brow": "neutral", "mouth": "rest"},
}

@export var character_root_path: NodePath
@export var eye_system_path: NodePath
@export var mouth_system_path: NodePath
@export var arm_left_path: NodePath
@export var arm_right_path: NodePath
@export var body_path: NodePath
@export var visual_root_path: NodePath

var _character_root: Node3D
var _eyes: LumoEyeSystem
var _mouth: LumoMouthSystem
var _arm_left: Node3D
var _arm_right: Node3D
var _body: Node3D
var _visual: Node3D
var _current_behavior: String = ""
var _active_tween: Tween


func _ready() -> void:
	_character_root = get_node_or_null(character_root_path) as Node3D
	_eyes = get_node_or_null(eye_system_path) as LumoEyeSystem
	_mouth = get_node_or_null(mouth_system_path) as LumoMouthSystem
	_arm_left = get_node_or_null(arm_left_path) as Node3D
	_arm_right = get_node_or_null(arm_right_path) as Node3D
	_body = get_node_or_null(body_path) as Node3D
	_visual = get_node_or_null(visual_root_path) as Node3D


## Triggert ein Behavior per Name. Alias wie "greet" werden aufgeloest.
func play_behavior(name: String) -> void:
	var resolved: String = BEHAVIOR_ALIAS.get(name, name)
	if not LumoAnimationState.is_valid(resolved):
		push_warning("[LumoBehavior] unbekanntes behavior: %s" % name)
		return
	if _current_behavior == resolved and LumoAnimationState.is_loop(resolved):
		return
	_current_behavior = resolved
	print("behavior:%s" % resolved)
	EventBus.lumo_behavior_started.emit(resolved)
	_apply_face(resolved)
	_stop_active_tween()
	match resolved:
		"idle":
			_behavior_idle()
		"idle_bounce":
			_behavior_idle_bounce()
		"greeting_wave":
			_behavior_greeting_wave()
		"listen":
			_behavior_listen()
		"speak_explain":
			_behavior_speak_explain()
		"encourage":
			_behavior_encourage()
		"celebrate":
			_behavior_celebrate()
		"walk_loop":
			_behavior_walk_loop()
		"jump_hop":
			_behavior_jump_hop()
		"point_portal":
			_behavior_point_portal()
		"reward_star":
			_behavior_reward_star()
		"turn_left":
			_behavior_turn(-PI * 0.5)
		"turn_right":
			_behavior_turn(PI * 0.5)


func get_current_behavior() -> String:
	return _current_behavior


func _apply_face(behavior: String) -> void:
	var cfg: Dictionary = BEHAVIOR_FACE.get(behavior, {})
	if _eyes != null and cfg.has("eye"):
		_eyes.set_eye_state(cfg["eye"])
	if _eyes != null and cfg.has("brow"):
		_eyes.set_brow_state(cfg["brow"])
	if _mouth != null and cfg.has("mouth"):
		_mouth.set_mouth_shape(cfg["mouth"])


func _stop_active_tween() -> void:
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
		_active_tween = null
	if _mouth != null and _mouth.has_method("stop_speaking"):
		_mouth.stop_speaking()
	_reset_pose_partial()


func _reset_pose_partial() -> void:
	if _arm_left != null:
		_arm_left.rotation = Vector3(0, 0, deg_to_rad(-15))
	if _arm_right != null:
		_arm_right.rotation = Vector3(0, 0, deg_to_rad(15))
	if _body != null:
		_body.position.y = 0.0
	if _visual != null:
		_visual.position.y = 0.0


func _behavior_idle() -> void:
	_emit_finished_after(0.4)


func _behavior_idle_bounce() -> void:
	if _visual == null:
		return
	_active_tween = create_tween().set_loops()
	_active_tween.tween_property(_visual, "position:y", 0.06, 0.6).set_trans(Tween.TRANS_SINE)
	_active_tween.tween_property(_visual, "position:y", 0.0, 0.6).set_trans(Tween.TRANS_SINE)


func _behavior_greeting_wave() -> void:
	if _arm_right == null:
		_emit_finished_after(0.8)
		return
	_active_tween = create_tween()
	_active_tween.tween_property(_arm_right, "rotation:z", deg_to_rad(140), 0.20)
	for i in range(2):
		_active_tween.tween_property(_arm_right, "rotation:z", deg_to_rad(170), 0.18)
		_active_tween.tween_property(_arm_right, "rotation:z", deg_to_rad(110), 0.18)
	_active_tween.tween_property(_arm_right, "rotation:z", deg_to_rad(15), 0.25)
	_active_tween.tween_callback(func(): _on_behavior_done("greeting_wave"))


func _behavior_listen() -> void:
	# leichtes Vorbeugen + Kopfneigung Illusion via visual_root
	if _visual == null:
		_emit_finished_after(0.4)
		return
	_active_tween = create_tween().set_loops()
	_active_tween.tween_property(_visual, "rotation:z", deg_to_rad(4), 1.4).set_trans(
		Tween.TRANS_SINE
	)
	_active_tween.tween_property(_visual, "rotation:z", deg_to_rad(-4), 1.4).set_trans(
		Tween.TRANS_SINE
	)


func _behavior_speak_explain() -> void:
	if _mouth != null:
		_mouth.start_speaking()
	# Arme heben sich leicht beim Sprechen
	if _arm_left != null and _arm_right != null:
		_active_tween = create_tween().set_loops()
		_active_tween.tween_property(_arm_left, "rotation:z", deg_to_rad(-40), 0.4)
		_active_tween.tween_property(_arm_left, "rotation:z", deg_to_rad(-25), 0.4)


func _behavior_encourage() -> void:
	# Kurzer Daumen-hoch Lift mit dem rechten Arm
	if _arm_right == null:
		_emit_finished_after(0.6)
		return
	_active_tween = create_tween()
	_active_tween.tween_property(_arm_right, "rotation:z", deg_to_rad(80), 0.20)
	_active_tween.tween_interval(0.6)
	_active_tween.tween_property(_arm_right, "rotation:z", deg_to_rad(15), 0.25)
	_active_tween.tween_callback(func(): _on_behavior_done("encourage"))


func _behavior_celebrate() -> void:
	# Beide Arme nach oben + 2x Hop
	if _arm_left != null:
		_arm_left.rotation.z = deg_to_rad(-150)
	if _arm_right != null:
		_arm_right.rotation.z = deg_to_rad(150)
	if _visual != null:
		_active_tween = create_tween()
		for i in range(2):
			(
				_active_tween
				. tween_property(_visual, "position:y", 0.35, 0.18)
				. set_trans(Tween.TRANS_QUAD)
				. set_ease(Tween.EASE_OUT)
			)
			(
				_active_tween
				. tween_property(_visual, "position:y", 0.0, 0.18)
				. set_trans(Tween.TRANS_QUAD)
				. set_ease(Tween.EASE_IN)
			)
		_active_tween.tween_callback(func(): _reset_pose_partial())
		_active_tween.tween_callback(func(): _on_behavior_done("celebrate"))


func _behavior_walk_loop() -> void:
	# Visual bobbing + Arm-Pendel (Loop). Keine echte Translation - LUMO
	# bleibt auf der Insel, wirkt aber als laufe er auf der Stelle.
	if _visual == null or _arm_left == null or _arm_right == null:
		return
	_active_tween = create_tween().set_loops()
	_active_tween.tween_callback(func(): _arm_left.rotation.z = deg_to_rad(-50))
	_active_tween.parallel().tween_callback(func(): _arm_right.rotation.z = deg_to_rad(50))
	_active_tween.tween_property(_visual, "position:y", 0.08, 0.30).set_trans(Tween.TRANS_SINE)
	_active_tween.tween_callback(func(): _arm_left.rotation.z = deg_to_rad(50))
	_active_tween.parallel().tween_callback(func(): _arm_right.rotation.z = deg_to_rad(-50))
	_active_tween.tween_property(_visual, "position:y", 0.0, 0.30).set_trans(Tween.TRANS_SINE)


func _behavior_jump_hop() -> void:
	if _visual == null:
		_emit_finished_after(0.6)
		return
	_active_tween = create_tween()
	# Anticipation
	_active_tween.tween_property(_visual, "position:y", -0.10, 0.10).set_trans(Tween.TRANS_QUAD)
	# Takeoff + Apex
	(
		_active_tween
		. tween_property(_visual, "position:y", 0.55, 0.20)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	# Landing
	(
		_active_tween
		. tween_property(_visual, "position:y", 0.0, 0.18)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_IN)
	)
	# Settle
	_active_tween.tween_property(_visual, "position:y", -0.05, 0.08)
	_active_tween.tween_property(_visual, "position:y", 0.0, 0.12)
	_active_tween.tween_callback(func(): _on_behavior_done("jump_hop"))


func _behavior_point_portal() -> void:
	if _arm_right == null:
		_emit_finished_after(0.6)
		return
	_active_tween = create_tween()
	_active_tween.tween_property(_arm_right, "rotation:z", deg_to_rad(95), 0.25)
	_active_tween.tween_interval(0.8)
	_active_tween.tween_property(_arm_right, "rotation:z", deg_to_rad(15), 0.25)
	_active_tween.tween_callback(func(): _on_behavior_done("point_portal"))


func _behavior_reward_star() -> void:
	# Beide Arme heben sich, Lumo praesentiert einen Stern
	if _arm_left != null:
		_arm_left.rotation.z = deg_to_rad(-100)
	if _arm_right != null:
		_arm_right.rotation.z = deg_to_rad(100)
	_emit_finished_after(0.8)


func _behavior_turn(target_rad: float) -> void:
	if _character_root == null:
		_emit_finished_after(0.4)
		return
	var current: float = _character_root.rotation.y
	_active_tween = create_tween()
	(
		_active_tween
		. tween_property(_character_root, "rotation:y", current + target_rad, 0.6)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	_active_tween.tween_callback(func(): _on_behavior_done("turn"))


func _emit_finished_after(seconds: float) -> void:
	var t: Tween = create_tween()
	t.tween_interval(seconds)
	t.tween_callback(func(): _on_behavior_done(_current_behavior))


func _on_behavior_done(name: String) -> void:
	EventBus.lumo_behavior_finished.emit(name)
