extends RefCounted
## Lumo Kart race HUD dressing. kart_island.gd builds the HUD nodes (names, sizes and the
## responsive layout stay there, the layout tests rely on them); this helper gives them the
## new look and feeds the live displays:
##   dress()    once after _build_ui: rendered buttons + stick, glass bar with badge/tacho,
##              message plate, framed minimap, matching top buttons
##   relayout() at the end of every responsive layout pass (font sizes, bar scale)
##   push()     every HUD update: real values into the bar and the button meters

const BAR = preload("res://scripts/games/kart_hud/kart_race_bar.gd")
const MESSAGE_PLATE = preload("res://scripts/games/kart_hud/kart_message_plate.gd")
const RACE_RULES = preload("res://scripts/games/kart_items/kart_race_rules.gd")
const GLASS := Color(0.02, 0.06, 0.15, 0.80)
const RIM := Color("6fe6ff")


static func glass_style(radius: float, border: float, fill: Color = GLASS, rim: Color = RIM) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = Color(rim, 0.78)
	style.set_border_width_all(maxi(1, roundi(border)))
	style.set_corner_radius_all(roundi(radius))
	style.shadow_color = Color(rim, 0.16)
	style.shadow_size = maxi(2, roundi(border * 3.0))
	style.anti_aliasing = true
	return style


static func dress(game: Node) -> void:
	for action in game.pedal_pad.get_children():
		if action.get("skin") != null:
			action.skin = "kart3d"
	game.joystick.skin = "kart3d"
	var panel: Control = game.hud.get_parent()
	if panel.get_node_or_null("KartRaceBar") == null:
		var bar: Control = BAR.new()
		panel.add_child(bar)
	# The text label stays for layout, tests and accessibility; the bar draws the values.
	game.hud.add_theme_color_override("font_color", Color(0, 0, 0, 0))
	game.hud.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	game.hud.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))
	var message: Label = game.message
	if message.get_node_or_null("MessagePlate") == null:
		message.add_child(MESSAGE_PLATE.new())
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message.add_theme_font_override("font", preload("res://assets/fonts/Nunito-Black.ttf"))
	message.add_theme_color_override("font_color", Color("fbfdff"))
	message.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	message.add_theme_color_override("font_outline_color", Color("061430"))
	relayout(game, 1.0, false)


## Linkshänder: Lenk-Stick rechts, Knopf-Feld links und darin gespiegelt. Läuft am Ende jedes
## Layout-Durchgangs (die Positionen der Knöpfe stehen dann schon fest).
static func apply_handedness(game: Node) -> void:
	var left_handed: bool = bool(game.get("left_handed"))
	var row: Container = game.controls_row
	if not is_instance_valid(row) or not is_instance_valid(game.joystick) or not is_instance_valid(game.pedal_pad):
		return
	var stick: Control = game.joystick
	var pad: Control = game.pedal_pad
	var first: Control = pad if left_handed else stick
	var last: Control = stick if left_handed else pad
	if first.get_index() != 0:
		row.move_child(first, 0)
	if last.get_index() != row.get_child_count() - 1:
		row.move_child(last, row.get_child_count() - 1)
	pad.set_meta("kart_mirrored", left_handed)
	var width: float = maxf(pad.custom_minimum_size.x, pad.size.x)
	for child in pad.get_children():
		if not child is Control:
			continue
		# Idempotent: "kart_mirror_x" merkt sich die gespiegelte Lage. Steht der Knopf schon
		# dort, ist nichts zu tun; beim Zurückschalten wird genau diese Lage aufgehoben.
		var mirrored_already: bool = child.has_meta("kart_mirror_x") and absf(child.position.x - float(child.get_meta("kart_mirror_x"))) < 0.01
		if left_handed and not mirrored_already:
			child.position.x = width - child.position.x - child.size.x
			child.set_meta("kart_mirror_x", child.position.x)
		elif not left_handed:
			if mirrored_already:
				child.position.x = width - child.position.x - child.size.x
			if child.has_meta("kart_mirror_x"):
				child.remove_meta("kart_mirror_x")


static func handedness_text(left_handed: bool) -> String:
	return "Steuerung: Linkshänder (Lenken rechts)" if left_handed else "Steuerung: Rechtshänder (Lenken links)"


