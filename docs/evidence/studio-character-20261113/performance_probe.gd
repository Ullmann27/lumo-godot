extends SceneTree
## Bounded native CPU probe. No renderer, device frame rate or GPU claim.
## Compares the original source against current poses on identical real skins.
const ACTOR = preload("res://scripts/characters/lumo/lumo_rigged_actor.gd")
const WALK = preload("res://scripts/characters/lumo/lumo_walk_locomotion.gd")
const PLATFORM = preload("res://scripts/characters/lumo/lumo_platform_pose.gd")
const EVIDENCE = "res://docs/evidence/studio-character-20261113/"
const DT: float = 1.0 / 60.0
const WARMUP: int = 30
const MEASURED_PER_PASS: int = 240
var failures: Array[String] = []
var scripts: Dictionary = {}
var cycle: Array[Dictionary] = []


class GardenHost:
	extends Node3D
	var reduced_motion: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error("[StudioCPU] " + message)


func _frozen(filename: String) -> GDScript:
	var source := GDScript.new()
	source.source_code = FileAccess.get_file_as_string(EVIDENCE + filename)
	_check(source.reload() == OK, "baseline source compiles: " + filename)
	return source


func _tick(pose, mode: String, sample: Dictionary) -> void:
	if mode == "walk":
		pose.advance(DT, 1.4)
	else:
		pose.advance(sample.velocity, sample.grounded, DT)


func _counters() -> Dictionary:
	return {
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"static_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
	}


func _batch(variant: String, mode: String, count: int) -> Dictionary:
	var stage := Node3D.new()
	root.add_child(stage)
	var actors: Array = []
	var poses: Array = []
	for _index in range(count):
		var actor = ACTOR.new()
		stage.add_child(actor)
		actor.set_process(false)
		actor.player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		actor.player.play("idle", 0.0)
		actor.player.seek(0.0, true)
		actor.player.advance(0.0)
		actor.player.pause()
		var source: GDScript = scripts[variant][mode]
		var pose = source.new()
		_check(pose.bind(actor.skeleton), "bind independent original skeleton")
		actors.append(actor)
		poses.append(pose)
	for tick in range(WARMUP):
		for pose in poses:
			_tick(pose, mode, cycle[tick])
	var durations := PackedInt64Array()
	durations.resize(MEASURED_PER_PASS)
	var before: Dictionary = _counters()
	for tick in range(MEASURED_PER_PASS):
		var sample: Dictionary = cycle[tick]
		var start: int = Time.get_ticks_usec()
		for pose in poses:
			_tick(pose, mode, sample)
		durations[tick] = Time.get_ticks_usec() - start
	var after: Dictionary = _counters()
	_check(after.objects == before.objects, "no retained object growth during pose ticks")
	_check(after.resources == before.resources, "no retained resource growth during pose ticks")
	_check(after.orphans == before.orphans, "no orphan growth during pose ticks")
	for pose in poses:
		pose.stop()
	poses.clear()
	actors.clear()
	stage.free()
	return {"durations_us": durations, "before": before, "after": after}


func _stats(values: PackedInt64Array, count: int) -> Dictionary:
	var sorted: PackedInt64Array = values.duplicate()
	sorted.sort()
	var middle: int = sorted.size() / 2
	var median: float = (float(sorted[middle - 1]) + float(sorted[middle])) * 0.5
	var p95: float = float(sorted[ceili(float(sorted.size()) * 0.95) - 1])
	return {
		"samples": sorted.size(), "batch_median_us": median,
		"batch_p95_us": p95, "batch_max_us": sorted[-1],
		"per_actor_median_us": median / count,
		"per_actor_p95_us": p95 / count,
	}


func _leaf_probe() -> Dictionary:
	var host := GardenHost.new()
	root.add_child(host)
	var atelier = load("res://scripts/learning/learning_atelier.gd").new()
	host.add_child(atelier)
	var surfaces: int = 0
	var weights: Array[float] = []
	for node in atelier.find_children("*", "MeshInstance3D", true, false):
		for index in range(node.mesh.get_surface_count()):
			var material = node.get_active_material(index)
			if material is ShaderMaterial and material.shader == atelier.LEAF_SHADER:
				surfaces += 1
				weights.append(float(material.get_shader_parameter("motion_weight")))
	_check(surfaces > 0, "actual imported leaves use shader")
	_check(not atelier.is_processing() and not atelier.is_physics_processing(), "atelier adds no per-frame script callback")
	for weight in weights:
		_check(weight >= 0.0 and weight <= 1.0, "applied wind strength stays bounded")
	var report: Dictionary = {
		"shader_sha256": FileAccess.get_sha256("res://assets/learning/studio/studio_leaf_motion.gdshader"),
		"atelier_sha256": FileAccess.get_sha256("res://scripts/learning/learning_atelier.gd"),
		"actual_shader_surfaces": surfaces, "applied_motion_weights": weights,
		"atelier_process_callback_enabled": atelier.is_processing(),
		"atelier_physics_callback_enabled": atelier.is_physics_processing(),
		"max_vertex_offset_x_model_metres": 0.022,
		"max_vertex_offset_z_model_metres": 0.013,
		"max_vertex_offset_length_model_metres": sqrt(0.022 * 0.022 + 0.013 * 0.013),
		"gpu_time_measured": false,
		"source_audit": "TIME-driven sin/cos and smoothstep; no shader loops or texture lookups; uniforms set once during ready; no leaf CPU tick added",
	}
	host.free()
	return report


