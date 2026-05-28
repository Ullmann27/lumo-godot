## AlphabetCarousel - Lese-Lern-Modul Phase 1: 26 Buchstaben.
##
## 26 3D-Tafeln im Halbkreis um Lumo. Jede Tafel zeigt einen Buchstaben.
## Tap auf Tafel: Lumo dreht sich hin + spricht den Laut (echte
## espeak-generierte WAV aus assets/audio/voice/letters/).
##
## Buttons:
##   "Vorlesen alles": cycelt durch alle 26 Buchstaben in 1.5s-Schritten
##   "Zurueck": zurueck zum Home
extends Node3D

const LETTERS: Array[String] = [
	"a",
	"b",
	"c",
	"d",
	"e",
	"f",
	"g",
	"h",
	"i",
	"j",
	"k",
	"l",
	"m",
	"n",
	"o",
	"p",
	"q",
	"r",
	"s",
	"t",
	"u",
	"v",
	"w",
	"x",
	"y",
	"z",
]
const CAROUSEL_RADIUS: float = 4.5
const CAROUSEL_Y: float = 1.4
const ARC_DEGREES: float = 260.0  # Halbkreis + etwas, fast voller Ring
const TILE_SIZE: float = 0.8

@export var lumo_path: NodePath
@export var back_button_path: NodePath
@export var read_all_button_path: NodePath
@export var current_label_path: NodePath

var _lumo: LumoCharacterController
var _tiles: Array[Node3D] = []
var _current_index: int = -1
var _read_all_tween: Tween


func _ready() -> void:
	_lumo = get_node_or_null(lumo_path) as LumoCharacterController
	var back: Button = get_node_or_null(back_button_path) as Button
	if back != null:
		back.pressed.connect(_back_to_home)
	var read_all: Button = get_node_or_null(read_all_button_path) as Button
	if read_all != null:
		read_all.pressed.connect(_play_all)
	_spawn_letters()
	print("[Alphabet] scene_loaded with %d letters" % LETTERS.size())


func _spawn_letters() -> void:
	var arc_rad: float = deg_to_rad(ARC_DEGREES)
	var start: float = -arc_rad * 0.5
	var step: float = arc_rad / float(LETTERS.size() - 1)
	for i in range(LETTERS.size()):
		var angle: float = start + step * float(i)
		var x: float = sin(angle) * CAROUSEL_RADIUS
		var z: float = -cos(angle) * CAROUSEL_RADIUS
		var letter: String = LETTERS[i]
		var tile: Node3D = _build_tile(letter, i)
		tile.position = Vector3(x, CAROUSEL_Y, z)
		add_child(tile)
		# look_at erst NACH add_child (sonst "not inside tree")
		tile.look_at(Vector3(0, CAROUSEL_Y, 0), Vector3.UP)
		_tiles.append(tile)


func _build_tile(letter: String, idx: int) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Tile_" + letter

	# Hintergrund-Plate (warmer Stein/Holz)
	var plate: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(TILE_SIZE, TILE_SIZE, 0.10)
	plate.mesh = box
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.78, 0.50, 1)
	mat.metallic = 0.10
	mat.roughness = 0.65
	mat.emission_enabled = true
	mat.emission = Color(0.40, 0.25, 0.15, 1)
	mat.emission_energy_multiplier = 0.20
	plate.material_override = mat
	root.add_child(plate)

	# Buchstabe als Label3D
	var label: Label3D = Label3D.new()
	label.text = letter.to_upper()
	label.font_size = 90
	label.position = Vector3(0, 0, 0.07)
	label.modulate = Color(0.30, 0.15, 0.08, 1)
	label.outline_size = 4
	label.outline_modulate = Color(1, 0.85, 0.55, 1)
	label.pixel_size = 0.003
	root.add_child(label)

	# Touch-Hitbox
	var area: Area3D = Area3D.new()
	area.input_ray_pickable = true
	var coll: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(TILE_SIZE * 1.25, TILE_SIZE * 1.25, 0.4)
	coll.shape = shape
	area.add_child(coll)
	area.input_event.connect(_on_tile_input.bind(idx))
	root.add_child(area)

	return root


func _on_tile_input(
	_cam: Camera3D,
	event: InputEvent,
	_pos: Vector3,
	_normal: Vector3,
	_shape_idx: int,
	tile_index: int,
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
	_select_letter(tile_index)


func _select_letter(idx: int) -> void:
	if idx < 0 or idx >= _tiles.size():
		return
	_current_index = idx
	var letter: String = LETTERS[idx]
	# Pulse-Animation auf der Tafel
	var tile: Node3D = _tiles[idx]
	var tw: Tween = create_tween()
	tw.tween_property(tile, "scale", Vector3.ONE * 1.30, 0.10)
	tw.tween_property(tile, "scale", Vector3.ONE, 0.20)
	# Aktuelles-Label aktualisieren
	var current_label: Label = get_node_or_null(current_label_path) as Label
	if current_label != null:
		current_label.text = letter.to_upper()
	# Voice abspielen
	AudioManager.play_voice("letters/" + letter)
	# Lumo zeigt auf die Tafel + macht "speak_explain"
	if _lumo != null:
		_lumo.play_behavior("point")
	# Erkundungs-Belohnung: 1 Stern pro NEUEM Buchstaben (nicht bei
	# wiederholten Taps, sonst trivial Sterne-Farmen)
	if not ProgressStore.is_letter_learned(letter):
		ProgressStore.mark_letter_learned(letter)
		ProgressStore.add_stars(1)
	print("[Alphabet] letter:%s" % letter)


func _play_all() -> void:
	if _read_all_tween != null and _read_all_tween.is_valid():
		_read_all_tween.kill()
	_read_all_tween = create_tween()
	for i in range(LETTERS.size()):
		var idx: int = i
		_read_all_tween.tween_callback(func(): _select_letter(idx))
		_read_all_tween.tween_interval(1.2)
	_read_all_tween.tween_callback(_on_read_all_done)


func _on_read_all_done() -> void:
	if _lumo != null:
		_lumo.play_behavior("celebrate")


func _back_to_home() -> void:
	if _read_all_tween != null and _read_all_tween.is_valid():
		_read_all_tween.kill()
	if _lumo != null:
		_lumo.play_behavior("idle")
	SceneRouter.goto("reading_hub")
