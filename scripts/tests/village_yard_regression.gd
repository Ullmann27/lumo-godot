extends "res://scripts/tests/build_village_tutorial_regression.gd"
## Tap an off-centre site and draw an enclosure through the shipped touch UI.
const YARDS = preload("res://scripts/creative/build_village_yards.gd")
const OWNER := "village_yard_touch_regression"


func _shot(file_name: String) -> void:
	var folder := OS.get_environment("DORF_CAPTURE_DIR")
	if folder.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(folder)
	root.get_texture().get_image().save_png(folder.path_join(file_name + ".png"))


func _screen_point(v: Node, at: Vector3) -> Vector2:
	return root.get_final_transform() * v.camera.unproject_position(at)


func _run() -> void:
	root.size = Vector2i(900, 1000)
	world_script = load("res://scripts/creative/build_settlement_world.gd")
	root.get_node("PerformanceManager").call("set_profile", 0, false)
	DirAccess.remove_absolute(_save_path(OWNER))
	var v: Node = await _open(OWNER)
	v.tutorial.skip()
	v.select_dock_section("bauen")
	v.focus = v._plot_world(4)
	v.radius = 28
	v.tilt = .88
	v.orbit = 0
	v._camera_update(true)
	await _frames(5)
	var desired: Vector3 = v._plot_world(4) + Vector3(-.69, .13, -.72)
	var point := _screen_point(v, desired)
	await _touch(point, true)
	await _touch(point, false)
	await _frames(4)
	_check(v.selected_plot == 4 and v.site_offset.length() > 45, "Touched continuous site")
	await _tap_control(v, v.purchase_buttons.house)
	_check(v.model.player().buildings.size() == 1, "One house bought")
	if v.model.player().buildings.size() != 1:
		quit(1)
		return
	var house: Dictionary = v.model.player().buildings[0]
	var home := YARDS.building_at(house)
	_check(home.distance_to(desired) < .5, "Visible house placed at tap")
	var facility: StaticBody3D = v.facility_nodes["p_" + str(house.id)]
	_check(facility.position.distance_to(home) < .1, "Collider follows house")
	await _tap_control(v, v.yard_button)
	_check(v.yard_mode, "Toolbar enters fence drawing")
	var a := _screen_point(v, v._plot_world(0) + Vector3.UP * .17)
	var b := _screen_point(v, v._plot_world(8) + Vector3.UP * .17)
	await _drag(a, b)
	var yards: Array = v.model._player.get("yards", [])
	_check(yards.size() == 1 and not v.yard_mode, "Real drag creates one garden")
	if yards.is_empty():
		print("[VillageYard] FAILED ", failures, " ", v.feedback.text, " screen=", [a,b])
		quit(1)
		return
	var yard: Dictionary = yards[0]
	_check(YARDS.FIELDS.rect(yard.a, yard.b).size == Vector2i(3,3), "Three by three yard")
	var gate := YARDS.gate(yard)
	var explorer: CharacterBody3D = v.explorer
	v._toggle_walk()
	await physics_frame
	var above := YARDS.TERRAIN.height(gate.x,gate.y) + .21
	var through := Transform3D(Basis.IDENTITY,Vector3(gate.x,above,gate.y+1.1))
	var rail := through
	rail.origin.x += 2.0
	_check(not explorer.test_move(through, Vector3.FORWARD*2.0), "Walker's real capsule fits through the gate")
	_check(explorer.test_move(rail,Vector3.FORWARD*2.0), "Fence beside the opening blocks the same walker")
	v._toggle_walk()
	var crossing := false
	for actor in v.village_residents._actors:
		if actor.axis == Vector3.BACK:
			crossing = true
			break
	_check(crossing, "Resident path crosses at gate")
	_check(v.model.undo() and v.model._player.get("yards", []).is_empty(), "Undo removes yard")
	_check(v.model.redo() and v.model._player.yards.size() == 1, "Redo restores yard")
	v._rebuild()
	v._save()
	if not v.tutorial.context_topic.is_empty():
		v.tutorial._close_context()
	v.radius = 38
	v.focus = v._plot_world(4) + Vector3(0,0,1.4)
	v._camera_update(true)
	Engine.time_scale = 4.0
	await _frames(25)
	Engine.time_scale = 1.0
	await _shot("dorf-garten")
	var saved_house := house.duplicate()
	await _close(v)
	v = await _open(OWNER)
	_check(not v.save_blocked and v.model._player.yards == yards, "Yard survives reload")
	_check(v.model._player.buildings[0] == saved_house, "Exact house site survives reload")
	var roster: Array = v.village_residents._actors
	for actor in roster:
		var holder: Node3D = actor.holder
		if holder.get_meta("village_role") == "Ari · Löwe":
			v.set_physics_process(false)
			v.safe_ui.hide()
			var at := holder.global_position + Vector3.UP * .85
			var relative := holder.global_basis * Vector3(2.8, .92, 3.25)
			v.camera.position = at + relative
			v.camera.look_at(at)
			await _frames(3)
			await _shot("dorf-loewe")
			break
	await _close(v)
	DirAccess.remove_absolute(_save_path(OWNER))
	print("[VillageYard] checks=", checks, " failures=", failures)
	quit(0 if failures.is_empty() else 1)
