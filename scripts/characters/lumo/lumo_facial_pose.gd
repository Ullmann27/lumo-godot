extends RefCounted
## Authored original-surface morphs and additional Head-skinned physical lids.
## Speech is measured PCM amplitude at the real player's media position.
## No phoneme/viseme or independent eyeball anatomy is claimed.
const BODY_NAMES: Array[String] = ["LookLeft", "LookRight", "LookUp", "LookDown", "JawArticulation"]
const LID_NAMES: Array[String] = ["BlinkLeftQuarter", "BlinkLeftHalf", "BlinkLeftThreeQuarter", "BlinkLeftClose", "BlinkRightQuarter", "BlinkRightHalf", "BlinkRightThreeQuarter", "BlinkRightClose"]
const STALE_AUDIO_SECONDS: float = 0.35
var body: MeshInstance3D
var lids: MeshInstance3D
var skeleton: Skeleton3D
var head: int = -1
var body_ids: PackedInt32Array = PackedInt32Array()
var lid_ids: PackedInt32Array = PackedInt32Array()
var _body_values: PackedFloat32Array = PackedFloat32Array()
var has_target: bool = false
var target: Vector3 = Vector3.ZERO
var gaze: Vector2 = Vector2.ZERO
var jaw: float = 0.0
var blink: float = 0.0
var _clock: float = 0.0
var _blink_start: float = 1.8
var _blink_cycle: int = 0
var _speech_age: float = 1000.0
var _speech_position: float = -1.0
var _speech_envelope: float = 0.0
var _speaking: bool = false


func bind(visual: Node3D, source: Skeleton3D) -> bool:
	if not is_instance_valid(source):
		return false
	skeleton = source
	head = source.find_bone("Head")
	for node in visual.find_children("*", "MeshInstance3D", true, false):
		var candidate := node as MeshInstance3D
		if candidate.mesh == null:
			continue
		var names: Array[String] = []
		for index in range(candidate.mesh.get_blend_shape_count()):
			names.append(str(candidate.mesh.get_blend_shape_name(index)))
		if names.has("JawArticulation"):
			body = candidate
			for name in BODY_NAMES:
				if not names.has(name):
					return false
				body_ids.append(names.find(name))
		if names.has("BlinkLeftClose"):
			lids = candidate
			for name in LID_NAMES:
				if not names.has(name):
					return false
				lid_ids.append(names.find(name))
	if head < 0 or not is_instance_valid(body) or not is_instance_valid(lids):
		return false
	_body_values.resize(body_ids.size())
	# Force each first zero assignment: Godot must register the imported
	# instance blend parameters before subsequent unchanged writes are skipped.
	_body_values.fill(-1.0)
	reset()
	return true


func set_target(world_position: Vector3) -> void:
	if world_position.is_finite():
		target = world_position
		has_target = true


func speech_sample(media_seconds: float, envelope: float, speaking: bool) -> void:
	if not speaking or not is_finite(media_seconds) or media_seconds < 0.0 or not is_finite(envelope):
		stop_speech()
		return
	# Repeated stale transport snapshots cannot keep a frozen player talking.
	if not _speaking or not is_equal_approx(media_seconds, _speech_position):
		_speech_age = 0.0
	_speaking = true
	_speech_position = media_seconds
	_speech_envelope = clampf(envelope, 0.0, 1.0)


func stop_speech() -> void:
	_speaking = false
	_speech_age = 1000.0
	_speech_position = -1.0
	_speech_envelope = 0.0
	jaw = 0.0
	if is_instance_valid(body) and body_ids.size() == BODY_NAMES.size():
		_set_body(4, 0.0)


func reset() -> void:
	stop_speech()
	gaze = Vector2.ZERO
	blink = 0.0
	_clock = 0.0
	_blink_start = 1.8
	_blink_cycle = 0
	if is_instance_valid(body):
		for index in range(body_ids.size()):
			_set_body(index, 0.0)
	if is_instance_valid(lids):
		for index in range(lid_ids.size()):
			_set_lid(index, 0.0)
		lids.visible = false


func advance(delta: float) -> void:
	if not is_instance_valid(body) or not is_instance_valid(lids) or not is_instance_valid(skeleton):
		return
	if not is_finite(delta) or delta <= 0.0:
		return
	_speech_age += minf(delta, 1.0)
	var dt := minf(delta, 0.10)
	_clock += dt
	var phase := _clock - _blink_start
	blink = 0.0
	if phase >= 0.0 and phase < 0.18:
		blink = clampf(phase / 0.07, 0.0, 1.0) if phase < 0.07 else clampf((0.18 - phase) / 0.11, 0.0, 1.0)
	elif phase >= 0.18:
		_blink_cycle += 1
		_blink_start = _clock + 3.2 + float(_blink_cycle % 3) * 0.35
	var desired := Vector2.ZERO
	if has_target:
		var pose := skeleton.get_bone_global_pose(head)
		# Conjugate the animated head through its measured rest basis so +Z
		# is the original face forward, not an arbitrary imported bone axis.
		var frame := (
			skeleton.global_basis * pose.basis * skeleton.get_bone_global_rest(head).basis.inverse()
		).orthonormalized()
		var direction := frame.inverse() * (target - skeleton.to_global(pose.origin))
		var horizontal := Vector2(direction.x, direction.z).length()
		if direction.z > 0.05 and horizontal > 0.05:
			desired = Vector2(
				clampf(atan2(direction.x, direction.z) / 0.32, -1.0, 1.0),
				clampf(atan2(direction.y, horizontal) / 0.24, -1.0, 1.0)
			)
	gaze = gaze.lerp(desired, 1.0 - exp(-10.0 * dt))
	# Return the painted eye surface under its measured lids as they close.
	# This is a restrained surface morph, not an independently rotating eyeball.
	var visible_gaze := gaze * (1.0 - smoothstep(0.0, 0.30, blink))
	_set_body(0, maxf(0.0, -visible_gaze.x))
	_set_body(1, maxf(0.0, visible_gaze.x))
	_set_body(2, maxf(0.0, visible_gaze.y))
	_set_body(3, maxf(0.0, -visible_gaze.y))
	var desired_jaw := _speech_envelope if _speaking and _speech_age < STALE_AUDIO_SECONDS else 0.0
	jaw = lerpf(jaw, desired_jaw, 1.0 - exp(-25.0 * dt))
	if jaw < 0.0001:
		jaw = 0.0
	_set_body(4, jaw)
	# Keep the full small imported lid mix synchronized. Skipping unchanged
	# lid slots exposed a reproduced Godot 4.6.3 dummy-material teardown error.
	for index in range(lid_ids.size()):
		var stage := float(index % 4 + 1)
		_set_lid(index, maxf(0.0, 1.0 - absf(blink * 4.0 - stage)))
	lids.visible = blink > 0.002


func _set_body(index: int, value: float) -> void:
	# Most actors are silent and are not looking at a teacher target. Avoid
	# repeatedly uploading unchanged mesh weights on every animation tick.
	if not is_equal_approx(_body_values[index], value):
		_body_values[index] = value
		body.set_blend_shape_value(body_ids[index], value)


func _set_lid(index: int, value: float) -> void:
	lids.set_blend_shape_value(lid_ids[index], value)
