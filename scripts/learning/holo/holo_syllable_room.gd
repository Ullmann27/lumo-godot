extends Node3D
## Holo-Raum „Silben klatschen“: Das Wort steht als große, ungeteilte Karte
## da (die Trennung ist nicht zu sehen), dahinter – wo vorhanden – das Bild.
## Vor der Karte liegt die Klatschleiste: Jeder Klatscher des Kindes legt dort
## eine leuchtende Klatschmarke ab. Erst nach der richtigen Antwort oder in der
## ausführlichen Hilfe teilt sich die Karte in Silbenkarten mit Silbenbögen.

const MODELS = preload("res://scripts/learning/holo/holo_models.gd")
const FIGURES = preload("res://scripts/learning/holo/holo_figures.gd")
const WORDS = preload("res://scripts/learning/holo/holo_word_room.gd")
const CARD_HEIGHT := 1.35
const CARD_Y := 0.86
const SYLLABLE_GAP := 0.45
const TOKEN_STEP := 0.72
const TOKEN_Z := 1.75
const PICTURE_Z := -2.1

var reduced_motion := false
var calm_holograms := false
var word := ""
var syllables: Array[String] = []
var word_card: Node3D
var syllable_cards: Array[Node3D] = []
var arcs: Array[Node3D] = []
var tokens: Array[Node3D] = []
var picture: Node3D
var split_shown := false
var _face_basis := Basis.IDENTITY
var _word_width := 2.0
var _tray_width := 4.6
var _tweens: Array[Tween] = []
var _clock := 0.0


func build(task: Dictionary, facing: Basis) -> void:
	for child in get_children():
		child.free()
	syllable_cards.clear()
	arcs.clear()
	tokens.clear()
	picture = null
	split_shown = false
	_face_basis = facing
	word = str(task.word)
	syllables.assign(task.syllables)
	_word_width = maxf(2.4, 0.7 + 0.42 * word.length())
	var shelf := _bar(_word_width + 0.9, 0.9)
	shelf.position = Vector3(0, 0, 0)
	add_child(shelf)
	word_card = WORDS.card_node(word, _word_width, _face_basis, CARD_HEIGHT, 210)
	word_card.name = "Wortkarte"
	word_card.position = Vector3(0, CARD_Y, 0)
	_rest_shadow(word_card, _word_width)
	add_child(word_card)
	_tray_width = maxf(_word_width, TOKEN_STEP * 6.0) + 0.4
	var tray := _bar(_tray_width, 1.0)
	tray.name = "Klatschleiste"
	tray.position = Vector3(0, 0, TOKEN_Z)
	add_child(tray)
	var picture_id := str(task.get("picture", ""))
	if not picture_id.is_empty():
		picture = Node3D.new()
		picture.name = "Bild"
		picture.position = Vector3(0, 0.02, PICTURE_Z)
		add_child(picture)
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.78
		torus.outer_radius = 0.86
		torus.rings = 40
		ring.mesh = torus
		ring.material_override = MODELS.holo_material(Color("8ff0ff"), 1.4)
		if calm_holograms:
			ring.material_override.set_shader_parameter("lines", 0.0)
		picture.add_child(ring)
		var figure := FIGURES.build(picture_id)
		figure.name = "Figur"
		figure.scale = Vector3.ONE * 1.7
		figure.rotation.y = -0.5
		picture.add_child(figure)


func _bar(width: float, depth: float) -> Node3D:
	var bar := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, 0.16, depth)
	bar.mesh = mesh
	bar.material_override = MODELS.with_outline(
		MODELS.rim_material(Color("173c5e"), Color("8ff0ff"), 0.4), Color("6fe3ff"), 0.02
	)
	bar.position.y = 0.08
	var root := Node3D.new()
	root.add_child(bar)
	return root


func _rest_shadow(card: Node3D, width: float) -> void:
	var shadow: MeshInstance3D = card.get_node("Schatten")
	shadow.position = Vector3(0, 0.17 - card.position.y, 0.3)
	shadow.scale = Vector3(width / (width + 0.2) * 1.05, 1, 1.3)


