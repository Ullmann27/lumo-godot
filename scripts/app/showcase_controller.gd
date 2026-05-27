## ShowcaseController - cyclet durch ein paar Lumo-Behaviors zum Vorzeigen.
##
## Headless-Run mit --quit-after 60 wird ein paar Behaviors loggen, in
## einem echten Run zeigt es die volle Sequenz.
extends Node3D

const BEHAVIOR_SEQUENCE: Array[String] = [
	"greet",
	"speak",
	"celebrate",
	"walk",
	"jump",
]
const BEHAVIOR_INTERVAL: float = 1.6

@export var lumo_path: NodePath = NodePath("LumoCharacter")

var _lumo: LumoCharacterController
var _step: int = 0


func _ready() -> void:
	_lumo = get_node_or_null(lumo_path) as LumoCharacterController
	await get_tree().process_frame
	EventBus.lumo_showcase_ready.emit()
	print("lumo_showcase_ready")
	if _lumo == null:
		push_warning("[Showcase] kein LumoCharacterController gefunden")
		return
	_start_cycle()


func _start_cycle() -> void:
	var tw: Tween = create_tween().set_loops()
	for b in BEHAVIOR_SEQUENCE:
		var behavior: String = b
		tw.tween_callback(func(): _lumo.play_behavior(behavior))
		tw.tween_interval(BEHAVIOR_INTERVAL)
