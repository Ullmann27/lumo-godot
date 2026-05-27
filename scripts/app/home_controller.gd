## HomeController - Hauptszene nach Intro.
##
## Instanziiert Lumo-Companion + 3 Portale + Sternenfeld. Verbindet
## EventBus.portal_selected fuer Tap-Logging.
extends Node3D

const COMPANION_SCENE: PackedScene = preload("res://scenes/characters/lumo_companion.tscn")
const PORTAL_SCENE: PackedScene = preload("res://scenes/hub/hub_portal.tscn")
const STAR_FIELD_SCENE: PackedScene = preload("res://scenes/hub/star_field.tscn")

const PORTAL_LAYOUT: Array = [
	{"type": "learn", "position": Vector3(-3.0, 0.6, 0.5)},
	{"type": "games", "position": Vector3(0.0, 1.6, -2.0)},
	{"type": "parent", "position": Vector3(3.0, 0.6, 0.5)},
]


func _ready() -> void:
	EventBus.portal_selected.connect(_on_portal_selected)
	_spawn_companion()
	_spawn_portals()
	_spawn_star_field()
	await get_tree().process_frame
	EventBus.scene_loaded.emit("home_3d")
	print("[Home] scene_loaded")


func _spawn_companion() -> void:
	var companion: Node3D = COMPANION_SCENE.instantiate() as Node3D
	companion.position = Vector3(0.0, 0.0, 0.0)
	add_child(companion)


func _spawn_portals() -> void:
	for entry in PORTAL_LAYOUT:
		var portal: Node3D = PORTAL_SCENE.instantiate() as Node3D
		portal.position = entry["position"]
		if portal.has_method("set_portal_type"):
			portal.call("set_portal_type", entry["type"])
		add_child(portal)


func _spawn_star_field() -> void:
	var stars: Node3D = STAR_FIELD_SCENE.instantiate() as Node3D
	stars.position = Vector3(0.0, 3.5, 0.0)
	add_child(stars)


func _on_portal_selected(portal_type: String) -> void:
	# Demo-Log fuer Heinz' Verifikation des Portal-Flows.
	print("portal_%s_selected" % portal_type)
