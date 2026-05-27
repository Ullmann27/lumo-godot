## IntroController - 3-5 Sekunden 3D-Intro mit pulsierendem warmem Stern.
##
## Verhaltensregeln:
##   - leuchtender Stern in der Mitte, Kamera dolly-in
##   - Tap/Klick irgendwo -> Skip, sofort zu Home
##   - nach 4.5 s automatischer Wechsel zu Home
extends Node3D

const AUTO_ADVANCE_SECONDS: float = 4.5
const STAR_GROW_DURATION: float = 1.2
const CAMERA_DOLLY_DURATION: float = 3.5

@export var star_path: NodePath
@export var camera_path: NodePath

var _skipped: bool = false


func _ready() -> void:
	print("[Intro] start")
	var star: Node3D = get_node_or_null(star_path) as Node3D
	if star != null:
		star.scale = Vector3.ZERO
		var tw_star: Tween = create_tween()
		(
			tw_star
			. tween_property(star, "scale", Vector3.ONE, STAR_GROW_DURATION)
			. set_ease(Tween.EASE_OUT)
			. set_trans(Tween.TRANS_CUBIC)
		)
	var cam: Camera3D = get_node_or_null(camera_path) as Camera3D
	if cam != null:
		var start_pos: Vector3 = cam.position
		var end_pos: Vector3 = start_pos - Vector3(0, 0, 1.5)
		var tw_cam: Tween = create_tween()
		(
			tw_cam
			. tween_property(cam, "position", end_pos, CAMERA_DOLLY_DURATION)
			. set_ease(Tween.EASE_OUT)
			. set_trans(Tween.TRANS_QUAD)
		)
	# Auto-advance Timer
	await get_tree().create_timer(AUTO_ADVANCE_SECONDS).timeout
	_advance()


func _unhandled_input(event: InputEvent) -> void:
	if _skipped:
		return
	if event is InputEventScreenTouch and event.pressed:
		_skipped = true
		print("[Intro] skipped by touch")
		_advance()
	elif event is InputEventMouseButton and event.pressed:
		_skipped = true
		print("[Intro] skipped by click")
		_advance()


func _advance() -> void:
	SceneRouter.goto("home")
