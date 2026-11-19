# gdlint: disable=max-public-methods
# Darstellung und Treffer des Mathe-Raums: jede Methode ist ein Baustein der Hilfe.
extends Node3D
## Holo-Raum der Textaufgabe „a Äpfel im Korb, Lumo legt b dazu“:
## a einzeln zählbare Äpfel im Korb, b Äpfel auf Lumos Holo-Schale und ein
## Zwanzigerfeld (zwei Zehnerfelder). Nur Darstellung und Treffer; den Ablauf
## und die Bewertung hält holo_lesson_plan.gd.

const MODELS = preload("res://scripts/learning/holo/holo_models.gd")
const CELL := 0.95
const APPLE_SCALE := 0.86
## Bühne: hinten links der Korb, hinten rechts Lumos Schale, dazwischen eine
## freie Gasse für Lumo; vorne mit klarem Abstand das Zwanzigerfeld.
const BASKET_AT := Vector3(-2.35, 0.0, -1.75)
const PLATE_AT := Vector3(2.3, 0.0, -1.75)
const PLATE_RADIUS := 1.5
## Vorderkante Korb/Schale bei z ≈ -0.15; das Zwanzigerfeld beginnt bei z ≈ 1.0 (Gang für Lumo).
const FRAME_ORIGIN := Vector3(0.0, 0.0, 2.1)
const FLOOR_Y := MODELS.BASKET_FILL
const ARC_HEIGHT := 0.95
const BORROWED := Color("ffb52e")
const REDS: Array[Color] = [
	Color("d8262c"), Color("c81f2a"), Color("e0412b"), Color("cf2f24"), Color("d93a33")
]

var reduced_motion := false
var a := 0
var b := 0
var apples: Array[Node3D] = []
var labels: Array[Label3D] = []
var home: Array[Vector3] = []
var basket: Node3D
var plate: Node3D
var frame: Node3D
var frame_glow: MeshInstance3D
var badges: Array[Label3D] = []
var ten_label: Label3D
var rest_label: Label3D
var start_label: Label3D
var borrow_label: Label3D
var ten_outline: Node3D
var paths: Node3D
var _tweens: Array[Tween] = []
var _pulse := {}
var _clock := 0.0


func build(task: Dictionary) -> void:
	for child in get_children():
		child.free()
	apples.clear()
	labels.clear()
	home.clear()
	badges.clear()
	_pulse.clear()
	a = int(task.a)
	b = int(task.b)
	basket = MODELS.basket_node()
	basket.position = BASKET_AT
	add_child(basket)
	plate = _plate()
	plate.position = PLATE_AT
	add_child(plate)
	frame = MODELS.ten_frame_node(CELL)
	frame.position = FRAME_ORIGIN
	add_child(frame)
	# EIN Zehner: leuchtender Rahmen um das volle erste Zehnerfeld.
	ten_outline = MODELS.glow_frame(Vector2(CELL * 5.0 + 0.36, CELL * 2.0 + 0.36), 0.07)
	ten_outline.position = Vector3(0, 0.12, 0)
	ten_outline.visible = false
	frame.add_child(ten_outline)
	frame_glow = MeshInstance3D.new()
	var glow_mesh := BoxMesh.new()
	glow_mesh.size = Vector3(CELL * 5.0 + 0.2, 0.02, CELL * 2.0 + 0.2)
	frame_glow.mesh = glow_mesh
	frame_glow.material_override = MODELS.flat(Color("ffe27a"), 0.9)
	frame_glow.position = Vector3(0, 0.07, 0)
	frame_glow.visible = false
	frame_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	frame.add_child(frame_glow)
	# Zähler direkt am Feld: links „10“ (bzw. „8“, „+2“), rechts neben dem
	# zweiten Feld „+3“ – keine Zahlen auf einzelnen Äpfeln während der Hilfe.
	ten_label = _label("10", 190, Color("ffe27a"))
	ten_label.name = "ZaehlerZehn"
	ten_label.position = Vector3(-CELL * 3.3, 0.35, 0.0)
	ten_label.visible = false
	frame.add_child(ten_label)
	start_label = _label("", 170, Color("eafcff"))
	start_label.position = Vector3(-CELL * 3.3, 0.35, 0.0)
	start_label.visible = false
	frame.add_child(start_label)
	# „+2“ schwebt über den zwei geliehenen Äpfeln (Feld 9 und 10).
	borrow_label = _label("", 160, BORROWED)
	borrow_label.position = Vector3(CELL * 1.5, 1.05, CELL * 0.5)
	borrow_label.visible = false
	frame.add_child(borrow_label)
	rest_label = _label("", 190, Color("9ff2ff"))
	rest_label.name = "ZaehlerRest"
	rest_label.position = Vector3(-CELL * 3.3, 0.35, CELL * 2.55)
	rest_label.visible = false
	frame.add_child(rest_label)
	paths = Node3D.new()
	paths.name = "Bahnen"
	add_child(paths)
	for group in range(2):
		var badge := _label("", 120, Color("eafcff"))
		# Wie ein Anhänger vorn an Korb bzw. Schale: über der Wand, nicht über Äpfeln.
		badge.position = (
			BASKET_AT + Vector3(0, 0.42, MODELS.BASKET_RADIUS + 0.2)
			if group == 0
			else PLATE_AT + Vector3(0, 0.3, PLATE_RADIUS + 0.2)
		)
		badge.visible = false
		add_child(badge)
		badges.append(badge)
	for index in range(a + b):
		var apple := MODELS.apple_node(REDS[index % REDS.size()])
		apple.name = "Apfel%d" % index
		apple.scale = Vector3.ONE * APPLE_SCALE
		apple.rotation.y = float(index) * 1.7
		var spot := _home_position(index)
		home.append(spot)
		apple.position = spot
		add_child(apple)
		apples.append(apple)
		var number := _label("", 130, Color("ffe9a0"))
		number.position = Vector3(0, 1.05, 0)
		number.visible = false
		apple.add_child(number)
		labels.append(number)


