extends Node3D
const STATE = preload("res://scripts/creative/rhythm_state.gd")
const TOUR = preload("res://scripts/creative/rhythm_tour.gd")
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
var pause_button: Button
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
var tour = TOUR.new()
var tour_mode := false
var tour_stage := 0
var round_stage := -1
var round_difficulty := 0
var progress_config := ConfigFile.new()
var progress_path := ""
var progress_read_only := false
var last_tour_result: Dictionary = {}
var goal_banner: Label
var top: HBoxContainer
var bottom: HBoxContainer
var menu_scroll: ScrollContainer
var touch_lanes: Dictionary = {}
var key_lanes: Dictionary = {}
var resume_countdown := 0.0
var audio_latency := 0.0
var use_audio_clock := false
var tour_beacons: Array[MeshInstance3D] = []


func _ready() -> void:
	previous = RUNTIME.enter(self, true)
	SceneRouter.current_scene_id = "rhythm"
	child_key = (
		str(SceneRouter.launch_options.get("childKey", "standalone"))
		. validate_filename()
		. substr(0, 80)
	)
	progress_path = "user://lumo_rhythm_" + child_key + ".cfg"
	var load_error := progress_config.load(progress_path)
	progress_read_only = load_error not in [OK, ERR_FILE_NOT_FOUND]
	if not progress_read_only:
		progress_read_only = not tour.read_from(progress_config)
	kit.environment(self, LumoEnvironmentCreativePresets.PRESET_RHYTHM_PARTY)
	kit.box(self, Vector3(0, -0.55, -9), Vector3(23, 1, 49), Color("12081f"))
	var stage: MeshInstance3D = kit.box(
		self, Vector3(0, 0.005, -11), Vector3(12.4, 0.06, 36), Color("1a0e32")
	)
	stage.material_override = BuildVoxelStyle.material("plain", Color("22143c"))
	var speaker_specs: Array[Dictionary] = []
	var lane_floors: Array[Transform3D] = []
	var lane_edges: Array = [[], [], [], []]
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	for lane in range(4):
		var x: float = (lane - 1.5) * 2.35
		lane_floors.append(
			Transform3D(Basis.from_scale(Vector3(2.05, 0.1, 34)), Vector3(x, 0.04, -11))
		)
		for side in [-1.0, 1.0]:
			lane_edges[lane].append(
				Transform3D(
					Basis.from_scale(Vector3(0.09, 0.2, 34)), Vector3(x + side * 1.08, 0.16, -11)
				)
			)
		var pad := CylinderMesh.new()
		pad.top_radius = 0.95
		pad.bottom_radius = 0.95
		pad.height = 0.16
		pad.radial_segments = 24
		lamps.append(kit.mesh(self, pad, Vector3(x, 0.2, 3), COLORS[lane], true))
		speaker_specs.append({"at": Vector3(x, 0, -26.5), "color": COLORS[lane], "scale": 0.72})
	BuildVoxelStyle.multimesh(self, "RhythmLanes", box, kit.material(Color("1c1438")), lane_floors)
	for lane in range(4):
		var edges: Array[Transform3D] = []
		edges.assign(lane_edges[lane])
		BuildVoxelStyle.multimesh(
			self, "RhythmLaneEdge%d" % lane, box, kit.material(COLORS[lane], true), edges
		)
	# Schloss bleibt weg: die LED-Wand verdeckt es in der Startansicht vollständig.
	_eq_wall()
	STAGE_ART.apply(self)
	_performer()
	_tour_landmarks()
	for side in [-1.0, 1.0]:
		speaker_specs.append(
			{
				"at": Vector3(side * 8.6, 0, -18),
				"color": COLORS[0 if side < 0 else 1],
				"scale": 1.15
			}
		)
	_batch_speakers(speaker_specs)
	_batch_columns()
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
	get_viewport().size_changed.connect(_layout)
	_layout()
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
	top = HBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 14
	top.offset_right = -14
	top.offset_top = 12
	safe_ui.add_child(top)
	top.add_child(KIT.button("‹ Spiele", _leave))
	var title := KIT.label("LUMO RHYTHM PARTY", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top.add_child(title)
	info = KIT.label("", 17)
	info.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	info.position.y = 66
	info.offset_left = 14
	info.offset_right = -14
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	safe_ui.add_child(info)
	pause_button = KIT.button("Ⅱ", func(): _pause(not paused), 52)
	pause_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(pause_button)
	feedback = KIT.label("", 22)
	feedback.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	feedback.position.y = 102
	feedback.offset_left = 14
	feedback.offset_right = -14
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	safe_ui.add_child(feedback)
	progress_bar = ProgressBar.new()
	progress_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	progress_bar.position.y = 91
	progress_bar.offset_left = 14
	progress_bar.offset_right = -14
	progress_bar.custom_minimum_size.y = 7
	progress_bar.show_percentage = false
	safe_ui.add_child(progress_bar)
	goal_banner = KIT.label("", 16)
	goal_banner.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	goal_banner.offset_left = 14
	goal_banner.offset_right = -14
	goal_banner.offset_top = -158
	goal_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	goal_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	safe_ui.add_child(goal_banner)
	bottom = HBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -100
	bottom.offset_bottom = -14
	bottom.offset_left = 14
	bottom.offset_right = -14
	bottom.add_theme_constant_override("separation", 8)
	safe_ui.add_child(bottom)
	for lane in range(4):
		var button: Button = KIT.button(
			str(lane + 1), func(): pass, 64
		)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_color_override("font_color", COLORS[lane])
		button.add_theme_font_size_override("font_size", 23)
		# Real pointer ownership is handled below; mouse emulation cannot leave
		# a ghost-held lane or prevent a second finger from holding another.
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bottom.add_child(button)
		lane_buttons.append(button)
	menu = PanelContainer.new()
	menu.add_theme_stylebox_override("panel", KIT.panel())
	safe_ui.add_child(menu)
	menu_scroll = ScrollContainer.new()
	menu_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu.add_child(menu_scroll)
	menu_box = VBoxContainer.new()
	menu_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_box.add_theme_constant_override("separation", 10)
	menu_scroll.add_child(menu_box)


func _clear_menu() -> void:
	for node in menu_box.get_children():
		if node is CanvasItem:
			node.hide()
		node.queue_free()
	menu.show()
	goal_banner.hide()
	call_deferred("_layout")


func _show_start() -> void:
	_clear_menu()
	menu_box.add_child(_menu_text("Lumos Sternentour" if tour_mode else "Finde deinen Rhythmus", 27))
	menu_box.add_child(KIT.button("Modus: Sternentour" if tour_mode else "Modus: Freies Spielen", _toggle_mode))
	if tour_mode:
		var stage: Dictionary = tour.stage(tour_stage, difficulty)
		menu_box.add_child(_menu_text("%d/4 Bühnen geschafft · %s" % [tour.cleared[difficulty], STATE.DIFFICULTY_NAMES[difficulty]], 18))
		menu_box.add_child(_menu_text(str(stage.story), 16))
		menu_box.add_child(_menu_text(tour.goal_text(tour_stage, difficulty), 17))
		song_button = KIT.button("Bühne %d: %s" % [tour_stage + 1, stage.title], _next_song)
		menu_box.add_child(song_button)
		menu_box.add_child(_menu_text("Dein bester Versuch: %d/40 Töne" % int(stage.best_hits), 15))
	else:
		menu_box.add_child(_menu_text("Tippen · Halten · zur Nachbarspur wischen", 16))
		menu_box.add_child(_menu_text("Treffe den Ton an der leuchtenden Ziellinie. Jedes Lied hat sein eigenes Muster.", 16))
		song_button = KIT.button(_song_label(), _next_song)
		menu_box.add_child(song_button)
	menu_box.add_child(KIT.button([
		"Entdecken · mehr Zeit", "Abenteuer · flüssige Folgen", "Sternen-Profi · schneller Takt"
	][difficulty], _next_difficulty))
	if progress_read_only:
		menu_box.add_child(_menu_text("Dein bisheriger Spielstand ist nicht lesbar und bleibt unverändert. Freies Spielen ist möglich.", 15))
	var play := KIT.button("Los geht’s!", start)
	play.disabled = progress_read_only and tour_mode
	menu_box.add_child(play)
	menu_box.add_child(KIT.button("‹ Zur Spielewelt", _leave))
	_update_tour_landmarks()
	call_deferred("_layout")


func _menu_text(text: String, size := 18) -> Label:
	var label := KIT.label(text, size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _toggle_mode() -> void:
	tour_mode = not tour_mode
	if tour_mode:
		tour_stage = tour.next_stage(difficulty)
	_show_start()


func _song_label() -> String:
	return "♫  %s  ·  %d/%d" % [STATE.SONGS[song_index].name, song_index + 1, STATE.SONGS.size()]


func _next_song() -> void:
	if tour_mode:
		tour_stage = (tour_stage + 1) % mini(tour.cleared[difficulty] + 1, TOUR.STAGES.size())
	else:
		song_index = (song_index + 1) % STATE.SONGS.size()
	_show_start()


func _next_difficulty() -> void:
	difficulty = (difficulty + 1) % 3
	if tour_mode:
		tour_stage = tour.next_stage(difficulty)
	_show_start()


func start() -> void:
	if tour_mode and progress_read_only:
		return
	round_stage = tour_stage if tour_mode else -1
	round_difficulty = difficulty
	if tour_mode:
		song_index = int(TOUR.STAGES[tour_stage].song)
	model.setup(song_index, difficulty)
	touch_lanes.clear()
	key_lanes.clear()
	resume_countdown = 0.0
	audio.stop()
	audio.stream_paused = false
	audio_latency = AudioServer.get_output_latency()
	use_audio_clock = AudioServer.get_driver_name() != "Dummy"
	last_tour_result.clear()
	goal_banner.text = tour.goal_text(round_stage, round_difficulty) if round_stage >= 0 else ""
	_update_tour_landmarks()
	cheer_until = -100.0
	for burst in [hit_burst, cheer_burst]:
		if burst != null:
			burst.visible = false
			burst.scale = Vector3.ZERO
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
				var end := Vector3((int(note.target) - int(note.lane)) * 2.35, 0.28, -float(note.length) * 8)
				var origin := Vector3(0, 0.28, 0)
				var beam := kit.box(root, (origin + end) * 0.5, Vector3(0.28, 0.14, origin.distance_to(end)), Color("e6f8ff"), true)
				beam.look_at_from_position(beam.position, end)
				_note_disc(root, end, COLORS[int(note.target)], 0.42)
				root.set_meta("slide_target_lane", int(note.target))
		root.position.x = x
		note_nodes[i] = root
	audio.stream = MUSIC.create(model.song, model.duration)
	running = true
	paused = false
	finished = false
	menu.hide()
	goal_banner.visible = round_stage >= 0
	feedback.text = "Mach dich bereit!"


func _press(lane: int) -> void:
	if not running or paused or menu.visible:
		return
	_sync_music_time(0.0)
	if model.press(lane):
		lamps[lane].scale.y = 2.6
		_burst_hit(lane)
		_maybe_cheer()
	feedback.text = model.judgement


func _input(event: InputEvent) -> void:
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event.is_action_pressed("ui_cancel"):
		_pause(not paused)
		return
	var pause_press: bool = (event is InputEventScreenTouch and event.pressed) or (
		event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	)
	if running and pause_press and pause_button.get_global_rect().has_point(event.position):
		_pause(not paused)
		get_viewport().set_input_as_handled()
		return
	if not running or paused or menu.visible:
		return
	if event is InputEventKey and not event.echo:
		var lane: int = [KEY_D, KEY_F, KEY_G, KEY_H].find(event.keycode)
		if lane >= 0:
			if event.pressed:
				key_lanes[lane] = true
				_press(lane)
			else:
				key_lanes.erase(lane)
				_release_unused_lane(lane)
	elif event is InputEventScreenTouch:
		if event.pressed:
			var lane := _lane_at(event.position)
			if lane >= 0:
				_set_pointer_lane(event.index, lane)
				get_viewport().set_input_as_handled()
		elif touch_lanes.has(event.index):
			_set_pointer_lane(event.index, -1)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and touch_lanes.has(event.index):
		_set_pointer_lane(event.index, _lane_at(event.position), true)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _lane_at(event.position) >= 0:
			_set_pointer_lane(-1, _lane_at(event.position))
		elif not event.pressed and touch_lanes.has(-1):
			_set_pointer_lane(-1, -1)
	elif event is InputEventMouseMotion and touch_lanes.has(-1):
		_set_pointer_lane(-1, _lane_at(event.position), true)


func _lane_at(point: Vector2) -> int:
	for lane in range(4):
		if lane_buttons[lane].get_global_rect().has_point(point):
			return lane
	return -1


func _set_pointer_lane(pointer_id: int, lane: int, keep_pointer := false) -> void:
	var previous_lane := int(touch_lanes.get(pointer_id, -1))
	if previous_lane == lane:
		if lane < 0 and not keep_pointer:
			touch_lanes.erase(pointer_id)
		return
	touch_lanes.erase(pointer_id)
	if previous_lane >= 0:
		_release_unused_lane(previous_lane)
	if lane >= 0 or keep_pointer:
		touch_lanes[pointer_id] = lane
	if lane >= 0:
		_press(lane)


func _release_unused_lane(lane: int) -> void:
	if not touch_lanes.values().has(lane) and not key_lanes.has(lane):
		_sync_music_time(0.0)
		model.release(lane)


func _sync_music_time(delta: float) -> void:
	if resume_countdown > 0:
		return
	if model.time < 0 or not use_audio_clock:
		var old_time: float = model.time
		model.advance(delta)
		if old_time < 0 and model.time >= 0:
			audio.play(maxf(0, model.time))
	elif audio.playing:
		# Godot's documented audio clock compensates output/mixing latency.
		# Ignore a backward sample rather than rewinding note judgement.
		var heard := audio.get_playback_position() + AudioServer.get_time_since_last_mix() - audio_latency
		model.advance(maxf(0, heard - model.time))
	else:
		# A missing audio device must not lock an otherwise playable round.
		model.advance(delta)


func _process(delta: float) -> void:
	_animate_performer()
	_fade_bursts(delta)
	if not running or paused:
		return
	if resume_countdown > 0:
		resume_countdown = maxf(0, resume_countdown - delta)
		feedback.text = "Weiter in %d … lange Töne wieder halten" % ceili(resume_countdown)
		if resume_countdown <= 0:
			audio.stream_paused = false
		return
	_sync_music_time(delta)
	_maybe_cheer()
	_draw_notes()
	for lamp in lamps:
		lamp.scale.y = lerpf(lamp.scale.y, 1.0, minf(1, delta * 10))
	info.text = "%d Punkte · %d× Combo · %s" % [model.total_score(), model.combo, STATE.DIFFICULTY_NAMES[round_difficulty]]
	feedback.text = model.judgement if model.time > 0 else "Start in %d …" % ceili(-model.time)
	progress_bar.value = clampf(model.time / model.duration * 100, 0, 100)
	if round_stage >= 0:
		goal_banner.text = "%s · %d/%d Töne" % [TOUR.STAGES[round_stage].title, model.hits, tour.stage(round_stage, round_difficulty).hits]
	if model.time >= model.duration:
		_finish()


func _draw_notes() -> void:
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


func _finish() -> void:
	if finished:
		return
	running = false
	finished = true
	audio.stop()
	var earned := model.stars()
	_reload_progress()
	var old: int = int(progress_config.get_value(str(model.song.id), "best", 0))
	var points: int = model.total_score()
	progress_config.set_value(str(model.song.id), "best", maxi(old, points))
	if round_stage >= 0:
		last_tour_result = tour.record(round_stage, round_difficulty, model.notes, result_id)
	var saved := _save_progress()
	_update_tour_landmarks()
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
	menu_box.add_child(_menu_text("Deine Sterne funkeln!", 28))
	if round_stage >= 0:
		var result_text := "Geschafft! Die nächste Bühne ist offen." if bool(last_tour_result.get("passed", false)) else "Übe in deinem Tempo. Dein bester Versuch bleibt gespeichert."
		if bool(last_tour_result.get("complete", false)):
			result_text = "Tour geschafft! Alle vier Bühnen leuchten. Andere Stufen warten auf dich."
		menu_box.add_child(_menu_text(result_text, 19))
		menu_box.add_child(_menu_text(tour.goal_text(round_stage, round_difficulty), 16))
	if not saved:
		menu_box.add_child(_menu_text("Der Fortschritt ist noch nicht gespeichert. Dein alter Spielstand bleibt erhalten.", 16))
		if not progress_read_only:
			menu_box.add_child(KIT.button("Speichern erneut versuchen", _retry_save))
	menu_box.add_child(
		_menu_text(
			(
				"%d Sterne · %d Punkte · %d%% getroffen"
				% [earned, points, roundi(model.accuracy() * 100)]
			),
			20
		)
	)
	menu_box.add_child(
		_menu_text("Längste Combo: %d · Bestwert: %d" % [model.best_combo, maxi(old, points)], 17)
	)
	if model.combo_bonus > 0:
		menu_box.add_child(
			_menu_text(
				"Combo-Bonus: +%d Punkte · +%d XP" % [int(model.combo_bonus), model.combo_xp()], 17
			)
		)
	menu_box.add_child(KIT.button("Noch einmal spielen", start))
	menu_box.add_child(KIT.button("Zur Tourkarte" if tour_mode else "Anderes Lied", _return_to_map))
	menu_box.add_child(KIT.button("Zur Spielewelt", _leave))


func _pause(value: bool) -> void:
	if not running:
		return
	paused = value
	audio.stream_paused = true
	if value:
		touch_lanes.clear()
		key_lanes.clear()
		model.held.clear()
		resume_countdown = 0.0
		_clear_menu()
		menu_box.add_child(KIT.label("Dein Lied wartet", 27))
		menu_box.add_child(KIT.button("Weiter im Takt", func(): _pause(false)))
		menu_box.add_child(KIT.button("Lied neu starten", start))
		menu_box.add_child(KIT.button("Zur Spielewelt", _leave))
	else:
		resume_countdown = 2.0
		menu.hide()
		goal_banner.visible = round_stage >= 0


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_GO_BACK_REQUEST] and running:
		_pause(true)


func _leave() -> void:
	audio.stop()
	SceneRouter.goto("games")


func _layout() -> void:
	if not is_inside_tree() or not is_instance_valid(menu):
		return
	RUNTIME.safe_area(self, safe_ui)
	var available := safe_ui.size
	menu.size = Vector2(minf(580, available.x - 28), maxf(180, minf(590, available.y - 170)))
	menu.position = (available - menu.size) * 0.5
	for lane in range(lane_buttons.size()):
		lane_buttons[lane].text = str(lane + 1) if available.x < 650 else ["1 / D", "2 / F", "3 / G", "4 / H"][lane]
	feedback.add_theme_font_size_override("font_size", 18 if available.y < 500 else 22)
	goal_banner.visible = round_stage >= 0 and running and not menu.visible


func _return_to_map() -> void:
	if tour_mode:
		tour_stage = tour.next_stage(difficulty)
	goal_banner.text = ""
	_show_start()


func _reload_progress() -> void:
	var disk := ConfigFile.new()
	var error := disk.load(progress_path)
	if error == ERR_FILE_NOT_FOUND:
		return
	if error != OK:
		progress_read_only = true
		return
	var disk_tour = TOUR.new()
	if not disk_tour.read_from(disk):
		progress_read_only = true
		return
	# Preserve scores written while this round was open. Tour progress is
	# monotonic and can also include an earlier failed save still in memory.
	progress_config = disk
	for index in range(3):
		tour.cleared[index] = maxi(tour.cleared[index], disk_tour.cleared[index])
	for key in disk_tour.best_hits:
		tour.best_hits[key] = maxi(int(tour.best_hits.get(key, 0)), int(disk_tour.best_hits[key]))
	for key in disk_tour.attempts:
		tour.attempts[key] = maxi(int(tour.attempts.get(key, 0)), int(disk_tour.attempts[key]))


func _save_progress() -> bool:
	if progress_read_only:
		return false
	tour.write_to(progress_config)
	if progress_config.save(progress_path + ".tmp") != OK:
		return false
	return DirAccess.rename_absolute(progress_path + ".tmp", progress_path) == OK


func _retry_save() -> void:
	feedback.text = "Dein Fortschritt ist gespeichert." if _save_progress() else "Speichern noch nicht möglich. Bitte erneut versuchen."


func _tour_landmarks() -> void:
	for index in range(TOUR.STAGES.size()):
		var at := Vector3(-10.5 if index % 2 == 0 else 10.5, 0, -3 - (index / 2) * 12)
		kit.cylinder(self, at + Vector3.UP * 0.3, 1.15, 0.6, Color("203457"))
		var star := kit.mesh(self, kit.SHAPES.star(), at + Vector3.UP * 2.6, COLORS[index], true)
		star.scale = Vector3.ONE * 1.4
		star.material_override = star.material_override.duplicate()
		tour_beacons.append(star)
		var sign := Label3D.new()
		sign.text = str(TOUR.STAGES[index].title)
		sign.position = at + Vector3.UP * 4.1
		sign.font_size = 48
		sign.pixel_size = 0.012
		sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sign.outline_size = 12
		add_child(sign)


func _update_tour_landmarks() -> void:
	for index in range(tour_beacons.size()):
		var star := tour_beacons[index]
		var completed: bool = index < tour.cleared[difficulty]
		var material := star.material_override as StandardMaterial3D
		material.albedo_color = COLORS[index] if completed else Color("64728b")
		material.emission = COLORS[index]
		material.emission_energy_multiplier = 2.0 if completed else 0.12
		star.scale = Vector3.ONE * (1.65 if completed else 1.1)
		star.set_meta("tour_completed", completed)


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


func _batch_speakers(specs: Array[Dictionary]) -> void:
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.0
	cyl.height = 1.0
	cyl.radial_segments = 20
	var cabinets: Array[Transform3D] = []
	var tweeters: Array[Transform3D] = []
	var woofers: Array = [[], [], [], []]
	var tops: Array = [[], [], [], []]
	for spec in specs:
		var at: Vector3 = spec.at
		var color: Color = spec.color
		var scale_factor: float = float(spec.scale)
		var lane: int = maxi(0, COLORS.find(color))
		cabinets.append(
			Transform3D(
				Basis.from_scale(Vector3(2.1, 3.1, 1.45) * scale_factor),
				at + Vector3(0, 1.55 * scale_factor, 0)
			)
		)
		var face := Basis.from_euler(Vector3(deg_to_rad(90), 0, 0))
		var woofer_basis := (
			face * Basis.from_scale(Vector3(0.72 * scale_factor, 0.18, 0.72 * scale_factor))
		)
		woofers[lane].append(
			Transform3D(woofer_basis, at + Vector3(0, 1.15 * scale_factor, 0.72 * scale_factor))
		)
		var tweeter_basis := (
			face * Basis.from_scale(Vector3(0.32 * scale_factor, 0.14, 0.32 * scale_factor))
		)
		tweeters.append(
			Transform3D(tweeter_basis, at + Vector3(0, 2.35 * scale_factor, 0.7 * scale_factor))
		)
		tops[lane].append(
			Transform3D(
				Basis.from_scale(Vector3(1.6, 0.16, 0.9) * scale_factor),
				at + Vector3(0, 3.2 * scale_factor, 0)
			)
		)
	BuildVoxelStyle.multimesh(
		self, "RhythmCabinets", box, BuildVoxelStyle.material("plain", Color("1a142c")), cabinets
	)
	BuildVoxelStyle.multimesh(
		self, "RhythmTweeters", cyl, kit.material(Color("e6f8ff"), true), tweeters
	)
	for lane in range(4):
		var woofer_x: Array[Transform3D] = []
		woofer_x.assign(woofers[lane])
		BuildVoxelStyle.multimesh(
			self, "RhythmWoofers%d" % lane, cyl, kit.material(COLORS[lane], true), woofer_x
		)
		var top_x: Array[Transform3D] = []
		top_x.assign(tops[lane])
		BuildVoxelStyle.multimesh(
			self, "RhythmSpeakerTops%d" % lane, box, kit.material(COLORS[lane], true), top_x
		)


func _batch_columns() -> void:
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.0
	cyl.height = 1.0
	cyl.radial_segments = 16
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 16
	sphere.rings = 8
	var columns: Array[Transform3D] = []
	var orbs: Array = [[], [], [], []]
	for side in [-1.0, 1.0]:
		for i in range(8):
			columns.append(
				Transform3D(
					Basis.from_scale(Vector3(0.2, 3.6, 0.2)), Vector3(side * 8, 1.8, 3 - i * 5)
				)
			)
			orbs[i % 4].append(
				Transform3D(Basis.from_scale(Vector3.ONE * 0.42), Vector3(side * 8, 3.8, 3 - i * 5))
			)
	BuildVoxelStyle.multimesh(
		self, "RhythmColumns", cyl, BuildVoxelStyle.material("plain", Color("2a1848")), columns
	)
	for lane in range(4):
		var orb_x: Array[Transform3D] = []
		orb_x.assign(orbs[lane])
		BuildVoxelStyle.multimesh(
			self, "RhythmOrbs%d" % lane, sphere, kit.material(COLORS[lane], true), orb_x
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
