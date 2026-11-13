extends "res://scripts/games/kart_menu_choice.gd"
## Native Button semantics and hit testing, with an original angled race ticket.
var accent := Color("51cdec")
var _paint_scale := 1.0


func _ready() -> void:
	super._ready()
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	resized.connect(queue_redraw)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	update_selected(selected)


func update_selected(value: bool) -> void:
	selected = value
	if not is_instance_valid(title_label):
		return
	var ink := Color("152d43") if selected else Color("fff8df")
	title_label.add_theme_color_override("font_color", ink)
	caption_label.add_theme_color_override("font_color", ink if selected else Color("d0e8e9"))
	icon_style.bg_color = accent.darkened(0.25) if selected else accent.darkened(0.42)
	icon_style.bg_color.a = 0.95
	icon_style.border_color = Color("fff4c9")
	selection_mark.visible = selected
	sheen_material.set_shader_parameter("highlight", 0.8 if selected else 0.0)
	queue_redraw()


func apply_size(scale_factor: float, compact: bool, tight: bool = false) -> void:
	super.apply_size(scale_factor, compact, tight)
	_paint_scale = scale_factor
	if is_instance_valid(margin):
		margin.add_theme_constant_override("margin_left", roundi(11 * scale_factor))
	queue_redraw()


func _draw() -> void:
	if size.x <= 1 or size.y <= 1:
		return
	var inset := 2.0 * _paint_scale
	var bevel := minf(14.0 * _paint_scale, size.x * 0.09)
	var outline := PackedVector2Array([
		Vector2(inset, bevel * 0.5), Vector2(size.x - bevel, inset),
		Vector2(size.x - inset, size.y - bevel * 0.5), Vector2(bevel, size.y - inset),
	])
	var background := Color("ffce4c") if selected else Color("163f51")
	if is_hovered() or has_focus():
		background = background.lightened(0.1)
	if is_pressed():
		background = background.darkened(0.13)
	draw_colored_polygon(outline, background)
	draw_polyline(PackedVector2Array([outline[0], outline[1], outline[2], outline[3], outline[0]]),
		Color("fff0b1") if selected else accent, 2.0 * _paint_scale, true)
	var stripe := PackedVector2Array([
		Vector2(inset + 1, bevel * 0.5), Vector2(bevel * 0.7, bevel * 0.45),
		Vector2(bevel * 1.6, size.y - inset), Vector2(bevel, size.y - inset),
	])
	draw_colored_polygon(stripe, accent)
	# Racing chevrons are contained in the button's own geometry and input rect.
	var chevron_color := Color(1, 1, 1, 0.13) if not selected else Color(0.45, 0.27, 0.05, 0.12)
	for i in range(3):
		var x := size.x - (46.0 - i * 11.0) * _paint_scale
		var y := size.y * 0.5
		var reach := 12.0 * _paint_scale
		draw_polyline(PackedVector2Array([Vector2(x - reach * .45, y - reach),
			Vector2(x, y), Vector2(x - reach * .45, y + reach)]),
			chevron_color, 5.0 * _paint_scale, true)
