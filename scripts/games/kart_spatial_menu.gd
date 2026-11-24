extends "res://scripts/games/kart_garage_menu.gd"
## One live stage shared by the landing and every customization section.
## Selection, unlocks, tuning, native gestures and saved setups stay in the base.
const SERVICE_STATION = preload("res://scripts/games/kart_garage_service_station.gd")
const STAGE_PINCH = preload("res://scripts/games/kart_stage_pinch.gd")
const HOME_PROMENADE = preload("res://scripts/games/kart_neon_arena.gd")
const TRACK_STAGE = preload("res://scripts/games/kart_track_stage.gd")
const SHOWROOM = preload("res://scripts/games/kart_garage_showroom.gd")
const PARTS_BAY = preload("res://scripts/games/kart_parts_bay.gd")
## Große Karten für „Fahrer“ und „Tempo & Gegner“ (Auftrag 18.11., Abschnitt 4).
const SECTIONS = preload("res://scripts/games/kart_menu_sections.gd")
## Wächter der 3D-Vorschau (siehe _watch_preview).
const PREVIEW_WATCH_SECONDS: float = 5.0
const PREVIEW_PIXEL_SECONDS: float = 20.0
const PREVIEW_REPAIR_GAP: float = 30.0
const PREVIEW_REPAIR_LIMIT: int = 6
## „Teile wechseln“ + „Werte“ beim gewählten Kart (Garage), siehe kart_parts_bay.gd.
var parts_bay
## Gründe der Reparaturen durch den Vorschau-Wächter (für Tests und Protokoll).
var preview_repairs: Array[String] = []
var service_station
var home_promenade
var track_stage
var track_pass
var _pinch = STAGE_PINCH.new()
var _camera_zoom := 1.0
var _last_section := -1
var _application_active := true
var _spatial_ready := false
var _landing_active := false
var _stage_header: Control
var _stage_controls: Array[Control] = []
var _selection_surface: Panel
var _landing_stage_region := Rect2(0.36, 0.19, 0.61, 0.60)
var _home_camera_phase := 1.0
var _home_camera_pose := Transform3D.IDENTITY
var _home_camera_focus := Vector3.ZERO
var _home_camera_offsets := Vector2.ZERO
var _home_mode := ""
var _home_environment: Environment
var _studio_ambient := Color.WHITE
var _studio_ambient_energy := 0.46
var _studio_sky: Sky
var _preview_watch_time := 0.0
var _preview_pixel_time := 0.0
var _preview_since_repair := PREVIEW_REPAIR_GAP


func _ready() -> void:
	super._ready()
	_stage_header = header_row.get_parent()
	for control in [premium_hero_shell, _stage_header, step_strip, setup_left, footer]:
		control.reparent(self, false)
		control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	move_child(premium_hero_shell, 0)
	premium_hero_shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview_container.custom_minimum_size = Vector2.ZERO
	world_backdrop.hide()
	world_veil.hide()
	sunset_layer.hide()
	page_margin.hide()
	_stage_controls.assign([_stage_header, step_strip, setup_left, footer])
	_selection_surface = Panel.new()
	_selection_surface.name = "ReadableSelectionSurface"
	_selection_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var surface := _status_glass()
	surface.bg_color = Color(0.018, 0.045, 0.11, 0.91)
	surface.set_content_margin_all(0)
	_selection_surface.add_theme_stylebox_override("panel", surface)
	add_child(_selection_surface)
	move_child(_selection_surface, setup_left.get_index())
	track_stage = TRACK_STAGE.new()
	track_stage.attach(self)
	add_child(track_stage)
	move_child(track_stage, premium_hero_shell.get_index() + 1)
	workshop_button.reparent(setup_left, false)
	workshop_button.text = "Lack, Teile & Effekte"
	kart_bars.reparent(setup_left, false)
	title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	subtitle.hide()
	detail.hide()
	preview_title.hide()
	preview_caption_panel.hide()
	quick_start_button.hide()
	brand_wordmark.custom_minimum_size = Vector2(136, 58)
	header_row.custom_minimum_size = Vector2.ZERO
	# A wrapping one-glyph label reports a 1px minimum width. At Android
	# density its wrapped height stretched the entire header behind the tabs.
	progress_icon.autowrap_mode = TextServer.AUTOWRAP_OFF
	progress_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_stage_header.minimum_size_changed.connect(func(): _apply_responsive_layout.call_deferred())
	learn_button.text = "Spielewelt"
	for connection in learn_button.pressed.get_connections():
		learn_button.pressed.disconnect(connection.callable)
	learn_button.pressed.connect(func(): exit_requested.emit("games"))
	# Brighter local studio materials; the original meshes and driver stay intact.
	# Konzeptbild-Farbwelt: warme Sandwände, heller Epoxid-Boden, heller Drehteller.
	garage_interior.materials.wall.albedo_color = Color("cdb79c")
	garage_interior.materials.floor.albedo_color = Color("566377")
	garage_interior.materials.ivory.albedo_color = Color("f1ece2")
	garage_interior.materials.recess.albedo_color = Color("2a2f45")
	garage_interior.materials.podium.albedo_color = Color("d9dee6")
	garage_interior.materials.podium.metallic = 0.2
	garage_interior.materials.podium.roughness = 0.3
	_style_view_choice()
	parts_bay = PARTS_BAY.new()
	add_child(parts_bay)
	parts_bay.setup(self)
	service_station = SERVICE_STATION.new()
	garage_interior.root.add_child(service_station)
	service_station.build(garage_interior.materials)
	home_promenade = HOME_PROMENADE.new()
	preview.add_child(home_promenade)
	home_promenade.build()
	for child in preview.get_children():
		if child is WorldEnvironment and child.environment != null:
			_home_environment = child.environment
			# Hellere, warme Grundhelligkeit im Studio: keine schwarzen Schattenseiten mehr.
			_studio_ambient = Color("8a8496")
			_studio_ambient_energy = 0.62
	_spatial_ready = true
	_refresh()


