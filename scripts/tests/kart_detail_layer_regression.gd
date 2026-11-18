extends SceneTree
## Detail-Schicht der Kart-Strecken: jede der 13 Strecken bekommt sie in allen
## drei Profilen, mit Mindestzahlen je Kategorie; nichts Stehendes auf der
## Fahrbahn; keine Kollisionskörper; Budgets je Profil (Meshes = Draw-Calls je
## Abschnitt, Dreiecke im Sichtfenster von drei Abschnitten); LOW bleibt sparsam.
## Headless: godot --headless --path . --script res://scripts/tests/kart_detail_layer_regression.gd
const WORLD = preload("res://scripts/games/kart_world.gd")
const TRACKS = preload("res://scripts/games/kart_tracks.gd")
const DETAIL = preload("res://scripts/games/visual/kart_detail_layer.gd")
## Mindestzahlen je Profil und Kategorie.
const MINIMA: Dictionary = {
	"low": {"stage": 4, "wear": 6, "life": 8},
	"medium": {"stage": 10, "wear": 40, "props": 25, "life": 25, "light": 8},
	"high": {"stage": 10, "wear": 70, "props": 40, "life": 35, "light": 14},
}
## Obergrenzen: Meshes der ganzen Schicht (LOW) bzw. je Abschnitt, Dreiecke.
const LOW_MAX_MESHES: int = 6
const LOW_MAX_TRIANGLES: int = 30000
const CHUNK_MAX_MESHES: int = 5
const MEDIUM_WINDOW_TRIANGLES: int = 120000
const SAFETY_M: float = 0.9
var failures: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	failures.append(message)
	print("[KartDetailLayer] FAIL " + message)


func _no_collision(node: Node) -> bool:
	if node is CollisionObject3D or node is CollisionShape3D:
		return false
	for child in node.get_children():
		if not _no_collision(child):
			return false
	return true


func _check(world, track: String, profile: String) -> Dictionary:
	DETAIL.apply(world, track, profile)
	var layer: Node3D = world.get_node_or_null(DETAIL.ROOT_NAME)
	if layer == null:
		_fail("%s/%s: keine Detail-Schicht" % [track, profile])
		return {}
	var info: Dictionary = world.get_meta(DETAIL.META)
	var stats: Dictionary = info.stats
	for category: String in MINIMA[profile]:
		if int(stats.get(category, 0)) < int(MINIMA[profile][category]):
			_fail("%s/%s: %s %d < %d" % [track, profile, category, int(stats.get(category, 0)), int(MINIMA[profile][category])])
	if not _no_collision(layer):
		_fail("%s/%s: Kollisionskörper in der Detail-Schicht" % [track, profile])
	for item: Dictionary in info.placed:
		if item.flat:
			continue
		if float(item.lateral) <= float(item.half_width) + SAFETY_M:
			_fail("%s/%s: %s steht bei %.1f m auf/zu nah an der Fahrbahn (halbe Breite %.1f)" % [
				track, profile, item.kind, float(item.lateral), float(item.half_width)])
	# Budgets.
	var per_chunk: Dictionary = {}
	var total_triangles: int = 0
	var meshes: int = 0
	for child in layer.get_children():
		if not (child is MeshInstance3D):
			continue
		meshes += 1
		var tris: int = int(child.get_meta("triangles", 0))
		if tris == 0:
			for s in range(child.mesh.get_surface_count()):
				tris += (child.mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		total_triangles += tris
		var name: String = str(child.name)
		if name.begins_with("Detail_"):
			var chunk: int = int(name.get_slice("_", 1))
			if not per_chunk.has(chunk):
				per_chunk[chunk] = {"meshes": 0, "triangles": 0}
			per_chunk[chunk].meshes += 1
			per_chunk[chunk].triangles += tris
	var window: int = 0
	var keys: Array = per_chunk.keys()
	keys.sort()
	for i in range(keys.size()):
		var sum: int = 0
		for k in range(3):
			if i + k < keys.size():
				sum += int(per_chunk[keys[i + k]].triangles)
		window = maxi(window, sum)
		if int(per_chunk[keys[i]].meshes) > CHUNK_MAX_MESHES:
			_fail("%s/%s: Abschnitt %d hat %d Meshes" % [track, profile, int(keys[i]), int(per_chunk[keys[i]].meshes)])
	if profile == "low":
		if meshes > LOW_MAX_MESHES:
			_fail("%s/low: %d Meshes > %d" % [track, meshes, LOW_MAX_MESHES])
		if total_triangles > LOW_MAX_TRIANGLES:
			_fail("%s/low: %d Dreiecke > %d" % [track, total_triangles, LOW_MAX_TRIANGLES])
	if profile == "medium" and window > MEDIUM_WINDOW_TRIANGLES:
		_fail("%s/medium: %d Dreiecke in drei Abschnitten > %d" % [track, window, MEDIUM_WINDOW_TRIANGLES])
	var summary := {"meshes": meshes, "triangles": total_triangles, "window": window, "stats": stats, "ms": info.build_ms}
	print("[KartDetailLayer] %s %s meshes=%d tris=%d window=%d %.0f ms %s" % [
		track, profile, meshes, total_triangles, window, float(info.build_ms), JSON.stringify(stats)])
	return summary


func _run() -> void:
	var tracks: Array[String] = []
	for argument in OS.get_cmdline_user_args():
		if argument in TRACKS.IDS:
			tracks.append(argument)
	if tracks.is_empty():
		tracks.assign(TRACKS.IDS)
	if tracks.size() == 13 and TRACKS.IDS.size() != 13:
		_fail("Erwartet 13 Strecken, Katalog hat %d" % TRACKS.IDS.size())
	for track in tracks:
		var world = WORLD.new()
		root.add_child(world)
		world.build(false, track)
		await process_frame
		await process_frame
		# Der automatische (deferred) Aufbau muss stattgefunden haben.
		if world.get_node_or_null(DETAIL.ROOT_NAME) == null:
			_fail("%s: Detail-Schicht wurde beim Weltaufbau nicht angehängt" % track)
		var low: Dictionary = _check(world, track, "low")
		var medium: Dictionary = _check(world, track, "medium")
		var high: Dictionary = _check(world, track, "high")
		if not low.is_empty() and not medium.is_empty() and int(low.triangles) * 3 > int(medium.triangles):
			_fail("%s: LOW ist nicht sparsam genug (%d vs. MEDIUM %d)" % [track, int(low.triangles), int(medium.triangles)])
		if not medium.is_empty() and not high.is_empty() and int(high.triangles) < int(medium.triangles):
			_fail("%s: HIGH hat weniger Details als MEDIUM" % track)
		world.queue_free()
		await process_frame
	# Leicht-/Geometrie-Bau: keine Schicht im reinen Geometrie-Modus.
	var geometry = WORLD.new()
	root.add_child(geometry)
	geometry.build(false, "sonnenhafen", true)
	await process_frame
	await process_frame
	if geometry.get_node_or_null(DETAIL.ROOT_NAME) != null:
		_fail("Geometrie-Bau darf keine Detail-Schicht bekommen")
	geometry.queue_free()
	await process_frame
	print("[KartDetailLayer] %s: %d Strecken, %d Fehler" % ["PASS" if failures.is_empty() else "FAIL", tracks.size(), failures.size()])
	quit(0 if failures.is_empty() else 1)
