extends "res://scripts/games/kart_garage_menu.gd"
## One live stage shared by the landing and every customization section.
## Selection, unlocks, tuning, native gestures and saved setups stay in the base.
var _spatial_ready := false
var _landing_active := false
var _stage_header: Control
var _stage_controls: Array[Control] = []
var _selection_surface: Panel


func _init() -> void:
	setup["difficulty"] = "pro"


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
	learn_button.text = "Spielewelt"
	for connection in learn_button.pressed.get_connections():
		learn_button.pressed.disconnect(connection.callable)
	learn_button.pressed.connect(func(): exit_requested.emit("games"))
	# Brighter local studio materials; the original meshes and driver stay intact.
	garage_interior.materials.wall.albedo_color = Color("37536e")
	garage_interior.materials.floor.albedo_color = Color("415c76")
	garage_interior.materials.ivory.albedo_color = Color("e2e4dc")
	_spatial_ready = true
	_refresh()


func set_landing_active(active: bool) -> void:
	_landing_active = active
	if active:
		step = 0
		_refresh()
	for control in _stage_controls:
		control.visible = not active
	_selection_surface.visible = not active
	view_choice.visible = not active and step in [1, 2]
	preview_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_fit_welcome_camera()


func _refresh() -> void:
	super._refresh()
	if not _spatial_ready:
		return
	for button in garage_buttons.values():
		button.body.hide()
	garage_interior.root.visible = step != 3
	workshop_button.visible = step == 2
	kart_bars.hide()
	subtitle.hide()
	title_label.text = ["Rennen", "Dein Fahrer", "Deine Garage", "Rennwelten", "Tempo & Gegner"][step]
	_apply_responsive_layout.call_deferred()


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
	var narrow := available.x < 520.0
	var short_view := available.y < 440.0
	var ultra_short := available.y < 300.0
	# A 240dp safe area cannot contain the tabs, footer, a full kart card
	# AND a separate 48dp workshop row. Share the existing footer instead
	# of clipping the scroll viewport below the card's touchable area.
	var workshop_in_footer := ultra_short and step == 2
	var workshop_parent: Node = footer if workshop_in_footer else setup_left
	if workshop_button.get_parent() != workshop_parent:
		workshop_button.reparent(workshop_parent, false)
		if workshop_in_footer:
			footer.move_child(workshop_button, next_button.get_index())
	workshop_button.text = "Werkstatt" if workshop_in_footer else "Lack, Teile & Effekte"
	var margin := 12.0 if narrow or short_view else 20.0
	var header_height := 0.0 if ultra_short else (48.0 if short_view else 64.0)
	var tabs_y := margin + header_height + (0.0 if ultra_short else 8.0)
	var footer_height := 52.0 if short_view else 60.0
	var footer_y := available.y - margin - footer_height
	_apply_ui_scale(self, scale_factor)
	_stage_rect(_stage_header, Rect2(margin, margin, available.x - margin * 2, header_height), scale_factor)
	_stage_rect(step_strip, Rect2(margin, tabs_y, available.x - margin * 2, 48), scale_factor)
	_set_physical_minimum(brand_wordmark, Vector2(112 if short_view else 136, header_height - 4), scale_factor)
	_set_physical_minimum(header_row, Vector2.ZERO, scale_factor)
	_set_physical_minimum(learn_button, Vector2(104, 48), scale_factor)
	_set_physical_font(learn_button, 14, scale_factor)
	var reward_style := progress_panel.get_theme_stylebox("panel") as StyleBoxFlat
	reward_style.set_content_margin_all(0)
	progress_label.visible = not narrow
	progress_icon.visible = not narrow
	_set_physical_font(progress_label, 16, scale_factor)
	for index in range(step_buttons.size()):
		var tab := step_buttons[index]
		tab.text = ["Rennen", "Fahrer", "Karts", "Strecken", "Tempo"][index]
		_set_physical_minimum(tab, Vector2(48, 48), scale_factor)
		_set_physical_font(tab, 12 if narrow else 15, scale_factor)
	var top := tabs_y + 60.0
	var choices_rect: Rect2
	if portrait:
		var drawer_height := clampf(available.y * 0.30, 160.0, 286.0)
		choices_rect = Rect2(margin, maxf(top + 60.0, footer_y - drawer_height - 12), available.x - margin * 2, drawer_height)
	else:
		choices_rect = Rect2(margin, top, clampf(available.x * 0.31, 208, 360), maxf(72, footer_y - top - 12))
	_stage_rect(_selection_surface, choices_rect, scale_factor)
	_stage_rect(setup_left, choices_rect.grow(-4.0 if short_view else -10.0), scale_factor)
	setup_left.custom_minimum_size = Vector2.ZERO
	setup_left.add_theme_constant_override("separation", roundi(6 * scale_factor))
	_set_physical_font(title_label, 18 if short_view or narrow else 23, scale_factor)
	title_label.visible = not short_view
	_set_physical_minimum(workshop_button, Vector2(0, 48), scale_factor)
	_set_physical_font(workshop_button, 15, scale_factor)
	for child in choices.get_children():
		if child is GridContainer:
			child.columns = 2 if portrait and not narrow and step == 2 else 1
		var cards: Array = child.get_children() if child is GridContainer else [child]
		for card in cards:
			if card is Button:
				var card_height := (72 if ultra_short else 90) if step == 2 else (64 if step == 0 else 68)
				_set_physical_minimum(card, Vector2(0, card_height), scale_factor)
				_set_physical_font(card, 16, scale_factor)
				if card.has_method("apply_size"):
					card.apply_size(scale_factor, true)
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
	view_choice.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	view_choice.offset_left = -194 * scale_factor
	view_choice.offset_right = -margin * scale_factor
	view_choice.offset_top = top * scale_factor
	view_choice.offset_bottom = (top + 48) * scale_factor
	view_choice.visible = not _landing_active and step in [1, 2]
	for control in _stage_controls:
		control.visible = not _landing_active
	_stage_header.visible = not _landing_active and not ultra_short
	_selection_surface.visible = not _landing_active
	call_deferred("_fit_welcome_camera")


