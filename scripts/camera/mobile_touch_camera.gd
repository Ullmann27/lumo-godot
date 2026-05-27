## MobileTouchCamera - Touch-Orbit-Kamera fuer Home-Szene.
##
## Verhalten:
##   - Drag (Touch oder Maus mit gedrueckter Taste) -> Orbit yaw/pitch
##   - clamp Pitch in einem kindgerechten engen Bereich
##   - Tap (Distanz <8 px UND Dauer <250 ms) -> Event NICHT verbrauchen
##     damit Area3D der Portale weiter Picking machen koennen
##   - Mouse-Wheel zoomt Radius (Desktop), Pinch waere fuer spaeter
##
## Anhaengen an Camera3D-Knoten mit target = "../Lumo" oder Insel-Mitte.
extends Camera3D

const TAP_MAX_DISTANCE: float = 8.0
const TAP_MAX_DURATION_MS: int = 250

@export var target_path: NodePath
@export var radius: float = 6.0
@export var radius_min: float = 4.0
@export var radius_max: float = 9.0
@export var yaw: float = 0.0
@export var pitch: float = -0.25
@export var pitch_min: float = -0.45
@export var pitch_max: float = -0.05
@export var sensitivity_yaw: float = 0.006
@export var sensitivity_pitch: float = 0.005
@export var follow_lerp_speed: float = 8.0

var _press_position: Vector2 = Vector2.ZERO
var _press_time_ms: int = 0
var _is_dragging: bool = false


func _ready() -> void:
	_update_position_immediate()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_press_release(event.pressed, event.position)
	elif event is InputEventScreenDrag:
		_handle_drag(event.relative)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_handle_press_release(event.pressed, event.position)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			radius = clamp(radius + 0.4, radius_min, radius_max)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			radius = clamp(radius - 0.4, radius_min, radius_max)
	elif event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_handle_drag(event.relative)


func _handle_press_release(pressed: bool, pos: Vector2) -> void:
	if pressed:
		_press_position = pos
		_press_time_ms = Time.get_ticks_msec()
		_is_dragging = false
		# nicht claimen - falls Tap, soll Area3D picken
	else:
		var dist: float = pos.distance_to(_press_position)
		var duration: int = Time.get_ticks_msec() - _press_time_ms
		if dist <= TAP_MAX_DISTANCE and duration <= TAP_MAX_DURATION_MS:
			# Tap - Event NICHT verbrauchen
			pass
		_is_dragging = false


func _handle_drag(relative: Vector2) -> void:
	# Sobald sich der Finger bewegt UND ueber Tap-Schwelle wandert,
	# beanspruchen wir die Geste als Drag.
	if not _is_dragging:
		var dist: float = relative.length()
		if dist <= 0.0:
			return
	_is_dragging = true
	yaw -= relative.x * sensitivity_yaw
	pitch = clamp(pitch - relative.y * sensitivity_pitch, pitch_min, pitch_max)
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	var target: Node3D = get_node_or_null(target_path) as Node3D
	var center: Vector3 = Vector3.ZERO
	if target != null:
		center = target.global_position
	var offset: Vector3 = Vector3(
		radius * cos(pitch) * sin(yaw),
		-radius * sin(pitch),
		radius * cos(pitch) * cos(yaw),
	)
	var desired: Vector3 = center + offset
	position = position.lerp(desired, clamp(delta * follow_lerp_speed, 0.0, 1.0))
	look_at(center, Vector3.UP)


func _update_position_immediate() -> void:
	var target: Node3D = get_node_or_null(target_path) as Node3D
	var center: Vector3 = Vector3.ZERO
	if target != null:
		center = target.global_position
	var offset: Vector3 = Vector3(
		radius * cos(pitch) * sin(yaw),
		-radius * sin(pitch),
		radius * cos(pitch) * cos(yaw),
	)
	position = center + offset
	look_at(center, Vector3.UP)
