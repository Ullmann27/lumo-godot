extends SceneTree
## Zieleinlauf-Beleg: echtes Rennen (nur Lenkung automatisch), danach Bilder
## der Zielfahrt-Kamera und des Ergebnisses als Kontaktbogen. Software-Rendering
## (xvfb), kein Android-FPS-Test.
## Aufruf: godot --rendering-method gl_compatibility --script scripts/tests/kart_finish_capture.gd -- <out.png> [--track=id]
const STEP: float = 1.0 / 60.0
var game
var track: String = "sonnenhafen"
var out_path: String = "res://exports/finish/zieleinlauf.png"
var sheet: Image
var shot: int = 0
var cine_frame: int = 0
var done_result: bool = false


func _initialize() -> void:
	call_deferred("_setup")


func _setup() -> void:
	root.size = Vector2i(960, 540)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--track="):
			track = arg.trim_prefix("--track=")
		elif arg.ends_with(".png"):
			out_path = arg
	sheet = Image.create(1920, 1620, false, Image.FORMAT_RGBA8)
	DirAccess.remove_absolute("user://kart_sonnenhafen_session.cfg")
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	game._start_selected_race(
		{"mode": "race", "driver": "fox", "kart": "comet", "track": track, "difficulty": "gemuetlich"}
	)


func _save() -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	sheet.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i((shot % 2) * 960, (shot / 2) * 540))
	shot += 1


func _process(_delta: float) -> bool:
	if not is_instance_valid(game) or game.menu_active or done_result:
		return false
	if not game.finished:
		if game.preview_left > 0.0:
			game._end_preview()
		# Viele Physikschritte pro Bild: das Rennen läuft unverändert mit 60 Hz.
		for i in range(240):
			if game.finished:
				break
			var target: Vector3 = game.world.position_at(game.previous_road_distance + 10, 0)
			var direction: Vector3 = target - game.player.position
			var heading: float = atan2(-direction.x, -direction.z)
			game.steering = clampf(-angle_difference(game.player_heading, heading) * 2.1, -1, 1)
			game.brake = 0.0
			game._physics_process(STEP)
		return false
	if game.finish_cine_left > 0.0:
		if cine_frame in [2, 70, 150, 186]:
			_save()
		game._physics_process(STEP)
		cine_frame += 1
		return false
	done_result = true
	_finish_capture()
	return false


func _finish_capture() -> void:
	for i in range(4):
		await process_frame
	await _save()
	DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
	assert(sheet.save_png(out_path) == OK)
	print("[KartFinishCapture] PASS: place=%d time=%.2f best_lap=%s cine_frames=%d -> %s" % [
		int(game.result_payload.get("place", 0)), game.elapsed,
		str(game.result_payload.get("bestLapSeconds", 0)), cine_frame, out_path])
	game.abandoned = true
	game.queue_free()
	quit(0)
