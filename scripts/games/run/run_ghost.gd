extends MeshInstance3D
## A non-interactive replay of this child's fastest recorded full run.

const SHAPES = preload("res://scripts/games/kart_world_meshes.gd")
const INTERVAL_MS: int = 250
const MAX_SAMPLES: int = 3600
const COLOUR := Color("85eaff")

var _best: Dictionary = {}
var _samples := PackedVector4Array()
var _recording: bool = false


func setup(best: Dictionary, start: Vector3, enabled: bool) -> void:
	_best = best if enabled else {}
	_recording = enabled
	if _recording:
		_samples.append(Vector4(start.x, start.y, start.z, 0.0))
	visible = false
	if _best.is_empty():
		return
	mesh = SHAPES.star()
	scale = Vector3.ONE * 0.85
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(COLOUR, 0.7)
	material_override = material


func sample(time_ms: int, feet: Vector3, progress: float) -> void:
	if not _recording or time_ms < _samples.size() * INTERVAL_MS:
		return
	if _samples.size() >= MAX_SAMPLES:
		_recording = false
		_samples.clear()
		return
	_samples.append(Vector4(feet.x, feet.y, feet.z, progress))


func stop() -> void:
	_recording = false
	_samples.clear()
	_best = {}
	visible = false


func recording(time_ms: int, feet: Vector3) -> PackedVector4Array:
	if not _recording or time_ms <= INTERVAL_MS:
		return PackedVector4Array()
	var samples := _samples.duplicate()
	if time_ms == (samples.size() - 1) * INTERVAL_MS:
		samples.remove_at(samples.size() - 1)
	samples.append(Vector4(feet.x, feet.y, feet.z, 1.0))
	return samples


func best_time_ms() -> int:
	return int(_best.get("time_ms", 0))


## Returns progress for the HUD. An inactive replay returns -1.
func show_at(time_ms: int, runner: Vector3, view: Camera3D) -> float:
	visible = false
	if _best.is_empty():
		return -1.0
	var samples: PackedVector4Array = _best.samples
	if time_ms >= best_time_ms():
		return 1.0
	var index: int = mini(floori(float(time_ms) / INTERVAL_MS), samples.size() - 2)
	var end_ms: int = best_time_ms() if index == samples.size() - 2 else (index + 1) * INTERVAL_MS
	var between: float = inverse_lerp(float(index * INTERVAL_MS), float(end_ms), float(time_ms))
	var first := Vector3(samples[index].x, samples[index].y, samples[index].z)
	var second := Vector3(samples[index + 1].x, samples[index + 1].y, samples[index + 1].z)
	# Checkpoint rescues and shortcuts can move instantly across an obstacle.
	if first.distance_squared_to(second) > 30.0 * 30.0:
		between = 0.0
	var feet: Vector3 = first.lerp(second, between)
	var distance: float = runner.distance_squared_to(feet)
	if distance > 2.5 * 2.5 and distance < 90.0 * 90.0:
		global_position = feet + Vector3.UP * 1.55
		global_basis = view.global_basis.scaled_local(Vector3.ONE * 0.85)
		visible = true
	return lerpf(samples[index].w, samples[index + 1].w, between)


static func valid_samples(samples: PackedVector4Array, time_ms: int) -> bool:
	if time_ms <= INTERVAL_MS or samples.size() != ceili(float(time_ms) / INTERVAL_MS) + 1:
		return false
	if samples.size() > MAX_SAMPLES + 1 or samples[0].w != 0.0 or samples[-1].w != 1.0:
		return false
	for point in samples:
		if not point.is_finite() or point.w < 0.0 or point.w > 1.0:
			return false
	return true
