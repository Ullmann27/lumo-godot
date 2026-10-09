extends SceneTree
## Safety contract for the non-driveable Sky Halo 360-degree authoring prototype.
const AUTHORING_SCENE = preload("res://scenes/games/track_authoring/sky_halo_loop_authoring.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := AUTHORING_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	assert(scene.get_meta("track_id") == "bergwelt")
	assert(scene.get_meta("setpiece_id") == "sky_halo_loop")
	assert(scene.get_meta("runtime_driveable") == false)
	assert(scene.get_meta("collision_included") == false)
	assert(scene.get_meta("requires_inverted_physics_contract") == true)
	var guide := scene.get_node("AuthoringOnly_NoRuntimeCollision")
	assert(guide != null)
	var road := guide.get_node("SkyHaloLoop_360deg_10p8mRoad") as MeshInstance3D
	assert(road != null and road.mesh != null)
	assert(road.get_meta("driveable") == false)
	assert(absf(float(road.get_meta("road_width_m")) - 10.8) < 0.001)
	var bounds := road.mesh.get_aabb()
	assert(bounds.size.x >= 10.7)
	assert(bounds.size.y >= 23.5, "360-degree guide must retain a real vertical loop envelope")
	assert(bounds.size.z >= 23.5)
	_assert_no_runtime_physics(scene)
	print(
		"[SkyHaloContract] authoring-only loop bounds=",
		bounds.size,
		" collision=false runtime=false PASS"
	)
	scene.free()
	quit(0)


func _assert_no_runtime_physics(node: Node) -> void:
	assert(not node is CollisionObject3D, "Authoring prototype must not contain runtime collision bodies")
	assert(not node is CollisionShape3D, "Authoring prototype must not contain collision shapes")
	for child in node.get_children():
		_assert_no_runtime_physics(child)
