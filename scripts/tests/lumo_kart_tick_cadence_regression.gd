extends SceneTree
## Real existing vehicle/model, manually sampled at different display cadences.
## Counts animation evaluations; this does not measure rendered or Android FPS.
const VEHICLE = preload("res://scripts/games/kart_vehicle.gd")
const CLIP_STEP := 1.0 / 30.0
const SAMPLE_SECONDS := 2
var checks := 0
var failures := 0
var samples: Array[Dictionary] = []
var kart


func _initialize() -> void:
	call_deferred("_run")


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("[LumoKartTickCadence] FAIL: ", label)


func _reset_adapter() -> void:
	kart.set_animated_lumo_enabled(false)
	kart.set_animated_lumo_enabled(true)
	kart.set_driver_runtime_state(false, false, false)
	kart.set_motion(18.0, 0.0, false, false)
	_check(is_instance_valid(kart.lumo_animation), "Existing rig is bound")
	_check(not kart.lumo_animation.is_processing(), "Vehicle owns the only visual clock")


func _hand_error() -> float:
	var skeleton: Skeleton3D = kart.lumo_animation.actor.skeleton
	var worst := 0.0
	for index in range(2):
		var bone := skeleton.find_bone("Hand.L" if index == 0 else "Hand.R")
		var hand := skeleton.to_global(skeleton.get_bone_global_pose(bone).origin)
		var anchor: Vector3 = kart.steering_wheel.to_global(kart.wheel_rest_grips[index])
		worst = maxf(worst, hand.distance_to(anchor))
	return worst


func _exercise_cadence(hz: int) -> void:
	_reset_adapter()
	var adapter = kart.lumo_animation
	var initial_transform: Transform3D = kart.transform
	var updates := 0
	var worst_contact := 0.0
	var largest_step := 0.0
	for frame in range(hz * SAMPLE_SECONDS):
		var previous: float = adapter.elapsed
		var steer := sin(float(frame) / float(hz) * TAU * 0.3)
		kart.set_motion(18.0, steer, false, absf(steer) > 0.6)
		kart._process(1.0 / float(hz))
		if adapter.elapsed > previous:
			updates += 1
			largest_step = maxf(largest_step, adapter.elapsed - previous)
		worst_contact = maxf(worst_contact, _hand_error())
		_check(kart.transform.is_equal_approx(initial_transform), "Animation preserves chassis")
	_check(updates == SAMPLE_SECONDS * 30, "%d Hz: exactly 30 clip evaluations per second" % hz)
	_check(absf(adapter.elapsed - float(SAMPLE_SECONDS)) < 0.000001,
		"%d Hz: no lost normal-frame duration" % hz)
	_check(worst_contact < 0.006, "%d Hz: both real hand anchors remain on the wheel" % hz)
	_check(largest_step <= CLIP_STEP + 0.000001, "%d Hz: uniform clip steps" % hz)
	var sample := {"input_hz": hz, "input_frames": hz * SAMPLE_SECONDS,
		"sample_seconds": SAMPLE_SECONDS, "clip_evaluations": updates,
		"clip_elapsed_seconds": adapter.elapsed, "largest_clip_step_seconds": largest_step,
		"worst_hand_contact_mm": worst_contact * 1000.0}
	samples.append(sample)
	print("[LumoKartTickCadence] ", JSON.stringify(sample))


func _exercise_pause() -> void:
	_reset_adapter()
	var adapter = kart.lumo_animation
	kart._process(1.0 / 120.0)
	kart.set_driver_runtime_state(false, false, true)
	var prior: float = adapter.elapsed
	var skeleton: Skeleton3D = adapter.actor.skeleton
	var head := skeleton.find_bone("Head")
	var pose := skeleton.get_bone_global_pose(head)
	for frame in range(120):
		kart._process(1.0 / 60.0)
	_check(adapter.elapsed == prior, "Pause does not advance the clip clock")
	_check(skeleton.get_bone_global_pose(head).is_equal_approx(pose), "Pause freezes the real head")
	kart.set_driver_runtime_state(false, false, false)
	for frame in range(3):
		kart._process(1.0 / 120.0)
		_check(adapter.elapsed == prior, "Resume does not replay paused time or a stale partial tick")
	kart._process(1.0 / 120.0)
	_check(absf(adapter.elapsed - prior - CLIP_STEP) < 0.000001,
		"Resume advances once after one fresh interval")


func _exercise_hitch_and_jitter() -> void:
	_reset_adapter()
	var adapter = kart.lumo_animation
	kart._process(1.237)
	_check(absf(adapter.elapsed - 0.10) < 0.000001, "Long frame remains capped at 100 ms")
	_check(adapter._tick >= 0.0 and adapter._tick < CLIP_STEP,
		"Long frame leaves only a fractional tick, never an animation backlog")
	var prior: float = adapter.elapsed
	var initial_remainder: float = adapter._tick
	var supplied := 0.0
	var largest_step := 0.0
	for frame in range(240):
		var delta: float = [1.0 / 50.0, 1.0 / 75.0, 1.0 / 144.0][frame % 3]
		var before: float = adapter.elapsed
		supplied += delta
		kart._process(delta)
		largest_step = maxf(largest_step, adapter.elapsed - before)
	_check(largest_step <= CLIP_STEP + 0.000001, "Normal frames after a hitch cannot create a catch-up burst")
	_check(absf(adapter.elapsed - prior + adapter._tick - initial_remainder - supplied) < 0.000001,
		"Variable normal frame lengths preserve their entire duration")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var output := args[0] if not args.is_empty() else "user://lumo-kart-tick-cadence.json"
	var orphan_baseline := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	kart = VEHICLE.new()
	kart.configure("fox", Color("357cba"), "comet")
	root.add_child(kart)
	kart.set_process(false)
	for hz in [30, 50, 60, 75, 90, 120, 144]:
		_exercise_cadence(hz)
	_exercise_pause()
	_exercise_hitch_and_jitter()
	var load_kind: String = kart.lumo_animation.actor.model_load_kind
	kart.free()
	await process_frame
	await process_frame
	_check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) == orphan_baseline,
		"Rebinding and teardown leave no orphan nodes")
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file := FileAccess.open(output, FileAccess.WRITE)
	_check(file != null, "Cadence report can be saved")
	var report := {"checks": checks, "failures": failures, "samples": samples,
		"model_load_kind": load_kind, "godot": Engine.get_version_info().string,
		"display": DisplayServer.get_name(), "android_test": false, "gpu_fps_measured": false}
	if file != null:
		file.store_string(JSON.stringify(report, "\t") + "\n")
		file.close()
	print("[LumoKartTickCadence] checks=", checks, " failures=", failures)
	if failures == 0:
		print("[LumoKartTickCadence] PASS real rig cadence, contact, pause, hitch and variable frame duration")
	quit(0 if failures == 0 else 1)
