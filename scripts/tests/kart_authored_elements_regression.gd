extends SceneTree
## Überlappungen, freie Spur und Landefläche für nachträglich ergänzte Fahrelemente.
const WORLD = preload("res://scripts/games/kart_world.gd")
const TRACKS = preload("res://scripts/games/kart_tracks.gd")
var failures: Array[String] = []
var tested := {}


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		printerr(message)


func _run() -> void:
	for id in TRACKS.IDS:
		var world := WORLD.new()
		root.add_child(world)
		world.build(true, id, true)
		_check_track(world)
		world.free()
		await process_frame
	for tag in ["thrill", "highlight", "garden"]:
		check(tested.has(tag), "Keine Elemente mit Schlüssel " + tag)
	print("[KartAuthored] %s %s" % ["PASS" if failures.is_empty() else "FAIL", tested])
	quit(0 if failures.is_empty() else 1)


func _check_track(world) -> void:
	var spans: Array[Dictionary] = []
	for kind in ["kickers", "edges", "dives", "pads", "gates"]:
		for item in world.action.get(kind, []):
			var tag := ""
			for key in ["thrill", "highlight", "garden"]:
				if item.has(key):
					tag = key
					tested[key] = int(tested.get(key, 0)) + 1
			var name := "%s %s %s" % [world.track_id, kind, item.get(tag, "")]
			var start: float = item.get("start", item.get("distance", 0.0))
			var end: float = item.get("end", item.get("take_off", start + 1.0))
			if kind == "kickers":
				end = item.get("landing_road_end", end + 10.0)
			if not tag.is_empty():
				check(start > 30.0 and start < end and end < world.length - 25.0, name + " Start/Ziel")
				if kind == "edges":
					var safe: float = -float(item.side) * 2.0
					check(world.sample_road(world.position_at(start, safe), start).on_road and
						world.open_edge_side(start + 0.5) != signf(safe), name + " Sichere Spur")
				if kind == "pads":
					check(absf(item.lateral) < world.road_width_at(start) * 0.5, name + " Turbo erreichbar")
				if kind == "kickers":
					check(not world.in_gap(end) and world.sample_road(
						world.position_at(end), end).on_road, name + " Landefläche")
			var group := str(item.get(tag, "")) if not tag.is_empty() else ""
			for other in spans:
				if tag.is_empty() and other.tag.is_empty():
					continue
				if start >= other.end or end <= other.start:
					continue
				# Beim Risiko-Höhepunkt gehört die Turbolinie an den offenen Rand.
				var risk_pair: bool = (tag == "highlight" and other.tag == tag and other.group == group
					and ((kind == "pads" and other.kind == "edges") or (kind == "edges" and other.kind == "pads")))
				check(risk_pair, "%s bei %.1f überlappt %s bei %.1f" % [name, start, other.name, other.start])
			spans.append({"start": start, "end": end, "kind": kind, "tag": tag, "group": group, "name": name})
