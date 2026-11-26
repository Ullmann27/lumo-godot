extends SceneTree
## Entwurfsbericht einer Signatur-Strecke (Team B1): Lage alle 100 m, Segmentgrenzen in
## Fahrbahnmetern, geplante Spannungsstellen, Schanzen, Turbofelder und Passagen.
##
##   godot --headless --path . --script res://scripts/tests/kart_signature_survey.gd -- --track=<id>
const SIGNATURE = preload("res://scripts/games/kart_signature/kart_signature_tracks.gd")
const GEOMETRY = preload("res://scripts/games/kart_signature/kart_signature_geometry.gd")
const THRILLS = preload("res://scripts/games/kart_track_thrills.gd")
const PASSAGES = preload("res://scripts/games/kart_passages.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var track: String = SIGNATURE.IDS[0]
	for argument in OS.get_cmdline_user_args():
		if str(argument).begins_with("--track="):
			track = str(argument).trim_prefix("--track=")
	var course = SIGNATURE.course(track)
	var world = load("res://scripts/games/kart_world.gd").new()
	root.add_child(world)
	world.build(true, track, true)
	print("[Survey] %s Länge %.2f m (Kurs sagt %.1f)" % [track, world.length, float(course.LENGTH)])
	var frees: Vector2 = GEOMETRY.close(course)
	print("[Survey] freie Geraden %.1f / %.1f m" % [frees.x, frees.y])
	var ends: Array[float] = GEOMETRY.segment_ends(course)
	var start: float = 0.0
	for i in range(ends.size()):
		var a: float = GEOMETRY.final_metres(course, start)
		var b: float = GEOMETRY.final_metres(course, ends[i])
		print("[Survey] Segment %02d %s: %.1f – %.1f m" % [i, str(course.SEGMENTS[i]), a, b])
		start = ends[i]
	for metre in range(0, floori(world.length), 100):
		var p: Vector3 = world.position_at(metre)
		print(
			(
				"[Survey] %4d m: (%.1f, %.1f, %.1f) Breite %.1f"
				% [metre, p.x, p.y, p.z, world.road_width_at(metre)]
			)
		)
	for entry in THRILLS.of(world):
		print(
			"[Survey] Spannung %s %s %.1f – %.1f" % [entry.kind, entry.id, entry.start, entry.end]
		)
	for kicker in world.action.kickers:
		print(
			(
				"[Survey] Schanze %.1f – %.1f (Landung bis %.1f) %s"
				% [
					kicker.start,
					kicker.take_off,
					float(kicker.get("landing_road_end", 0.0)),
					str(kicker.get("thrill", kicker.get("signature", "")))
				]
			)
		)
	for pad in world.action.pads:
		print("[Survey] Turbo %.1f – %.1f quer %.1f" % [pad.start, pad.end, pad.lateral])
	for entry in PASSAGES.of(world):
		print(
			(
				"[Survey] Passage %s %s %.1f – %.1f"
				% [entry.kind, entry.id, entry.zone_start, entry.zone_end]
			)
		)
	world.free()
	quit(0)
