class_name LumoKartShieldDome
extends MeshInstance3D
## Visible Sternenschild around a kart: one ellipsoid, one shader draw call.
## raise() sweeps it up from the road, impact() sends a ripple from the hit point,
## the last 1.5 s breathe slowly (no blinking) before it sinks away again.

const SHADER = preload("res://assets/shaders/kart_shield_dome.gdshader")
const RAISE_SECONDS: float = 0.42
const FADE_SECONDS: float = 0.55
const SIZE := Vector3(2.35, 2.6, 3.0)

var reduced_motion: bool = false
var remaining: float = 0.0
var reveal: float = 0.0
var hit_age: float = 9.0
var impacts: int = 0
var _material: ShaderMaterial


func _init() -> void:
	name = "ShieldDome"
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 28
	sphere.rings = 14
	mesh = sphere
	scale = SIZE
	position = Vector3(0.0, 0.72, 0.05)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("reveal", 0.0)
	_material.set_shader_parameter("time_offset", randf() * 10.0)
	material_override = _material
	visible = false


func set_tint(color: Color) -> void:
	_material.set_shader_parameter("tint", color)
	_material.set_shader_parameter("rim_tint", color.lightened(0.55))


## Show the shield for `seconds`; refreshing an active dome keeps it up.
func raise(seconds: float) -> void:
	remaining = maxf(remaining, seconds)
	visible = true


func drop() -> void:
	remaining = 0.0


## A rocket bounced off: ripple from the world-space contact point.
func impact(world_point: Vector3) -> void:
	impacts += 1
	hit_age = 0.0
	var local: Vector3 = to_local(world_point)
	if local.length_squared() < 0.0001:
		local = Vector3.FORWARD
	_material.set_shader_parameter("hit_direction", local.normalized())


func is_active() -> bool:
	return visible and reveal > 0.01


## `seconds_left` mirrors the race's shield clock so save/restore stays exact.
func advance(delta: float, seconds_left: float) -> void:
	remaining = seconds_left
	var target: float = 1.0 if remaining > 0.0 else 0.0
	var rate: float = 1.0 / (RAISE_SECONDS if target > reveal else FADE_SECONDS)
	reveal = target if reduced_motion else move_toward(reveal, target, delta * rate)
	hit_age = minf(9.0, hit_age + delta)
	visible = reveal > 0.001
	if not visible:
		return
	var ending: float = clampf(1.0 - remaining / 1.5, 0.0, 1.0) if remaining > 0.0 else 0.0
	_material.set_shader_parameter("reveal", reveal)
	_material.set_shader_parameter("hit_age", hit_age)
	# Calm in reduced motion; a slow, stronger breathing tells "running out" (0.7 Hz, no flashing).
	_material.set_shader_parameter("pulse_amount", 0.0 if reduced_motion else 0.22 + ending * 0.5)
	_material.set_shader_parameter("strength", 1.0 - ending * 0.35)
	var bump: float = 0.0 if reduced_motion else exp(-hit_age * 9.0) * 0.06
	scale = SIZE * (0.92 + 0.08 * reveal + bump)
