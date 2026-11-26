extends SceneTree
## Reproduces the device defects with actual mesh arrays, heightmap collision,
## physics queries and the production World/kart transition.
const TERRAIN = preload("res://scripts/creative/build_village_terrain.gd")
const LANDSCAPE = preload("res://scripts/creative/build_village_landscape.gd")
const REGION = preload("res://scripts/creative/build_settlement_region.gd")
const VILLAGE = preload("res://scripts/creative/lumo_world_village.gd")
const WORLD_STATE = preload("res://scripts/creative/lumo_world_state.gd")
const PROFILE := "lumo_world_device_regression_2078"
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error("[LumoWorldDevice] " + label)


func _run() -> void:
	var original_bytes := FileAccess.get_sha256(TERRAIN.DATA_PATH)
	await _terrain_projection()
	await _vehicle_transition()
	_check(FileAccess.get_sha256(TERRAIN.DATA_PATH) == original_bytes, "original terrain resource remains byte-identical")
	print("[LumoWorldDevice] %s %d checks" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)


func _terrain_projection() -> void:
	_check(TERRAIN.ensure(), "exact production terrain data loads")
	var grid := TERRAIN.grid_size()
	var step := TERRAIN.step()
	var original := LANDSCAPE.new()
	var original_collision := original.collision_shape()
	var original_map := original_collision.shape as HeightMapShape3D
	_check(original.first_grid_column() == 0, "standalone village retains every terrain column")
	_check(original_map.map_width == grid.x and original_map.map_depth == grid.y, "standalone collision dimensions are unchanged")
	var default_unchanged := true
	for z in range(grid.y):
		for x in range(grid.x):
			if absf(original_map.map_data[z * grid.x + x] * step - TERRAIN.grid_height(x, z)) > 0.00002:
				default_unchanged = false
	_check(default_unchanged, "all standalone heightmap collision samples retain their original heights")
	original_collision.free()
	original.free()
	var projected := LANDSCAPE.new()
	projected.west_entry_x = VILLAGE.WEST_ENTRY_X
	projected.west_entry_blend_width = VILLAGE.WEST_ENTRY_BLEND_WIDTH
	root.add_child(projected)
	projected._build_terrain()
	var first := projected.first_grid_column()
	_check(first == 48, "World crops the actual -440m heightmap to its -320m joining edge")
	var minimum_x := INF
	var wrong_heights := 0
	var invalid_normals := 0
	var vertices_checked := 0
	for chunk in projected.chunks:
		var arrays: Array = chunk.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for index in range(vertices.size()):
			var vertex := vertices[index]
			minimum_x = minf(minimum_x, vertex.x)
			vertices_checked += 1
			if absf(vertex.y - _expected_grid_height(vertex.x, vertex.z)) > 0.0001:
				wrong_heights += 1
			if not normals[index].is_finite() or absf(normals[index].length() - 1.0) > 0.001:
				invalid_normals += 1
	_check(vertices_checked > 70000, "actual projected render meshes were examined")
	_check(is_equal_approx(minimum_x + VILLAGE.ORIGIN.x, 280.0), "no projected terrain vertex reaches the existing town road")
	_check(wrong_heights == 0, "every rendered terrain vertex uses the projected surface height")
	_check(invalid_normals == 0, "cropped and blended terrain retains finite unit normals")
	var collision := projected.collision_shape()
	var heightmap := collision.shape as HeightMapShape3D
	_check(heightmap.map_width == grid.x - first and heightmap.map_depth == grid.y, "render and collision use the same cropped footprint")
	var collision_matches := true
	var edge_flat := true
	for z in range(grid.y):
		for x in range(heightmap.map_width):
			var sample := heightmap.map_data[z * heightmap.map_width + x] * step
			var at := TERRAIN.origin() + Vector2(x + first, z) * step
			if absf(sample - _expected_grid_height(at.x, at.y)) > 0.0001:
				collision_matches = false
			if x == 0 and not is_zero_approx(sample):
				edge_flat = false
	_check(collision_matches, "every projected collision sample matches the rendered surface")
	_check(edge_flat, "the entire joining edge meets zero-height mainland without a cliff")
	var plots_unchanged := true
	for plot in range(REGION.MAX_PLOTS):
		var at := REGION.plot_position(plot)
		if absf(projected.surface_height(at.x, at.z) - TERRAIN.height(at.x, at.z)) > 0.000001:
			plots_unchanged = false
	_check(plots_unchanged, "all 4225 saved player plot heights remain unchanged")
	var body := StaticBody3D.new()
	body.position = VILLAGE.ORIGIN
	body.add_child(collision)
	root.add_child(body)
	await _settle()
	var space := body.get_world_3d().direct_space_state
	for x in [160.0, 170.0, 218.0, 260.0, 276.0]:
		var query := PhysicsRayQueryParameters3D.create(Vector3(x, 110, 6), Vector3(x, -10, 6))
		_check(space.intersect_ray(query).is_empty(), "village mountain collision no longer overlaps town x=%s" % x)
	for x in [282.5, 287.5, 300.0, 350.0, 500.0]:
		var query := PhysicsRayQueryParameters3D.create(Vector3(x, 110, 5), Vector3(x, -10, 5))
		var hit := space.intersect_ray(query)
		_check(not hit.is_empty(), "projected village has real floor collision at x=%s" % x)
		if not hit.is_empty():
			_check(absf(float(hit.position.y) - projected.surface_height(x - VILLAGE.ORIGIN.x, 5.0)) < 0.02, "physics floor matches mesh at x=%s" % x)
	body.queue_free()
	projected.queue_free()
	await _settle()


