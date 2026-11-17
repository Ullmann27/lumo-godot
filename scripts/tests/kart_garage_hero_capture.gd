extends SceneTree
## 1280x720 hero shots of the garage: kart + Lumo, rotation, large cards.
## Usage: godot --script scripts/tests/kart_garage_hero_capture.gd -- <out_dir> [stars]

const TUNING = preload("res://scripts/games/kart_tuning.gd")
var out_dir: String = "res://exports/garage-hero"
var stars: int = 60


func _initialize() -> void:
	call_deferred("_run")


func _settle(frames: int = 8) -> void:
	for _i in range(frames):
		await process_frame
	await RenderingServer.frame_post_draw


func _shot(name: String) -> void:
	await _settle(12)
	var image: Image = root.get_texture().get_image()
	assert(image.get_width() == 1280 and image.get_height() == 720)
	assert(image.save_png(out_dir + "/" + name + ".png") == OK)
	print("[GarageHero] captured ", name)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	if args.size() > 1:
		stars = int(args[1])
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(out_dir)
	DirAccess.remove_absolute("user://kart_preferences.cfg")
	var game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	await _settle()
	var garage = game.garage
	garage.stars = stars
	garage.unlocked_ids = []
	garage.workshop = TUNING.new("capture_child", stars)
	garage.workshop.save_enabled = false
	garage.workshop.upgrade("comet", "motor")
	garage.workshop.upgrade("comet", "motor")
	garage.workshop.upgrade("comet", "turbo")
	garage.setup.kart = "comet"
	garage._apply_responsive_layout()

	garage.step = 2
	garage._refresh()
	garage.preview_angle = -0.25
	garage.preview_idle_time = 0.0
	await _shot("01_kart_select")

	garage.preview_angle = 1.05
	if is_instance_valid(garage.preview_pivot):
		garage.preview_pivot.rotation.y = garage.preview_angle
	await _shot("02_kart_rotated")

	garage.step = 0
	garage._refresh()
	await _shot("03_mode_cards")

	garage.step = 4
	garage._refresh()
	await _shot("04_difficulty_cards")

	print("[GarageHero] PASS: ", out_dir)
	quit(0)
