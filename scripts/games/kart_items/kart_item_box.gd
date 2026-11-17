@tool
class_name LumoKartItemBox
extends Node3D
## Reusable Lumo item box (scenes/games/props/kart_item_box.tscn). Place it on any
## track; the race finds it through the "lumo_kart_triggers" group. Driving through
## gives a weighted item (see kart_items.json) and pops the prism with sparkles.

const PRISM = preload("res://scripts/games/kart_mystery_prism.gd")
const GROUP := "lumo_kart_triggers"
const KIND := "item_box"

@export var pickup_radius: float = 2.0
## Seconds until the box is back for everybody. The built-in race keeps its
## existing once-per-lap rule for the player; rivals and editors use this timer.
@export var respawn_seconds: float = 4.0
@export var spin_speed: float = 1.35

var trigger_kind: String = KIND
var cooldown: float = 0.0
## The built-in race animates, hides and counts its own boxes (once per lap).
## Free-standing boxes placed by track scenes animate and respawn themselves.
var managed: bool = false
var _pop: float = 0.0
var _age: float = 0.0
var _base_scale := Vector3.ONE


func _ready() -> void:
	add_to_group(GROUP)
	# The prism (core + gold edges) is built directly on this node: two draw surfaces.
	if get_node_or_null("MysteryPrismCore") == null:
		PRISM.build(self)
	_base_scale = scale


## True when a kart centre at `world_position` touches the box.
func contains(world_position: Vector3) -> bool:
	return is_ready() and global_position.distance_to(world_position) <= pickup_radius


func is_ready() -> bool:
	return cooldown <= 0.0


## Called by the race when someone collects it: squash-and-burst, then respawn.
func pop(respawn: bool = true) -> void:
	_pop = 1.0
	if respawn:
		cooldown = respawn_seconds


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or managed:
		return
	_age += delta
	cooldown = maxf(0.0, cooldown - delta)
	_pop = maxf(0.0, _pop - delta * 3.5)
	visible = cooldown <= 0.0 or _pop > 0.0
	scale = _base_scale * (1.0 + _pop * 0.6)
	rotation.y += delta * spin_speed
