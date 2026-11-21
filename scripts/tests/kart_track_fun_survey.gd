extends SceneTree
## Fahrspaß-Messung je Strecke aus echten Rennabläufen (Container, keine Gerätewerte).
## Ein volles Feld (Kind + fünf Rivalen) fährt zwei Runden mit festem Startwert. Das
## Test-Kind lenkt physikalisch wie ein aufmerksames Kind: mit leerem Item-Feld auf das
## nächste Prisma, sonst auf Turbo-Felder und Slalom-Tore voraus, sonst Mitte; Items nutzt
## es nach kurzer Pause. Kein Zustand des Rennens wird nach dem Start gesetzt.
##
## Gemessen wird die Zeitachse aller Ereignisse:
##   Strecke   – Überfahren gebauter Elemente (Passage, Schanze, Turbo-Feld, Slalom, Tunnel,
##               offene Kante, Looping, Itemzone, Resonanzring, Lasso-Posten, Spannungsstelle)
##               und echte Sprünge (Flug ≥ 0,25 s);
##   Rennen    – Überholung (Platz gewonnen/verloren), Treffer, Sturz/Rettung, Item-Nutzung.
## Kennzahlen: Zeit bis zum ersten Ereignis, längste ereignislose Zeit (gesamt und nur
## Strecke), Ereignisarten je Runde, Rivalen-Abstände, Stürze/Rettungen.
##
## Argumente: --tracks=a,b  --difficulties=gemuetlich,flott  --seeds=1  --report=<json>
##            --capture=<ordner> --shots=t1,t2,...  (Bilder aus der Fahrerkamera zu Rennzeiten)
const TRACKS = preload("res://scripts/games/kart_tracks.gd")
const PASSAGES = preload("res://scripts/games/kart_passages.gd")
const STEP := 1.0 / 60.0
const ROCKET := "star_rocket"
const MIN_AIR := 0.25
## Markante Stellen: was ein Kind später beschreiben kann (nicht Turbo-Feld/Prisma/Ring).
const HIGHLIGHTS: Array[String] = [
	"passage",
	"schanze",
	"sprung",
	"looping",
	"tunnel",
	"kante",
	"lasso",
	"tor",
	"spannung",
	"element"
]

var game
var events: Array[Dictionary] = []
var shots: Array[float] = []
var capture_dir := ""
var shot_index := 0


func _initialize() -> void:
	call_deferred("_run")


