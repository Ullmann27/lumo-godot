extends RefCounted
## Zieleinlauf-Bausatz: Farben, Schrift, Flächen und Vektor-Icons der Ergebnisanzeige.
##
## TEXTUR-TAUSCH AN EINER STELLE: Liegt unter TEXTURE_DIR eine PNG mit einem der
## Namen aus TEXTURE_IDS, zeichnen Abzeichen, Zeilen, Icons und Knöpfe diese
## Textur statt der Vektorform. Ohne Datei bleibt alles wie hier gezeichnet.
## Zahl, „PLATZ“ und alle Werte bleiben immer echter Text.
const UI = preload("res://scripts/games/kart_ui_theme.gd")
const TEXTURE_DIR := "res://assets/kart/result/"
const TEXTURE_IDS: Array[String] = [
	"badge_gold", "badge_silver", "badge_bronze", "badge_neutral",
	"row", "button_primary", "button_secondary", "button_small",
	"icon_time", "icon_lap", "icon_token", "icon_reward", "icon_crystal",
	"icon_pass", "icon_record", "icon_cup", "icon_notice", "star"
]
## Entwurfsbreite der Tafel; alle Maße der Ergebnisanzeige beziehen sich darauf.
const DESIGN_WIDTH: float = 560.0
const NAVY_TEXT := Color("1a2450")
const ROW_TEXT := Color("eaf3ff")
const VALUE_TEXT := Color("ffffff")
const CYAN := Color("53ddfd")
const TIERS: Dictionary = {
	"gold": {
		"light": Color("fff7c2"), "mid": Color("ffcf3f"), "dark": Color("d9870a"),
		"deep": Color("7a3d00"), "glow": Color("ffb21a")
	},
	"silver": {
		"light": Color("ffffff"), "mid": Color("d3dfee"), "dark": Color("8496b1"),
		"deep": Color("33425d"), "glow": Color("bfe2ff")
	},
	"bronze": {
		"light": Color("ffe0bd"), "mid": Color("f3a05a"), "dark": Color("b25a20"),
		"deep": Color("5c2709"), "glow": Color("ff9a4a")
	},
	"neutral": {
		"light": Color("f4fcff"), "mid": Color("bfe8fc"), "dark": Color("5aa7d6"),
		"deep": Color("0b2f52"), "glow": Color("53ddfd")
	},
}
static var _textures: Dictionary = {}
static var _display_font: FontVariation
static var _spaced_font: FontVariation
static var _metal_shader: Shader


## Die eine Stelle für gerenderte Texturen (siehe Kopfkommentar). Null = selbst zeichnen.
static func texture(id: String) -> Texture2D:
	if not _textures.has(id):
		var path: String = TEXTURE_DIR + id + ".png"
		_textures[id] = load(path) if ResourceLoader.exists(path) else null
	return _textures[id]


static func tier_name(place: int, ranked: bool) -> String:
	if not ranked:
		return "neutral"
	match place:
		1:
			return "gold"
		2:
			return "silver"
		3:
			return "bronze"
	return "neutral"


static func tier(place: int, ranked: bool) -> Dictionary:
	return TIERS[tier_name(place, ranked)]


## Schräg gestellte Nunito Black für Zahl, „PLATZ“ und Knöpfe (kein fremder Font).
static func display_font() -> FontVariation:
	if _display_font == null:
		_display_font = FontVariation.new()
		_display_font.base_font = UI.HEADING
		_display_font.variation_transform = Transform2D(Vector2(1.0, 0.19), Vector2(0.0, 1.0), Vector2.ZERO)
	return _display_font


static func spaced_font() -> FontVariation:
	if _spaced_font == null:
		_spaced_font = FontVariation.new()
		_spaced_font.base_font = UI.BODY
		_spaced_font.spacing_glyph = 2
	return _spaced_font


