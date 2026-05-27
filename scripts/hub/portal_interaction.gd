## PortalInteraction - 3D-Touch-Target fuer ein Hub-Portal.
##
## - grosse Area3D Hitbox (Sphere r=1.6) fuer Mobile-Touch
## - Idle-Rotation um Y
## - Tap -> Scale-Pulse 1.0 -> 1.18 -> 1.0 + EventBus.portal_selected
## - Farbe pro portal_type (learn=gold, games=tuerkis, parent=violett)
extends Node3D

const PORTAL_COLORS: Dictionary = {
	"learn": Color(1.00, 0.78, 0.30, 1),
	"games": Color(0.30, 0.85, 0.85, 1),
	"parent": Color(0.62, 0.50, 0.95, 1),
}

const PORTAL_LABELS: Dictionary = {
	"learn": "Lernen",
	"games": "Spiele",
	"parent": "Eltern",
}

@export var portal_type: String = "learn"
@export var idle_rotation_speed: float = 0.35


func _ready() -> void:
	_apply_type()
	var area: Area3D = $TouchArea as Area3D
	if area != null:
		area.input_event.connect(_on_area_input_event)


func set_portal_type(new_type: String) -> void:
	portal_type = new_type
	if is_inside_tree():
		_apply_type()


func _apply_type() -> void:
	var color: Color = PORTAL_COLORS.get(portal_type, Color(1, 1, 1, 1))
	var ring: MeshInstance3D = $Ring as MeshInstance3D
	if ring != null:
		var mat: StandardMaterial3D = ring.material_override as StandardMaterial3D
		if mat == null:
			mat = StandardMaterial3D.new()
			ring.material_override = mat
		mat.albedo_color = color
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 1.4
		mat.metallic = 0.10
		mat.roughness = 0.30
	var label: Label3D = $Label as Label3D
	if label != null:
		label.text = PORTAL_LABELS.get(portal_type, portal_type)
		label.modulate = Color(1, 1, 1, 1)


func _process(delta: float) -> void:
	rotation.y += idle_rotation_speed * delta


func _on_area_input_event(
	_camera: Camera3D,
	event: InputEvent,
	_pos: Vector3,
	_normal: Vector3,
	_shape_idx: int,
) -> void:
	var triggered: bool = false
	if event is InputEventScreenTouch and event.pressed:
		triggered = true
	elif (
		event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	):
		triggered = true
	if not triggered:
		return
	_pulse()
	EventBus.portal_selected.emit(portal_type)


func _pulse() -> void:
	var ring: MeshInstance3D = $Ring as MeshInstance3D
	if ring == null:
		return
	var tw: Tween = create_tween()
	tw.tween_property(ring, "scale", Vector3.ONE * 1.18, 0.10).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_OUT
	)
	tw.tween_property(ring, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_IN_OUT
	)
