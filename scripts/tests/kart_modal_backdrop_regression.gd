extends SceneTree
## External layout/touch/pixel fixture, same script for immutableBASE and candidate.
## Normal scene physics enabled. Synthetic physical safeinsets explicitly declared.
## White calibration is diagnostic only; actualworld PNG always captured first.
var game
var output := ""
var checks: Array[Dictionary] = []
var cases: Array[Dictionary] = []
var inputs: Array[Dictionary] = []
var previous_touch_emulation := false

func _initialize() -> void:
	call_deferred("_run")

func _settle() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

func _rect(rectangle: Rect2) -> Array:
	return [rectangle.position.x, rectangle.position.y, rectangle.size.x, rectangle.size.y]

func _physical(rectangle: Rect2) -> Rect2:
	var factor := Vector2(root.size) / root.get_visible_rect().size
	return Rect2(rectangle.position * factor, rectangle.size * factor)

func _touch(point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 4
	event.position = point
	event.pressed = pressed
	inputs.append({"point": [point.x, point.y], "pressed": pressed})
	Input.parse_input_event(event)
	await process_frame

func _tap(control: Control) -> void:
	assert(control.is_visible_in_tree())
	assert(root.get_visible_rect().encloses(control.get_global_rect()))
	var point := _physical(control.get_global_rect()).get_center()
	await _touch(point, true)
	await _touch(point, false)
	await _settle()

func _button(prefix: String) -> Button:
	for child in game.modal_column.get_children():
		if child is Button and child.text.begins_with(prefix):
			return child
	assert(false, "Actual public button missing: " + prefix)
	return null

func _state() -> Dictionary:
	return {"paused": game.paused, "elapsed": game.elapsed, "distance": game.distance,
		"gate": game.checkpoint_index, "result_id": game.result_id,
		"steering": game.steering, "gas_held": game.gas_held, "brake": game.brake,
		"drifting": game.drifting, "music": game.music_volume, "effects":game.effects_volume,
		"muted": game.muted, "auto_gas": game.auto_gas, "reduced_motion": game.reduced_motion,
		"resets": game.reset_count, "physics_enabled":game.is_physics_processing()}

func _check(condition: bool, label: String, actual: Variant, name: String) -> void:
	checks.append({"case": name, "label": label, "passed": condition, "actual": actual})

func _run() -> void:
	output = OS.get_environment("LUMO_QA_DIR")
	assert(not output.is_empty() and DisplayServer.get_name().to_lower() == "x11")
	previous_touch_emulation = Input.emulate_touch_from_mouse
	Input.emulate_touch_from_mouse = true
	assert(DisplayServer.is_touchscreen_available() and Input.emulate_mouse_from_touch)
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	await _settle()
	for step in range(5):
		assert(game.garage.step == step)
		await _tap(game.garage.next_button)
	assert(not game.menu_active and game.is_physics_processing())
	await _tap(game.top_pause_button)
	assert(game.paused)
	var scenarios := [
		["cover", Vector2i(2316,904), Rect2(24,32,48,40), false],
		["inner", Vector2i(2176,1812), Rect2(16,32,126,126), false],
		["cover_restored", Vector2i(2316,904), Rect2(40,24,24,48), false],
		["phone_restored", Vector2i(1920,1080), Rect2(16,32,32,24), false],
		["phone_reduced", Vector2i(1920,1080), Rect2(16,32,32,24), true],
	]
	for scenario in scenarios:
		var name: String = scenario[0]
		var physical_size: Vector2i = scenario[1]
		var physical_insets: Rect2 = scenario[2]
		var motion: bool = scenario[3]
		root.size = physical_size
		await _settle()
		game._apply_safe_area(physical_insets, Vector2(physical_size))
		await _settle()
		game._apply_responsive_layout()
		await _settle()
		if game.reduced_motion != motion:
			await _tap(_button("Ruhige Bewegung:"))
			await _settle()
		var viewport := root.get_visible_rect()
		var backdrop := game.modal_backdrop.get_global_rect() as Rect2
		var safe := game.safe_ui.get_global_rect() as Rect2
		var dialog := game.modal.get_global_rect() as Rect2
		var footer := game.pause_navigation.get_global_rect() as Rect2
		var physical_backdrop := _physical(backdrop)
		var expected_safe := Rect2(physical_insets.position,
			Vector2(physical_size)-physical_insets.position-physical_insets.size)
		var discrepancy := maxf(maxf(absf(physical_backdrop.position.x),
			absf(physical_backdrop.position.y)),maxf(absf(physical_backdrop.end.x-physical_size.x),
			absf(physical_backdrop.end.y-physical_size.y)))
		_check(discrepancy <= 0.5, "backdrop full physical viewport <=0.5px",
			{"physical_backdrop":_rect(physical_backdrop),"error_px":discrepancy},name)
		_check(_physical(safe).position.distance_to(expected_safe.position) <= 0.5
			and _physical(safe).size.distance_to(expected_safe.size) <= 0.5,
			"safe UI retains exactly scaled physical insets",_rect(_physical(safe)),name)
		_check(safe.encloses(dialog) and safe.encloses(footer),
			"dialog/footer remain within unchanged safe UI",[_rect(dialog),_rect(footer)],name)
		_check(game.modal_backdrop.get_parent() == game.safe_ui
			and game.modal_backdrop.get_index() < game.modal.get_index()
			and game.modal_backdrop.mouse_filter == Control.MOUSE_FILTER_STOP
			and game.modal_backdrop.color == Color(0.015,0.045,0.09,0.46)
			and game.modal_backdrop.visible and game.modal.visible,
			"original backdrop routing/color/order/visibility retained",
			{"parent":str(game.modal_backdrop.get_parent().name),
			"filter":game.modal_backdrop.mouse_filter,"color":str(game.modal_backdrop.color)},name)
		_check(game.reduced_motion == motion and game.paused and game.is_physics_processing(),
			"public reduced-motion state and normal paused physics retained",_state(),name)
		assert(root.get_texture().get_image().save_png(output.path_join(name+"-actual-pause.png")) == OK)
		# Fixture-only static white source makes alpha coverage measurable independently
		# of world shaders/animation. It is inserted below SafeUI, never shown as gameplay.
		var white := ColorRect.new()
		white.color = Color.WHITE
		white.mouse_filter = Control.MOUSE_FILTER_IGNORE
		game.safe_ui.get_parent().add_child(white)
		game.safe_ui.get_parent().move_child(white,0)
		white.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		await _settle()
		var image := root.get_texture().get_image()
		assert(image.get_size() == physical_size)
		assert(image.save_png(output.path_join(name+"-DIAGNOSTIC-white-mask.png")) == OK)
		var pixel_points := [Vector2i(8,8),Vector2i(physical_size.x-9,8),
			Vector2i(8,physical_size.y-9),Vector2i(physical_size.x-9,physical_size.y-9),
			Vector2i(8,physical_size.y/2),Vector2i(physical_size.x-9,physical_size.y/2),
			Vector2i(physical_size.x/2,8),Vector2i(physical_size.x/2,physical_size.y-9)]
		var pixel_rows: Array[Dictionary] = []
		var pixels_dimmed := true
		for point in pixel_points:
			var pixel: Color = image.get_pixelv(point)
			var max_channel: float = maxf(pixel.r,maxf(pixel.g,pixel.b)) * 255.0
			pixel_rows.append({"point":[point.x,point.y],"rgb":[pixel.r*255,pixel.g*255,pixel.b*255]})
			pixels_dimmed = pixels_dimmed and max_channel <= 225.0
		_check(pixels_dimmed,"all eight viewport edge/corner calibration pixels dim >=30/255",
			pixel_rows,name)
		white.queue_free()
		await _settle()
		var before := _state()
		for point in [Vector2(8,physical_size.y*0.5),Vector2(physical_size.x-9,physical_size.y*0.5),
			Vector2(physical_size.x*0.5,8),Vector2(physical_size.x*0.5,physical_size.y-9)]:
			await _touch(point,true)
			await _touch(point,false)
		await _settle()
		_check(before == _state(),"real touches outside safe area cannot alter paused race/settings",
			{"before":before,"after":_state()},name)
		var resume := _button("Weiterfahren")
		var presses := [0]
		resume.pressed.connect(func(): presses[0] += 1)
		await _tap(resume)
		_check(presses[0] == 1 and not game.paused and not game.modal.visible
			and not game.modal_backdrop.visible,"real continue resumes once and hides backdrop",
			{"press_count":presses[0],"paused":game.paused,"backdrop":game.modal_backdrop.visible},name)
		cases.append({"name":name,"physical_size":[physical_size.x,physical_size.y],
			"physical_insets":_rect(physical_insets),"logical_viewport":_rect(viewport),
			"backdrop_logical":_rect(backdrop),"backdrop_physical":_rect(physical_backdrop),
			"safe_logical":_rect(safe),"dialog_logical":_rect(dialog),"footer_logical":_rect(footer),
			"pixels":pixel_rows,"reduced_motion":motion})
		await _tap(game.top_pause_button)
		assert(game.paused)
	var passed := 0
	for row in checks:
		if row.passed:
			passed += 1
	assert(checks.size() == 40)
	var report := {"checks":checks,"cases":cases,"inputs":inputs,"pass_count":passed,
		"check_count":40,"scope":"Actual Linux softwareGL world pause PNGs plus separately labelled white calibration; synthetic scaledsafeinsets; realScreenTouch; no manualphysics/productrace-state assignments",
		"android_new_apk_performance_physical_fold":"NOT EXECUTED","engine":Engine.get_version_info()}
	FileAccess.open(output.path_join("modal-backdrop-evidence.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	game.queue_free()
	game = null
	await _settle()
	Input.emulate_touch_from_mouse = previous_touch_emulation
	root.world_3d.fallback_environment = null
	await create_timer(0.6).timeout
	print("[LumoBackdrop] OBSERVATIONS_CLOSED: %d/40" % passed)
	if passed == 40:
		print("[LumoBackdrop] PASS:40 viewport/safe/dialog/color/routing/pixel/touch/reduced-motion checks")
	quit(0 if passed == 40 else 1)
