extends SceneTree
## Bauwelt HUD and campaign-map capture (run under xvfb, gl_compatibility).
## Per quality tier: free build start view and living-village start view.
## When the campaign map exists, it is captured from the living village too.
## Output: BAUWELT_HUD_CAPTURE_DIR (PNG + metrics.json). llvmpipe numbers are
## not device performance; draw calls and objects are comparable across runs.

const CHILD := "hudcapture"


func _initialize() -> void:
	call_deferred("_run")


func _stats() -> Dictionary:
	return {
		"draw_calls":
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives":
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		"objects":
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
	}


func _save(dir: String, name: String) -> Dictionary:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(dir.path_join(name + ".png"))
	await process_frame
	await RenderingServer.frame_post_draw
	var stats: Dictionary = _stats()
	print("[BauweltHudCapture] %s %s" % [name, JSON.stringify(stats)])
	return stats


func _frames(count: int) -> void:
	for _frame in range(count):
		await process_frame


func _clear_saves() -> void:
	DirAccess.remove_absolute("user://lumo_build_%s_1.json" % CHILD)
	var village_path: String = load("res://scripts/creative/build_settlement_world.gd").project_path(
		CHILD, 1, "village"
	)
	DirAccess.remove_absolute(village_path)


func _run() -> void:
	var dir: String = OS.get_environment("BAUWELT_HUD_CAPTURE_DIR")
	if dir.is_empty():
		dir = ProjectSettings.globalize_path("user://bauwelt_hud_capture")
	DirAccess.make_dir_recursive_absolute(dir)
	var sizes: Array = [[Vector2i(1280, 720), "landscape"], [Vector2i(412, 915), "portrait"]]
	var only_landscape := "--landscape-only" in OS.get_cmdline_user_args()
	var performance: Node = root.get_node("PerformanceManager")
	var router: Node = root.get_node("SceneRouter")
	var metrics: Dictionary = {}
	await process_frame
	for tier in [0, 1, 2]:
		var tier_name: String = ["low", "medium", "high"][tier]
		var entry: Dictionary = {}
		for size_spec in sizes:
			if only_landscape and size_spec[1] != "landscape":
				continue
			if size_spec[1] != "landscape" and tier != 2:
				continue
			root.size = size_spec[0]
			var suffix := "%s_%s" % [tier_name, size_spec[1]]
			performance.call("set_profile", tier, false)
			_clear_saves()
			router.launch_options = {"childKey": CHILD}
			var build: Node = load("res://scenes/creative/build_world.tscn").instantiate()
			root.add_child(build)
			current_scene = build
			performance.call("set_profile", tier, false)
			await _frames(30)
			entry["build_" + size_spec[1]] = await _save(dir, "build_" + suffix)
			build.queue_free()
			await _frames(2)
			router.launch_options = {
				"childKey": CHILD, "settlementMode": "settlement", "livingVillage": true, "buildSlot": 1
			}
			var village: Node = load("res://scenes/creative/build_settlement_world.tscn").instantiate()
			root.add_child(village)
			current_scene = village
			performance.call("set_profile", tier, false)
			await _frames(30)
			entry["village_" + size_spec[1]] = await _save(dir, "village_" + suffix)
			if village.has_method("open_campaign_map"):
				village.open_campaign_map()
				await _frames(20)
				entry["map_" + size_spec[1]] = await _save(dir, "map_" + suffix)
			village.queue_free()
			await _frames(2)
			_clear_saves()
		metrics[tier_name] = entry
	var file := FileAccess.open(dir.path_join("metrics.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(metrics, "  "))
	file.close()
	print("[BauweltHudCapture] PASS %s" % dir)
	quit(0)
