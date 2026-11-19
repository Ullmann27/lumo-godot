extends RefCounted
## Erste Einführung für VIER GEWINNT – nur wenn das Kind gegen Lumo am Zug ist.
## Schritte: Stein einwerfen, Stein neben den eigenen legen, Stein auf Lumos Stein legen.
## Brett: board[row * 7 + column], Reihe 5 unten; 1 = Kind, 2 = Lumo.

const GUIDE = preload("res://scripts/systems/first_run_guide.gd")
const ID := "connect_four"
const ROWS := 6
const COLUMNS := 7


static func attach(game: Node) -> CanvasLayer:
	var steps: Array = [
		{
			"id": "drop",
			"text": "Tippe auf einen Pfeil – dein Stein fällt in diese Spalte.",
			"target": func() -> Variant: return _column_button(game, 3, 0),
			"done": func(guide) -> bool: return guide.since_step("own", _count(game, 1)) >= 1.0,
		},
		{
			"id": "neighbour",
			"text": "Vier in einer Reihe gewinnt! Leg deinen Stein neben deinen.",
			"target": func() -> Variant: return _column_button(game, _last_column(game), 1),
			"done": func(guide) -> bool: return guide.since_step("links", _links(game)) >= 1.0,
		},
		{
			"id": "block",
			"text": "Lumo baut auch eine Reihe. Leg einen Stein auf Lumos Stein!",
			"target": func() -> Variant: return _lumo_column_button(game),
			"done": func(guide) -> bool: return guide.since_step("on_lumo", _on_lumo(game)) >= 1.0,
		},
	]
	var options := {
		"outro": "Prima! Jetzt spielst du allein gegen Lumo.",
		"replay_position": _replay_spot.bind(game),
	}
	return GUIDE.attach(game, ID, steps, _active.bind(game), options)


static func _active(game: Node) -> bool:
	var state: Dictionary = game._state
	return (
		not state.is_empty()
		and str(state.get("phase", "")) == "playing"
		and int(state.get("turn", 0)) == 1
		and not bool(state.get("paused", true))
		and not bool(state.get("twoPlayers", false))
		and not bool(game._dropping)
		and not game.overlay.visible
	)


static func _piece(game: Node, row: int, column: int) -> int:
	var board: Array = game._state.get("board", [])
	if row < 0 or row >= ROWS or column < 0 or column >= COLUMNS or board.size() != ROWS * COLUMNS:
		return -1
	return int(board[row * COLUMNS + column])


static func _count(game: Node, piece: int) -> float:
	var count := 0
	for cell in game._state.get("board", []):
		if int(cell) == piece:
			count += 1
	return float(count)


## Anzahl Nachbarpaare eigener Steine (waagrecht, senkrecht, schräg).
static func _links(game: Node) -> float:
	var count := 0
	for row in range(ROWS):
		for column in range(COLUMNS):
			if _piece(game, row, column) != 1:
				continue
			for step: Vector2i in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, -1)]:
				if _piece(game, row + step.x, column + step.y) == 1:
					count += 1
	return float(count)


## Eigene Steine, die direkt auf einem Stein von Lumo liegen.
static func _on_lumo(game: Node) -> float:
	var count := 0
	for row in range(ROWS - 1):
		for column in range(COLUMNS):
			if _piece(game, row, column) == 1 and _piece(game, row + 1, column) == 2:
				count += 1
	return float(count)


static func _last_column(game: Node) -> int:
	var history: Array = game._state.get("columns", [])
	for index in range(history.size() - 1, -1, -1):
		if index % 2 == 0:
			return int(history[index])
	return 3


## Spaltenknopf column + offset (abwechselnd links/rechts), der gerade einwerfen kann.
static func _column_button(game: Node, column: int, offset: int) -> Variant:
	var valid: Array[int] = []
	for value in game._state.get("validColumns", []):
		valid.append(int(value))
	for distance in range(offset, COLUMNS):
		for candidate in [column + distance, column - distance]:
			if candidate < 0 or candidate >= game.column_buttons.size() or not valid.has(candidate):
				continue
			var button: Control = game.column_buttons[candidate]
			if button.is_visible_in_tree():
				return button
	return null


static func _lumo_column_button(game: Node) -> Variant:
	for column in range(COLUMNS):
		for row in range(ROWS):
			var piece := _piece(game, row, column)
			if piece == 0:
				continue
			if piece == 2:
				return _column_button(game, column, 0)
			break
	return null


## Unter dem Pause-Knopf.
static func _replay_spot(size: Vector2, game: Node) -> Vector2:
	var pause: Rect2 = game.pause_button.get_global_rect()
	return Vector2(pause.end.x - size.x, pause.end.y + 12.0)
