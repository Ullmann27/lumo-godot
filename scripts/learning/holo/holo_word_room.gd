# gdlint: disable=max-public-methods
# Darstellung und Treffer des Deutsch-Raums: jede Methode ist ein Baustein der Hilfe.
extends Node3D
## Holo-Raum für Deutsch: gleichfarbige, greifbare Wortkarten.
## Tunwort/Namenwort: Karten in Satzreihenfolge, eine Karte wählen und ins
## Feld legen. Satzbau: gemischte Karten auf dem Tablett, Satzleiste mit
## gleich breiten Feldern. Keine Karte ist farblich oder durch ihre Lage als
## Lösung erkennbar. Im Hochformat bricht der Satz in zwei Zeilen um (wie in
## einem Buch), damit die Karten groß bleiben.

const MODELS = preload("res://scripts/learning/holo/holo_models.gd")
const FIGURES = preload("res://scripts/learning/holo/holo_figures.gd")
const CARD_HEIGHT := 1.0
const CARD_DEPTH := 0.16
const GAP := 0.18
const REST_Y := 0.72
const SHELF_TOP := 0.16
const ROW_DZ := 2.35
## Zeilenbreite, ab der im Hochformat umgebrochen wird.
const WRAP_WIDTH := 5.0
const CAPTIONS := {"verb": "Tunwort", "noun": "Namenwort", "adjective": "Wiewort"}
const HALO_IDLE := Color("6fdcff")
const HALO_LIFT := Color("ffd34d")
const HALO_HINT := Color("8af7c4")

var reduced_motion := false
## LOW-Profil: Hologramm ohne wandernde Rasterlinien.
var calm_holograms := false
var mode := "verb"
var words: Array[String] = []
var cards: Array[Node3D] = []
var widths: Array[float] = []
var home: Array[Vector3] = []
var slots: Array[Vector3] = []
var slot_nodes: Array[MeshInstance3D] = []
var selected := -1
var answer_field: Node3D
var full_stop: Label3D
var picture: Node3D
## Wiewort-Hilfe: zwei Figuren, die sich in Größe oder Farbe unterscheiden.
var contrast: Node3D
## Zeilen der Kartenreihe bzw. des Tabletts (z-Lage je Zeile).
var row_z: Array[float] = []
var row_half_width := 0.0
var _tweens: Array[Tween] = []
var _face_basis := Basis.IDENTITY
var _floor: Array[float] = []
var _box := AABB()
var _clock := 0.0
var _field_width := 3.6


func build(
	task: Dictionary, card_mode: String, order: Array[int], facing: Basis, narrow: bool = false
) -> void:
	for child in get_children():
		child.free()
	cards.clear()
	widths.clear()
	home.clear()
	slots.clear()
	slot_nodes.clear()
	row_z.clear()
	_floor.clear()
	picture = null
	contrast = null
	answer_field = null
	full_stop = null
	selected = -1
	mode = card_mode
	_face_basis = facing
	words.clear()
	for word: String in task.words:
		words.append(word)
	for word in words:
		widths.append(maxf(1.15, 0.36 + 0.27 * word.length()))
	for index in range(words.size()):
		var card := _card(words[index], widths[index])
		card.name = "Wortkarte%d" % index
		add_child(card)
		cards.append(card)
		home.append(Vector3.ZERO)
		_floor.append(SHELF_TOP)
	var sentence_order: Array[int] = []
	for index in range(words.size()):
		sentence_order.append(index)
	if mode == "order":
		_build_order(order, narrow)
	else:
		_build_pick(sentence_order, narrow)
	for index in range(words.size()):
		cards[index].position = home[index]
		_update_shadow(index)


