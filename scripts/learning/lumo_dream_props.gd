extends Node3D
## Original Blender sculptures around the lesson perimeter. These are visual
## only: no body, input handler or lesson-state dependency is introduced.
const STORYBOOK = preload("res://assets/dream_garden/dream_storybook.glb")
const BLOSSOM = preload("res://assets/dream_garden/dream_blossom.glb")

var reduced_motion := false
var quality := "medium"
var _moving: Array[Node3D] = []
var _rests: Array[Transform3D] = []
var _stars: Array[bool] = []
var _elapsed := 0.0
var _application_paused := false
var _storybook: Node3D


func _ready() -> void:
	name = "LumoDreamGardenSculptures"
	# Keep every sculpture outside the lesson carpet and the teacher's space.
	_storybook = _add_model(STORYBOOK, "StorybookGarden", Vector3(5.35, 0.02, -1.4), 0.48, -0.2)
	_add_model(BLOSSOM, "ReadingBlossomRight", Vector3(7.25, -0.65, 0.4), 1.3, 0.3)
	if quality == "high":
		_add_model(BLOSSOM, "ReadingBlossomLeft", Vector3(-7.25, -0.65, 0.4), 1.1, -0.5)
	visibility_changed.connect(_update_processing)
	get_viewport().size_changed.connect(_layout_for_viewport)
	_layout_for_viewport()
	_update_processing()


func _add_model(
	scene: PackedScene, node_name: String, at: Vector3, size_value: float, yaw: float
) -> Node3D:
	var model := scene.instantiate() as Node3D
	model.name = node_name
	model.position = at
	model.scale = Vector3.ONE * size_value
	model.quaternion = Quaternion(Vector3.UP, yaw)
	add_child(model)
	for node: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var part_name := str(node.name)
		if part_name.begins_with("DreamOrbit") or part_name.begins_with("DreamFlower"):
			_moving.append(node)
			_rests.append(node.transform)
			_stars.append(part_name.begins_with("DreamOrbit"))
	return model


func _layout_for_viewport() -> void:
	if not is_inside_tree() or not is_instance_valid(_storybook):
		return
	var dimensions := get_viewport().get_visible_rect().size
	var portrait := dimensions.x / maxf(dimensions.y, 1.0) < 0.95
	# The original centre-window sill is 0.62 m high. In portrait the book
	# rests there, above the learning objects and beside the original teacher.
	_storybook.position = Vector3(0.7, 0.62, -5.65) if portrait else Vector3(5.35, 0.02, -1.4)
	_storybook.scale = Vector3.ONE * (0.46 if portrait else 0.48)


func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	if value:
		for index in range(_moving.size()):
			_moving[index].transform = _rests[index]
	_update_processing()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		_application_paused = true
		_update_processing()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		_application_paused = false
		_update_processing()


func _update_processing() -> void:
	set_process(
		is_inside_tree()
		and is_visible_in_tree()
		and not reduced_motion
		and quality != "low"
		and not _application_paused
	)


func _process(delta: float) -> void:
	# Both rates (0.72 and 0.504) complete whole cycles at this boundary.
	_elapsed = fmod(_elapsed + minf(delta, 0.1), TAU / 0.072)
	_apply_pose(_elapsed)


func _apply_pose(seconds: float) -> void:
	for index in range(_moving.size()):
		var rest := _rests[index]
		var phase := seconds * 0.72 + float(index) * 1.61
		if _stars[index]:
			rest.origin.y += sin(phase) * 0.045
			rest.basis = rest.basis * Basis(Quaternion(Vector3.UP, sin(phase * 0.7) * 0.18))
		else:
			rest.basis = rest.basis * Basis(Quaternion(Vector3.FORWARD, sin(phase) * 0.055))
		_moving[index].transform = rest
