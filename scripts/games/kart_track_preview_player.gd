extends Control
## Höchstens eine bewegte Streckenvorschau: ein vorab aus der echten Godot-Strecke
## gerenderter, stummer Theora-Clip über dem gleichnamigen Standbild. Das erste Bild
## des Clips ist das Standbild, Start und Rückblende sind deshalb ohne Sprung.
signal clip_started(track_id: String)
const CLIP_DIR := "res://assets/kart/track_stage/clips/"
## Standbild halten, bevor die Kamera losfährt; Pause nach der Rückblende.
const HOLD_BEFORE := 0.9
const HOLD_AFTER := 2.4
const FADE := 0.45
var video: VideoStreamPlayer
var track_id := ""
var reduced_motion := false
var _wait := -1.0
var _fading_out := false
var _paused := false
var _video_aspect := 16.0 / 9.0
var _fade_tween: Tween


func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_meta("kart_self_sized", true)
	video = VideoStreamPlayer.new()
	video.name = "TrackPreviewVideo"
	video.volume_db = -80.0
	video.autoplay = false
	video.expand = true
	video.mouse_filter = Control.MOUSE_FILTER_IGNORE
	video.modulate.a = 0.0
	video.finished.connect(_on_finished)
	add_child(video)
	resized.connect(_fit)


static func clip_path(id: String) -> String:
	return CLIP_DIR + id + ".ogv"


static func has_clip(id: String) -> bool:
	return FileAccess.file_exists(clip_path(id)) or ResourceLoader.exists(clip_path(id))


## Neue Strecke: laufenden Clip sofort anhalten und erst nach kurzer Ruhe laden,
## damit schnelles Blättern keine Clips öffnet, die niemand sieht.
func show_track(id: String) -> void:
	if id == track_id and video.stream != null:
		return
	stop()
	track_id = id
	if reduced_motion or not has_clip(id):
		return
	_wait = HOLD_BEFORE


func stop() -> void:
	_wait = -1.0
	_fading_out = false
	if is_instance_valid(_fade_tween):
		_fade_tween.kill()
	video.stop()
	video.stream = null
	video.modulate.a = 0.0
	track_id = ""


func set_paused(paused: bool) -> void:
	if paused == _paused:
		return
	_paused = paused
	if paused:
		# Verlassen der Ansicht: sofort anhalten und den Decoder freigeben.
		var id := track_id
		stop()
		track_id = id
	elif not track_id.is_empty() and not reduced_motion and has_clip(track_id):
		_wait = HOLD_BEFORE


func is_playing() -> bool:
	return video.is_playing() and not video.paused


func _process(delta: float) -> void:
	if _paused or _wait < 0.0:
		return
	_wait -= delta
	if _wait <= 0.0:
		_wait = -1.0
		_start()


func _start() -> void:
	if video.stream == null:
		var stream := load(clip_path(track_id)) as VideoStream
		if stream == null:
			return
		video.stream = stream
	_fading_out = false
	video.modulate.a = 1.0
	video.stream_position = 0.0
	video.play()
	var texture := video.get_video_texture()
	if texture != null and texture.get_height() > 0:
		_video_aspect = float(texture.get_width()) / float(texture.get_height())
	_fit()
	clip_started.emit(track_id)


func _on_finished() -> void:
	if _paused or track_id.is_empty():
		return
	# Weiche Rückblende auf das Standbild darunter, dann von vorn.
	_fading_out = true
	if is_instance_valid(_fade_tween):
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(video, "modulate:a", 0.0, FADE)
	_wait = FADE + HOLD_AFTER


func _fit() -> void:
	# Wie das Standbild: füllend, mittig beschnitten (KEEP_ASPECT_COVERED).
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var cover := size
	if size.x / size.y > _video_aspect:
		cover.y = size.x / _video_aspect
	else:
		cover.x = size.y * _video_aspect
	video.position = (size - cover) * 0.5
	video.size = cover
