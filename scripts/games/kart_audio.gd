extends Node
## Original offline Lumo score. Music crossfades; focus loss and pause are silent.
## API: play_menu(), play_track(track_id), effect(kind), set_muted(bool),
## set_paused(bool). The owner persists its existing sound preference.

const MUSIC_PATH := "res://assets/audio/kart/%s.ogg"
const TRACKS := ["sonnenhafen", "zauberwald", "bergwelt", "holo_city"]
const EFFECTS := ["start", "boost", "drift", "item", "finish", "countdown", "collision"]
const MUSIC_DB := -17.0
const EFFECT_DB := -9.0
const QUIET_DB := -60.0

var _music: Array[AudioStreamPlayer] = []
var _effects: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}
var _last_effect: Dictionary = {}
var _active: int = 0
var _effect_cursor: int = 0
var _current: String = ""
var _muted: bool = false
var _paused: bool = false
var _focused: bool = true
var _background: bool = false
var _fade: Tween
## Getrennte Lautstärken (0–1) für Musik und Effekte; die Motorgeräusche folgen den Effekten.
var music_volume: float = 1.0
var effects_volume: float = 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_players()


func _ensure_players() -> void:
	if not _music.is_empty():
		return
	for index in range(2):
		var player := AudioStreamPlayer.new()
		player.name = "Music%d" % index
		player.bus = "Master"
		player.volume_db = MUSIC_DB
		add_child(player)
		_music.append(player)
	for index in range(4):
		var player := AudioStreamPlayer.new()
		player.name = "Effect%d" % index
		player.bus = "Master"
		player.volume_db = EFFECT_DB
		add_child(player)
		_effects.append(player)


func set_volumes(music: float, effects: float) -> void:
	music_volume = clampf(music, 0.0, 1.0)
	effects_volume = clampf(effects, 0.0, 1.0)
	if not _music.is_empty() and _music[_active].playing:
		if is_instance_valid(_fade):
			_fade.kill()
		_music[_active].volume_db = music_db()


func music_db() -> float:
	return QUIET_DB if music_volume <= 0.01 else MUSIC_DB + linear_to_db(music_volume)


func effect_db() -> float:
	return QUIET_DB if effects_volume <= 0.01 else EFFECT_DB + linear_to_db(effects_volume)


func play_menu() -> void:
	_play_music("garage")


func play_track(track_id: Variant) -> void:
	var track := str(track_id)
	if track_id is int:
		track = TRACKS[clampi(int(track_id), 0, TRACKS.size() - 1)]
	if track == "arena":
		track = "holo_city"
	if not TRACKS.has(track):
		track = "sonnenhafen"
	_play_music(track)


func _play_music(track: String) -> void:
	_ensure_players()
	if track == _current:
		_apply_pause()
		return
	var stream := _load_stream(track, true)
	if stream == null:
		return
	_current = track
	if is_instance_valid(_fade):
		_fade.kill()
	var previous := _music[_active]
	_active = 1 - _active
	var next := _music[_active]
	next.stop()
	next.stream = stream
	next.volume_db = QUIET_DB if previous.playing else music_db()
	next.play()
	if previous.playing and is_inside_tree():
		_fade = create_tween().set_parallel(true)
		_fade.tween_property(previous, "volume_db", QUIET_DB, 0.45)
		_fade.tween_property(next, "volume_db", music_db(), 0.45)
		_fade.chain().tween_callback(previous.stop)
	_apply_pause()


func effect(kind: String) -> void:
	if _blocked() or not EFFECTS.has(kind):
		return
	_ensure_players()
	var now := Time.get_ticks_msec()
	var cooldown := 300 if kind in ["drift", "collision"] else 85
	if now - int(_last_effect.get(kind, -1000)) < cooldown:
		return
	var stream := _load_stream(kind, false)
	if stream == null:
		return
	_last_effect[kind] = now
	var player := _effects[_effect_cursor]
	_effect_cursor = (_effect_cursor + 1) % _effects.size()
	player.stop()
	player.stream = stream
	player.volume_db = effect_db() - 4.0 if kind == "collision" else effect_db()
	player.play()


func set_muted(value: bool) -> void:
	_muted = value
	_apply_pause()


func set_paused(value: bool) -> void:
	_paused = value
	_apply_pause()


func _blocked() -> bool:
	return _muted or _paused or not _focused or _background


func _apply_pause() -> void:
	var blocked := _blocked()
	for player in _music:
		player.stream_paused = blocked
	if blocked:
		for player in _effects:
			player.stop()


func _load_stream(key: String, loop: bool) -> AudioStreamOggVorbis:
	if _streams.has(key):
		return _streams[key] as AudioStreamOggVorbis
	var path := MUSIC_PATH % key
	if not ResourceLoader.exists(path):
		push_warning("[KartAudio] Missing original audio: %s" % key)
		return null
	var stream := load(path) as AudioStreamOggVorbis
	if stream == null:
		return null
	stream.loop = loop
	_streams[key] = stream
	return stream


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			_background = true
			_apply_pause()
		NOTIFICATION_APPLICATION_RESUMED:
			_background = false
			_apply_pause()
		NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			_focused = false
			_apply_pause()
		NOTIFICATION_WM_WINDOW_FOCUS_IN:
			_focused = true
			_apply_pause()


func _exit_tree() -> void:
	if is_instance_valid(_fade):
		_fade.kill()
	for player in _music:
		player.stop()
	for player in _effects:
		player.stop()
