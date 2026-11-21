extends RefCounted
## Streckenprofil (Messwerkzeug + Grundlage von kart_track_excitement_regression):
## fährt eine Strecke mit dem Mittellinien-Fahrer zwei Runden durch die echte Rennphysik
## und misst Höhenverlauf, Kurvenfolge, längste ereignislose Phase, Sprünge, Entscheidungen,
## Überholstellen und Tempo-Schwankung. Alle Werte sind Container-Messungen.
##
## „Ereignis“ (für die ereignislose Phase, gemessen in Runde 2):
##   Gierrate des Karts >= YAW_EVENT_DEG_S, Flug, spürbare Steigung/Gefälle
##   (|Höhenänderung| >= VERTICAL_EVENT_M_S), Turbo-Feld, Slalomtor, Schanze, Item-Ring/-Box,
##   LUMO-Passage, Spannungsstelle (kart_track_thrills) oder Fahrspaß-Höhepunkt
##   (kart_track_highlights) innerhalb EVENT_WINDOW_M.

const PASSAGES = preload("res://scripts/games/kart_passages.gd")
const DRAMA = preload("res://scripts/games/kart_adventure_drama.gd")
const THRILLS = preload("res://scripts/games/kart_track_thrills.gd")
const STEP: float = 1.0 / 60.0
const YAW_EVENT_DEG_S: float = 22.0
const VERTICAL_EVENT_M_S: float = 3.0
const EVENT_WINDOW_M: float = 12.0
const DECISION_KINDS: Array[String] = ["gate", "swing", "bridge"]
## Offene Kante (Leitplanke fehlt, Sturz möglich) zählt wie im Fahrspaß-Messwerkzeug
## (kart_track_fun_survey „kante“) als markante Stelle.
const HIGHLIGHT_PREFIXES: Array[String] = [
	"air", "kicker", "passage", "thrill", "highlight", "jump", "gate", "dive", "loop", "edge"
]
## Plan der Fahrspaß-Höhepunkte (kart_track_highlights.gd META).
const HIGHLIGHT_META: String = "highlight_plan"


## Static element positions along the finished road (local lap distance).
static func static_events(game) -> Array:
	var world = game.world
	var length: float = float(world.length)
	var events: Array = []
	var action: Dictionary = world.action
	for pad in action.get("pads", []):
		events.append({"kind": "pad", "start": float(pad.start), "end": float(pad.end)})
	for fraction in DRAMA.turbo_fractions(str(world.track_id)):
		var at: float = THRILLS.clear_distance(
			world, PASSAGES.clear_distance(world, float(fraction) * length)
		)
		events.append({"kind": "pad", "start": at, "end": at + 2.6})
	for gate in action.get("gates", []):
		events.append({"kind": "gate", "start": float(gate.distance), "end": float(gate.distance)})
	for kicker in action.get("kickers", []):
		events.append(
			{"kind": "kicker", "start": float(kicker.start), "end": float(kicker.take_off) + 20.0}
		)
	for dive in action.get("dives", []):
		events.append({"kind": "dive", "start": float(dive.start), "end": float(dive.end)})
	for edge in action.get("edges", []):
		events.append({"kind": "edge", "start": float(edge.start), "end": float(edge.end)})
	for d in game.item_box_distances:
		events.append({"kind": "item", "start": float(d), "end": float(d)})
	for d in game.catalog_box_distances:
		events.append({"kind": "item", "start": float(d), "end": float(d)})
	for entry in PASSAGES.of(world):
		if entry.has("zone_start"):
			events.append(
				{
					"kind": "passage:" + str(entry.kind),
					"start": float(entry.zone_start),
					"end": float(entry.zone_end),
					"id": str(entry.id)
				}
			)
		elif entry.has("start") and entry.has("end"):
			events.append(
				{
					"kind": "passage:" + str(entry.kind),
					"start": float(entry.start),
					"end": float(entry.end),
					"id": str(entry.id)
				}
			)
	for thrill in THRILLS.of(world):
		events.append(
			{
				"kind": "thrill:" + str(thrill.kind),
				"start": float(thrill.start),
				"end": float(thrill.end),
				"id": str(thrill.id)
			}
		)
	for entry in world.get_meta(HIGHLIGHT_META, []):
		events.append(
			{
				"kind": "highlight:" + str(entry.kind),
				"start": float(entry.start),
				"end": float(entry.end),
				"id": str(entry.id)
			}
		)
	if not world.loop_layout.is_empty():
		var loop_start: float = float(world.loop_layout.start)
		events.append({"kind": "loop", "start": loop_start, "end": loop_start + 70.0})
	if not world.jump.is_empty():
		events.append(
			{
				"kind": "jump",
				"start": float(world.jump.ramp_start),
				"end": float(world.jump.gap_end)
			}
		)
	return events


