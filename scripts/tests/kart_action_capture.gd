extends SceneTree
## Echte Spielaufnahmen der Action-Elemente aus der Verfolgerkamera (1280×720, gl_compatibility):
## Turbo-Feld, Slalom, Sprungschanze im Flug, Unterwasser-Tunnel und offene Kante.
## Aufruf: godot --rendering-method gl_compatibility --script scripts/tests/kart_action_capture.gd -- [ordner]
const STEP: float = 1.0 / 60.0
var game
var out_dir: String = "res://exports/action-course"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	call_deferred("_run")


func _start(track: String) -> void:
	game._start_selected_race({"mode": "training", "driver": "fox", "kart": "comet", "track": track, "difficulty": "flott"})
	game._end_preview()
	for frame in range(3):
		await process_frame
	game.countdown = 0
	game.racing = true
	game.auto_gas = true


func _place(at: float, lateral: float, speed: float) -> void:
	game.distance = at
	game.previous_road_distance = at
	game.player.transform = game.world.reset_transform(at, lateral)
	game.player_heading = game._heading(at)
	game.player.rotation = Vector3(0, game.player_heading, 0)
	game.speed = speed
	game.physical_velocity = Vector3(-sin(game.player_heading), 0, -cos(game.player_heading)) * speed
	game.airborne = false


## Fährt mit echter Physik bis kurz vor die Stelle und nimmt dann das Bild auf.
func _shot(name: String, start: float, lateral: float, frames: int, until_airborne: bool = false) -> void:
	_place(start, lateral, 15.0)
	for frame in range(frames):
		var target: Vector3 = game.world.position_at(game.previous_road_distance + 8.0, lateral)
		var direction: Vector3 = target - game.player.position
		game.steering = clampf(-angle_difference(game.player_heading, atan2(-direction.x, -direction.z)) * 2.3, -1, 1)
		game._physics_process(STEP)
		if until_airborne and game.airborne and frame > 4:
			break
		if frame % 10 == 0:
			await process_frame
	for frame in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	assert(image.save_png(out_dir.path_join(name + ".png")) == OK)
	print("[ActionCapture] ", name)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1280, 720)
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	for frame in range(4):
		await process_frame
	await _start("zauberwald")
	var course: Dictionary = game.world.action
	await _shot("01-turbo-feld", float(course.pads[0].start) - 13.0, float(course.pads[0].lateral), 45)
	await _shot("02-slalom", float(course.gates[0].distance) - 15.0, float(course.gates[0].lateral), 40)
	await _shot("03-schanze-flug", float(course.kickers[0].start) - 16.0, 0.0, 120, true)
	await _shot("04-unterwasser-tunnel", float(course.dives[0].start) - 6.0, 0.0, 40)
	await _start("candy_cloud")
	var edge: Dictionary = game.world.action.edges[0]
	await _shot("05-offene-kante", float(edge.start) - 2.0, float(edge.side) * 2.5, 40)
	game.abandoned = true
	game.queue_free()
	for frame in range(6):
		await process_frame
	await create_timer(1.3).timeout
	print("[ActionCapture] PASS: ", out_dir)
	quit(0)
