## Einfache, fluessige Rotation um die Y- und X-Achse.
## An eine MeshInstance3D (oder beliebige Node3D) gehaengt, dreht sich
## das Objekt sichtbar - so weiss man: die Engine laeuft.
##
## Sendet `rotation_speed_changed` via EventBus wenn die Geschwindigkeit
## sich aendert - Demo der Event-Bus-Architektur.
class_name Rotator
extends Node3D

## Rotationsgeschwindigkeit in Radian pro Sekunde.
@export var speed_y: float = 1.2
@export var speed_x: float = 0.6

var _last_emitted_y: float = -1.0
var _last_emitted_x: float = -1.0


func _ready() -> void:
	_emit_speed_change()


func _process(delta: float) -> void:
	# Schluesselwort 'rotation' ist ein Vector3 in Radian.
	# delta = Sekunden seit dem letzten Frame -> Framerate-unabhaengig.
	rotation.y += speed_y * delta
	rotation.x += speed_x * delta


## Aenderung der Rotationsgeschwindigkeit zur Laufzeit, sendet Signal.
func set_speed(new_y: float, new_x: float) -> void:
	speed_y = new_y
	speed_x = new_x
	_emit_speed_change()


func _emit_speed_change() -> void:
	if speed_y == _last_emitted_y and speed_x == _last_emitted_x:
		return
	_last_emitted_y = speed_y
	_last_emitted_x = speed_x
	EventBus.rotation_speed_changed.emit(speed_y, speed_x)
