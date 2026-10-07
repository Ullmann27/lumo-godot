extends Node3D
const STATE = preload("res://scripts/creative/rhythm_state.gd")
const MUSIC = preload("res://scripts/creative/rhythm_audio.gd")
const KIT = preload("res://scripts/creative/creative_kit.gd")
const RUNTIME = preload("res://scripts/creative/creative_runtime.gd")
const COLORS = [Color("62dcff"), Color("b997ff"), Color("ffc985"), Color("77efbd")]
var model = STATE.new()
var kit = KIT.new()
var previous: Dictionary
var safe_ui: Control
var notes_root: Node3D
var note_nodes: Dictionary = {}
var lamps: Array[MeshInstance3D] = []
var audio: AudioStreamPlayer
var info: Label
var feedback: Label
var progress_bar: ProgressBar
var song_button: Button
var lane_buttons: Array[Button] = []
var menu: PanelContainer
var menu_box: VBoxContainer
var running: bool = false
var paused: bool = false
var finished: bool = false
var song_index: int = 0
var difficulty: int = 0
var result_id: String
var child_key: String


func _ready() -> void:
	previous = RUNTIME.enter(self)
	SceneRouter.current_scene_id = "rhythm"
	child_key = (
		str(SceneRouter.launch_options.get("childKey", "standalone"))
		. validate_filename()
		. substr(0, 80)
	)
	kit.environment(self)
	kit.box(self, Vector3(0, -0.55, -9), Vector3(23, 1, 49), Color("172946"))
	for lane in range(4):
		var x: float = (lane - 1.5) * 2.35
		kit.box(self, Vector3(x, 0.03, -11), Vector3(2.1, 0.12, 34), Color("20374e"))
		for side in [-1.0, 1.0]:
			kit.box(
				self,
				Vector3(x + side * 1.10, 0.13, -11),
				Vector3(0.05, 0.12, 34),
				COLORS[lane],
				true
			)
		lamps.append(kit.box(self, Vector3(x, 0.2, 3), Vector3(2.1, 0.15, 0.9), COLORS[lane], true))
		var crystal := kit.mesh(
			self, kit.SHAPES.crystal(), Vector3(x, 1.5, -27), COLORS[lane], true
		)
		crystal.scale = Vector3(1, 2, 1)
	kit.castle(self, Vector3(0, 0, -38), 1.5)
	for side in [-1.0, 1.0]:
		for i in range(8):
			kit.cylinder(self, Vector3(side * 8, 1.8, 3 - i * 5), 0.18, 3.6, Color("53769c"))
			kit.sphere(
				self, Vector3(side * 8, 3.8, 3 - i * 5), Vector3.ONE * 0.42, COLORS[i % 4], true
			)
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(0, 12, 16)
	camera.look_at(Vector3(0, 0, -8))
	camera.fov = 56
	camera.current = true
	notes_root = Node3D.new()
	add_child(notes_root)
	audio = AudioStreamPlayer.new()
	add_child(audio)
	_ui()
	get_viewport().size_changed.connect(func(): RUNTIME.safe_area(self, safe_ui))
	RUNTIME.safe_area(self, safe_ui)
	model.setup(0)
	_show_start()


func _exit_tree() -> void:
	RUNTIME.restore(self, previous)