func _plate() -> Node3D:
	var root := Node3D.new()
	root.name = "LumosSchale"
	var disc := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = PLATE_RADIUS
	mesh.bottom_radius = PLATE_RADIUS - 0.2
	mesh.height = 0.14
	mesh.radial_segments = 40
	disc.mesh = mesh
	disc.material_override = MODELS.with_outline(
		MODELS.rim_material(Color("2a5c86"), Color("9af0ff"), 0.35), Color("8fe9ff"), 0.025
	)
	disc.position.y = 0.07
	root.add_child(disc)
	var ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = PLATE_RADIUS - 0.02
	ring_mesh.outer_radius = PLATE_RADIUS + 0.05
	ring_mesh.rings = 40
	ring_mesh.ring_segments = 6
	ring.mesh = ring_mesh
	ring.material_override = MODELS.flat(Color("74e6ff"), 2.0)
	ring.position.y = 0.15
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ring)
	return root


func _label(text: String, size_value: int, color: Color) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = size_value
	label.pixel_size = 0.0042
	label.modulate = color
	label.outline_size = 22
	label.outline_modulate = Color("08203a")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 4
	label.outline_render_priority = 3
	return label


## Korb: eine Lage auf dem eingelegten Boden, Ring um die Mitte (ab 7 Äpfeln
## liegt einer in der Mitte) – jeder Apfel bleibt einzeln sichtbar.
## Schale: Würfelbild bzw. lockeres Raster, nie überlappend.
func _home_position(index: int) -> Vector3:
	if index < a:
		var centre := 1 if a >= 7 else 0
		if index < centre:
			return BASKET_AT + Vector3(0, FLOOR_Y, 0)
		var ring := a - centre
		var angle := TAU * (index - centre) / ring - PI * 0.5
		var radius := 0.92 if a >= 7 else 0.72
		return BASKET_AT + Vector3(cos(angle) * radius, FLOOR_Y, sin(angle) * radius)
	return PLATE_AT + Vector3(0, 0.15, 0) + _dice_offset(index - a, b)


## Würfelbilder bis 5, darüber ein lockeres 3er-Raster – nie überlappend.
static func _dice_offset(j: int, count: int) -> Vector3:
	var d := 0.5
	var patterns := {
		1: [Vector2(0, 0)],
		2: [Vector2(-d, -d), Vector2(d, d)],
		3: [Vector2(-d, -d), Vector2(0, 0), Vector2(d, d)],
		4: [Vector2(-d, -d), Vector2(d, -d), Vector2(-d, d), Vector2(d, d)],
		5: [Vector2(-d, -d), Vector2(d, -d), Vector2(0, 0), Vector2(-d, d), Vector2(d, d)],
	}
	if patterns.has(count):
		var spot: Vector2 = patterns[count][j]
		return Vector3(spot.x * 1.15, 0, spot.y)
	var columns := 3
	var rows := int(ceil(count / 3.0))
	var row := j / columns
	var in_row := mini(columns, count - row * columns)
	var x := (j % columns - (in_row - 1) * 0.5) * 0.74
	var z := (row - (rows - 1) * 0.5) * 0.72
	return Vector3(x, 0, z)


func slot_position(slot: int) -> Vector3:
	return frame.position + MODELS.frame_slot(CELL, slot) + Vector3(0, 0.02, 0)


func group_center(group: int) -> Vector3:
	return (BASKET_AT if group == 0 else PLATE_AT) + Vector3(0, 0.5, 0)


func frame_center() -> Vector3:
	return frame.position + Vector3(0, 0.1, CELL * 1.27)


