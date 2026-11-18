extends Node
## Original offline Lumo score. Music crossfades; focus loss and pause are silent.
## API: play_menu(), play_track(track_id), effect(kind), set_muted(bool),
## set_paused(bool). The owner persists its existing sound preference.

const MUSIC_PATH := "res://assets/audio/kart/%s.ogg"
const JUNGLE_ID := "jungle_emerald_3600"
const JUNGLE_AMBIENCE = preload("res://scripts/games/kart_jungle_audio.gd")
const TRACKS := ["sonnenhafen", "zauberwald", "bergwelt", "holo_city"]
const EFFECTS := ["start", "boost", "drift", "item", "finish", "countdown", "collision"]
## Item cues (tools/art/generate_kart_item_audio.py) in assets/audio/kart/items/.
const ITEM_EFFECTS := [
	"rocket_arm", "lock_beep", "lock_on", "rocket_launch", "rocket_hit", "shield_up",
	"shield_ping", "missile_warning", "roulette_tick", "roulette_done",
]
## Short repeating cues (lock tone, roulette, warning) use their own player so they
## never cut the launch or hit sounds.
const TONE_EFFECTS := ["lock_beep", "roulette_tick", "missile_warning"]
## Driving sounds (tools/art/generate_kart_fx_audio.py) in assets/audio/kart/fx/.
## One-shots go through effect(); loops are driven every frame with set_loop().
const FX_EFFECTS := ["rail_hit", "rail_hit_soft", "backfire", "land_thump", "confetti", "whoosh"]
const FX_LOOPS := [
	"engine_low", "engine_mid", "engine_high", "engine_off", "scrape", "squeal", "gravel", "snow",
	"turbo", "wind",
]
## Per-loop trim in dB against the effect level, so the mix stays kind to small ears.
const LOOP_TRIM := {
	"engine_low": -13.0, "engine_mid": -14.0, "engine_high": -16.0, "engine_off": -15.0,
	"scrape": -7.0, "squeal": -15.0, "gravel": -12.0, "snow": -11.0, "turbo": -12.0, "wind": -15.0,
}
const MUSIC_DB := -17.0
const EFFECT_DB := -9.0
const QUIET_DB := -60.0

var _music: Array[AudioStreamPlayer] = []
var _effects: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}
var _last_effect: Dictionary = {}
var _active: int = 0
var _effect_cursor: int = 0
var _tone: AudioStreamPlayer
var _current: String = ""
var _track_id: String = ""
var _ambience: Node3D
var _muted: bool = false
var _paused: bool = false
var _focused: bool = true
var _background: bool = false
var _fade: Tween
var _loops: Dictionary = {}
## Driving one-shots have their own voices: they never cut a race cue.
var _fx_players: Array[AudioStreamPlayer] = []
var _fx_cursor: int = 0
var _loop_fed: Dictionary = {}
## Every accepted driving-sound request (kind -> count), muted or not; tests read it.
var fx_requests: Dictionary = {}
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
	for index in range(3):
		var fx_player := AudioStreamPlayer.new()
		fx_player.name = "DriveFx%d" % index
		fx_player.bus = "Master"
		add_child(fx_player)
		_fx_players.append(fx_player)
	_tone = AudioStreamPlayer.new()
	_tone.name = "ItemTone"
	_tone.bus = "Master"
	_tone.volume_db = EFFECT_DB
	add_child(_tone)


func set_volumes(music: float, effects: float) -> void:
	music_volume = clampf(music, 0.0, 1.0)
	effects_volume = clampf(effects, 0.0, 1.0)
	if not _music.is_empty() and _music[_active].playing:
		if is_instance_valid(_fade):
			_fade.kill()
		_music[_active].volume_db = music_db()
	if is_instance_valid(_ambience):
		_ambience.set_audio_state(_blocked(), effects_volume)


func music_db() -> float:
	return QUIET_DB if music_volume <= 0.01 else MUSIC_DB + linear_to_db(music_volume)


func effect_db() -> float:
	return QUIET_DB if effects_volume <= 0.01 else EFFECT_DB + linear_to_db(effects_volume)


func play_menu() -> void:
	_track_id = ""
	_play_music("garage")


func play_track(track_id: Variant) -> void:
	var track := str(track_id)
	if track_id is int:
		track = TRACKS[clampi(int(track_id), 0, TRACKS.size() - 1)]
	if track == "arena":
		track = "holo_city"
	_track_id = track
	if track == JUNGLE_ID:
		_play_music(JUNGLE_ID + "/main")
		return
	if not TRACKS.has(track):
		track = "sonnenhafen"
	_play_music(track)


func _play_music(track: String, preserve_phase: bool = false) -> void:
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
	var phase := previous.get_playback_position() if preserve_phase and previous.playing else 0.0
	_active = 1 - _active
	var next := _music[_active]
	next.stop()
	next.stream = stream
	next.volume_db = QUIET_DB if previous.playing else music_db()
	next.play(fposmod(phase, maxf(stream.get_length(), 0.01)))
	if previous.playing and is_inside_tree():
		var transition: float = 1.2 if preserve_phase else 0.45
		_fade = create_tween().set_parallel(true)
		_fade.tween_property(previous, "volume_db", QUIET_DB, transition)
		_fade.tween_property(next, "volume_db", music_db(), transition)
		_fade.chain().tween_callback(previous.stop)
	_apply_pause()


func bind_world(world) -> void:
	if is_instance_valid(_ambience):
		_ambience.queue_free()
	_ambience = null
	if world == null or str(world.track_id) != JUNGLE_ID:
		return
	_ambience = JUNGLE_AMBIENCE.new()
	world.add_child(_ambience)
	_ambience.configure(world)
	_ambience.set_audio_state(_blocked(), effects_volume)