func _ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	safe_ui = Control.new()
	safe_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(safe_ui)
	var top := HBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 14
	top.offset_right = -14
	top.offset_top = 12
	safe_ui.add_child(top)
	top.add_child(KIT.button("‹ Spiele", _leave))
	top.add_child(KIT.label("LUMO STERNENRHYTHMUS", 24))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	info = KIT.label("", 18)
	top.add_child(info)
	top.add_child(KIT.button("Ⅱ", func(): _pause(not paused), 52))
	feedback = KIT.label("", 25)
	feedback.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	feedback.position = Vector2(-220, 82)
	feedback.custom_minimum_size = Vector2(440, 42)
	feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	safe_ui.add_child(feedback)
	progress_bar = ProgressBar.new()
	progress_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	progress_bar.position.y = 66
	progress_bar.offset_left = 14
	progress_bar.offset_right = -14
	progress_bar.custom_minimum_size.y = 7
	progress_bar.show_percentage = false
	safe_ui.add_child(progress_bar)
	var bottom := HBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -100
	bottom.offset_bottom = -14
	bottom.offset_left = 120
	bottom.offset_right = -120
	bottom.add_theme_constant_override("separation", 18)
	safe_ui.add_child(bottom)
	for lane in range(4):
		var button: Button = KIT.button(
			["◆  1 / D", "◆  2 / F", "◆  3 / G", "◆  4 / H"][lane], func(): pass
		)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_color_override("font_color", COLORS[lane])
		button.add_theme_font_size_override("font_size", 23)
		button.button_down.connect(func(): _press(lane))
		button.button_up.connect(func(): model.release(lane))
		bottom.add_child(button)
		lane_buttons.append(button)
	menu = PanelContainer.new()
	menu.add_theme_stylebox_override("panel", KIT.panel())
	menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	menu.position = Vector2(-230, -170)
	menu.custom_minimum_size = Vector2(460, 340)
	safe_ui.add_child(menu)
	menu_box = VBoxContainer.new()
	menu_box.add_theme_constant_override("separation", 10)
	menu.add_child(menu_box)


func _clear_menu() -> void:
	for node in menu_box.get_children():
		menu_box.remove_child(node)
		node.queue_free()
	menu.show()


func _show_start() -> void:
	_clear_menu()
	menu_box.add_child(KIT.label("Finde deinen Rhythmus", 27))
	menu_box.add_child(KIT.label("Tippen · Halten · zur nächsten Spur wischen", 16))
	menu_box.add_child(KIT.label("Treffe den Ton an der leuchtenden Ziellinie.", 16))
	song_button = KIT.button("♫  " + STATE.SONGS[song_index].name, _next_song)
	menu_box.add_child(song_button)
	menu_box.add_child(
		KIT.button(
			[
				"Entdecken · großzügiges Timing",
				"Abenteuer · genauer treffen",
				"Sternen-Profi · schnelles Timing"
			][difficulty],
			_next_difficulty
		)
	)
	menu_box.add_child(KIT.button("Los geht’s!", start))
	menu_box.add_child(KIT.button("‹ Zur Spielewelt", _leave))


func _next_song() -> void:
	song_index = (song_index + 1) % 3
	_show_start()


func _next_difficulty() -> void:
	difficulty = (difficulty + 1) % 3
	_show_start()


func start() -> void:
	model.setup(song_index, difficulty)
	result_id = HostBridge.new_result_id()
	for node in notes_root.get_children():
		node.queue_free()
	note_nodes.clear()
	for i in range(model.notes.size()):
		var note: Dictionary = model.notes[i]
		var root := Node3D.new()
		notes_root.add_child(root)
		var x: float = (int(note.lane) - 1.5) * 2.35
		var color: Color = COLORS[int(note.lane)]
		if note.kind == "star":
			var shape := kit.mesh(root, kit.SHAPES.star(), Vector3.ZERO, Color("ffe1a2"), true)
			shape.scale = Vector3.ONE * 0.75
		else:
			kit.box(root, Vector3.ZERO, Vector3(1.5, 0.34, 0.8), color, true)
			if note.kind == "hold":
				kit.box(
					root,
					Vector3(0, 0, -float(note.length) * 4),
					Vector3(0.75, 0.15, float(note.length) * 8),
					color,
					true
				)
			elif note.kind == "slide":
				kit.box(
					root,
					Vector3(0.75, 0.3, -float(note.length) * 4),
					Vector3(0.65, 0.12, float(note.length) * 8),
					Color("e6f8ff"),
					true
				)
		root.position.x = x
		note_nodes[i] = root
	audio.stream = MUSIC.create(model.song, model.duration)
	running = true
	paused = false
	finished = false
	menu.hide()
	feedback.text = "Mach dich bereit!"


