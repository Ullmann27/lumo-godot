extends SceneTree
## Vertragstest der Sammelzonen (kart_item_zones.gd) auf allen 13 Strecken.
## Je Strecke wird das echte Rennen gebaut und geprüft:
##  - Anzahl 5–8 Zonen je Runde (Streckenlänge/270 m), je Zone 2–3 Prismen;
##  - kein Prisma in einem Sperrbereich (Start/Ziel, Checkpoint, Rampe, Looping, Sprung,
##    Tunnel, Passage, offene Kante, Slalom, Turbofeld, Hindernis, Ringe);
##  - innerhalb der Planke, auf Kart-Höhe, keine scharfe Kurve, keine Kuppe;
##  - Sichtweite aus der Fahrerkamera ≥ 45 m;
##  - Abstände zwischen Zonen ≥ halber Idealabstand (auch über die Rundengrenze);
##  - in Runde 2 wieder einsammelbar (Schlüssel je Runde), Rivalen können sammeln;
##  - Spannungsstellen (kart_track_thrills.gd) und Fahrspaß-Höhepunkte
##    (kart_track_highlights.gd) sind Sperrbereiche: keine Zone im Element samt Anlauf,
##    über einem Spalt und an einer Risiko-Kante kein Treffer (Raketen-Fairness).
## `--tracks=a,b` grenzt ein, `--report=<json>` schreibt die Tabelle.
const TRACKS = preload("res://scripts/games/kart_tracks.gd")
const ZONES = preload("res://scripts/games/kart_items/kart_item_zones.gd")
const THRILLS = preload("res://scripts/games/kart_track_thrills.gd")
## Anlauf vor einem Element, in dem keine Zone liegen darf (Meter).
const ELEMENT_LEAD_M: float = 25.0

var game
var checks := 0
var failures: Array[String] = []
var course := ""
var table: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition:
		failures.append("%s: %s" % [course, label])
		print("[KartItemZones] FAIL %s: %s" % [course, label])
	return condition


func _zones_from_race() -> Array[Dictionary]:
	var zones: Array[Dictionary] = []
	for i in range(game.catalog_boxes.size()):
		var d: float = game.catalog_box_distances[i]
		if zones.is_empty() or absf(d - float(zones.back().distance)) > 1.0:
			zones.append({"distance": d, "laterals": [], "boxes": []})
		zones.back().laterals.append(float(game.catalog_box_laterals[i]))
		zones.back().boxes.append(i)
	return zones


func _course(track: String) -> void:
	course = track
	game._start_selected_race(
		{
			"mode": "race",
			"driver": "fox",
			"kart": "comet",
			"track": track,
			"difficulty": "gemuetlich"
		}
	)
	await process_frame
	var world = game.world
	var length: float = game.track_length
	var zones := _zones_from_race()
	var expected: int = ZONES.target_count(length)
	var row := {
		"strecke": track,
		"laenge_m": roundi(length),
		"zonen": zones.size(),
		"ziel": expected,
		"prismen": game.catalog_boxes.size(),
	}
	_check(zones.size() >= ZONES.MIN_ZONES, "mindestens 5 Zonen je Runde (%d)" % zones.size())
	_check(zones.size() <= ZONES.MAX_ZONES, "höchstens 8 Zonen je Runde (%d)" % zones.size())
	_check(
		zones.size() >= expected - 2,
		"Zonen passen zur Länge (%d von %d)" % [zones.size(), expected]
	)
	var areas: Array[Dictionary] = ZONES.hazards(world, game._catalog_zone_occupied())
	var spacing: float = length / float(maxi(1, zones.size()))
	var min_gap := INF
	var min_sight := INF
	var min_half := INF
	var max_turn := 0.0
	var patterns: Dictionary = {}
	for z in range(zones.size()):
		var zone: Dictionary = zones[z]
		var d: float = float(zone.distance)
		var count: int = zone.laterals.size()
		_check(count >= 2 and count <= 3, "Zone %d hat 2–3 Prismen (%d)" % [z, count])
		var reason: String = ZONES.blocked_by(world, d, areas)
		_check(reason.is_empty(), "Zone %d bei %.0f m liegt frei (%s)" % [z, d, reason])
		var half: float = ZONES.usable_half(world, d)
		min_half = minf(min_half, half)
		_check(half >= ZONES.MIN_HALF, "Zone %d breit genug (%.1f m)" % [z, half])
		var turn: float = ZONES.turn_degrees(world, d)
		max_turn = maxf(max_turn, turn)
		_check(turn <= ZONES.MAX_TURN_DEG, "Zone %d keine scharfe Kurve (%.0f°)" % [z, turn])
		var crest: float = ZONES.crest_height(world, d)
		_check(absf(crest) <= ZONES.CREST_LIMIT_M, "Zone %d keine enge Kuppe (%.2f m)" % [z, crest])
		var sight := INF
		var lanes: Array = []
		for k in range(zone.boxes.size()):
			var i: int = zone.boxes[k]
			var lateral: float = float(zone.laterals[k])
			lanes.append("L" if lateral < -0.5 else ("R" if lateral > 0.5 else "M"))
			var wall: float = game._wall_lateral_at(d)
			_check(
				absf(lateral) <= wall - 1.0,
				"Prisma %d innerhalb der Planke (%.1f/%.1f)" % [i, lateral, wall]
			)
			var lift: float = game.catalog_boxes[i].position.distance_to(
				game._track_position(d, lateral)
			)
			_check(lift > 0.5 and lift < 1.8, "Prisma %d auf Kart-Höhe (%.2f m)" % [i, lift])
			sight = minf(sight, ZONES.sight_distance(world, d, lateral))
		min_sight = minf(min_sight, sight)
		_check(
			sight >= ZONES.SIGHT_MIN_M,
			"Zone %d aus der Fahrerkamera sichtbar (%.0f m)" % [z, sight]
		)
		var pattern: String = "".join(lanes)
		patterns[pattern] = int(patterns.get(pattern, 0)) + 1
		var next_d: float = float(zones[(z + 1) % zones.size()].distance)
		var gap: float = fposmod(next_d - d, length) if zones.size() > 1 else length
		min_gap = minf(min_gap, gap)
	_check(
		min_gap >= length / float(ZONES.target_count(length)) * ZONES.MIN_GAP_FRACTION - 0.1,
		"Zonenabstand ≥ halber Idealabstand (%.0f m)" % min_gap
	)
	_elements(world, zones, areas, length, row)
	row["kleinster_abstand_m"] = roundi(min_gap)
	row["kleinste_sicht_m"] = roundi(min_sight)
	row["kleinste_halbbreite_m"] = snappedf(min_half, 0.1)
	row["groesste_kurve_grad"] = roundi(max_turn)
	row["muster"] = patterns
	# Runde 2: der Rundenschlüssel gibt jedes Prisma wieder frei.
	if not zones.is_empty():
		var first: int = zones[0].boxes[0]
		game.catalog_box_collected[0 * game.catalog_boxes.size() + first] = true
		game.distance = length + 5.0
		game._sync_item_box_visibility()
		_check(game.catalog_boxes[first].visible, "Prisma in Runde 2 wieder da")
		game.distance = 5.0
		game._sync_item_box_visibility()
		_check(not game.catalog_boxes[first].visible, "in Runde 1 eingesammelt bleibt weg")
		game.catalog_box_collected.clear()
		game._sync_item_box_visibility()
		# Rivale an einem Prisma bekommt ein Item.
		if not game.opponents.is_empty():
			game.opponent_items[0] = ""
			game.opponents[0].position = game.catalog_boxes[first].position
			game._rival_collect_catalog_box(0)
			_check(not str(game.opponent_items[0]).is_empty(), "Rivale sammelt ein Prisma")
	table.append(row)
	print("[KartItemZones] ", JSON.stringify(row))


