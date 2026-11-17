extends SceneTree
## Bildbeleg für den Zieleinlauf: echtes Rennen auf einer Strecke starten, mit
## Platz 1, 2 und 3 ins Ziel bringen (nur die Rangfolge wird gesetzt, sonst läuft
## der normale _finish()-Weg samt Zielfahrt) und das Ergebnis in mehreren
## Fenstergrößen speichern. Echter Renderer (xvfb), kein Android-FPS-Test.
## Aufruf: godot --rendering-method gl_compatibility --script
##   res://scripts/tests/kart_result_capture.gd -- <zielordner>
##   [--track=id] [--mode=race] [--places=1,2,3] [--sizes=1600x720@2,2400x1080@2.625]
##   [--reduced] [--cheer=0.3] [--drive]
## --drive fährt das ganze Rennen ohne Lenkeingabe (Auto-Gas); das Kart rollt
## dann wie bei einem echten Kind am Rand aus und der Platz ist der gefahrene.
const SCENE_TEARDOWN = preload("res://scripts/tests/helpers/kart_scene_teardown.gd")
const STEP: float = 1.0 / 60.0
var game
var track: String = "sonnenhafen"
var race_mode: String = "race"
var out_dir: String = "user://kart_result_capture"
var places: Array[int] = [1, 2, 3]
var reduced: bool = false
var drive: bool = false
## Anteil der Jubelbewegung, an dem das Bild entsteht.
var cheer_phase: float = 0.45
## Fenster in Pixeln und die Gerätedichte, die die App auf so einem Gerät meldet.
var sizes: Array = [
	[Vector2i(1600, 720), 2.0], [Vector2i(2400, 1080), 2.625], [Vector2i(1812, 2176), 2.625]
]
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _parse_arguments() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--track="):
			track = arg.trim_prefix("--track=")
		elif arg.begins_with("--mode="):
			race_mode = arg.trim_prefix("--mode=")
		elif arg == "--reduced":
			reduced = true
		elif arg == "--drive":
			drive = true
		elif arg.begins_with("--cheer="):
			cheer_phase = float(arg.trim_prefix("--cheer="))
		elif arg.begins_with("--places="):
			places.clear()
			for value in arg.trim_prefix("--places=").split(","):
				places.append(int(value))
		elif arg.begins_with("--sizes="):
			sizes.clear()
			for value in arg.trim_prefix("--sizes=").split(","):
				var parts: PackedStringArray = value.split("@")
				var pixels: PackedStringArray = parts[0].split("x")
				sizes.append([
					Vector2i(int(pixels[0]), int(pixels[1])),
					float(parts[1]) if parts.size() > 1 else 1.0
				])
		elif not arg.begins_with("--"):
			out_dir = arg


## Lumo im Kart steht in der freien Fläche neben bzw. über der Tafel, vor der
## Kamera und im Bild; das Ergebnis dunkelt die Szene nicht ab.
func _check_framing(window: Vector2i) -> void:
	var screen: Rect2 = root.get_visible_rect()
	var dialog: Rect2 = game.modal.get_global_rect()
	var body: Vector3 = game.player.global_position + Vector3.UP * 0.9
	var head: Vector3 = game.player.global_position + Vector3.UP * 1.7
	var problems: PackedStringArray = []
	for point in [body, head]:
		var at: Vector2 = game.camera.unproject_position(point)
		if game.camera.is_position_behind(point) or not screen.has_point(at):
			problems.append("Lumo is outside the picture at %s" % at)
		elif dialog.has_point(at):
			problems.append("Lumo is hidden behind the panel at %s" % at)
	var centre: Vector2 = game.camera.unproject_position(body)
	if float(window.x) >= float(window.y) * 1.3:
		if centre.x >= dialog.position.x:
			problems.append("kart is not left of the panel")
	elif centre.y >= dialog.position.y:
		problems.append("kart is not above the panel")
	if game.modal_backdrop.visible:
		problems.append("result dims the scene")
	if game.hud_content.visible:
		problems.append("race HUD still covers the result")
	for problem in problems:
		failures += 1
		push_error("[KartResultCapture] FAIL: %s %s" % [window, problem])


