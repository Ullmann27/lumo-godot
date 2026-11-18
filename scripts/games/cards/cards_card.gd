extends Node3D
## Eine Karte des Sternendecks als 3D-Objekt. Liegt flach in der XZ-Ebene,
## Vorderseite nach oben. Bewegt sich im Bogen von Ort zu Ort.

const ART = preload("res://scripts/games/cards/cards_deck_art.gd")

var card_id := -1
var zone := ""
var owner_seat := -1
var order := 0
var playable := false
var body: MeshInstance3D
var glow: MeshInstance3D
var _move: Tween
var _look := ""


func setup(id: int) -> void:
	card_id = id
	name = "Card%d" % id
	body = MeshInstance3D.new()
	body.mesh = ART.card_mesh(id)
	add_child(body)
	set_look("table")


func set_look(kind: String) -> void:
	if _look == kind:
		return
	_look = kind
	body.material_override = ART.material(kind)
	body.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if kind in ["hand", "dim"]
		else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	)


func look() -> String:
	return _look


## Leuchtrahmen unter der Karte; Color(0,0,0,0) schaltet ihn ab.
func set_glow(color: Color) -> void:
	if color.a <= 0.0:
		if glow != null:
			glow.visible = false
		return
	if glow == null:
		glow = MeshInstance3D.new()
		glow.mesh = ART.glow_mesh()
		glow.position.y = -ART.THICKNESS
		glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(glow)
	glow.material_override = ART.glow_material(color)
	glow.visible = true


func is_moving() -> bool:
	return _move != null and _move.is_valid() and _move.is_running()


func stop() -> void:
	if _move != null and _move.is_valid():
		_move.kill()
	_move = null


func snap_to(target: Transform3D) -> void:
	stop()
	transform = target


## Fliegt im Bogen zum Ziel (lokaler Raum des Elternknotens).
func fly_to(target: Transform3D, duration: float, delay: float = 0.0, arc: float = 0.0, spin: float = 0.0) -> Tween:
	stop()
	if duration <= 0.001:
		transform = target
		return null
	var from := transform
	_move = create_tween()
	if delay > 0.0:
		_move.tween_interval(delay)
	_move.tween_method(_step.bind(from, target, arc, spin), 0.0, 1.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return _move


func _step(t: float, from: Transform3D, target: Transform3D, arc: float, spin: float) -> void:
	var now := from.interpolate_with(target, t)
	var lift := 4.0 * t * (1.0 - t)
	now.origin += Vector3.UP * arc * lift
	if spin != 0.0:
		now.basis = now.basis * Basis(Vector3.UP, spin * (1.0 - t) * lift)
	transform = now


## Kurzes Kopfschütteln der Karte: „geht gerade nicht“.
func refuse() -> void:
	var base := body.position
	var shake := create_tween()
	for offset: float in [0.018, -0.016, 0.010, -0.006, 0.0]:
		shake.tween_property(body, "position:x", base.x + offset, 0.045)


## Trifft der Strahl die Karte? Gibt die Entfernung oder -1 zurück.
func ray_hit(origin: Vector3, direction: Vector3, grow: float = 0.0) -> float:
	var inverse := global_transform.affine_inverse()
	var local_origin := inverse * origin
	var local_direction := inverse.basis * direction
	if absf(local_direction.y) < 0.0001:
		return -1.0
	var distance := -local_origin.y / local_direction.y
	if distance <= 0.0:
		return -1.0
	var hit := local_origin + local_direction * distance
	if absf(hit.x) <= ART.WIDTH * 0.5 + grow and absf(hit.z) <= ART.HEIGHT * 0.5 + grow:
		return distance
	return -1.0