func set_landing_active(active: bool) -> void:
	_landing_active = active
	_home_camera_phase = 0.0 if active and not reduced_motion else 1.0
	if active:
		step = 0
		_refresh()
	for control in _stage_controls:
		control.visible = not active
	_selection_surface.visible = not active
	view_choice.visible = not active and step in [1, 2]
	preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	preview_camera.make_current()
	_sync_home_stage()
	_fit_welcome_camera()


func set_landing_stage_region(region: Rect2) -> void:
	if region.has_area():
		_landing_stage_region = region
		if _landing_active:
			_fit_welcome_camera()


func _refresh() -> void:
	super._refresh()
	if not _spatial_ready:
		return
	if step != _last_section:
		_reset_stage_gesture()
		_camera_zoom = 1.0
		# The shared drawer must not carry a kart's scroll offset into the world
		# list, clipping its first track name even though its goal is visible.
		var drawer := choices.get_parent() as ScrollContainer
		drawer.scroll_vertical = 0
		drawer.scroll_horizontal = 0
		_last_section = step
	_sync_workshop_host()
	for button in garage_buttons.values():
		button.body.hide()
	_sync_home_stage()
	workshop_button.visible = step == 2
	kart_bars.hide()
	if parts_bay != null:
		parts_bay._sync()
	subtitle.hide()
	SECTIONS.build(self, step, _select)
	title_label.text = ["Rennen", "Dein Fahrer", "Deine Garage", "Rennwelten", "Tempo & Gegner"][step]
	_update_track_goals()
	track_stage.sync()
	_apply_responsive_layout.call_deferred()


func _refresh_preview() -> void:
	# Die Streckenwahl zeigt Bilder: beim Blättern nicht jedes Mal die ganze Welt bauen.
	if track_stage != null and track_stage.defers_world():
		return
	super._refresh_preview()
	# Nova und Milo erscheinen im Menü als dieselben 3D-Figuren wie im Rennen.
	if is_instance_valid(preview_kart) and preview_kart.has_method("set_reference_rival_enabled"):
		preview_kart.set_reference_rival_enabled(true)


func _update_track_goals() -> void:
	if step != 3 or track_pass == null or setup.mode not in ["race", "cup"]:
		return
	var difficulty_id: String = str(setup.difficulty)
	var difficulty_name: String = str(CATALOG.entry(CATALOG.DIFFICULTIES, difficulty_id).name)
	title_label.text = "Rennwelten · %d/%d" % [track_pass.total(difficulty_id), CATALOG.TRACKS.size() * 3]
	if setup.mode == "cup":
		if choices.get_child_count() == 1:
			var card: Button = choices.get_child(0)
			card.text += "\nStreckenpass: %d/%d Ziele · %s" % [track_pass.total(difficulty_id), CATALOG.TRACKS.size() * 3, difficulty_name]
		return
	for index in range(mini(choices.get_child_count(), CATALOG.TRACKS.size())):
		var card = choices.get_child(index)
		if card.get("caption_label") == null:
			continue
		var track: Dictionary = CATALOG.TRACKS[index]
		var achieved: int = track_pass.stage(str(track.id), difficulty_id)
		var goal: String = track_pass.goal_text(achieved)
		var short_goal: String = ["2 Runden ins Ziel", "Aufs Podium", "Sieg ohne Rücksetzen", "Geschafft!"][achieved]
		card.caption = "%d/3 · %s" % [achieved, short_goal]
		card.caption_label.text = card.caption
		card.caption_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.caption_label.max_lines_visible = 2
		card.tooltip_text = "%s · %s\n%s\nZiele gelten im Einzelrennen und Sternen-Cup." % [track.name, difficulty_name, goal]


func _apply_selected_preview() -> void:
	var changed := _selection_reaction_pending
	super._apply_selected_preview()
	_sync_workshop_host()
	if step == 2:
		call_deferred("_fit_welcome_camera")
	if changed and is_instance_valid(service_station):
		service_station.react_to_selection()
	if changed and step == 1:
		_play_driver_signature()


## Kurze eigene Bewegung des gewählten Fahrers: Lumo winkt, Nova und Milo jubeln.
func _play_driver_signature() -> void:
	if reduced_motion or not is_instance_valid(preview_kart):
		return
	var actor = preview_kart.get("lumo_animation")
	if is_instance_valid(actor):
		actor.play_menu_behavior("greeting_wave")
		return
	preview_kart.cheer_in_race(1.4)
	var kart_reference: WeakRef = weakref(preview_kart)
	get_tree().create_timer(1.6).timeout.connect(func():
		var kart := kart_reference.get_ref() as Node3D
		if kart != null:
			kart.end_in_race_cheer())


func _sync_workshop_host() -> void:
	if not is_instance_valid(service_station):
		return
	var show_host: bool = _application_active and visible and step == 2 and inspection_view == 0 and not _landing_active
	show_host = show_host and not (parts_bay != null and parts_bay.is_open())
	service_station.set_active(show_host, reduced_motion)
	# The same original fox stands beside his kart only in the workshop. The
	# selected vehicle/driver are untouched for every actual start and inspection.
	if is_instance_valid(preview_kart) and is_instance_valid(preview_kart.lumo_animation):
		var seated = preview_kart.lumo_animation
		seated.visible = not (show_host and is_instance_valid(service_station.host))
		seated.set_suspended(not seated.visible)


func _sync_home_stage() -> void:
	if not is_instance_valid(home_promenade):
		return
	var home_visible := _landing_active and step == 0
	home_promenade.set_active(home_visible and visible and _application_active, reduced_motion)
	garage_interior.root.visible = not home_visible and step != 3
	if _home_environment != null:
		_home_environment.ambient_light_color = Color("284286") if home_visible else _studio_ambient
		_home_environment.ambient_light_energy = 0.36 if home_visible else _studio_ambient_energy
		var workshop_visible := step == 2 and visible and _application_active and not _landing_active
		if workshop_visible and _studio_sky == null:
			_studio_sky = SHOWROOM.studio_sky()
		SHOWROOM.apply_reflections(_home_environment, _studio_sky, workshop_visible)


