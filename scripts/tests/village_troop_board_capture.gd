extends SceneTree
## Belegbild der Verbände-Tafel in einer kleinen Stadt (schnell, ohne Großstadt):
## Fold 1812×2176, Telefon 1080×2340 und Fold quer 2176×1812 mit 2,625 px je dp.
## Aufruf mit Renderer (xvfb, gl_compatibility): -- <ausgabeordner>
const STATE = preload("res://scripts/creative/build_settlement_state.gd")
const GUARDS = preload("res://scripts/creative/build_village_guards.gd")
const ECONOMY = preload("res://scripts/creative/build_settlement_economy.gd")
const CHILD := "village_troop_board_capture"
const SLOT := 3


func _initialize() -> void:
	call_deferred("_run")


func _frames(count := 4) -> void:
	for _i in range(count):
		await process_frame


func _run() -> void:
	var out := (
		OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "user://"
	)
	DirAccess.make_dir_recursive_absolute(out)
	var model = STATE.new("settlement", true)
	model._player.resources = {"wood": 900, "stone": 900, "food": 900, "coins": 900}
	model._player.crops.carrots = 900
	model.day = 20
	for index in range(9):
		model.try_build(
			["farm", "farm", "farm", "house", "house", "house", "house", "house", "lumber"][index],
			index
		)
	model._player.population = mini(24, int(model._capacity(model._player)))
	ECONOMY.reconcile_households(model._player)
	var raids = load("res://scripts/creative/build_village_raids.gd").restore(null, model)
	for site in ["schiessplatz", "kaserne"]:
		GUARDS.build_site(model, raids, site)
	raids.guards = 10
	raids.units = [
		{"id": 1, "name": "Fuchs-Trupp", "size": 5, "post": "sued", "type": "schild"},
		{"id": 2, "name": "Eule-Trupp", "size": 3, "post": "nord", "type": "bogen"},
		{"id": 3, "name": "Dachs-Trupp", "size": 2, "post": "mitte", "type": "speer"},
	]
	var options := {
		"childKey": CHILD,
		"buildSlot": SLOT,
		"settlementMode": "settlement",
		"livingVillage": true,
		"displayDensity": 2.625
	}
	root.get_node("HostBridge").set("_options", options.duplicate(true))
	root.get_node("SceneRouter").launch_options = options.duplicate(true)
	var script = load("res://scripts/creative/build_settlement_world.gd")
	var path: String = script.project_path(CHILD, SLOT, "village")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var envelope := {
		"version": 1,
		"child": CHILD,
		"settlement": model.snapshot(),
		"mode": "settlement",
		"slot": SLOT,
		"village_meta":
		{
			"meta_version": 1,
			"raids": raids.snapshot(model),
			"tutorial": {"done": true, "step": 99, "version": 1},
			"dock":
			{
				"version": 1,
				"current": "schuetzen",
				"full": true,
				"open": {"bauen": true, "versorgen": true, "nachbarn": true, "schuetzen": true}
			}
		}
	}
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(envelope))
	file.close()
	root.size = Vector2i(1812, 2176)
	var village = load("res://scenes/creative/build_settlement_world.tscn").instantiate()
	root.add_child(village)
	await _frames(10)
	if is_instance_valid(village.tutorial) and village.tutorial.has_method("skip"):
		village.tutorial.skip()
	village.dock.unlock_all()
	village._apply_dock()
	village.select_dock_section("schuetzen")
	await _frames(10)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join("kleine_stadt_verbaende_1812x2176.png"))
	village._guard_units_dialog()
	print(
		"board_state raids=",
		village.raids != null,
		" visible=",
		village.troop_board.visible,
		" blocked=",
		village._transactions_blocked(),
		" paused=",
		village.paused,
		" save_blocked=",
		village.save_blocked
	)
	for screen in [Vector2i(1812, 2176), Vector2i(1080, 2340), Vector2i(2176, 1812)]:
		root.size = screen
		await _frames(4)
		village._layout()
		await _frames(8)
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		var name := "tafel_%dx%d.png" % [screen.x, screen.y]
		image.save_png(out.path_join(name))
		print("board_capture_saved:", name, " ", image.get_size())
	quit(0)