func _stage_rect(control: Control, rect: Rect2, ui_scale: float) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	control.position = rect.position * ui_scale
	control.size = rect.size * ui_scale


func _choose_preview_view(index: int, animate: bool = true) -> void:
	if is_instance_valid(preview_camera):
		preview_camera.h_offset = 0.0
		preview_camera.v_offset = 0.0
	super._choose_preview_view(index, animate)
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
	# Fit the actual chassis, seated rig and light rings to the unoccluded
	# part of the live stage. Portrait width cannot reuse a landscape frustum.
	var focus := Vector3(0, 0.95, 0)
	# A camera offset translates the optical origin too. The shallower side
	# angle keeps that origin inside the open service bay after the framing
	# offset, so its right wall cannot occlude an otherwise valid frustum.
	var direction := Vector3(1.6, 1.05, -4.6).normalized()
	var region := Rect2(0.36, 0.19, 0.61, 0.60)
	if aspect < 1.0:
		region = Rect2(0.04, 0.18, 0.92, 0.38 if _landing_active else 0.35)
	var pixels := Vector2(preview_viewport.size)
	var target := Rect2(region.position * pixels, region.size * pixels)
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
		points = _stage_subject_points()
	var distance := 6.0 if step == 3 else 4.8
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
	_camera_progress = 1.0
	_camera_ready = true
	_camera_focus = focus
	_set_camera_veil(0.0)


func _stage_subject_points() -> Array[Vector3]:
	var points: Array[Vector3] = []
	for mesh in preview_kart.find_children("*", "MeshInstance3D", true, false):
		if not mesh.is_visible_in_tree() or mesh.skin != null or mesh == preview_kart.far_mesh:
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
	for ring in stage_rings:
		for sample in range(32):
			var angle := TAU * sample / 32.0
			var radius: float = ring.mesh.outer_radius
			points.append(ring.to_global(Vector3(cos(angle) * radius, 0, sin(angle) * radius)))
	return points


func _process(delta: float) -> void:
	var previous_angle := preview_angle
	super._process(delta)
	if not visible or not _spatial_ready:
		return
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