## Tunwort/Namenwort: Karten in Satzreihenfolge, davor das Antwortfeld.
func _build_pick(sentence_order: Array[int], narrow: bool) -> void:
	var rows := _split(sentence_order, narrow)
	var z0 := -0.5 * ROW_DZ * (rows.size() - 1) - 0.6
	row_half_width = 0.0
	for row in range(rows.size()):
		var z := z0 + row * ROW_DZ
		row_z.append(z)
		_place_row(rows[row], z)
		var shelf := _shelf(_width_of(rows[row]) + 0.7)
		shelf.position = Vector3(0, 0, z)
		add_child(shelf)
	if mode == "strip":
		# Nur der Satz als Kartenleiste (Lesen): kein Antwortfeld.
		_box = AABB(
			Vector3(-row_half_width - 0.35, 0, row_z[0] - 0.6),
			Vector3(row_half_width * 2.0 + 0.7, 1.4, row_z[-1] - row_z[0] + 1.2)
		)
		return
	# Genug Abstand, damit Karte und Bild im Feld keine Karte der Reihe verdecken.
	var field_z := row_z[-1] + 2.7
	# Links im Feld ist Platz für das Bild (Namenwort), rechts liegt die Karte.
	_field_width = maxf(3.6, _widest() + 2.1)
	answer_field = _field(_field_width, CAPTIONS.get(mode, ""))
	answer_field.position = Vector3(0, 0.02, field_z)
	add_child(answer_field)
	_box = AABB(
		Vector3(-row_half_width - 0.35, 0, row_z[0] - 0.6),
		Vector3(row_half_width * 2.0 + 0.7, 1.4, field_z + 1.0 - (row_z[0] - 0.6))
	)


## Satzbau: hinten die Satzleiste mit gleich breiten Feldern, vorn das Tablett.
func _build_order(order: Array[int], narrow: bool) -> void:
	var uniform := 0.0
	for width in widths:
		uniform += width
	# Alle Felder gleich breit (mittlere Kartenbreite + Rand, mindestens die
	# breiteste Karte): Die Feldbreite verrät kein Wort.
	uniform = maxf(uniform / widths.size() + 0.1, _widest() + 0.06)
	var per_row := words.size()
	if narrow and uniform * words.size() + GAP * (words.size() - 1) > WRAP_WIDTH:
		per_row = int(ceil(words.size() / 2.0))
	var rail_rows := int(ceil(float(words.size()) / per_row))
	var z0 := -0.6 - ROW_DZ * (rail_rows - 1)
	row_half_width = 0.0
	for index in range(words.size()):
		var row := index / per_row
		var in_row := mini(per_row, words.size() - row * per_row)
		var total := uniform * in_row + GAP * (in_row - 1)
		var x := -total * 0.5 + (index % per_row) * (uniform + GAP) + uniform * 0.5
		var center := Vector3(x, REST_Y, z0 + row * ROW_DZ)
		slots.append(center)
		row_half_width = maxf(row_half_width, total * 0.5)
		var plate := MeshInstance3D.new()
		plate.mesh = MODELS.card_mesh(Vector3(uniform + 0.08, CARD_HEIGHT + 0.08, 0.03))
		plate.material_override = MODELS.flat(Color("1f4f78"), 0.3, 0.4)
		plate.position = center + _face_basis.z * -0.12
		plate.basis = _face_basis
		plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(plate)
		slot_nodes.append(plate)
	for row in range(rail_rows):
		var shelf := _shelf(row_half_width * 2.0 + 1.0)
		shelf.position = Vector3(0, 0, z0 + row * ROW_DZ)
		add_child(shelf)
	full_stop = Label3D.new()
	full_stop.name = "Punkt"
	full_stop.text = "."
	full_stop.font_size = 220
	full_stop.pixel_size = 0.005
	full_stop.modulate = Color("eafcff")
	full_stop.outline_size = 18
	full_stop.outline_modulate = Color("08203a")
	full_stop.position = slots[-1] + Vector3(uniform * 0.5 + 0.2, -0.3, 0)
	full_stop.basis = _face_basis
	add_child(full_stop)
	var tray_z0 := slots[-1].z + ROW_DZ + 0.3
	var rows := _split(order, narrow)
	for row in range(rows.size()):
		var z := tray_z0 + row * ROW_DZ
		row_z.append(z)
		_place_row(rows[row], z)
		var tray := _shelf(_width_of(rows[row]) + 0.7)
		tray.position = Vector3(0, 0, z)
		add_child(tray)
	_box = AABB(
		Vector3(-row_half_width - 0.5, 0, z0 - 0.6),
		Vector3(row_half_width * 2.0 + 1.0, 1.4, row_z[-1] + 0.6 - (z0 - 0.6))
	)


