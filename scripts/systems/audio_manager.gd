## AudioManager (Autoload als 'AudioManager').
##
## Leichtgewichtiger SFX-Layer. API:
##   AudioManager.play_sfx(name)
##   AudioManager.set_muted(b)
##   AudioManager.has_sample(name) / AudioManager.set_sfx_volume(linear)
##
## Bekannte Namen (SFX_SAMPLES) spielen echte, selbst erzeugte OGG-Klaenge aus
## assets/audio/klangwelt/sfx/ (tools/art/generate_klangwelt_audio.py), mit
## mehreren Varianten und leichter Tonhoehen-/Pegelvariation. Nur unbekannte
## Namen fallen auf die alten prozedural erzeugten Toene (SFX_PRESETS) zurueck.
extends Node

signal voice_started(seconds: float)
signal sfx_played(name: String)

const SAMPLE_PATH: String = "res://assets/audio/klangwelt/sfx/%s_%d.ogg"
# Name -> Anzahl Varianten (Dateien <name>_0.ogg .. <name>_<n-1>.ogg).
const SFX_SAMPLES: Dictionary = {
	"ui_click": 4, "ui_confirm": 3, "ui_cancel": 2, "ui_back": 2, "portal_tap": 2,
	"card_next": 3, "star_collected": 4, "celebrate": 2, "card_deal": 4, "card_play": 4,
	"card_draw": 3, "card_select": 3, "card_refuse": 2, "card_pass": 2, "card_shuffle": 2,
	"card_flip": 3, "trick_win": 2, "quartet": 1, "round_win": 1, "turn_ping": 2,
	"piece_drop": 4, "pair_found": 2, "pair_miss": 2, "answer_correct": 3, "answer_wrong": 2,
	"coin": 4, "count_tick": 4, "build_place": 4, "build_remove": 3, "level_up": 1,
	"treasure_found": 1, "puzzle_snap": 3, "dig": 3, "applause": 2, "crowd_ooh": 1,
	"lumo_jingle": 1, "whoosh": 2,
}
const SFX_ALIASES: Dictionary = {"back": "ui_back"}
# Sehr haeufige Toene variieren staerker, seltene Fanfaren kaum.
const PITCH_SPREAD: Dictionary = {
	"ui_click": 1.06, "card_deal": 1.07, "card_play": 1.05, "card_select": 1.04,
	"count_tick": 1.0, "coin": 1.03, "build_place": 1.05, "dig": 1.08, "piece_drop": 1.04,
}
const SFX_DB: float = -4.0
const SFX_VOICES: int = 6

# (frequency_hz, duration_seconds, kind) - kind: "sine"|"square"|"chirp_up"|"chirp_down"
const SFX_PRESETS: Dictionary = {
	"star_collected": {"freq": 880.0, "dur": 0.18, "kind": "chirp_up"},
	"portal_tap": {"freq": 440.0, "dur": 0.10, "kind": "sine"},
	"celebrate": {"freq": 660.0, "dur": 0.35, "kind": "chirp_up"},
	"card_next": {"freq": 520.0, "dur": 0.08, "kind": "sine"},
	"back": {"freq": 320.0, "dur": 0.12, "kind": "chirp_down"},
	"ui_confirm": {"freq": 720.0, "dur": 0.10, "kind": "chirp_up"},
	"ui_cancel": {"freq": 280.0, "dur": 0.18, "kind": "chirp_down"},
	"ui_back": {"freq": 360.0, "dur": 0.10, "kind": "chirp_down"},
	# Kartentisch
	"card_deal": {"freq": 940.0, "dur": 0.035, "kind": "chirp_down"},
	"card_play": {"freq": 610.0, "dur": 0.07, "kind": "chirp_down"},
	"card_draw": {"freq": 480.0, "dur": 0.06, "kind": "chirp_up"},
	"card_select": {"freq": 820.0, "dur": 0.05, "kind": "sine"},
	"card_refuse": {"freq": 230.0, "dur": 0.14, "kind": "square"},
	"card_pass": {"freq": 300.0, "dur": 0.16, "kind": "chirp_down"},
	"trick_win": {"freq": 700.0, "dur": 0.22, "kind": "chirp_up"},
	"quartet": {"freq": 780.0, "dur": 0.30, "kind": "chirp_up"},
	"round_win": {"freq": 590.0, "dur": 0.45, "kind": "chirp_up"},
	"turn_ping": {"freq": 990.0, "dur": 0.09, "kind": "sine"},
}

const SAMPLE_RATE: float = 22050.0

