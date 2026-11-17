extends RefCounted
## Layout only: existing race routes, profile, rewards and native preview stay owned by the hub.

static func _button(button: Button, factor: float, font_dp: int = 16) -> void:
	button.clip_text = false
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", maxi(12, roundi(font_dp * factor)))
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := button.get_theme_stylebox(state)
		if style is StyleBoxFlat:
			style.set_content_margin_all(8.0 * factor)
			style.set_corner_radius_all(roundi(12.0 * factor))
	var font: Font = button.get_theme_font("font")
	var pixels: int = button.get_theme_font_size("font_size")
	var measured := font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels)
	var width := measured.x + 16.0 * factor
	if button.icon != null:
		button.add_theme_constant_override("icon_max_width", roundi(28.0 * factor))
		width += 32.0 * factor
	button.custom_minimum_size = Vector2(maxf(48.0 * factor, ceilf(width)), maxf(48.0 * factor, ceilf(font.get_height(pixels) + 16.0 * factor)))

static func _mode_cards(hub: Control, factor: float, vertical: bool) -> void:
	for id in hub._mode_buttons:
		var card = hub._mode_buttons[id]
		card.apply_size(factor, true)
		card.custom_minimum_size = Vector2(80.0, 56.0) * factor
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card.caption_label.hide()
		# Mode cards (kart_menu_choice.gd) carry their artwork in icon_plate;
		# they have no separate badge label.
		if is_instance_valid(card.icon_plate):
			card.icon_plate.visible = vertical
			card.icon_plate.custom_minimum_size = Vector2(30.0, 30.0) * factor
		card.title_label.text = card.title
		card.title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		card.title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if vertical else HORIZONTAL_ALIGNMENT_CENTER
		card.title_label.add_theme_font_size_override("font_size", roundi(15.0 * factor))
		for child in card.get_children():
			if child is MarginContainer:
				for edge in ["left", "right", "top", "bottom"]:
					child.add_theme_constant_override("margin_" + edge, roundi(8.0 * factor))
				for row in child.get_children():
					if row is HBoxContainer:
						row.add_theme_constant_override("separation", roundi(6.0 * factor))

