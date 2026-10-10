extends SceneTree
## Actual exported skin/AnimationPlayer rendered by Godot, never generated pictures.
const ACTOR = preload("res://scripts/characters/lumo/lumo_rigged_actor.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("[LumoRig] " + message)


func _settle(frames := 3) -> void:
	for i in range(frames):
		await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var output := args[0] if not args.is_empty() else "res://exports/lumo-animation"
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(720, 800)
	var baseline := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var stage := Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("101b30")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("dce8ff")
	environment.environment.ambient_light_energy = 0.65
	stage.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-30, 150, 0)
	key.light_energy = 1.2
	stage.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, -50, 0)
	fill.light_energy = 0.4
	stage.add_child(fill)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.14
	camera.current = true
	stage.add_child(camera)
	camera.look_at_from_position(Vector3(0, 1.00, 4), Vector3(0, 0.88, 0))
	var actor = ACTOR.new()
	stage.add_child(actor)
	await _settle()
	actor.player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_check(actor.skeleton.get_bone_count() == 65, "Real skeleton required")
	var head_id: int = actor.skeleton.find_bone("Head")
	_check(head_id >= 0 and actor.skeleton.find_bone("Hand.R") >= 0, "Semantic bones must survive export")
	for clip in ACTOR.CLIPS:
		var hand_id: int = actor.skeleton.find_bone("Hand.L" if clip == "point_portal" else "Hand.R")
		actor.player.play(clip, 0)
		actor.player.advance(0)
		var start: Transform3D = actor.skeleton.get_bone_global_pose(hand_id)
		var animation: Animation = actor.player.get_animation(clip)
		var sample: float = animation.length * 0.5
		actor.player.seek(sample, true)
		actor.skeleton.force_update_all_bone_transforms()
		await _settle()
		var end: Transform3D = actor.skeleton.get_bone_global_pose(hand_id)
		_check(end.origin.is_finite(), "Finite skin pose: " + clip)
		if clip in ["greeting_wave", "celebrate", "point_portal"]:
			_check(start.origin.distance_to(end.origin) > 0.06, "A real hand moves: " + clip)
		if DisplayServer.get_name() != "headless":
			_check(root.get_texture().get_image().save_png(output.path_join(clip + ".png")) == OK, "Capture write")
		print("[LumoRig] actual animation=", clip, " duration=", animation.length)
	if args.has("--video") and DisplayServer.get_name() != "headless":
		var sequence := 0
		for clip in ["idle", "greeting_wave", "celebrate"]:
			actor.player.play(clip, 0)
			actor.player.advance(0)
			var length: float = actor.player.get_animation(clip).length
			for frame in range(ceili(length * 12.0)):
				actor.player.seek(minf(frame / 12.0, length), true)
				actor.skeleton.force_update_all_bone_transforms()
				await _settle(1)
				_check(root.get_texture().get_image().save_png(
					output.path_join("frame-%04d.png" % sequence)) == OK, "Real animated video frame")
				sequence += 1
	actor.apply_speech_sample(0.25, 0.8, true)
	_check(actor.audio_active and is_equal_approx(actor.last_audio_envelope, 0.8),
		"Playback-envelope interface accepts a synthetic test sample")
	_check(not actor.mouth_supported, "No false lip-sync claim")
	actor.apply_speech_sample(0.5, 0.7, false)
	_check(is_zero_approx(actor.last_audio_envelope), "Stopping audio clears the envelope")
	actor.set_reduced_motion(true)
	_check(not actor.player.is_playing(), "Reduced motion stops the animation clock")
	actor.set_suspended(true)
	_check(not actor.play_behavior("celebrate"), "No hidden motion while suspended")
	actor.set_suspended(false)
	_check(not actor.play_behavior("nonexistent"), "Unknown clips cannot replace the state")
	stage.free()
	await _settle()
	var orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	if orphans != baseline:
		Node.print_orphan_nodes()
	_check(orphans == baseline, "No orphan renderer nodes")
	if failures == 0:
		print("[LumoRig] PASS checks=", checks, " real exported rig and clips; physical Android not tested")
	quit(0 if failures == 0 else 1)