## Im Hochformat höchstens zwei Zeilen, so gleich lang wie möglich.
func _split(order: Array[int], narrow: bool) -> Array:
	if not narrow or _width_of(order) <= WRAP_WIDTH or order.size() < 2:
		return [order]
	var best := 1
	var best_width := INF
	for cut in range(1, order.size()):
		var widest := maxf(_width_of(order.slice(0, cut)), _width_of(order.slice(cut)))
		if widest < best_width:
			best_width = widest
			best = cut
	return [order.slice(0, best), order.slice(best)]


func _width_of(order: Array) -> float:
	var total := 0.0
	for index: int in order:
		total += widths[index] + GAP
	return maxf(0.0, total - GAP)


func _widest() -> float:
	var widest := 0.0
	for width in widths:
		widest = maxf(widest, width)
	return widest


func _place_row(order: Array, z: float) -> void:
	var total := _width_of(order)
	row_half_width = maxf(row_half_width, total * 0.5)
	var x := -total * 0.5
	for word_index: int in order:
		var width: float = widths[word_index]
		home[word_index] = Vector3(x + width * 0.5, REST_Y, z)
		x += width + GAP


func half_width() -> float:
	return row_half_width + 0.35


## Lumos Platz: seitlich rechts neben den Karten, Füße frei.
func lumo_spot(half_width_fox: float) -> Vector3:
	var middle := _box.get_center().z if mode == "order" else (row_z[0] + row_z[-1]) * 0.5
	return Vector3(row_half_width + 0.55 + half_width_fox, 0, middle)


## Zeigeplatz neben einer Karte (rechts am Ende ihrer Zeile).
func point_spot(index: int, half_width_fox: float) -> Vector3:
	return Vector3(row_half_width + 0.55 + half_width_fox, 0, home[index].z)


func _shelf(width: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Kartenleiste"
	var bar := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, 0.16, 0.9)
	bar.mesh = mesh
	bar.material_override = MODELS.with_outline(
		MODELS.rim_material(Color("173c5e"), Color("8ff0ff"), 0.4), Color("6fe3ff"), 0.02
	)
	bar.position.y = 0.08
	root.add_child(bar)
	return root


func _field(width: float, caption: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Antwortfeld"
	var plate := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, 0.06, 1.7)
	plate.mesh = mesh
	plate.material_override = MODELS.flat(Color("17406a"), 0.35, 0.4)
	root.add_child(plate)
	var ring := MeshInstance3D.new()
	var ring_mesh := BoxMesh.new()
	ring_mesh.size = Vector3(width + 0.12, 0.02, 1.82)
	ring.mesh = ring_mesh
	ring.material_override = MODELS.flat(Color("ffd96b"), 1.6)
	ring.position.y = -0.01
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ring)
	# Beschriftung liegt im Feld (zur Kamera gekippt) statt darüber zu schweben.
	var label := Label3D.new()
	label.name = "Feldname"
	label.text = caption
	label.font_size = 120
	label.pixel_size = 0.004
	label.modulate = Color("ffe9a0", 0.85)
	label.outline_size = 10
	label.outline_modulate = Color("08203a")
	label.rotation_degrees = Vector3(-62, 0, 0)
	label.position = Vector3(0, 0.3, 0.4)
	root.add_child(label)
	return root


func _card(word: String, width: float) -> Node3D:
	return card_node(word, width, _face_basis)