func _advance_home_camera(delta: float) -> void:
	if not _landing_active or inspection_view != 0 or rotate_drag or not _application_active:
		return
	_home_camera_phase = 1.0 if reduced_motion else minf(1.0, _home_camera_phase + maxf(delta, 0.0) / 0.55)
	var blend := smoothstep(0.0, 1.0, _home_camera_phase)
	var distance_scale := 1.0 + (1.0 - blend) * 0.065
	# A true bounded dolly-in: zoom begins wider than the fully fitted subject.
	# Framing offsets scale with the optical origin, so UI remains clear.
	preview_camera.transform = _home_camera_pose
	preview_camera.position = _home_camera_focus + (_home_camera_pose.origin - _home_camera_focus) * distance_scale
	preview_camera.h_offset = _home_camera_offsets.x * distance_scale
	preview_camera.v_offset = _home_camera_offsets.y * distance_scale


func _preview_input(event: InputEvent) -> void:
	var gesture: Dictionary = _pinch.consume(event)
	if gesture.started:
		_cancel_garage_press()
		_preview_touch_index = -1
		rotate_drag = false
		_camera_progress = 1.0
		_set_camera_veil(0.0)
	if gesture.consumed:
		if inspection_view == 0 and step != 3 and not is_equal_approx(float(gesture.scale), 1.0):
			_camera_zoom = clampf(_camera_zoom * float(gesture.scale), 0.78, 1.25)
			_fit_welcome_camera()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		if inspection_view == 0 and step != 3:
			_camera_zoom = clampf(_camera_zoom * (0.92 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.08), 0.78, 1.25)
			_fit_welcome_camera()
		return
	super._preview_input(event)


func _reset_stage_gesture() -> void:
	_pinch.reset()
	_preview_touch_index = -1
	rotate_drag = false
	_cancel_garage_press()


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		_application_active = false
		_reset_stage_gesture()
		if is_instance_valid(service_station):
			service_station.set_active(false, reduced_motion)
		_sync_home_stage()
	elif what in [NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED]:
		_application_active = true
		if _spatial_ready and visible and not is_instance_valid(workshop_view):
			preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			preview_camera.make_current()
			_queue_preview_render_scale()
			_fit_welcome_camera.call_deferred()
		_sync_home_stage()
		# Nach der Rückkehr in die App sofort prüfen, ob die Vorschau noch zeichnet.
		_preview_watch_time = PREVIEW_WATCH_SECONDS
		_preview_pixel_time = PREVIEW_PIXEL_SECONDS


func _next() -> void:
	start_requested.emit(setup.duplicate(true))


func _back() -> void:
	main_menu_requested.emit()


func _pick_garage_action(_local: Vector2) -> String:
	# Spatial signage is scenery. All navigation belongs to the visible native UI.
	return ""


func _update_garage_action_targets() -> void:
	_garage_targets.clear()
	for button in garage_buttons.values():
		button.body.hide()


## „Rundum ansehen“ als Glasknopf im Stil der Reiter (statt nacktem Auswahlfeld).
func _style_view_choice() -> void:
	var normal := _step_glass(false)
	normal.bg_color = Color(0.03, 0.16, 0.34, 0.92)
	normal.border_color = Color(0.40, 0.88, 1.0, 0.85)
	normal.set_border_width_all(2)
	normal.content_margin_left = 18
	normal.content_margin_right = 14
	var hover := _step_glass(true)
	hover.content_margin_left = 18
	hover.content_margin_right = 14
	for state in ["normal", "focus", "disabled"]:
		view_choice.add_theme_stylebox_override(state, normal)
	for state in ["hover", "pressed", "hover_pressed"]:
		view_choice.add_theme_stylebox_override(state, hover)
	view_choice.add_theme_color_override("font_color", Color("f2fbff"))
	view_choice.add_theme_color_override("font_hover_color", Color.WHITE)
	view_choice.add_theme_font_override("font", UI.HEADING)
	view_choice.add_theme_constant_override("arrow_margin", 14)
	view_choice.add_theme_constant_override("h_separation", 8)
	view_choice.icon = _orbit_icon()
	view_choice.expand_icon = false


## Kleines Rundum-Symbol (Kreisbogen mit Pfeilspitze), selbst gezeichnet.
func _orbit_icon() -> Texture2D:
	var size := 30
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var centre := Vector2(size, size) * 0.5
	for y in range(size):
		for x in range(size):
			var offset := Vector2(x + 0.5, y + 0.5) - centre
			var radius := offset.length()
			var angle := fposmod(atan2(offset.y, offset.x), TAU)
			var ring := 1.0 - clampf(absf(radius - 10.0) - 1.6, 0.0, 1.0)
			if angle > TAU * 0.86:
				ring = 0.0
			image.set_pixel(x, y, Color(0.60, 0.95, 1.0, ring))
	# Pfeilspitze am Ende des Bogens.
	var tip := centre + Vector2(cos(TAU * 0.86), sin(TAU * 0.86)) * 10.0
	for y in range(size):
		for x in range(size):
			var p := Vector2(x + 0.5, y + 0.5) - tip
			var local := p.rotated(-TAU * 0.86)
			if local.x > -5.0 and local.x < 2.0 and absf(local.y) < (local.x + 5.0) * 0.9:
				if absf(local.y) < 6.0:
					image.set_pixel(x, y, Color(1.0, 0.86, 0.35, 1.0))
	var texture := ImageTexture.create_from_image(image)
	return texture


