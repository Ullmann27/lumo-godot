extends MultiMeshInstance3D
## One draw call for a whole family of particles. Each particle is written once,
## when it is born; its flight (drag, gravity, growth, fading) is evaluated in the
## shader from that spawn data, so the CPU does no per-frame particle work.
## The clock (fx_time) is the race clock: paused races freeze every particle.

const HIDDEN := Transform3D(Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), Vector3.ZERO)
## The last slots are pinned (brake-lamp glow etc.) and never evicted by bursts.
const PINNED := 4

var capacity: int = 0
var fx_time: float = 0.0
var spawned_total: int = 0
var _cursor: int = 0
var _death := PackedFloat32Array()
var _birth := PackedFloat32Array()
var _last_death: float = -1.0
var _material: ShaderMaterial
## Spark layout: CUSTOM.z packs cooling (x2) + white core, CUSTOM.w carries an
## optional ground height for one analytic bounce (+10000 marks "bounce on").
var spark_layout: bool = false
const NO_BOUNCE := -1.0e9
## Data of the newest particle (tests; headless keeps no MultiMesh data).
var last_data := Color()
var bounced_total: int = 0


func setup(label: String, shader: Shader, count: int) -> void:
	name = label
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_material = ShaderMaterial.new()
	_material.shader = shader
	material_override = _material
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.mesh = quad
	resize(count)


func resize(count: int) -> void:
	capacity = maxi(PINNED + 8, count)
	multimesh.instance_count = capacity
	_death.resize(capacity)
	_birth.resize(capacity)
	clear()


func clear() -> void:
	_death.fill(-1.0)
	_birth.fill(0.0)
	for index in range(capacity):
		multimesh.set_instance_transform(index, HIDDEN)
	_cursor = 0
	_last_death = -1.0
	visible = false


func advance(delta: float, focus: Vector3) -> void:
	fx_time += maxf(0.0, delta)
	_material.set_shader_parameter("fx_time", fx_time)
	visible = fx_time < _last_death
	if visible:
		multimesh.custom_aabb = AABB(focus - Vector3.ONE * 70.0, Vector3.ONE * 140.0)


func set_parameter(key: StringName, value: Variant) -> void:
	_material.set_shader_parameter(key, value)


## [param data] = (drag, spin seed 0-1, cooling | spin speed, white core | kind).
func spawn(
	at: Vector3,
	velocity: Vector3,
	size_start: float,
	size_end: float,
	streak: float,
	life: float,
	gravity: float,
	color: Color,
	data: Color,
	bounce_y: float = NO_BOUNCE
) -> void:
	if spark_layout:
		var cooling := 2.0 if data.b > 0.5 else 0.0
		data = Color(data.r, data.g, cooling + clampf(data.a, 0.0, 1.0),
			bounce_y + 10000.0 if bounce_y > NO_BOUNCE else 0.0)
		if bounce_y > NO_BOUNCE:
			bounced_total += 1
	last_data = data
	var slot := _cursor
	_cursor = (_cursor + 1) % (capacity - PINNED)
	_write(slot, at, velocity, size_start, size_end, streak, life, gravity, color, data)
	spawned_total += 1


func pin(index: int, at: Vector3, size: float, life: float, color: Color) -> void:
	_write(capacity - PINNED + clampi(index, 0, PINNED - 1), at, Vector3.ZERO, size, size, 0.0, life,
		0.0, color, Color(1.0, 0.0, 0.6 if spark_layout else 0.0, 0.0 if spark_layout else 0.6))


func _write(
	slot: int,
	at: Vector3,
	velocity: Vector3,
	size_start: float,
	size_end: float,
	streak: float,
	life: float,
	gravity: float,
	color: Color,
	data: Color
) -> void:
	var basis := Basis(velocity, Vector3(size_start, size_end, streak), Vector3(fx_time, life, gravity))
	multimesh.set_instance_transform(slot, Transform3D(basis, at))
	multimesh.set_instance_color(slot, color)
	multimesh.set_instance_custom_data(slot, data)
	_birth[slot] = fx_time
	_death[slot] = fx_time + life
	_last_death = maxf(_last_death, fx_time + life)
	visible = true


func live_count() -> int:
	var count := 0
	for index in range(capacity):
		if _death[index] > fx_time and _birth[index] <= fx_time + 0.0005:
			count += 1
	return count


func newest_birth() -> float:
	var newest := -1.0
	for index in range(capacity):
		if _death[index] > 0.0:
			newest = maxf(newest, _birth[index])
	return newest
