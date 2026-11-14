extends SceneTree
## Screenshots from the real Godot scene, not prerendered design mockups.
var output_dir := ""
const IDENTITY = preload("res://scripts/tests/helpers/game_hub_original_identity.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	output_dir = OS.get_environment("LUMO_HUB_CAPTURE_DIR")
	if output_dir.is_empty() or DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		printerr("[LumoHubCapture] Missing writable evidence directory")
		quit(1)
		return
	root.get_node("SceneRouter").launch_options = {
		"grade": 2, "subject": "Mathematik",
		"childKey": "capture-no-production-save", "reduceAnimations": false
	}
	root.size = Vector2i(1080, 1920)
	var packed := load("res://scenes/games/game_hub.tscn") as PackedScene
	if packed == null:
		printerr("[LumoHubCapture] Native games scene could not be imported")
		quit(1)
		return
	var hub: Node = packed.instantiate()
	root.add_child(hub)
	var evidence: Array[Dictionary] = []
	for spec in [
		{"size": Vector2i(1080, 1920), "name": "hub_portrait.png"},
		{"size": Vector2i(2400, 1080), "name": "hub_fold_landscape.png"},
	]:
		root.size = spec.size
		for frame in range(32):
			await process_frame
		var identity: Dictionary = IDENTITY.inspect(hub)
		if not identity.failures.is_empty():
			printerr("[LumoHubCapture] Original identity failed: ", identity.failures)
			quit(1)
			return
		var bounds: Rect2 = IDENTITY.projected_mesh_bounds(hub)
		var hero := hub.find_child("OriginalFox3DHeroSpace", true, false) as Control
		if not bounds.has_area() or not hero.get_global_rect().encloses(bounds):
			printerr("[LumoHubCapture] Original fox is outside its free hero area: ", bounds,
				" hero=", hero.get_global_rect())
			quit(1)
			return
		var controls := {}
		for control_name in ["ReturnToHome", "ExistingLearningOptions", "LiveGameRoutes"]:
			var control := hub.find_child(control_name, true, false) as Control
			if control == null or control.get_global_rect().intersects(bounds):
				printerr("[LumoHubCapture] Original fox overlaps required controls: ", control_name)
				quit(1)
				return
			controls[control_name] = _rect_values(control.get_global_rect())
		var actual: Image = root.get_texture().get_image()
		if actual == null or actual.is_empty():
			printerr("[LumoHubCapture] GPU failed to return a rendered frame")
			quit(1)
			return
		if actual.get_size() != spec.size:
			printerr("[LumoHubCapture] Wrong rendered dimensions: ", actual.get_size())
			quit(1)
			return
		var path := output_dir.path_join(spec.name)
		if actual.save_png(path) != OK:
			printerr("[LumoHubCapture] Cannot write original screenshot ", path)
			quit(1)
			return
		print("[LumoHubCapture] screenshot ", spec.name, " ", spec.size)
		identity["png"] = str(spec.name)
		identity["pixels"] = [spec.size.x, spec.size.y]
		identity["viewport"] = [root.get_visible_rect().size.x, root.get_visible_rect().size.y]
		identity["hero_rect"] = _rect_values(hero.get_global_rect())
		identity["projected_mesh_rect"] = _rect_values(bounds)
		identity["control_rects"] = controls
		evidence.append(identity)
	var manifest := FileAccess.open(output_dir.path_join("hub-original-identity.json"), FileAccess.WRITE)
	if manifest == null:
		printerr("[LumoHubCapture] Cannot write actual original identity evidence")
		quit(1)
		return
	manifest.store_string(JSON.stringify({"captures": evidence}, "\t") + "\n")
	manifest.close()
	hub.queue_free()
	print("[LumoHubCapture] PASS 2 original current-source rendered PNGs")
	quit(0)


func _rect_values(value: Rect2) -> Array[float]:
	return [value.position.x, value.position.y, value.size.x, value.size.y]