func _apply_responsive_layout() -> void:
	if not _spatial_ready or not is_inside_tree():
		return
	var viewport_size := get_viewport_rect().size
	var window_dp := Vector2(get_window().size) / MobileRuntime.get_ui_density()
	if window_dp.x <= 0 or window_dp.y <= 0 or size.x <= 0 or size.y <= 0:
		return
	var scale_factor := maxf(viewport_size.x / window_dp.x, viewport_size.y / window_dp.y)
	var available := size / scale_factor
	var portrait := available.x < available.y
	var landscape_workshop := step == 2 and not portrait
	var side_toolbar := landscape_workshop and available.x >= 590.0
	var parts_open: bool = step == 2 and parts_bay != null and parts_bay.is_open()
	var narrow := available.x < 520.0
	var short_view := available.y < 440.0
	var ultra_short := available.y < 300.0
	# Short landscapes also need the footer workshop: at 351dp safe height
	# a separate 48dp workshop leaves only 82dp for a readable 90dp card.
	var workshop_in_footer := step == 2 and (
		ultra_short or (not portrait and available.y < 360.0)
	)
	var workshop_parent: Node = footer if workshop_in_footer else setup_left
	if workshop_button.get_parent() != workshop_parent:
		workshop_button.reparent(workshop_parent, false)
		if workshop_in_footer:
			footer.move_child(workshop_button, next_button.get_index())
	workshop_button.text = "Werkstatt" if workshop_in_footer else "Lack, Teile & Effekte"
	var margin := 12.0 if narrow or short_view else 20.0
	var header_height := 0.0 if ultra_short else (48.0 if short_view else 64.0)
	var footer_height := 52.0 if short_view else 60.0
	var footer_y := available.y - margin - footer_height
	_apply_ui_scale(self, scale_factor)
	_set_physical_minimum(brand_wordmark, Vector2(112 if short_view else 136, maxf(0, header_height - 4)), scale_factor)
	_set_physical_minimum(header_row, Vector2.ZERO, scale_factor)
	_set_physical_minimum(learn_button, Vector2(104, 48), scale_factor)
	_set_physical_font(learn_button, 14, scale_factor)
	var reward_style := progress_panel.get_theme_stylebox("panel") as StyleBoxFlat
	reward_style.set_content_margin_all(0)
	# Stern sitzt mit Luft im runden Rahmen statt auf der Kante.
	reward_style.content_margin_left = 16.0 * scale_factor
	# Schmales Hochformat: nur Stern und Zahl (vorher blieb ein leerer Rahmen stehen).
	progress_label.visible = true
	progress_icon.visible = true
	progress_label.text = ("%d" if narrow else "%d Sterne") % stars
	_set_physical_font(progress_label, 16, scale_factor)
	_set_physical_font(progress_icon, 22, scale_factor)
	# Measure the actual children and panel margins before positioning the
	# next row; requested Control.size alone cannot override container minima.
	if not ultra_short:
		header_height = maxf(header_height, _stage_header.get_combined_minimum_size().y / scale_factor)
	_stage_rect(_stage_header, Rect2(margin, margin, available.x - margin * 2, header_height), scale_factor)
	var tabs_y := margin + header_height + (0.0 if ultra_short else 8.0)
	for index in range(step_buttons.size()):
		var tab := step_buttons[index]
		tab.text = ["Rennen", "Fahrer", "Karts", "Strecken", "Tempo"][index]
		_set_physical_minimum(tab, Vector2(48, 48), scale_factor)
		_set_physical_font(tab, 12 if narrow else 15, scale_factor)
	_stage_rect(step_strip, Rect2(margin, tabs_y, available.x - margin * 2, 48), scale_factor)
	var top := tabs_y + 60.0
	var choices_rect: Rect2
	if portrait:
		var drawer_height := clampf(available.y * 0.30, 160.0, 286.0)
		if step in [0, 1, 4]:
			# Große Rennarten-, Fahrer- und Stufenkarten statt schmaler Zeilen.
			drawer_height = clampf(available.y * 0.36, 210.0, 330.0)
		choices_rect = Rect2(margin, maxf(top + 60.0, footer_y - drawer_height - 12), available.x - margin * 2, drawer_height)
	else:
		var drawer_width := clampf(available.x * (0.40 if step in [0, 1, 4] else 0.31), 208, 420 if step in [0, 1, 4] else 360)
		if side_toolbar:
			drawer_width = clampf(available.x * 0.36, 306.0, 390.0)
		choices_rect = Rect2(margin, top, drawer_width, maxf(72, footer_y - top - 12))
	var parts_rect := choices_rect
	if landscape_workshop:
		# Reserve the toolbar above the list without reducing the height of the photo.
		choices_rect.position.y += 56.0
		choices_rect.size.y = maxf(48.0, choices_rect.size.y - 56.0)
		parts_rect.size.y = available.y - margin - top
	if parts_open:
		# The parts editor owns its drawer. Its measured outer edge defines the camera stage.
		if portrait:
			var height := clampf(available.y * 0.49, 225.0, 482.0)
			parts_rect = Rect2(margin, available.y - margin - height, available.x - 2 * margin, height)
		else:
			parts_rect = Rect2(margin, margin, minf(available.x * 0.43, 530), available.y - 2 * margin)
		parts_bay.panel.position = parts_rect.position * scale_factor
		parts_bay.panel.size = parts_rect.size * scale_factor
	var stage_mode: bool = track_stage.wanted()
	if stage_mode:
		choices_rect = track_stage.layout(available, top, footer_y, margin, portrait, scale_factor)
	_stage_rect(_selection_surface, choices_rect, scale_factor)
	_stage_rect(setup_left, choices_rect.grow(-4.0 if short_view else -10.0), scale_factor)
	setup_left.custom_minimum_size = Vector2.ZERO
	setup_left.add_theme_constant_override("separation", roundi(6 * scale_factor))
	_set_physical_font(title_label, 18 if short_view or narrow else 23, scale_factor)
	title_label.visible = not short_view
	_set_physical_minimum(workshop_button, Vector2(0, 48), scale_factor)
	_set_physical_font(workshop_button, 15, scale_factor)
	for child in choices.get_children():
		# Die Rennarten-Karten ordnet allein SECTIONS.layout (weiter unten): ein
		# Zwischenwert hier ließ das Raster auf der Höhe der einspaltigen Liste stehen.
		if child is GridContainer and child.name != "ModeCards":
			child.columns = 2 if portrait and not narrow and step == 2 else 1
		var cards: Array = child.get_children() if child is GridContainer else [child]
		for card in cards:
			if card is Button:
				var card_height := (72 if ultra_short else 90) if step == 2 else (64 if step == 0 else 68)
				_set_physical_minimum(card, Vector2(0, card_height), scale_factor)
				if step == 2:
					# Scroll offsets are integers; a half-pixel row can remain
					# clipped after ensure_control_visible at Android density.
					card.custom_minimum_size.y = ceilf(card.custom_minimum_size.y)
				_set_physical_font(card, 16, scale_factor)
				if card.has_method("apply_size"):
					card.apply_size(scale_factor, true)
					# Compact mode hides decorative captions. Race objectives are
					# actionable information and remain visible on every form factor.
					if step == 3 and setup.mode == "race" and track_pass != null:
						card.caption_label.show()
	if stage_mode:
		title_label.hide()
		_stage_rect(setup_left, choices_rect, scale_factor)
		track_stage.layout_cards(choices_rect, scale_factor)
	else:
		track_stage.release_drawer()
	if step in [0, 1, 4]:
		var title_dp := 0.0 if short_view else 40.0
		var inset := 8.0 if short_view else 20.0
		SECTIONS.layout(self, choices_rect.size - Vector2(inset + 4.0, inset + title_dp), scale_factor, short_view)
	_stage_rect(footer, Rect2(margin, footer_y, available.x - margin * 2, footer_height), scale_factor)
	footer_spacer.hide()
	footer.columns = (3 if has_saved_race else 2) + (1 if workshop_in_footer else 0)
	footer.add_theme_constant_override("h_separation", roundi(8 * scale_factor))
	for child in footer.get_children():
		if child is Button:
			child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_set_physical_minimum(child, Vector2(48, footer_height), scale_factor)
			_set_physical_font(child, 14 if narrow or ultra_short else 18, scale_factor)
			if child.name == "ResumeRace":
				child.text = "Fortsetzen"
	back_button.text = "Menü" if narrow or ultra_short else "← Kart-Menü"
	next_button.text = "START" if narrow or ultra_short else "Rennen starten"
	_set_physical_minimum(view_choice, Vector2(112, 48), scale_factor)
	_set_physical_font(view_choice, 14, scale_factor)
	view_choice.fit_to_longest_item = not side_toolbar
	view_choice.clip_text = side_toolbar
	view_choice.set_item_text(0, "Rundum" if side_toolbar or narrow else "Rundum ansehen")
	var actions := Rect2()
	if landscape_workshop:
		var view_width := choices_rect.size.x
		if side_toolbar:
			view_width = roundf(choices_rect.size.x * 0.42)
			actions = Rect2(margin + view_width + 4.0, top, choices_rect.size.x - view_width - 4.0, 48.0)
		_stage_rect(view_choice, Rect2(margin, top, view_width, 48.0), scale_factor)
	else:
		view_choice.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		view_choice.offset_left = -256 * scale_factor
		view_choice.offset_right = -margin * scale_factor
		view_choice.offset_top = top * scale_factor
		view_choice.offset_bottom = (top + 48) * scale_factor
	view_choice.visible = not _landing_active and step in [1, 2] and not parts_open
	if parts_bay != null:
		# Projektion und Bedienelemente verwenden dieselben gemessenen Bildschirmflächen.
		var stage_px := _visible_stage_region()
		var full := preview_container.get_global_rect()
		var stage_rect := Rect2(full.position + stage_px.position * full.size, stage_px.size * full.size)
		var config_area := Rect2(parts_rect.position * scale_factor, parts_rect.size * scale_factor)
		parts_bay.relayout(
			scale_factor, Rect2(stage_rect.position - global_position, stage_rect.size), config_area,
			Rect2(actions.position * scale_factor, actions.size * scale_factor)
		)
	for control in _stage_controls:
		control.visible = not _landing_active
	setup_left.visible = not _landing_active and not parts_open
	footer.visible = not _landing_active and not parts_open
	step_strip.visible = not _landing_active and not parts_open
	_stage_header.visible = not _landing_active and not ultra_short and not parts_open
	_selection_surface.visible = not _landing_active and not stage_mode and not parts_open
	call_deferred("_fit_welcome_camera")


