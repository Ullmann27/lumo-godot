## SceneRouter (Autoload als 'SceneRouter').
##
## Zentraler Wechsel zwischen den Top-Level-Szenen Boot/Intro/Home/Loading.
## Verhindert dass irgendwo im Code direkt `change_scene_to_file()` mit
## hartem Pfad steht.
##
## Verwendung:
##   SceneRouter.goto("intro")
##   SceneRouter.goto("home")
extends Node

const SCENES: Dictionary = {
	"boot": "res://scenes/app/boot.tscn",
	"intro": "res://scenes/app/intro_3d.tscn",
	"home": "res://scenes/app/home_3d.tscn",
	"loading": "res://scenes/app/loading_screen.tscn",
	"learn": "res://scenes/games/reading_hub.tscn",
	"reading_hub": "res://scenes/games/reading_hub.tscn",
	"alphabet": "res://scenes/games/alphabet_carousel.tscn",
	"word_picture_match": "res://scenes/games/word_picture_match.tscn",
	"sound_letter_match": "res://scenes/games/sound_letter_match.tscn",
	"word_build": "res://scenes/games/word_build.tscn",
	"learn_old": "res://scenes/games/learn_card.tscn",
	"games": "res://scenes/games/game_hub.tscn",
	"puzzle": "res://scenes/creative/puzzle_world.tscn",
	"build": "res://scenes/creative/build_world.tscn",
	"rhythm": "res://scenes/creative/rhythm_world.tscn",
	"treasure": "res://scenes/creative/treasure_world.tscn",
	"kart": "res://scenes/games/kart_island.tscn",
	"jump": "res://scenes/games/jump_islands.tscn",
	"stars": "res://scenes/games/star_collect.tscn",
	"parent": "res://scenes/games/parent_settings.tscn",
}

var launch_options: Dictionary = {}
var current_scene_id: String = "boot"
signal loaded_navigation_failed(scene_id: String)
var _loaded_navigation_pending := false


## Boot consumes actual ResourceLoader results instead of reopening the same
## scene synchronously. Existing in-game navigation and host return stay intact.
func goto_loaded(scene_id: String, scene: PackedScene) -> Error:
	if _loaded_navigation_pending:
		return ERR_BUSY
	if not SCENES.has(scene_id) or scene == null or not scene.can_instantiate():
		return ERR_INVALID_PARAMETER
	if scene.resource_path != str(SCENES[scene_id]):
		return ERR_INVALID_PARAMETER
	_loaded_navigation_pending = true
	_commit_loaded_scene.call_deferred(scene_id, scene)
	return OK


func _commit_loaded_scene(scene_id: String, scene: PackedScene) -> void:
	var from := current_scene_id
	var entry_cover: CanvasLayer
	# Retain only the original artwork for the one frame where SceneTree's
	# current_scene is null. No screenshot/readback and no duplicate menu.
	var previous := get_tree().current_scene
	if DisplayServer.get_name() != "headless" and is_instance_valid(previous):
		var background := previous.get_node_or_null("Layer/Background") as TextureRect
		if background != null:
			entry_cover = CanvasLayer.new()
			entry_cover.layer = 100
			get_tree().root.add_child(entry_cover)
			entry_cover.add_child(background.duplicate())
	var error := get_tree().change_scene_to_packed(scene)
	if error != OK:
		_loaded_navigation_pending = false
		if is_instance_valid(entry_cover):
			entry_cover.queue_free()
		loaded_navigation_failed.emit(scene_id)
		return
	await get_tree().scene_changed
	_loaded_navigation_pending = false
	current_scene_id = scene_id
	EventBus.scene_changed.emit(from, scene_id)
	print("[Router] loaded:%s (%s)" % [scene_id, scene.resource_path])
	if is_instance_valid(entry_cover):
		await RenderingServer.frame_post_draw
		var cover := entry_cover.get_child(0) as TextureRect
		if bool(launch_options.get("reduceAnimations", false)):
			entry_cover.queue_free()
		else:
			var fade := create_tween()
			fade.tween_property(cover, "modulate:a", 0.0, 0.16)
			fade.finished.connect(entry_cover.queue_free)


func goto(scene_id: String) -> void:
	if current_scene_id != "boot" and scene_id in ["home", "games", "learn"]:
		if HostBridge.is_embedded():
			HostBridge.return_to_app("learn" if scene_id == "learn" else "games")
			return
	if not SCENES.has(scene_id):
		push_warning("[Router] unbekannte scene_id: %s" % scene_id)
		return
	var from: String = current_scene_id
	var path: String = SCENES[scene_id]
	print("[Router] goto:%s (%s)" % [scene_id, path])
	current_scene_id = scene_id
	# call_deferred damit der Wechsel sicher zwischen Frames passiert
	get_tree().call_deferred("change_scene_to_file", path)
	EventBus.scene_changed.emit(from, scene_id)
