extends SceneTree
## Builds every selectable kart and exercises real geometry, motion and garage views.

const VEHICLE = preload("res://scripts/games/kart_vehicle.gd")
const CATALOG = preload("res://scripts/games/kart_catalog.gd")
const FLEET = preload("res://scripts/games/kart_fleet.gd")
const GARAGE = "res://scripts/games/kart_garage_menu.gd"
const WORLD = preload("res://scripts/games/kart_world.gd")


func _initialize() -> void:
	call_deferred("_run")


func _geometry(node: Node3D, kart, result: Dictionary) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			if child == kart.far_mesh or kart.flames.has(child) or kart.sparks.has(child):
				continue
			result.surfaces += child.mesh.get_surface_count()
			for surface in range(child.mesh.get_surface_count()):
				var arrays: Array = child.mesh.surface_get_arrays(surface)
				result.vertices += arrays[Mesh.ARRAY_VERTEX].size()
		elif child is Node3D:
			_geometry(child, kart, result)


func _run() -> void:
	assert(CATALOG.KARTS.size() == 9)
	var seen: Dictionary = {}
	var signatures: Dictionary = {}
	for entry in CATALOG.KARTS:
		assert(not seen.has(entry.id), "Garage IDs must be unique")
		seen[entry.id] = true
		var kart = VEHICLE.new()
		kart.configure("fox", Color("76d9ff"), str(entry.id))
		root.add_child(kart)
		kart.set_process(false)
		assert(kart.kart_style == entry.id, "Selectable design must not fall back to Comet")
		assert(kart.wheel_pivots.size() == 4 and kart.wheel_rotors.size() == 4)
		assert(kart.head != null and kart.arm_right != null)
		var shape := {"surfaces": 0, "vertices": 0}
		_geometry(kart, kart, shape)
		assert(shape.vertices > 1000)
		assert(shape.surfaces <= 64, "Fleet must retain the mobile draw-surface budget")
		assert(kart.far_mesh.mesh.get_surface_count() == 1)
		assert(float(entry.speed) >= 0.9 and float(entry.speed) <= 1.11)
		assert(float(entry.turn) >= 0.9 and float(entry.turn) <= 1.14)
		kart.set_motion(12.0, 0.7, true, true)
		kart._process(0.016)
		assert(kart.flames[0].visible and kart.sparks[0].visible)
		if FLEET.IDS.has(str(entry.id)):
			var body: Node3D = kart.get_node("AuroraCoachwork")
			assert(body.get_meta("fleet_design") == entry.id)
			var info: Dictionary = FLEET.profile(str(entry.id))
			var signature: String = str(info)
			assert(not signatures.has(signature), "New designs need distinct physical profiles")
			signatures[signature] = true
		kart.free()
	var fallback = VEHICLE.new()
	fallback.configure("fox", Color.WHITE, "unknown_future_kart")
	assert(fallback.kart_style == "comet")
	fallback.free()
	var garage = load(GARAGE).new()
	garage.stars = 100
	garage.reduced_motion = true
	root.add_child(garage)
	garage.step = 2
	garage.setup.kart = "boru_rally"
	garage._refresh()
	await process_frame
	assert(garage._entries().size() == 9)
	for view in range(1, 6):
		garage._choose_preview_view(view)
		assert(garage.preview_camera.projection == Camera3D.PROJECTION_ORTHOGONAL)
		assert(garage.preview_pivot.rotation.y == 0.0)
	garage.step = 3
	garage._refresh()
	assert(garage.preview_camera.projection == Camera3D.PROJECTION_PERSPECTIVE)
	garage.step = 2
	garage._refresh()
	garage._choose_preview_view(0)
	assert(garage.preview_camera.projection == Camera3D.PROJECTION_PERSPECTIVE)
	garage.free()
	for track in ["sonnenhafen", "zauberwald", "holo_city"]:
		var world = WORLD.new()
		root.add_child(world)
		world.build(false, track, true)
		assert(world.get_meta("fleet_dressing_detail_count", 0) > 0)
		world.free()
	print("[KartFleet] PASS: 9 designs, animated chassis, LOD, budgets, garage views, scenery")
	quit()
