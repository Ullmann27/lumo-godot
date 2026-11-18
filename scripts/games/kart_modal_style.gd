extends RefCounted
## Pause- und Einstellungsfenster im Stil des Neon-Hauptmenüs: dunkles Glas mit
## Leuchtkante, farbige Knöpfe mit Lichtkante. Gold nur für die wichtigste Aktion
## (Weiterfahren). Größen in dp, `k` = Pixel je dp wie im übrigen Menü.
const UI = preload("res://scripts/games/kart_ui_theme.gd")
const NEON := Color("21ccff")
const GOLD := Color("ffc23d")
const VIOLET := Color("8a5cff")
## Knopfname → Akzent. Alles andere bekommt das Neon-Blau des Hauptmenüs.
const ACCENTS := {
	"PauseResume": GOLD,
	"FinishTraining": Color("37e0a0"),
	"PauseNewDrive": VIOLET,
	"PauseAbandon": Color("ff6a7d"),
	"DifficultyToggle": Color("37e0a0"),
	"CloseKartSettings": GOLD,
}


static func panel(k: float) -> StyleBoxFlat:
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color("08133a", 0.97)
	skin.border_color = NEON
	skin.set_border_width_all(maxi(1, roundi(2.0 * k)))
	skin.set_corner_radius_all(roundi(22.0 * k))
	skin.set_content_margin_all(14.0 * k)
	skin.shadow_color = Color(NEON.r, NEON.g, NEON.b, 0.30)
	skin.shadow_size = roundi(14.0 * k)
	return skin


static func button_skin(accent: Color, k: float, state: String, gold: bool) -> StyleBoxFlat:
	var skin := StyleBoxFlat.new()
	var base := accent if gold else accent.darkened(0.55)
	skin.bg_color = base
	if state == "hover" or state == "focus":
		skin.bg_color = base.lightened(0.12)
	elif state == "pressed":
		skin.bg_color = base.darkened(0.12)
	elif state == "disabled":
		skin.bg_color = Color("26364b")
	skin.bg_color.a = 0.97
	# Lichtkante oben wie bei den Kacheln des Hauptmenüs, Schatten unten.
	skin.border_color = accent.lightened(0.35) if state != "disabled" else Color("455971")
	skin.border_width_top = maxi(1, roundi(3.0 * k))
	skin.border_width_left = maxi(1, roundi(1.5 * k))
	skin.border_width_right = maxi(1, roundi(1.5 * k))
	skin.border_width_bottom = maxi(1, roundi((1.5 if state == "pressed" else 4.0) * k))
	if not gold and state != "disabled":
		skin.border_color = accent
	skin.set_corner_radius_all(roundi(16.0 * k))
	skin.content_margin_left = 16.0 * k
	skin.content_margin_right = 16.0 * k
	skin.content_margin_top = 6.0 * k
	skin.content_margin_bottom = 8.0 * k
	return skin


static func dress_button(button: Button, k: float) -> void:
	var accent: Color = ACCENTS.get(str(button.name), NEON)
	var gold: bool = accent == GOLD
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, button_skin(accent, k, state, gold))
	button.add_theme_font_override("font", UI.HEADING)
	var face := Color("2a1600") if gold else Color("f7fbff")
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, face)
	button.add_theme_color_override("font_disabled_color", Color("9fb4d8"))


## Fenster und alle Knöpfe darin (auch die feste Navigation unter der Liste) einkleiden.
static func dress(modal: Control, k: float) -> void:
	modal.add_theme_stylebox_override("panel", panel(k))
	for node in modal.find_children("*", "Button", true, false):
		var button := node as Button
		if button is OptionButton or button is CheckBox:
			continue
		dress_button(button, k)