## Kind of the element near d; highlights (flight, passage, Spannungsstelle …) win over
## routine elements (turbo field, item ring) so the highlight gap is measured honestly.
static func near_event(events: Array, d: float, length: float) -> String:
	var found: String = ""
	for event in events:
		var a: float = float(event.start) - EVENT_WINDOW_M
		var b: float = float(event.end) + EVENT_WINDOW_M
		for shift in [0.0, length, -length]:
			if d + shift >= a and d + shift <= b:
				if is_highlight(str(event.kind)):
					return str(event.kind)
				found = str(event.kind)
	return found


static func is_highlight(kind: String) -> bool:
	for prefix in HIGHLIGHT_PREFIXES:
		if kind.begins_with(prefix):
			return true
	return false


## Geometry of the finished road: heights, crests, corners and straights.
static func geometry(world) -> Dictionary:
	var length: float = float(world.length)
	var step: float = 5.0
	var count: int = int(length / step)
	var heights := PackedFloat32Array()
	var headings := PackedFloat32Array()
	for i in range(count):
		var d: float = float(i) * step
		var p: Vector3 = world.position_at(d)
		heights.append(p.y)
		var f: Vector3 = world.forward(d)
		headings.append(atan2(f.x, f.z))
	var climb: float = 0.0
	var steepest: float = 0.0
	for i in range(count):
		var dy: float = heights[(i + 1) % count] - heights[i]
		climb += maxf(0.0, dy)
		steepest = maxf(steepest, absf(dy) / step)
	# Crests: local maxima over +-40 m with at least 2.5 m prominence on both sides.
	var crests: Array = []
	for i in range(count):
		var h: float = heights[i]
		var is_max: bool = true
		var low_before: float = h
		var low_after: float = h
		for k in range(1, 9):
			low_before = minf(low_before, heights[posmod(i - k, count)])
			low_after = minf(low_after, heights[(i + k) % count])
			if heights[posmod(i - k, count)] > h or heights[(i + k) % count] > h:
				is_max = false
		if is_max and h - low_before >= 2.5 and h - low_after >= 2.5:
			crests.append(float(i) * step)
	# Corners: heading change per metre over a 30 m window.
	var turn := PackedFloat32Array()
	for i in range(count):
		turn.append(angle_difference(headings[i], headings[(i + 6) % count]) / (6.0 * step))
	var corners: Array = []
	var straights: Array = []
	var i0: int = -1
	var run: int = 0
	for i in range(count + 1):
		var rate: float = absf(turn[i % count])
		if rate < deg_to_rad(0.22):
			run += 1
		else:
			if run * step >= 100.0:
				straights.append(run * step)
			run = 0
		var cornering: bool = rate >= deg_to_rad(0.9)
		if cornering and i0 < 0:
			i0 = i
		elif not cornering and i0 >= 0:
			var total: float = 0.0
			var tightest: float = 0.0
			for k in range(i0, i):
				total += turn[k % count] * step
				tightest = maxf(tightest, absf(turn[k % count]))
			if absf(total) >= deg_to_rad(35.0):
				corners.append(
					{
						"at": float(i0) * step,
						"deg": rad_to_deg(total),
						"radius": 1.0 / maxf(tightest, 0.0001)
					}
				)
			i0 = -1
	var direction_changes: int = 0
	for k in range(1, corners.size()):
		if signf(float(corners[k].deg)) != signf(float(corners[k - 1].deg)):
			direction_changes += 1
	var samples: Array = []
	for i in range(count):
		var q: Vector3 = world.position_at(float(i) * step)
		samples.append([snappedf(q.x, 0.01), snappedf(q.y, 0.01), snappedf(q.z, 0.01)])
	return {
		"samples": samples,
		"length": length,
		"height_min": Array(heights).min(),
		"height_max": Array(heights).max(),
		"climb": climb,
		"steepest_pct": steepest * 100.0,
		"crests": crests,
		"corners": corners,
		"direction_changes": direction_changes,
		"straights": straights,
	}


