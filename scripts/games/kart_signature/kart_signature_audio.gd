extends Node3D
## Klanginseln und Ereignisklänge der Signatur-Strecken. Alle Klänge sind eigene Synthesen
## (tools/art/compose_signature_ambience.py), je Strecke ein Ordner unter
## assets/audio/kart/signature/. Ferne Quellen schlafen; meist laufen zwei oder drei.
## Lautstärke, Stummschaltung, Fokusverlust und Pause folgen den Kart-Einstellungen.
const ROOT: String = "res://assets/audio/kart/signature/%s/%s.ogg"
## Ereignisklänge liegen unter den Effekten (Ansagen bleiben verständlich).
const CUE_TRIM_DB: float = -6.0

var emitters: Array[AudioStreamPlayer3D] = []
var cues: Array[AudioStreamPlayer] = []
var folder: String = ""
var _blocked: bool = true
var _gain: float = 1.0
var _effect_db: float = -9.0
var _elapsed: float = 0.0
var _cursor: int = 0


func configure(world: Node3D, course) -> void:
	name = "SignatureAudio"
	folder = str(course.AUDIO_DIR)
	for entry in course.AMBIENCE:
		var stream: AudioStream = _stream(str(entry.kind))
		if stream == null:
			continue
		var emitter := AudioStreamPlayer3D.new()
		emitter.name = "%s_%04d" % [str(entry.kind), int(entry.metres)]
		emitter.stream = stream
		emitter.bus = "Master"
		emitter.unit_size = 30.0
		emitter.max_distance = float(entry.radius)
		emitter.max_db = float(entry.db)
		emitter.volume_db = float(entry.db)
		emitter.attenuation_filter_cutoff_hz = 9000.0
		emitter.position = (
			world.position_at(float(entry.metres), float(entry.side)) + Vector3.UP * 3.0
		)
		emitter.set_meta("base_db", float(entry.db))
		add_child(emitter)
		emitters.append(emitter)
	for i in range(2):
		var player := AudioStreamPlayer.new()
		player.name = "Cue%d" % i
		player.bus = "Master"
		add_child(player)
		cues.append(player)


func _stream(kind: String) -> AudioStream:
	var path: String = ROOT % [folder, kind]
	if not ResourceLoader.exists(path):
		push_warning("[Signatur] Klang fehlt: " + path)
		return null
	var stream := load(path) as AudioStreamOggVorbis
	if stream != null:
		stream.loop = true
	return stream


## Ein Takt aus advance_race: Stummschaltung/Pause übernehmen, nahe Quellen anschalten.
func update(game: Node, listener: Vector3, delta: float) -> void:
	var audio = game.get("kart_audio")
	var blocked: bool = bool(game.get("paused")) or bool(game.get("finished"))
	var gain: float = 1.0
	if is_instance_valid(audio):
		blocked = blocked or bool(audio.call("_blocked"))
		gain = clampf(float(audio.get("effects_volume")), 0.0, 1.0)
		_effect_db = float(audio.call("effect_db")) if audio.has_method("effect_db") else -9.0
	else:
		blocked = true
	set_audio_state(blocked, gain)
	if _blocked:
		return
	_elapsed += delta
	for emitter in emitters:
		var audible := emitter.global_position.distance_to(listener) < emitter.max_distance - 1.0
		if audible and not emitter.playing:
			emitter.play(fposmod(_elapsed, maxf(emitter.stream.get_length(), 0.1)))
		elif not audible and emitter.playing:
			emitter.stop()


func set_audio_state(blocked: bool, gain: float) -> void:
	var muted: bool = blocked or gain <= 0.01
	if muted == _blocked and is_equal_approx(gain, _gain):
		return
	_blocked = muted
	_gain = gain
	for emitter in emitters:
		emitter.stream_paused = muted
		emitter.volume_db = (
			-80.0 if muted else float(emitter.get_meta("base_db")) + linear_to_db(maxf(gain, 0.01))
		)
	for player in cues:
		if muted:
			player.stop()


## Ereignisklang (Grollen, Donner, Fontäne). Stumm bei Pause oder Stummschaltung.
func cue(kind: String, trim_db: float = 0.0) -> bool:
	if _blocked:
		return false
	var path: String = ROOT % [folder, kind]
	if not ResourceLoader.exists(path):
		return false
	var stream := load(path) as AudioStreamOggVorbis
	if stream == null:
		return false
	stream.loop = false
	var player: AudioStreamPlayer = cues[_cursor]
	_cursor = (_cursor + 1) % cues.size()
	player.stream = stream
	player.volume_db = _effect_db + CUE_TRIM_DB + trim_db
	player.play()
	return true


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
	for player in cues:
		player.stop()
		player.stream = null
