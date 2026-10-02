extends SceneTree
var frame: int = 0
var game
func _initialize() -> void:
	call_deferred("_setup")

func _setup() -> void:
	root.size = Vector2i(720, 1280)
	var scene: PackedScene = load("res://scenes/games/kart_island.tscn")
	game = scene.instantiate()
	root.add_child(game)
	await process_frame
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
		image.save_png("res://exports/screenshots/lumo-kart-3d.png")
	if frame == 110:
		game._open_question()
	if frame == 145:
		var image: Image = root.get_texture().get_image()
		image.save_png("res://exports/screenshots/lumo-kart-learning.png")
		quit(0)
	return false
