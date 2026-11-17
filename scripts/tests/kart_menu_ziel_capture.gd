extends SceneTree
## Echte Godot-Aufnahme des Kart-Hauptmenüs (kart_island + Live-3D-Bühne) in
## Handy-, Fold- und Querformat. Ausgabe: user-definierter Ordner per --out=<pfad>.
## Nur Aufnahme; keine Spielstände werden geschrieben.
## [Name, Fensterpixel, Android-Dichte]: Dichte wie auf echten Geräten (dp = px / Dichte).
const SURFACES := [
	["phone_portrait", Vector2i(720, 1600), 2.0],
	["fold7_inner", Vector2i(1968, 2184), 2.625],
	["fold7_cover", Vector2i(1080, 2520), 2.625],
	["phone_landscape", Vector2i(1600, 720), 2.0],
]
var output := "user://kart_menu_ziel"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output = arg.substr(6)
	call_deferred("_run")


func _settle(frames: int = 8) -> void:
	for i in range(frames):
		await process_frame


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	var game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await _settle(10)
	for entry in SURFACES:
		var host: Node = root.get_node_or_null("HostBridge")
		if host != null and "_options" in host:
			host._options["displayDensity"] = float(entry[2])
		root.size = entry[1]
		await _settle(6)
		game.reduced_motion = true
		game._show_reference_landing()
		await _settle(30)
		var image: Image = root.get_texture().get_image()
		var path: String = output.path_join("menu_%s.png" % entry[0])
		image.save_png(path)
		print("[KartMenuZielCapture] saved ", path, " ", image.get_size())
	game.queue_free()
	await _settle(4)
	print("[KartMenuZielCapture] PASS")
	quit(0)