## Karte: abgerundet mit Fase und Kartonkante, leuchtender Halo dahinter,
## weicher Schatten darunter. Alle Karten gleich gefärbt. Auch die Silben-
## und Lesekarten nutzen diese Karte.
static func card_node(
	word: String, width: float, facing: Basis, height: float = CARD_HEIGHT, font: int = 150
) -> Node3D:
	var root := Node3D.new()
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = MODELS.card_mesh(Vector3(width, height, CARD_DEPTH))
	var paper := MODELS.rim_material(Color("f6f1e1"), Color("9ff2ff"), 0.6)
	paper.set_shader_parameter("rim_strength", 0.18)
	paper.set_shader_parameter("self_light", 0.32)
	body.set_surface_override_material(0, paper)
	var edge := MODELS.rim_material(Color("c9b48a"), Color("9ff2ff"), 0.7)
	edge.set_shader_parameter("rim_strength", 0.35)
	body.set_surface_override_material(1, edge)
	body.basis = facing
	root.add_child(body)
	var halo := MeshInstance3D.new()
	halo.name = "Halo"
	halo.mesh = MODELS.card_mesh(Vector3(width + 0.16, height + 0.16, 0.02))
	halo.material_override = MODELS.flat(HALO_IDLE, 1.1)
	halo.basis = facing
	halo.position = facing.z * -(CARD_DEPTH * 0.5 + 0.02)
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(halo)
	var shadow := MeshInstance3D.new()
	shadow.name = "Schatten"
	var plane := PlaneMesh.new()
	plane.size = Vector2(width + 0.2, 0.55)
	shadow.mesh = plane
	var dark := StandardMaterial3D.new()
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dark.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dark.albedo_color = Color(0.0, 0.03, 0.08, 0.45)
	shadow.material_override = dark
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(shadow)
	var label := Label3D.new()
	label.name = "Wort"
	label.text = word
	label.font_size = font
	label.pixel_size = 0.0034
	label.modulate = Color("12304f")
	label.outline_size = 0
	label.basis = facing
	label.position = facing.z * (CARD_DEPTH * 0.5 + 0.012)
	label.double_sided = false
	root.add_child(label)
	return root


func paper(index: int) -> ShaderMaterial:
	var body: MeshInstance3D = cards[index].get_node("Body")
	return body.get_surface_override_material(0) as ShaderMaterial


## Weicher Schatten bleibt am Boden: Je höher die Karte, desto größer und
## blasser – so sieht man, dass sie gehoben ist.
func _update_shadow(index: int) -> void:
	var card := cards[index]
	var shadow: MeshInstance3D = card.get_node("Schatten")
	var lift := maxf(0.0, card.position.y - REST_Y - (_floor[index] - SHELF_TOP))
	shadow.position = Vector3(0.0, _floor[index] + 0.012 - card.position.y, 0.25)
	shadow.scale = Vector3.ONE * (1.0 + lift * 0.35)
	var material := shadow.material_override as StandardMaterial3D
	material.albedo_color.a = clampf(0.45 - lift * 0.22, 0.12, 0.45)


func lift_of(index: int) -> float:
	return cards[index].position.y - REST_Y - (_floor[index] - SHELF_TOP)


func _process(delta: float) -> void:
	_clock += delta
	for index in range(cards.size()):
		_update_shadow(index)
	if is_instance_valid(picture) and not reduced_motion:
		picture.get_node("Figur").rotation.y = sin(_clock * 0.9) * 0.6


func _track(tween: Tween) -> Tween:
	_tweens.append(tween)
	return tween


func finish_motion() -> void:
	for tween in _tweens:
		if tween.is_valid() and tween.is_running():
			tween.custom_step(30.0)
	_tweens.clear()


func move_card(index: int, target: Vector3, seconds: float = 0.35, floor_y: float = -1.0) -> void:
	var card := cards[index]
	if floor_y >= 0.0:
		_floor[index] = floor_y
	if reduced_motion or seconds <= 0.0:
		card.position = target
		return
	var start := card.position
	var tween := _track(create_tween())
	(
		tween
		. tween_method(
			func(t: float) -> void:
				var point := start.lerp(target, t)
				point.y += sin(t * PI) * 0.45
				card.position = point,
			0.0,
			1.0,
			seconds
		)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)