## Drives the player two laps along the centre line; returns trace-derived metrics.
static func drive(tree: SceneTree, game, frame_limit: int = 14000) -> Dictionary:
	var events: Array = static_events(game)
	var length: float = float(game.track_length)
	var trace: Array = []
	var frames: int = 0
	var last_heading: float = game.player_heading
	var last_y: float = game.player.position.y
	var takeoffs: int = 0
	var air: float = 0.0
	var was_air: bool = false
	var lap2_start: float = -1.0
	var resets_before: int = game.reset_count
	# Saved preferences of earlier tests may hold "gas button" mode; the profile drives on Auto-Gas.
	game.auto_gas = true
	var rival_start: Array = game.opponent_distances.duplicate()
	var rival_mark: Array = game.opponent_distances.duplicate()
	var rival_stall: float = 0.0
	while not game.finished and frames < frame_limit:
		var lookahead: float = 9.0
		var target: Vector3 = game.world.position_at(
			game.previous_road_distance + lookahead,
			THRILLS.bot_lane(game.world, game.previous_road_distance)
		)
		var direction: Vector3 = target - game.player.position
		var heading: float = atan2(-direction.x, -direction.z)
		game.steering = clampf(-angle_difference(game.player_heading, heading) * 2.3, -1, 1)
		game._physics_process(STEP)
		frames += 1
		var yaw: float = (
			rad_to_deg(absf(angle_difference(last_heading, game.player_heading))) / STEP
		)
		var vy: float = (game.player.position.y - last_y) / STEP
		last_heading = game.player_heading
		last_y = game.player.position.y
		if game.airborne and not was_air:
			takeoffs += 1
		if game.airborne:
			air += STEP
		was_air = game.airborne
		if lap2_start < 0.0 and game.distance >= length:
			lap2_start = float(frames) * STEP
		var d: float = fposmod(game.previous_road_distance, length)
		var reason: String = ""
		var near: String = near_event(events, d, length)
		if game.airborne:
			reason = "air"
		elif yaw >= YAW_EVENT_DEG_S:
			reason = "yaw"
		elif absf(vy) >= VERTICAL_EVENT_M_S:
			reason = "hill"
		else:
			reason = near
		# Ein Höhepunkt zählt auch, wenn er in einer Kurve oder am Hang durchfahren wird
		# (vorher verdeckte „yaw“/„hill“ z. B. eine offene Kante in der Kurve).
		var highlight: bool = game.airborne or is_highlight(near)
		(
			trace
			. append(
				{
					"t": float(frames) * STEP,
					"d": d,
					"lap": int(game.distance / length),
					"speed": float(game.speed),
					"y": game.player.position.y,
					"event": reason,
					"highlight": highlight,
					"yaw": yaw,
				}
			)
		)
		if frames % 120 == 0:
			# Rival stall: the worst two-second progress of any rival (after the start phase).
			if frames > 240:
				for i in range(game.opponent_distances.size()):
					var moved: float = float(game.opponent_distances[i]) - float(rival_mark[i])
					if moved < 5.0:
						rival_stall += 2.0
			rival_mark = game.opponent_distances.duplicate()
			await tree.process_frame
	# Longest stretch without any event, lap 2 only (flying lap).
	var longest: float = 0.0
	var longest_at: float = 0.0
	var quiet_since: float = -1.0
	var quiet_from_d: float = 0.0
	var speeds: Array = []
	for row in trace:
		if int(row.lap) != 1:
			continue
		speeds.append(float(row.speed))
		if str(row.event) == "":
			if quiet_since < 0.0:
				quiet_since = float(row.t)
				quiet_from_d = float(row.d)
			elif float(row.t) - quiet_since > longest:
				longest = float(row.t) - quiet_since
				longest_at = quiet_from_d
		else:
			quiet_since = -1.0
	# Longest stretch without a highlight (flight, passage, Spannungsstelle, slalom …), lap 2.
	var gap: float = 0.0
	var gap_at: float = 0.0
	var gap_since: float = -1.0
	var gap_from: float = 0.0
	var highlights_lap2: int = 0
	var in_highlight: bool = false
	for row in trace:
		if int(row.lap) != 1:
			continue
		if not bool(row.highlight):
			in_highlight = false
			if gap_since < 0.0:
				gap_since = float(row.t)
				gap_from = float(row.d)
			elif float(row.t) - gap_since > gap:
				gap = float(row.t) - gap_since
				gap_at = gap_from
		else:
			if not in_highlight:
				highlights_lap2 += 1
			in_highlight = true
			gap_since = -1.0
	var mean: float = 0.0
	for s in speeds:
		mean += float(s)
	mean /= maxf(1.0, float(speeds.size()))
	var variance: float = 0.0
	for s in speeds:
		variance += pow(float(s) - mean, 2.0)
	variance /= maxf(1.0, float(speeds.size()))
	var compact: Array = []
	for k in range(0, trace.size(), 6):
		var row: Dictionary = trace[k]
		compact.append(
			[
				snappedf(row.t, 0.01),
				snappedf(row.d, 0.1),
				row.lap,
				snappedf(row.speed, 0.1),
				snappedf(row.y, 0.01),
				row.event,
				snappedf(row.yaw, 0.1)
			]
		)
	var rival_progress: Array = []
	for i in range(game.opponent_distances.size()):
		rival_progress.append(float(game.opponent_distances[i]) - float(rival_start[i]))
	var rival_rescues: int = 0
	for rival in game.opponents:
		rival_rescues += int(rival.get_meta(&"lumo_flight_rescues", 0))
	var decisions: int = 0
	for entry in PASSAGES.of(game.world):
		if str(entry.kind) in DECISION_KINDS:
			decisions += 1
	for thrill in THRILLS.of(game.world):
		if bool(thrill.get("decision", false)):
			decisions += 1
	# Risiko-Kante: außen mutig mit Turbo-Feldern an der offenen Kante oder innen sicher.
	for entry in game.world.get_meta(HIGHLIGHT_META, []):
		if str(entry.kind) == "risiko":
			decisions += 1
	if not game.world.loop_layout.is_empty():
		decisions += 1  # optional loop lane (kart_physical_loop): enter on the outer lane or not
	if str(game.world.track_id) == "bergwelt":
		decisions += 1  # split cloud bridge / island line (kart_sky_islands)
	return {
		"finished": bool(game.finished),
		"time": float(game.elapsed),
		"lap2_time": float(frames) * STEP - lap2_start if lap2_start > 0.0 else 0.0,
		"resets": int(game.reset_count) - resets_before,
		"longest_quiet_s": longest,
		"highlight_gap_s": gap,
		"highlight_gap_at": gap_at,
		"highlights": highlights_lap2,
		"longest_quiet_at": longest_at,
		"takeoffs": takeoffs,
		"air_s": air,
		"mean_speed": mean,
		"speed_cv": sqrt(variance) / maxf(0.1, mean),
		"decisions": decisions,
		"rival_progress": rival_progress,
		"rival_stall_s": rival_stall,
		"rival_rescues": rival_rescues,
		"gap_falls": int(game.gap_falls),
		"events": events.size(),
		"static_events": events,
		"trace": compact,
	}
