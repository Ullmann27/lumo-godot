extends Node
## Music and sounds of Lumo Lauf. Dschungelherz has its own procedural score
## (tools/art/generate_run_jungle_audio.py): a calm and an action layer that play
## in sync and are cross-faded by section, a chase motif, a finish fanfare and
## its own effects (star series climb a scale). The other courses play their
## Lumo Kart world music. Volumes follow the existing settings: the music and
## effects sliders of Lumo Kart and the app-wide mute of AudioManager.

const RUN_PATH: String = "res://assets/audio/run/%s.ogg"
const KART_PATH: String = "res://assets/audio/kart/%s.ogg"
const PREFERENCES: String = "user://kart_preferences.cfg"
const MUSIC_DB: float = -14.0
const EFFECT_DB: float = -7.0
const QUIET_DB: float = -60.0
const EFFECTS: Array[String] = [
	"jump", "land", "dash", "letter", "barrel_in", "barrel_shoot", "vine", "checkpoint", "stomp", "hit",
	"respawn", "gate", "cart", "star_0", "star_1", "star_2", "star_3", "star_4", "star_5", "star_6", "star_7",
]

var music_volume: float = 1.0
var effects_volume: float = 1.0
var adventure: bool = false
var intensity: float = 0.0
var chasing: bool = false
var music: AudioStreamPlayer
var chase: AudioStreamPlayer
var stinger_player: AudioStreamPlayer
var layers: AudioStreamSynchronized
var _effects: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _next: int = 0
var _chase_mix: float = 0.0
var _finished: bool = false


func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(PREFERENCES) == OK:
		music_volume = clampf(float(config.get_value("race", "music_volume", 1.0)), 0.0, 1.0)
		effects_volume = clampf(float(config.get_value("race", "effects_volume", 1.0)), 0.0, 1.0)
	music = _player("Music")
	chase = _player("Chase")
	stinger_player = _player("Stinger")
	for index in range(6):
		_pool.append(_player("Effect%d" % index))


func _player(label: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = label
	player.bus = "Master"
	add_child(player)
	return player


func _load(path: String, loop: bool) -> AudioStreamOggVorbis:
	if not ResourceLoader.exists(path):
		return null
	var stream := load(path) as AudioStreamOggVorbis
	if stream != null:
		stream.loop = loop
	return stream


func muted() -> bool:
	return AudioManager.is_muted()


func music_db() -> float:
	return QUIET_DB if music_volume <= 0.01 else MUSIC_DB + linear_to_db(music_volume)


func effect_db() -> float:
	return QUIET_DB if effects_volume <= 0.01 else EFFECT_DB + linear_to_db(effects_volume)


func start_course(course_id: String, is_adventure: bool) -> void:
	adventure = is_adventure
	_finished = false
	chasing = false
	_chase_mix = 0.0
	music.stop()
	chase.stop()
	if adventure:
		var calm: AudioStreamOggVorbis = _load(RUN_PATH % "jungle_calm", true)
		var action: AudioStreamOggVorbis = _load(RUN_PATH % "jungle_action", true)
		if calm != null and action != null:
			layers = AudioStreamSynchronized.new()
			layers.stream_count = 2
			layers.set_sync_stream(0, calm)
			layers.set_sync_stream(1, action)
			layers.set_sync_stream_volume(0, 0.0)
			layers.set_sync_stream_volume(1, QUIET_DB)
			music.stream = layers
		chase.stream = _load(RUN_PATH % "jungle_chase", true)
		for name in EFFECTS:
			var stream: AudioStreamOggVorbis = _load(RUN_PATH % ("sfx_" + name), false)
			if stream != null:
				_effects[name] = stream
		for name in ["finish", "bonus"]:
			var stream: AudioStreamOggVorbis = _load(RUN_PATH % name, false)
			if stream != null:
				_effects[name] = stream
	else:
		layers = null
		var track: String = {"sonnenhafen": "sonnenhafen", "zauberwald": "zauberwald"}.get(course_id, "")
		music.stream = _load(KART_PATH % track, true) if not track.is_empty() else null
	music.volume_db = music_db()
	if music.stream != null and not muted():
		music.play()


func has_effects() -> bool:
	return not _effects.is_empty()


func effect(name: String, pitch: float = 1.0) -> void:
	if muted() or not _effects.has(name):
		return
	var player: AudioStreamPlayer = _pool[_next % _pool.size()]
	_next += 1
	player.stream = _effects[name]
	player.pitch_scale = pitch
	player.volume_db = effect_db() - (3.0 if name.begins_with("star") else 0.0)
	player.play()


## Each further star of a quick series rings one step higher.
func play_star(combo: int) -> void:
	effect("star_%d" % clampi(combo, 0, 7))


func stinger(name: String) -> void:
	if muted() or not _effects.has(name):
		return
	stinger_player.stream = _effects[name]
	stinger_player.volume_db = effect_db()
	stinger_player.play()


func set_chase(value: bool) -> void:
	chasing = value
	if value and chase.stream != null and not chase.playing and not muted():
		chase.volume_db = QUIET_DB
		chase.play()


func set_paused(value: bool) -> void:
	for player in [music, chase, stinger_player]:
		player.stream_paused = value


## Called every running step: choose calm or action from the section and what
## happens, and fade smoothly towards it.
func update(delta: float, player, track) -> void:
	if not adventure or _finished:
		return
	var wanted: float = 0.0
	var plan = track.plan
	if player.s >= 0.0:
		for section in plan.sections:
			if player.s >= float(section.s0) and player.s < float(section.s1):
				wanted = 1.0 if str(section.mood) == "action" else 0.0
	if player.in_cart or player.is_riding() or player.s < 0.0:
		wanted = 1.0
	intensity = move_toward(intensity, wanted, delta / 2.5)
	_chase_mix = move_toward(_chase_mix, 1.0 if chasing else 0.0, delta / (0.6 if chasing else 2.0))
	if layers != null:
		var base: float = music_db()
		var duck: float = linear_to_db(maxf(0.0001, 1.0 - _chase_mix))
		layers.set_sync_stream_volume(1, linear_to_db(maxf(0.0001, intensity)))
		music.volume_db = base + duck
	if chase.playing:
		chase.volume_db = music_db() - 3.0 + linear_to_db(maxf(0.0001, _chase_mix))
		if _chase_mix <= 0.0 and not chasing:
			chase.stop()


func finish() -> void:
	_finished = true
	chasing = false
	var fade := create_tween()
	fade.tween_property(music, "volume_db", QUIET_DB, 1.2)
	chase.stop()
