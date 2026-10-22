extends SceneTree
## Every Kart landing choice must be fully readable without scrolling, above
## the persistent START / return bar, at real Android pixel sizes and densities.
## Android CI (pixel_5, 2400x1080 @ 420 dpi) showed the lower row (Sonnenhafen,
## Garage, Einstellungen) hidden under START: the landscape content was forced
## to the full screen height although the action bar takes its own row.
## Set LUMO_CAPTURE_DIR (with a display) to also save each layout as PNG.

const PROFILES := [
	["emulator_landscape", Vector2i(2400, 1080), 2.625],
	["phone_720p_landscape", Vector2i(1600, 720), 2.0],
	["fold_cover_landscape", Vector2i(2316, 904), 2.625],
	["fold_open", Vector2i(2176, 1812), 2.625],
]
# No portrait profile: kart_island.gd forces SCREEN_SENSOR_LANDSCAPE on Android.
const CHOICES := ["cup", "time_trial", "sonnenhafen", "garage", "settings"]


func _initialize() -> void:
	call_deferred("_run")


func _settle() -> void:
	for i in range(14):
		await process_frame
	# Layout needs no GPU; only a capture waits for a drawn frame.
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw


func _run() -> void:
	var capture_dir := OS.get_environment("LUMO_CAPTURE_DIR")
	var failures: Array[String] = []
	for profile in PROFILES:
		var label: String = profile[0]
		var pixels: Vector2i = profile[1]
		var density: float = profile[2]
		# The embedded Android host supplies the real density the same way.
		root.get_node("/root/HostBridge").set("_options", {"displayDensity": density})
		root.size = pixels
		var landing: Control = load("res://scripts/games/kart_reference_landing.gd").new()
		root.add_child(landing)
		await _settle()
		var bar: Control = landing.find_child("PersistentStartAndReturn", true, false)
		var scroll: ScrollContainer = landing.find_child("ReachableReferenceButtons", true, false)
		var start: Control = landing.find_child("LiveQuickStart", true, false)
		var visible_top := scroll.get_global_rect().position.y
		var visible_bottom := minf(scroll.get_global_rect().end.y, bar.get_global_rect().position.y)
		var dp := landing.get_viewport_rect().size.y / (float(pixels.y) / density)
		if start.get_global_rect().size.y < 48.0 * dp - 0.5:
			failures.append(
				"%s START only %.0f dp tall" % [label, start.get_global_rect().size.y / dp]
			)
		for id in CHOICES:
			var tile: Control = landing.find_child("Landing_" + id, true, false)
			var captions: Control = tile.find_child("AccessibleRealLabels", true, false)
			for caption in captions.get_children():
				var rect: Rect2 = (caption as Control).get_global_rect()
				if rect.position.y < visible_top - 0.5 or rect.end.y > visible_bottom + 0.5:
					failures.append(
						(
							"%s %s caption '%s' outside visible area %.0f..%.0f: %s"
							% [
								label,
								id,
								(caption as Label).text,
								visible_top,
								visible_bottom,
								rect
							]
						)
					)
			if tile.get_global_rect().size.y < 48.0 * dp - 0.5:
				failures.append("%s %s tile below 48 dp" % [label, id])
		if not capture_dir.is_empty() and DisplayServer.get_name() != "headless":
			DirAccess.make_dir_recursive_absolute(capture_dir)
			var image: Image = root.get_texture().get_image()
			image.save_png(capture_dir.path_join("kart-landing-%s.png" % label))
		print("[KartLandingFit] measured ", label, " ", pixels, " @", density)
		landing.queue_free()
		await process_frame
	root.get_node("/root/HostBridge").set("_options", {})
	if failures.is_empty():
		print(
			"[KartLandingFit] PASS: all five choices readable above START on ",
			PROFILES.size(),
			" Android sizes"
		)
		quit(0)
	else:
		for failure in failures:
			push_error("[KartLandingFit] " + failure)
		print("[KartLandingFit] FAIL: ", failures.size(), " problems")
		quit(1)
