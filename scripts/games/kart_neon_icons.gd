extends RefCounted
## Icons für das Kart-Menü. draw3d() nimmt das gerenderte 3D-Icon aus dem UI-Kit
## (assets/kart/ui3d); fehlt es, zeichnet draw() das eigene Vektor-Icon als Ersatz.
## Keine Emoji-Schrift nötig, keine fremden Assets.
const KIT = preload("res://scripts/games/kart_ui3d.gd")
## Menü-Icon -> Datei im Kit. "rotate_left" ist das gespiegelte "icon_rotate".
const KIT_ICONS := {
	"flag": "icon_flag", "trophy": "icon_trophy", "star": "icon_star_crystal", "star_gold": "icon_star_gold",
	"calendar": "icon_calendar", "wrench": "icon_wrench", "road": "icon_route", "gift": "icon_gift",
	"home": "icon_home", "gear": "icon_gear", "back": "icon_back", "play": "icon_play",
	"rotate_left": "icon_rotate", "rotate_right": "icon_rotate", "chevrons": "icon_chevrons",
	"alert": "icon_alert", "lock": "icon_lock", "crown": "icon_crown", "laurel": "icon_laurel",
	"stopwatch": "icon_stopwatch",
}
## Vektor-Ersatz für Kit-Icons ohne eigene Vektorform.
const VECTOR_FALLBACK := {"star_gold": "star", "crown": "star", "laurel": "star", "stopwatch": "play"}


## Gerendertes Icon mit Kantenlänge `s` um `c`; Vektor-Ersatz in `color`, wenn es fehlt.
static func draw3d(canvas: CanvasItem, kind: String, c: Vector2, s: float, color: Color = Color.WHITE, tint: Color = Color.WHITE) -> void:
	if KIT_ICONS.has(kind) and KIT.draw_icon(canvas, KIT_ICONS[kind], c, s, tint, kind == "rotate_left"):
		return
	draw(canvas, VECTOR_FALLBACK.get(kind, kind), c, s * 0.86, color)


