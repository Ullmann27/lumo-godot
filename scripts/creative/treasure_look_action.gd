extends "res://scripts/games/kart_touch_action.gd"
## „Ansehen“-Knopf der Schatzsuche: eine Lupe statt der Raketen-Grafik aus
## Lumo Kart. Berührung, Mehrfinger-Bedienung und Signale bleiben die des
## gemeinsamen Daumenknopfs.

const LENS_GOLD := Color("ffd166")


func _ready() -> void:
	super()
	icon_id = "look"
	accent = LENS_GOLD
	tooltip_text = "Ansehen: Hinweis oder Entdeckung in der Nähe untersuchen"


func _draw() -> void:
	var side: float = minf(size.x, size.y)
	var center := Vector2(size.x * 0.5, side * 0.5 + press_depth * side * 0.04)
	var radius: float = side * 0.47
	var tint: Color = Color("67809b") if disabled else accent
	draw_circle(center + Vector2(0, side * 0.035), radius, Color(0.02, 0.06, 0.13, 0.85))
	draw_circle(center, radius, Color("173a5e").lerp(tint, 0.38 if held else 0.16))
	draw_arc(center, radius - side * 0.02, 0.0, TAU, 56, tint, side * 0.035, true)
	# Lupe: Glas, Rand, Griff und ein kleiner Lichtpunkt.
	var lens := center + Vector2(-side * 0.05, -side * 0.1)
	var lens_radius: float = side * 0.17
	var face: Color = Color(0.85, 0.9, 0.97, 0.75) if disabled else Color.WHITE
	draw_circle(lens, lens_radius, Color(0.55, 0.85, 1.0, 0.35))
	draw_arc(lens, lens_radius, 0.0, TAU, 40, face, side * 0.045, true)
	var handle_from := lens + Vector2.ONE.normalized() * lens_radius * 1.05
	var handle_to := handle_from + Vector2.ONE.normalized() * side * 0.17
	draw_line(handle_from, handle_to, tint.darkened(0.15), side * 0.075, true)
	draw_arc(
		lens, lens_radius * 0.62, PI * 1.1, PI * 1.45, 10, Color(1, 1, 1, 0.9), side * 0.03, true
	)
