extends Control
## Kindgerechte Draufsicht: dasselbe Holzbrett (Textur der Blender-Fläche) von
## oben, darauf die gerenderten Figurensymbole aufrecht, gut unterscheidbar.
## Leuchten, Sterne, Mauern und Feldnamen wie im 3D-Tisch.
##
## Reine Darstellung – Eingaben verarbeitet der Tisch über `square_at()`.

signal move_animated

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
var reduced_motion := false
var time_scale := 1.0
var _anim: Tween
var _moving := false
var _suspended := false
var _move_from := -1
var _move_to := -1
var _move_piece := 0
var _progress := 0.0
var _victim_sq := -1
var _rook_from := -1
var _rook_to := -1
var _rook_piece := 0
var _rook_progress := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.resize(64)
	_top = load("res://assets/chess/textures/board_top.webp")
	_font = ThemeDB.fallback_font
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func _process(delta: float) -> void:
	if not _suspended:
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
	cancel_animation()
	board = value.duplicate()
	queue_redraw()


## Dieselbe Zugfolge wie das Holzbrett: Ausgangsfeld, Zwischenpositionen, Ziel.
## Das Endbrett wird erst nach der Landung übernommen (auch bei Umwandlung).
func animate_move(m: int, board_after: PackedInt32Array, seconds: float = 0.65) -> void:
	cancel_animation()
	_move_from = m & 63
	_move_to = (m >> 6) & 63
	var flags := m >> 15
	_move_piece = board[_move_from]
	if reduced_motion or _move_piece == 0:
		show_board(board_after)
		move_animated.emit.call_deferred()
		return
	_moving = true
	_progress = 0.0
	_rook_progress = 0.0
	_victim_sq = _move_to
	if flags & 4:
		_victim_sq = _move_to - 8 if (_move_to >> 3) == 5 else _move_to + 8
	board[_move_from] = 0
	_rook_from = -1
	if flags & 8:
		_rook_from = int({6: 7, 2: 0, 62: 63, 58: 56}.get(_move_to, -1))
		_rook_to = int({6: 5, 2: 3, 62: 61, 58: 59}.get(_move_to, -1))
		_rook_piece = board[_rook_from]
		board[_rook_from] = 0
	var duration := seconds / maxf(0.01, time_scale)
	_anim = create_tween()
	_anim.tween_method(
		func(t: float) -> void:
			_progress = t
			queue_redraw(),
		0.0, 1.0, duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if _rook_from >= 0:
		_anim.tween_method(
			func(t: float) -> void:
				_rook_progress = t
				queue_redraw(),
			0.0, 1.0, duration * 0.65
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var final_board := board_after.duplicate()
	_anim.tween_callback(
		func() -> void:
			show_board(final_board)
			move_animated.emit()
	)
	if _suspended:
		_anim.pause()
	queue_redraw()


func is_animating() -> bool:
	return _moving


func set_suspended(value: bool) -> void:
	_suspended = value
	if _anim != null and _anim.is_valid():
		if value:
			_anim.pause()
		else:
			_anim.play()


func cancel_animation() -> void:
	if _anim != null and _anim.is_valid():
		_anim.kill()
	_anim = null
	_moving = false
	drag_square = -1


## In Brettkoordinaten, damit auch ein Ansichts-/Formatwechsel weich bleibt.
func moving_piece_rect() -> Rect2:
	var start := square_rect(_move_from)
	var finish := square_rect(_move_to)
	return Rect2(start.position.lerp(finish.position, _progress), start.size)


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
	draw_rect(frame, Color("192e35"))
	draw_rect(frame.grow(-r.size.x * 0.006), Color("294749"))
	if _top != null:
		draw_texture_rect(_top, r, false)
	else:
		for sq in 64:
			draw_rect(
				square_rect(sq),
				Color("cbdcc9") if (sq & 7) % 2 != (sq >> 3) % 2 else Color("62918c")
			)
	var c := cell()
	var pulse := 0.8 if reduced_motion else 0.65 + 0.3 * sin(_time * 4.2)
	for sq: int in glow:
		var rect := square_rect(sq)
		match str(glow[sq]):
			"move":
				draw_circle(rect.get_center(), c * 0.16, Color(0.25, 0.81, 0.47, 0.9))
				draw_arc(
					rect.get_center(), c * 0.16, 0, TAU, 24, Color(0.08, 0.3, 0.15, 0.7), 2.0, true
				)
			"capture":
				draw_arc(
					rect.get_center(),
					c * 0.44,
					0,
					TAU,
					40,
					Color(1.0, 0.55, 0.25, 0.95),
					c * 0.07,
					true
				)
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
		if _moving and sq == _victim_sq:
			var fraction := 1.0 - smoothstep(0.72, 1.0, _progress)
			var rect := square_rect(sq)
			_draw_piece(board[sq], rect.grow(-c * 0.48 * (1.0 - fraction)))
		else:
			_draw_piece(board[sq], square_rect(sq))
	if _moving:
		_draw_piece(_move_piece, moving_piece_rect())
		if _rook_from >= 0:
			var start := square_rect(_rook_from)
			var finish := square_rect(_rook_to)
			_draw_piece(_rook_piece, Rect2(start.position.lerp(finish.position, _rook_progress), start.size))
	if drag_square >= 0 and board[drag_square] != 0:
		var local := get_global_transform_with_canvas().affine_inverse() * drag_point
		_draw_piece(board[drag_square], Rect2(local - Vector2(c, c) * 0.6, Vector2(c, c) * 1.2))
	if coords:
		var font_size := int(maxf(10.0, c * 0.2))
		for i in 8:
			var col := square_rect(i)
			draw_string(
				_font,
				Vector2(
					col.get_center().x - font_size * 0.3,
					r.end.y + font_size * 0.15 + r.size.x * 0.012
				),
				"abcdefgh"[i],
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				font_size,
				Color("f6dfad")
			)
			var row := square_rect(i * 8)
			draw_string(
				_font,
				Vector2(r.position.x - r.size.x * 0.032, row.get_center().y + font_size * 0.35),
				str(i + 1),
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				font_size,
				Color("f6dfad")
			)


func _draw_piece(piece: int, rect: Rect2) -> void:
	var tex := icon(piece)
	if tex != null:
		draw_texture_rect(tex, rect.grow(-rect.size.x * 0.02), false)
	else:
		draw_circle(
			rect.get_center(), rect.size.x * 0.35, Color.WHITE if piece >> 3 == 0 else Color.BLACK
		)


func _draw_star(centre: Vector2, radius: float) -> void:
	var points := PackedVector2Array()
	for i in 10:
		var a := TAU * i / 10.0 - PI * 0.5
		var rr := radius if i % 2 == 0 else radius * 0.45
		points.append(centre + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(points, Color("ffd23f"))
	points.append(points[0])
	draw_polyline(points, Color("b8740f"), maxf(1.5, radius * 0.08), true)
