@tool
class_name LumoKartBoostRing
extends Node3D
## Reusable upright boost ring (scenes/games/props/kart_boost_ring.tscn). Driving
## through the ring along its local -Z gives a turbo, a screen flash, a camera push
## and a sparkle burst. The ring stands on its origin; place the origin on the road.

const GROUP := "lumo_kart_triggers"
const KIND := "boost_ring"

@export var ring_radius: float = 2.6
@export var boost_seconds: float = 1.4
@export var ring_color: Color = Color("66f7e8")

var trigger_kind: String = KIND
var _pulse: float = 0.0
var _age: float = 0.0
var _ring: MeshInstance3D
var _halo: MeshInstance3D


func _ready() -> void:
	add_to_group(GROUP)
	if _ring == null:
		_ring = _torus(ring_radius - 0.16, ring_radius + 0.16, ring_color, 2.2, 1.0)
		_ring.name = "RingCore"
		_halo = _torus(ring_radius - 0.42, ring_radius + 0.42, ring_color.lightened(0.3), 0.8, 0.28)
		_halo.name = "RingHalo"


func _torus(inner: float, outer: float, color: Color, energy: float, alpha: float) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 40
	mesh.ring_segments = 10
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(color, alpha)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	if alpha < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Torus lies in XZ: stand it up so karts drive through along -Z.
	node.rotation.x = PI / 2
	node.position.y = ring_radius
	add_child(node)
	return node


## True when the segment previous -> current crosses the ring disc front-to-back.
func crossed(previous: Vector3, current: Vector3) -> bool:
	var a: Vector3 = to_local(previous)
	var b: Vector3 = to_local(current)
	if not (a.z > 0.0 and b.z <= 0.0):
		return false
	var t: float = a.z / maxf(0.0001, a.z - b.z)
	var hit: Vector3 = a.lerp(b, t)
	return Vector2(hit.x, hit.y - ring_radius).length() <= ring_radius


func celebrate() -> void:
	_pulse = 1.0


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_age += delta
	_pulse = maxf(0.0, _pulse - delta * 2.5)
	if _ring:
		_ring.scale = Vector3.ONE * (1.0 + _pulse * 0.18)
	if _halo:
		_halo.scale = Vector3.ONE * (1.0 + _pulse * 0.45 + sin(_age * 3.0) * 0.03)
