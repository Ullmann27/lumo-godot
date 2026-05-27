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
	"learn": "res://scenes/games/learn_card.tscn",
	"games": "res://scenes/games/star_collect.tscn",
	"parent": "res://scenes/games/parent_settings.tscn",
}

var current_scene_id: String = "boot"


func goto(scene_id: String) -> void:
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