func _press(lane: int) -> void:
	if not running or paused:
		return
	if model.press(lane):
		lamps[lane].scale.y = 2.6
	feedback.text = model.judgement


func _input(event: InputEvent) -> void:
	if event is InputEventKey and not event.echo:
		var lane: int = [KEY_D, KEY_F, KEY_G, KEY_H].find(event.keycode)
		if lane >= 0:
			if event.pressed:
				_press(lane)
			else:
				model.release(lane)
	if event is InputEventScreenDrag and running and not paused:
		for lane in range(4):
			if lane_buttons[lane].get_global_rect().has_point(event.position):
				_press(lane)
	if event.is_action_pressed("ui_cancel"):
		_pause(not paused)


func _process(delta: float) -> void:
	if not running or paused:
		return
	var old_time: float = model.time
	model.advance(delta)
	if old_time < 0 and model.time >= 0:
		audio.play(model.time)
	for i in note_nodes:
		var note: Dictionary = model.notes[int(i)]
		var node: Node3D = note_nodes[i]
		node.position.z = 3.0 - (float(note.time) - model.time) * 8
		node.position.y = 0.38
		node.visible = (
			int(note.state) in [0, 1, 4] and node.position.z >= -33 and node.position.z <= 6
		)
		if int(note.state) == 1:
			node.position.z = 3
	for lamp in lamps:
		lamp.scale.y = lerpf(lamp.scale.y, 1.0, delta * 10)
	info.text = "%d Punkte · %d× Combo" % [int(model.score), model.combo]
	feedback.text = model.judgement if model.time > 0 else "Start in %d …" % ceili(-model.time)
	progress_bar.value = clampf(model.time / model.duration * 100, 0, 100)
	if model.time >= model.duration:
		_finish()


func _finish() -> void:
	running = false
	finished = true
	audio.stop()
	var earned := model.stars()
	var config := ConfigFile.new()
	var path := "user://lumo_rhythm_" + child_key + ".cfg"
	config.load(path)
	var old: int = int(config.get_value(str(model.song.id), "best", 0))
	config.set_value(str(model.song.id), "best", maxi(old, int(model.score)))
	config.save(path)
	if earned > 0:
		HostBridge.reward(
			{
				"resultId": result_id,
				"game": "rhythm",
				"status": "completed",
				"stars": earned,
				"xp": 12 + earned * 4
			}
		)
	_clear_menu()
	menu_box.add_child(KIT.label("Deine Sterne funkeln!", 28))
	menu_box.add_child(
		KIT.label(
			(
				"%d Sterne · %d Punkte · %d%% getroffen"
				% [earned, int(model.score), roundi(model.accuracy() * 100)]
			),
			20
		)
	)
	menu_box.add_child(
		KIT.label(
			"Längste Combo: %d · Bestwert: %d" % [model.best_combo, maxi(old, int(model.score))], 17
		)
	)
	menu_box.add_child(KIT.button("Noch einmal spielen", start))
	menu_box.add_child(KIT.button("Anderes Lied", _show_start))
	menu_box.add_child(KIT.button("Zur Spielewelt", _leave))


func _pause(value: bool) -> void:
	if not running:
		return
	paused = value
	audio.stream_paused = value
	if value:
		_clear_menu()
		menu_box.add_child(KIT.label("Dein Lied wartet", 27))
		menu_box.add_child(KIT.button("Weiter im Takt", func(): _pause(false)))
		menu_box.add_child(KIT.button("Lied neu starten", start))
		menu_box.add_child(KIT.button("Zur Spielewelt", _leave))
	else:
		menu.hide()


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_GO_BACK_REQUEST] and running:
		_pause(true)


func _leave() -> void:
	audio.stop()
	SceneRouter.goto("games")