## Metallverlauf mit Horizontkante; die Schrift liefert nur die Deckkraft.
static func metal_material(colors: Dictionary, y_top: float, y_bottom: float) -> ShaderMaterial:
	if _metal_shader == null:
		_metal_shader = Shader.new()
		_metal_shader.code = """shader_type canvas_item;
uniform vec4 c_top : source_color = vec4(1.0);
uniform vec4 c_mid : source_color = vec4(1.0);
uniform vec4 c_low : source_color = vec4(1.0);
uniform vec4 c_bottom : source_color = vec4(1.0);
uniform float y_top = 0.0;
uniform float y_bottom = 100.0;
uniform float horizon = 0.58;
varying float local_y;
void vertex() {
	local_y = VERTEX.y;
}
void fragment() {
	float t = clamp((local_y - y_top) / max(1.0, y_bottom - y_top), 0.0, 1.0);
	vec3 upper = mix(c_top.rgb, c_mid.rgb, smoothstep(0.0, horizon, t));
	vec3 lower = mix(c_low.rgb, c_bottom.rgb, smoothstep(horizon, 1.0, t));
	COLOR = vec4(mix(upper, lower, smoothstep(horizon - 0.02, horizon + 0.02, t)), COLOR.a);
}
"""
	var material := ShaderMaterial.new()
	material.shader = _metal_shader
	material.set_shader_parameter("c_top", colors.light)
	material.set_shader_parameter("c_mid", colors.mid)
	material.set_shader_parameter("c_low", colors.dark)
	material.set_shader_parameter("c_bottom", (colors.mid as Color).lerp(colors.light, 0.35))
	material.set_shader_parameter("y_top", y_top)
	material.set_shader_parameter("y_bottom", y_bottom)
	return material


## Dunkle Glaszeile mit Neonrand; `accent` färbt Rand und Schimmer.
static func row_style(scale: float, accent: Color = CYAN) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.022, 0.078, 0.215, 0.92)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.55)
	style.set_border_width_all(maxi(1, roundi(1.4 * scale)))
	style.set_corner_radius_all(roundi(13.0 * scale))
	style.content_margin_left = 12.0 * scale
	style.content_margin_right = 16.0 * scale
	style.content_margin_top = 3.0 * scale
	style.content_margin_bottom = 3.0 * scale
	style.shadow_color = Color(0.0, 0.02, 0.08, 0.5)
	style.shadow_size = roundi(5.0 * scale)
	style.shadow_offset = Vector2(0, 3.0 * scale)
	style.anti_aliasing_size = 1.2
	return style


## Halbdurchsichtige Tafel hinter Zeilen und Knöpfen; die 3D-Szene bleibt sichtbar.
static func plate_style(scale: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.016, 0.055, 0.16, 0.68)
	style.border_color = Color(0.33, 0.78, 1.0, 0.85)
	style.set_border_width_all(maxi(1, roundi(2.0 * scale)))
	style.set_corner_radius_all(roundi(24.0 * scale))
	style.shadow_color = Color(0.18, 0.55, 1.0, 0.3)
	style.shadow_size = roundi(14.0 * scale)
	style.anti_aliasing_size = 1.2
	return style


static func font_size(design: float, scale: float, dp: float, minimum_dp: float = 12.0) -> int:
	return maxi(roundi(minimum_dp * dp), roundi(design * scale))


## Abgerundetes Rechteck mit echtem Farbverlauf von oben nach unten.
static func draw_gradient_box(
	canvas: CanvasItem, rect: Rect2, radius: float, top: Color, bottom: Color, outline: Color = Color.TRANSPARENT,
	outline_width: float = 1.0
) -> void:
	if rect.size.x <= 2.0 or rect.size.y <= 2.0:
		return
	var r: float = minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	var centres: Array[Vector2] = [
		rect.position + Vector2(r, r), Vector2(rect.end.x - r, rect.position.y + r),
		rect.end - Vector2(r, r), Vector2(rect.position.x + r, rect.end.y - r)
	]
	for corner in range(4):
		for step in range(7):
			var angle: float = PI + PI * 0.5 * (float(corner) + float(step) / 6.0)
			var point: Vector2 = centres[corner] + Vector2.from_angle(angle) * r
			# Where two arcs meet (pill shape) or the radius is zero, points
			# coincide; duplicates make the triangulation fail.
			if not points.is_empty() and point.distance_squared_to(points[points.size() - 1]) < 0.0004:
				continue
			points.append(point)
			colors.append(top.lerp(bottom, clampf((point.y - rect.position.y) / rect.size.y, 0.0, 1.0)))
	if points.size() > 3 and points[0].distance_squared_to(points[points.size() - 1]) < 0.0004:
		points.remove_at(points.size() - 1)
		colors.remove_at(colors.size() - 1)
	if points.size() < 3:
		return
	canvas.draw_polygon(points, colors)
	if outline.a > 0.0:
		points.append(points[0])
		canvas.draw_polyline(points, outline, outline_width, true)


