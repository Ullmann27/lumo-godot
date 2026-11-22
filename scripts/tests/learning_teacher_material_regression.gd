extends SceneTree
## Normal Flutter scene IDs resolve the production actor, moves and help callbacks.
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, description: String) -> void:
	if not ok:
		failures.append(description)
		push_error(description)


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _tap(screen_position: Vector2) -> void:
	for down in [true, false]:
		var tap := InputEventScreenTouch.new()
		tap.index = 0
		tap.pressed = down
		tap.position = screen_position
		Input.parse_input_event(tap)
		await process_frame


func _shot(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--screens="):
			var directory := argument.trim_prefix("--screens=")
			DirAccess.make_dir_recursive_absolute(directory)
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(directory.path_join(label + ".png")) == OK, "Capture " + label)


func _open(scene_id: String, payload: Dictionary, grade: int):
	var router = root.get_node("SceneRouter")
	router.launch_options = {"learning": payload, "grade": grade}
	var room = load(router.SCENES[scene_id]).instantiate()
	root.add_child(room)
	await _frames(4)
	return room


func _point_error(actor, at: Vector3) -> float:
	var skeleton: Skeleton3D = actor.skeleton
	var shoulder := skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("UpperArm.L")).origin)
	var palm := skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("Hand.L")).origin)
	return rad_to_deg((palm - shoulder).angle_to(at - shoulder))


func _run() -> void:
	root.size = Vector2i(1024, 720)
	if "--tutor-only" not in OS.get_cmdline_user_args():
		await _lesson_routes()
	var fixture := JSON.parse_string(FileAccess.get_file_as_string("res://scripts/tests/fixtures/tutor_payloads.json")) as Dictionary
	var tutor: Dictionary = fixture.cases[0].learning.duplicate(true)
	tutor.startWeg = "rechenrahmen"
	tutor.startStufe = "ueben"
	var room = await _open("tutor", tutor, 4)
	var count := int(room.tutor.current().aktion.reihe1)
	check(room.set_bead_count(1, count + 1) == "zu_viel", "Tutor reads the child's real bead count")
	check(room.fox.teacher_pose.reaction == "encourage" or room._pending_reaction == "encourage", "Retry uses the original rig")
	check(room.set_bead_count(1, count + 1) == "gezeigt", "Second try demonstrates the actual material")
	for i in range(210):
		await process_frame
		if room.fox_spot == "show" and room.fox.teacher_pose.reaction == "explain":
			break
	await _frames(20)
	check(room.bubble_role.text == "Lumo zeigt" and room.bubble_text.text.contains(str(count)) and room.bubble_text.text.contains("Perlen"), "Tutor describes the bead operation it has demonstrated")
	check(room.fox_point_target.distance_to(room.frame.counted_anchor(0)) < .02, "Original tutor rig points towards the demonstrated row")
	var error := _point_error(room.fox, room.fox_point_target)
	room.fox.teacher_pose.restore_sampled_pose()
	var authored := _point_error(room.fox, room.fox_point_target)
	print("[LessonTeacherMaterial] bead pointing error in degrees, authored=", authored, " aimed=", error)
	check(error < authored - 3.0, "Real upper-arm and hand align more closely with the counted beads")
	room.fox.teacher_pose.advance(room.fox, 1.0 / 60.0)
	await _shot("tutor-beads")
	room.queue_free()
	await _frames(3)
	print("[LessonTeacherMaterial] ", "PASS" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)


func _lesson_routes() -> void:
	var room = await _open("learning", {"kind": "bridge_ten", "a": 8, "b": 5}, 1)
	check(room.fox.is_usable(), "The routed lesson has an original animated rig")
	await _tap(room.main_button.get_global_rect().get_center())
	await _frames(5)
	var id: String = room.fox.director.point_target_id
	check(room.activity.placed == [0] and not id.is_empty(), "Demonstration moves the selected mesh and points at it")
	check(room.fox.registry.world_target(id).distance_to(room.tokens[0].global_position) < .45, "Paw target follows moving lesson material")
	await _frames(26)
	check(room.explanation.text.contains("8 weiter auf 9"), "First grader can count along after the animation")
	await _shot("lesson-show")
	await _tap(room.camera.unproject_position(room.tokens[1].global_position))
	check(room.fox.director.state == "nodding" and room.activity.placed.size() == 2, "Child action has its own live acknowledgement")
	await _frames(26)
	room.queue_free()
	await _frames(2)
	room = await _open("learning", {"kind": "bridge_ten", "a": 8, "b": 5}, 2)
	room.main_button.pressed.emit()
	check(room.explanation.text.contains("ein Platz"), "Second grader sees the bridge to ten")
	room.queue_free()
	await _frames(2)
	room = await _open("learning", {"kind": "bridge_hundred", "a": 180, "b": 30}, 3)
	room.main_button.pressed.emit()
	check(room.explanation.text.contains("180 + 10 = 190"), "Third grader sees how moving a strip changes the tens")
	room.queue_free()
	await _frames(2)
	room = await _open("learning", {"kind": "fraction_parts", "a": 2, "b": 6, "extra": 2}, 4)
	room.main_button.pressed.emit()
	check(room.explanation.text.contains("Zähler auf 3") and room.explanation.text.contains("Nenner bleibt 6"), "Fourth grader sees the relation between real parts and the fraction")
	room.queue_free()
	await _frames(2)
