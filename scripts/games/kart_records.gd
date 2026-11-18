extends RefCounted
## Best-time ghosts use the same track, kart and difficulty. Corrupt saves are ignored.
const FILE: String = "user://kart_holographic_records.cfg"
const MAX_FRAMES: int = 18000
var config := ConfigFile.new()
var recording: Array = []
var replay: Array = []
var replay_index: int = 0
var sample_clock: float = 0.0
var record_key: String = ""
var previous_best: float = 0.0
var earned_unlocks: Array = []

func _init() -> void:
	config.load(FILE)
	earned_unlocks = config.get_value("profile", "unlocks", [])

func update_unlocks(stars: int, drivers: Array[Dictionary], karts: Array[Dictionary]) -> void:
	for item in drivers + karts:
		if stars >= int(item.get("unlock", 0)) and not earned_unlocks.has(str(item.id)):
			earned_unlocks.append(str(item.id))
	config.set_value("profile", "unlocks", earned_unlocks)
	_save()

func begin(track: String, kart: String, difficulty: String) -> void:
	record_key = "%s_%s_%s_v3" % [track, kart, difficulty]
	previous_best = float(config.get_value("times", record_key, 0.0))
	recording.clear()
	replay.clear()
	replay_index = 0
	sample_clock = 0
	var frames: Variant = config.get_value("ghosts", record_key, [])
	if frames is Array and frames.size() <= MAX_FRAMES:
		var last_time: float = -1.0
		for frame in frames:
			if not frame is Array or frame.size() != 5 or not frame[1] is Vector3:
				replay.clear()
				break
			var t: float = float(frame[0])
			if not is_finite(t) or t <= last_time:
				replay.clear()
				break
			replay.append(frame)
			last_time = t

func capture(delta: float, elapsed: float, position: Vector3, rotation: Vector3, steer: float, speed: float) -> void:
	sample_clock += delta
	if recording.size() >= MAX_FRAMES:
		return
	if sample_clock >= 0.08 or recording.is_empty():
		sample_clock = 0
		recording.append([elapsed, position, rotation, steer, speed])

func sample(time: float) -> Dictionary:
	if replay.size() < 2 or time > float(replay[-1][0]):
		return {}
	while replay_index < replay.size() - 2 and float(replay[replay_index + 1][0]) < time:
		replay_index += 1
	var a: Array = replay[replay_index]
	var b: Array = replay[replay_index + 1]
	var blend: float = clampf((time - float(a[0])) / maxf(0.001, float(b[0]) - float(a[0])), 0, 1)
	var rotation_a: Vector3 = a[2]
	var rotation_b: Vector3 = b[2]
	return {
		"position": (a[1] as Vector3).lerp(b[1], blend),
		"rotation": Vector3(lerp_angle(rotation_a.x, rotation_b.x, blend), lerp_angle(rotation_a.y, rotation_b.y, blend), lerp_angle(rotation_a.z, rotation_b.z, blend)),
		"steer": lerpf(float(a[3]), float(b[3]), blend),
		"speed": lerpf(float(a[4]), float(b[4]), blend)
	}

func finish(elapsed: float, valid: bool) -> bool:
	if not valid or recording.size() < 2 or elapsed <= 0 or not is_finite(elapsed):
		return false
	if previous_best > 0 and elapsed >= previous_best:
		return false
	config.set_value("times", record_key, elapsed)
	config.set_value("ghosts", record_key, recording)
	return _save()

func _save() -> bool:
	if config.save(FILE + ".tmp") != OK:
		return false
	return DirAccess.rename_absolute(FILE + ".tmp", FILE) == OK
