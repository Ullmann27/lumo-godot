extends Control
## Kindgerechte Draufsicht: dasselbe Holzbrett (Textur der Blender-Fläche) von
## oben, darauf die gerenderten Figurensymbole aufrecht, gut unterscheidbar.
## Leuchten, Sterne, Mauern und Feldnamen wie im 3D-Tisch.
##
## Reine Darstellung – Eingaben verarbeitet der Tisch über `square_at()`.

const ICONS := "res://assets/chess/icons/%s.webp"
const NAMES := ["", "pawn", "knight", "bishop", "rook", "queen", "king"]
## Anteil von Rand und Intarsienband an der Brett-Textur (0,84 m davon 0,02 je Seite).
const BAND := 0.02 / 0.84

var board := PackedInt32Array()
var glow: Dictionary = {}
var stars: Array = []
var walls: Array = []
var coords := true
var drag_square := -1
var drag_point := Vector2.ZERO
var _icons: Dictionary = {}
var _top: Texture2D
var _time := 0.0
var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.resize(64)
	_top = load("res://assets/chess/textures/board_top.webp")
	_font = ThemeDB.fallback_font
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func _process(delta: float) -> void:
	_time += delta
	if visible and not glow.is_empty():
		queue_redraw()


func icon(piece: int) -> Texture2D:
	if piece == 0:
		return null
	var key := "%s_%s" % ["w" if piece >> 3 == 0 else "b", NAMES[piece & 7]]
	if not _icons.has(key):
		var path := ICONS % key
		_icons[key] = load(path) if ResourceLoader.exists(path) else null
	return _icons[key]


func show_board(value: PackedInt32Array) -> void:
	board = value.duplicate()
	queue_redraw()


func set_glow(value: Dictionary) -> void:
	glow = value.duplicate()
	queue_redraw()


func set_props(star_squares: Array, wall_squares: Array) -> void:
	stars = star_squares.duplicate()
	walls = wall_squares.duplicate()
	queue_redraw()


## Quadrat des ganzen Bretts (mit Rand) im eigenen Rechteck.
func board_rect() -> Rect2:
	# Rand für Rahmen und Feldnamen bleibt innerhalb des eigenen Rechtecks.
	var side := minf(size.x, size.y) / 1.09
	return Rect2((size - Vector2(side, side)) * 0.5, Vector2(side, side))


func cell() -> float:
	return board_rect().size.x * (1.0 - 2.0 * BAND) / 8.0


func square_rect(sq: int) -> Rect2:
	var r := board_rect()
	var c := cell()
	var origin := r.position + Vector2.ONE * r.size.x * BAND
	return Rect2(origin + Vector2((sq & 7) * c, (7 - (sq >> 3)) * c), Vector2(c, c))


## Feld unter einem Punkt in Fensterkoordinaten, -1 außerhalb.
func square_at(global_point: Vector2) -> int:
	if not visible:
		return -1
	var local := get_global_transform_with_canvas().affine_inverse() * global_point
	var r := board_rect()
	var c := cell()
	var origin := r.position + Vector2.ONE * r.size.x * BAND
	var f := int(floor((local.x - origin.x) / c))
	var rank := 7 - int(floor((local.y - origin.y) / c))
	if f < 0 or f > 7 or rank < 0 or rank > 7:
		return -1
	return rank * 8 + f


func screen_point(sq: int) -> Vector2:
	return get_global_transform_with_canvas() * square_rect(sq).get_center()


func _draw() -> void:
	var r := board_rect()
	# Schatten und Rahmen, dann die echte Brett-Textur.
	draw_rect(Rect2(r.position + Vector2(0, r.size.x * 0.012), r.size), Color(0, 0, 0, 0.35))
	var frame := r.grow(r.size.x * 0.035)
	draw_rect(frame, Color("4a2c1a"))
	draw_rect(frame.grow(-r.size.x * 0.006), Color("6b4128"))
	if _top != null:
		draw_texture_rect(_top, r, false)
	else:
		for sq in 64:
			draw_rect(square_rect(sq), Color("eed6ac") if (sq & 7) % 2 != (sq >> 3) % 2 else Color("70482c"))
	var c := cell()
	var pulse := 0.65 + 0.3 * sin(_time * 4.2)
	for sq: int in glow:
		var rect := square_rect(sq)
		match str(glow[sq]):
			"move":
				draw_circle(rect.get_center(), c * 0.16, Color(0.25, 0.81, 0.47, 0.9))
				draw_arc(rect.get_center(), c * 0.16, 0, TAU, 24, Color(0.08, 0.3, 0.15, 0.7), 2.0, true)
			"capture":
				draw_arc(rect.get_center(), c * 0.44, 0, TAU, 40, Color(1.0, 0.55, 0.25, 0.95), c * 0.07, true)
			"hint":
				draw_rect(rect, Color(0.45, 0.95, 0.6, 0.5 * pulse))
			"last":
				draw_rect(rect, Color(1.0, 0.88, 0.45, 0.28))
			"can":
				draw_rect(rect, Color(1.0, 0.82, 0.3, 0.22))
			"danger":
				draw_rect(rect, Color(1.0, 0.3, 0.3, 0.55 * pulse))
			"show":
				draw_rect(rect, Color(0.45, 0.82, 1.0, 0.5 * pulse))
			_:
				draw_rect(rect, Color(1.0, 0.82, 0.3, 0.5))
	for sq: int in walls:
		var rect := square_rect(sq).grow(-c * 0.06)
		draw_rect(rect, Color("b8a48c"))
		draw_rect(rect, Color("7d6a55"), false, maxf(2.0, c * 0.04))
	for sq: int in stars:
		_draw_star(square_rect(sq).get_center(), c * 0.32)
	for sq in 64:
		if board[sq] == 0 or sq == drag_square:
			continue
		_draw_piece(board[sq], square_rect(sq))
	if drag_square >= 0 and board[drag_square] != 0:
		var local := get_global_transform_with_canvas().affine_inverse() * drag_point
		_draw_piece(board[drag_square], Rect2(local - Vector2(c, c) * 0.6, Vector2(c, c) * 1.2))
	if coords:
		var font_size := int(maxf(10.0, c * 0.2))
		for i in 8:
			var col := square_rect(i)
			draw_string(_font, Vector2(col.get_center().x - font_size * 0.3, r.end.y + font_size * 0.15 + r.size.x * 0.012),
				"abcdefgh"[i], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("f6dfad"))
			var row := square_rect(i * 8)
			draw_string(_font, Vector2(r.position.x - r.size.x * 0.032, row.get_center().y + font_size * 0.35),
				str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("f6dfad"))


func _draw_piece(piece: int, rect: Rect2) -> void:
	var tex := icon(piece)
	if tex != null:
		draw_texture_rect(tex, rect.grow(-rect.size.x * 0.02), false)
	else:
		draw_circle(rect.get_center(), rect.size.x * 0.35, Color.WHITE if piece >> 3 == 0 else Color.BLACK)


func _draw_star(centre: Vector2, radius: float) -> void:
	var points := PackedVector2Array()
	for i in 10:
		var a := TAU * i / 10.0 - PI * 0.5
		var rr := radius if i % 2 == 0 else radius * 0.45
		points.append(centre + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(points, Color("ffd23f"))
	points.append(points[0])
	draw_polyline(points, Color("b8740f"), maxf(1.5, radius * 0.08), true)
