extends SceneTree
const TABLE = "res://scenes/games/cards_table.tscn"
const FIXTURE = preload("res://scripts/tests/cards_table_regression.gd")

func _initialize() -> void:
	call_deferred("_run")

func _settle() -> void:
	for frame in range(5):
		await process_frame
	await RenderingServer.frame_post_draw

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Cards capture requires a real renderer")
		quit(2)
		return
	var out := OS.get_environment("LUMO_CAPTURE_DIR")
	if out.is_empty():
		out = "res://exports/cards-table"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			out = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(out)
	var table = load(TABLE).instantiate()
	root.add_child(table)
	var views: Array[Dictionary] = []
	for shape in [Vector2i(1280, 720), Vector2i(412, 915), Vector2i(690, 829), Vector2i(2400, 1080)]:
		root.size = shape
		root.get_node("HostBridge")._options = {"displayDensity": 2.625 if shape.x == 2400 else 1.0}
		await _settle()
		table._resize()
		table.apply_state(FIXTURE.fixture())
		await _settle()
		var image := root.get_texture().get_image()
		if image.is_empty() or image.get_width() != shape.x or image.get_height() != shape.y:
			quit(3)
			return
		var error := image.save_png("%s/cards-table-%dx%d.png" % [out, shape.x, shape.y])
		if error != OK:
			quit(4)
			return
		views.append({"width": shape.x, "height": shape.y, "density": table._ui_scale,
			"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
	var report := FileAccess.open(out.path_join("cards-render.json"), FileAccess.WRITE)
	if report == null:
		quit(5)
		return
	report.store_string(JSON.stringify({"renderer": DisplayServer.get_name(), "public_fixture": true,
		"android_device_measurement": false, "views": views}, "  "))
	report.close()
	print("CARDS_TABLE_RENDER_PASS renderer=%s images=4" % DisplayServer.get_name())
	table.queue_free()
	await process_frame
	quit(0)