func _run() -> void:
	scripts = {
		"before": {"walk": _frozen("before_walk_locomotion.gd.txt"), "platform": _frozen("before_platform_pose.gd.txt")},
		"after": {"walk": WALK, "platform": PLATFORM},
	}
	for tick in range(MEASURED_PER_PASS):
		var velocity := Vector3(0, 0, 1.4)
		var grounded: bool = true
		if tick >= 60 and tick < 120:
			velocity = Vector3(0, 0, 5.5)
		elif tick >= 120 and tick < 160:
			velocity = Vector3(0, lerpf(8.5, 0.4, float(tick - 120) / 40.0), 2.0)
			grounded = false
		elif tick >= 160 and tick < 200:
			velocity = Vector3(0, lerpf(-0.3, -8.0, float(tick - 160) / 40.0), 2.0)
			grounded = false
		elif tick >= 200:
			velocity = Vector3.ZERO
		cycle.append({"velocity": velocity, "grounded": grounded})
	var result: Dictionary = {
		"godot": Engine.get_version_info().string, "platform": OS.get_name(),
		"display": DisplayServer.get_name(), "baseline_commit": "ada5ed81",
		"integration_snapshot_label": "9eb25fcb", "source_sha256": {},
		"timer": "Time.get_ticks_usec, monotonic native microseconds",
		"scope": "Pose sampling and actual 65-bone Skeleton3D update only; excludes render/GPU/physics/full-app time",
		"simulation_delta_seconds": DT, "warmup_ticks_per_pass": WARMUP,
		"passes": 2, "measured_ticks_per_pass": MEASURED_PER_PASS,
		"measurement_order": "before, after in pass 1; after, before in pass 2",
		"platform_cycle": "60 walk,60 sprint,40 ascending,40 descending,40 grounded/landing ticks",
		"walk_cycle": "constant 1.4 metres/second; identical 60Hz delta",
		"physical_android_measured": false, "gpu_fps_measured": false,
		"allocation_scope": "Retained Object/Resource/orphan counters and static bytes; transient allocator traffic was not profiled",
		"rows": [],
	}
	# Reading a fresh counter Dictionary itself consumes retained probe memory.
	# Measure that overhead with zero pose ticks before interpreting byte deltas.
	var control_before: Dictionary = _counters()
	var control_after: Dictionary = _counters()
	result["counter_only_zero_tick_control"] = {
		"before": control_before, "after": control_after,
		"static_bytes_delta": int(control_after.static_bytes) - int(control_before.static_bytes),
	}
	for path in ["scripts/characters/lumo/lumo_rigged_actor.gd", "scripts/characters/lumo/lumo_walk_locomotion.gd", "scripts/characters/lumo/lumo_platform_pose.gd", "scripts/characters/lumo/lumo_body_space_pose.gd", "assets/characters/lumo_animated/lumo_studio_clips.gd", "docs/evidence/studio-character-20261113/before_platform_pose.gd.txt", "docs/evidence/studio-character-20261113/before_walk_locomotion.gd.txt"]:
		result.source_sha256[path] = FileAccess.get_sha256("res://" + path)
	for count in [1, 4, 8]:
		for mode in ["walk", "platform"]:
			var timings: Dictionary = {"before": PackedInt64Array(), "after": PackedInt64Array()}
			var allocations: Dictionary = {"before": [], "after": []}
			for pass_index in range(2):
				var order: Array = ["before", "after"] if pass_index == 0 else ["after", "before"]
				for variant in order:
					var batch: Dictionary = _batch(variant, mode, count)
					var accumulated: PackedInt64Array = timings[variant]
					accumulated.append_array(batch.durations_us)
					timings[variant] = accumulated
					allocations[variant].append({"before": batch.before, "after": batch.after})
			var before: Dictionary = _stats(timings.before, count)
			var after: Dictionary = _stats(timings.after, count)
			var row: Dictionary = {"mode": mode, "actors": count, "before": before, "after": after, "median_ratio": after.batch_median_us / maxf(1.0, before.batch_median_us), "p95_ratio": after.batch_p95_us / maxf(1.0, before.batch_p95_us), "counters": allocations}
			result.rows.append(row)
			print("[StudioCPU] ", mode, " actors=", count, " before_median/p95_us=", before.batch_median_us, "/", before.batch_p95_us, " after_median/p95_us=", after.batch_median_us, "/", after.batch_p95_us, " ratio=", row.median_ratio)
	result["leaf_shader"] = _leaf_probe()
	result["failures"] = failures
	var file := FileAccess.open(EVIDENCE + "performance_cpu_comparison.json", FileAccess.WRITE)
	if file == null:
		push_error("[StudioCPU] Unable to save comparison")
		quit(1)
		return
	file.store_string(JSON.stringify(result, "  ") + "\n")
	file.close()
	print("[StudioCPU] ", "PASS" if failures.is_empty() else "FAIL", " 1/4/8 original actors, 480 native timed ticks per path, no retained object/resource growth; GPU/physical device unmeasured")
	quit(0 if failures.is_empty() else 1)
