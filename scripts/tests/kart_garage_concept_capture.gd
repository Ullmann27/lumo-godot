extends SceneTree
## Neue farbige Garage-Seite („Deine Garage“) mit den drei Karosserien, je Quer 1600x720
## und Hoch 720x1600. Aufruf: godot --path . --rendering-method gl_compatibility --script
##   res://scripts/tests/kart_garage_concept_capture.gd -- <out_dir>

const TUNING = preload("res://scripts/games/kart_tuning.gd")
var out_dir: String = "user://garage-concept"


func _initialize() -> void:
	call_deferred("_run")


func _settle(frames: int = 14) -> void:
	for _i in range(frames):
		await process_frame
	await RenderingServer.frame_post_draw


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DirAccess.remove_absolute("user://kart_preferences.cfg")
	root.size = Vector2i(1600, 720)
	var game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await _settle()
	var garage = game.garage
	garage.stars = 200
	garage.unlocked_ids = []
	garage.workshop = TUNING.new("capture_child", 200)
	garage.workshop.save_enabled = false
	for size in [Vector2i(1600, 720), Vector2i(720, 1600)]:
		root.size = size
		for kart in ["comet", "glider", "turbo"]:
			garage.setup.kart = kart
			garage.step = 2
			garage._refresh()
			garage._apply_responsive_layout()
			garage.preview_angle = -0.35
			garage.preview_idle_time = 0.0
			await _settle(24)
			var path := "%s/garage_%s_%dx%d.png" % [out_dir, kart, size.x, size.y]
			root.get_texture().get_image().save_png(path)
			print("[GarageConcept] ", path, " draw_calls=", garage.preview_draw_calls())
	quit(0)
