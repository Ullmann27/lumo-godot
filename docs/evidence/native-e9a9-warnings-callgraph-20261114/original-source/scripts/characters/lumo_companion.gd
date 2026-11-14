## LumoCompanion - Platzhalter aus Primitiven, bis lumo_fox.glb existiert.
##
## Idle-Bobbing (sanftes Y-Wippen) + Look-At-Camera. Bei Wechsel zum
## echten GLB: in scenes/characters/lumo_companion.tscn dieses Script
## entfernen und ein GLB via AssetLoader.get_model("lumo_fox") als Kind
## einsetzen - die Idle-Bob-Logik bleibt im Wrapper.
extends Node3D

@export var look_target_path: NodePath
@export var bob_amplitude: float = 0.06
@export var bob_speed: float = 1.5

var _base_y: float = 0.0
var _time: float = 0.0


func _ready() -> void:
	_base_y = position.y
	EventBus.companion_ready.emit()
	print("[Lumo] companion_ready")


func _process(delta: float) -> void:
	_time += delta * bob_speed
	position.y = _base_y + sin(_time) * bob_amplitude
	var look_target: Node3D = get_node_or_null(look_target_path) as Node3D
	if look_target != null:
		look_at(look_target.global_position, Vector3.UP)
