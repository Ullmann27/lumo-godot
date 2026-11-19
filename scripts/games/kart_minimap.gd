extends Control
## A live map of the actual course, including all six racers.

var race: Node3D
var path: PackedVector2Array = []
var bounds := Rect2(-75, -65, 150, 125)
## LUMO passages on the map: position, kind ("bridge" / "swing" / ...) and colour.
var passage_marks: Array[Dictionary] = []


func configure(game: Node3D) -> void:
	race = game
	path.clear()
	if race.mode == "arena" or not is_instance_valid(race.world):
		return
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for i in range(181):
		var p: Vector3 = race._track_position(float(i) * race.track_length / 180, 0)
		path.append(Vector2(p.x, p.z))
		minimum = minimum.min(Vector2(p.x, p.z))
		maximum = maximum.max(Vector2(p.x, p.z))
	bounds = Rect2(minimum - Vector2.ONE * 5, maximum - minimum + Vector2.ONE * 10)
	passage_marks.clear()
	var passages: Script = load("res://scripts/games/kart_passages.gd")
	for entry in passages.of(race.world):
		var kind: String = str(entry.kind)
		if kind not in ["bridge", "swing"]:
			continue
		var at_d: float = (
			(float(entry.deck_start) + float(entry.deck_end)) * 0.5 if kind == "bridge" else float(entry.plane)
		)
		var p3: Vector3 = race._track_position(at_d, 0)
		var ahead: Vector3 = race._forward(at_d)
		passage_marks.append({
			"id": str(entry.id), "kind": kind, "at": Vector2(p3.x, p3.z),
			"along": Vector2(ahead.x, ahead.z).normalized(),
			"colour": Color("8fe3ff") if kind == "bridge" else Color("ffab2e"),
		})


func _map(point: Vector2) -> Vector2:
	return Vector2(12, 12) + (point - bounds.position) / bounds.size * (size - Vector2(24, 24))


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if not is_instance_valid(race) or path.is_empty():
		return
	var mapped := PackedVector2Array()
	for point in path:
		mapped.append(_map(point))
	draw_polyline(mapped, Color("24465b"), 7, true)
	draw_polyline(mapped, Color("d6eff0"), 3, true)
	for i in range(race.opponents.size()):
		var point: Vector3 = race.opponents[i].position
		draw_circle(_map(Vector2(point.x, point.z)), 4, race.opponents[i].vehicle_color)
	var point: Vector3 = race.player.position
	draw_circle(_map(Vector2(point.x, point.z)), 7, Color("263549"))
	draw_circle(_map(Vector2(point.x, point.z)), 5, Color("91f4ff"))
