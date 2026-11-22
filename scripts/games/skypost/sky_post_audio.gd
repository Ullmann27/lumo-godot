extends Node
## Music and sounds of Lumos Sternenpost. Own pieces live in
## assets/audio/skypost/ (tools/lumo_skypost_art/generate_skypost_audio.py: the
## calm Wolkenhafen waltz, the race layer, chute, mailbox, photo click); the
## star series, ring and finish sounds are shared with Lumo Lauf and Lumo Kart.
## Volumes follow the music and effects sliders of Lumo Kart and the app mute.

const OWN: String = "res://assets/audio/skypost/%s.ogg"
const RUN: String = "res://assets/audio/run/%s.ogg"
const KART: String = "res://assets/audio/kart/%s.ogg"
const PREFERENCES: String = "user://kart_preferences.cfg"
const MUSIC_DB: float = -15.0
const EFFECT_DB: float = -8.0
const WIND_DB: float = -13.0
const QUIET_DB: float = -60.0
## name -> candidate paths, first existing one wins.
const EFFECTS := {
	"star_0": [RUN % "sfx_star_0"],
	"star_1": [RUN % "sfx_star_1"],
	"star_2": [RUN % "sfx_star_2"],
	"star_3": [RUN % "sfx_star_3"],
	"star_4": [RUN % "sfx_star_4"],
	"star_5": [RUN % "sfx_star_5"],
	"star_6": [RUN % "sfx_star_6"],
	"star_7": [RUN % "sfx_star_7"],
	"boost": [OWN % "boost", KART % "fx/turbo", KART % "boost"],
	"ring": [OWN % "ring", RUN % "sfx_gate"],
	"release": [OWN % "release", KART % "fx/whoosh"],
	"chute": [OWN % "chute", KART % "fx/whoosh"],
	"delivered": [OWN % "mailbox", RUN % "sfx_letter"],
	"wrong": [OWN % "wrong", RUN % "sfx_hit"],
	"miss": [OWN % "puff", KART % "fx/land_thump"],
	"cushion": [OWN % "cushion", KART % "fx/whoosh"],
	"photo": [OWN % "photo", RUN % "sfx_checkpoint"],
	"secret": [RUN % "bonus"],
	"countdown": [KART % "countdown"],
	"go": [KART % "start"],
	"finish": [RUN % "finish", KART % "finish"],
	"confetti": [KART % "fx/confetti"],
	"liftoff": [OWN % "liftoff", KART % "fx/whoosh"],
}

var music_volume: float = 1.0
var effects_volume: float = 1.0
var music: AudioStreamPlayer
var race_layer: AudioStreamPlayer
var wind: AudioStreamPlayer
var _effects: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _next: int = 0
var _wind_mix: float = 0.0
var _race_mix: float = 0.0
var _race_wanted: float = 0.0
var _paused: bool = false
var _finished: bool = false


func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(PREFERENCES) == OK:
		music_volume = clampf(float(config.get_value("race", "music_volume", 1.0)), 0.0, 1.0)
		effects_volume = clampf(float(config.get_value("race", "effects_volume", 1.0)), 0.0, 1.0)
	music = _player("Music")
	race_layer = _player("RaceLayer")
	wind = _player("Wind")
	for index in range(6):
		_pool.append(_player("Effect%d" % index))
	for name in EFFECTS:
		for path in EFFECTS[name]:
			var stream: AudioStream = _load(str(path), false)
			if stream != null:
				_effects[name] = stream
				break
	var air: AudioStream = _load(KART % "fx/wind", true)
	if air != null:
		wind.stream = air
		wind.volume_db = QUIET_DB


func _player(label: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = label
	player.bus = "Master"
	add_child(player)
	return player


func _load(path: String, loop: bool) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	var stream := load(path) as AudioStreamOggVorbis
	if stream == null:
		return null
	if loop != stream.loop:
		stream = stream.duplicate()
		stream.loop = loop
	return stream


func muted() -> bool:
	return AudioManager.is_muted()


func music_db() -> float:
	return QUIET_DB if music_volume <= 0.01 else MUSIC_DB + linear_to_db(music_volume)


func effect_db() -> float:
	return QUIET_DB if effects_volume <= 0.01 else EFFECT_DB + linear_to_db(effects_volume)


## [param race]: the race layer joins the waltz (same tempo and length).
func start_music(race: bool) -> void:
	_finished = false
	var base: AudioStream = _load(OWN % "wolkenhafen", true)
	if base == null:
		base = _load(KART % "sonnenhafen", true)
	if music.stream != base:
		music.stream = base
	var layer: AudioStream = _load(OWN % "wolkenhafen_race", true)
	race_layer.stream = layer
	_race_wanted = 1.0 if race else 0.0
	music.volume_db = music_db()
	if music.stream != null and not muted() and not music.playing:
		music.play()
	if layer != null and not muted():
		race_layer.volume_db = QUIET_DB
		race_layer.play(music.get_playback_position() if music.playing else 0.0)


func has_effect(name: String) -> bool:
	return _effects.has(name)


func effect(name: String, pitch: float = 1.0, gain_db: float = 0.0) -> void:
	if muted() or _paused or not _effects.has(name):
		return
	var player: AudioStreamPlayer = _pool[_next % _pool.size()]
	_next += 1
	player.stream = _effects[name]
	player.pitch_scale = pitch
	player.volume_db = effect_db() + gain_db - (3.0 if name.begins_with("star") else 0.0)
	player.play()


func play_star(combo: int) -> void:
	effect("star_%d" % clampi(combo, 0, 7))


func set_paused(value: bool) -> void:
	_paused = value
	for player in [music, race_layer, wind]:
		player.stream_paused = value


## Per frame: rushing air with the speed, the race layer fading in and out.
func update(delta: float, speed: float, cruise: float) -> void:
	if _paused:
		return
	var rush: float = clampf((speed - cruise + 2.0) / 10.0, 0.0, 1.0)
	_wind_mix = move_toward(_wind_mix, rush, delta * 1.5)
	if wind.stream != null and not muted() and not _finished:
		if _wind_mix > 0.02 and not wind.playing:
			wind.play()
		wind.volume_db = effect_db() + WIND_DB + linear_to_db(maxf(0.0001, _wind_mix))
		wind.pitch_scale = 0.9 + 0.3 * _wind_mix
	_race_mix = move_toward(_race_mix, _race_wanted, delta / 1.5)
	if race_layer.playing:
		race_layer.volume_db = music_db() + linear_to_db(maxf(0.0001, _race_mix))


func finish() -> void:
	_finished = true
	_race_wanted = 0.0
	wind.stop()


func stop_all() -> void:
	for player in [music, race_layer, wind]:
		player.stop()
	for player in _pool:
		player.stop()