func content_boxes() -> Array[AABB]:
	return [basket_box(), handle_box(), plate_box(), frame_box()]


func content_box() -> AABB:
	var box := basket_box()
	box = box.merge(plate_box())
	box = box.merge(frame_box())
	return box


## Korb samt Rand, Bügel und Äpfeln (für Kamera und Überdeckungsprüfung).
func basket_box() -> AABB:
	var r := MODELS.BASKET_RADIUS + 0.12
	return AABB(BASKET_AT + Vector3(-r, 0, -r), Vector3(2.0 * r, 1.2, 2.0 * r))


## Der nach hinten geneigte Bügel (nur für die Kamera).
func handle_box() -> AABB:
	var r := MODELS.BASKET_RADIUS + 0.1
	return AABB(BASKET_AT + Vector3(-r, 1.0, -1.35), Vector3(2.0 * r, 1.45, 1.35))


func plate_box() -> AABB:
	var r := PLATE_RADIUS + 0.06
	return AABB(PLATE_AT + Vector3(-r, 0, -r), Vector3(2.0 * r, 0.75, 2.0 * r))


## Boden-Rechteck beider Zehnerfelder (für Kamera und Überdeckungsprüfung).
func frame_box() -> AABB:
	return AABB(
		frame.position + Vector3(-CELL * 2.6, 0, -CELL * 1.15),
		Vector3(CELL * 5.2, 0.7, CELL * 4.85)
	)


func _track(tween: Tween) -> Tween:
	_tweens.append(tween)
	return tween


func finish_motion() -> void:
	for tween in _tweens:
		if tween.is_valid() and tween.is_running():
			tween.custom_step(30.0)
	_tweens.clear()


func move_apple(index: int, target: Vector3, seconds: float = 0.45) -> void:
	var apple := apples[index]
	if reduced_motion or seconds <= 0.0:
		apple.position = target
		return
	var start := apple.position
	var spin := apple.rotation.y
	var lift := ARC_HEIGHT * clampf(start.distance_to(target) / 3.0, 0.45, 1.0)
	var tween := _track(create_tween())
	(
		tween
		. tween_method(
			func(t: float) -> void:
				apple.position = arc_point(start, target, t, lift)
				apple.rotation.y = spin + t * TAU * 0.5,
			0.0,
			1.0,
			seconds
		)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)


## Bogenflug: gerade Linie plus Sinus-Bogen nach oben.
static func arc_point(start: Vector3, target: Vector3, t: float, lift: float) -> Vector3:
	var point := start.lerp(target, t)
	point.y += sin(t * PI) * lift
	return point


## Bahn eines geliehenen Apfels: goldene Spur von der Schale ins Zehnerfeld.
func show_path(start: Vector3, target: Vector3) -> void:
	var lift := ARC_HEIGHT * clampf(start.distance_to(target) / 3.0, 0.45, 1.0)
	var points := PackedVector3Array()
	var base := Vector3(0, 0.3, 0)
	for step in range(21):
		points.append(arc_point(start + base, target + base, step / 20.0, lift))
	var trail := MeshInstance3D.new()
	trail.name = "Bahn"
	trail.mesh = MODELS.tube(points, 0.035, 6)
	trail.material_override = MODELS.flat(BORROWED, 1.6)
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	paths.add_child(trail)
	var tip := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.11
	cone.height = 0.24
	cone.radial_segments = 10
	tip.mesh = cone
	tip.material_override = trail.material_override
	tip.position = points[18]
	paths.add_child(tip)
	tip.look_at(points[20] + (points[20] - points[18]) * 4.0, Vector3.UP)
	tip.rotate_object_local(Vector3.RIGHT, -PI * 0.5)


func to_home(index: int, seconds: float = 0.4) -> void:
	move_apple(index, home[index], seconds)


func to_slot(index: int, slot: int, seconds: float = 0.45) -> void:
	move_apple(index, slot_position(slot), seconds)


## Entdecken: Zahl am Apfel, kleiner Hüpfer.
func show_count(index: int, number: int) -> void:
	labels[index].text = str(number)
	labels[index].visible = true
	_pop(apples[index])


func clear_counts() -> void:
	for label in labels:
		label.visible = false
	for badge in badges:
		badge.visible = false


func show_badge(group: int, words: String) -> void:
	badges[group].text = words
	badges[group].visible = true
	_pop(badges[group])


func _pop(node: Node3D) -> void:
	if reduced_motion:
		return
	var base := node.scale
	var tween := _track(create_tween())
	tween.tween_property(node, "scale", base * 1.22, 0.11).set_trans(Tween.TRANS_BACK)
	tween.tween_property(node, "scale", base, 0.16)