## Antippen hebt die Karte an (Halo gold). Beim Tunwort/Namenwort kehrt eine
## vorher gehobene Karte zurück.
func select(index: int) -> void:
	if selected >= 0 and selected != index and mode != "order":
		move_card(selected, home[selected], 0.2)
		_glow(selected, 0.0)
	selected = index
	if index >= 0:
		if mode != "order":
			move_card(index, home[index] + Vector3(0, 0.42, 0.22), 0.2)
		_glow(index, 0.7)


func deselect() -> void:
	if selected >= 0:
		if mode != "order":
			move_card(selected, home[selected], 0.25)
		_glow(selected, 0.0)
	selected = -1


func highlight(index: int, value: float, color: Color = HALO_LIFT) -> void:
	_glow(index, value, color)


func _glow(index: int, value: float, color: Color = HALO_LIFT) -> void:
	card_glow(cards[index], value, color)


## Hervorheben über den Halo: heller und farbig; die Karte bleibt gleichfarbig.
static func card_glow(card: Node3D, value: float, color: Color = HALO_LIFT) -> void:
	var body: MeshInstance3D = card.get_node("Body")
	(body.get_surface_override_material(0) as ShaderMaterial).set_shader_parameter(
		"highlight", value * 0.35
	)
	var halo: MeshInstance3D = card.get_node("Halo")
	var material := halo.material_override as StandardMaterial3D
	var shade := color if value > 0.0 else HALO_IDLE
	material.albedo_color = shade
	material.emission = shade
	material.emission_energy_multiplier = 2.6 if value > 0.0 else 1.1
	halo.scale = Vector3.ONE * (1.06 if value > 0.0 else 1.0)


func halo_color(index: int) -> Color:
	var halo: MeshInstance3D = cards[index].get_node("Halo")
	return (halo.material_override as StandardMaterial3D).albedo_color


func clear_highlights() -> void:
	for index in range(cards.size()):
		_glow(index, 0.0)


## Lokales Antwortziel: Beim Satzbau ersetzt die Satzleiste das einzelne Feld.
func field_spot() -> Vector3:
	if mode == "order":
		return Vector3(0.0, REST_Y, (slots[0].z + slots[-1].z) * 0.5)
	var x := _field_width * 0.5 - _widest() * 0.5 - 0.2
	return answer_field.position + Vector3(x, 0.66, 0.0)


func to_field(index: int) -> void:
	move_card(index, field_spot(), 0.35, 0.06)
	# Die Feldbeschriftung macht der Karte (und dem Bild) Platz.
	answer_field.get_node("Feldname").visible = false


func to_home(index: int) -> void:
	move_card(index, home[index], 0.35, SHELF_TOP)


func to_slot(index: int, slot: int) -> void:
	move_card(index, slots[slot], 0.32, SHELF_TOP)


## Das Ding/Tier erscheint als Hologramm neben der gewählten Karte im
## Antwortfeld – erst nach der richtigen Wahl. Ein Sockelring trägt das Bild.
## Bei ruhiger Bewegung steht es sofort da.
func show_picture(id: String, look: String = "") -> void:
	clear_contrast()
	if is_instance_valid(picture):
		picture.free()
	picture = Node3D.new()
	picture.name = "Hologramm"
	# Steht links im Feld neben der Karte, auf einem leuchtenden Sockelring.
	var left := -_field_width * 0.5 + 0.9
	picture.position = answer_field.position + Vector3(left, 0.05, 0.0)
	add_child(picture)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.62
	torus.outer_radius = 0.7
	torus.rings = 40
	ring.mesh = torus
	ring.material_override = MODELS.holo_material(Color("8ff0ff"), 1.4)
	if calm_holograms:
		ring.material_override.set_shader_parameter("lines", 0.0)
	picture.add_child(ring)
	var figure := FIGURES.build(id, FIGURES.COLOR_WORDS.get(look, Color(0, 0, 0, 0)))
	figure.name = "Figur"
	figure.scale = Vector3.ONE * {"klein": 0.95, "groß": 1.75}.get(look, 1.4)
	picture.add_child(figure)
	if reduced_motion:
		return
	picture.scale = Vector3.ONE * 0.05
	var tween := _track(create_tween())
	tween.tween_property(picture, "scale", Vector3.ONE * 1.12, 0.45).set_trans(Tween.TRANS_BACK)
	tween.tween_property(picture, "scale", Vector3.ONE, 0.2)


