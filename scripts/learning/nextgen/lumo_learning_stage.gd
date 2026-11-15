extends Node3D
## LUMO Nextgen Chat 3: isolated Godot 4.6 learning-stage prototype.
## Keeps the existing production scenes intact. Chat 1 owns APK integration.
## All mathematical objects have stable IDs, never pixel-coordinate targets.
signal lesson_changed(lesson_id: String)
signal speech_state_changed(state: String)
signal object_targeted(object_id: String)

const ACTOR_RESOURCE := "res://assets/characters/lumo_nextgen_chat3/Lumo-Learning-Animated.glb"
const PROPS_RESOURCE := "res://assets/characters/lumo_nextgen_chat3/Lumo-Learning-Objects.glb"
const VALID_STATES := ["idle", "listen", "think", "speak", "interrupt", "success"]
const VISEMES := ["viseme_A", "viseme_E", "viseme_I", "viseme_O",
	"viseme_U", "viseme_MBP", "viseme_FV", "viseme_L"]
const BLEND_STATE := {
	"idle": "learn_idle_breathe",
	"listen": "learn_listen",
	"think": "learn_think",
	"speak": "learn_explain",
	"interrupt": "learn_interrupt",
	"success": "learn_celebrate",
}
var lesson_id := "math_8_plus_5"
var character_state := "idle"
var speech_seconds := 0.0
var speech_active := false
var current_focus_id := ""
var _actor: Node3D
var _player: AnimationPlayer
var _skeleton: Skeleton3D
var _face: MeshInstance3D
var _eyelids: Array[MeshInstance3D] = []
var _board := Node3D.new()
var _actor_mount := Node3D.new()
var _targets: Dictionary = {}
var _counter_objects: Array[Node3D] = []
var _mesh_assets: Dictionary = {}
var _current_mouth := ""
var _camera: Camera3D
var _light: DirectionalLight3D
var _reduced_motion := false
var _point_target: Node3D
var _point_line: MeshInstance3D


func _ready() -> void:
	_actor_mount.name = "CharacterAnchor"
	add_child(_actor_mount)
	_board.name = "LessonBoard"
	add_child(_board)
	_make_world()
	_load_assets()
	configure_lesson(lesson_id)
	set_character_state("listen")


func _make_world() -> void:
	_camera = Camera3D.new()
	_camera.name = "LearningCamera"
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 5.9
	_camera.position = Vector3(0.35, 2.9, 6.5)
	add_child(_camera)
	_camera.look_at(Vector3(0.25, 0.95, 0), Vector3.UP)
	_camera.current = true
	_light = DirectionalLight3D.new()
	_light.name = "SoftSchoolKey"
	_light.light_color = Color(1.0, 0.91, 0.80)
	_light.light_energy = 1.0
	_light.rotation_degrees = Vector3(-42, -26, 0)
	add_child(_light)
	var env := WorldEnvironment.new()
	env.name = "SoftSchoolEnvironment"
	var setting := Environment.new()
	setting.background_mode = Environment.BG_COLOR
	setting.background_color = Color(0.065, 0.095, 0.18)
	setting.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	setting.ambient_light_color = Color(0.62, 0.72, 0.96)
	setting.ambient_light_energy = 0.65
	env.environment = setting
	add_child(env)
	var floor_tile := MeshInstance3D.new()
	floor_tile.name = "NonCountingStageFloor"
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 2.85
	cylinder.bottom_radius = 2.90
	cylinder.height = 0.12
	floor_tile.mesh = cylinder
	floor_tile.position = Vector3(0.0, -0.08, 0.0)
	floor_tile.material_override = _material(Color(0.17, 0.22, 0.35), 0.8)
	add_child(floor_tile)
	_point_line = MeshInstance3D.new()
	_point_line.name = "TargetRayFeedback"
	_point_line.visible = false
	add_child(_point_line)
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	if _camera == null:
		return
	var screen := get_viewport().get_visible_rect().size
	var ratio := screen.x / maxf(screen.y, 1.0)
	if ratio < 0.75:
		# Portrait: keep counters and text at the center, without occlusion.
		_camera.size = 8.0
		_actor_mount.position = Vector3(-1.25, 0.70, -0.55)
		_board.position = Vector3(-0.12, -0.70, 0.62)
	else:
		_camera.size = 5.9
		_actor_mount.position = Vector3(-1.85, 0.0, 0.0)
		_board.position = Vector3(0.12, 0.0, 0.25)


