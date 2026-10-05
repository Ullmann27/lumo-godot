extends SceneTree
## Real pictures of the surrounding Godot app, generated alongside game changes.

var frame_index: int = 0
var scene


func _initialize() -> void:
	call_deferred("_setup")


func _setup() -> void:
	root.size = Vector2i(720, 1280)
	scene = load("res://scenes/games/game_hub.tscn").instantiate()
	root.add_child(scene)
	DirAccess.make_dir_recursive_absolute("res://exports/screenshots")


func _process(_delta: float) -> bool:
	frame_index += 1
	if frame_index == 15:
		var picture: Image = root.get_texture().get_image()
		picture.save_png("res://exports/screenshots/lumo-games-menu.png")
		scene.queue_free()
		var home = load("res://scenes/app/home_3d.tscn").instantiate()
		root.add_child(home)
	if frame_index == 35:
		var picture: Image = root.get_texture().get_image()
		picture.save_png("res://exports/screenshots/lumo-existing-home.png")
		print("[AppRender] PASS: games menu and existing Godot home")
		quit(0)
	return false