func _run() -> void:
	_parse_arguments()
	if DisplayServer.get_name() == "headless":
		push_error("[KartResultCapture] FAIL: needs a real renderer (xvfb)")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	DirAccess.remove_absolute("user://kart_sonnenhafen_session.cfg")
	var bridge: Node = root.get_node("HostBridge")
	for place in places:
		root.size = sizes[0][0]
		bridge._options["displayDensity"] = float(sizes[0][1])
		game = load("res://scenes/games/kart_island.tscn").instantiate()
		root.add_child(game)
		game.set_physics_process(false)
		await process_frame
		game.reduced_motion = reduced
		game.preferred_reduced_motion = reduced
		game._start_selected_race(
			{"mode": race_mode, "driver": "fox", "kart": "comet", "track": track, "difficulty": "flott"}
		)
		game._end_preview()
		game.countdown = 0
		game.racing = true
		await process_frame
		if drive:
			for frame in range(20000):
				if game.finished:
					break
				game._physics_process(STEP)
				if frame % 240 == 0:
					await process_frame
			place = int(game.result_payload.get("place", 0))
		else:
			# Ein kurzes echtes Stück fahren, damit das Kart mit Schwung über die Linie rollt.
			for frame in range(90):
				game.gas_held = true
				game._physics_process(STEP)
			game.gas_held = false
			game.elapsed = 98.4 + float(place) * 2.137
			game.checkpoint_index = 16
			game.lap_times.assign([50.312 + float(place), 48.088 + float(place) * 1.137])
			game.lap_started_at = -1.0
			# _place() zählt die Gegner, die weiter sind: genau place - 1 liegen vorn.
			game.distance = game.track_length * 2.0
			for i in range(game.opponent_distances.size()):
				game.opponent_distances[i] = game.distance + (5.0 if i < place - 1 else -5.0 - float(i))
			game._finish()
		var cine_frames: int = 0
		while game.finish_cine_left > 0.0 and cine_frames < 600:
			game._physics_process(STEP)
			cine_frames += 1
			if cine_frames % 6 == 0:
				await process_frame
		if not game.modal.visible:
			failures += 1
			push_error("[KartResultCapture] FAIL: result did not appear for place %d" % place)
		if game._ranked() and int(game.result_payload.get("place", 0)) != place:
			failures += 1
			push_error("[KartResultCapture] FAIL: wanted place %d, payload has %s" % [
				place, str(game.result_payload.get("place"))
			])
		for size in sizes:
			var window: Vector2i = size[0]
			bridge._options["displayDensity"] = float(size[1])
			root.size = window
			for frame in range(50):
				game._physics_process(STEP)
				if frame % 2 == 0:
					await process_frame
			# Die echte Jubelbewegung an der gewünschten Stelle festhalten (kein gestelltes Bild).
			var animator = game.player.get("lumo_animation")
			if not reduced and is_instance_valid(animator) and is_instance_valid(animator.actor):
				var clip_player: AnimationPlayer = animator.actor.player
				for frame in range(900):
					if animator.victory and clip_player.current_animation_length > 0.0:
						var phase: float = clip_player.current_animation_position / clip_player.current_animation_length
						if absf(phase - cheer_phase) < 0.03:
							break
					game._physics_process(STEP)
					game.player._process(STEP)
				await process_frame
			_check_framing(window)
			await RenderingServer.frame_post_draw
			var image: Image = root.get_texture().get_image()
			var name: String = "ziel_platz%d_%dx%d%s%s" % [
				place, window.x, window.y, "_ruhig" if reduced else "", "_gefahren" if drive else ""
			]
			if race_mode != "race":
				name = race_mode + "_" + name
			var path: String = out_dir.path_join(name + ".png")
			if image.save_png(path) != OK:
				failures += 1
				push_error("[KartResultCapture] FAIL: could not write " + path)
			print("[KartResultCapture] %s place=%d window=%s density=%.3f dialog=%s" % [
				path, place, window, float(size[1]), game.modal.get_global_rect()
			])
		game.abandoned = true
		if not (await SCENE_TEARDOWN.release_scene(self, game, "[KartResultCapture]")):
			failures += 1
	bridge._options.erase("displayDensity")
	DirAccess.remove_absolute("user://kart_sonnenhafen_session.cfg")
	if failures > 0:
		print("[KartResultCapture] FAIL: %d problems" % failures)
		quit(1)
		return
	print("[KartResultCapture] PASS: %d places x %d window sizes -> %s" % [
		places.size(), sizes.size(), out_dir
	])
	quit(0)
