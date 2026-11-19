extends RefCounted
## Erste Einführung für LUMO PUZZLE-ATELIER – sobald ein Puzzle offen ist.
## Schritte: ein Teil auf seinen Platz ziehen, „Ein Tipp“ antippen, das leuchtende
## Teil hinlegen.

const GUIDE = preload("res://scripts/systems/first_run_guide.gd")
const ID := "puzzle"


static func attach(game: Node) -> CanvasLayer:
	var steps: Array = [
		{
			"id": "drag",
			"text": "Halte ein Teil mit dem Finger fest und zieh es auf seinen Platz.",
			"target": func() -> Variant: return _drag_target(game),
			"done": _placed.bind(game),
		},
		{
			"id": "hint",
			"text": "Weißt du nicht weiter? Tippe auf „Ein Tipp“.",
			"target": func() -> Variant: return _tool(game, "Ein Tipp"),
			"done":
			func(guide) -> bool: return guide.since_step("hints", float(game.model.hints)) >= 1.0,
		},
		{
			"id": "hint_piece",
			"text": "Das gehobene Teil passt auf den hellen Platz. Leg es hin!",
			"target": func() -> Variant: return _drag_target(game),
			"done": _placed.bind(game),
		},
	]
	var options := {
		"outro": "Super! Jetzt puzzelst du dein Bild fertig.",
		"replay_position": _replay_spot.bind(game),
		"bubble_position": func(_size: Vector2) -> float: return _bubble_top(game),
	}
	return GUIDE.attach(game, ID, steps, _active.bind(game), options)


static func _active(game: Node) -> bool:
	return not bool(game.paused) and not game.menu.visible and not game.model.complete()


static func _placed(guide, game: Node) -> bool:
	return guide.since_step("placed", float(game.model.placed())) >= 1.0


## Beim Ziehen der Zielplatz des Teils, sonst das ausgewählte bzw. erste freie Teil.
static func _drag_target(game: Node) -> Variant:
	var camera: Camera3D = game.camera
	var id: int = int(game.dragging) if int(game.dragging) >= 0 else int(game.selected_piece)
	if id >= 0 and int(game.dragging) >= 0:
		var slot: Vector2 = game.model.target(id)
		return _screen_rect(camera, Vector3(slot.x, 0.14, slot.y), game.model.cell_size())
	if id < 0:
		for index in range(game.nodes.size()):
			if not game.model.pieces[index].locked and game.nodes[index].visible:
				id = index
				break
	if id < 0:
		return null
	var at: Vector3 = game.nodes[id].global_position
	return _screen_rect(camera, at, game.model.cell_size())


static func _screen_rect(camera: Camera3D, centre: Vector3, cell: Vector2) -> Rect2:
	var half := Vector3(cell.x * 0.5, 0.0, cell.y * 0.5)
	var a: Vector2 = camera.unproject_position(centre - half)
	var b: Vector2 = camera.unproject_position(centre + half)
	var rect := Rect2(a, Vector2.ZERO).expand(b)
	rect = rect.expand(camera.unproject_position(centre + Vector3(half.x, 0, -half.z)))
	return rect.expand(camera.unproject_position(centre + Vector3(-half.x, 0, half.z)))


static func _tool(game: Node, caption: String) -> Variant:
	for button in game.tool_scroll.find_children("*", "Button", true, false):
		if button.text == caption and button.is_visible_in_tree():
			return button
	return null


## Oben unter Kopfzeile und Statuszeile; das Brett bleibt frei.
static func _bubble_top(game: Node) -> float:
	return game.status.get_global_rect().end.y + 10.0


static func _replay_spot(size: Vector2, game: Node) -> Vector2:
	var view: Rect2 = game.get_viewport().get_visible_rect()
	return Vector2(view.end.x - size.x - 16.0, _bubble_top(game))