static func draw(canvas: CanvasItem, kind: String, c: Vector2, s: float, color: Color) -> void:
	var w := maxf(1.5, s * 0.09)
	match kind:
		"flag":
			canvas.draw_line(c + Vector2(-0.38, 0.5) * s, c + Vector2(-0.38, -0.5) * s, color, w * 1.3, true)
			var cell := s * 0.19
			for row in range(4):
				for col in range(4):
					var origin := c + Vector2(-0.34, -0.48) * s + Vector2(col * cell, row * cell + sin(col * 1.2) * s * 0.03)
					var tint := color if (row + col) % 2 == 0 else Color(color.r, color.g, color.b, 0.25)
					canvas.draw_rect(Rect2(origin, Vector2(cell, cell)), tint)
		"trophy":
			var cup := PackedVector2Array([c + Vector2(-0.3, -0.42) * s, c + Vector2(0.3, -0.42) * s,
				c + Vector2(0.22, 0.02) * s, c + Vector2(0.0, 0.14) * s, c + Vector2(-0.22, 0.02) * s])
			canvas.draw_colored_polygon(cup, color)
			canvas.draw_arc(c + Vector2(-0.3, -0.24) * s, s * 0.14, PI * 0.5, PI * 1.5, 10, color, w)
			canvas.draw_arc(c + Vector2(0.3, -0.24) * s, s * 0.14, -PI * 0.5, PI * 0.5, 10, color, w)
			canvas.draw_rect(Rect2(c + Vector2(-0.05, 0.12) * s, Vector2(0.1, 0.2) * s), color)
			canvas.draw_rect(Rect2(c + Vector2(-0.24, 0.32) * s, Vector2(0.48, 0.12) * s), color)
		"star":
			canvas.draw_colored_polygon(star_points(c, s * 0.5, s * 0.22), color)
		"calendar":
			canvas.draw_rect(Rect2(c + Vector2(-0.4, -0.32) * s, Vector2(0.8, 0.74) * s), color, false, w)
			canvas.draw_rect(Rect2(c + Vector2(-0.4, -0.32) * s, Vector2(0.8, 0.2) * s), color)
			for x in [-0.22, 0.22]:
				canvas.draw_line(c + Vector2(x, -0.46) * s, c + Vector2(x, -0.26) * s, color, w * 1.2, true)
			canvas.draw_colored_polygon(star_points(c + Vector2(0, 0.14) * s, s * 0.17, s * 0.075), color)
		"wrench":
			canvas.draw_line(c + Vector2(-0.3, 0.36) * s, c + Vector2(0.14, -0.08) * s, color, w * 2.0, true)
			canvas.draw_arc(c + Vector2(0.22, -0.18) * s, s * 0.18, PI * 0.15, PI * 1.85, 14, color, w * 1.6)
		"road":
			var road := PackedVector2Array([c + Vector2(-0.14, -0.46) * s, c + Vector2(0.14, -0.46) * s,
				c + Vector2(0.44, 0.46) * s, c + Vector2(-0.44, 0.46) * s])
			canvas.draw_colored_polygon(road, Color(color.r, color.g, color.b, 0.35))
			canvas.draw_polyline(PackedVector2Array([road[0], road[3]]), color, w, true)
			canvas.draw_polyline(PackedVector2Array([road[1], road[2]]), color, w, true)
			for i in range(3):
				var y := -0.34 + i * 0.3
				canvas.draw_line(c + Vector2(0, y) * s, c + Vector2(0, y + 0.14) * s, color, w, true)
		"gift":
			canvas.draw_rect(Rect2(c + Vector2(-0.36, -0.1) * s, Vector2(0.72, 0.52) * s), color)
			canvas.draw_rect(Rect2(c + Vector2(-0.42, -0.26) * s, Vector2(0.84, 0.18) * s), color)
			var ribbon := Color(0.03, 0.08, 0.2, 0.55)
			canvas.draw_rect(Rect2(c + Vector2(-0.06, -0.26) * s, Vector2(0.12, 0.68) * s), ribbon)
			canvas.draw_arc(c + Vector2(-0.12, -0.34) * s, s * 0.11, 0, TAU, 12, color, w)
			canvas.draw_arc(c + Vector2(0.12, -0.34) * s, s * 0.11, 0, TAU, 12, color, w)
		"home":
			canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -0.46) * s, c + Vector2(0.46, -0.04) * s,
				c + Vector2(-0.46, -0.04) * s]), color)
			canvas.draw_rect(Rect2(c + Vector2(-0.32, -0.06) * s, Vector2(0.64, 0.48) * s), color)
			canvas.draw_rect(Rect2(c + Vector2(-0.09, 0.14) * s, Vector2(0.18, 0.28) * s), Color(0.03, 0.08, 0.2, 0.7))
		"gear":
			for i in range(8):
				var a := TAU * i / 8.0
				canvas.draw_line(c + Vector2.from_angle(a) * s * 0.26, c + Vector2.from_angle(a) * s * 0.46, color, w * 2.1, true)
			canvas.draw_circle(c, s * 0.3, color)
			canvas.draw_circle(c, s * 0.12, Color(0.03, 0.08, 0.2, 0.9))
		"kart":
			canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.46, 0.08) * s, c + Vector2(-0.2, -0.16) * s,
				c + Vector2(0.18, -0.16) * s, c + Vector2(0.46, 0.08) * s, c + Vector2(0.42, 0.2) * s, c + Vector2(-0.42, 0.2) * s]), color)
			for x in [-0.28, 0.28]:
				canvas.draw_circle(c + Vector2(x, 0.24) * s, s * 0.13, color.darkened(0.45))
				canvas.draw_circle(c + Vector2(x, 0.24) * s, s * 0.06, color)
		"chevrons":
			for i in range(2):
				var x := (-0.2 + i * 0.36) * s
				canvas.draw_polyline(PackedVector2Array([c + Vector2(x - 0.16 * s, -0.3 * s), c + Vector2(x + 0.1 * s, 0),
					c + Vector2(x - 0.16 * s, 0.3 * s)]), color, w * 1.4, true)
		"alert":
			canvas.draw_circle(c, s * 0.46, Color("ffd23f"))
			canvas.draw_line(c + Vector2(0, -0.26) * s, c + Vector2(0, 0.06) * s, Color("3a2400"), w * 1.5, true)
			canvas.draw_circle(c + Vector2(0, 0.24) * s, w * 0.85, Color("3a2400"))
		"lock":
			canvas.draw_arc(c + Vector2(0, -0.12) * s, s * 0.2, PI, TAU, 12, color, w * 1.4)
			canvas.draw_rect(Rect2(c + Vector2(-0.32, -0.1) * s, Vector2(0.64, 0.5) * s), color)
		"back":
			canvas.draw_polyline(PackedVector2Array([c + Vector2(0.16, -0.34) * s, c + Vector2(-0.18, 0) * s,
				c + Vector2(0.16, 0.34) * s]), color, w * 1.6, true)
		"play":
			canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.22, -0.32) * s, c + Vector2(0.32, 0) * s,
				c + Vector2(-0.22, 0.32) * s]), color)
		"rotate_left", "rotate_right":
			var dir := -1.0 if kind == "rotate_left" else 1.0
			canvas.draw_arc(c, s * 0.3, -PI * 0.9, PI * 0.6, 16, color, w * 1.4)
			var tip := c + Vector2.from_angle(-PI * 0.9 if dir < 0 else PI * 0.6) * s * 0.3
			canvas.draw_colored_polygon(PackedVector2Array([tip + Vector2(-0.14, 0.0) * s, tip + Vector2(0.14, 0.0) * s,
				tip + Vector2(0, 0.16 * dir) * s]), color)
		_:
			canvas.draw_circle(c, s * 0.3, color)


static func star_points(c: Vector2, outer: float, inner: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(10):
		var r := outer if i % 2 == 0 else inner
		points.append(c + Vector2.from_angle(-PI * 0.5 + PI * i / 5.0) * r)
	return points