func _load_assets() -> void:
	var actor_scene := ResourceLoader.load(ACTOR_RESOURCE, "PackedScene") as PackedScene
	if actor_scene == null:
		push_error("[LumoChat3] Actual animated GLB has not been imported: " + ACTOR_RESOURCE)
		return
	_actor = actor_scene.instantiate() as Node3D
	_actor.name = "LumoAnimated"
	_actor_mount.add_child(_actor)
	for node in _actor.find_children("*", "AnimationPlayer", true, false):
		if node is AnimationPlayer and (node as AnimationPlayer).has_animation("learn_listen"):
			_player = node as AnimationPlayer
	for node in _actor.find_children("*", "Skeleton3D", true, false):
		if node is Skeleton3D and (node as Skeleton3D).find_bone("Head") != -1:
			_skeleton = node as Skeleton3D
	for node in _actor.find_children("*", "MeshInstance3D", true, false):
		if not node is MeshInstance3D:
			continue
		var part := node as MeshInstance3D
		if part.name.begins_with("MouthVisemes"):
			_face = part
		elif part.name.begins_with("Eyelid"):
			_eyelids.append(part)
	if _player:
		_player.animation_finished.connect(_on_animation_finished)
	var props_scene := ResourceLoader.load(PROPS_RESOURCE, "PackedScene") as PackedScene
	if props_scene == null:
		push_error("[LumoChat3] Editable learning-object GLB not imported")
		return
	var props_root := props_scene.instantiate() as Node3D
	for node in props_root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi:
			_mesh_assets[mi.name] = mi.mesh
	props_root.queue_free()


func _material(color: Color, roughness: float = 0.55) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material


func _mesh_object(asset: String, fallback: Mesh, tint: Color = Color.WHITE) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = "Visible_" + asset
	visual.mesh = _mesh_assets.get(asset, fallback)
	if tint != Color.WHITE:
		visual.material_override = _material(tint)
	return visual


func _erase_board() -> void:
	for child in _board.get_children():
		_board.remove_child(child)
		child.queue_free()
	_targets.clear()
	_counter_objects.clear()
	current_focus_id = ""
	_point_line.visible = false


func _add_prop(id: String, asset: String, position: Vector3, color: Color = Color.WHITE) -> Node3D:
	var fallback := SphereMesh.new()
	fallback.radius = 0.15
	fallback.height = 0.30
	var target := Node3D.new()
	target.name = id.replace(":", "_")
	target.set_meta("lesson_object_id", id)
	_board.add_child(target)
	target.position = position
	var visual := _mesh_object(asset, fallback, color)
	visual.position = Vector3.ZERO
	target.add_child(visual)
	_targets[id] = target
	return target


func _text(text: String, parent: Node3D, height: float = 0.22) -> void:
	var label := Label3D.new()
	label.name = "LearningText"
	label.text = text
	label.font_size = 80
	label.pixel_size = height / 80.0
	label.outline_size = 6
	label.modulate = Color(0.12, 0.13, 0.22)
	label.position = Vector3(0, 0, 0.16)
	parent.add_child(label)


func configure_lesson(new_lesson: String) -> void:
	_erase_board()
	match new_lesson:
		"math_8_plus_5":
			_lesson_math()
		"reading_ba_na_ne":
			_lesson_syllables()
		"patterns_circle_square_triangle":
			_lesson_pattern()
		_:
			push_warning("[LumoChat3] Unknown lesson: " + new_lesson)
			return
	lesson_id = new_lesson
	lesson_changed.emit(new_lesson)


func _lesson_math() -> void:
	# Exactly 13 colored counting objects, with stable math identifiers.
	# 8 on the left, 5 on the right; moving two does NOT create duplicates.
	for i in range(8):
		var id := "math:8plus5:left:%02d" % (i + 1)
		var pos := Vector3(-0.09 + (i % 5) * 0.39, 0.52 + int(i / 5) * 0.43, 0.1)
		_counter_objects.append(_add_prop(id, "CounterBerry", pos))
	for i in range(5):
		var id := "math:8plus5:right:%02d" % (i + 1)
		var pos := Vector3(-0.09 + (i % 5) * 0.39, 1.51, 0.10)
		_counter_objects.append(_add_prop(id, "CounterBerry", pos, Color(1.0, 0.82, 0.43)))
	var caption := Node3D.new()
	caption.name = "NonCountingEquation"
	caption.position = Vector3(0.72, 2.16, 0.0)
	_board.add_child(caption)
	_text("8 + 5 = ?", caption, 0.34)


func bridge_to_ten() -> void:
	if lesson_id != "math_8_plus_5" or _counter_objects.size() != 13:
		return
	for i in range(2):
		var moved := _targets.get("math:8plus5:right:%02d" % (i + 1)) as Node3D
		if moved == null:
			continue
		var dest := Vector3(1.08 + i * 0.39, 0.95, 0.1)
		if _reduced_motion:
			moved.position = dest
		else:
			var tween := create_tween().set_trans(Tween.TRANS_CUBIC)
			tween.tween_property(moved, "position", dest, 0.55)


func _lesson_syllables() -> void:
	for i in range(3):
		var syllable := ["Ba", "na", "ne"][i]
		var id := "reading:banane:syllable:%d" % (i + 1)
		var prop := _add_prop(id, "LetterTile", Vector3(-0.02 + i * 0.73, 1.07, 0.02))
		_text(syllable, prop, 0.32)