static func relayout(game: Node, ui_scale: float, short_landscape: bool) -> void:
	apply_handedness(game)
	var panel: PanelContainer = game.hud.get_parent()
	var k: float = ui_scale
	var bar_style := glass_style(18.0 * k, 2.0 * k)
	bar_style.content_margin_left = 10.0 * k
	bar_style.content_margin_right = 10.0 * k
	bar_style.content_margin_top = 3.0 * k
	bar_style.content_margin_bottom = 3.0 * k
	panel.add_theme_stylebox_override("panel", bar_style)
	var bar: Control = panel.get_node_or_null("KartRaceBar")
	if bar != null:
		bar.k = k
		bar.reduced_motion = bool(game.reduced_motion)
	for button in [game.top_menu_button, game.top_reset_button, game.top_pause_button]:
		if not button is Button:
			continue
		button.add_theme_stylebox_override("normal", glass_style(18.0 * k, 2.0 * k))
		button.add_theme_stylebox_override("hover", glass_style(18.0 * k, 2.0 * k, Color(0.05, 0.14, 0.3, 0.86)))
		button.add_theme_stylebox_override("pressed", glass_style(18.0 * k, 3.0 * k, Color(0.08, 0.3, 0.5, 0.92), Color("b6f4ff")))
		button.add_theme_stylebox_override("focus", glass_style(18.0 * k, 3.0 * k, Color(0, 0, 0, 0), Color.WHITE))
		button.add_theme_font_override("font", preload("res://assets/fonts/Nunito-Black.ttf"))
	if is_instance_valid(game.map_panel):
		var map_style := glass_style(16.0 * k, 2.0 * k, Color(0.02, 0.06, 0.15, 0.74))
		map_style.set_content_margin_all(8.0 * k)
		game.map_panel.add_theme_stylebox_override("panel", map_style)
	var message: Label = game.message
	var font_size: int = roundi((17.0 if short_landscape else 25.0) * k)
	message.add_theme_font_size_override("font_size", font_size)
	message.add_theme_constant_override("outline_size", maxi(2, roundi(font_size * 0.16)))
	message.custom_minimum_size.y = ceilf(font_size * (1.5 if short_landscape else 2.9))
	var plate: Control = message.get_node_or_null("MessagePlate")
	if plate != null:
		plate.reduced_motion = bool(game.reduced_motion)
		plate.queue_redraw()
	for action in game.pedal_pad.get_children():
		if action.get("reduced_motion") != null:
			action.reduced_motion = bool(game.reduced_motion)
	game.joystick.reduced_motion = bool(game.reduced_motion)


static func top_speed_kmh(game: Node) -> float:
	if game.kart_factors.is_empty():
		return 100.0
	var rules: Dictionary = game.CATALOG.entry(game.CATALOG.DIFFICULTIES, game.difficulty)
	return maxf(10.0, float(game.POWERTRAIN.top_speed(game.kart_factors, float(rules.get("speed", 1.0)))) * 3.6)


## Real race values into the bar and the live button rings (called from _update_hud).
static func push(game: Node, place: int, display_speed: int) -> void:
	var delta: float = game.get_process_delta_time()
	var top: float = top_speed_kmh(game)
	var panel: Control = game.hud.get_parent()
	var bar: Control = panel.get_node_or_null("KartRaceBar")
	if bar != null:
		var lap: int = mini(game.TOTAL_LAPS, int(game.distance / maxf(game.track_length, 0.001)) + 1)
		bar.show_values({
			"mode": game.mode, "lap": lap, "laps": game.TOTAL_LAPS, "place": place, "field": 6,
			"speed": display_speed, "top": top, "stars": game.collected.size(),
			"time": maxf(0.0, 90.0 - game.elapsed) if game.mode == "arena" else game.elapsed,
			"score": game.arena_scores,
		}, delta)
	if game.gas_button.get("skin") == "kart3d":
		game.gas_button.meter = clampf(float(display_speed) / top, 0.0, 1.0)
		var charge: float = float(game.drift_charge)
		game.drift_button.tier = RACE_RULES.drift_tier(charge)
		game.drift_button.meter = clampf(charge / RACE_RULES.DRIFT_TIERS[2], 0.0, 1.0) if game.drifting else 0.0
		game.boost_button.stock = int(game.boosts)
		game.boost_button.meter = clampf(float(game.boost_time) / 3.2, 0.0, 1.0)