static func arrange(hub: Control) -> void:
	var viewport_size := hub.get_viewport_rect().size
	var runtime: Node = hub.get_tree().root.get_node_or_null("MobileRuntime")
	var density := 1.0
	if runtime != null and runtime.has_method("get_ui_density"):
		density = maxf(float(runtime.call("get_ui_density")), 0.25)
	var window_dp := Vector2(hub.get_window().size) / density
	if window_dp.x <= 0.0 or window_dp.y <= 0.0 or hub.size.x <= 0.0 or hub.size.y <= 0.0:
		return
	var factor := maxf(viewport_size.x / window_dp.x, viewport_size.y / window_dp.y)
	hub._layout_scale = factor
	hub._layout_root.size = hub.size
	var area := hub.size / factor
	var wide := area.x >= 760.0 and area.y >= 680.0
	var short_landscape := area.x >= 760.0 and area.y < 680.0
	var margin := 12.0
	var gap := 8.0
	var width := area.x - 2.0 * margin
	var header_h := 48.0 if short_landscape else 64.0
	var top := margin + header_h + gap
	var footer_h := 48.0 if short_landscape else 56.0
	var dock_h := 64.0
	var dock_y := area.y - margin - dock_h
	var footer_y := dock_y - gap - footer_h
	hub._neon_veil.position = Vector2.ZERO
	hub._neon_veil.size = hub.size
	hub._header.show()
	hub._header.add_theme_constant_override("separation", roundi(6.0 * factor))
	hub._header_profile.text = "Lumo · Fahrer" if area.x >= 600.0 else ""
	hub._header_profile.tooltip_text = "Lumo – Fahrer auswählen"
	_button(hub._header_profile, factor, 15)
	hub._logo.custom_minimum_size = Vector2(180.0 if area.x >= 600.0 else 100.0, header_h) * factor
	hub._stars.add_theme_font_size_override("font_size", roundi(18.0 * factor))
	hub._settings.text = "Optionen" if area.x >= 600.0 else "⚙"
	hub._settings.tooltip_text = "Optionen"
	_button(hub._settings, factor, 15)
	hub._rect(hub._header, Rect2(margin, margin, width, header_h), factor)

	hub._navigation.columns = 9
	hub._navigation.custom_minimum_size = Vector2.ZERO
	hub._navigation.position = Vector2.ZERO
	hub._navigation.add_theme_constant_override("h_separation", roundi(6.0 * factor))
	for child in hub._navigation.get_children():
		if child is Button:
			_button(child, factor, 15)
	hub._rect(hub._dock, Rect2(margin, dock_y, width, dock_h), factor)
	hub._start.text = "▶ START"
	hub._back.text = "← Spielewelt" if area.x >= 440.0 else "← Spiele"
	hub._skin(hub._start, hub.AMBER)
	hub._skin(hub._back, hub.NEON)
	_button(hub._start, factor, 21 if short_landscape else 24)
	_button(hub._back, factor, 15)
	hub._back.size_flags_stretch_ratio = 1.0
	hub._start.size_flags_stretch_ratio = 2.2
	hub._footer.add_theme_constant_override("separation", roundi(gap * factor))
	hub._rect(hub._footer, Rect2(margin, footer_y, width, footer_h), factor)

	for group in [hub._features, hub._extra_modes]:
		for child in group.get_children():
			if child is Button:
				_button(child, factor, 15)
	hub._features.add_theme_constant_override("separation", roundi(gap * factor))
	for group in [hub._modes, hub._extra_modes]:
		group.add_theme_constant_override("h_separation", roundi(gap * factor))
		group.add_theme_constant_override("v_separation", roundi(gap * factor))
	_mode_cards(hub, factor, wide)
	hub._highlight.show()
	hub._features.show()
	hub._track_scroll.show()
	hub._track_scroll.custom_minimum_size = Vector2(0.0, 62.0) * factor
	hub._track_row.add_theme_constant_override("separation", roundi(6.0 * factor))
	for tile in hub._track_buttons.values():
		_button(tile, factor, 14)
	_button(hub._highlight_pick, factor, 14)
	hub._highlight_title.text = "Strecken-Highlight" if wide or short_landscape else "Strecken"
	hub._highlight_title.add_theme_font_size_override("font_size", roundi(17.0 * factor))
	hub._highlight_image.custom_minimum_size = Vector2(0.0, 36.0) * factor
	for panel in [hub._highlight, hub._progress]:
		var style: StyleBox = panel.get_theme_stylebox("panel")
		if style is StyleBoxFlat:
			style.set_content_margin_all(8.0 * factor)
	hub._progress_label.text = "✦ %d gesammelte Sterne" % hub.total_stars
	hub._progress_label.add_theme_font_size_override("font_size", roundi(15.0 * factor))
	hub._progress.visible = not short_landscape
	var stage := Rect2()
	if wide:
		var left_w := 164.0 if area.x < 1100.0 else 188.0
		var right_w := 280.0 if area.x < 1000.0 else 340.0
		var feature_y := footer_y - gap - 64.0
		var bottom := feature_y - gap
		hub._modes.columns = 1
		hub._extra_modes.columns = 1
		hub._rect(hub._modes, Rect2(margin, top, left_w, 232.0), factor)
		hub._rect(hub._extra_modes, Rect2(margin, top + 240.0, left_w, 112.0), factor)
		hub._rect(hub._features, Rect2(margin, feature_y, width, 64.0), factor)
		var right_x := area.x - margin - right_w
		hub._rect(hub._highlight, Rect2(right_x, top, right_w, bottom - top - 60.0), factor)
		hub._rect(hub._progress, Rect2(right_x, bottom - 52.0, right_w, 52.0), factor)
		stage = Rect2(margin + left_w + gap, top, right_x - margin - left_w - gap * 2.0, bottom - top)
	elif short_landscape:
		var left_w := clampf(width * 0.34, 270.0, 330.0)
		var right_w := clampf(width * 0.30, 245.0, 310.0)
		var right_x := area.x - margin - right_w
		hub._modes.columns = 3
		hub._extra_modes.columns = 2
		hub._rect(hub._modes, Rect2(margin, top, left_w, 56.0), factor)
		hub._rect(hub._extra_modes, Rect2(margin, top + 64.0, left_w, 48.0), factor)
		hub._rect(hub._features, Rect2(margin, top + 120.0, left_w, 48.0), factor)
		hub._rect(hub._highlight, Rect2(right_x, top, right_w, footer_y - gap - top), factor)
		stage = Rect2(margin + left_w + gap, top, right_x - margin - left_w - gap * 2.0, footer_y - gap - top)
	else:
		var progress_y := footer_y - gap - 48.0
		var features_y := progress_y - gap - 56.0
		var extra_y := features_y - gap - 52.0
		var modes_y := extra_y - gap - 56.0
		var hero_bottom := modes_y - gap
		var model_w := width * 0.44
		hub._modes.columns = 3
		hub._extra_modes.columns = 2
		hub._rect(hub._modes, Rect2(margin, modes_y, width, 56.0), factor)
		hub._rect(hub._extra_modes, Rect2(margin, extra_y, width, 52.0), factor)
		hub._rect(hub._features, Rect2(margin, features_y, width, 56.0), factor)
		hub._rect(hub._progress, Rect2(margin, progress_y, width, 48.0), factor)
		hub._rect(hub._highlight, Rect2(margin + model_w + gap, top, width - model_w - gap, hero_bottom - top), factor)
		stage = Rect2(margin, top, model_w, hero_bottom - top)

	_button(hub._rotation_left, factor, 18)
	_button(hub._rotation_right, factor, 18)
	hub._rect(hub._rotation_left, Rect2(stage.position.x, stage.end.y - 48.0, 48.0, 48.0), factor)
	hub._rect(hub._rotation_right, Rect2(stage.end.x - 48.0, stage.end.y - 48.0, 48.0, 48.0), factor)
	hub._stage_bounds = Rect2(stage.position * factor, Vector2(stage.size.x, maxf(48.0, stage.size.y - 56.0)) * factor)
	hub.call_deferred("_publish_stage_region")
