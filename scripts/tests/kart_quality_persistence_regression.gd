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
	var restore: int = 1
	if original == "low":
		restore = 0
	elif original == "high":
		restore = 2
	performance.call("set_profile", restore, true)
	assert(str(store.call("get_profile")) == original)
	print("[KartQualityPersist] PASS: Autoload read/write, file persistence, scene signal")
	quit(0)
