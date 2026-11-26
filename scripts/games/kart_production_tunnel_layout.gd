extends RefCounted
## Select an actual uninterrupted road section before placing any tunnel art.
## Distances use the existing baked race curve; no checkpoints or road points move.

const THEMES: Array[String] = [
	"zauberwald", "bergwelt", "holo_city", "crystal_canyon", "jungle_temple",
	"candy_cloud", "volcano_night", "winter_sprint", "galaxy_ringway",
	"desert_drift", "learning_lab",
]
const PREFERRED: Dictionary = {
	"zauberwald": 0.51, "bergwelt": 0.555, "holo_city": 0.60,
	"crystal_canyon": 0.24, "jungle_temple": 0.56, "candy_cloud": 0.56,
	"volcano_night": 0.60, "winter_sprint": 0.55, "galaxy_ringway": 0.52,
	"desert_drift": 0.57, "learning_lab": 0.53,
}
const MAX_CURVATURE: float = 0.045
const MAX_GRADE: float = 0.25
const OTHER_ROAD_CLEARANCE: float = 27.0
const PASSAGES = preload("res://scripts/games/kart_passages.gd")
const THRILLS = preload("res://scripts/games/kart_track_thrills.gd")


static func supports(track_id: String) -> bool:
	return track_id in THEMES


static func plan(world) -> Dictionary:
	if not supports(str(world.track_id)):
		return {}
	var blocked: Array[Vector2] = _blocked(world)
	var preferred: float = float(PREFERRED[world.track_id]) * float(world.length)
	for span in [44.0, 32.0]:
		var best: Dictionary = {}
		var best_score: float = INF
		var count: int = ceili((float(world.length) - 70.0 - span) / 4.0)
		for index in range(maxi(0, count)):
			var start: float = snappedf(35.0 + float(index) * 4.0, 0.25)
			var finish: float = start + span
			if _overlaps(start, finish, blocked):
				continue
			# Keep both portals on an actual island. The former cave island is
			# occupied by the existing landing and slalom; another island may win.
			if world.track_id == "bergwelt" and not _on_sky_island(world, start, finish):
				continue
			var measures: Dictionary = _measure(world, start, finish)
			if not bool(measures.safe):
				continue
			var score: float = absf((start + finish) * 0.5 - preferred) + float(measures.curvature) * 180.0
			if score < best_score:
				best_score = score
				best = {"start": start, "end": finish, "length": span,
					"max_curvature": measures.curvature, "max_grade": measures.grade,
					"nearest_other_road": measures.nearest_other,
					"modules": _modules(start, int(round((span - 8.0) / 12.0))),
					"blocked_ranges": blocked}
		if not best.is_empty():
			return best
	push_error("No safe production tunnel section on " + str(world.track_id))
	return {}


static func contains(layout: Dictionary, distance: float, margin: float = 0.0) -> bool:
	return not layout.is_empty() and distance >= float(layout.start) - margin and distance <= float(layout.end) + margin


static func _modules(start: float, straight_count: int) -> Array[Dictionary]:
	var modules: Array[Dictionary] = [{"kind": "portal_entry", "start": start, "length": 4.0}]
	var cursor: float = start + 4.0
	for index in range(straight_count):
		modules.append({"kind": "straight_12m", "start": cursor, "length": 12.0})
		cursor += 12.0
	modules.append({"kind": "portal_exit", "start": cursor, "length": 4.0})
	return modules


static func _blocked(world) -> Array[Vector2]:
	var result: Array[Vector2] = [Vector2(0, 35), Vector2(float(world.length) - 35.0, float(world.length))]
	var adventure: Dictionary = world.adventure_tunnel
	if not adventure.is_empty():
		result.append(Vector2(float(adventure.start) - 20.0, float(adventure.end) + 20.0))
	result.append_array(PASSAGES.blocked_ranges(world))
	for section in THRILLS.of(world):
		# The floor of a road-following collision shell intersects an upright
		# kart capsule where the road twists into a strongly banked curve.
		if section.kind == "bank":
			result.append(Vector2(float(section.start) - 5.0, float(section.end) + 5.0))
	if not world.jump.is_empty():
		result.append(Vector2(float(world.jump.ramp_start) - 16.0, float(world.jump.gap_end) + 25.0))
	if not world.loop_layout.is_empty():
		result.append(Vector2(float(world.loop_layout.start) - 16.0, float(world.loop_layout.start) + 90.0))
	for kicker in world.action.get("kickers", []):
		result.append(Vector2(float(kicker.start) - 14.0, float(kicker.take_off) + 40.0))
	for pad in world.action.get("pads", []):
		result.append(Vector2(float(pad.start) - 10.0, float(pad.end) + 10.0))
	for key in ["dives", "edges"]:
		for zone in world.action.get(key, []):
			result.append(Vector2(float(zone.start) - 10.0, float(zone.end) + 10.0))
	for gate in world.action.get("gates", []):
		result.append(Vector2(float(gate.distance) - 7.0, float(gate.distance) + 7.0))
	if world.track_id == "bergwelt":
		result.append(Vector2(float(world.length) * 0.80 - 25.0, float(world.length) * 0.80 + 25.0))
	return result


static func _overlaps(start: float, finish: float, blocked: Array[Vector2]) -> bool:
	for zone in blocked:
		if start < zone.y and finish > zone.x:
			return true
	return false


static func _on_sky_island(world, start: float, finish: float) -> bool:
	# _road_island extends 10 m beyond each nominal interval. Keep 2 m
	# of its existing geological apron beyond both portal ends.
	for island in world.SKY_ISLANDS.ISLANDS:
		if start >= float(island.x) * world.length - 8.0 and finish <= float(island.y) * world.length + 8.0:
			return true
	return false


static func _measure(world, start: float, finish: float) -> Dictionary:
	var max_curvature: float = 0.0
	var max_grade: float = 0.0
	var nearest_other: float = INF
	var steps: int = ceili((finish - start) / 3.0)
	for step in range(steps + 1):
		var distance: float = lerpf(start, finish, float(step) / steps)
		var ahead: Vector3 = world.forward(distance)
		var next: Vector3 = world.forward(distance + 1.0)
		max_curvature = maxf(max_curvature, ahead.angle_to(next))
		max_grade = maxf(max_grade, absf(ahead.y))
		if max_curvature > MAX_CURVATURE or max_grade > MAX_GRADE:
			return {"safe": false}
		var point: Vector3 = world.position_at(distance)
		for index in world._road_samples.size():
			var other_distance: float = float(world._road_distances[index])
			var along: float = absf(other_distance - distance)
			along = minf(along, float(world.length) - along)
			if along < 45.0:
				continue
			var other: Vector3 = world._road_samples[index]
			if absf(other.y - point.y) > 15.0:
				continue
			var horizontal: float = Vector2(other.x - point.x, other.z - point.z).length()
			nearest_other = minf(nearest_other, horizontal)
			if horizontal < OTHER_ROAD_CLEARANCE:
				return {"safe": false}
	return {"safe": true, "curvature": max_curvature, "grade": max_grade, "nearest_other": nearest_other}