## Spannungsstellen und Höhepunkte: Sperrbereich, keine Zone darin, Sturzstellen trefferfrei.
func _elements(
	world, zones: Array[Dictionary], areas: Array[Dictionary], length: float, row: Dictionary
) -> void:
	var elements: Array = []
	for thrill in THRILLS.of(world):
		elements.append({"source": "spannung", "entry": thrill})
	for entry in world.get_meta("highlight_plan", []):
		elements.append({"source": "hoehepunkt", "entry": entry})
	var names: Array = []
	for item in elements:
		var entry: Dictionary = item.entry
		var label: String = "%s %s:%s" % [item.source, entry.kind, entry.id]
		names.append("%s:%s" % [entry.kind, entry.id])
		var start: float = float(entry.start)
		var end: float = float(entry.end)
		_check(
			not ZONES.blocked_by(world, (start + end) * 0.5, areas).is_empty(),
			"%s ist Sperrbereich der Sammelzonen" % label
		)
		for z in range(zones.size()):
			var d: float = float(zones[z].distance)
			var inside: bool = false
			for shift in [-length, 0.0, length]:
				if d + shift >= start - ELEMENT_LEAD_M and d + shift <= end:
					inside = true
			_check(not inside, "Zone %d bei %.0f m nicht in %s" % [z, d, label])
		if str(entry.kind) == "leap":
			var over_gap: float = (float(entry.take_off) + float(entry.gap_end)) * 0.5
			_check(
				not str(game.rocket_fairness.danger_at(world, over_gap)).is_empty(),
				"%s: über dem Spalt kein Treffer" % label
			)
		if str(entry.kind) == "risiko":
			_check(
				not str(game.rocket_fairness.danger_at(world, (start + end) * 0.5)).is_empty(),
				"%s: an der offenen Kante kein Treffer" % label
			)
	row["elemente"] = names


func _run() -> void:
	root.get_node("SceneRouter").launch_options = {"childKey": "items-zones"}
	var selected: Array[String] = TRACKS.IDS.duplicate()
	var report := ""
	for argument in OS.get_cmdline_user_args():
		if str(argument).begins_with("--tracks="):
			selected.clear()
			for id in str(argument).trim_prefix("--tracks=").split(","):
				selected.append(id)
		if str(argument).begins_with("--report="):
			report = str(argument).trim_prefix("--report=")
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	await process_frame
	for track in selected:
		await _course(track)
	game.abandoned = true
	game.queue_free()
	await process_frame
	if not report.is_empty():
		var file := FileAccess.open(report, FileAccess.WRITE)
		if file != null:
			file.store_string(
				JSON.stringify({"checks": checks, "failures": failures, "courses": table}, "  ")
			)
	if failures.is_empty():
		print("[KartItemZones] PASS: %d checks on %d courses" % [checks, table.size()])
	else:
		for text in failures:
			print("[KartItemZones]   - ", text)
		print("[KartItemZones] FAILED: %d of %d checks" % [failures.size(), checks])
	await create_timer(0.2).timeout
	quit(0 if failures.is_empty() else 1)
