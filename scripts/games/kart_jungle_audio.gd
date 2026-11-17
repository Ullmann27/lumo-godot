extends Node3D
## Original environmental loops, attached to measured positions in the new world.
## Distant emitters are virtualized; the listener usually activates two or three.
## Existing Kart effects-volume, mute, application-focus and pause settings apply.

const PATH := "res://assets/audio/kart/jungle_emerald_3600/%s.ogg"
const SOURCES: Array[Dictionary] = [
	{"kind": "jungle", "metres": 150.0, "side": 27.0, "radius": 220.0, "db": -28.0},
	{"kind": "jungle", "metres": 450.0, "side": -25.0, "radius": 220.0, "db": -28.0},
	{"kind": "water", "metres": 750.0, "side": 26.0, "radius": 210.0, "db": -24.0},
	{"kind": "water", "metres": 1040.0, "side": 24.0, "radius": 180.0, "db": -20.0},
	{"kind": "water", "metres": 1350.0, "side": 12.0, "radius": 180.0, "db": -29.0},
	{"kind": "jungle", "metres": 1650.0, "side": -25.0, "radius": 220.0, "db": -29.0},
	{"kind": "bridge", "metres": 1950.0, "side": 9.0, "radius": 180.0, "db": -30.0},
	{"kind": "jungle", "metres": 2250.0, "side": 30.0, "radius": 210.0, "db": -30.0},
	{"kind": "jungle", "metres": 2550.0, "side": -24.0, "radius": 220.0, "db": -28.0},
	{"kind": "water", "metres": 2850.0, "side": -22.0, "radius": 215.0, "db": -23.0},
	{"kind": "rain", "metres": 3150.0, "side": 15.0, "radius": 185.0, "db": -26.0},
	{"kind": "water", "metres": 3450.0, "side": 32.0, "radius": 215.0, "db": -27.0}
]

var emitters: Array[AudioStreamPlayer3D] = []
var _blocked: bool = false
var _gain: float = 1.0
var _elapsed: float = 0.0


func configure(world: Node3D) -> void:
	name = "DschungelherzSpatialAudio"
	for entry in SOURCES:
		var stream := load(PATH % str(entry.kind)) as AudioStreamOggVorbis
		if stream == null:
			push_error("[Dschungelherz] Missing original ambience: " + str(entry.kind))
			continue
		stream.loop = true
		var emitter := AudioStreamPlayer3D.new()
		emitter.name = "%s_%04d" % [str(entry.kind), int(entry.metres)]
		emitter.stream = stream
		emitter.bus = "Master"
		emitter.unit_size = 35.0
		emitter.max_distance = float(entry.radius)
		emitter.max_db = float(entry.db)
		emitter.volume_db = float(entry.db)
		emitter.attenuation_filter_cutoff_hz = 11500.0
		emitter.position = world.position_at(float(entry.metres), float(entry.side)) + Vector3.UP * 4.0
		emitter.set_meta("base_db", float(entry.db))
		add_child(emitter)
		emitters.append(emitter)


func set_audio_state(blocked: bool, effects_gain: float) -> void:
	_blocked = blocked
	_gain = clampf(effects_gain, 0.0, 1.0)
	for emitter in emitters:
		emitter.stream_paused = _blocked or _gain <= 0.01
		emitter.volume_db = -80.0 if _gain <= 0.01 else float(emitter.get_meta("base_db")) + linear_to_db(_gain)


func advance(delta: float, listener: Vector3) -> void:
	if _blocked:
		return
	_elapsed += delta
	for emitter in emitters:
		var audible := emitter.global_position.distance_to(listener) < emitter.max_distance - 1.0
		if audible and not emitter.playing and _gain > 0.01:
			emitter.play(fposmod(_elapsed, emitter.stream.get_length()))
		elif not audible and emitter.playing:
			emitter.stop()


func active_voice_count() -> int:
	var count := 0
	for emitter in emitters:
		if emitter.playing and not emitter.stream_paused:
			count += 1
	return count


func _exit_tree() -> void:
	for emitter in emitters:
		emitter.stop()
		emitter.stream = null