func update_course_state(delta: float, distance: float, length: float, final_lap: bool, finished: bool, listener: Vector3) -> void:
	if _track_id != JUNGLE_ID:
		return
	if not finished and not _blocked():
		var metres := fposmod(distance, maxf(length, 1.0))
		var calm: bool = (metres >= 1200.0 and metres < 1500.0) or (metres >= 2100.0 and metres < 2400.0)
		var variation := "calm" if calm else "final" if final_lap else "main"
		if _current != JUNGLE_ID + "/" + variation:
			_play_music(JUNGLE_ID + "/" + variation, true)
	if is_instance_valid(_ambience):
		_ambience.set_audio_state(_blocked() or finished, effects_volume)
		_ambience.advance(delta, listener)


func effect(kind: String, pitch: float = 1.0, gain: float = 1.0) -> void:
	var item_cue: bool = ITEM_EFFECTS.has(kind)
	var fx_cue: bool = FX_EFFECTS.has(kind)
	if fx_cue:
		fx_requests[kind] = int(fx_requests.get(kind, 0)) + 1
	if _blocked() or not (EFFECTS.has(kind) or item_cue or fx_cue):
		return
	_ensure_players()
	var now := Time.get_ticks_msec()
	var cooldown := 300 if kind in ["drift", "collision"] else (40 if kind in TONE_EFFECTS else (140 if fx_cue else 85))
	if now - int(_last_effect.get(kind, -1000)) < cooldown:
		return
	var key := JUNGLE_ID + "/" + kind if _track_id == JUNGLE_ID and kind in ["start", "finish"] else kind
	if item_cue:
		key = "items/" + kind
	elif fx_cue:
		key = "fx/" + kind
	var stream := _load_stream(key, false)
	if stream == null:
		return
	_last_effect[kind] = now
	var player: AudioStreamPlayer = _tone if kind in TONE_EFFECTS else _effects[_effect_cursor]
	if fx_cue:
		player = _fx_players[_fx_cursor]
		_fx_cursor = (_fx_cursor + 1) % _fx_players.size()
	elif player != _tone:
		_effect_cursor = (_effect_cursor + 1) % _effects.size()
	player.stop()
	player.stream = stream
	player.pitch_scale = clampf(pitch, 0.5, 2.0)
	player.volume_db = effect_db() - 4.0 if kind == "collision" else (effect_db() - 3.0 if kind in TONE_EFFECTS else effect_db())
	if fx_cue:
		player.volume_db = effect_db() - 2.0 + linear_to_db(clampf(gain, 0.05, 1.0))
	player.play()


## Continuous driving sound: [param gain] 0-1 follows the real driving state each
## frame, [param pitch] its tempo. Silent (and stopped) while muted or paused.
func set_loop(kind: String, gain: float, pitch: float = 1.0) -> void:
	if not FX_LOOPS.has(kind):
		return
	_loop_fed[kind] = Time.get_ticks_msec()
	var player: AudioStreamPlayer = _loops.get(kind)
	if gain <= 0.005 or _blocked() or effects_volume <= 0.01:
		if player != null and player.playing:
			player.stop()
		return
	if player == null:
		var stream := _load_stream("fx/" + kind, true)
		if stream == null:
			return
		player = AudioStreamPlayer.new()
		player.name = "Loop_" + kind
		player.bus = "Master"
		player.stream = stream
		add_child(player)
		_loops[kind] = player
	player.volume_db = effect_db() + float(LOOP_TRIM.get(kind, -12.0)) + linear_to_db(clampf(gain, 0.0, 1.0))
	player.pitch_scale = clampf(pitch, 0.5, 2.5)
	if not player.playing:
		player.play(randf() * maxf(0.0, player.stream.get_length() - 0.05))


## Loops are driven by the race every tick. When nobody feeds them any more
## (menu, scene change, a stalled race) they fall silent on their own.
func _process(_delta: float) -> void:
	if _loops.is_empty():
		return
	var now := Time.get_ticks_msec()
	for kind in _loops:
		var player: AudioStreamPlayer = _loops[kind]
		if player.playing and now - int(_loop_fed.get(kind, 0)) > 250:
			player.stop()


func loop_level(kind: String) -> float:
	var player: AudioStreamPlayer = _loops.get(kind)
	return db_to_linear(player.volume_db) if player != null and player.playing else 0.0


func stop_loops() -> void:
	for player in _loops.values():
		(player as AudioStreamPlayer).stop()


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
		if is_instance_valid(_tone):
			_tone.stop()
		for fx_player in _fx_players:
			fx_player.stop()
		stop_loops()
	if _track_id == JUNGLE_ID and is_instance_valid(_fade) and _fade.is_valid():
		if blocked:
			_fade.pause()
		else:
			_fade.play()
	if is_instance_valid(_ambience):
		_ambience.set_audio_state(blocked, effects_volume)


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
	_fade = null
	# Exit can interrupt a crossfade or an effect. Release both the players'
	# stream references and our cache, including when this node is detached
	# and later re-entered instead of immediately destroyed.
	for player in _music:
		player.stop()
		player.stream = null
	for player in _effects:
		player.stop()
		player.stream = null
	for player in _loops.values():
		player.stop()
		player.stream = null
		player.queue_free()
	_loops.clear()
	_streams.clear()
	_last_effect.clear()
	_current = ""
	_track_id = ""
	if is_instance_valid(_ambience):
		_ambience.queue_free()
	_ambience = null