var _muted: bool = false
var _player: AudioStreamPlayer
var _cache: Dictionary = {}
var _samples: Dictionary = {}
var _last_variant: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
var _sfx_volume: float = 1.0
var last_sfx_msec: int = -100000
var last_sfx_name: String = ""


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = "Master"
	add_child(_player)
	for index in range(SFX_VOICES):
		var voice := AudioStreamPlayer.new()
		voice.name = "Sfx%d" % index
		voice.bus = "Master"
		voice.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(voice)
		_pool.append(voice)
	# Synchronisiere mit gespeicherten Settings, falls vorhanden.
	if Engine.has_singleton("SettingsStore"):
		var store: Node = Engine.get_singleton("SettingsStore")
		if store.has_method("is_audio_muted"):
			_muted = store.call("is_audio_muted")
	print("[Audio] manager ready (muted:%s)" % _muted)


func _exit_tree() -> void:
	# Wiedergaben vor dem Programmende lösen (keine festgehaltenen Ressourcen).
	for voice in _pool:
		voice.stop()
		voice.stream = null
	_samples.clear()


func set_muted(b: bool) -> void:
	_muted = b
	if Engine.has_singleton("SettingsStore"):
		var store: Node = Engine.get_singleton("SettingsStore")
		if store.has_method("set_audio_muted"):
			store.call("set_audio_muted", b)
	AudioServer.set_bus_mute(0, b)


func is_muted() -> bool:
	return _muted


## Lautstaerke der Ereignistoene (0..1, z. B. aus dem Effekte-Regler).
func set_sfx_volume(linear: float) -> void:
	_sfx_volume = clampf(linear, 0.0, 1.0)


func get_sfx_volume() -> float:
	return _sfx_volume


## true, wenn fuer den Namen echte Klangdateien hinterlegt sind.
func has_sample(name: String) -> bool:
	return SFX_SAMPLES.has(str(SFX_ALIASES.get(name, name)))


## Alle Dateipfade eines Tons (fuer Tests und Doku).
func sample_paths(name: String) -> PackedStringArray:
	var key := str(SFX_ALIASES.get(name, name))
	var paths := PackedStringArray()
	for index in range(int(SFX_SAMPLES.get(key, 0))):
		paths.append(SAMPLE_PATH % [key, index])
	return paths


## Laufende Sprachausgabe ueber play_voice (fuer Ducking der Musik).
func is_voice_playing() -> bool:
	return is_instance_valid(_player) and _player.playing


func play_sfx(name: String) -> void:
	if _muted:
		return
	var variants := _sample_variants(name)
	if not variants.is_empty():
		_play_variant(name, variants)
		return
	if not SFX_PRESETS.has(name):
		push_warning("[Audio] unknown sfx: %s" % name)
		return
	var stream: AudioStream = _get_or_make(name)
	if stream == null:
		return
	# Alte Ersatztoene laufen ueber die Effekt-Stimmen; _player bleibt der Sprache vorbehalten.
	_play_sample(name, stream)


func _mark_sfx(name: String) -> void:
	last_sfx_msec = Time.get_ticks_msec()
	last_sfx_name = name
	sfx_played.emit(name)


func _play_sample(name: String, stream: AudioStream, pitch: float = 1.0, gain_db: float = 0.0) -> void:
	if _sfx_volume <= 0.01 or _pool.is_empty():
		_mark_sfx(name)
		return
	var voice: AudioStreamPlayer = _pool[_next_voice % _pool.size()]
	# Freie Stimme bevorzugen, damit schnelle Folgen (Austeilen) sich nicht abschneiden.
	for offset in range(_pool.size()):
		var candidate: AudioStreamPlayer = _pool[(_next_voice + offset) % _pool.size()]
		if not candidate.playing:
			voice = candidate
			break
	_next_voice = (_pool.find(voice) + 1) % _pool.size()
	voice.stream = stream
	voice.pitch_scale = pitch
	voice.volume_db = SFX_DB + gain_db + linear_to_db(_sfx_volume)
	voice.play()
	_mark_sfx(name)


## Zufällige Variante (nie zweimal dieselbe hintereinander) mit leichter
## Tonhöhen- und Pegelvariation. Bewusst ohne AudioStreamRandomizer: dessen
## Wiedergabe hält beim Programmende Ressourcen fest.
func _play_variant(name: String, variants: Array) -> void:
	var key := str(SFX_ALIASES.get(name, name))
	var index := 0
	if variants.size() > 1:
		index = randi() % (variants.size() - 1)
		if index >= int(_last_variant.get(key, -1)):
			index += 1
	_last_variant[key] = index
	var spread := float(PITCH_SPREAD.get(key, 1.025))
	var pitch := exp(randf_range(-log(spread), log(spread)))
	_play_sample(name, variants[index], pitch, randf_range(-1.2, 0.0))


