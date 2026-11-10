extends SceneTree
## 2013 menu depth: old five-step garage stays intact, with extra 3D cues.

const EXPECTED_SETUP := ["mode", "driver", "kart", "track", "difficulty"]
const EXPECTED_TRACKS := ["sonnenhafen", "zauberwald", "bergwelt", "holo_city"]
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		print("[MenuDepth] FAIL: ", label)


func _settle(frames: int = 6) -> void:
	for _i in range(frames):
		await process_frame


func _find(root: Node, name: String) -> Node:
	return root.find_child(name, true, false)


func _run() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.remove_absolute("user://kart_preferences.cfg")
	var game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	await _settle(8)
	var garage = game.garage
	_check(is_instance_valid(garage), "garage exists")
	_check(garage.step_buttons.size() == 5, "five setup steps")
	_check(garage.step == 0, "starts on mode step")
	for key in EXPECTED_SETUP:
		_check(garage.setup.has(key), "setup keeps " + key)
	_check(str(garage.setup.mode) == "race", "default mode race")
	_check(str(garage.setup.track) == "sonnenhafen", "default track sonnenhafen")
	_check(str(garage.setup.kart) == "comet", "default kart comet")
	_check(str(garage.setup.driver) == "fox", "default driver fox")
	_check(is_instance_valid(garage.preview_viewport), "live 3D preview viewport")
	_check(is_instance_valid(garage.preview_kart), "live 3D kart")
	_check(is_instance_valid(garage.world_backdrop), "original world backdrop")
	_check(is_instance_valid(_find(garage, "SonnenhafenGoldenHour")), "sunset depth layer")
	_check(is_instance_valid(_find(garage, "HeroDepthVignette")), "preview vignette")
	_check(is_instance_valid(_find(garage, "TranslucentHeroStage")), "glass podium")
	_check(is_instance_valid(_find(garage, "HeroStageUnderlayer")), "podium underlayer")
	_check(garage.stage_rings.size() == 3, "three neon rings")
	_check(is_instance_valid(_find(garage.preview, "GarageInterior3D")), "3D garage interior")
	_check(is_instance_valid(_find(garage.preview, "NeonLumoSign")), "neon LUMO sign")
	_check(is_instance_valid(_find(garage.preview, "GarageFloor")), "garage floor")
	_check(is_instance_valid(_find(garage.preview_pivot, "GarageTurntable")), "rotating turntable")
	for action in ["start", "strecke", "kart", "back"]:
		_check(garage.garage_buttons.has(action), "3D button " + action)
		_check(is_instance_valid(_find(garage.preview, "Garage3DButton_" + action)), "3D button node " + action)
	garage.graphics_profile = "high"
	var high_calls: int = garage.preview_draw_calls()
	print("[MenuDepth] draw_calls high=", high_calls)
	_check(high_calls < 220, "high-tier draw calls stay in the mobile preview budget")
	_check(is_instance_valid(garage.next_button), "Weiter control remains")
	_check(garage.title_label.text in ["Dein nächstes Abenteuer", "Dein Abenteuer"], "old title")
	var catalog = load("res://scripts/games/kart_catalog.gd")
	var tracks: Array = catalog.TRACKS if catalog.get("TRACKS") != null else []
	if tracks.is_empty() and catalog.has_method("tracks"):
		tracks = catalog.tracks()
	# Catalog exposes TRACKS as a const on the script.
	var ids: Array[String] = []
	for item in catalog.TRACKS:
		ids.append(str(item.id))
	for track_id in EXPECTED_TRACKS:
		_check(track_id in ids, "track id remains " + track_id)
	# Parallax must not run when reduced motion is on.
	garage.reduced_motion = true
	garage.preview_idle_time = 2.5
	garage.preview_angle = 0.8
	garage._process(0.16)
	_check(garage._backdrop_parallax == Vector2.ZERO, "reduced motion keeps backdrop still")
	garage.reduced_motion = false
	garage._process(0.16)
	_check(garage._backdrop_parallax != Vector2.ZERO, "idle parallax offsets the painting")
	game.queue_free()
	await _settle(2)
	if failures.is_empty():
		print("[MenuDepth] PASS: ", checks, " checks")
		quit(0)
	else:
		print("[MenuDepth] FAIL: ", failures)
		quit(1)
