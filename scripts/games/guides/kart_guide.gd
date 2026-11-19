extends RefCounted
## Erste Einführung für LUMO KART – erscheint erst im Rennen (nach der Startampel),
## nie im Menü. Schritte: lenken, GAS halten, driften, Itembox holen, Item einsetzen.

const GUIDE = preload("res://scripts/systems/first_run_guide.gd")
const ID := "kart"


static func attach(game: Node) -> CanvasLayer:
	var steps: Array = [
		{
			"id": "steer",
			"text": "Lenke mit dem linken Daumen: zieh den Stick zur Seite.",
			"target": func() -> Variant: return game.joystick,
			"done": func(guide) -> bool: return guide.held(absf(_axis(game)) > 0.35, 0.35),
		},
		{
			"id": "gas",
			"text": "Halte GAS mit dem rechten Daumen gedrückt.",
			"target": func() -> Variant: return game.gas_button,
			"done": func(guide) -> bool: return guide.held(bool(game.gas_held), 0.8),
			"skip": func() -> bool: return bool(game.auto_gas),
		},
		{
			"id": "drift",
			"text": "Halte DRIFT und lenke dabei – so rutschst du durch die Kurve.",
			"target": func() -> Variant: return game.drift_button,
			"done": _drift_done.bind(game),
		},
		{
			"id": "itembox",
			"text": "Fahr durch eine leuchtende Itembox.",
			"target": func() -> Variant: return _next_box_rect(game),
			"done": _box_done.bind(game),
			"skip": func() -> bool: return game.item_boxes.is_empty() and str(game.item).is_empty(),
		},
		{
			"id": "item",
			"text": "Tippe jetzt auf dein Item!",
			"target": func() -> Variant: return game.item_button,
			"done": func(guide) -> bool: return guide.seen("item_tap"),
			"skip": func() -> bool: return game.item_boxes.is_empty() and str(game.item).is_empty(),
		},
	]
	var active := func() -> bool:
		return (
			bool(game.racing)
			and not bool(game.paused)
			and not bool(game.finished)
			and not bool(game.menu_active)
		)
	var guide = GUIDE.attach(
		game,
		ID,
		steps,
		active,
		{
			"outro": "Super gefahren! Jetzt gehört die Strecke dir.",
			"replay_position": func(size: Vector2) -> Vector2: return _replay_spot(game, size),
		}
	)
	if guide == null:
		return null
	game.item_button.pressed.connect(func() -> void: guide.note("item_tap"))
	game.drift_button.button_up.connect(
		func() -> void:
			if float(game.drift_charge) > 0.0:
				guide.note("drift_boost")
	)
	return guide


static func _axis(game: Node) -> float:
	var axis: float = float(game.steering)
	if absf(axis) < 0.01:
		axis = Input.get_axis("ui_left", "ui_right")
	return axis


static func _drift_done(guide, game: Node) -> bool:
	var drifting: bool = bool(game.drifting) and absf(_axis(game)) > 0.2
	return guide.held(drifting, 0.6) or guide.seen("drift_boost")


static func _box_done(_guide, game: Node) -> bool:
	return not str(game.item).is_empty() and float(game.item_roulette_time) <= 0.0


## Bildschirmrechteck der nächsten sichtbaren Itembox vor dem Kart (sonst der Itemknopf).
static func _next_box_rect(game: Node) -> Variant:
	var camera: Camera3D = game.camera
	if not is_instance_valid(camera) or not is_instance_valid(game.player):
		return game.item_button
	var best: Node3D = null
	var best_distance := 70.0
	for box: Node3D in game.item_boxes:
		if (
			not is_instance_valid(box)
			or not box.is_visible_in_tree()
			or camera.is_position_behind(box.global_position)
		):
			continue
		var distance: float = box.global_position.distance_to(game.player.global_position)
		if distance < best_distance:
			best_distance = distance
			best = box
	if best == null:
		return game.item_button
	var view: Rect2 = game.get_viewport().get_visible_rect()
	var centre: Vector2 = camera.unproject_position(best.global_position + Vector3.UP * 0.6)
	var half: float = clampf(900.0 / maxf(best_distance, 6.0), 26.0, 120.0)
	var rect := Rect2(centre - Vector2.ONE * half, Vector2.ONE * half * 2.0)
	return rect if view.encloses(rect) else game.item_button


## Unter dem Menü-Knopf oben links, damit Lenkstick und Pedale frei bleiben.
static func _replay_spot(game: Node, _size: Vector2) -> Vector2:
	var top: Control = game.top_menu_button
	if is_instance_valid(top) and top.is_visible_in_tree():
		var rect: Rect2 = top.get_global_rect()
		return Vector2(rect.position.x, rect.end.y + 14.0)
	return Vector2(24.0, 120.0)
