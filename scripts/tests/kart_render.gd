extends SceneTree
var frame: int = 0
var game
var is_jump: bool = false
func _initialize() -> void:
	call_deferred("_setup")

func _setup() -> void:
	root.size = Vector2i(720, 1280)
	is_jump = OS.get_cmdline_user_args().has("--game=jump")
	var scene: PackedScene = load("res://scenes/games/jump_islands.tscn" if is_jump else "res://scenes/games/kart_island.tscn")
	game = scene.instantiate()
	root.add_child(game)
	await process_frame
	if is_jump:
		game.actor.position = game.islands[2] + Vector3(0, 0.4, 1)
		game.checkpoint = 2
		game.paused = true
		game.message.text = "Lumos Wolkeninseln\nSpringen, Kristalle und Lerninseln"
	else:
		game.countdown = 0
		game.distance = 16
		game.speed = 11
		game.racing = false
		game.message.text = "Lumos Insel-Cup\nKurven, Kristalle und Lernstopps"
func _process(_delta: float) -> bool:
	if not is_instance_valid(game) or game.message == null:
		return false
	frame += 1
	if frame == 70:
		var image: Image = root.get_texture().get_image()
		DirAccess.make_dir_recursive_absolute("res://exports/screenshots")
		image.save_png("res://exports/screenshots/lumo-jump-3d.png" if is_jump else "res://exports/screenshots/lumo-kart-3d.png")
	if frame == 110:
		game._open_question()
	if frame == 145:
		var image: Image = root.get_texture().get_image()
		image.save_png("res://exports/screenshots/lumo-jump-learning.png" if is_jump else "res://exports/screenshots/lumo-kart-learning.png")
		quit(0)
	return false