## Blick lenken: die Äpfel einer Gruppe leuchten kurz nacheinander auf.
func pulse_group(group: int, seconds: float = 1.6) -> void:
	var first := 0 if group == 0 else a
	var last := a if group == 0 else a + b
	for index in range(first, last):
		_pulse[index] = seconds
	if reduced_motion:
		for index in range(first, last):
			_set_highlight(index, 0.8)


func clear_pulse() -> void:
	for index in range(apples.size()):
		_set_highlight(index, 0.0)
	_pulse.clear()


func _set_highlight(index: int, value: float) -> void:
	var body: MeshInstance3D = apples[index].get_node("Body")
	(body.material_override as ShaderMaterial).set_shader_parameter("highlight", value)


func show_ten(full: bool) -> void:
	frame_glow.visible = full
	ten_outline.visible = full
	ten_label.visible = full
	if full:
		start_label.visible = false
		borrow_label.visible = false
		_pop(ten_label)


## Hilfe Schritt für Schritt sichtbar: „8“ am Feld, „+2“ in Gold, „+3“ daneben.
func show_parts(start: int, borrowed: int, rest: int) -> void:
	start_label.text = str(start) if start > 0 else ""
	start_label.visible = start > 0 and not ten_label.visible
	borrow_label.text = "+%d" % borrowed if borrowed > 0 else ""
	borrow_label.visible = borrowed > 0 and not ten_label.visible
	rest_label.text = "+ %d" % rest if rest > 0 else ""
	rest_label.visible = rest > 0
	for label: Label3D in [start_label, borrow_label, rest_label]:
		if label.visible:
			_pop(label)


func clear_parts() -> void:
	for label: Label3D in [start_label, borrow_label, rest_label, ten_label]:
		label.visible = false
	ten_outline.visible = false
	frame_glow.visible = false
	for child in paths.get_children():
		child.free()
	for index in range(apples.size()):
		mark_borrowed(index, false)


## Die geliehenen Äpfel leuchten gold (Kontur und Schimmer), bis die Aufgabe wechselt.
func mark_borrowed(index: int, value: bool) -> void:
	var body: MeshInstance3D = apples[index].get_node("Body")
	var material := body.material_override as ShaderMaterial
	material.set_shader_parameter("rim_color", BORROWED if value else Color("ffd2b0"))
	material.set_shader_parameter("rim_strength", 2.2 if value else 0.9)
	var outline := material.next_pass as ShaderMaterial
	outline.set_shader_parameter("glow", BORROWED if value else Color("ffe7a8"))
	outline.set_shader_parameter("width", 0.05 if value else 0.022)


func _process(delta: float) -> void:
	_clock += delta
	if _pulse.is_empty() or reduced_motion:
		return
	for index: int in _pulse.keys():
		_pulse[index] -= delta
		var wave := 0.5 + 0.5 * sin(_clock * 7.0 - float(index) * 0.7)
		_set_highlight(index, wave if _pulse[index] > 0.0 else 0.0)
		if _pulse[index] <= 0.0:
			_pulse.erase(index)


## Treffer: nächster Apfel im Bildschirmabstand, mindestens 63 px Radius
## (126 px Ziel am Fold) und mindestens die projizierte Apfelgröße.
func pick(camera: Camera3D, point: Vector2, minimum_radius: float) -> int:
	var best := -1
	var best_distance := INF
	for index in range(apples.size()):
		var center := camera.unproject_position(apples[index].global_position + Vector3(0, 0.27, 0))
		var radius := maxf(minimum_radius, screen_radius(camera, index))
		var distance := center.distance_to(point)
		if distance <= radius and distance < best_distance:
			best = index
			best_distance = distance
	return best


func screen_radius(camera: Camera3D, index: int) -> float:
	var center := apples[index].global_position + Vector3(0, 0.27, 0)
	var side := camera.global_basis.x * 0.36 * APPLE_SCALE
	return camera.unproject_position(center).distance_to(camera.unproject_position(center + side))


func frame_hit(camera: Camera3D, point: Vector2) -> bool:
	var corners := [
		Vector3(-CELL * 2.7, 0, -CELL * 1.2),
		Vector3(CELL * 2.7, 0, -CELL * 1.2),
		Vector3(CELL * 2.7, 0, CELL * 3.8),
		Vector3(-CELL * 2.7, 0, CELL * 3.8)
	]
	var polygon := PackedVector2Array()
	for corner: Vector3 in corners:
		polygon.append(camera.unproject_position(frame.global_position + corner))
	return Geometry2D.is_point_in_polygon(point, polygon)


func floor_point(camera: Camera3D, point: Vector2, height: float) -> Variant:
	var origin := camera.project_ray_origin(point)
	var normal := camera.project_ray_normal(point)
	if absf(normal.y) < 0.0001:
		return null
	var distance := (height - origin.y) / normal.y
	if distance <= 0.0:
		return null
	return to_local(origin + normal * distance)
