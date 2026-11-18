extends SceneTree
## Bildfolge „erster Dorfbesuch bis zur ersten sichtbaren Ernte“ über den
## App-Einstieg (HostBridge-Optionen), mit ECHTEN Tipps an die Stellen, auf
## die Lumos Pfeil zeigt. xvfb + gl_compatibility (wie das Handy).
## Aufruf: ... --script res://scripts/tests/dorf_first_visit_capture.gd -- <breite> <höhe> <dichte>
## Ausgabe: DORF_CAPTURE_DIR/<breite>x<höhe>/NN_name.png
const CHILD := "dorf_first_visit_capture"
const SLOT := 2
var out := ""
var index := 0


func _initialize() -> void:
	call_deferred("_run")


func _frames(count: int) -> void:
	for _i in range(count):
		await process_frame


func _shot(name: String) -> void:
	await _frames(3)
	await RenderingServer.frame_post_draw
	index += 1
	var path := out.path_join("%02d_%s.png" % [index, name])
	root.get_viewport().get_texture().get_image().save_png(path)
	print("[FirstVisitCapture] ", path)


func _touch(point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 1
	event.position = point
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame


func _tap_local(village: Node, local: Vector2) -> void:
	var point: Vector2 = root.get_final_transform() * (village.safe_ui.get_global_transform_with_canvas() * local)
	await _touch(point, true)
	await _touch(point, false)
	await _frames(6)


func _tap_pointer(village: Node) -> void:
	await _tap_local(village, village.tutorial.target_rect().get_center())


func _tap_bubble(village: Node, caption: String) -> void:
	for child in village.tutorial.bubble_buttons.get_children():
		if child is Button and child.text == caption:
			await _tap_local(village, village._hud_rect(child).get_center())
			return
	push_warning("[FirstVisitCapture] Knopf fehlt: " + caption)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var size := Vector2i(1812, 2176)
	var density := 2.625
	if args.size() >= 2:
		size = Vector2i(int(args[0]), int(args[1]))
	if args.size() >= 3:
		density = float(args[2])
	out = OS.get_environment("DORF_CAPTURE_DIR")
	if out.is_empty():
		out = ProjectSettings.globalize_path("user://dorf_first_visit")
	out = out.path_join("%dx%d" % [size.x, size.y])
	DirAccess.make_dir_recursive_absolute(out)
	root.size = size
	Input.emulate_touch_from_mouse = true
	root.get_node("PerformanceManager").call("set_profile", 2, false)
	var world: GDScript = load("res://scripts/creative/build_settlement_world.gd")
	DirAccess.remove_absolute(world.project_path(CHILD, SLOT, "village"))
	var launch := {"game": "settlement", "scene": "settlement", "livingVillage": true, "settlementMode": "settlement",
		"childKey": CHILD, "buildSlot": SLOT, "displayDensity": density}
	root.get_node("HostBridge").set("_options", launch.duplicate(true))
	root.get_node("SceneRouter").launch_options = launch.duplicate(true)
	var village: Node = load("res://scenes/creative/build_settlement_world.tscn").instantiate()
	root.add_child(village)
	current_scene = village
	await _frames(12)
	var guide: Node = village.tutorial.guide
	await _shot("luftblick_tal")
	while guide.flying and guide.flight_time < 2.6:
		await process_frame
	await _shot("luftblick_anflug")
	while guide.flying:
		await process_frame
	await _frames(30)
	await _shot("lumo_am_bauplatz")
	await _tap_bubble(village, "Ja, los!")
	await _shot("bauplatz_zeigen")
	await _tap_pointer(village)
	await _shot("wohnhaus_waehlen")
	await _tap_pointer(village)
	await _frames(40)
	await _shot("haus_gebaut_versorgen")
	await _tap_pointer(village)
	await _shot("bauernhof_waehlen")
	await _tap_pointer(village)
	await _frames(40)
	await _shot("hof_gebaut_naechster_tag")
	await _tap_pointer(village)
	await _frames(20)
	await _shot("ernte_hof_zum_vorrat")
	await _frames(45)
	await _shot("ernte_hof_zum_vorrat_2")
	await _tap_bubble(village, "Verstanden")
	await _frames(30)
	await _shot("vorrat_zur_familie")
	await _tap_bubble(village, "Verstanden")
	await _shot("ziel")
	await _tap_bubble(village, "Verstanden")
	await _frames(20)
	await _shot("freies_spiel_vier_bereiche")
	print("[FirstVisitCapture] PASS images=", index, " step=", village.tutorial.current_id(), " done=", village.tutorial.done)
	village.queue_free()
	await _frames(6)
	DirAccess.remove_absolute(world.project_path(CHILD, SLOT, "village"))
	quit(0)
