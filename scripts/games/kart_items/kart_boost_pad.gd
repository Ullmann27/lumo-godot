@tool
class_name LumoKartBoostPad
extends Node3D
## Reusable boost pad (scenes/games/props/kart_boost_pad.tscn): a dark plate with
## glowing chevrons that point along local -Z. Place the origin on the road surface
## and align -Z with the driving direction.

const GROUP := "lumo_kart_triggers"
const KIND := "boost_pad"

@export var pad_size: Vector2 = Vector2(4.4, 2.6)
@export var boost_seconds: float = 1.0

var trigger_kind: String = KIND
var _chevrons: Array[MeshInstance3D] = []
var _age: float = 0.0


func _ready() -> void:
	add_to_group(GROUP)
	if get_child_count() > 0:
		return
	var plate := MeshInstance3D.new()
	plate.name = "Plate"
	var plate_mesh := BoxMesh.new()
	plate_mesh.size = Vector3(pad_size.x, 0.04, pad_size.y)
	plate.mesh = plate_mesh
	var plate_material := StandardMaterial3D.new()
	plate_material.albedo_color = Color("142a6e")
	plate_material.roughness = 0.6
	plate.material_override = plate_material
	plate.position.y = 0.02
	add_child(plate)
	var arm_mesh := BoxMesh.new()
	arm_mesh.size = Vector3(1.3, 0.04, 0.2)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color("4fe6ff")
	glow.emission_enabled = true
	glow.emission = Color("4fe6ff")
	glow.emission_energy_multiplier = 1.6
	for row in range(3):
		for side in [-1.0, 1.0]:
			var arm := MeshInstance3D.new()
			arm.mesh = arm_mesh
			arm.material_override = glow
			# Each arm runs from the outer tail back to the tip ahead (-Z).
			var tip := Vector3(0, 0.05, -0.38 + 0.85 - row * 0.75)
			var tail := Vector3(side * 0.72, 0.05, 0.42 + 0.85 - row * 0.75)
			arm.position = (tip + tail) * 0.5
			arm.rotation.y = atan2(-(tip.z - tail.z), tip.x - tail.x)
			add_child(arm)
			_chevrons.append(arm)


func contains(world_position: Vector3) -> bool:
	var local: Vector3 = to_local(world_position)
	return absf(local.x) <= pad_size.x * 0.5 and absf(local.z) <= pad_size.y * 0.5 and absf(local.y) < 1.5


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_age += delta
	for index in range(_chevrons.size()):
		var row: int = index / 2
		var glow: float = 0.6 + 0.4 * sin(_age * 8.0 - row * 1.4)
		_chevrons[index].scale = Vector3(1.0, 1.0, 0.8 + glow * 0.4)
