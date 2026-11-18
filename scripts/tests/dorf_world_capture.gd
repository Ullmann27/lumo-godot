extends SceneTree
## Dorf- und Bauwelt-Bildaufnahme (xvfb + gl_compatibility oder Vulkan).
## Pro Qualitätsstufe: Dorf-Startblick, belebtes Dorf (gleicher Spielstand für
## Vorher/Nachher), Abendstimmung und die Bauwelt; quer 1600x720, hoch 720x1600.
## Ausgabe: DORF_CAPTURE_DIR (PNG + metrics.json). llvmpipe-Zahlen sind keine
## Gerätemessung; Draw-Calls/Dreiecke aus der Spielkamera sind vergleichbar.
const CHILD := "dorfcapture"
const STATE = preload("res://scripts/creative/build_settlement_state.gd")
const KINDS := [
	"house", "farm", "house", "lumber", "house", "well", "market", "house", "grain", "bakery",
	"house", "quarry", "school", "house", "road", "house", "clinic", "farm", "house", "grain",
	"house", "lumber", "house", "well", "house", "market", "house", "farm", "house", "bakery",
	"house", "grain", "house", "house", "road", "house", "farm", "house", "school", "house",
]


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
	print("[DorfCapture] %s %s" % [name, JSON.stringify(stats)])
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


## Ein fester, gültiger Spielstand: 49 Grundstücke, 40 Gebäude aller Arten.
func _populate(village: Node) -> void:
	var town: Dictionary = village.model._player
	town.region = 3
	town.plots = 49
	town.buildings = []
	town.households = []
	var plot := 0
	for index in range(KINDS.size()):
		var kind: String = KINDS[index]
		if village.has_method("plot_buildable") and not village.plot_buildable(plot):
			plot += 1
		var id := "b%d" % (index + 1)
		town.buildings.append({"id": id, "kind": kind, "plot": plot})
		if kind == "house":
			town.households.append({"building_id": id, "adults": 2, "children": 1, "supplied_days": 9})
		plot += 1
	town.next_id = KINDS.size() + 1
	town.population = 40
	village._rebuild()
	village._camera_update(true)


func _run() -> void:
	var dir: String = OS.get_environment("DORF_CAPTURE_DIR")
	if dir.is_empty():
		dir = ProjectSettings.globalize_path("user://dorf_capture")
	DirAccess.make_dir_recursive_absolute(dir)
	var args := OS.get_cmdline_user_args()
	var tiers: Array = [0, 1, 2]
	if "--high-only" in args:
		tiers = [2]
	var sizes: Array = [[Vector2i(1600, 720), "quer"], [Vector2i(720, 1600), "hoch"]]
	var quick := "--quick" in args
	if quick:
		tiers = [2]
		sizes = [[Vector2i(1600, 720), "quer"]]
	var performance: Node = root.get_node("PerformanceManager")
	var router: Node = root.get_node("SceneRouter")
	var metrics: Dictionary = {}
	await process_frame
	for tier in tiers:
		var tier_name: String = ["low", "medium", "high"][tier]
		var entry: Dictionary = {}
		for size_spec in sizes:
			if size_spec[1] == "hoch" and tier == 0 and "--all-sizes" not in args:
				continue
			root.size = size_spec[0]
			var suffix := "%s_%s" % [tier_name, size_spec[1]]
			performance.call("set_profile", tier, false)
			_clear_saves()
			router.launch_options = {
				"childKey": CHILD, "settlementMode": "settlement", "livingVillage": true, "buildSlot": 1
			}
			var village: Node = load("res://scenes/creative/build_settlement_world.tscn").instantiate()
			root.add_child(village)
			current_scene = village
			performance.call("set_profile", tier, false)
			await _frames(40)
			entry["dorf_start_" + size_spec[1]] = await _save(dir, "dorf_start_" + suffix)
			_populate(village)
			await _frames(40)
			entry["dorf_belebt_" + size_spec[1]] = await _save(dir, "dorf_belebt_" + suffix)
			if village.has_method("set_time_of_day"):
				village.set_time_of_day(0.82)
				await _frames(20)
				entry["dorf_abend_" + size_spec[1]] = await _save(dir, "dorf_abend_" + suffix)
				village.set_time_of_day(0.35)
			if "--close" in args or tier == 2:
				village.radius = 18.0
				village.tilt = 0.5
				village.orbit = 0.6
				village._camera_update(true)
				await _frames(30)
				entry["dorf_nah_" + size_spec[1]] = await _save(dir, "dorf_nah_" + suffix)
			village.queue_free()
			await _frames(3)
			_clear_saves()
			if quick:
				continue
			router.launch_options = {"childKey": CHILD}
			var build: Node = load("res://scenes/creative/build_world.tscn").instantiate()
			root.add_child(build)
			current_scene = build
			performance.call("set_profile", tier, false)
			await _frames(30)
			if build.get("model") != null and build.model.has_method("template"):
				build.model.template("village")
				build._rebuild()
				await _frames(20)
			entry["bauwelt_" + size_spec[1]] = await _save(dir, "bauwelt_" + suffix)
			build.queue_free()
			await _frames(3)
			_clear_saves()
		metrics[tier_name] = entry
	var file := FileAccess.open(dir.path_join("metrics.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(metrics, "  "))
	file.close()
	print("[DorfCapture] PASS %s" % dir)
	quit(0)
