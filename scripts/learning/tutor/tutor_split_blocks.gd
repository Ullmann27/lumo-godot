extends Node3D
## Zahlenhaus zum Zerlegen: die zweite Zahl als Würfelreihe, die sich in zwei
## Teile trennt. Der erste Teil leuchtet golden – er macht die 10 voll.

const CUBE := 0.42

var _cubes: Array[MeshInstance3D] = []
var _labels: Array[Label3D] = []
var _whole := 0
var _first := 0
var _gold: StandardMaterial3D
var _blue: StandardMaterial3D


func _ready() -> void:
	name = "LumoNachhilfeZahlenhaus"
	_gold = StandardMaterial3D.new()
	_gold.albedo_color = Color("ffc94a")
	_gold.roughness = 0.4
	_gold.emission_enabled = true
	_gold.emission = Color("ffb020")
	_gold.emission_energy_multiplier = 0.35
	_blue = StandardMaterial3D.new()
	_blue.albedo_color = Color("4fb3e8")
	_blue.roughness = 0.45
	for index in range(2):
		var label := Label3D.new()
		label.font_size = 88
		label.pixel_size = 0.006
		label.outline_size = 16
		label.modulate = Color("fff6d8")
		label.outline_modulate = Color("10243a")
		label.visible = false
		add_child(label)
		_labels.append(label)


func show_whole(whole: int) -> void:
	_whole = clampi(whole, 0, 19)
	_first = 0
	_rebuild()


func split(first: int) -> void:
	_first = clampi(first, 0, _whole)
	_rebuild()


func _rebuild() -> void:
	for cube in _cubes:
		cube.queue_free()
	_cubes.clear()
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * CUBE
	var gap := 0.5 if _first > 0 else 0.0
	var width := _whole * (CUBE + 0.06) + gap
	var x := -width * 0.5
	for index in range(_whole):
		if index == _first and _first > 0:
			x += gap
		var cube := MeshInstance3D.new()
		cube.mesh = mesh
		cube.material_override = _gold if index < _first else _blue
		cube.position = Vector3(x + CUBE * 0.5, CUBE * 0.5, 0)
		add_child(cube)
		_cubes.append(cube)
		x += CUBE + 0.06
	_labels[0].visible = _first > 0
	_labels[1].visible = _first > 0 and _first < _whole
	if _first > 0:
		_labels[0].text = str(_first)
		_labels[0].position = Vector3(-width * 0.5 + _first * (CUBE + 0.06) * 0.5, CUBE + 0.45, 0)
		_labels[1].text = str(_whole - _first)
		_labels[1].position = Vector3(width * 0.5 - (_whole - _first) * (CUBE + 0.06) * 0.5, CUBE + 0.45, 0)


func cube_count() -> int:
	return _cubes.size()
