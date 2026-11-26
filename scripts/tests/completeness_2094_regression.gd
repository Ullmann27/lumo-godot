extends SceneTree
## Real asset/route gate: a recovered file alone is not proof of use.
const BRIDGE = preload("res://scripts/systems/host_bridge.gd")
const ACTOR = preload("res://scripts/characters/lumo/lumo_rigged_actor.gd")
const PROPS := "res://assets/characters/lumo_nextgen_chat3/Lumo-Learning-Objects.glb"
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		printerr("[Completeness2094] FAIL " + description)

func _run() -> void:
	var bridge := root.get_node("HostBridge")
	var router := root.get_node("SceneRouter")
	var old_options: Dictionary = bridge.get("_options").duplicate(true)
	var old_host: Object = bridge.get("_host")
	var old_router: Dictionary = router.get("launch_options").duplicate(true)
	var transport := Node.new()
	root.add_child(transport)
	bridge.set("_host", transport)
	var options := BRIDGE.validated_options({"game": "stars", "childKey": "stars-test", "sessionId": "test-stars", "grade": 3, "stars": 12})
	_check(options.scene == "stars", "Android host accepts Sternenjagd without Kart fallback")
	bridge.set("_options", options)
	var packed := load("res://scenes/app/boot.tscn") as PackedScene
	var boot := packed.instantiate()
	boot.set("auto_transition", false)
	root.add_child(boot)
	await process_frame
	await process_frame
	var deadline := Time.get_ticks_msec() + 30000
	while boot.get("load_phase") not in ["ready", "error"] and Time.get_ticks_msec() < deadline:
		await create_timer(0.01).timeout
	_check(boot.get("target_scene") == "stars", "boot selects registered Sternenjagd")
	_check(boot.get("load_phase") == "ready", "Sternenjagd PackedScene is ready")
	_check(boot.get_node("Layer/Title").text == "LUMO STERNENJAGD", "real loading title")
	var resources: Dictionary = boot.get("_resources")
	_check(resources.has("res://scenes/games/star_collect.tscn"), "real scene loaded")
	var routed: Dictionary = router.get("launch_options")
	_check(routed.get("childKey") == "stars-test" and routed.get("grade") == 3, "profile and grade retained")
	boot.queue_free()
	await process_frame
	bridge.set("_host", old_host)
	bridge.set("_options", old_options)
	router.set("launch_options", old_router)
	transport.queue_free()

	var original := ACTOR.new()
	root.add_child(original)
	_check(original.is_usable() and not original.using_learning_model, "default game actor remains original")
	var learning := ACTOR.new()
	learning.prefer_learning_model = true
	root.add_child(learning)
	await process_frame
	_check(learning.is_usable() and learning.using_learning_model, "recovered learning actor selected")
	if learning.is_usable() and learning.using_learning_model:
		_check(learning.skeleton.get_bone_count() == 65, "original skeleton contract")
		for clip in ["learn_celebrate", "learn_encourage", "learn_explain", "learn_farewell", "learn_idle_breathe", "learn_interrupt", "learn_listen", "learn_nod", "learn_point", "learn_return_listen", "learn_think", "learn_unsure"]:
			_check(learning.player.has_animation(clip), "authored clip " + clip)
		_check(learning.play_behavior("learn_listen"), "authored animation callable")
		_check(learning.mouth_supported and not learning.phoneme_lipsync_supported, "honest amplitude animation contract")
		var mouth: MeshInstance3D = learning.get("_mouth_mesh")
		var index: int = learning.get("_mouth_index")
		_check(is_instance_valid(mouth) and index >= 0, "original viseme A binding")
		if is_instance_valid(mouth) and index >= 0:
			learning.apply_speech_sample(0.2, 0.7, true)
			_check(mouth.get_blend_shape_value(index) > 0.0, "real envelope opens mouth")
			learning._advance_face(0.4)
			_check(is_zero_approx(mouth.get_blend_shape_value(index)), "stale sample clears mouth")
			learning.apply_speech_sample(0.6, 0.7, true)
			learning.set_suspended(true)
			_check(is_zero_approx(mouth.get_blend_shape_value(index)), "pause clears mouth")
			learning.set_suspended(false)
			learning.apply_speech_sample(0.9, 0.7, true)
			learning.cancel_teaching_performance()
			_check(is_zero_approx(mouth.get_blend_shape_value(index)), "cancel clears mouth")
	_check(ResourceLoader.exists(PROPS, "PackedScene"), "original educational prop pack importable")
	original.queue_free()
	learning.queue_free()
	await process_frame
	if failures.is_empty():
		print("[Completeness2094] PASS %d route, actor, and asset checks" % checks)
	quit(0 if failures.is_empty() else 1)