static func star_points(center: Vector2, outer: float, inner: float, turn: float = 0.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(10):
		var angle: float = -PI * 0.5 + turn + PI * float(index) / 5.0
		points.append(center + Vector2.from_angle(angle) * (outer if index % 2 == 0 else inner))
	return points


## Facettierter Stern: jede Zacke hat eine helle und eine dunkle Hälfte.
static func draw_star(canvas: CanvasItem, center: Vector2, radius: float, colors: Dictionary = TIERS.gold) -> void:
	if radius < 0.5:
		return
	var replacement: Texture2D = texture("star")
	if replacement != null:
		canvas.draw_texture_rect(replacement, Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), false)
		return
	var shadow: PackedVector2Array = star_points(center + Vector2(0, radius * 0.14), radius * 1.08, radius * 0.52)
	canvas.draw_colored_polygon(shadow, Color(0.0, 0.02, 0.08, 0.45))
	canvas.draw_colored_polygon(star_points(center, radius * 1.1, radius * 0.54), colors.deep)
	var points: PackedVector2Array = star_points(center, radius, radius * 0.46)
	for index in range(10):
		var lit: bool = index % 2 == 1
		var shade: Color = (colors.light as Color).lerp(colors.mid, 0.45) if lit else (colors.mid as Color).lerp(colors.dark, 0.55)
		if index in [3, 4, 5, 6]:
			shade = shade.darkened(0.12)
		canvas.draw_colored_polygon(PackedVector2Array([center, points[index], points[(index + 1) % 10]]), shade)
	canvas.draw_circle(center + Vector2(-0.22, -0.3) * radius, radius * 0.1, Color(1, 1, 1, 0.85))


static func _ring(canvas: CanvasItem, center: Vector2, radius: float, width: float, color: Color) -> void:
	canvas.draw_arc(center, radius, 0.0, TAU, 40, color, width, true)


