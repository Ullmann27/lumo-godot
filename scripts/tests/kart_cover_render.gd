extends SceneTree
## Actual game rendering, original fox and vehicle; no UI or image editing.

var game
var frame: int = 0


func _initialize() -> void:
	call_deferred("_setup")


func _setup() -> void:
	root.size = Vector2i(1280, 720)
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.countdown = 0
	game.paused = true
	game.distance = game.track_length * 0.31
	game._update_vehicles(0)
	for child in game.get_children():
		if child is CanvasLayer:
			child.hide()
	for opponent in game.opponents:
		opponent.hide()
	for gem in game.gems:
		gem.hide()
	for node in game.world.find_children("*", "Label3D", true, false):
		node.hide()
	var at: Vector3 = game.player.position
	game.camera.fov = 40
	game.camera.position = at + game.world.frame(game.distance) * Vector3(2.7, 1.6, -4.3)
	game.camera.look_at(at + Vector3.UP * 0.95)
	DirAccess.make_dir_recursive_absolute("res://exports/screenshots")


func _process(_delta: float) -> bool:
	if not is_instance_valid(game):
		return false
	frame += 1
	if frame == 24:
		var capture: Image = root.get_texture().get_image()
		assert(capture.save_png("res://exports/screenshots/lumo-kart-cover.png") == OK)
		print("[KartCover] PASS: actual engine render, 1280x720 original Lumo fox and kart")
		game.abandoned = true
		game.queue_free()
		quit(0)
	return false
