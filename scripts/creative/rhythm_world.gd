extends Node3D
const STATE = preload("res://scripts/creative/rhythm_state.gd")
const MUSIC = preload("res://scripts/creative/rhythm_audio.gd")
const KIT = preload("res://scripts/creative/creative_kit.gd")
const RUNTIME = preload("res://scripts/creative/creative_runtime.gd")
const STAGE_ART = preload("res://scripts/creative/rhythm_stage_art.gd")
const FOX = preload("res://scripts/games/kart_vehicle.gd")
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
var performer_fox: Node3D
var hit_burst: MeshInstance3D
var cheer_burst: MeshInstance3D
var cheer_until: float = -100.0


func _ready() -> void:
	previous = RUNTIME.enter(self)
	SceneRouter.current_scene_id = "rhythm"
	child_key = (
		str(SceneRouter.launch_options.get("childKey", "standalone"))
		. validate_filename()
		. substr(0, 80)
	)
	kit.environment(self, LumoEnvironmentCreativePresets.PRESET_RHYTHM_PARTY)
	kit.box(self, Vector3(0, -0.55, -9), Vector3(23, 1, 49), Color("12081f"))
	var stage: MeshInstance3D = kit.box(
		self, Vector3(0, 0.005, -11), Vector3(12.4, 0.06, 36), Color("1a0e32")
	)
	stage.material_override = BuildVoxelStyle.material("plain", Color("22143c"))
	for lane in range(4):
		var x: float = (lane - 1.5) * 2.35
		kit.box(self, Vector3(x, 0.04, -11), Vector3(2.05, 0.1, 34), Color("1c1438"))
		for side in [-1.0, 1.0]:
			kit.box(
				self,
				Vector3(x + side * 1.08, 0.16, -11),
				Vector3(0.09, 0.2, 34),
				COLORS[lane],
				true
			)
		var pad := CylinderMesh.new()
		pad.top_radius = 0.95
		pad.bottom_radius = 0.95
		pad.height = 0.16
		pad.radial_segments = 24
		lamps.append(kit.mesh(self, pad, Vector3(x, 0.2, 3), COLORS[lane], true))
		_speaker(Vector3(x, 0, -26.5), COLORS[lane], 0.72)
	kit.castle(self, Vector3(0, 0, -38), 1.5)
	_eq_wall()
	STAGE_ART.apply(self)
	_performer()
	for side in [-1.0, 1.0]:
		_speaker(Vector3(side * 8.6, 0, -18), COLORS[0 if side < 0 else 1], 1.15)
		for i in range(8):
			var column: MeshInstance3D = kit.cylinder(
				self, Vector3(side * 8, 1.8, 3 - i * 5), 0.2, 3.6, Color("2a1848")
			)
			column.material_override = BuildVoxelStyle.material("plain", Color("2a1848"))
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
	menu.position = Vector2(-240, -190)
	menu.custom_minimum_size = Vector2(480, 380)
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
	menu_box.add_child(KIT.label("Lange Combos bringen Extra-Punkte und einen Freudentanz!", 16))
	song_button = KIT.button(_song_label(), _next_song)
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


func _song_label() -> String:
	return "♫  %s  ·  %d/%d" % [STATE.SONGS[song_index].name, song_index + 1, STATE.SONGS.size()]