func _process(delta: float) -> void:
	_clock += delta
	if is_instance_valid(picture) and not reduced_motion:
		picture.get_node("Figur").rotation.y = -0.5 + sin(_clock * 0.8) * 0.35


func _track(tween: Tween) -> Tween:
	_tweens.append(tween)
	return tween


func finish_motion() -> void:
	for tween in _tweens:
		if tween.is_valid() and tween.is_running():
			tween.custom_step(30.0)
	_tweens.clear()


# ---------------------------------------------------------------- Klatschen


## Eine Klatschmarke auf der Leiste (n = Anzahl nach dem Klatscher).
func add_token(count: int) -> void:
	while tokens.size() < count:
		var token := _token()
		token.name = "Klatschmarke%d" % tokens.size()
		add_child(token)
		tokens.append(token)
		if not reduced_motion:
			token.scale = Vector3.ONE * 0.2
			var tween := _track(create_tween())
			tween.tween_property(token, "scale", Vector3.ONE * 1.15, 0.12)
			tween.tween_property(token, "scale", Vector3.ONE, 0.1)
	_arrange_tokens()


func clear_tokens() -> void:
	for token in tokens:
		token.queue_free()
	tokens.clear()


func _arrange_tokens() -> void:
	var start := -(tokens.size() - 1) * TOKEN_STEP * 0.5
	for index in range(tokens.size()):
		tokens[index].position = Vector3(start + index * TOKEN_STEP, 0.2, TOKEN_Z)


## Klatschmarke: zwei kleine Hände (Handflächen aneinander) auf einer
## leuchtenden Scheibe – ohne Ziffer, nur zum Mitzählen.
func _token() -> Node3D:
	var root := Node3D.new()
	var disc := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.28
	mesh.bottom_radius = 0.3
	mesh.height = 0.06
	mesh.radial_segments = 28
	disc.mesh = mesh
	disc.material_override = MODELS.with_outline(
		MODELS.rim_material(Color("ffcf4a"), Color("fff1b8"), 0.4), Color("ffe58a"), 0.018
	)
	root.add_child(disc)
	for side in [-1.0, 1.0]:
		FIGURES.part(
			root,
			FIGURES.capsule(0.07, 0.3),
			Color("f6efe4"),
			Vector3(side * 0.055, 0.2, 0),
			Vector3(0, 0, side * -14),
			Vector3(1, 1, 0.55)
		)
	return root


# ---------------------------------------------------------------- Silben


## Breite der Silbenkarte und Mittelpunkte nach dem Teilen.
func syllable_layout() -> Array[Vector3]:
	var widths := _syllable_widths()
	var total := SYLLABLE_GAP * (widths.size() - 1)
	for width in widths:
		total += width
	var points: Array[Vector3] = []
	var x := -total * 0.5
	for width in widths:
		points.append(Vector3(x + width * 0.5, CARD_Y, 0))
		x += width + SYLLABLE_GAP
	return points


func _syllable_widths() -> Array[float]:
	var widths: Array[float] = []
	for part in syllables:
		widths.append(maxf(1.1, 0.45 + 0.38 * part.length()))
	return widths


## Die Karte teilt sich: Silbenkarten gleiten auseinander, unter jeder wächst
## ein Silbenbogen. Bei ruhiger Bewegung stehen sie sofort da.
func split(seconds: float = 0.55) -> void:
	if split_shown:
		return
	split_shown = true
	word_card.visible = false
	var widths := _syllable_widths()
	var targets := syllable_layout()
	var x := -_word_width * 0.5
	var letters := float(word.length())
	for index in range(syllables.size()):
		var card := WORDS.card_node(syllables[index], widths[index], _face_basis, CARD_HEIGHT, 210)
		card.name = "Silbe%d" % index
		var share := syllables[index].length() / letters * _word_width
		card.position = Vector3(x + share * 0.5, CARD_Y, 0)
		x += share
		_rest_shadow(card, widths[index])
		add_child(card)
		syllable_cards.append(card)
		var arc := _arc(widths[index] * 0.82)
		arc.name = "Silbenbogen%d" % index
		arc.position = targets[index] + _face_basis.y * -(CARD_HEIGHT * 0.5 + 0.12)
		arc.position += _face_basis.z * 0.12
		add_child(arc)
		arcs.append(arc)
		if reduced_motion or seconds <= 0.0:
			card.position = targets[index]
			continue
		arc.scale = Vector3(0.05, 0.05, 1)
		var tween := _track(create_tween())
		tween.tween_property(card, "position", targets[index], seconds).set_trans(Tween.TRANS_BACK)
		tween.parallel().tween_property(arc, "scale", Vector3.ONE, seconds)


