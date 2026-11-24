extends Node3D
## Ein fünfsekündiger Vorspann mit dem echten Tisch, dem Sternendeck und den Sitzfiguren.

signal finished
signal sound_cue(id: String)

const CARD = preload("res://scripts/games/cards/cards_card.gd")
const ROOM = preload("res://scripts/games/cards/cards_room.gd")
const UI = preload("res://scripts/games/cards/cards_ui_kit.gd")
const SCORE = preload("res://assets/cards_table/audio/table_opening.ogg")
const FAN := [7, 23, 36, 51, 11]
const PORTRAIT_AT := 1.8
const WIDE_AT := 3.6
const DURATION := 5.7

var camera: Camera3D
var seats: Array
var elapsed := 0.0
var shot := -1
var skip: Button
var title: Label
var fan: Array[Node3D] = []
var dealt: Node3D
var throw_origin: Vector3
var hand_bone := -1
var lamp: SpotLight3D
var lamp_energy := 0.0
var overlay: Control
var fade: ColorRect
var previous_camera: Transform3D
var previous_fov: float
var previous_offset: float
var closing := false
var music: AudioStreamPlayer


func begin(table_camera: Camera3D, characters: Array, density: float, insets: Rect2, volume: float) -> void:
	camera = table_camera
	seats = characters
	lamp = camera.get_parent().key_light
	lamp_energy = lamp.light_energy
	if seats[1].usable():
		hand_bone = seats[1].skeleton.find_bone("Hand.R")
	if volume > 0.01:
		music = AudioStreamPlayer.new()
		music.stream = SCORE
		music.volume_db = linear_to_db(volume) - 3.0
		add_child(music)
		music.play()
	for id: int in FAN:
		var card: Node3D = CARD.new()
		card.setup(id)
		add_child(card)
		fan.append(card)
	dealt = CARD.new()
	dealt.setup(12)
	add_child(dealt)
	var layer := CanvasLayer.new()
	layer.layer = 3
	add_child(layer)
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(overlay)
	overlay.gui_input.connect(_on_overlay_input)
	title = UI.label("Lumo Cards", 44, density, UI.WHITE, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	overlay.add_child(title)
	fade = ColorRect.new()
	fade.color = Color(0.027, 0.041, 0.054, 0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(fade)
	skip = UI.button("Überspringen", "blue", density, 112, 16)
	skip.name = "SkipOpening"
	skip.pressed.connect(finish)
	overlay.add_child(skip)
	resize(density, insets)


## Called after the normal table camera has been framed for this viewport.
func resize(density: float, insets: Rect2) -> void:
	previous_camera = camera.global_transform
	previous_fov = camera.fov
	previous_offset = camera.v_offset
	var size_px := get_viewport().get_visible_rect().size
	skip.reset_size()
	skip.position = Vector2(size_px.x - insets.size.x - skip.size.x - 12 * density, insets.position.y + 12 * density)
	title.position = Vector2(insets.position.x, size_px.y * 0.74)
	title.size = Vector2(size_px.x - insets.position.x - insets.size.x, size_px.y * 0.15)
	_stage()


func _process(delta: float) -> void:
	if closing or not is_instance_valid(camera):
		return
	elapsed = minf(DURATION, elapsed + delta)
	_stage()
	if elapsed >= DURATION:
		finish()


func _stage() -> void:
	var next_shot := 0 if elapsed < PORTRAIT_AT else (1 if elapsed < WIDE_AT else 2)
	if next_shot != shot:
		shot = next_shot
		if shot == 0:
			sound_cue.emit("card_deal")
		elif shot == 1:
			seats[1].react("play")
			seats[0].look_at_point(seats[1].chest())
		else:
			sound_cue.emit("card_play")
			seats[0].look_at_point(previous_camera.origin)
			seats[0].react("wave")
	# Five real cards slide out from under one another, exposing their indices.
	for i in range(fan.size()):
		var amount := smoothstep(0.05 + i * 0.055, 0.85 + i * 0.055, elapsed)
		var spread := (i - 2.0) * amount
		fan[i].position = Vector3(spread * 0.112, ROOM.TABLE_Y + 0.019 + i * 0.008, 0.28 - absf(spread) * 0.026)
		fan[i].rotation.y = -spread * 0.14
	var centre := Vector3(0.01, ROOM.TABLE_Y + 0.055, -0.15)
	if elapsed < PORTRAIT_AT + 0.30:
		throw_origin = seats[1].chest()
		if hand_bone >= 0:
			var rig: Skeleton3D = seats[1].skeleton
			throw_origin = rig.to_global(rig.get_bone_global_pose(hand_bone).origin) - seats[1].global_basis.z * 0.09
	var play := smoothstep(PORTRAIT_AT + 0.30, WIDE_AT - 0.09, elapsed)
	dealt.visible = shot > 0
	dealt.position = throw_origin.lerp(centre, play) + Vector3.UP * 0.30 * sin(PI * play)
	dealt.rotation = Vector3(-0.65 * (1.0 - play), -0.18 + 0.60 * (1.0 - play), -0.17 * sin(PI * play))
	var aspect := overlay.size.x / maxf(1.0, overlay.size.y)
	camera.v_offset = 0.0
	if shot == 0:
		lamp.light_energy = lamp_energy * 0.62
		var t := smoothstep(0.0, PORTRAIT_AT + 0.25, elapsed)
		var at := Vector3(lerpf(-0.048, 0.025, t), ROOM.TABLE_Y + 0.045, 0.26)
		var distance := maxf(0.85, 0.46 / (maxf(aspect, 0.36) * tan(deg_to_rad(22.0))))
		var direction := Vector3(lerpf(-0.32, 0.025, t), 0.89, 0.54).normalized()
		_frame(at + direction * distance, at, 44.0)
	elif shot == 1:
		lamp.light_energy = lamp_energy * 0.86
		var t := smoothstep(PORTRAIT_AT, WIDE_AT, elapsed)
		var at: Vector3 = seats[1].chest() + Vector3.UP * 0.34
		at = at.lerp(centre + Vector3.UP * 0.30, t * 0.37)
		var distance := maxf(1.23, 0.51 / (maxf(aspect, 0.36) * tan(deg_to_rad(22.0))))
		var direction := Vector3(lerpf(0.52, 0.68, t), 0.29, 1.0).normalized()
		_frame(at + direction * distance, at, 44.0)
	else:
		var t := smoothstep(WIDE_AT, DURATION - 0.08, elapsed)
		lamp.light_energy = lamp_energy * lerpf(0.86, 1.0, t)
		var at := Vector3(-0.08, ROOM.TABLE_Y + 0.12, 0.0)
		var start := at + (previous_camera.origin - at) * 0.63 + Vector3(0.36, -0.16, 0)
		var pose := Transform3D(Basis.IDENTITY, start).looking_at(at)
		camera.global_transform = pose.interpolate_with(previous_camera, t)
		camera.v_offset = previous_offset * t
		camera.fov = lerpf(42.0, previous_fov, t)
	title.visible = shot == 2
	title.modulate.a = smoothstep(WIDE_AT + 0.12, WIDE_AT + 0.58, elapsed) * (1.0 - smoothstep(DURATION - 0.45, DURATION, elapsed))
	var cut := maxf(0.0, 1.0 - absf(elapsed - WIDE_AT) / 0.10)
	fade.color.a = cut * 0.32


func _frame(eye: Vector3, target: Vector3, lens: float) -> void:
	camera.global_position = eye
	camera.look_at(target)
	camera.fov = lens


func _on_overlay_input(event: InputEvent) -> void:
	var released: bool = event is InputEventScreenTouch and not event.pressed
	if event is InputEventMouseButton:
		released = event.button_index == MOUSE_BUTTON_LEFT and not event.pressed
	if released:
		overlay.accept_event()
		finish()


func finish() -> void:
	if closing:
		return
	closing = true
	lamp.light_energy = lamp_energy
	if is_instance_valid(music):
		music.stop()
	overlay.hide()
	hide()
	finished.emit()
