## StarCollectGame - sammle 5 Sterne, dann zurueck zum Home.
##
## - 5 Stern-Meshes mit Area3D-Picking auf einer Kreisbahn um Lumo
## - Tap auf Stern: Pulse + Reward-Sound (kein Audio noch), Counter++
## - Nach 5: Lumo macht celebrate, dann zurueck zum Home
extends Node3D

const STAR_COUNT: int = 5
const STAR_RADIUS: float = 3.2

@export var lumo_path: NodePath
@export var counter_label_path: NodePath
@export var back_button_path: NodePath

var _collected: int = 0
var _stars: Array[Node3D] = []
var _lumo: LumoCharacterController
var _counter_label: Label
var _finished: bool = false


func _ready() -> void:
	_lumo = get_node_or_null(lumo_path) as LumoCharacterController
	_counter_label = get_node_or_null(counter_label_path) as Label
	var back_btn: Button = get_node_or_null(back_button_path) as Button
	if back_btn != null:
		back_btn.pressed.connect(_back_to_home)
	_spawn_stars()
	_update_counter()
	print("[StarCollect] scene_loaded")


func _spawn_stars() -> void:
	var star_mat: StandardMaterial3D = StandardMaterial3D.new()
	star_mat.albedo_color = Color(1.0, 0.86, 0.30, 1)
	star_mat.emission_enabled = true
	star_mat.emission = Color(1.0, 0.75, 0.25, 1)
	star_mat.emission_energy_multiplier = 1.8
	star_mat.metallic = 0.10
	star_mat.roughness = 0.30
	for i in range(STAR_COUNT):
		var angle: float = TAU * float(i) / float(STAR_COUNT)
		var x: float = cos(angle) * STAR_RADIUS
		var z: float = sin(angle) * STAR_RADIUS
		var root: Node3D = Node3D.new()
		root.position = Vector3(x, 1.2, z)
		root.set_meta("star_index", i)
		var mesh: MeshInstance3D = MeshInstance3D.new()
		var sphere: SphereMesh = SphereMesh.new()
		sphere.radius = 0.25
		sphere.height = 0.50
		mesh.mesh = sphere
		mesh.material_override = star_mat
		root.add_child(mesh)
		var area: Area3D = Area3D.new()
		area.input_ray_pickable = true
		var coll: CollisionShape3D = CollisionShape3D.new()
		var shape: SphereShape3D = SphereShape3D.new()
		shape.radius = 0.55
		coll.shape = shape
		area.add_child(coll)
		root.add_child(area)
		area.input_event.connect(_on_star_input.bind(root))
		# Idle-Rotation/Bob als Tween
		var tw: Tween = root.create_tween().set_loops()
		tw.tween_property(root, "position:y", 1.45, 0.9).set_trans(Tween.TRANS_SINE)
		tw.tween_property(root, "position:y", 1.15, 0.9).set_trans(Tween.TRANS_SINE)
		add_child(root)
		_stars.append(root)


func _on_star_input(
	_cam: Camera3D,
	event: InputEvent,
	_pos: Vector3,
	_normal: Vector3,
	_shape_idx: int,
	star: Node3D
) -> void:
	if _finished or not is_instance_valid(star):
		return
	var triggered: bool = false
	if event is InputEventScreenTouch and event.pressed:
		triggered = true
	elif (
		event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	):
		triggered = true
	if not triggered:
		return
	_collect(star)


func _collect(star: Node3D) -> void:
	_stars.erase(star)
	# Pulse + entfernen
	var tw: Tween = star.create_tween()
	tw.tween_property(star, "scale", Vector3(1.6, 1.6, 1.6), 0.12)
	tw.tween_property(star, "scale", Vector3.ZERO, 0.20)
	tw.tween_callback(func(): star.queue_free())
	_collected += 1
	_update_counter()
	EventBus.companion_reaction.emit("star_collected")
	print("[StarCollect] collected:%d/%d" % [_collected, STAR_COUNT])
	if _collected >= STAR_COUNT:
		_finish()


func _update_counter() -> void:
	if _counter_label != null:
		_counter_label.text = "Sterne: %d / %d" % [_collected, STAR_COUNT]


func _finish() -> void:
	_finished = true
	if _lumo != null:
		_lumo.play_behavior("celebrate")
	if _counter_label != null:
		_counter_label.text = "Geschafft!"
	# Nach 2.4s zurueck
	var t: Tween = create_tween()
	t.tween_interval(2.4)
	t.tween_callback(_back_to_home)


func _back_to_home() -> void:
	if _lumo != null:
		_lumo.play_behavior("idle")
	SceneRouter.goto("home")
