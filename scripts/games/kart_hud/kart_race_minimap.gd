extends "res://scripts/games/kart_minimap.gd"
## Lumo Kart minimap with a clean road, a start/finish mark, rivals as clear outlined
## dots in their kart colour and the player as a small Lumo face (fox ears, muzzle, eyes).
## Same data as the base map: the real course and the real racer positions.

const ROAD_EDGE := Color("0b1d38")
const ROAD := Color("dcefff")
const LUMO_FUR := Color("ff8a2a")
const LUMO_LIGHT := Color("fff1de")
const INK := Color("071428")


func _draw() -> void:
	if not is_instance_valid(race) or path.is_empty():
		return
	var mapped := PackedVector2Array()
	for point in path:
		mapped.append(_map(point))
	var u: float = clampf(minf(size.x, size.y) / 128.0, 0.6, 2.6)
	draw_polyline(mapped, ROAD_EDGE, 10.0 * u, true)
	draw_polyline(mapped, Color("6fe6ff", 0.55), 6.5 * u, true)
	draw_polyline(mapped, ROAD, 4.0 * u, true)
	# Start/finish: a short checkered bar across the road at the first path point.
	if mapped.size() > 2:
		var along: Vector2 = (mapped[1] - mapped[0]).normalized()
		var across := Vector2(-along.y, along.x)
		for i in range(4):
			var t: float = (float(i) - 1.5) * 2.4 * u
			var colour: Color = Color.WHITE if i % 2 == 0 else INK
			draw_line(mapped[0] + across * (t - 1.2 * u), mapped[0] + across * (t + 1.2 * u), colour, 3.2 * u)
	# LUMO passages: a short cross bar for a narrow bridge, a dot for Kiri's vine.
	for mark in passage_marks:
		var centre: Vector2 = _map(mark.at)
		var along: Vector2 = mark.along
		var across := Vector2(-along.y, along.x)
		if str(mark.kind) == "bridge":
			draw_line(centre - across * 5.0 * u, centre + across * 5.0 * u, INK, 4.6 * u)
			draw_line(centre - across * 4.2 * u, centre + across * 4.2 * u, mark.colour, 2.6 * u)
		else:
			draw_circle(centre, 4.4 * u, INK)
			draw_circle(centre, 3.2 * u, mark.colour)
	for i in range(race.opponents.size()):
		var rival: Node3D = race.opponents[i]
		var at: Vector2 = _map(Vector2(rival.position.x, rival.position.z))
		var colour: Color = rival.get("vehicle_color") if rival.get("vehicle_color") is Color else Color("ff6a5a")
		draw_circle(at, 5.6 * u, INK)
		draw_circle(at, 4.2 * u, colour.lightened(0.15))
	var me: Vector2 = _map(Vector2(race.player.position.x, race.player.position.z))
	_draw_lumo(me, 8.5 * u)


## A tiny Lumo face: orange head with pointed ears, light muzzle, two dark eyes.
func _draw_lumo(at: Vector2, r: float) -> void:
	for side in [-1.0, 1.0]:
		var ear := PackedVector2Array([
			at + Vector2(side * r * 0.95, -r * 1.35), at + Vector2(side * r * 0.25, -r * 0.62), at + Vector2(side * r * 1.02, -r * 0.18)
		])
		draw_colored_polygon(ear, INK)
		var inner := PackedVector2Array([
			at + Vector2(side * r * 0.86, -r * 1.12), at + Vector2(side * r * 0.42, -r * 0.62), at + Vector2(side * r * 0.86, -r * 0.36)
		])
		draw_colored_polygon(inner, LUMO_FUR)
	draw_circle(at, r * 1.18, INK)
	draw_circle(at, r, LUMO_FUR)
	draw_circle(at + Vector2(0, r * 0.38), r * 0.55, LUMO_LIGHT)
	for side in [-1.0, 1.0]:
		draw_circle(at + Vector2(side * r * 0.38, -r * 0.12), r * 0.17, INK)
	draw_circle(at + Vector2(0, r * 0.2), r * 0.13, INK)
