extends SceneTree
## Proves native menu buttons, underlying mode wiring and real Godot renders.
## No mock UI or static screenshot in this capture.
func _initialize() -> void:
	call_deferred("_run")


func _settle() -> void:
	for i in range(12):
		await process_frame
	await RenderingServer.frame_post_draw


func _run() -> void:
	var landing_script = load("res://scripts/games/kart_reference_landing.gd")
	var landing: Control = landing_script.new()
	landing.total_stars = 16
	root.add_child(landing)
	await _settle()
	var buttons: Array[String] = ["cup", "time_trial", "sonnenhafen", "garage", "settings"]
	for id in buttons:
		var control: Button = landing.find_child("Landing_" + id, true, false)
		assert(control != null, "Missing real reference landing control: " + id)
		assert(control.focus_mode == Control.FOCUS_ALL, "Keyboard focus must be supported")
		assert(control.custom_minimum_size.y >= 48.0, "Touch target too small")
	var start: Button = landing.find_child("LiveQuickStart", true, false)
	assert(start != null and start.custom_minimum_size.y >= 48.0)
	var received: Array[String] = []
	landing.mode_selected.connect(func(mode_id: String): received.append(mode_id))
	landing.find_child("Landing_time_trial", true, false).pressed.emit()
	assert(received == ["time_trial"], "Native button did not select the real time-trial mode")
	if DisplayServer.get_name() != "headless":
		var destination := "res://exports/nextgen-ui/"
		DirAccess.make_dir_recursive_absolute(destination)
		for dimensions in [Vector2i(1280, 720), Vector2i(690, 829)]:
			root.size = dimensions
			await _settle()
			var image: Image = root.get_texture().get_image()
			assert(image.save_png(destination + "referenz-landing-%dx%d.png" % [dimensions.x, dimensions.y]) == OK)
			print("[ReferenceLanding] CAPTURE ", dimensions)
	landing.queue_free()
	print("[ReferenceLanding] PASS: native real menu controls, live selected mode, phone and landscape")
	quit(0)
