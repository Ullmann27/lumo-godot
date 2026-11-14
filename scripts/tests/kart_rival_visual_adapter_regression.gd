extends SceneTree
## In-memory skinned fixtures test the adapter without fabricating roster assets.
const CONTRACT = preload("res://scripts/games/kart_rival_model_contract.gd")
const ADAPTER = preload("res://scripts/games/kart_rival_visual_adapter.gd")
const ROSTER = preload("res://scripts/games/lumo_opponent_roster.gd")
const VEHICLE = preload("res://scripts/games/kart_vehicle.gd")
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error(label)


func _fixture() -> Node3D:
	var model := Node3D.new()
	model.name = "FixtureOnly"
	var skeleton := Skeleton3D.new()
	skeleton.name = "Skeleton3D"
	skeleton.add_bone("Chest")
	model.add_child(skeleton)
	skeleton.owner = model
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-0.1, 0, 0), Vector3(0, 0.2, 0), Vector3(0.1, 0, 0)])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.FORWARD, Vector3.FORWARD, Vector3.FORWARD])
	arrays[Mesh.ARRAY_BONES] = PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
	arrays[Mesh.ARRAY_WEIGHTS] = PackedFloat32Array([1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0])
	var geometry := ArrayMesh.new()
	geometry.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var skin := Skin.new()
	skin.add_bind(0, Transform3D.IDENTITY)
	var mesh := MeshInstance3D.new()
	mesh.name = "Skin"
	mesh.mesh = geometry
	mesh.skin = skin
	mesh.skeleton = NodePath("../Skeleton3D")
	model.add_child(mesh)
	mesh.owner = model
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	model.add_child(player)
	player.owner = model
	var library := AnimationLibrary.new()
	for key in ["kart_seated", "kart_steer_left"]:
		var clip := Animation.new()
		clip.length = 1.0
		clip.loop_mode = Animation.LOOP_LINEAR
		var track: int = clip.add_track(Animation.TYPE_ROTATION_3D)
		clip.track_set_path(track, NodePath("Skeleton3D:Chest"))
		clip.rotation_track_insert_key(track, 0.0, Quaternion.IDENTITY)
		clip.rotation_track_insert_key(track, 0.5, Quaternion(Vector3.UP, 0.10))
		library.add_animation(key, clip)
	player.add_animation_library("", library)
	return model


func _vehicle_cadence(packed: PackedScene, hz: int) -> void:
	# The real island supplies runtime state every physics frame, even when
	# suspension has not changed. Exercise that full path with a test-only
	# skinned fixture; the production roster remains explicitly unready.
	var kart: LumoRaceKart = VEHICLE.new()
	kart.configure("rabbit", Color.WHITE, "comet")
	root.add_child(kart)
	kart.set_process(false)
	var visual := ADAPTER.new()
	kart.add_child(visual)
	_check(visual.bind_scene(packed), "%d Hz vehicle fixture binds an actual rig" % hz)
	kart.rival_visual = visual
	kart.driver.hide()
	kart._refresh_far_proxy()
	var evaluations := 0
	for frame in range(hz):
		var previous: float = visual.elapsed
		kart.set_driver_runtime_state(false, false, false)
		kart._process(1.0 / float(hz))
		if visual.elapsed > previous:
			evaluations += 1
	_check(evaluations == 30, "%d Hz repeated vehicle runtime state retains 30 visual evaluations" % hz)
	_check(is_equal_approx(visual.elapsed, 1.0), "%d Hz repeated unsuspended state preserves one second of animation" % hz)
	for frame in range(hz):
		kart.set_driver_runtime_state(false, false, true)
		kart._process(1.0 / float(hz))
	_check(is_equal_approx(visual.elapsed, 1.0), "%d Hz repeated suspended state freezes the rig" % hz)
	for frame in range(hz):
		kart.set_driver_runtime_state(false, false, false)
		kart._process(1.0 / float(hz))
	_check(is_equal_approx(visual.elapsed, 2.0), "%d Hz resume continues without paused time or repeated resets" % hz)
	kart.free()


