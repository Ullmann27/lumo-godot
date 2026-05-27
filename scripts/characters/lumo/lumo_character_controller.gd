## LumoCharacterController
##
## Wurzel-Script auf lumo_character.tscn. Stellt den oeffentlichen
## High-Level-Zugriff bereit:
##   lumo.play_behavior(name)        -> BehaviorController
##   lumo.set_eye_state(state)       -> EyeSystem
##   lumo.set_brow_state(state)
##   lumo.set_mouth_shape(shape)     -> MouthSystem
##   lumo.speak_text_preview(text)
##   lumo.start_speaking() / stop_speaking()
##
## Diese Trennung hat einen Zweck: spaeter kann lumo_character.tscn das
## Visual durch ein echtes lumo_fox.glb ersetzen - die API bleibt
## identisch, Home- und Portal-Code muss nichts aendern.
class_name LumoCharacterController
extends Node3D

const AURA_BASE_ENERGY: float = 1.2
const AURA_PULSE_AMP: float = 0.30
const AURA_PULSE_SPEED: float = 1.4

@export var behavior_controller_path: NodePath
@export var eye_system_path: NodePath
@export var mouth_system_path: NodePath
@export var aura_path: NodePath = NodePath("Aura")

@export var auto_idle_on_ready: bool = true

var _behavior: LumoBehaviorController
var _eyes: LumoEyeSystem
var _mouth: LumoMouthSystem
var _aura: OmniLight3D
var _aura_time: float = 0.0
var _aura_target: float = AURA_BASE_ENERGY


func _ready() -> void:
	_behavior = get_node_or_null(behavior_controller_path) as LumoBehaviorController
	_eyes = get_node_or_null(eye_system_path) as LumoEyeSystem
	_mouth = get_node_or_null(mouth_system_path) as LumoMouthSystem
	_aura = get_node_or_null(aura_path) as OmniLight3D
	# Aura im LOW-Profil aus
	if _aura != null and Engine.has_singleton("PerformanceManager"):
		var pm: Node = Engine.get_singleton("PerformanceManager")
		if pm.has_method("get_profile_name") and pm.call("get_profile_name") == "low":
			_aura.visible = false
	EventBus.companion_ready.emit()
	EventBus.lumo_behavior_started.connect(_on_behavior_started)
	print("[Lumo] character_ready")
	if auto_idle_on_ready and _behavior != null:
		# Warte 1 Frame damit Sub-Systeme initialisiert sind
		await get_tree().process_frame
		_behavior.play_behavior("idle_bounce")


func _process(delta: float) -> void:
	if _aura == null or not _aura.visible:
		return
	_aura_time += delta * AURA_PULSE_SPEED
	var pulse: float = sin(_aura_time) * AURA_PULSE_AMP
	_aura.light_energy = lerp(
		_aura.light_energy, _aura_target + pulse, clamp(delta * 4.0, 0.0, 1.0)
	)


func _on_behavior_started(behavior: String) -> void:
	# Aura passt sich an: hoeher bei celebrate/reward, niedriger bei walk/jump
	match behavior:
		"celebrate", "reward_star":
			_aura_target = AURA_BASE_ENERGY * 2.0
		"walk_loop", "jump_hop":
			_aura_target = AURA_BASE_ENERGY * 0.6
		_:
			_aura_target = AURA_BASE_ENERGY


## High-Level API
func play_behavior(name: String) -> void:
	if _behavior == null:
		push_warning("[Lumo] kein BehaviorController angeschlossen")
		return
	_behavior.play_behavior(name)


func set_eye_state(state: String) -> void:
	if _eyes != null:
		_eyes.set_eye_state(state)


func set_brow_state(state: String) -> void:
	if _eyes != null:
		_eyes.set_brow_state(state)


func set_mouth_shape(shape: String) -> void:
	if _mouth != null:
		_mouth.set_mouth_shape(shape)


func speak_text_preview(text: String) -> void:
	if _mouth != null:
		_mouth.speak_text_preview(text)


func start_speaking() -> void:
	if _mouth != null:
		_mouth.start_speaking()


func stop_speaking() -> void:
	if _mouth != null:
		_mouth.stop_speaking()


func get_current_behavior() -> String:
	if _behavior == null:
		return ""
	return _behavior.get_current_behavior()
