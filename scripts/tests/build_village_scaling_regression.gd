extends SceneTree
## Reuse the published village scale review against the production collector.
## Counts are engine nodes, never a renderer frame-rate or device measurement.
const STATE = preload("res://scripts/creative/build_settlement_state.gd")
const REGION = preload("res://scripts/creative/build_settlement_region.gd")
var checks := 0
var failures: Array[String] = []
var capture_dir := ""


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_warning("[VillageScaling] " + message)


func _frames(count := 4) -> void:
	for _frame in range(count):
		await physics_frame


func _counts(city: Node3D) -> Dictionary:
	var batches: Variant = city.get("overview_nodes")
	var roofs := 0
	var distant := 0
	if batches is Array:
		for batch: MultiMeshInstance3D in batches:
			if str(batch.name) == "VillageMap_roofs":
				roofs += batch.multimesh.instance_count
			else:
				distant += batch.multimesh.instance_count
	return {
		"nodes": city.find_children("*", "Node", true, false).size(),
		"meshes": city.find_children("*", "MeshInstance3D", true, false).size(),
		"bodies": city.find_children("*", "StaticBody3D", true, false).size(),
		"detailed": city.facility_nodes.size(),
		"batches": batches.size() if batches is Array else 0,
		"distant": distant,
		"roofs": roofs
	}


func _assert_budget(city: Node3D, label: String) -> void:
	var counts := _counts(city)
	print("[VillageScaling] ", label, " ", JSON.stringify(counts))
	_check(int(counts.detailed) <= 192, label + ": at most 96 detailed buildings per town")
	_check(int(counts.batches) <= 4, label + ": at most four shared overview batches")
	_check(int(counts.meshes) < 4000, label + ": the full model has bounded mesh nodes")
	_check(int(counts.bodies) < 900, label + ": only nearby plots and buildings have colliders")
	_check(
		int(counts.detailed) + int(counts.distant) == 2178,
		label + ": every model building remains represented near or far"
	)
	_check(int(counts.distant) == int(counts.roofs), label + ": distant houses keep their roofs")


func _capture(name: String) -> void:
	if capture_dir.is_empty():
		return
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_check(image != null and image.get_size() == Vector2i(1280, 720), name + ": actual viewport size")
	if image != null:
		_check(image.save_png(capture_dir.path_join(name + ".png")) == OK, name + ": PNG saved")


func _run() -> void:
	if "--capture" in OS.get_cmdline_user_args():
		capture_dir = OS.get_environment("LUMO_CAPTURE_DIR")
		if DisplayServer.get_name() == "headless" or capture_dir.is_empty():
			push_error("[VillageScaling] Capture requires an actual renderer and LUMO_CAPTURE_DIR")
			quit(1)
			return
		DirAccess.make_dir_recursive_absolute(capture_dir)
	root.size = Vector2i(1280, 720)
	var router := root.get_node("SceneRouter")
	router.launch_options = {
		"childKey": "village_scaling_collector_regression",
		"buildSlot": 6,
		"settlementMode": "settlement",
		"livingVillage": true
	}
	var city = load("res://scenes/creative/build_settlement_world.tscn").instantiate()
	root.add_child(city)
	await _frames()
	city.set_physics_process(false)
	var model = STATE.new("rival", true)
	for town: Dictionary in [model._player, model._rival]:
		town.region = 11
		town.plots = 1089
		town.population = 2180
		town.next_id = 1090
		town.buildings = []
		town.households = []
		for index in range(1089):
			var id := "b%d" % (index + 1)
			town.buildings.append({"id": id, "kind": "house", "plot": index})
			town.households.append(
				{"building_id": id, "adults": 2, "children": 0, "supplied_days": 20}
			)
	var saved: Dictionary = model.snapshot()
	var restored = STATE.restore(JSON.parse_string(JSON.stringify(saved)))
	_check(restored != null and restored.snapshot() == saved, "The 2178-house fixture is a valid save")
	city.model = model
	city.mode = "rival"
	city.radius = 94
	city.focus = Vector3(-REGION.TOWN_CENTER, 0, 0)
	city._rebuild()
	city._camera_update(true)
	await _frames()
	_assert_budget(city, "home")
	_check(city.facility_nodes.has("p_b5"), "The home center has its actual detailed collider")
	_check(not city.facility_nodes.has("r_b5"), "The distant neighbor center uses overview geometry")
	_check(city.model.snapshot() == saved, "Building presentation preserves all saved economy data")
	await _capture("01-home-region")

	city.focus = Vector3(REGION.TOWN_CENTER, 0, 0)
	city._camera_update(true)
	await _frames()
	_assert_budget(city, "neighbor")
	_check(city.facility_nodes.has("r_b5"), "Camera movement activates the neighbor's real center")
	_check(not city.facility_nodes.has("p_b5"), "Camera movement retires distant home detail")
	_check(city.model.snapshot() == saved, "Camera movement does not mutate the economy")

	city.focus = Vector3.ZERO
	city._camera_update(true)
	await _frames()
	_assert_budget(city, "river")
	await _capture("02-river-boundary")

	# The ordinary physics callback must follow the explorer, not the planning camera.
	city._toggle_walk()
	city.explorer.start_at(Vector3(-REGION.TOWN_CENTER, 0.08, 0))
	city._physics_process(0.0)
	await _frames()
	_check(city.facility_nodes.has("p_b5"), "Walking refreshes the actual home-center collider")
	city.explorer.start_at(Vector3(REGION.TOWN_CENTER, 0.08, 0))
	city._physics_process(0.0)
	await _frames()
	_assert_budget(city, "walking_neighbor")
	_check(city.facility_nodes.has("r_b5"), "Explorer movement activates the neighbor collider")
	_check(not city.facility_nodes.has("p_b5"), "Explorer movement retires distant home detail")
	_check(city.model.snapshot() == saved, "Exploring preserves the full simulation and save")
	city._toggle_walk()
	await _frames()
	_assert_budget(city, "planning_restored")
	_check(city.model.snapshot() == saved, "Returning to planning preserves both villages")
	city.queue_free()
	await _frames()
	if failures.is_empty():
		print("[VillageScaling] PASS ", checks, " checks: full 2178-house model, camera and explorer")
		quit(0)
	else:
		print("[VillageScaling] FAIL ", checks, " checks: ", failures)
		quit(1)
