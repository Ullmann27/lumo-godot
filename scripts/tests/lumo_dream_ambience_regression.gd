extends SceneTree
## Product-entry, pause, accessibility and resource-bound checks for ambient life.
const AMBIENCE = preload("res://scripts/systems/render/lumo_dream_ambience.gd")
const ENVIRONMENT = preload("res://scripts/systems/render/lumo_environment.gd")
const PRESETS = preload("res://scripts/systems/render/lumo_environment_creative_presets.gd")
var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("[DreamAmbience] " + message)


func _holder() -> Node3D:
	var holder := Node3D.new()
	root.add_child(holder)
	return holder


func _check_visual_only(node: Node) -> void:
	_check(not node is CollisionObject3D, "decoration must not intercept physics picking")
	_check(not node is Control, "decoration must not intercept touch controls")
	_check(not node is Light3D, "existing lighting remains authoritative")
	for child in node.get_children():
		_check_visual_only(child)


func _run() -> void:
	await process_frame
	await process_frame
	var router: Node = root.get_node("SceneRouter")
	var saved_options: Dictionary = router.get("launch_options").duplicate(true)
	router.set("launch_options", {"reduceAnimations": false})
	var performance: Node = root.get_node("PerformanceManager")
	var saved_profile: int = int(performance.get("current_profile"))
	var presets: Array[String] = [
		"creative_night", "wolkeninseln", "bauwelt_day",
		"puzzle_atelier", "rhythm_party", "treasure_day"
	]
	for preset in presets:
		var holder := _holder()
		var environment: Dictionary = ENVIRONMENT.apply(holder, preset, "high")
		var ambience := holder.get_node_or_null(AMBIENCE.NODE_NAME) as LumoDreamAmbience
		_check(ambience != null, "shared apply attaches " + preset)
		if ambience == null:
			holder.queue_free()
			continue
		_check(holder.get_node("WorldEnvironment") == environment.world, "original environment remains")
		_check(ambience.get_child_count() == 2, "exactly two instanced geometry batches")
		_check(ambience.process_mode == Node.PROCESS_MODE_PAUSABLE, "scene pause must stop animation")
		_check_visual_only(ambience)
		var before_count: int = holder.get_child_count()
		var same := AMBIENCE.attach(holder, preset, "high")
		_check(same == ambience and holder.get_child_count() == before_count, "reattach is idempotent")
		var high: Dictionary = ambience.render_state()
		ambience.set_quality_tier("medium")
		var medium: Dictionary = ambience.render_state()
		ambience.set_quality_tier("low")
		var low: Dictionary = ambience.render_state()
		_check(high.motes > medium.motes and medium.motes > low.motes, "quality scales " + preset)
		_check(low.motes > 0, "the lowest tier retains bounded life")
		_check(high.motes <= AMBIENCE.MAX_MOTES, "mote pool has a hard bound")
		_check(high.butterflies <= AMBIENCE.MAX_BUTTERFLIES, "butterfly pool has a hard bound")
		for batch: MultiMeshInstance3D in ambience.get_children():
			_check(batch.multimesh.mesh != null, "real geometry exists")
			_check(batch.multimesh.use_custom_data, "instance phases are present")
			_check(batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "no extra shadow passes")
			_check(batch.multimesh.custom_aabb.size.length() > 0, "animated geometry has explicit culling bounds")
		holder.queue_free()
		await process_frame

	for preset in ["bauwelt_day", "puzzle_atelier", "rhythm_party", "treasure_day"]:
		var holder := _holder()
		PRESETS.apply(holder, preset, "low")
		_check(holder.get_node_or_null(AMBIENCE.NODE_NAME) != null, "CreativeKit direct path: " + preset)
		holder.queue_free()
		await process_frame

	var holder := _holder()
	_check(AMBIENCE.attach(holder, "unknown_world") == null, "unsupported worlds are not decorated")
	_check(holder.get_child_count() == 0, "unknown preset creates no orphan nodes")
	var layer := AMBIENCE.attach(holder, "learning_garden")
	performance.call("set_profile", 0, false)
	_check(layer.quality_tier == "low", "app quality event reaches automatic layer")
	performance.call("set_profile", 2, false)
	_check(layer.quality_tier == "high", "quality can be raised without recreating the scene")
	var before: float = layer.animation_time
	await create_timer(0.06).timeout
	_check(layer.animation_time > before, "ordinary frames advance local animation")
	layer.set_reduced_motion(true)
	before = layer.animation_time
	await create_timer(0.06).timeout
	_check(is_equal_approx(layer.animation_time, before), "reduced motion freezes the local shader clock")
	layer.set_reduced_motion(false)
	paused = true
	before = layer.animation_time
	await create_timer(0.06).timeout
	_check(is_equal_approx(layer.animation_time, before), "paused scenes freeze shader animation")
	paused = false
	await create_timer(0.06).timeout
	_check(layer.animation_time > before, "animation resumes after scene pause")
	holder.queue_free()
	await process_frame

	router.set("launch_options", {"reduceAnimations": true})
	holder = _holder()
	layer = AMBIENCE.attach(holder, "learning_garden", "high")
	_check(layer.reduced_motion and not layer.is_processing(), "host accessibility reaches the layer")
	_check(layer.render_state().motes > 0, "reduced motion preserves the static composition")
	holder.queue_free()
	await process_frame
	router.set("launch_options", saved_options)
	performance.call("set_profile", saved_profile, false)
	print("[DreamAmbience] %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)
