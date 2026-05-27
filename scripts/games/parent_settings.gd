## ParentSettings - einfaches Settings-Panel: Quality-Profile waehlen
##   + Audio-Toggle (Master-Bus mute) + Zurueck zum Home.
##
## Speichert KEINE Persistenz aktuell (user://settings.cfg waere naechster
## Schritt). Anpassungen wirken zur Laufzeit.
extends Node

@export var low_button_path: NodePath
@export var medium_button_path: NodePath
@export var high_button_path: NodePath
@export var audio_button_path: NodePath
@export var back_button_path: NodePath
@export var profile_label_path: NodePath

var _audio_muted: bool = false


func _ready() -> void:
	_wire_button(low_button_path, _on_low)
	_wire_button(medium_button_path, _on_medium)
	_wire_button(high_button_path, _on_high)
	_wire_button(audio_button_path, _on_audio_toggle)
	_wire_button(back_button_path, _back_to_home)
	if Engine.has_singleton("AudioManager"):
		_audio_muted = Engine.get_singleton("AudioManager").is_muted()
	_update_profile_label()
	print("[Parent] scene_loaded")


func _wire_button(path: NodePath, cb: Callable) -> void:
	var b: Button = get_node_or_null(path) as Button
	if b != null:
		b.pressed.connect(cb)


func _on_low() -> void:
	PerformanceManager.set_profile(PerformanceManager.Profile.LOW)
	_update_profile_label()


func _on_medium() -> void:
	PerformanceManager.set_profile(PerformanceManager.Profile.MEDIUM)
	_update_profile_label()


func _on_high() -> void:
	PerformanceManager.set_profile(PerformanceManager.Profile.HIGH)
	_update_profile_label()


func _on_audio_toggle() -> void:
	_audio_muted = not _audio_muted
	if Engine.has_singleton("AudioManager"):
		Engine.get_singleton("AudioManager").set_muted(_audio_muted)
	else:
		AudioServer.set_bus_mute(0, _audio_muted)
	print("[Parent] audio_muted:%s" % _audio_muted)
	_update_profile_label()


func _update_profile_label() -> void:
	var label: Label = get_node_or_null(profile_label_path) as Label
	if label == null:
		return
	var p: String = (
		PerformanceManager.get_profile_name() if Engine.has_singleton("PerformanceManager") else "?"
	)
	var audio: String = "AUS" if _audio_muted else "AN"
	label.text = "Profil: %s\nAudio: %s" % [p.to_upper(), audio]


func _back_to_home() -> void:
	SceneRouter.goto("home")