func _lesson_pattern() -> void:
	var kinds := ["ShapeCircle", "ShapeSquare", "ShapeTriangle"]
	for i in range(8):
		var kind := kinds[i % 3]
		var id := "pattern:shapes:item:%02d" % (i + 1)
		_add_prop(id, kind, Vector3(-0.15 + (i % 4) * 0.64,
			1.13 + int(i / 4) * 0.63, 0.04))
	# Item 9 is a question mark, not a falsely countable item.
	var question := Node3D.new()
	question.name = "PatternQuestionSlot"
	question.position = Vector3(2.28, 1.76, 0.1)
	_board.add_child(question)
	_text("?", question, 0.31)


func get_counted_amount() -> int:
	return _counter_objects.size()


func get_target_ids() -> Array[String]:
	var result: Array[String] = []
	for id in _targets:
		result.append(str(id))
	return result


func point_at_object(id: String) -> bool:
	if not _targets.has(id) or _actor == null:
		return false
	var target := _targets[id] as Node3D
	if not is_instance_valid(target):
		return false
	current_focus_id = id
	_point_target = target
	set_character_state("speak")
	if _player and _player.has_animation("learn_point"):
		_player.play("learn_point", 0.18)
	# Use actual 3D world target and live viewport layout, never pixels.
	var d := target.global_position - _actor.global_position
	_actor.rotation.y = clampf(atan2(d.x, d.z) * 0.18, -0.32, 0.32)
	_show_target_line()
	object_targeted.emit(id)
	return true


func _show_target_line() -> void:
	if not is_instance_valid(_point_target):
		return
	var beginning := _actor_mount.global_position + Vector3(0.48, 1.07, 0.18)
	var end := _point_target.global_position
	var segment := end - beginning
	if segment.length() < 0.0001:
		return
	var beam := CylinderMesh.new()
	beam.top_radius = 0.008
	beam.bottom_radius = 0.008
	beam.height = segment.length()
	_point_line.mesh = beam
	_point_line.material_override = _material(Color(1.0, 0.85, 0.31))
	_point_line.position = (beginning + end) / 2.0
	_point_line.quaternion = Quaternion(Vector3.UP, segment.normalized())
	_point_line.visible = true


func set_reduced_motion(enabled: bool) -> void:
	_reduced_motion = enabled


func set_character_state(state: String) -> bool:
	if not VALID_STATES.has(state):
		return false
	character_state = state
	if state != "speak":
		_set_mouth("")
	if state == "interrupt":
		speech_active = false
		_point_line.visible = false
	if _player:
		var animation := str(BLEND_STATE.get(state, "learn_listen"))
		if _player.has_animation(animation):
			_player.play(animation, 0.15 if not _reduced_motion else 0.03)
			if _reduced_motion:
				_player.pause()
	speech_state_changed.emit(state)
	return true


func apply_speech_frame(playback_seconds: float, viseme: String, playing: bool) -> void:
	# The host's REAL audio playback clock owns playback_seconds and viseme.
	# Time-coded phonemes require Chat 4. This does not synthesize timing.
	speech_seconds = maxf(playback_seconds, 0.0) if is_finite(playback_seconds) else 0.0
	if not playing:
		speech_active = false
		_set_mouth("")
		if character_state == "speak":
			set_character_state("listen")
		return
	speech_active = true
	if character_state != "speak":
		set_character_state("speak")
	_set_mouth(viseme if VISEMES.has(viseme) else "")


func _set_mouth(viseme: String) -> void:
	_current_mouth = viseme
	if _face == null or _face.mesh == null:
		return
	for i in range(_face.mesh.get_blend_shape_count()):
		var shape := str(_face.mesh.get_blend_shape_name(i))
		_face.set_blend_shape_value(i, 1.0 if shape == viseme else 0.0)


func blink() -> void:
	if _reduced_motion:
		return
	for lid in _eyelids:
		if lid.mesh == null:
			continue
		for i in range(lid.mesh.get_blend_shape_count()):
			if str(lid.mesh.get_blend_shape_name(i)) == "blink":
				var tween := create_tween()
				tween.tween_method(_apply_blink.bind(lid, i), 0.0, 1.0, 0.10)
				tween.tween_method(_apply_blink.bind(lid, i), 1.0, 0.0, 0.14)


func _apply_blink(value: float, lid: MeshInstance3D, shape_index: int) -> void:
	if is_instance_valid(lid):
		lid.set_blend_shape_value(shape_index, value)


func interrupt() -> void:
	# A speaking animation must be stopped and mouth cleared immediately.
	speech_active = false
	_set_mouth("")
	set_character_state("interrupt")


func _on_animation_finished(name: StringName) -> void:
	if name == "learn_interrupt":
		set_character_state("listen")
	elif name == "learn_point":
		_point_line.visible = false
		if speech_active:
			set_character_state("speak")
		else:
			set_character_state("listen")
	elif name == "learn_celebrate":
		set_character_state("listen")
