extends Node3D
## Holo-Raum „Lesen“: hinten der Satz als Kartenleiste, davor drei kleine
## Holo-Szenen mit demselben Ding und demselben Möbel – nur die Lage ist
## verschieden (darauf, darunter, daneben, darin, davor). Das Kind tippt die
## Szene, die zum Satz passt. Alle Szenen sind gleich gefärbt; keine Szene wird
## in der Hilfe markiert, nur das entscheidende Wort im Satz.

const MODELS = preload("res://scripts/learning/holo/holo_models.gd")
const FIGURES = preload("res://scripts/learning/holo/holo_figures.gd")
const WORDS = preload("res://scripts/learning/holo/holo_word_room.gd")
const PLATE_RADIUS := 1.12
const SCENE_STEP := 2.55
## Abstand der Szenen vor der letzten Satzzeile.
const SCENE_GAP := 2.5
const PROP_SCALE := 1.3
const THING_SCALE := 0.5
const RING_IDLE := Color("63dcff")
const RING_RIGHT := Color("ffd34d")

var reduced_motion := false
var calm_holograms := false
var strip: Node3D
var scenes: Array[String] = []
var plates: Array[Node3D] = []
var scene_z := 1.9
var things: Array[Node3D] = []
var _tweens: Array[Tween] = []


func build(task: Dictionary, order: Array, facing: Basis, narrow: bool) -> void:
	for child in get_children():
		child.free()
	plates.clear()
	things.clear()
	scenes.assign(order)
	strip = WORDS.new()
	strip.name = "Satzleiste"
	strip.reduced_motion = reduced_motion
	add_child(strip)
	var sentence_order: Array[int] = []
	for index in range(task.words.size()):
		sentence_order.append(index)
	strip.build(task, "strip", sentence_order, facing, narrow)
	scene_z = strip.row_z[-1] + SCENE_GAP
	for index in range(scenes.size()):
		var plate := _scene(str(task.place), str(task.object), scenes[index])
		plate.name = "Szene%d" % index
		plate.position = Vector3((index - 1) * SCENE_STEP, 0, scene_z)
		add_child(plate)
		plates.append(plate)


## Eine Szene: runde Holo-Platte, Möbel in der Mitte, das Ding je nach Lage.
func _scene(place: String, thing: String, relation: String) -> Node3D:
	var root := Node3D.new()
	var disc := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = PLATE_RADIUS
	mesh.bottom_radius = PLATE_RADIUS * 1.03
	mesh.height = 0.1
	mesh.radial_segments = 40
	disc.mesh = mesh
	disc.material_override = MODELS.rim_material(Color("143a5e"), Color("8ff0ff"), 0.45)
	disc.position.y = 0.05
	root.add_child(disc)
	var ring := MeshInstance3D.new()
	ring.name = "Rand"
	var torus := TorusMesh.new()
	torus.inner_radius = PLATE_RADIUS * 0.98
	torus.outer_radius = PLATE_RADIUS * 1.06
	torus.rings = 48
	torus.ring_segments = 6
	ring.mesh = torus
	ring.material_override = MODELS.flat(RING_IDLE, 1.8)
	ring.position.y = 0.1
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ring)
	var prop := FIGURES.build(place)
	prop.name = "Moebel"
	prop.scale = Vector3.ONE * PROP_SCALE
	prop.position.y = 0.1
	root.add_child(prop)
	var item := FIGURES.build(thing)
	item.name = "Ding"
	item.scale = Vector3.ONE * THING_SCALE
	item.rotation.y = -0.35
	item.position = thing_spot(place, relation)
	root.add_child(item)
	things.append(item)
	return root


## Lage des Dings relativ zur Plattenmitte.
static func thing_spot(place: String, relation: String) -> Vector3:
	var floor_y := 0.1
	match relation:
		"darauf":
			return Vector3(0.05, floor_y + FIGURES.prop_top(place) * PROP_SCALE, 0.05)
		"darunter":
			return Vector3(0.05, floor_y, 0.05)
		"darin":
			return Vector3(0.0, floor_y + FIGURES.prop_inside(place) * PROP_SCALE, 0.0)
		"davor":
			return Vector3(0.0, floor_y, 0.78)
	# daneben: rechts neben dem Möbel, noch auf der Platte.
	return Vector3(FIGURES.prop_half_width(place) * PROP_SCALE * 0.5 + 0.55, floor_y, 0.3)


