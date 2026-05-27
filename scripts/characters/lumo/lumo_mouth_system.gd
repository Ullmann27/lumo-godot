## LumoMouthSystem
##
## Steuert die Mundform. Mouth wird als 1 CapsuleMesh ueber dem Schnauzen-
## Sphere modelliert. Viseme-Wechsel werden durch unterschiedliche Skala
## (Breite/Hoehe) + leichten Open/Close-Effekt erreicht. Keine schwere
## LipSync-Bibliothek.
##
## API:
##   set_mouth_shape(shape)
##   speak_text_preview(text)         - zaehlt grobe Visemes durch
##   start_speaking() / stop_speaking()
class_name LumoMouthSystem
extends Node3D

const SHAPES: Array[String] = [
	"rest",
	"smile",
	"a",
	"e",
	"i",
	"o",
	"u",
	"fv",
	"l",
	"mbp",
	"wq",
	"surprise_open",
	"grin",
	"closed_smile",
]

# Pro Viseme: scale.x (Breite), scale.y (Hoehe), scale.z (Tiefe).
const SHAPE_SCALES: Dictionary = {
	"rest": Vector3(1.0, 0.15, 1.0),
	"smile": Vector3(1.3, 0.12, 1.0),
	"a": Vector3(0.9, 0.55, 1.0),
	"e": Vector3(1.2, 0.30, 1.0),
	"i": Vector3(1.3, 0.18, 1.0),
	"o": Vector3(0.7, 0.55, 1.0),
	"u": Vector3(0.55, 0.45, 1.0),
	"fv": Vector3(1.1, 0.22, 1.0),
	"l": Vector3(1.0, 0.35, 1.0),
	"mbp": Vector3(0.95, 0.10, 1.0),
	"wq": Vector3(0.65, 0.50, 1.0),
	"surprise_open": Vector3(0.85, 0.75, 1.0),
	"grin": Vector3(1.4, 0.20, 1.0),
	"closed_smile": Vector3(1.25, 0.08, 1.0),
}

@export var mouth_mesh_path: NodePath
@export var speak_viseme_interval: float = 0.18

var _mouth: Node3D
var _current_shape: String = "rest"
var _speaking: bool = false
var _speak_tw: Tween


func _ready() -> void:
	_mouth = get_node_or_null(mouth_mesh_path) as Node3D
	set_mouth_shape("rest")


func set_mouth_shape(shape: String) -> void:
	if not SHAPE_SCALES.has(shape):
		push_warning("[LumoMouth] unknown shape: %s" % shape)
		return
	_current_shape = shape
	if _mouth != null:
		_mouth.scale = SHAPE_SCALES[shape]
	EventBus.lumo_mouth_shape_changed.emit(shape)


## Spielt eine grobe Viseme-Sequenz fuer den uebergebenen Text. Wahre
## LipSync ist nicht das Ziel, aber das Maul soll sich beim Sprechen
## bewegen.
func speak_text_preview(text: String) -> void:
	if text.is_empty():
		return
	var sequence: Array[String] = []
	for c in text.to_lower():
		match c:
			"a":
				sequence.append("a")
			"e":
				sequence.append("e")
			"i":
				sequence.append("i")
			"o":
				sequence.append("o")
			"u":
				sequence.append("u")
			"f", "v":
				sequence.append("fv")
			"l":
				sequence.append("l")
			"m", "b", "p":
				sequence.append("mbp")
			"w", "q":
				sequence.append("wq")
			" ", ".":
				sequence.append("rest")
			_:
				sequence.append("rest")
	_play_sequence(sequence)


func start_speaking() -> void:
	if _speaking:
		return
	_speaking = true
	# Endlosschleife durch A-E-I-O-U bis stop_speaking()
	_speak_tw = create_tween().set_loops()
	for v in ["a", "e", "o", "i"]:
		var viseme_name: String = v
		_speak_tw.tween_callback(func(): set_mouth_shape(viseme_name))
		_speak_tw.tween_interval(speak_viseme_interval)


func stop_speaking() -> void:
	if not _speaking:
		return
	_speaking = false
	if _speak_tw != null and _speak_tw.is_valid():
		_speak_tw.kill()
	set_mouth_shape("rest")


func get_mouth_shape() -> String:
	return _current_shape


func _play_sequence(sequence: Array[String]) -> void:
	var tw: Tween = create_tween()
	for shape in sequence:
		var shape_local: String = shape
		tw.tween_callback(func(): set_mouth_shape(shape_local))
		tw.tween_interval(speak_viseme_interval)
	tw.tween_callback(func(): set_mouth_shape("rest"))
