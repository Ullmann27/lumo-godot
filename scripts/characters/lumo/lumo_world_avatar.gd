extends Node3D
## Der echte Lumo (geriggtes 65-Knochen-Modell) für Erkundungs- und
## Bühnenwelten wie Schatzsuche und Rhythmus. Dieser Knoten ist nur ein
## Dreh- und Haltepunkt: Seine -Z-Achse ist "vorn" (gleiche Konvention wie
## bisher), das Modell selbst schaut nach +Z und wird deshalb um PI gedreht.
## Die Füße stehen auf y = 0 dieses Knotens. Aussehen und Proportionen des
## Modells bleiben unverändert, nur die Größe wird einheitlich skaliert.
##
## Ist das Modell nicht ladbar (is_usable() == false), erscheint ersatzweise
## die alte Grundformen-Figur und es wird eine Warnung ausgegeben.
const ORIGINAL_LUMO = preload("res://scripts/characters/lumo/lumo_rigged_actor.gd")
const STAND_IN = preload("res://scripts/games/kart_vehicle.gd")
## Höhe des Modells in Ruhepose (Fußsohle bis Ohrspitze) bei Maßstab 1.
const MODEL_HEIGHT := 1.70

var rig: Node3D
var stand_in: Node3D
var height := 2.0
var reduced_motion := false
var _gesture := ""


## Baut den echten Lumo. Muss aufgerufen werden, wenn dieser Knoten bereits im
## Szenenbaum hängt, damit das Modell sofort geladen wird.
func setup(target_height: float, reduce_motion := false) -> bool:
	height = target_height
	reduced_motion = reduce_motion
	rig = ORIGINAL_LUMO.new()
	rig.name = "OriginalLumo"
	add_child(rig)
	if rig.is_usable():
		rig.scale = Vector3.ONE * (height / MODEL_HEIGHT)
		rig.rotation.y = PI
		rig.position.y = 0.0
		rig.set_reduced_motion(reduced_motion)
		rig.behavior_finished.connect(_on_behavior_finished)
		return true
	push_warning("[LumoWorldAvatar] Echter Lumo nicht ladbar; Notfall-Ersatzfigur aktiv")
	rig.queue_free()
	rig = null
	stand_in = STAND_IN.new()
	stand_in.name = "StandInFox"
	add_child(stand_in)
	stand_in.configure_companion("fox")
	stand_in.scale = Vector3.ONE * (height / 2.3)
	return false


func is_real() -> bool:
	return is_instance_valid(rig) and rig.is_usable()


func current_behavior() -> String:
	return str(rig.get_current_behavior()) if is_real() else ""


## Bewegung aus der tatsächlichen Geschwindigkeit nach move_and_slide().
## Stehen = idle-Clip, Gehen/Laufen = Lauf-Pose aus dem Bewegungssystem des
## Modells, in der Luft = Sprung-/Fallpose. Gesten laufen im Stand weiter.
func drive(velocity: Vector3, grounded: bool, delta: float, time: float) -> void:
	if is_real():
		var speed := Vector2(velocity.x, velocity.z).length()
		if not _gesture.is_empty() and grounded and speed <= 0.06:
			return
		_gesture = ""
		# Schrittfrequenz in Modellmetern, damit die Füße bei jeder Größe
		# nicht über den Boden rutschen (Gehen → Laufen ab ca. 2 m/s Modell).
		rig.set_platform_motion(velocity / maxf(rig.scale.x, 0.01), grounded, delta)
	elif is_instance_valid(stand_in):
		var moving := Vector2(velocity.x, velocity.z).length() > 0.3
		stand_in.set_companion_pose(time, "walk" if moving else "idle")


## Einmalige Geste (celebrate, greeting_wave, agree_nod, point_portal, idle).
func gesture(behavior: String) -> bool:
	if not is_real():
		return false
	if not rig.play_behavior(behavior):
		return false
	_gesture = "" if behavior == "idle" else behavior
	return true


func set_suspended(value: bool) -> void:
	if is_real():
		rig.set_suspended(value)


func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	if is_real():
		rig.set_reduced_motion(value)


## Stimmung für die Ersatzfigur (nur im Notfall sichtbar).
func stand_in_pose(time: float, mood: String) -> void:
	if is_instance_valid(stand_in):
		stand_in.set_companion_pose(time, mood)


func _on_behavior_finished(behavior: String) -> void:
	if behavior == _gesture:
		_gesture = ""
