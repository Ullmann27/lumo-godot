## Einfache, fluessige Rotation um die Y- und X-Achse.
## An eine MeshInstance3D (oder beliebige Node3D) gehaengt, dreht sich
## das Objekt sichtbar - so weiss man: die Engine laeuft.
class_name Rotator
extends Node3D

## Rotationsgeschwindigkeit in Radian pro Sekunde.
@export var speed_y: float = 1.2
@export var speed_x: float = 0.6


func _process(delta: float) -> void:
	# Schluesselwort 'rotation' ist ein Vector3 in Radian.
	# delta = Sekunden seit dem letzten Frame -> Framerate-unabhaengig.
	rotation.y += speed_y * delta
	rotation.x += speed_x * delta