func _expected_grid_height(x: float, z: float) -> float:
	# Grid vertices include the last row/column. TERRAIN.height deliberately
	# clamps an interpolated lookup just inside those edges, so compare the
	# real mesh/collider grid against raw authored samples at their vertices.
	var index := Vector2i((Vector2(x, z) - TERRAIN.origin()) / TERRAIN.step())
	var factor := clampf((x - VILLAGE.WEST_ENTRY_X) / VILLAGE.WEST_ENTRY_BLEND_WIDTH, 0.0, 1.0)
	var eased := factor * factor * (3.0 - 2.0 * factor)
	return TERRAIN.grid_height(index.x, index.y) * eased


func _vehicle_transition() -> void:
	var world_path := "user://lumo_world_" + PROFILE.sha256_text().substr(0, 32) + ".json"
	var village_path: String = VILLAGE.save_path_for(PROFILE, 1)
	DirAccess.remove_absolute(world_path)
	DirAccess.remove_absolute(village_path)
	root.size = Vector2i(884, 920)
	root.get_node("SceneRouter").launch_options = {"childKey": PROFILE, "grade": 2, "reduceAnimations": true}
	var scene = load("res://scenes/creative/lumo_world.tscn").instantiate()
	root.add_child(scene)
	scene.set_physics_process(false)
	await _settle()
	var western_scenery := 0
	var checked_scenery := 0
	for holder in scene.own_village.region.get_children():
		if not str(holder.name).begins_with("Wild_"):
			continue
		for node in holder.get_children():
			if not node is MultiMeshInstance3D:
				continue
			for placement in node.multimesh.get_meta("authored_transforms", []):
				checked_scenery += 1
				if placement.origin.x < VILLAGE.WEST_ENTRY_X:
					western_scenery += 1
	_check(checked_scenery > 0 and western_scenery == 0, "actual wilderness has no floating trees or rocks over the cropped town area")
	scene.player.position = Vector3(75, 0.1, 18)
	scene.kart_body.position = Vector3(77, 0.2, 18)
	scene.kart_body.rotation.y = 0.65
	await _settle()
	scene._toggle_vehicle()
	_check(scene.driving, "production entry transitions into the kart")
	_check(await _land_kart(scene), "production physics establishes solid ground before testing exit")
	scene.player.velocity = Vector3(4, -8, 2)
	scene.airborne_time = 1.3
	scene.last_safe = Vector3(0, 0.1, 6)
	scene.camera_yaw = -1.7
	scene.camera_contacts[31] = Vector2(120, 200)
	scene.gesture_index = 31
	scene.drive_speed = 0.0
	scene._toggle_vehicle()
	_check(not scene.driving and scene.fox.visible, "production exit restores the walking avatar on free ground")
	_check(scene.player.velocity == Vector3.ZERO and is_zero_approx(scene.airborne_time), "exit clears stale velocity and falling timer")
	_check(scene.last_safe.is_equal_approx(scene.player.position), "exit establishes the actual new safe walking position")
	_check(is_equal_approx(scene.camera_yaw, scene.kart_body.rotation.y), "exit keeps the driving camera heading")
	_check(scene.camera_contacts.is_empty() and scene.gesture_index == -1, "mode switch clears stale camera touches")
	await _settle()
	_check(not scene.player_shape.disabled, "walking collision is restored after the physics-safe deferred update")
	_check(scene.player.position.y > 0.0 and scene.player.position.y < 0.3, "exit feet lie just above the real mainland floor")
	scene._toggle_vehicle()
	_check(scene.driving, "the same parked kart can be entered again")
	var obstacle := StaticBody3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(9, 3, 9)
	var obstacle_shape := CollisionShape3D.new()
	obstacle_shape.shape = box
	obstacle.add_child(obstacle_shape)
	obstacle.position = scene.kart_body.position + Vector3.UP * 1.5
	scene.add_child(obstacle)
	await _settle()
	_check(scene._safe_vehicle_exit() == null, "blocked exit positions are rejected by real capsule overlap queries")
	scene._toggle_vehicle()
	_check(scene.driving and not scene.fox.visible, "blocked exit leaves the child safely seated")
	obstacle.queue_free()
	await _settle()
	var parked: Vector3 = scene.kart_body.position
	scene.kart_body.position = Vector3(2000, 0.2, 0)
	await _settle()
	_check(scene._safe_vehicle_exit() == null, "no-floor exit is rejected by real ground queries")
	scene.kart_body.position = parked
	_check(await _land_kart(scene), "the kart has real floor contact after being restored")
	scene._toggle_vehicle()
	_check(not scene.driving, "removing the obstruction restores a normal exit")
	_check(not FileAccess.file_exists(village_path), "walking and kart transitions do not create or overwrite a village economy save")
	# Follow the actual save/re-entry path, without relocating the kart after load.
	var parked_in_city := Vector3(218, 0.2, 8)
	var parked_heading := -1.1
	scene.kart_body.position = parked_in_city
	scene.kart_body.rotation.y = parked_heading
	scene.kart_body.velocity = Vector3.ZERO
	for index in range(30):
		await physics_frame
		scene._drive_tick(Vector2.ZERO, 1.0 / 60.0)
	_check(scene.kart_body.is_on_floor(), "city parking pose has real post-movement ground contact")
	parked_in_city = scene.kart_body.position
	scene.player.position = Vector3(parked_in_city.x + 2, 0.2, parked_in_city.z)
	scene.last_safe = scene.player.position
	_check(scene._save(), "parking away from the original village writes the actual World save")
	scene.queue_free()
	await _settle()
	scene = load("res://scenes/creative/lumo_world.tscn").instantiate()
	root.add_child(scene)
	scene.set_physics_process(false)
	await _settle()
	_check(scene.kart_body.position.is_equal_approx(parked_in_city), "re-entry restores the kart at its saved parking place, not the original spawn")
	_check(is_equal_approx(scene.kart_body.rotation.y, parked_heading), "re-entry restores the saved kart heading")
	_check(scene.player.position.distance_to(scene.kart_body.position) < 5.0, "the restored player can reach the parked kart immediately")
	_check(scene.kart_visual.is_visible_in_tree(), "the restored kart visual is attached and visible")
	_check(scene.residents.size() == 3, "all three local story residents are loaded on re-entry")
	scene._map_dialog()
	_check(scene.overview.kart_at.is_equal_approx(parked_in_city), "the production map receives the current parked kart, not the racing portal")
	scene.overview.focus_kart()
	_check(scene.overview.view_bounds.has_point(Vector2(parked_in_city.x, parked_in_city.z)), "the kart map action reveals its saved parking place")
	scene._close_dialog()
	scene._toggle_vehicle()
	_check(scene.driving, "the child can enter the restored kart through the normal production action")
	# Pause immediately after leaving an edge: the height is still plausible,
	# but the actual motion has lost its floor contact.
	scene.kart_body.position = Vector3(0, 0.2, 70)
	scene.kart_body.velocity = Vector3.ZERO
	await physics_frame
	scene._drive_tick(Vector2.ZERO, 1.0 / 60.0)
	_check(not scene.kart_body.is_on_floor() and scene.kart_body.position.y > -0.5, "the early-fall fixture is airborne while its numeric height is still in range")
	_check(scene._save(), "pausing during an early fall still saves the world")
	var falling_save: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(world_path))
	var resumed = WORLD_STATE.new()
	_check(resumed.restore(falling_save), "the early-fall save restores normally")
	_check(resumed.kart_position.is_equal_approx(parked_in_city), "falling cannot replace the last grounded kart pose")
	_check(resumed.position.is_equal_approx(scene.last_safe), "falling resumes the child at the last safe walking point")
	scene.queue_free()
	await _settle()
	DirAccess.remove_absolute(world_path)
	DirAccess.remove_absolute(village_path)


## The fixture pauses automatic physics to isolate the transitions. Advance
## the real drive controller explicitly before expecting a grounded exit.
func _land_kart(scene: Node) -> bool:
	for index in range(30):
		await physics_frame
		scene._drive_tick(Vector2.ZERO, 1.0 / 60.0)
		if scene.kart_body.is_on_floor():
			return true
	return false


func _settle() -> void:
	for index in range(3):
		await physics_frame
		await process_frame
