extends Control
## A live map of the actual course, including all six racers.

var race: Node3D
var path: PackedVector2Array = []
var bounds := Rect2(-75, -65, 150, 125)


func configure(game: Node3D) -> void:
	race = game
	for i in range(181):
		var p: Vector3 = race._track_position(float(i) * race.track_length / 180, 0)
		path.append(Vector2(p.x, p.z))


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
		var point: Vector3 = race._track_position(race.opponent_distances[i], 0)
		draw_circle(_map(Vector2(point.x, point.z)), 4, race.opponents[i].vehicle_color)
	var point: Vector3 = race.player.position
	draw_circle(_map(Vector2(point.x, point.z)), 7, Color("263549"))
	draw_circle(_map(Vector2(point.x, point.z)), 5, Color("fff2bb"))
