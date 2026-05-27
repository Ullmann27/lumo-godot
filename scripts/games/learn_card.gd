## LearnCard - einfache Demo: Lumo zeigt 4 Karten nacheinander, spricht
##   das Wort, Kind tippt auf "Weiter" oder "Nochmal".
##
## Cycle: A -> B -> C -> D -> back to home
extends Node3D

const CARDS: Array[Dictionary] = [
	{"letter": "A", "word": "Apfel", "color": Color(1.00, 0.62, 0.30, 1)},
	{"letter": "B", "word": "Ball", "color": Color(0.55, 0.85, 0.40, 1)},
	{"letter": "C", "word": "Clown", "color": Color(0.30, 0.75, 0.95, 1)},
	{"letter": "D", "word": "Drache", "color": Color(0.90, 0.45, 0.85, 1)},
]

@export var lumo_path: NodePath
@export var card_label_path: NodePath
@export var word_label_path: NodePath
@export var card_mesh_path: NodePath
@export var next_button_path: NodePath
@export var back_button_path: NodePath

var _index: int = 0
var _lumo: LumoCharacterController
var _card_label: Label
var _word_label: Label
var _card_mesh: MeshInstance3D


func _ready() -> void:
	_lumo = get_node_or_null(lumo_path) as LumoCharacterController
	_card_label = get_node_or_null(card_label_path) as Label
	_word_label = get_node_or_null(word_label_path) as Label
	_card_mesh = get_node_or_null(card_mesh_path) as MeshInstance3D
	var next_btn: Button = get_node_or_null(next_button_path) as Button
	if next_btn != null:
		next_btn.pressed.connect(_on_next)
	var back_btn: Button = get_node_or_null(back_button_path) as Button
	if back_btn != null:
		back_btn.pressed.connect(_back_to_home)
	print("[Learn] scene_loaded")
	_show_card(0)


func _show_card(idx: int) -> void:
	if idx < 0 or idx >= CARDS.size():
		return
	_index = idx
	var c: Dictionary = CARDS[idx]
	if _card_label != null:
		_card_label.text = c["letter"]
	if _word_label != null:
		_word_label.text = c["word"]
	if _card_mesh != null:
		var mat: StandardMaterial3D = _card_mesh.material_override as StandardMaterial3D
		if mat == null:
			mat = StandardMaterial3D.new()
			_card_mesh.material_override = mat
		mat.albedo_color = c["color"]
		mat.emission_enabled = true
		mat.emission = c["color"]
		mat.emission_energy_multiplier = 0.3
	if _lumo != null:
		_lumo.play_behavior("speak")
		_lumo.speak_text_preview(c["word"])
	print("[Learn] card:%s (%s)" % [c["letter"], c["word"]])


func _on_next() -> void:
	if _index + 1 < CARDS.size():
		_show_card(_index + 1)
	else:
		# Fertig - kurz feiern dann zurueck
		if _lumo != null:
			_lumo.play_behavior("celebrate")
		var tw: Tween = create_tween()
		tw.tween_interval(1.8)
		tw.tween_callback(_back_to_home)


func _back_to_home() -> void:
	if _lumo != null:
		_lumo.play_behavior("idle")
		_lumo.stop_speaking()
	SceneRouter.goto("home")