func _sample_variants(name: String) -> Array:
	var key := str(SFX_ALIASES.get(name, name))
	if not SFX_SAMPLES.has(key):
		return []
	if _samples.has(key):
		return _samples[key]
	var loaded: Array = []
	for path in sample_paths(key):
		if not ResourceLoader.exists(path):
			continue
		var stream := load(path) as AudioStream
		if stream == null:
			continue
		if stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = false
		loaded.append(stream)
	if loaded.is_empty() and not SFX_PRESETS.has(key):
		push_warning("[Audio] sample missing: %s" % key)
	_samples[key] = loaded
	return loaded


## Spielt eine Voice-WAV-Datei aus assets/audio/voice/ ab.
## path: relativ ab voice/ ohne Endung, z.B. "letters/a" oder "words/apfel"
func play_voice(path: String) -> void:
	if _muted:
		return
	if not _valid_voice_key(path):
		return
	# Legacy voice files are eSpeak voices and must never be audible.
	# Only explicitly approved Gemini Sulafat recordings can play.
	var manifest_path := "res://assets/audio/voice/sulafat_manifest.json"
	if not FileAccess.file_exists(manifest_path):
		push_warning("[Lumo] Legacy voice blocked; Sulafat recordings not installed.")
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not _manifest_matches_reference(parsed):
		return
	var approved: Variant = parsed.get("files", {})
	var asset_key := "%s.wav" % path
	var voice_path := "res://assets/audio/voice/%s" % asset_key
	if not (approved is Dictionary) or not approved.has(asset_key):
		return
	var expected := String(approved[asset_key])
	if expected.length() != 64 or not FileAccess.file_exists(voice_path):
		return
	if FileAccess.get_sha256(voice_path) != expected:
		push_warning("[Lumo] Refused unverified voice file: %s" % asset_key)
		return
	var full: String = "res://assets/audio/voice/%s.wav" % path
	if _cache.has(full):
		_player.stream = _cache[full]
		_player.play()
		voice_started.emit((_cache[full] as AudioStream).get_length())
		return
	if not ResourceLoader.exists(full):
		push_warning("[Audio] voice missing: %s" % full)
		return
	var stream: AudioStream = ResourceLoader.load(full) as AudioStream
	if stream == null:
		push_warning("[Audio] voice not playable: %s" % full)
		return
	_cache[full] = stream
	_player.stream = stream
	_player.play()
	voice_started.emit(stream.get_length())


func _manifest_matches_reference(parsed: Variant) -> bool:
	return parsed is Dictionary \
		and parsed.get("voice", "") == "Sulafat" \
		and parsed.get("model", "") == "gemini-2.5-pro-preview-tts" \
		and parsed.get("profile", "") == "lumo-sulafat-reference-v1"


func _valid_voice_key(path: String) -> bool:
	var pattern := RegEx.new()
	pattern.compile("^(letters/[a-z]|words/[a-z]+)$")
	return pattern.search(path) != null


func _get_or_make(name: String) -> AudioStream:
	if _cache.has(name):
		return _cache[name]
	var preset: Dictionary = SFX_PRESETS[name]
	var stream: AudioStreamWAV = _generate_wav(preset["freq"], preset["dur"], preset["kind"])
	_cache[name] = stream
	return stream


func _generate_wav(freq: float, dur: float, kind: String) -> AudioStreamWAV:
	var sample_count: int = int(SAMPLE_RATE * dur)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)  # 16-bit mono
	for i in range(sample_count):
		var t: float = float(i) / SAMPLE_RATE
		var phase: float = 0.0
		match kind:
			"sine":
				phase = sin(TAU * freq * t)
			"square":
				phase = sign(sin(TAU * freq * t))
			"chirp_up":
				var f: float = freq + (freq * 1.5) * (t / dur)
				phase = sin(TAU * f * t)
			"chirp_down":
				var f2: float = freq - (freq * 0.5) * (t / dur)
				phase = sin(TAU * f2 * t)
			_:
				phase = sin(TAU * freq * t)
		# Envelope: schnelles Attack, exponentielles Decay
		var env: float = exp(-3.0 * t / dur)
		var sample: float = phase * env * 0.6  # max 60% volume
		var int_val: int = clampi(int(sample * 32767.0), -32768, 32767)
		data[i * 2] = int_val & 0xFF
		data[i * 2 + 1] = (int_val >> 8) & 0xFF
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = int(SAMPLE_RATE)
	stream.stereo = false
	stream.data = data
	return stream
