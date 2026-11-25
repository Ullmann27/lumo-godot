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
var _riffle: Tween
var _look := ""
var _suspended := false


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
	return (_move != null and _move.is_valid()) or (_riffle != null and _riffle.is_valid())


func set_suspended(value: bool) -> void:
	_suspended = value
	for motion: Tween in [_move, _riffle]:
		if motion != null and motion.is_valid():
			if value:
				motion.pause()
			else:
				motion.play()


func stop() -> void:
	if _move != null and _move.is_valid():
		_move.kill()
	_move = null
	if _riffle != null and _riffle.is_valid():
		_riffle.kill()
	_riffle = null


func snap_to(target: Transform3D) -> void:
	stop()
	transform = target


## Fliegt im Bogen zum Ziel (lokaler Raum des Elternknotens).
func fly_to(target: Transform3D, duration: float, delay: float = 0.0, arc: float = 0.0, spin: float = 0.0) -> Tween:
	# Ein laufendes Mischen darf zu Ende spielen; der Flug wartet auf seine Verzögerung.
	if _move != null and _move.is_valid():
		_move.kill()
	_move = null
	if duration <= 0.001:
		stop()
		transform = target
		return null
	var from := transform
	_move = create_tween()
	if delay > 0.0:
		_move.tween_interval(delay)
	_move.tween_method(_step.bind(from, target, arc, spin), 0.0, 1.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	if _suspended:
		_move.pause()
	return _move


func _step(t: float, from: Transform3D, target: Transform3D, arc: float, spin: float) -> void:
	var now := from.interpolate_with(target, t)
	var lift := 4.0 * t * (1.0 - t)
	now.origin += Vector3.UP * arc * lift
	if spin != 0.0:
		now.basis = now.basis * Basis(Vector3.UP, spin * (1.0 - t) * lift)
	if arc > 0.0:
		# Geworfene Karten kippen in der Luft leicht über die Längsachse und
		# landen flach – wie ein Schnipsen aus dem Handgelenk.
		now.basis = now.basis * Basis(Vector3.FORWARD, 0.35 * lift * signf(spin if spin != 0.0 else 1.0))
		# Kurz vor dem Aufsetzen drückt die Luft die Karte noch einmal an.
		if t > 0.82:
			now.origin.y -= 0.004 * sin((t - 0.82) / 0.18 * PI)
	transform = now


## Mischen: die Karte rutscht zu einer Hälfte des Stapels und fällt
## verschränkt zurück (Riffle). Rein optisch, ändert keine Zuordnung.
func riffle(side: float, height: float, duration: float, delay: float = 0.0) -> void:
	if _riffle != null and _riffle.is_valid():
		_riffle.kill()
	if duration <= 0.001:
		return
	var home := transform
	var apart := home
	apart.origin += Vector3(side * 0.2, 0.02 + height, 0.0)
	apart.basis = home.basis * Basis(Vector3.FORWARD, side * 0.28) * Basis(Vector3.UP, side * 0.12)
	_riffle = create_tween()
	if delay > 0.0:
		_riffle.tween_interval(delay)
	_riffle.tween_method(func(t: float) -> void: transform = home.interpolate_with(apart, t), 0.0, 1.0, duration * 0.45) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_riffle.tween_method(func(t: float) -> void: transform = apart.interpolate_with(home, t), 0.0, 1.0, duration * 0.55) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if _suspended:
		_riffle.pause()


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