func _next_song() -> void:
	song_index = (song_index + 1) % STATE.SONGS.size()
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
			shape.scale = Vector3.ONE * 0.9
			_note_disc(root, Vector3(0, -0.1, 0), Color("ffe1a2"), 0.38)
		else:
			_note_disc(root, Vector3.ZERO, color, 0.72)
			if note.kind == "hold":
				kit.box(
					root,
					Vector3(0, 0, -float(note.length) * 4),
					Vector3(0.88, 0.2, float(note.length) * 8),
					color,
					true
				)
			elif note.kind == "slide":
				kit.box(
					root,
					Vector3(0.85, 0.28, -float(note.length) * 4),
					Vector3(0.72, 0.14, float(note.length) * 8),
					Color("e6f8ff"),
					true
				)
				var tip: MeshInstance3D = kit.box(
					root,
					Vector3(1.45, 0.32, 0),
					Vector3(0.55, 0.2, 0.55),
					Color("e6f8ff"),
					true
				)
				tip.rotation_degrees = Vector3(0, 45, 0)
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
		_burst_hit(lane)
		_maybe_cheer()
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
	_animate_performer()
	_fade_bursts(delta)
	if not running or paused:
		return
	var old_time: float = model.time
	model.advance(delta)
	_maybe_cheer()
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
	info.text = "%d Punkte · %d× Combo" % [model.total_score(), model.combo]
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
	var points: int = model.total_score()
	config.set_value(str(model.song.id), "best", maxi(old, points))
	config.save(path)
	if earned > 0:
		HostBridge.reward(
			{
				"resultId": result_id,
				"game": "rhythm",
				"status": "completed",
				"stars": earned,
				"xp": model.reward_xp()
			}
		)
	_clear_menu()
	menu_box.add_child(KIT.label("Deine Sterne funkeln!", 28))
	menu_box.add_child(
		KIT.label(
			(
				"%d Sterne · %d Punkte · %d%% getroffen"
				% [earned, points, roundi(model.accuracy() * 100)]
			),
			20
		)
	)
	menu_box.add_child(
		KIT.label(
			"Längste Combo: %d · Bestwert: %d" % [model.best_combo, maxi(old, points)], 17
		)
	)
	if model.combo_bonus > 0:
		menu_box.add_child(
			KIT.label(
				"Combo-Bonus: +%d Punkte · +%d XP" % [int(model.combo_bonus), model.combo_xp()],
				17
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


func _performer() -> void:
	performer_fox = FOX.new()
	add_child(performer_fox)
	performer_fox.configure_companion("fox")
	performer_fox.position = Vector3(0, 0.48, -21.8)
	performer_fox.scale = Vector3.ONE * 2.05
	performer_fox.rotation_degrees = Vector3(0, 180, 0)
	hit_burst = kit.mesh(self, kit.SHAPES.star(), Vector3(0, 1.15, 3), Color("ffe1a2"), true)
	hit_burst.scale = Vector3.ZERO
	hit_burst.visible = false
	cheer_burst = kit.mesh(self, kit.SHAPES.star(), Vector3(0, 2.35, 2.2), Color("ffd36a"), true)
	cheer_burst.scale = Vector3.ZERO
	cheer_burst.visible = false


func _animate_performer() -> void:
	if performer_fox == null:
		return
	var t: float = model.time if running else float(Time.get_ticks_msec()) * 0.001
	var mood := "idle"
	if running and (model.time < cheer_until or model.combo >= 20):
		mood = "cheer"
	elif running and model.combo >= 5:
		mood = "walk"
	performer_fox.set_companion_pose(t, mood)


func _burst_hit(lane: int) -> void:
	if hit_burst == null:
		return
	hit_burst.position = Vector3((float(lane) - 1.5) * 2.35, 1.15, 3.0)
	hit_burst.scale = Vector3.ONE * 0.85
	hit_burst.visible = true


func _maybe_cheer() -> void:
	if model.last_cheer <= 0:
		return
	if cheer_burst != null:
		cheer_burst.position = Vector3(0, 2.35, 2.2)
		cheer_burst.scale = Vector3.ONE * (1.15 if model.last_cheer < 20 else 1.65)
		cheer_burst.visible = true
	cheer_until = model.time + 1.8
	model.last_cheer = 0


func _fade_bursts(delta: float) -> void:
	for burst in [hit_burst, cheer_burst]:
		if burst == null or not burst.visible:
			continue
		burst.scale = burst.scale.lerp(Vector3.ZERO, clampf(delta * 6.0, 0.0, 1.0))
		if burst.scale.x < 0.05:
			burst.visible = false
			burst.scale = Vector3.ZERO


func _note_disc(root: Node3D, at: Vector3, color: Color, radius: float) -> MeshInstance3D:
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.18
	disc.radial_segments = 20
	return kit.mesh(root, disc, at, color, true)


func _speaker(at: Vector3, color: Color, scale_factor: float) -> void:
	var cabinet: MeshInstance3D = kit.box(
		self, at + Vector3(0, 1.55 * scale_factor, 0), Vector3(2.1, 3.1, 1.45) * scale_factor, Color("141022")
	)
	cabinet.material_override = BuildVoxelStyle.material("plain", Color("1a142c"))
	var woofer := CylinderMesh.new()
	woofer.top_radius = 0.72 * scale_factor
	woofer.bottom_radius = 0.72 * scale_factor
	woofer.height = 0.18
	woofer.radial_segments = 20
	var cone: MeshInstance3D = kit.mesh(
		self, woofer, at + Vector3(0, 1.15 * scale_factor, 0.72 * scale_factor), color, true
	)
	cone.rotation_degrees = Vector3(90, 0, 0)
	var tweeter := CylinderMesh.new()
	tweeter.top_radius = 0.32 * scale_factor
	tweeter.bottom_radius = 0.32 * scale_factor
	tweeter.height = 0.14
	tweeter.radial_segments = 16
	var top: MeshInstance3D = kit.mesh(
		self, tweeter, at + Vector3(0, 2.35 * scale_factor, 0.7 * scale_factor), Color("e6f8ff"), true
	)
	top.rotation_degrees = Vector3(90, 0, 0)
	kit.box(
		self,
		at + Vector3(0, 3.2 * scale_factor, 0),
		Vector3(1.6, 0.16, 0.9) * scale_factor,
		color,
		true
	)


func _eq_wall() -> void:
	var xforms: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 221409
	for i in range(22):
		var height: float = 0.7 + float((i * 7) % 11) * 0.28
		var at := Vector3(-6.6 + float(i) * 0.62, height * 0.5, -32.4)
		xforms.append(Transform3D(Basis.from_scale(Vector3(0.4, height, 0.26)), at))
	var bar := BoxMesh.new()
	bar.size = Vector3.ONE
	BuildVoxelStyle.multimesh(self, "EqBars", bar, kit.material(Color("8a6cff"), true), xforms)

