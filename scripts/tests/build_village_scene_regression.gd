extends SceneTree
## Real scene integration for the separately launched living village.
## Confirms chapter/UI/3D/market/saving without replacing legacy save slots.
const CHILD := "village_native_scene_regression"
const SLOT := 6
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_warning("[VillageScene] " + message)


func _frames(count := 6) -> void:
	for _index in range(count):
		await process_frame


func _run() -> void:
	root.size = Vector2i(1280, 720)
	# SceneRouter is registered after the SceneTree script has loaded. Do not
	# preload production scenes that refer to this autoload at script parse time.
	var world_script = load("res://scripts/creative/build_settlement_world.gd")
	if world_script == null:
		push_error("[VillageScene] Production scene script did not compile")
		quit(1)
		return
	var save := world_script.project_path(CHILD, SLOT, "village")
	var classic_save := world_script.project_path(CHILD, SLOT, "settlement")
	DirAccess.remove_absolute(save)
	var router := root.get_node("SceneRouter")
	router.launch_options = {
		"childKey": CHILD, "buildSlot": SLOT,
		"settlementMode": "settlement", "livingVillage": true
	}
	var village = load("res://scenes/creative/build_settlement_world.tscn").instantiate()
	root.add_child(village)
	await _frames(8)
	_check(village.model.living_village, "The real village scene launches a version-two economy")
	_check(village.model.snapshot().version == 2, "Village save state uses version two")
	_check(village.save_path == save, "Village has its own save path")
	_check(village.save_path != classic_save, "Classic settlement file is never replaced")
	_check(village.purchase_buttons.size() == 11, "All eleven village buildings are offered")
	_check(
		village.village_region != null
		and village.village_region.get_meta("max_plots_per_town", 0) == 1089,
		"The 1089-plot region is attached to the production scene"
	)
	_check(
		village.village_residents != null
		and village.village_residents.has_node("VillageFamilies"),
		"Nelli/Bruno/Tilda residents render through the actual scene"
	)
	_check(
		village.model.campaign_status().chapter == 1
		and village.goal_label.text.contains("Kapitel 1/12"),
		"The first chapter is displayed in the real HUD"
	)
	_check(
		not village.purchase_buttons["market"].text.contains("Münzen"),
		"The actual market purchase button uses the coin-free village quote"
	)

	village.model._player.resources.coins = 0
	village.selected_plot = 4
	village._buy("market")
	_check(
		village.model._count(village.model.player(), "market") == 1,
		"The real scene builds a market with zero coins"
	)
	_check(
		village.model.player().resources.coins == 0
		and village.model.player().buildings[0].purchase_cost == {"wood": 6, "stone": 4},
		"The market keeps its exact cost receipt without gaining coins"
	)
	_check(FileAccess.file_exists(save), "Village market is saved to the isolated file")

	village._chapter_dialog()
	await _frames(2)
	_check(
		is_instance_valid(village.village_window),
		"The 12-chapter UI opens as a real native dialog"
	)
	if is_instance_valid(village.village_window):
		village.village_window.queue_free()
	await _frames(2)

	village._tilda_dialog()
	await _frames(2)
	_check(
		is_instance_valid(village.village_window),
		"Tilda deliveries can be opened in the real game"
	)
	if is_instance_valid(village.village_window):
		village.village_window.queue_free()
	await _frames(2)

	village._public_project_dialog()
	await _frames(2)
	_check(
		is_instance_valid(village.village_window),
		"The town treasury and project UI is reachable"
	)
	if is_instance_valid(village.village_window):
		village.village_window.queue_free()
	await _frames(2)

	village._pan_village(1, 0)
	_check(
		village.focus.x > -100.0,
		"The village can pan towards new district plots"
	)
	village._zoom_village(1)
	_check(village.radius > 34.0, "The village can zoom out across its large land")

	village.queue_free()
	await _frames(5)
	var restored = load("res://scenes/creative/build_settlement_world.tscn").instantiate()
	root.add_child(restored)
	await _frames(8)
	_check(
		restored.model.living_village
		and restored.model._count(restored.model.player(), "market") == 1,
		"The same child resumes the actual version-two village"
	)
	_check(
		restored.model.player().buildings[0].purchase_cost == {"wood": 6, "stone": 4},
		"Save/reload retains the exact market cost receipt"
	)
	restored.queue_free()
	await _frames(5)
	DirAccess.remove_absolute(save)
	if failures.is_empty():
		print("[VillageScene] PASS checks=", checks, " : production village, chapter, economy and resume")
		quit(0)
	else:
		print("[VillageScene] FAIL checks=", checks, " failures=", failures)
		quit(1)