func _stage_rect(control: Control, rect: Rect2, ui_scale: float) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	control.position = rect.position * ui_scale
	control.size = rect.size * ui_scale


func _choose_preview_view(index: int, animate: bool = true) -> void:
	_camera_zoom = 1.0
	if is_instance_valid(preview_camera):
		preview_camera.h_offset = 0.0
		preview_camera.v_offset = 0.0
	super._choose_preview_view(index, animate)
	_sync_workshop_host()
	if step == 3 or inspection_view == 0:
		return
	# The live studio is a room. Inspection cameras must stay on the model
	# side of its walls and ceiling, including while changing projection.
	var inside_positions := {
		2: Vector3(-4.6, 1.2, 0),
		3: Vector3(0, 1.2, 3.6),
		4: Vector3(4.6, 1.2, 0),
		5: Vector3(0, 4.8, 0),
	}
	if inside_positions.has(inspection_view):
		_camera_to.origin = inside_positions[inspection_view]
		_camera_to = _camera_to.looking_at(_camera_to_focus,
			Vector3.FORWARD if inspection_view == 5 else Vector3.UP)
		if _camera_progress >= 1.0:
			_apply_camera_target()


func _fit_welcome_camera() -> void:
	if not _spatial_ready or not is_instance_valid(preview_camera) or preview_viewport.size.y <= 0:
		return
	var aspect := float(preview_viewport.size.x) / float(preview_viewport.size.y)
	if inspection_view != 0 and step != 3:
		preview_camera.h_offset = 0.0
		preview_camera.v_offset = 0.0
		return
	if parts_bay != null and parts_bay.is_open() and step == 2:
		parts_bay.fit_camera(_visible_stage_region())
		_camera_progress = 1.0
		_set_camera_veil(0.0)
		return
	# Fit the actual chassis, seated rig and light rings to the unoccluded
	# part of the live stage. Portrait width cannot reuse a landscape frustum.
	var focus := Vector3(0, 0.95, 0)
	# A camera offset translates the optical origin too. The shallower side
	# angle keeps that origin inside the open service bay after the framing
	# offset, so its right wall cannot occlude an otherwise valid frustum.
	var direction := Vector3(1.6, 1.05, -4.6).normalized()
	# Hochformat-Garage: flachere, frontalere Kamera wie ein Konzeptbild – das Kart steht
	# groß im unteren Drittel, darüber Leuchtwand und Schild statt leerer Bodenfläche.
	var portrait_garage: bool = step == 2 and aspect < 1.0 and garage_interior.root.visible
	# Garage (Auftrag 18.11.): das gewählte Kart groß in niedriger Dreiviertelansicht, Lumo
	# steht seitlich daneben; Leuchtwand und Werkbank bleiben Hintergrund und werden nicht
	# mehr ins Bild gezwungen.
	var garage_stage: bool = step == 2 and garage_interior.root.visible
	if garage_stage:
		focus = Vector3(0, 0.62, 0.15)
		# The landscape drawer offsets the optical origin to the left. A
		# shallow view from the right keeps that origin inside the service bay
		# instead of backing through the left wall while framing the whole kart.
		direction = Vector3(1.6, 0.82, -4.6).normalized()
	# Fahrer: nah an Figur und Cockpit, leicht von vorn – Gesicht und Silhouette groß.
	var driver_stage: bool = step == 1 and inspection_view == 0
	# Hauptmenü (offenes Fold): Kart und Lumo füllen die linke Bühne; der Lichtring darf
	# angeschnitten sein, statt das Kart klein in die Mitte zu zwingen.
	var landing_stage: bool = _landing_active and step == 0
	if landing_stage:
		focus = Vector3(0, 0.85, 0)
		direction = Vector3(1.1, 0.95, -4.6).normalized()
	if driver_stage:
		focus = Vector3(0, 1.0, 0)
		direction = Vector3(-1.2, 0.75, -3.4).normalized()
	var region := _visible_stage_region()
	var pixels := Vector2(preview_viewport.size)
	var target := Rect2(region.position * pixels, region.size * pixels)
	if garage_stage:
		# Etwas Luft am Rand: das leichte Pendeln des Drehtellers schneidet kein Rad an.
		target = target.grow_individual(-target.size.x * 0.05, -target.size.y * 0.03, -target.size.x * 0.05, -target.size.y * 0.02)
	var points: Array[Vector3] = []
	if step == 3:
		if not is_instance_valid(preview_world):
			return
		var route: Curve3D = preview_world.get("curve")
		for sample in range(96):
			points.append(preview_world.to_global(route.sample_baked(route.get_baked_length() * sample / 96.0)))
		var bounds := AABB(points[0], Vector3.ZERO)
		for point in points:
			bounds = bounds.expand(point)
		focus = bounds.get_center()
		direction = Vector3(0.65, 0.90, -1.0).normalized()
	else:
		points = _stage_subject_points(garage_stage or driver_stage or landing_stage)
		if driver_stage and is_instance_valid(preview_kart):
			points = _driver_subject_points()
			if points.is_empty():
				# The original Lumo has its established animated head/cockpit fit.
				# Production rivals use their actual selected mesh silhouette.
				for x in [-0.5, 0.5]:
					for y in [0.95, 2.02]:
						for z in [-0.55, 0.4]:
							points.append(preview_kart.to_global(Vector3(x, y, z)))
		if garage_stage and aspect >= 1.0:
			var plinth: MeshInstance3D = garage_interior.turntable.get_parent().get_node("GarageTurntablePlinth")
			var base := plinth.mesh as CylinderMesh
			for i in range(48):
				var angle := TAU * i / 48.0
				points.append(plinth.to_global(Vector3(cos(angle) * base.bottom_radius, -base.height * 0.5, sin(angle) * base.bottom_radius)))
		if garage_stage and not points.is_empty():
			# Kart und stehender Lumo bestimmen gemeinsam die Bildmitte.
			var group := AABB(points[0], Vector3.ZERO)
			for point in points:
				group = group.expand(point)
			focus.x = group.get_center().x * 0.6
			focus.z = group.get_center().z * 0.6
	var distance := 6.0 if step == 3 else (2.6 if garage_stage or driver_stage or landing_stage else 4.8)
	preview_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	preview_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	preview_camera.fov = 40.0 if aspect < 1.0 else 35.0
	for attempt in range(64):
		preview_camera.position = focus + direction * distance
		preview_camera.look_at(focus)
		var height := 2.0 * distance * tan(deg_to_rad(preview_camera.fov * 0.5))
		preview_camera.h_offset = -height * aspect * (region.get_center().x - 0.5)
		preview_camera.v_offset = height * (region.get_center().y - 0.5)
		var fits := true
		for point in points:
			if preview_camera.is_position_behind(point) or not target.has_point(preview_camera.unproject_position(point)):
				fits = false
				break
		if fits:
			break
		distance *= 1.08
	# User-requested inspection zoom is applied after the default complete-subject
	# fit. Section changes restore that fit; no UI positions or hitboxes move.
	if step != 3 and not is_equal_approx(_camera_zoom, 1.0):
		distance *= _camera_zoom
		preview_camera.position = focus + direction * distance
		preview_camera.look_at(focus)
		var height := 2.0 * distance * tan(deg_to_rad(preview_camera.fov * 0.5))
		preview_camera.h_offset = -height * aspect * (region.get_center().x - 0.5)
		preview_camera.v_offset = height * (region.get_center().y - 0.5)
	_camera_progress = 1.0
	_camera_ready = true
	_camera_focus = focus
	_set_camera_veil(0.0)
	if _landing_active:
		_home_camera_pose = preview_camera.transform
		_home_camera_focus = focus
		_home_camera_offsets = Vector2(preview_camera.h_offset, preview_camera.v_offset)
		_advance_home_camera(0.0)