## Zurück zur ganzen Karte (neue Aufgabe oder neuer Versuch).
func merge() -> void:
	for node in syllable_cards + arcs:
		node.queue_free()
	syllable_cards.clear()
	arcs.clear()
	split_shown = false
	word_card.visible = true


## Silbenbogen: ein leuchtender Bogen unter der Silbe (wie im Heft).
func _arc(width: float) -> Node3D:
	var root := Node3D.new()
	var path := PackedVector3Array()
	for step in range(15):
		var angle := PI + PI * step / 14.0
		path.append(Vector3(cos(angle) * width * 0.5, sin(angle) * 0.24 + 0.24, 0))
	var bow := MeshInstance3D.new()
	bow.mesh = MODELS.tube(path, 0.045, 8)
	bow.material_override = MODELS.flat(Color("ffd96b"), 2.0)
	bow.basis = _face_basis
	bow.position = _face_basis.y * -0.24
	bow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(bow)
	return root


## Silbe leuchtet im Takt von Lumos Klatscher.
func pulse_syllable(index: int) -> void:
	if index < 0 or index >= syllable_cards.size():
		return
	var card := syllable_cards[index]
	WORDS.card_glow(card, 0.9)
	if reduced_motion:
		return
	var rest: Vector3 = syllable_layout()[index]
	var tween := _track(create_tween())
	tween.tween_property(card, "position", rest + Vector3(0, 0.28, 0), 0.1)
	tween.tween_property(card, "position", rest, 0.16)


func clear_glow() -> void:
	for card in syllable_cards:
		WORDS.card_glow(card, 0.0)
	if is_instance_valid(word_card):
		WORDS.card_glow(word_card, 0.0)


## Antippen der Wortkarte (vorlesen): kurzes Leuchten.
func flash_word() -> void:
	WORDS.card_glow(word_card, 0.6)


# ---------------------------------------------------------------- Rahmen


func card_rect(camera: Camera3D) -> Rect2:
	var half := Vector2(_word_width * 0.5, CARD_HEIGHT * 0.5)
	var center := word_card.global_position
	var rect := Rect2(camera.unproject_position(center), Vector2.ZERO)
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var offset: Vector3 = _face_basis.x * half.x * corner.x + _face_basis.y * half.y * corner.y
		rect = rect.expand(camera.unproject_position(center + offset))
	return rect


func hits_word(camera: Camera3D, point: Vector2) -> bool:
	return card_rect(camera).grow(8.0).has_point(point)


func split_width() -> float:
	var total := SYLLABLE_GAP * (syllables.size() - 1)
	for width in _syllable_widths():
		total += width
	return total


func half_width() -> float:
	return maxf(maxf(_tray_width, _word_width), split_width()) * 0.5


func lumo_spot(half_width_fox: float) -> Vector3:
	return Vector3(half_width() + 0.5 + half_width_fox, 0, -0.6)


func content_boxes() -> Array[AABB]:
	# Platz für die geteilte Karte schon von Anfang an: Die Bühne springt nicht.
	var width := maxf(maxf(_tray_width, _word_width + 0.9), split_width() + 0.4)
	var boxes: Array[AABB] = [
		AABB(Vector3(-width * 0.5, 0, -0.6), Vector3(width, CARD_Y + CARD_HEIGHT * 0.6, 0.9 + 0.6)),
		AABB(Vector3(-_tray_width * 0.5, 0, TOKEN_Z - 0.5), Vector3(_tray_width, 0.6, 1.0)),
	]
	if is_instance_valid(picture):
		boxes.append(AABB(Vector3(-0.9, 0, PICTURE_Z - 0.9), Vector3(1.8, 2.0, 1.8)))
	return boxes
