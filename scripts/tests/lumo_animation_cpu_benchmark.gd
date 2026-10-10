extends SceneTree
## Desktop/headless CPU characterization only. Never an Android FPS claim.
const ACTOR = preload("res://scripts/characters/lumo/lumo_rigged_actor.gd")
const ADAPTER = preload("res://scripts/characters/lumo/lumo_kart_animation_adapter.gd")
const VEHICLE = preload("res://scripts/games/kart_vehicle.gd")
var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("[LumoAnimationCPU] " + label)


func _distribution(samples: Array[float]) -> Dictionary:
	samples.sort()
	var total := 0.0
	for sample in samples:
		total += sample
	return {"mean_ms": total / samples.size(),
		"p95_ms": samples[mini(samples.size() - 1, ceili(samples.size() * 0.95) - 1)],
		"max_ms": samples[-1], "samples": samples.size()}


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var output := args[0] if not args.is_empty() else "res://exports/lumo-animation-cpu.json"
	var baseline := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var stage := Node3D.new()
	root.add_child(stage)
	var result := {"platform": OS.get_name(), "godot": Engine.get_version_info().string,
		"display": DisplayServer.get_name(), "android_test": false,
		"gpu_fps_measured": false, "frames_per_sample": 1, "pose_step_seconds": 1.0 / 30.0,
		"scope": "CPU AnimationPlayer plus bone update; excludes GPU skinning, draw and full app",
		"load_ms": [], "actor_batches": []}
	var actors: Array = []
	for i in range(6):
		var begin := Time.get_ticks_usec()
		var actor = ACTOR.new()
		stage.add_child(actor)
		result.load_ms.append((Time.get_ticks_usec() - begin) / 1000.0)
		actor.player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		actor.player.play("idle", 0)
		actors.append(actor)
		if i > 0:
			_check(actor.skeleton != actors[0].skeleton, "Independent skeleton per racer")
			var first_mesh: MeshInstance3D = actors[0].visual.find_children("*", "MeshInstance3D", true, false)[0]
			var current_mesh: MeshInstance3D = actor.visual.find_children("*", "MeshInstance3D", true, false)[0]
			_check(first_mesh.mesh == current_mesh.mesh, "Mesh shared across instances")
		if actors.size() in [1, 6]:
			var timings: Array[float] = []
			var head_id: int = actors[0].skeleton.find_bone("Head")
			var head_before: Quaternion = actors[0].skeleton.get_bone_pose_rotation(head_id)
			for frame in range(270):
				begin = Time.get_ticks_usec()
				for item in actors:
					item.player.advance(1.0 / 30.0)
					item.skeleton.force_update_all_bone_transforms()
				if frame >= 30:
					timings.append((Time.get_ticks_usec() - begin) / 1000.0)
			var stats := _distribution(timings)
			stats["instances"] = actors.size()
			stats["triangles_if_all_drawn"] = actors.size() * 30000
			stats["bones"] = actors.size() * 65
			result.actor_batches.append(stats)
			_check(not actors[0].skeleton.get_bone_pose_rotation(head_id).is_equal_approx(head_before),
				"Benchmark actually advances the idle animation")
	actors[1].play_behavior("greeting_wave")
	_check(actors[0].current_behavior == "idle", "One actor cannot change another actor state")
	actors[1].player.advance(0.8)
	_check(actors[0].skeleton != actors[1].skeleton, "Independent playback")
	for actor in actors:
		actor.free()
	actors.clear()
	var kart = VEHICLE.new()
	kart.configure("fox", Color("357cba"), "comet")
	stage.add_child(kart)
	kart.set_process(false)
	var adapter = ADAPTER.new()
	kart.add_child(adapter)
	adapter.bind_visual(kart)
	adapter.set_process(false)
	var ik_times: Array[float] = []
	var worst_contact := 0.0
	for frame in range(150):
		var steer := sin(frame * 0.1)
		kart.set_motion(18.0, steer, false, false)
		kart._process(1.0 / 30.0)
		adapter.apply_vehicle_sample(18.0, steer, false)
		var begin := Time.get_ticks_usec()
		adapter.advance_visual(1.0 / 30.0)
		worst_contact = maxf(worst_contact, adapter.maximum_contact_error)
		if frame >= 30:
			ik_times.append((Time.get_ticks_usec() - begin) / 1000.0)
		_check(adapter.maximum_contact_error < 0.006, "Wheel contacts across continuous steering")
	result["one_kart_visual_ik"] = _distribution(ik_times)
	result["worst_contact_mm"] = worst_contact * 1000.0
	result["static_memory_bytes_at_peak_sample"] = int(Performance.get_monitor(Performance.MEMORY_STATIC))
	stage.free()
	await process_frame
	await process_frame
	_check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) == baseline, "No orphan nodes")
	result["checks"] = checks
	result["failures"] = failures
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file := FileAccess.open(output, FileAccess.WRITE)
	_check(file != null, "Benchmark report can be saved")
	if file != null:
		file.store_string(JSON.stringify(result, "\t") + "\n")
		file.close()
	print("[LumoAnimationCPU] ", JSON.stringify(result))
	quit(0 if failures == 0 else 1)
