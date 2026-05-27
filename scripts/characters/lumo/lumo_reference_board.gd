## LumoReferenceBoard
##
## Reference-Board fuer scenes/characters/lumo/lumo_showcase.tscn.
## Liest die 10 Referenzbild-PNGs aus assets/characters/lumo/reference/
## und legt sie als 3D-Plane-Reihe nebeneinander hinter Lumo ab. Dient
## als Inspektions-/Showcase-Tafel - so sieht man bei einem Editor-Run
## sofort welche Sheets in die Implementierung eingeflossen sind.
##
## Im Headless-Modus bleibt das Board funktional (Materials werden
## gesetzt), nur ohne sichtbare Anzeige.
class_name LumoReferenceBoard
extends Node3D

const REFERENCE_DIR: String = "res://assets/characters/lumo/reference/"
const REFERENCE_FILES: Array[String] = [
	"01_master_character_sheet.png",
	"02_orthographic_model_sheet.png",
	"03_facial_expression_sheet.png",
	"04_mouth_viseme_sheet.png",
	"05_eye_blink_sheet.png",
	"06_gesture_arm_pose_sheet.png",
	"07_walk_cycle_keyposes.png",
	"08_jump_hop_keyposes.png",
	"09_turnaround_rotation_sheet.png",
	"10_interaction_app_behavior_sheet.png",
]

@export var board_width: float = 14.0
@export var board_height: float = 2.4
@export var board_y: float = 3.0


func _ready() -> void:
	var loaded: int = 0
	var step: float = board_width / float(REFERENCE_FILES.size())
	var start_x: float = -board_width * 0.5 + step * 0.5
	for i in range(REFERENCE_FILES.size()):
		var path: String = REFERENCE_DIR + REFERENCE_FILES[i]
		if not ResourceLoader.exists(path):
			push_warning("[LumoRefBoard] missing: %s" % path)
			continue
		var tex: Texture2D = ResourceLoader.load(path) as Texture2D
		if tex == null:
			continue
		var plane: MeshInstance3D = MeshInstance3D.new()
		var mesh: QuadMesh = QuadMesh.new()
		mesh.size = Vector2(step * 0.92, board_height)
		plane.mesh = mesh
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_texture = tex
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		plane.material_override = mat
		plane.position = Vector3(start_x + step * float(i), board_y, 0.0)
		add_child(plane)
		loaded += 1
	print("[LumoRefBoard] %d/%d sheets loaded" % [loaded, REFERENCE_FILES.size()])
