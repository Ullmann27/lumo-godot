## AudioManager (Autoload als 'AudioManager').
##
## Leichtgewichtiger SFX-Layer. API:
##   AudioManager.play_sfx(name)
##   AudioManager.set_muted(b)
##
## Sounds werden zur Laufzeit prozedural generiert (kein Asset-File noetig).
## Pro SFX gibt es ein Preset (Frequenz, Dauer, Wellenform).
extends Node

# (frequency_hz, duration_seconds, kind) - kind: "sine"|"square"|"chirp_up"|"chirp_down"
const SFX_PRESETS: Dictionary = {
	"star_collected": {"freq": 880.0, "dur": 0.18, "kind": "chirp_up"},
	"portal_tap": {"freq": 440.0, "dur": 0.10, "kind": "sine"},
	"celebrate": {"freq": 660.0, "dur": 0.35, "kind": "chirp_up"},
	"card_next": {"freq": 520.0, "dur": 0.08, "kind": "sine"},
	"back": {"freq": 320.0, "dur": 0.12, "kind": "chirp_down"},
}

const SAMPLE_RATE: float = 22050.0

var _muted: bool = false
var _player: AudioStreamPlayer
var _cache: Dictionary = {}


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = "Master"
	add_child(_player)
	# Synchronisiere mit gespeicherten Settings, falls vorhanden.
	if Engine.has_singleton("SettingsStore"):
		var store: Node = Engine.get_singleton("SettingsStore")
		if store.has_method("is_audio_muted"):
			_muted = store.call("is_audio_muted")
	print("[Audio] manager ready (muted:%s)" % _muted)


func set_muted(b: bool) -> void:
	_muted = b
	if Engine.has_singleton("SettingsStore"):
		var store: Node = Engine.get_singleton("SettingsStore")
		if store.has_method("set_audio_muted"):
			store.call("set_audio_muted", b)
	AudioServer.set_bus_mute(0, b)


func is_muted() -> bool:
	return _muted


func play_sfx(name: String) -> void:
	if _muted:
		return
	if not SFX_PRESETS.has(name):
		push_warning("[Audio] unknown sfx: %s" % name)
		return
	var stream: AudioStream = _get_or_make(name)
	if stream == null:
		return
	_player.stream = stream
	_player.play()


## Spielt eine Voice-WAV-Datei aus assets/audio/voice/ ab.
## path: relativ ab voice/ ohne Endung, z.B. "letters/a" oder "words/apfel"
func play_voice(path: String) -> void:
	if _muted:
		return
	var full: String = "res://assets/audio/voice/%s.wav" % path
	if _cache.has(full):
		_player.stream = _cache[full]
		_player.play()
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