## Kleine Icons mit Glanz und Schatten; `kind` wie in TEXTURE_IDS ohne „icon_“.
static func draw_icon(canvas: CanvasItem, kind: String, center: Vector2, size: float) -> void:
	if size < 1.0:
		return
	var replacement: Texture2D = texture("icon_" + kind)
	if replacement != null:
		canvas.draw_texture_rect(replacement, Rect2(center - Vector2.ONE * size * 0.5, Vector2.ONE * size), false)
		return
	var s: float = size
	var line: float = maxf(1.5, s * 0.085)
	var dark := Color(0.0, 0.03, 0.1, 0.5)
	match kind:
		"time":
			var c: Vector2 = center + Vector2(0, s * 0.05)
			canvas.draw_circle(c + Vector2(0, s * 0.05), s * 0.42, dark)
			canvas.draw_circle(c, s * 0.4, Color("0b2d5e"))
			_ring(canvas, c, s * 0.36, line * 1.25, CYAN)
			canvas.draw_arc(c, s * 0.36, -PI * 0.95, -PI * 0.35, 12, Color(1, 1, 1, 0.75), line * 0.7, true)
			canvas.draw_rect(Rect2(c + Vector2(-0.09, -0.52) * s, Vector2(0.18, 0.1) * s), CYAN)
			canvas.draw_line(c + Vector2(0.26, -0.34) * s, c + Vector2(0.34, -0.42) * s, CYAN, line, true)
			canvas.draw_line(c, c + Vector2(0, -0.22) * s, Color.WHITE, line, true)
			canvas.draw_line(c, c + Vector2(0.15, 0.06) * s, Color.WHITE, line, true)
			canvas.draw_circle(c, s * 0.055, Color.WHITE)
		"lap":
			canvas.draw_line(center + Vector2(-0.34, 0.46) * s, center + Vector2(-0.34, -0.42) * s, Color("d9ecff"), line * 1.2, true)
			var cell: float = s * 0.17
			for row in range(3):
				for col in range(4):
					var wave: float = sin(float(col) * 1.25) * s * 0.035
					var origin: Vector2 = center + Vector2(-0.3, -0.42) * s + Vector2(col * cell, row * cell + wave)
					canvas.draw_rect(
						Rect2(origin, Vector2(cell + 0.5, cell + 0.5)),
						Color.WHITE if (row + col) % 2 == 0 else Color("16407c")
					)
			canvas.draw_circle(center + Vector2(-0.34, -0.44) * s, s * 0.06, CYAN)
		"token":
			_ring(canvas, center, s * 0.4, line, Color(CYAN.r, CYAN.g, CYAN.b, 0.9))
			draw_star(canvas, center, s * 0.26, TIERS.neutral)
		"reward":
			draw_star(canvas, center, s * 0.44)
		"crystal":
			var top: Vector2 = center + Vector2(0, -0.46) * s
			var low: Vector2 = center + Vector2(0, 0.46) * s
			var left: Vector2 = center + Vector2(-0.32, -0.08) * s
			var right: Vector2 = center + Vector2(0.32, -0.08) * s
			var mid: Vector2 = center + Vector2(0, -0.08) * s
			canvas.draw_colored_polygon(PackedVector2Array([top, mid, left]), Color("b6f3ff"))
			canvas.draw_colored_polygon(PackedVector2Array([top, right, mid]), Color("5fd3fa"))
			canvas.draw_colored_polygon(PackedVector2Array([left, mid, low]), Color("39a9e6"))
			canvas.draw_colored_polygon(PackedVector2Array([mid, right, low]), Color("1f74bd"))
		"pass":
			for x in [-0.14, 0.14]:
				canvas.draw_colored_polygon(PackedVector2Array([
					center + Vector2(x - 0.11, -0.48) * s, center + Vector2(x + 0.11, -0.48) * s,
					center + Vector2(x * 0.3 + 0.1, -0.02) * s, center + Vector2(x * 0.3 - 0.1, -0.02) * s
				]), Color("3b9be8") if x < 0 else Color("2a6fc4"))
			canvas.draw_circle(center + Vector2(0, 0.2) * s, s * 0.3, TIERS.gold.deep)
			canvas.draw_circle(center + Vector2(0, 0.17) * s, s * 0.27, TIERS.gold.mid)
			canvas.draw_colored_polygon(star_points(center + Vector2(0, 0.17) * s, s * 0.16, s * 0.07), TIERS.gold.light)
		"record", "cup":
			var gold: Dictionary = TIERS.gold
			var cup := PackedVector2Array([
				center + Vector2(-0.28, -0.42) * s, center + Vector2(0.28, -0.42) * s,
				center + Vector2(0.2, 0.0) * s, center + Vector2(0.0, 0.12) * s, center + Vector2(-0.2, 0.0) * s
			])
			canvas.draw_arc(center + Vector2(-0.28, -0.24) * s, s * 0.13, PI * 0.5, PI * 1.5, 10, gold.dark, line, true)
			canvas.draw_arc(center + Vector2(0.28, -0.24) * s, s * 0.13, -PI * 0.5, PI * 0.5, 10, gold.dark, line, true)
			canvas.draw_colored_polygon(cup, gold.mid)
			canvas.draw_colored_polygon(PackedVector2Array([cup[0], center + Vector2(-0.1, -0.42) * s, center + Vector2(-0.08, 0.04) * s, cup[4]]), gold.light)
			canvas.draw_rect(Rect2(center + Vector2(-0.05, 0.1) * s, Vector2(0.1, 0.2) * s), gold.dark)
			canvas.draw_rect(Rect2(center + Vector2(-0.24, 0.3) * s, Vector2(0.48, 0.12) * s), gold.mid)
		"notice":
			canvas.draw_colored_polygon(PackedVector2Array([
				center + Vector2(0, -0.44) * s, center + Vector2(0.46, 0.4) * s, center + Vector2(-0.46, 0.4) * s
			]), Color("ffb648"))
			canvas.draw_line(center + Vector2(0, -0.18) * s, center + Vector2(0, 0.12) * s, NAVY_TEXT, line * 1.3, true)
			canvas.draw_circle(center + Vector2(0, 0.26) * s, line * 0.8, NAVY_TEXT)
		"next":
			for x in [-0.2, 0.12]:
				canvas.draw_polyline(PackedVector2Array([
					center + Vector2(x - 0.12, -0.3) * s, center + Vector2(x + 0.16, 0) * s,
					center + Vector2(x - 0.12, 0.3) * s
				]), Color("8a4a00"), line * 1.9, true)
		"replay":
			canvas.draw_arc(center, s * 0.3, -PI * 0.2, PI * 1.45, 22, CYAN, line * 1.7, true)
			var tip: Vector2 = center + Vector2.from_angle(-PI * 0.2) * s * 0.3
			canvas.draw_colored_polygon(PackedVector2Array([
				tip + Vector2(-0.2, -0.16) * s, tip + Vector2(0.14, -0.2) * s, tip + Vector2(0.04, 0.14) * s
			]), CYAN)
