extends SceneTree
const VEHICLE = preload("res://scripts/games/kart_vehicle.gd")
const STAGE = preload("res://scripts/games/kart_stage.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var output := args[0]
	var adapter_source := args[1]
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1000, 800)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var stage := Node3D.new()
	root.add_child(stage)
	var built: Dictionary = STAGE.build(stage)
	var camera: Camera3D = built.camera
	camera.look_at_from_position(Vector3(4.4, 1.05, 0), Vector3(0, 0.90, 0))
	camera.fov = 37
	camera.current = true
	var kart = VEHICLE.new()
	kart.configure("fox", Color("357cba"), "gecko_velo")
	stage.add_child(kart)
	kart.set_process(false)
	kart.driver.hide()
	var adapter = load(adapter_source).new()
	kart.add_child(adapter)
	assert(adapter.bind_visual(kart))
	adapter.set_process(false)
	adapter.set_reduced_motion(true)
	adapter.apply_vehicle_sample(0.0, 0.0, false)
	adapter.advance_visual(0.0)
	var skeleton: Skeleton3D = adapter.actor.skeleton
	var report := {"adapter_source": adapter_source, "pose": "kart_seated@0.3, reduced motion",
		"model_sha256": FileAccess.get_sha256(adapter.actor.MODEL), "bones": {},
		"actor_transform": _transform_values(adapter.actor.global_transform), "pedal_centres": {},
		"all_bones": {}, "skin_meshes": {},
		"godot": Engine.get_version_info().string, "display": DisplayServer.get_name()}
	for side in ["L", "R"]:
		for part in ["Thigh.", "Shin.", "Foot.", "Toe.", "ToeTip."]:
			var name: String = part + side
			var index := skeleton.find_bone(name)
			var pose := skeleton.global_transform * skeleton.get_bone_global_pose(index)
			report.bones[name] = {"origin": [pose.origin.x, pose.origin.y, pose.origin.z],
				"transform": str(pose), "pose_rotation": str(skeleton.get_bone_pose_rotation(index))}
	for index in range(skeleton.get_bone_count()):
		report.all_bones[skeleton.get_bone_name(index)] = _transform_values(skeleton.global_transform * skeleton.get_bone_global_pose(index))
	for mesh in adapter.actor.find_children("*", "MeshInstance3D", true, false):
		report.skin_meshes[str(adapter.actor.get_path_to(mesh))] = _transform_values(mesh.global_transform)
	for node in kart.find_children("FootPedal*", "MeshInstance3D", true, false):
		report.pedal_centres[node.name] = str(node.global_position)
	if DisplayServer.get_name() != "headless":
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(output.path_join("gecko-side.png")) == OK)
	var file := FileAccess.open(output.path_join("pose.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()
	stage.free()
	await process_frame
	await process_frame
	print("[LumoSeatProbe] ", JSON.stringify(report))
	quit(0)

func _transform_values(value: Transform3D) -> Array:
	return [value.basis.x.x, value.basis.x.y, value.basis.x.z,
		value.basis.y.x, value.basis.y.y, value.basis.y.z,
		value.basis.z.x, value.basis.z.y, value.basis.z.z,
		value.origin.x, value.origin.y, value.origin.z]