func _visible_stage_region() -> Rect2:
	if _landing_active:
		return _landing_stage_region
	var stage := preview_container.get_global_rect()
	if track_stage.active and stage.has_area():
		# Rundkurs-Übersicht der Streckenwahl: genau im Rahmen des Bühnenbilds.
		var frame: Rect2 = track_stage.picture_rect().grow(-8.0 * _preview_dp_scale())
		if frame.has_area():
			return Rect2((frame.position - stage.position) / stage.size, frame.size / stage.size)
	var inset := 8.0 * _preview_dp_scale()
	var clear := stage.grow(-inset)
	if step == 2 and parts_bay != null and parts_bay.is_open() and stage.has_area():
		var drawer: Rect2 = parts_bay.panel.get_global_rect()
		if size.x < size.y:
			clear.end.y = minf(clear.end.y, drawer.position.y - inset)
		else:
			var right := clear.end.x
			clear.position.x = maxf(clear.position.x, drawer.end.x + inset)
			clear.end.x = right
		return Rect2((clear.position - stage.position) / stage.size, clear.size / stage.size)
	var top := maxf(clear.position.y, step_strip.get_global_rect().end.y + inset)
	var bottom := footer.global_position.y - inset
	var left := clear.position.x
	var right := clear.end.x
	var portrait := size.x < size.y
	var side_toolbar := step == 2 and not portrait and size.x / _preview_dp_scale() >= 590.0
	if portrait:
		bottom = _selection_surface.global_position.y - inset
	else:
		left = _selection_surface.get_global_rect().end.x + inset
	# In the landscape garage all three controls share the kart list's toolbar.
	if view_choice.is_visible_in_tree() and (portrait or step != 2):
		top = maxf(top, view_choice.get_global_rect().end.y + inset)
	if step == 2 and parts_bay != null and not side_toolbar:
		bottom -= 62.0 * _preview_dp_scale()
	clear = Rect2(Vector2(left, top), Vector2(right - left, bottom - top))
	if not clear.has_area():
		return Rect2(0.36, 0.19, 0.61, 0.60)
	return Rect2((clear.position - stage.position) / stage.size, clear.size / stage.size)


