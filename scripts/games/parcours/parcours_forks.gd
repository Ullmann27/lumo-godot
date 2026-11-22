extends RefCounted
## Eine befahrbare Seitenstrecke mit offenen Abzweigen und Geländern auf der freien Strecke.

const PEN = preload("res://scripts/games/parcours/parcours_pen.gd")


static func connect_route(
	course, entry: int, exit_index: int, route_name: String, style: String,
	offset: float, rise: float, width: float, cap: float, distance_from: float
) -> void:
	var start: Vector3 = course.route[entry].pos - Vector3.UP * 0.3
	var end: Vector3 = course.route[exit_index].pos - Vector3.UP * 0.3
	var chord := end - start
	var lateral := Vector3(-chord.z, 0, chord.x).normalized()
	var stations: Array[Vector3] = []
	for i in range(9):
		var u := float(i) / 8.0
		var bend := sin(PI * u)
		var point := start.lerp(end, u) + lateral * offset * bend * bend
		point.y += 0.055 + rise * bend * bend
		stations.append(point)
	var original_size: int = course.route.size()
	var middle: Array[Dictionary] = []
	var distance_step := (float(course.slabs.back().route_from) - distance_from) / (stations.size() - 1)
	for i in range(stations.size() - 1):
		var travel := stations[i + 1] - stations[i]
		var heading := atan2(-travel.x, -travel.z)
		var pen = PEN.new(course, stations[i], heading, width)
		pen.style = style
		var fenced := i >= 2 and i <= 5
		pen.straight(
			Vector2(travel.x, travel.z).length(), travel.y, fenced, fenced,
			{
				"cap": cap, "race_fork": true, "no_supports": i % 2 != 0,
				"route_from": distance_from + distance_step * i, "race_distance_span": distance_step
			}
		)
		if i > 0:
			middle.append({"pos": stations[i] + Vector3.UP * 0.3, "cap": cap})
	# Der Bau-Stift trägt jede Platte in die Hauptroute ein. Die Seitenstrecke
	# bekommt eigene Wegpunkte, damit die ursprüngliche Fahrlinie erhalten bleibt.
	course.route.resize(original_size)
	course.race_branch = {
		"entry": entry, "exit": exit_index, "points": middle, "name": route_name,
		"sign_pos": stations[2] + lateral * signf(offset) * (width * 0.5 + 1.4) + Vector3.UP * 2.4,
		"heading": atan2(-chord.x, -chord.z)
	}