func _track(tween: Tween) -> Tween:
	_tweens.append(tween)
	return tween


func finish_motion() -> void:
	for tween in _tweens:
		if tween.is_valid() and tween.is_running():
			tween.custom_step(30.0)
	_tweens.clear()
	if is_instance_valid(strip):
		strip.finish_motion()


func ring_color(index: int) -> Color:
	var ring: MeshInstance3D = plates[index].get_node("Rand")
	return (ring.material_override as StandardMaterial3D).albedo_color


func _set_ring(index: int, color: Color, energy: float) -> void:
	var ring: MeshInstance3D = plates[index].get_node("Rand")
	var material := ring.material_override as StandardMaterial3D
	material.albedo_color = color
	material.emission = color
	material.emission_energy_multiplier = energy


## Das Kind hat diese Szene gewählt und sie passt: Ring gold, das Ding hüpft.
func mark_right(index: int) -> void:
	_set_ring(index, RING_RIGHT, 2.8)
	if reduced_motion:
		return
	var item := things[index]
	var rest := item.position
	var tween := _track(create_tween())
	tween.tween_property(item, "position", rest + Vector3(0, 0.35, 0), 0.18)
	tween.tween_property(item, "position", rest, 0.22).set_trans(Tween.TRANS_BOUNCE)


## Gewählt, passt aber nicht: kurzes, ruhiges Abdunkeln – danach wieder wie
## die anderen Szenen (keine bleibende Markierung, die etwas verrät).
func mark_wrong(index: int) -> void:
	if reduced_motion:
		return
	_set_ring(index, Color("4a6b88"), 0.8)
	var tween := _track(create_tween())
	tween.tween_interval(0.5)
	tween.tween_callback(_set_ring.bind(index, RING_IDLE, 1.8))


func clear_marks() -> void:
	for index in range(plates.size()):
		_set_ring(index, RING_IDLE, 1.8)


func scene_rect(camera: Camera3D, index: int) -> Rect2:
	var center := plates[index].global_position
	var rect := Rect2(camera.unproject_position(center), Vector2.ZERO)
	for corner in [
		Vector3(-PLATE_RADIUS, 0, -PLATE_RADIUS),
		Vector3(PLATE_RADIUS, 0, -PLATE_RADIUS),
		Vector3(PLATE_RADIUS, 0, PLATE_RADIUS),
		Vector3(-PLATE_RADIUS, 0, PLATE_RADIUS),
		Vector3(0, 1.3, 0),
	]:
		rect = rect.expand(camera.unproject_position(center + corner))
	return rect


func pick(camera: Camera3D, point: Vector2) -> int:
	var best := -1
	var best_distance := INF
	for index in range(plates.size()):
		var rect := scene_rect(camera, index)
		if rect.has_point(point):
			var distance := rect.get_center().distance_to(point)
			if distance < best_distance:
				best = index
				best_distance = distance
	return best


func half_width() -> float:
	return maxf(SCENE_STEP + PLATE_RADIUS + 0.1, strip.half_width())


func lumo_spot(half_width_fox: float) -> Vector3:
	return Vector3(half_width() + 0.45 + half_width_fox, 0, (strip.row_z[0] + scene_z) * 0.5)


## Zeigeplatz neben dem Satzstreifen (Hilfe: entscheidendes Wort).
func point_spot(half_width_fox: float) -> Vector3:
	return Vector3(half_width() + 0.45 + half_width_fox, 0, strip.row_z[-1])


func content_boxes() -> Array[AABB]:
	var boxes: Array[AABB] = [strip.content_box()]
	var width := SCENE_STEP * 2.0 + PLATE_RADIUS * 2.0 + 0.2
	boxes.append(
		AABB(
			Vector3(-width * 0.5, 0, scene_z - PLATE_RADIUS - 0.1),
			Vector3(width, 1.5, PLATE_RADIUS * 2.0 + 0.2)
		)
	)
	return boxes