func _run() -> void:
	for entry in ROSTER.all():
		_check(not bool(entry.runtimeReady), "Pending " + str(entry.id) + " remains explicitly unready")
		_check(ROSTER.racing_scene(str(entry.id)) == null, "Pending model is never silently instantiated")
	_check(not ROSTER.ready_for_race(), "The roster cannot claim assets that are still absent")
	_check(not CONTRACT.model_path_allowed("res://assets/characters/rivals/../lumo.glb"), "Parent traversal is outside the rival model contract")
	_check(not CONTRACT.model_path_allowed("res://assets/characters/rivals/test.tscn"), "Runtime roster accepts imported GLB data only")
	var good := _fixture()
	var inspection: Dictionary = CONTRACT.inspect(good)
	_check(bool(inspection.valid), "A real skin, local skeleton and seated clip satisfy the contract")
	var packed := PackedScene.new()
	_check(packed.pack(good) == OK, "In-memory test skin can be instantiated")
	var player: AnimationPlayer = good.get_node("AnimationPlayer")
	var clip: Animation = player.get_animation("kart_seated")
	clip.track_set_path(0, NodePath("../Outside:Chest"))
	_check(not bool(CONTRACT.inspect(good).valid), "Animation paths escaping the model are rejected")
	clip.track_set_path(0, NodePath("Skeleton3D:MissingBone"))
	_check(not bool(CONTRACT.inspect(good).valid), "Missing bone tracks are rejected")
	clip.track_set_path(0, NodePath("Skeleton3D:Chest"))
	var method: int = clip.add_track(Animation.TYPE_METHOD)
	clip.track_set_path(method, NodePath("Skeleton3D"))
	clip.track_insert_key(method, 0.0, {"method": "reset_bone_poses", "args": []})
	_check(not bool(CONTRACT.inspect(good).valid), "Executable animation callbacks are rejected")
	clip.remove_track(method)
	good.get_node("Skin").skin = null
	_check(not bool(CONTRACT.inspect(good).valid), "Static meshes cannot masquerade as a rigged driver")
	good.free()
	# PackedScene resources are shared; build a fresh valid fixture after negative mutations.
	good = _fixture()
	_check(packed.pack(good) == OK, "Fresh test-only rig is packed")
	good.free()
	ROSTER._validated_scenes["rabbit"] = packed
	_check(ROSTER.racing_scene("rabbit") == null, "An old cached model cannot override explicit unready state")
	ROSTER._validated_scenes.erase("rabbit")
	var adapter := ADAPTER.new()
	root.add_child(adapter)
	_check(adapter.bind_scene(packed), "Adapter actually instantiates the valid rig")
	_check(adapter.model != null and adapter.player != null and adapter.get_child_count() == 1, "Exactly one imported model is present")
	_check(not adapter.bind_scene(packed), "Repeated binding cannot create a second driver")
	adapter.advance_tick(1.0 / 60.0)
	_check(is_zero_approx(adapter.elapsed), "One half tick cannot double-evaluate an animation")
	adapter.advance_tick(1.0 / 60.0)
	_check(is_equal_approx(adapter.elapsed, 1.0 / 30.0), "Vehicle clock advances the rig once per visual tick")
	adapter.set_suspended(true)
	var before: float = adapter.elapsed
	adapter.advance_tick(1.0)
	_check(adapter.elapsed == before, "Paused vehicle freezes the imported rig")
	adapter.set_suspended(false)
	adapter.apply_vehicle_sample(10, -0.7, false)
	adapter.advance_tick(1.0 / 30.0)
	_check(adapter._current == "kart_steer_left", "Authored steering clip is selected")
	adapter.apply_vehicle_sample(10, 0.7, false)
	adapter.advance_tick(1.0 / 30.0)
	_check(adapter._current == "kart_seated", "Missing optional clips use the valid seated pose")
	adapter.set_reduced_motion(true)
	before = adapter.elapsed
	adapter.advance_tick(0.3)
	_check(adapter.elapsed == before, "Reduced motion keeps the seated rig still")
	adapter.set_reduced_motion(false)
	before = adapter.elapsed
	var evaluations := 0
	for frame in range(50):
		var previous: float = adapter.elapsed
		adapter.advance_tick(1.0 / 50.0)
		if adapter.elapsed > previous:
			evaluations += 1
	_check(evaluations == 30 and is_equal_approx(adapter.elapsed - before, 1.0), "50 Hz input preserves exactly 30 evaluations and all animation time")
	adapter.advance_tick(1.25)
	_check(adapter.elapsed - before <= 1.100001 and adapter._tick < 1.0 / 30.0, "A long frame caps work and retains no whole-tick backlog")
	adapter.free()
	_vehicle_cadence(packed, 60)
	_vehicle_cadence(packed, 144)
	var kart: LumoRaceKart = VEHICLE.new()
	kart.configure("rabbit", Color.WHITE, "comet")
	kart.set_reference_rival_enabled(true)
	_check(kart.rival_visual == null, "Reference preference is safe before entering the tree")
	root.add_child(kart)
	kart.set_process(false)
	_check(kart.rival_visual == null and kart.driver.visible, "Unready reference preserves the current full 3D driver")
	kart.set_reference_rival_enabled(true)
	_check(kart.rival_visual == null, "Repeated preference never invents a missing model")
	kart.set_reference_rival_enabled(false)
	_check(kart.driver.visible, "Disabling references keeps the real fallback visible")
	kart.free()
	print("[RivalAdapter] checks=", checks, " failures=", failures.size())
	if failures.is_empty():
		print("[RivalAdapter] PASS: actual rig instantiation, validation, one clock, pause and honest readiness")
	quit(0 if failures.is_empty() else 1)