func _arg(name: String, fallback: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if str(argument).begins_with("--%s=" % name):
			return str(argument).trim_prefix("--%s=" % name)
	return fallback


func _run() -> void:
	var track_ids: Array = Array(TRACKS.IDS)
	var wanted := _arg("tracks", "")
	if not wanted.is_empty():
		track_ids = Array(wanted.split(","))
	var difficulties: Array = Array(_arg("difficulties", "gemuetlich,flott").split(","))
	var seeds: Array = Array(_arg("seeds", "1").split(","))
	capture_dir = _arg("capture", "")
	for value in _arg("shots", "").split(",", false):
		shots.append(float(value))
	var report := _arg("report", "user://kart_track_fun_survey.json")
	if _arg("highlights-off", "") == "1":
		load("res://scripts/games/kart_track_highlights.gd").enabled = false
	var rows: Array = []
	for track in track_ids:
		for difficulty in difficulties:
			for seed_text in seeds:
				game = load("res://scenes/games/kart_island.tscn").instantiate()
				root.add_child(game)
				game.set_physics_process(false)
				game.lightweight = capture_dir.is_empty()
				await process_frame
				var row: Dictionary = await _race(str(track), str(difficulty), int(seed_text))
				rows.append(row)
				print(
					"[FunSurvey] ROW ",
					JSON.stringify(row.duplicate().merged({"events": row.events.size()}, true))
				)
				game.queue_free()
				await process_frame
				await process_frame
	var file := FileAccess.open(report, FileAccess.WRITE)
	file.store_string(JSON.stringify(rows, " "))
	file.close()
	print("[FunSurvey] REPORT ", ProjectSettings.globalize_path(report))
	var soundscape = root.get_node_or_null("GameSoundscape")
	if soundscape and soundscape.has_method("release_audio"):
		soundscape.release_audio()
	await create_timer(0.4).timeout
	quit(0)


## Gebaute Streckenelemente als (Rundendistanz, Art, Name). Alles aus den echten Plänen.
func _authored() -> Array[Dictionary]:
	var world = game.world
	var length: float = game.track_length
	var out: Array[Dictionary] = []
	for entry in PASSAGES.of(world):
		out.append(
			{
				"d": float(entry.zone_start),
				"kind": "passage",
				"name": "%s:%s" % [entry.kind, entry.get("id", "")]
			}
		)
	var action: Dictionary = world.action
	for pad in action.get("pads", []):
		out.append({"d": float(pad.start), "kind": "turbo", "name": "pad"})
	var gates: Array = action.get("gates", [])
	if not gates.is_empty():
		out.append({"d": float(gates[0].distance) - 8.0, "kind": "tor", "name": "slalom"})
	for kicker in action.get("kickers", []):
		out.append(
			{
				"d": float(kicker.start),
				"kind": "schanze",
				"name":
				(
					"hero"
					if bool(kicker.get("hero_flight", false))
					else str(kicker.get("thrill", "kicker"))
				)
			}
		)
	for dive in action.get("dives", []):
		out.append({"d": float(dive.start), "kind": "tunnel", "name": "dive"})
	for edge in action.get("edges", []):
		out.append({"d": float(edge.start), "kind": "kante", "name": "edge"})
	for key in action.keys():
		if key in ["pads", "gates", "kickers", "dives", "edges"]:
			continue
		if action[key] is Array:
			for element in action[key]:
				if element is Dictionary and element.has("start"):
					out.append({"d": float(element.start), "kind": "element", "name": str(key)})
	if not world.loop_layout.is_empty() and world.loop_layout.has("start"):
		out.append({"d": float(world.loop_layout.start), "kind": "looping", "name": "loop"})
	if not world.jump.is_empty() and world.jump.has("ramp_start"):
		out.append({"d": float(world.jump.ramp_start), "kind": "schanze", "name": "gap"})
	if not world.adventure_tunnel.is_empty() and world.adventure_tunnel.has("start"):
		out.append(
			{"d": float(world.adventure_tunnel.start), "kind": "tunnel", "name": "adventure"}
		)
	var production: Dictionary = world.production_tunnel_layout
	if not production.is_empty() and production.has("start"):
		out.append({"d": float(production.start), "kind": "tunnel", "name": "production"})
	# Prismen-Reihen und Resonanzringe als Itemzonen (benachbarte zusammengefasst).
	var item_d: Array = []
	for d in game.catalog_box_distances:
		item_d.append(float(d))
	for d in game.item_box_distances:
		item_d.append(float(d))
	item_d.sort()
	var last := -1000.0
	for d in item_d:
		if d - last > 12.0:
			out.append({"d": d - 4.0, "kind": "itemzone", "name": "prisma"})
		last = d
	if is_instance_valid(game.roadside_lasso) and "layout" in game.roadside_lasso:
		for crew in game.roadside_lasso.layout:
			out.append({"d": float(crew.distance) - 10.0, "kind": "lasso", "name": "posten"})
	for trigger in game.track_triggers:
		if is_instance_valid(trigger):
			var sampled: Dictionary = world.sample_road(trigger.global_position, 0.0)
			out.append(
				{
					"d": float(sampled.distance),
					"kind": "turbo",
					"name": str(trigger.get("trigger_kind"))
				}
			)
	var drama = load("res://scripts/games/kart_adventure_drama.gd")
	for fraction in drama.turbo_fractions(str(game.track_id)):
		out.append(
			{
				"d": PASSAGES.clear_distance(world, float(fraction) * length),
				"kind": "turbo",
				"name": "drama"
			}
		)
	# Hindernisse (Felsen, Hütchen, Lianen) als Gruppen; Bauteil-Platzhalter mit Warnschild.
	var obstacle_d: Array = []
	for at in world.action_obstacles:
		obstacle_d.append(float(world.sample_road(at, 0.0).distance))
	obstacle_d.sort()
	var last_obstacle := -1000.0
	for d in obstacle_d:
		if d - last_obstacle > 20.0:
			out.append({"d": d - 6.0, "kind": "hindernis", "name": "fels"})
		last_obstacle = d
	var drama_report: Dictionary = world.get_meta("adventure_drama", {})
	for marker in drama_report.get("markers", []):
		out.append({"d": float(marker.distance_m), "kind": "attrappe", "name": str(marker.bauteil)})
	if world.has_meta("thrill_plan"):
		for thrill in world.get_meta("thrill_plan"):
			out.append(
				{
					"d": float(thrill.get("start", thrill.get("at", 0.0))),
					"kind": "spannung",
					"name": "%s:%s" % [thrill.get("kind", ""), thrill.get("id", "")]
				}
			)
	for entry in out:
		entry.d = fposmod(float(entry.d), length)
	out.sort_custom(func(a, b): return float(a.d) < float(b.d))
	return out


func _counters() -> Dictionary:
	var stats: Dictionary = game.gameplay_stats
	var lasso := 0
	if is_instance_valid(game.roadside_lasso) and "catches" in game.roadside_lasso:
		lasso = int(game.roadside_lasso.catches) + int(game.roadside_lasso.dodges)
	return {
		"reset": int(game.reset_count),
		"sturz": int(game.passage_falls) + int(game.gap_falls) + int(game.action_edge_falls),
		"treffer":
		(
			int(stats.get("player_hits_taken", 0))
			+ int(game.passage_hits)
			+ int(game.action_gates_hit)
		),
		"looping": int(game.loop_count),
		"item_nutzung": int(stats.get("items_used", 0)),
		"ring": int(stats.get("rings", 0)),
		"windschatten": int(stats.get("slipstreams", 0)),
		"trick": int(stats.get("tricks", 0)),
		"rivale_getroffen": int(stats.get("player_hits_scored", 0)),
		"lasso_reaktion": lasso,
		"turbo_ausgeloest": int(game.action_pads_triggered),
		"slalom_geschafft": int(game.action_slaloms_cleared),
	}


func _event(kind: String, name: String, group: String) -> void:
	var lap: int = int(game.distance / game.track_length)
	(
		events
		. append(
			{
				"t": snappedf(game.elapsed, 0.01),
				"d": snappedf(fposmod(game.previous_road_distance, game.track_length), 0.1),
				"lap": lap,
				"kind": kind,
				"name": name,
				"group": group,
			}
		)
	)


func _target_lane() -> float:
	var here: float = fposmod(game.previous_road_distance, game.track_length)
	var lap: int = int(game.distance / game.track_length)
	var best := INF
	var lane := 0.0
	if str(game.item).is_empty():
		for i in range(game.catalog_boxes.size()):
			if game.catalog_box_collected.has(lap * game.catalog_boxes.size() + i):
				continue
			var ahead: float = fposmod(
				float(game.catalog_box_distances[i]) - here, game.track_length
			)
			if ahead < 3.0 or ahead > 55.0:
				continue
			var score: float = (
				ahead + absf(float(game.catalog_box_laterals[i]) - float(game.lane)) * 4.0
			)
			if score < best:
				best = score
				lane = float(game.catalog_box_laterals[i])
	if best == INF:
		var action: Dictionary = game.world.action
		for pad in action.get("pads", []):
			var ahead: float = fposmod(float(pad.start) - here, game.track_length)
			if (
				ahead < 40.0
				or (
					fposmod(here - float(pad.start), game.track_length)
					< float(pad.end) - float(pad.start)
				)
			):
				lane = float(pad.get("lateral", 0.0))
				best = ahead
				break
		for gate in action.get("gates", []):
			var ahead: float = fposmod(float(gate.distance) - here, game.track_length)
			if ahead < 20.0:
				lane = float(gate.lateral)
				break
	if (
		not PASSAGES.zone_at(game.world, here).is_empty()
		or PASSAGES.deck_half(game.world, here) > 0.0
	):
		lane = 0.0
	var wall: float = float(game._wall_lateral_at(here)) - 1.3
	return clampf(lane, -maxf(0.0, wall), maxf(0.0, wall))


func _race(track: String, difficulty: String, race_seed: int) -> Dictionary:
	events.clear()
	shot_index = 0
	game.race_seed = race_seed
	game._start_selected_race(
		{"mode": "race", "driver": "fox", "kart": "comet", "track": track, "difficulty": difficulty}
	)
	await process_frame
	game._end_preview()
	game.countdown = 0
	game.racing = true
	game.paused = false
	game.auto_gas = true
	var authored := _authored()
	var counters := _counters()
	var place: int = game._place()
	var last_here: float = fposmod(game.previous_road_distance, game.track_length)
	var air := 0.0
	var max_air := 0.0
	var hold := 0.0
	var armed_for := 0.0
	var lane_goal := 0.0
	var frames := 0
	var last_message := ""
	var messages: Array[Dictionary] = []
	var gaps: Array[Dictionary] = []
	var had_item := false
	var max_seconds: float = maxf(240.0, game.track_length * 2.0 / 14.0)
	while not game.finished and frames < int(max_seconds * 60.0):
		if frames % 6 == 0:
			lane_goal = _target_lane()
		var target: Vector3 = game.world.position_at(game.previous_road_distance + 9.0, lane_goal)
		var direction: Vector3 = target - game.player.position
		var heading: float = atan2(-direction.x, -direction.z)
		game.steering = clampf(-angle_difference(game.player_heading, heading) * 2.3, -1, 1)
		if str(game.item).is_empty():
			hold = 0.0
			armed_for = 0.0
		elif game.item_roulette_time <= 0.0:
			hold += STEP
			if str(game.item) == ROCKET and game.rocket_phase == "armed":
				armed_for += STEP
				if game.lock_progress >= 1.0 or armed_for > 3.0:
					game._use_item()
					armed_for = 0.0
			elif hold > 1.5:
				game._use_item()
				hold = 0.0
		game._physics_process(STEP)
		frames += 1
		# Streckenelemente überfahren (Vorwärtsfahrt, Rundenwechsel, keine Rücksetz-Sprünge).
		var here: float = fposmod(game.previous_road_distance, game.track_length)
		var moved: float = fposmod(here - last_here, game.track_length)
		if moved > 0.0 and moved < 30.0:
			for element in authored:
				var ahead: float = fposmod(float(element.d) - last_here, game.track_length)
				if ahead > 0.0 and ahead <= moved:
					_event(str(element.kind), str(element.name), "strecke")
		last_here = here
		if game.airborne:
			air += STEP
		else:
			if air >= MIN_AIR:
				_event("sprung", "%.2fs" % air, "strecke")
			max_air = maxf(max_air, air)
			air = 0.0
		var now_counters := _counters()
		for key in now_counters.keys():
			if int(now_counters[key]) > int(counters[key]):
				_event(
					key,
					"",
					(
						"strecke"
						if (
							key
							in [
								"looping",
								"ring",
								"lasso_reaktion",
								"turbo_ausgeloest",
								"slalom_geschafft"
							]
						)
						else "rennen"
					)
				)
		counters = now_counters
		var has_item := not str(game.item).is_empty()
		if has_item and not had_item:
			_event("item", str(game.item), "rennen")
		had_item = has_item
		var now_place: int = game._place()
		if now_place != place and game.elapsed > 1.0:
			_event(
				"ueberholt" if now_place < place else "ueberholt_worden",
				"%d->%d" % [place, now_place],
				"rennen"
			)
		place = now_place
		var text: String = str(game.message.text) if is_instance_valid(game.message) else ""
		if text != last_message and not text.is_empty():
			messages.append({"t": snappedf(game.elapsed, 0.1), "text": text})
		last_message = text
		if frames % 60 == 0:
			var ahead := INF
			var behind := INF
			for i in range(game.opponents.size()):
				var gap: float = float(game.opponent_distances[i]) - float(game.distance)
				if gap >= 0.0:
					ahead = minf(ahead, gap)
				else:
					behind = minf(behind, -gap)
			(
				gaps
				. append(
					{
						"t": snappedf(game.elapsed, 0.1),
						"place": now_place,
						"speed": snappedf(game.speed, 0.1),
						"ahead": -1.0 if ahead == INF else snappedf(ahead, 0.1),
						"behind": -1.0 if behind == INF else snappedf(behind, 0.1),
						"d": snappedf(here, 1.0),
					}
				)
			)
		if not capture_dir.is_empty():
			if shot_index >= shots.size() and _arg("stop-after-shots", "") == "1":
				break
			if shot_index < shots.size() and game.elapsed >= shots[shot_index]:
				await _capture(
					"%s_%s_%02d_%03ds" % [track, difficulty, shot_index, int(shots[shot_index])]
				)
				shot_index += 1
			elif shot_index < shots.size() and game.elapsed > shots[shot_index] - 0.6:
				await process_frame
			elif frames % 240 == 0:
				await process_frame
		elif frames % 240 == 0:
			await process_frame
	if not capture_dir.is_empty() and game.finished:
		for _i in range(90):
			game._physics_process(STEP)
			if _i % 3 == 0:
				await process_frame
		await _capture("%s_%s_99_ziel" % [track, difficulty])
	return _summary(track, difficulty, race_seed, authored, messages, gaps, max_air)


func _capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	if image.get_width() > 1200:
		image.resize(image.get_width() / 2, image.get_height() / 2, Image.INTERPOLATE_BILINEAR)
	image.save_jpg(capture_dir.path_join(name + ".jpg"), 0.8)
	print(
		"[FunSurvey] SHOT ",
		name,
		" t=",
		snappedf(game.elapsed, 0.1),
		" d=",
		snappedf(game.previous_road_distance, 1.0)
	)


func _gap_stats(times: Array, start_t: float, end_t: float) -> Dictionary:
	var longest := 0.0
	var at := start_t
	var previous := start_t
	for t in times:
		if float(t) - previous > longest:
			longest = float(t) - previous
			at = previous
		previous = float(t)
	if end_t - previous > longest:
		longest = end_t - previous
		at = previous
	return {"longest": snappedf(longest, 0.1), "from": snappedf(at, 0.1)}


func _summary(
	track: String,
	difficulty: String,
	race_seed: int,
	authored: Array,
	messages: Array,
	gaps: Array,
	max_air: float
) -> Dictionary:
	var end_t: float = game.elapsed
	var all_t: Array = []
	var track_t: Array = []
	var high_t: Array = []
	var high_per_lap: Array = [0, 0]
	var kinds_per_lap: Dictionary = {}
	for e in events:
		if str(e.kind) != "attrappe":
			all_t.append(float(e.t))
		if str(e.kind) == "attrappe":
			continue
		if str(e.group) == "strecke":
			track_t.append(float(e.t))
		if str(e.kind) in HIGHLIGHTS and str(e.kind) != "sprung":
			high_t.append(float(e.t))
			if int(e.lap) < 2:
				high_per_lap[int(e.lap)] += 1
		var key := str(int(e.lap))
		if not kinds_per_lap.has(key):
			kinds_per_lap[key] = {}
		kinds_per_lap[key][str(e.kind)] = int(kinds_per_lap[key].get(str(e.kind), 0)) + 1
	var gap_all := _gap_stats(all_t, 0.0, end_t)
	var gap_track := _gap_stats(track_t, 0.0, end_t)
	var gap_high := _gap_stats(high_t, 0.0, end_t)
	var gap_track_d := -1.0
	for e in events:
		if str(e.group) == "strecke" and float(e.t) >= float(gap_track.from) - 0.001:
			gap_track_d = float(e.d)
			break
	var from_d := 0.0
	for g in gaps:
		if float(g.t) >= float(gap_track.from):
			from_d = float(g.d)
			break
	var overtakes := 0
	var lost := 0
	for e in events:
		if str(e.kind) == "ueberholt":
			overtakes += 1
		elif str(e.kind) == "ueberholt_worden":
			lost += 1
	var ahead_sum := 0.0
	var ahead_n := 0
	var close := 0
	for g in gaps:
		if float(g.ahead) >= 0.0:
			ahead_sum += float(g.ahead)
			ahead_n += 1
		if (
			(float(g.ahead) >= 0.0 and float(g.ahead) < 15.0)
			or (float(g.behind) >= 0.0 and float(g.behind) < 15.0)
		):
			close += 1
	return {
		"track": track,
		"difficulty": difficulty,
		"seed": race_seed,
		"length_m": roundi(game.track_length),
		"finished": bool(game.finished),
		"seconds": snappedf(end_t, 0.1),
		"lap_times": game.lap_times.duplicate(),
		"place": int(game.result_payload.get("place", game._place())),
		"first_event_s": snappedf(float(all_t[0]) if not all_t.is_empty() else -1.0, 0.1),
		"first_track_event_s": snappedf(float(track_t[0]) if not track_t.is_empty() else -1.0, 0.1),
		"longest_gap_all_s": gap_all.longest,
		"longest_gap_all_from_s": gap_all.from,
		"longest_gap_track_s": gap_track.longest,
		"longest_gap_track_from_s": gap_track.from,
		"longest_gap_track_from_d": from_d,
		"longest_gap_track_until_d": gap_track_d,
		"first_highlight_s": snappedf(float(high_t[0]) if not high_t.is_empty() else -1.0, 0.1),
		"longest_gap_highlight_s": gap_high.longest,
		"longest_gap_highlight_from_s": gap_high.from,
		"highlights_per_lap": high_per_lap,
		"kinds_per_lap": kinds_per_lap,
		"distinct_kinds_lap":
		[
			(kinds_per_lap.get("0", {}) as Dictionary).size(),
			(kinds_per_lap.get("1", {}) as Dictionary).size()
		],
		"overtakes": overtakes,
		"places_lost": lost,
		"mean_gap_ahead_m": snappedf(ahead_sum / maxf(1.0, float(ahead_n)), 0.1),
		"close_seconds": close,
		"resets": int(game.reset_count),
		"falls": int(game.passage_falls) + int(game.gap_falls) + int(game.action_edge_falls),
		"max_air_s": snappedf(max_air, 0.01),
		"wall_contacts": int(game.wall_contacts),
		"authored": authored,
		"events": events.duplicate(true),
		"messages": messages,
		"gaps": gaps,
	}
