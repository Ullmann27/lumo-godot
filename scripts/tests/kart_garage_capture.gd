extends SceneTree
## Echte Engine-Aufnahmen der Garage (Kart-Auswahl mit Werten) und der Werkstatt in mehreren Größen.
## Aufruf: godot --rendering-method gl_compatibility --script scripts/tests/kart_garage_capture.gd -- <ordner> [sterne]
const TUNING = preload("res://scripts/games/kart_tuning.gd")
var out_dir: String = "res://exports/screenshots"
var stars: int = 60


func _initialize() -> void:
	call_deferred("_run")


func _settle(frames: int = 3) -> void:
	for i in range(frames):
		await process_frame
	await RenderingServer.frame_post_draw


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	if args.size() > 1:
		stars = int(args[1])
	DirAccess.make_dir_recursive_absolute(out_dir)
	DirAccess.remove_absolute("user://kart_preferences.cfg")
	var game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	await _settle()
	for pixels in [Vector2i(1280, 720), Vector2i(412, 915), Vector2i(690, 829)]:
		root.size = pixels
		await _settle(4)
		var garage = game.garage
		garage.stars = stars
		garage.unlocked_ids = []
		garage.workshop = TUNING.new("capture_child", stars)
		garage.workshop.save_enabled = false
		garage.workshop.upgrade("comet", "motor")
		garage.workshop.upgrade("comet", "motor")
		garage.workshop.upgrade("comet", "turbo")
		garage._apply_responsive_layout()
		garage.setup.kart = "comet"
		garage.step = 2
		garage._refresh()
		await _settle(40)
		root.get_texture().get_image().save_png("%s/garage-kart-%dx%d.png" % [out_dir, pixels.x, pixels.y])
		garage.workshop_button.pressed.emit()
		await _settle(40)
		root.get_texture().get_image().save_png("%s/werkstatt-%dx%d.png" % [out_dir, pixels.x, pixels.y])
		garage.handle_back()
		await _settle()
	print("[GarageCapture] PASS: ", out_dir)
	quit(0)
