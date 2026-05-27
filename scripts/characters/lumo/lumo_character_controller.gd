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

@export var behavior_controller_path: NodePath
@export var eye_system_path: NodePath
@export var mouth_system_path: NodePath

@export var auto_idle_on_ready: bool = true

var _behavior: LumoBehaviorController
var _eyes: LumoEyeSystem
var _mouth: LumoMouthSystem


func _ready() -> void:
	_behavior = get_node_or_null(behavior_controller_path) as LumoBehaviorController
	_eyes = get_node_or_null(eye_system_path) as LumoEyeSystem
	_mouth = get_node_or_null(mouth_system_path) as LumoMouthSystem
	EventBus.companion_ready.emit()
	print("[Lumo] character_ready")
	if auto_idle_on_ready and _behavior != null:
		# Warte 1 Frame damit Sub-Systeme initialisiert sind
		await get_tree().process_frame
		_behavior.play_behavior("idle_bounce")


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
