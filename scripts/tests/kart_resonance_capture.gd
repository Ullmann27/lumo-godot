extends SceneTree
## Actual Godot/GL Compatibility screenshot of a playable Lumo racing
## resonance ring. No authored/mock composite and no forced result state.
var game
var scene: PackedScene
var frames: int = 0

func _initialize() -> void:
	call_deferred("_setup")

func _setup() -> void:
	root.size = Vector2i(1280, 720)
	scene = load("res://scenes/games/kart_island.tscn")
	game = scene.instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = false
	await process_frame
	game._start_selected_race({
		"mode": "race", "driver": "fox", "kart": "comet",
		"track": "sonnenhafen", "difficulty": "flott"
	})
	game._end_preview()
	await process_frame
	var gate: float = game.item_box_distances[0]
	var lane: float = game.item_box_laterals[0]
	var before: float = gate - 13.0
	game.player.transform = game.world.reset_transform(before, lane)
	game.player_heading = game._heading(before)
	game.player.rotation = Vector3(0.0, game.player_heading, 0.0)
	game.previous_road_distance = before
	game.distance = before
	game.speed = 17.0
	game.countdown = 0.0
	game.racing = true
	game._update_camera(1.0, true)
	DirAccess.make_dir_recursive_absolute("res://exports/resonance")
	frames = 0

func _process(_delta: float) -> bool:
	if not is_instance_valid(game):
		return false
	frames += 1
	if frames == 18:
		var frame: Image = root.get_texture().get_image()
		assert(frame.get_width() == 1280 and frame.get_height() == 720)
		var path: String = "res://exports/resonance/sonnenhafen-real-ring.png"
		assert(frame.save_png(path) == OK, "Actual GL framebuffer capture must succeed")
		print("[KartResonanceCapture] PASS: actual Sonnenhafen in-game ring at 1280x720")
		game.abandoned = true
		game.queue_free()
		scene = null
		call_deferred("_complete")
	return false

func _complete() -> void:
	await create_timer(1.3).timeout
	game = null
	quit(0)
