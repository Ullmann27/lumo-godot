extends SceneTree
## Headless regression for native Godot Autoload quality persistence.
## Not an FPS benchmark; deliberately checks durable user:// data instead.

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	await process_frame
	var store: Node = root.get_node_or_null("SettingsStore")
	var performance: Node = root.get_node_or_null("PerformanceManager")
	assert(store != null, "SettingsStore autoload missing")
	assert(performance != null, "PerformanceManager autoload missing")
	var original: String = str(store.call("get_profile"))
	var original_choice: String = str(store.call("get_graphics_choice"))
	assert(original in ["low", "medium", "high"])
	assert(scene_changed.is_connected(Callable(performance, "_on_scene_changed")),
		"Quality profile must reapply on new race scenes")
	for entry in [
		{"value": 0, "name": "low"},
		{"value": 2, "name": "high"},
		{"value": 1, "name": "medium"},
	]:
		performance.call("set_profile", entry.value, true)
		assert(str(store.call("get_profile")) == entry.name,
			"Autoload Quality preference was not updated")
		var cfg := ConfigFile.new()
		assert(cfg.load("user://settings.cfg") == OK, "Quality setting was not saved")
		assert(str(cfg.get_value("lumo", "profile", "")) == entry.name,
			"Quality preference on disk differs from active profile")
	LumoQuality.set_graphics_choice("ultra")
	assert(performance.call("is_ultra") and LumoQuality.graphics_choice() == "ultra")
	assert(LumoQuality.tier() == "high" and LumoQuality.budget() == LumoQuality.BUDGETS.high)
	var ultra_cfg := ConfigFile.new()
	assert(ultra_cfg.load("user://settings.cfg") == OK)
	assert(ultra_cfg.get_value("lumo", "profile") == "high")
	assert(ultra_cfg.get_value("lumo", "graphics_choice") == "ultra")
	performance.call("set_graphics_choice", "low", false)
	store.call("load_now")
	assert(store.call("get_graphics_choice") == "ultra", "Reload retains the selected graphics tier")
	performance.call("set_graphics_choice", store.call("get_graphics_choice"), false)
	assert(performance.call("is_ultra"), "Reapplying the saved option restores the scenery modifier")
	LumoQuality.set_graphics_choice("high")
	assert(not performance.call("is_ultra") and LumoQuality.graphics_choice() == "high")
	store.call("set_profile", "medium")
	store.call("load_now")
	assert(store.call("get_profile") == "medium" and store.call("get_graphics_choice") == "")
	performance.call("set_graphics_choice", original_choice if not original_choice.is_empty() else original, false)
	if original_choice.is_empty():
		store.call("set_profile", original)
	else:
		store.call("set_graphics_choice", original_choice)
	assert(str(store.call("get_profile")) == original)
	print("[KartQualityPersist] PASS: four choices, legacy base tiers, reload and scene signal")
	quit(0)