## Wiewort-Hilfe: zwei gleiche Figuren im Antwortfeld, eine klein und eine
## groß bzw. in zwei Farben. Keine Beschriftung – das Kind vergleicht selbst.
func show_contrast(id: String, kind: String, look: String) -> void:
	clear_contrast()
	contrast = Node3D.new()
	contrast.name = "Vergleich"
	contrast.position = answer_field.position + Vector3(0, 0.05, 0)
	add_child(contrast)
	var looks: Array = []
	if kind == "size":
		looks = [{"scale": 0.85}, {"scale": 1.6}]
	else:
		var other := "blau" if look != "blau" else "rot"
		if id == "ente" and look == "gelb":
			other = "weiß"
		looks = [
			{"scale": 1.25, "color": FIGURES.COLOR_WORDS[look]},
			{"scale": 1.25, "color": FIGURES.COLOR_WORDS[other]}
		]
	var step := minf(1.5, _field_width * 0.27)
	for index in range(2):
		var figure := FIGURES.build(id, looks[index].get("color", Color(0, 0, 0, 0)))
		figure.name = "Figur%d" % index
		figure.scale = Vector3.ONE * float(looks[index].scale)
		figure.rotation.y = -0.4
		figure.position = Vector3((index * 2 - 1) * step, 0, 0)
		contrast.add_child(figure)
	answer_field.get_node("Feldname").visible = false
	if reduced_motion:
		return
	contrast.scale = Vector3.ONE * 0.05
	var tween := _track(create_tween())
	tween.tween_property(contrast, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BACK)


func clear_contrast(restore_label: bool = false) -> void:
	if is_instance_valid(contrast):
		contrast.free()
	contrast = null
	if restore_label and is_instance_valid(answer_field):
		answer_field.get_node("Feldname").visible = true


func card_rect(camera: Camera3D, index: int) -> Rect2:
	var card := cards[index]
	var half := Vector2(widths[index] * 0.5, CARD_HEIGHT * 0.5)
	var rect := Rect2(camera.unproject_position(card.global_position), Vector2.ZERO)
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var offset: Vector3 = _face_basis.x * half.x * corner.x + _face_basis.y * half.y * corner.y
		rect = rect.expand(camera.unproject_position(card.global_position + offset))
	return rect


func pick(camera: Camera3D, point: Vector2, minimum: float) -> int:
	var best := -1
	var best_distance := INF
	for index in range(cards.size()):
		var rect := card_rect(camera, index)
		var grow := maxf(0.0, (minimum - minf(rect.size.x, rect.size.y)) * 0.5)
		rect = rect.grow(grow + 4.0)
		if rect.has_point(point):
			var distance := rect.get_center().distance_to(point)
			if distance < best_distance:
				best = index
				best_distance = distance
	return best


func field_hit(camera: Camera3D, point: Vector2) -> bool:
	if not is_instance_valid(answer_field):
		return false
	var center := camera.unproject_position(answer_field.global_position)
	var edge := camera.unproject_position(answer_field.global_position + Vector3(1.45, 0, 0))
	return center.distance_to(point) <= center.distance_to(edge) * 1.1


func content_boxes() -> Array[AABB]:
	var boxes: Array[AABB] = [_box]
	if mode != "order" and is_instance_valid(answer_field):
		# Platz für Karte und Bild über dem Antwortfeld.
		var spot := answer_field.position
		boxes.append(
			AABB(spot + Vector3(-_field_width * 0.5, 0, -0.9), Vector3(_field_width, 1.7, 1.8))
		)
	return boxes


func content_box() -> AABB:
	return _box


func floor_point(camera: Camera3D, point: Vector2, height: float) -> Variant:
	var origin := camera.project_ray_origin(point)
	var normal := camera.project_ray_normal(point)
	if absf(normal.y) < 0.0001:
		return null
	var distance := (height - origin.y) / normal.y
	if distance <= 0.0:
		return null
	return to_local(origin + normal * distance)
