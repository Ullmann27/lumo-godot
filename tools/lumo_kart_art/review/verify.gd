extends SceneTree
## Actual Godot import/instantiation and animation evaluation, without gameplay changes.

const CLIPS := ["idle", "kart_seated", "kart_steer_left", "kart_steer_right", "kart_jump", "celebrate"]
var repo := ""
var output := ""
var records: Array = []
var failures: Array[String] = []


func _initialize() -> void:
	repo = ProjectSettings.globalize_path("res://../../../").simplify_path()
	output = repo.path_join("evidence/lumo_kart_art/review/final_godot_import.json")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--repo="):
			repo = arg.trim_prefix("--repo=")
		elif arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
	call_deferred("_run")


func _walk_files(folder: String, result: Array[String]) -> void:
	var dir := DirAccess.open(folder)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		var path := folder.path_join(entry)
		if dir.current_is_dir() and not entry.begins_with("."):
			_walk_files(path, result)
		elif entry.ends_with(".glb"):
			result.append(path)
		entry = dir.get_next()
	dir.list_dir_end()


func _collect(node: Node, meshes: Array[MeshInstance3D], players: Array[AnimationPlayer], skeletons: Array[Skeleton3D]) -> void:
	if node is MeshInstance3D:
		meshes.append(node)
	if node is AnimationPlayer:
		players.append(node)
	if node is Skeleton3D:
		skeletons.append(node)
	for child in node.get_children():
		_collect(child, meshes, players, skeletons)


func _bone_sample(skeletons: Array[Skeleton3D]) -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	for skeleton in skeletons:
		skeleton.force_update_all_bone_transforms()
		for index in skeleton.get_bone_count():
			result.append(skeleton.get_bone_global_pose(index))
	return result


func _driver_contact_sample(skeletons: Array[Skeleton3D]) -> Dictionary:
	var result := {}
	for skeleton in skeletons:
		for name in ["Hand.L", "Hand.R", "Foot.L", "Foot.R", "Head", "Pelvis"]:
			var index := skeleton.find_bone(name)
			if index >= 0:
				var point := skeleton.global_transform * skeleton.get_bone_global_pose(index).origin
				result[name] = [point.x, point.y, point.z]
	return result


func _run() -> void:
	var paths: Array[String] = []
	_walk_files(repo.path_join("assets/kart/production"), paths)
	paths.sort()
	for path in paths:
		var relative := path.trim_prefix(repo + "/")
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		var error := doc.append_from_file(path, state)
		if error != OK:
			failures.append(relative + ": append_from_file " + str(error))
			continue
		# Every clip restores standing/seated root and limb transforms. Preserve
		# constant channels so a prior clip cannot leak its pose into the next one.
		var model: Node = doc.generate_scene(state, 30.0, false, false)
		if model == null:
			failures.append(relative + ": generate_scene failed")
			continue
		root.add_child(model)
		var meshes: Array[MeshInstance3D] = []
		var players: Array[AnimationPlayer] = []
		var skeletons: Array[Skeleton3D] = []
		_collect(model, meshes, players, skeletons)
		var material_surfaces := 0
		var surfaces := 0
		var skin_instances := 0
		var triangle_count := 0
		for mesh in meshes:
			if mesh.skin != null:
				skin_instances += 1
			for index in mesh.mesh.get_surface_count():
				surfaces += 1
				if mesh.get_active_material(index) != null:
					material_surfaces += 1
				var arrays: Array = mesh.mesh.surface_get_arrays(index)
				var indices: Variant = arrays[Mesh.ARRAY_INDEX]
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				triangle_count += (indices.size() if indices != null and not indices.is_empty() else vertices.size()) / 3
		var clips: Array = []
		for player in players:
			player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			for clip_name in player.get_animation_list():
				if clip_name == "RESET":
					continue
				var animation := player.get_animation(clip_name)
				player.play(clip_name, 0.0)
				player.seek(animation.length * 0.13, true)
				player.advance(0.0)
				var first := _bone_sample(skeletons)
				player.seek(animation.length * 0.61, true)
				player.advance(0.0)
				var second := _bone_sample(skeletons)
				var contacts := _driver_contact_sample(skeletons)
				var changed_bones := 0
				for index in mini(first.size(), second.size()):
					if not first[index].is_equal_approx(second[index]):
						changed_bones += 1
				clips.append({"name": clip_name, "length_seconds": animation.length,
					"tracks": animation.get_track_count(), "bones_changed_between_samples": changed_bones,
					"sampled_bone_positions_m": contacts})
				if "/drivers/" in path and clip_name == "kart_seated":
					for side in ["L", "R"]:
						var hand_key: String = "Hand." + side
						if not contacts.has(hand_key):
							failures.append(relative + ": missing hand contact bone " + hand_key)
							continue
						var point_data: Array = contacts[hand_key]
						var point := Vector3(point_data[0], point_data[1], point_data[2])
						var expected := Vector3(-0.16 if side == "L" else 0.16, 1.055, -0.34)
						if point.distance_to(expected) > 0.06:
							failures.append(relative + ": seated hand is outside the wheel grip envelope: " + hand_key + " " + str(point))
					if contacts.has("Head"):
						var head_data: Array = contacts.Head
						if float(head_data[1]) < 1.15 or float(head_data[1]) > 2.25:
							failures.append(relative + ": seated head height is outside the kart envelope")
				player.stop()
		if meshes.is_empty():
			failures.append(relative + ": no visible mesh")
		if material_surfaces != surfaces and not path.ends_with("_collision.glb"):
			failures.append(relative + ": missing material")
		if "/drivers/" in path:
			if skeletons.is_empty() or skin_instances == 0:
				failures.append(relative + ": missing usable Skeleton3D/skin")
			for expected in CLIPS:
				var matching: Array = clips.filter(func(clip: Dictionary) -> bool: return clip.name == expected)
				if matching.is_empty():
					failures.append(relative + ": missing clip " + expected)
				elif matching[0].bones_changed_between_samples == 0:
					failures.append(relative + ": sampled clip has no bone motion " + expected)
		records.append({"path": relative, "sha256": FileAccess.get_sha256(path),
			"meshes": meshes.size(), "surfaces": surfaces, "material_surfaces": material_surfaces,
			"triangles": triangle_count, "skeletons": skeletons.size(), "skin_instances": skin_instances, "clips": clips})
		model.free()
		await process_frame
	if paths.is_empty():
		failures.append("No assets found")
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write Godot verification report")
		quit(2)
		return
	file.store_string(JSON.stringify({"godot": Engine.get_version_info().string,
		"method": "GLTFDocument import, scene instantiation, material inventory, manual AnimationPlayer sampling",
		"rendered": false, "physical_android": false, "assets": records,
		"errors": failures, "passed": failures.is_empty()}, "  "))
	file.close()
	for failure in failures:
		printerr(failure)
	print("[LumoKartArtImport] ", "PASS" if failures.is_empty() else "FAIL", " assets=", records.size())
	quit(0 if failures.is_empty() else 1)