## The production animals are authored seated. Their real mesh bounds include
## different ears, tails and shells; the original Lumo keeps his measured head fit.
func _driver_subject_points() -> Array[Vector3]:
	var points: Array[Vector3] = []
	if not is_instance_valid(preview_kart) or not is_instance_valid(preview_kart.production_driver):
		return points
	for mesh in preview_kart.production_driver.find_children("*", "MeshInstance3D", true, false):
		if not mesh.is_visible_in_tree():
			continue
		var bounds: AABB = mesh.get_aabb()
		for corner in range(8):
			points.append(mesh.to_global(bounds.get_endpoint(corner)))
	return points


func _stage_subject_points(close_up: bool = false) -> Array[Vector3]:
	var points: Array[Vector3] = []
	for mesh in preview_kart.find_children("*", "MeshInstance3D", true, false):
		var seated_rival: bool = is_instance_valid(preview_kart.production_driver) and preview_kart.production_driver.is_ancestor_of(mesh)
		if not mesh.is_visible_in_tree() or (mesh.skin != null and not seated_rival) or mesh == preview_kart.far_mesh:
			continue
		var bounds: AABB = mesh.get_aabb()
		for corner in range(8):
			points.append(mesh.to_global(bounds.get_endpoint(corner)))
	if is_instance_valid(preview_kart.lumo_animation):
		var skeleton: Skeleton3D = preview_kart.lumo_animation.actor.skeleton
		var head := skeleton.find_bone("Head")
		var head_point := skeleton.to_global(skeleton.get_bone_global_pose(head).origin)
		points.append(head_point + Vector3.UP * 0.46)
		points.append(head_point + Vector3(0.66, 0.37, 0))
		points.append(head_point + Vector3(-0.66, 0.37, 0))
	# Nahaufnahme (Hochformat-Garage): Kart, Lumo und Werkbank füllen das Bild, der
	# Drehteller darf seitlich angeschnitten sein.
	for ring in ([] if close_up else stage_rings):
		for sample in range(32):
			var angle := TAU * sample / 32.0
			var radius: float = ring.mesh.outer_radius
			points.append(ring.to_global(Vector3(cos(angle) * radius, 0, sin(angle) * radius)))
	if is_instance_valid(service_station):
		points.append_array(service_station.subject_points())
		if not close_up:
			points.append_array(service_station.workbench_points())
	# Das LUMO-Schild gehört ins Bild, nie unter Reiter oder Kopfzeile (Gesamtansicht).
	if step == 2 and garage_interior.root.visible and not close_up:
		points.append_array(SHOWROOM.sign_points(garage_interior.root))
	return points


func _process(delta: float) -> void:
	var previous_angle := preview_angle
	super._process(delta)
	if not visible or not _spatial_ready:
		if is_instance_valid(service_station):
			service_station.set_active(false, reduced_motion)
		if is_instance_valid(home_promenade):
			home_promenade.set_active(false, reduced_motion)
		return
	_sync_workshop_host()
	_sync_home_stage()
	service_station.advance(delta)
	home_promenade.advance(delta)
	if _landing_active and str(setup.mode) != _home_mode:
		_home_mode = str(setup.mode)
		_home_camera_phase = 1.0 if reduced_motion else 0.0
		if is_instance_valid(preview_kart.lumo_animation):
			preview_kart.lumo_animation.play_menu_behavior("agree_nod")
	_advance_home_camera(delta)
	_watch_preview(delta)
	if step == 3:
		if not rotate_drag:
			preview_angle = previous_angle
		preview_pivot.rotation.y = preview_angle
		if rotate_drag:
			_fit_welcome_camera()
	if inspection_view == 0 and not rotate_drag and step != 3:
		preview_angle = previous_angle
		if step != 0:
			preview_idle_time += delta
		preview_pivot.rotation.y = preview_angle + (0.0 if reduced_motion else sin(preview_idle_time * 0.35) * 0.07)
	for button in garage_buttons.values():
		button.body.hide()


