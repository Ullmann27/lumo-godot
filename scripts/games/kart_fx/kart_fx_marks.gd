extends MultiMeshInstance3D
## Marks that stay behind: brake and drift rubber, sand grooves, snow tracks and
## scrape streaks on the rail. Each stream (one per tyre) is one continuous band:
## every piece starts exactly on the previous piece's end edge, so the band bends
## cleanly through curves without overlaps (no "ladder"). One draw call; fading
## runs in the shader against the race clock, the CPU only writes new pieces.

const HIDDEN := Transform3D(Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), Vector3.ZERO)
const MIN_STEP := 0.12
const MAX_STEP := 3.0

var capacity: int = 0
var fx_time: float = 0.0
var segments_total: int = 0
var _cursor: int = 0
var _death := PackedFloat32Array()
## stream -> {"at": last centre, "half": last half-width vector, "v": length so far}
var _last := {}
var _last_death: float = -1.0
var _material: ShaderMaterial
## CPU copy of every piece's start, end and half-width vectors (tests read it;
## the headless renderer keeps no MultiMesh data).
var piece_start := PackedVector3Array()
var piece_end := PackedVector3Array()
var piece_half_start := PackedVector3Array()
var piece_half_end := PackedVector3Array()


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
	piece_start.resize(capacity)
	piece_end.resize(capacity)
	piece_half_start.resize(capacity)
	piece_half_end.resize(capacity)
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
## normal (road up, or the rail's face); the band lies in that surface.
func stroke(
	stream: String, at: Vector3, normal: Vector3, width: float, color: Color, life: float, kind: int
) -> bool:
	if not _last.has(stream):
		_last[stream] = {"at": at, "half": Vector3.ZERO, "v": 0.0}
		return false
	var state: Dictionary = _last[stream]
	var previous: Vector3 = state.at
	var step := at - previous
	var length := step.length()
	if length < MIN_STEP:
		return false
	if length > MAX_STEP:
		_last[stream] = {"at": at, "half": Vector3.ZERO, "v": 0.0}
		return false
	var direction := step / length
	var across := normal.normalized().cross(direction)
	if across.length_squared() < 0.25:
		_last[stream] = {"at": at, "half": Vector3.ZERO, "v": 0.0}
		return false
	var half_end := across.normalized() * width * 0.5
	var half_start: Vector3 = state.half
	if half_start == Vector3.ZERO:
		half_start = half_end
	var v: float = float(state.v)
	var slot := _cursor
	_cursor = (_cursor + 1) % capacity
	multimesh.set_instance_transform(slot, Transform3D(Basis(step, half_start, half_end), previous))
	multimesh.set_instance_color(slot, color)
	multimesh.set_instance_custom_data(slot, Color(fx_time, life, float(kind), v))
	_death[slot] = fx_time + life
	piece_start[slot] = previous
	piece_end[slot] = at
	piece_half_start[slot] = half_start
	piece_half_end[slot] = half_end
	_last_death = maxf(_last_death, fx_time + life)
	_last[stream] = {"at": at, "half": half_end, "v": v + length}
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
