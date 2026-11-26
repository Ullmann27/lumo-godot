extends Node
## Original offline Lumo score. Music crossfades; focus loss and pause are silent.
## API: play_menu(), play_track(track_id), effect(kind), set_muted(bool),
## set_paused(bool). The owner persists its existing sound preference.

const MOTOR = preload("res://scripts/games/kart_fx/kart_motor_voice.gd")
const RIVAL_LIMIT := {"low": 1, "medium": 2, "high": 3}
const MUSIC_PATH := "res://assets/audio/kart/%s.ogg"
const JUNGLE_ID := "jungle_emerald_3600"
const JUNGLE_AMBIENCE = preload("res://scripts/games/kart_jungle_audio.gd")
## Hook items-neu: Töne der erweiterten Items (gleicher Ordner items/).
const ITEM_EXT_REGISTRY = preload("res://scripts/games/kart_items/ext/kart_item_ext_registry.gd")
const TRACKS := ["sonnenhafen", "zauberwald", "bergwelt", "holo_city"]
const COURSE_CATALOG = preload("res://scripts/games/kart_catalog.gd")
const PARCOURS_MUSIC := ["wolkenwerkstatt", "eisturm", "dschungeltempel"]
const EFFECTS := ["start", "boost", "drift", "item", "finish", "countdown", "collision"]
## Item cues (tools/art/generate_kart_item_audio.py) in assets/audio/kart/items/.
const ITEM_EFFECTS := [
	"rocket_arm", "lock_beep", "lock_on", "rocket_launch", "rocket_hit", "magnet_pull", "shield_up",
	"shield_ping", "missile_warning", "roulette_tick", "roulette_done",
]
## Short repeating cues (lock tone, roulette, warning) use their own player so they
## never cut the launch or hit sounds.
const TONE_EFFECTS := ["lock_beep", "roulette_tick", "missile_warning"]
## Driving sounds (tools/art/generate_kart_fx_audio.py) in assets/audio/kart/fx/.
## One-shots go through effect(); loops are driven every frame with set_loop().
## LUMO-Passagen: Kiris Ruf vor dem Schwung (assets/audio/kart/passage/).
const PASSAGE_EFFECTS := [
	"monkey_call", "gate_bell", "stone_rumble", "switch_chime", "lava_hiss", "robot_beep"
]
const FX_EFFECTS := [
	"rail_hit", "rail_hit_soft", "backfire", "land_thump", "confetti", "whoosh", "splash", "bump"
]
const FX_LOOPS := [
	"engine_low", "engine_mid", "engine_high", "engine_off", "scrape", "squeal", "gravel", "snow",
	"turbo", "wind", "rocket_fly", "curb",
]
## One-shot trims: the race already plays its own collision/boost cue on the same
## event, so these sit underneath it (worst-case sum stays below clipping).
const FX_TRIM := {
	"rail_hit": -5.0, "rail_hit_soft": -7.0, "backfire": -5.0, "land_thump": -3.0, "confetti": -5.0,
	"whoosh": -9.0, "splash": -6.0, "bump": -6.0,
}
## Music ducking on a hard hit: depth in dB and how long it holds.
const DUCK_DB := 3.0
## Per-loop trim in dB against the effect level, so the mix stays kind to small ears.
const LOOP_TRIM := {
	"engine_low": -13.0, "engine_mid": -14.0, "engine_high": -16.0, "engine_off": -15.0,
	"scrape": -9.0, "squeal": -15.0, "gravel": -12.0, "snow": -11.0, "turbo": -12.0, "wind": -15.0,
	"rocket_fly": -13.0, "curb": -13.0,
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
var _fade_paused: bool = false
var _loops: Dictionary = {}
## Driving one-shots have their own voices: they never cut a race cue.
var _fx_players: Array[AudioStreamPlayer] = []
var _fx_cursor: int = 0
var _loop_fed: Dictionary = {}
var player_motor: MOTOR
var rival_motors: Array[MOTOR] = []
var _motors_fed := 0
var _duck_until_msec: int = 0
var ducking: bool = false
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
	player_motor = MOTOR.new(self, false)
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
	if effects_volume <= .01:
		stop_loops()
	if not _music.is_empty() and _music[_active].playing:
		if is_instance_valid(_fade):
			_fade.kill()
		_music[_active].volume_db = music_db()
	if is_instance_valid(_ambience):
		_ambience.set_audio_state(_blocked(), effects_volume)


func configure_motors(player, rivals: Array) -> void:
	stop_motors()
	rival_motors.clear()
	player_motor.configure(player.kart_style, player.look)
	for kart in rivals:
		var voice := MOTOR.new(kart, true)
		voice.configure(kart.kart_style, kart.look)
		rival_motors.append(voice)


func stop_motors() -> void:
	if player_motor:
		player_motor.stop()
	for voice in rival_motors:
		voice.stop()


func update_motors(race, step: float) -> void:
	if _blocked() or effects_volume <= .01 or race.menu_active or race.finished or not is_instance_valid(race.player):
		stop_motors()
		return
	var grid: bool = not race.racing and race.countdown > 0.0 and race.preview_left <= 0.0
	if (not grid and not race.racing) or player_motor.body.stream == null:
		stop_motors()
		return
	update_player_motor(step, race.speed, race.brake_visual_amount, race._manual_gas_active(),
		race.auto_gas, grid, race.boost_time > 0.0, race.airborne)
	update_rival_motors(step, race.player.global_position, race.graphics_profile, grid)


func update_rival_motors(step: float, listener_position: Vector3, profile: String, grid: bool, parked: Array = []) -> void:
	var near: Array[MOTOR] = []
	for voice in rival_motors:
		var kart = voice.body.get_parent()
		voice.distance_sq = listener_position.distance_squared_to(kart.global_position)
		if not _blocked() and effects_volume > .01 and not parked.has(kart) and voice.distance_sq < MOTOR.RADIUS * MOTOR.RADIUS:
			near.append(voice)
		else:
			voice.stop()
			voice.previous_speed = absf(kart.motion_speed)
	# A voice already playing keeps a one-metre advantage at a close pass.
	near.sort_custom(func(a: MOTOR, b: MOTOR) -> bool:
		return sqrt(a.distance_sq) - float(a.body.playing) < sqrt(b.distance_sq) - float(b.body.playing))
	for i in near.size():
		var voice := near[i]
		var kart = voice.body.get_parent()
		var speed := 0.0 if grid else absf(kart.motion_speed)
		if i >= int(RIVAL_LIMIT.get(profile, 2)):
			voice.stop()
			voice.previous_speed = speed
			continue
		var delta_speed := (speed - voice.previous_speed) / maxf(step, .001)
		var brake_load := clampf(-delta_speed / 22.0, 0.0, 1.0)
		var gas := 0.0 if grid or speed < .1 else clampf(.78 + delta_speed / 25.0, 0.0, 1.0)
		voice.advance(step, speed, gas, brake_load, kart.motion_boost and not grid, false, effect_db() - 11.0)
		var cue := ""
		var gain := 0.0
		if not grid and kart.motion_boost:
			cue = "turbo"
			gain = .55 * voice.boost_timbre
		elif speed > 4.0 and (kart.motion_drift or brake_load > .15):
			cue = "squeal"
			gain = .55 if kart.motion_drift else brake_load
		if cue.is_empty():
			voice.road.stop()
		else:
			var stream := _load_stream("fx/" + cue, true)
			if stream != null:
				if voice.road.stream != stream:
					voice.road.stream = stream
				voice.road.pitch_scale = clampf((.82 + speed / 68.0) * voice.tire_grip, .7, 1.75)
				voice.road.volume_db = effect_db() - 16.0 + linear_to_db(gain)
				if not voice.road.playing:
					voice.road.play()


func update_player_motor(step: float, speed: float, brake: float, manual: bool,
		auto_gas: bool, grid: bool, boost: bool, airborne: bool) -> void:
	if _blocked() or effects_volume <= .01 or player_motor.body.stream == null:
		player_motor.stop()
		return
	_motors_fed = Time.get_ticks_msec()
	var braking := 0.0 if grid else brake
	var throttle := manual or (auto_gas and not grid and braking < .5)
	var rev := manual and (grid or (braking > .5 and absf(speed) < 3.0) or airborne)
	var before: int = player_motor.shifts
	# Keep the player's motor in front of music and the distant rival motors.
	# The existing effects slider, parent mute and focus/pause gates still apply.
	player_motor.advance(step, 0.0 if grid else speed, float(throttle), braking,
		boost and not grid, rev, effect_db() - 2.0)
	if player_motor.shifts > before and throttle and not grid:
		# Briefly clear the soundtrack from the real upshift; combustion
		# motors get their soft original exhaust cue, not an electric shift.
		duck(0.32)
		effect("backfire", 0.90, 0.60)


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
		_play_music(_jungle_music("main"))
		return
	if track not in PARCOURS_MUSIC and not COURSE_CATALOG.TRACKS.any(func(entry: Dictionary): return str(entry.id) == track):
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
		_fade_paused = false
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
		var track := _jungle_music(variation)
		if _current != track:
			_play_music(track, true)
	if is_instance_valid(_ambience):
		_ambience.set_audio_state(_blocked() or finished, effects_volume)
		_ambience.advance(delta, listener)


func _jungle_music(variation: String) -> String:
	var key := JUNGLE_ID + "/" + variation
	if _load_stream(key, true) != null:
		return key
	if variation != "main" and _load_stream(JUNGLE_ID + "/main", true) != null:
		return JUNGLE_ID + "/main"
	return "zauberwald"


func effect(kind: String, pitch: float = 1.0, gain: float = 1.0) -> void:
	var item_cue: bool = ITEM_EFFECTS.has(kind) or ITEM_EXT_REGISTRY.has_sound(kind)
	var fx_cue: bool = FX_EFFECTS.has(kind)
	if fx_cue:
		fx_requests[kind] = int(fx_requests.get(kind, 0)) + 1
	var passage_cue: bool = PASSAGE_EFFECTS.has(kind)
	if _blocked() or effects_volume <= .01 or not (EFFECTS.has(kind) or item_cue or fx_cue or passage_cue):
		return
	_ensure_players()
	var now := Time.get_ticks_msec()
	var cooldown := 300 if kind in ["drift", "collision"] else (40 if kind in TONE_EFFECTS else (140 if fx_cue else 85))
	if now - int(_last_effect.get(kind, -1000)) < cooldown:
		return
	var key := JUNGLE_ID + "/" + kind if _track_id == JUNGLE_ID and kind in ["start", "finish"] else kind
	if item_cue:
		key = "items/" + kind
	elif passage_cue:
		key = "passage/" + kind
	elif fx_cue:
		key = "fx/" + kind
	var stream := _load_stream(key, false)
	if stream == null and key.begins_with(JUNGLE_ID + "/"):
		stream = _load_stream(kind, false)
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
		player.volume_db = effect_db() + float(FX_TRIM.get(kind, -4.0)) + linear_to_db(clampf(gain, 0.05, 1.0))
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
	var now := Time.get_ticks_msec()
	_update_duck(now)
	if now - _motors_fed > 250 and player_motor and player_motor.body.playing:
		stop_motors()
	if _loops.is_empty():
		return
	for kind in _loops:
		var player: AudioStreamPlayer = _loops[kind]
		if player.playing and now - int(_loop_fed.get(kind, 0)) > 250:
			player.stop()


## Briefly lower the music (default 3 dB for 0.3 s) so a hard hit cuts through
## without making everything louder. Skipped while a crossfade owns the volume.
func duck(seconds: float = 0.3) -> void:
	_duck_until_msec = Time.get_ticks_msec() + int(seconds * 1000.0)
	_update_duck(Time.get_ticks_msec())


func _update_duck(now: int) -> void:
	var want := now < _duck_until_msec and not _blocked()
	if want == ducking and not want:
		return
	if _music.is_empty() or (is_instance_valid(_fade) and _fade.is_running()):
		return
	var player := _music[_active]
	if not player.playing:
		ducking = false
		return
	ducking = want
	player.volume_db = music_db() - (DUCK_DB if want else 0.0)


func loop_level(kind: String) -> float:
	var player: AudioStreamPlayer = _loops.get(kind)
	return db_to_linear(player.volume_db) if player != null and player.playing else 0.0


func stop_loops() -> void:
	stop_motors()
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
		# Only resume a crossfade this code paused: a finished Tween may still be
		# valid, and play() on it reports an engine ERROR.
		if blocked and _fade.is_running():
			_fade.pause()
			_fade_paused = true
		elif not blocked and _fade_paused:
			_fade.play()
			_fade_paused = false
	if is_instance_valid(_ambience):
		_ambience.set_audio_state(blocked, effects_volume)


func _load_stream(key: String, loop: bool) -> AudioStreamOggVorbis:
	if _streams.has(key):
		return _streams[key] as AudioStreamOggVorbis
	var path := MUSIC_PATH % key
	if not ResourceLoader.exists(path):
		_streams[key] = null
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
	stop_motors()
	rival_motors.clear()
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