func handle_back() -> bool:
	if parts_bay != null and parts_bay.handle_back():
		return true
	return super.handle_back()


## Wächter der 3D-Vorschau im Kart-Menü. Gerätefehler vom 21.11.2026: „Im Hauptmenü
## verschwindet nach einer Zeit Lumo mit dem Kart und man sieht nichts mehr.“ Im Container
## (Ersatz-Renderer) ließ sich das weder durch langen Leerlauf noch durch Fokus-, Pause- oder
## Größenwechsel nachstellen. Darum prüft die Vorschau sich selbst: alle 5 s ihren Zustand,
## alle 20 s zusätzlich das tatsächlich gezeichnete Bild. Fehlt etwas, wird sie neu aufgebaut
## und der Grund ins Protokoll (logcat) geschrieben, damit ein Gerätelauf die Ursache zeigt.
func _watch_preview(delta: float) -> void:
	_preview_since_repair += delta
	if not visible or not _application_active or step == 3 or is_instance_valid(workshop_view):
		_preview_watch_time = 0.0
		return
	_preview_watch_time += delta
	_preview_pixel_time += delta
	if _preview_watch_time < PREVIEW_WATCH_SECONDS:
		return
	_preview_watch_time = 0.0
	var reason := preview_problem()
	if reason.is_empty() and _preview_pixel_time >= PREVIEW_PIXEL_SECONDS:
		_preview_pixel_time = 0.0
		reason = preview_pixels_problem()
	if not reason.is_empty():
		repair_preview(reason)


## Leerer Text = Vorschau in Ordnung; sonst ein kurzer Grund.
func preview_problem() -> String:
	if not is_instance_valid(preview_viewport) or not is_instance_valid(preview_camera):
		return "vorschau_fehlt"
	if preview_viewport.size.x < 16 or preview_viewport.size.y < 16:
		return "vorschau_ohne_flaeche"
	if preview_viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED:
		return "vorschau_angehalten"
	if not preview_camera.is_current():
		return "kamera_nicht_aktiv"
	return _preview_kart_problem()


func _preview_kart_problem() -> String:
	if not is_instance_valid(preview_kart) or not preview_kart.is_inside_tree():
		return "kart_fehlt"
	if not preview_kart.is_visible_in_tree():
		return "kart_unsichtbar"
	var where: Vector3 = preview_kart.global_position
	if not (is_finite(where.x) and is_finite(where.y) and is_finite(where.z)):
		return "kart_position_ungueltig"
	if preview_kart.global_transform.basis.get_scale().length() < 0.3:
		return "kart_winzig"
	if not preview_camera.is_position_in_frustum(where + Vector3.UP * 0.5):
		return "kart_ausserhalb_bild"
	return ""


## Prüft das gezeichnete Bild: Ist es (fast) einfarbig, zeichnet die Vorschau nichts mehr.
## Ohne echten Renderer (Tests ohne Bildschirm) wird nichts geprüft.
func preview_pixels_problem() -> String:
	if DisplayServer.get_name() == "headless" or not is_instance_valid(preview_viewport):
		return ""
	var texture: ViewportTexture = preview_viewport.get_texture()
	if texture == null:
		return "bild_fehlt"
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		return "bild_leer"
	# Sample local edges where the vehicle is framed. A uniform wall with a
	# brightness gradient passed the old full-screen min/max luminance check.
	var area := _visible_stage_region().intersection(Rect2(0, 0, 1, 1))
	if not area.has_area():
		return "vorschau_ohne_flaeche"
	var edges := 0
	for row in range(1, 10):
		var previous := Color()
		for col in range(1, 14):
			var uv := area.position + area.size * Vector2(col / 14.0, row / 10.0)
			var point := Vector2i(uv * Vector2(image.get_size()))
			var color := image.get_pixelv(point.min(image.get_size() - Vector2i.ONE))
			if col > 1 and maxf(absf(color.r - previous.r),
					maxf(absf(color.g - previous.g), absf(color.b - previous.b))) > 0.09:
				edges += 1
			previous = color
	return "bild_einfarbig" if edges < 3 else ""


func _renew_render_target() -> void:
	# An Android surface can resume with a valid scene and a stale colour buffer.
	# Keep the live nodes and their signals, but allocate a fresh viewport target.
	var old := preview_viewport
	var fresh := SubViewport.new()
	fresh.world_3d = old.world_3d
	fresh.size = old.size
	fresh.msaa_3d = old.msaa_3d
	fresh.scaling_3d_scale = old.scaling_3d_scale
	fresh.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	preview_container.add_child(fresh)
	preview.reparent(fresh, false)
	preview_container.remove_child(old)
	old.queue_free()
	preview_viewport = fresh
	fresh.size_changed.connect(_queue_preview_render_scale)
	preview_camera.make_current()
	_queue_preview_render_scale()


## Baut die Vorschau neu auf (höchstens alle 30 s, höchstens sechsmal je Besuch).
func repair_preview(reason: String) -> bool:
	var limited: bool = preview_repairs.size() >= PREVIEW_REPAIR_LIMIT
	if _preview_since_repair < PREVIEW_REPAIR_GAP or limited:
		return false
	_preview_since_repair = 0.0
	preview_repairs.append(reason)
	push_warning("[KartMenu] preview_repair:%s (%d)" % [reason, preview_repairs.size()])
	print("[KartMenu] preview_repair:%s count=%d" % [reason, preview_repairs.size()])
	if is_instance_valid(preview_viewport):
		if reason in ["bild_fehlt", "bild_leer", "bild_einfarbig"]:
			_renew_render_target()
		preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# Der Drehpunkt der Vorschau steht immer im Ursprung (nur seine Drehung wird animiert).
	if is_instance_valid(preview_pivot):
		preview_pivot.position = Vector3.ZERO
		preview_pivot.scale = Vector3.ONE
		preview_pivot.visible = true
	preview_signature = ""
	_refresh_preview()
	if is_instance_valid(preview_camera):
		preview_camera.make_current()
	_fit_welcome_camera()
	return true

