extends RefCounted
## Register der Signatur-Strecken (Team B1, 26.11.2026): drei eigene Welten mit eigener
## Fahrbahn, Kulisse, Ereignissen und Klängen. kart_world.gd und kart_tracks.gd fragen hier
## mit has() und erhalten Mittellinie, Breite, Wand, Trennwand-Kontakt und Kamera-Grenzen.
## Jede Strecke liegt in ihrem eigenen Ordner (Kurs = Fahrautorität, Umgebung = Bild/Ton).
const GEOMETRY = preload("res://scripts/games/kart_signature/kart_signature_geometry.gd")
const VULKAN = preload("res://scripts/games/vulkanexpress/vulkan_course.gd")
const WOLKEN = preload("res://scripts/games/wolkensturm/wolken_course.gd")
const FLUT = preload("res://scripts/games/kristallflut/flut_course.gd")
const COURSES: Dictionary = {
	VULKAN.ID: VULKAN,
	WOLKEN.ID: WOLKEN,
	FLUT.ID: FLUT,
}
const IDS: Array[String] = [VULKAN.ID, WOLKEN.ID, FLUT.ID]
const WORLD_PATH: String = "res://scripts/games/kart_signature/kart_signature_world.gd"
## Kinderkart: Mitte bleibt 0,9 m innerhalb der Fahrbahnkante (wie Riesengarten).
const WALL_INSET: float = 0.9
const KART_RADIUS: float = 0.9


## Katalogeinträge (kart_catalog.gd) in der Reihenfolge von IDS.
static func catalog() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id in IDS:
		result.append(course(id).CATALOG_ENTRY)
	return result


static func has(track_id: String) -> bool:
	return COURSES.has(track_id)


static func course(track_id: String):
	return COURSES[track_id]


static func definition(track_id: String) -> Dictionary:
	return course(track_id).definition()


static func make_curve(track_id: String) -> Curve3D:
	return GEOMETRY.make_curve(course(track_id))


static func width_at(track_id: String, distance: float) -> float:
	return GEOMETRY.width_at(course(track_id), distance)


static func wall_at(track_id: String, distance: float) -> float:
	return width_at(track_id, distance) * 0.5 - WALL_INSET


static func build(world: Node3D, geometry_only: bool) -> void:
	load(WORLD_PATH).build(world, course(str(world.track_id)), geometry_only)


# ------------------------------------------------------------------ Trennwände (Abzweige)


## Halbe Dicke der Trennwand an dieser Stelle und ihre Querlage (Vector2(0, 0) außerhalb).
static func divider(track_id: String, distance: float) -> Vector2:
	var data = course(track_id)
	var d: float = fposmod(distance, float(data.LENGTH))
	for split in data.SPLITS:
		var a: float = float(split.start)
		var b: float = float(split.end)
		if d < a or d > b:
			continue
		var wedge: float = float(split.get("wedge", 8.0))
		var grow: float = clampf(minf((d - a) / wedge, (b - d) / wedge), 0.0, 1.0)
		return Vector2(float(split.half) * grow, float(split.lateral))
	return Vector2.ZERO


## Trennwand: die Kartmitte bleibt half + Kartradius von ihr weg, auf der Seite, von der
## das Kart kommt (dieselbe Regel wie die Kürbisschale im Riesengarten).
static func resolve_motion(world: Node3D, from: Vector3, desired: Vector3) -> Dictionary:
	var result: Dictionary = {"position": desired, "normal": Vector3.ZERO, "collided": false}
	var to_road: Dictionary = world.sample_road(desired)
	var wall: Vector2 = divider(str(world.track_id), float(to_road.distance))
	if wall.x <= 0.0:
		return result
	var reach: float = wall.x + KART_RADIUS
	var offset: float = float(to_road.lateral) - wall.y
	if absf(offset) >= reach:
		return result
	var from_road: Dictionary = world.sample_road(from, float(to_road.distance))
	var side: float = signf(float(from_road.lateral) - wall.y)
	if side == 0.0:
		side = signf(offset) if offset != 0.0 else 1.0
	var basis: Basis = to_road.basis
	result.position = desired + basis.x * (side * reach - offset)
	result.normal = basis.x * side
	result.collided = true
	return result


# ------------------------------------------------------------------ Kamera


## Die Kamera bleibt in Tunneln und Höhlen unter der Decke und zwischen den Wänden.
static func clip_camera(world: Node3D, anchor: Vector3, desired: Vector3) -> Vector3:
	var data = course(str(world.track_id))
	var anchor_road: Dictionary = world.sample_road(anchor)
	var road: Dictionary = world.sample_road(desired, float(anchor_road.distance))
	var d: float = float(road.distance)
	for tunnel in data.TUNNELS:
		if d < float(tunnel.start) - 2.0 or d > float(tunnel.end) + 2.0:
			continue
		var basis: Basis = road.basis
		var centre: Vector3 = world.position_at(d)
		var lateral: float = (desired - centre).dot(basis.x)
		var elevation: float = (desired - centre).dot(basis.y)
		var half: float = world.road_width_at(d) * 0.5 - 0.6
		return (
			centre
			+ basis.x * clampf(lateral, -half, half)
			+ basis.y * clampf(elevation, 1.0, float(tunnel.ceiling) - 0.8)
		)
	return desired
