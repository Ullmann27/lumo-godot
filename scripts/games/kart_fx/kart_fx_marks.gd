extends MultiMeshInstance3D
## Marks that stay behind: brake and drift rubber, sand grooves, snow tracks and
## scrape streaks on the rail. Continuous strokes per stream (one per tyre),
## one flat ribbon segment per instance, all in one draw call. Fading is done in
## the shader against the race clock, so the CPU only writes new segments.

const HIDDEN := Transform3D(Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), Vector3.ZERO)
const MIN_STEP := 0.09
const MAX_STEP := 3.0

var capacity: int = 0
var fx_time: float = 0.0
var segments_total: int = 0
var _cursor: int = 0
var _death := PackedFloat32Array()
var _last := {}
var _last_death: float = -1.0
var _material: ShaderMaterial


func setup(shader: Shader, count: int) -> void:
	name = "KartFxMarks"
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_material = ShaderMaterial.new()
	_material.shader = shader
	# Draw marks before the glowing particles that pass over them.
	_material.render_priority = -1
	material_override = _material
	var quad := PlaneMesh.new()
	quad.size = Vector2.ONE
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.mesh = quad
	resize(count)


func resize(count: int) -> void:
	capacity = maxi(16, count)
	multimesh.instance_count = capacity
	_death.resize(capacity)
	clear()


func clear() -> void:
	_death.fill(-1.0)
	for index in range(capacity):
		multimesh.set_instance_transform(index, HIDDEN)
	_last.clear()
	_cursor = 0
	_last_death = -1.0
	visible = false


func advance(delta: float, focus: Vector3) -> void:
	fx_time += maxf(0.0, delta)
	_material.set_shader_parameter("fx_time", fx_time)
	visible = fx_time < _last_death
	if visible:
		multimesh.custom_aabb = AABB(focus - Vector3.ONE * 90.0, Vector3.ONE * 180.0)


## Continue stream [param stream] to [param at]. [param normal] is the surface
## normal (road up, or the rail's face); the ribbon lies in that surface.
func stroke(
	stream: String, at: Vector3, normal: Vector3, width: float, color: Color, life: float, kind: int
) -> bool:
	if not _last.has(stream):
		_last[stream] = at
		return false
	var previous: Vector3 = _last[stream]
	var step := at - previous
	var length := step.length()
	if length < MIN_STEP:
		return false
	_last[stream] = at
	if length > MAX_STEP:
		return false
	var z := step / length
	var x := normal.normalized().cross(z)
	if x.length_squared() < 0.25:
		return false
	x = x.normalized()
	var y := z.cross(x).normalized()
	# PlaneMesh lies in XZ: X = across (width), Z = along (length).
	var basis := Basis(x * width, y, z * (length + width * 0.15))
	var slot := _cursor
	_cursor = (_cursor + 1) % capacity
	multimesh.set_instance_transform(slot, Transform3D(basis, (at + previous) * 0.5))
	multimesh.set_instance_color(slot, color)
	multimesh.set_instance_custom_data(slot, Color(fx_time, life, 1.0, float(kind)))
	_death[slot] = fx_time + life
	_last_death = maxf(_last_death, fx_time + life)
	segments_total += 1
	visible = true
	return true


func lift(stream: String) -> void:
	_last.erase(stream)


func lift_all() -> void:
	_last.clear()


func live_count() -> int:
	var count := 0
	for value in _death:
		if value > fx_time:
			count += 1
	return count
