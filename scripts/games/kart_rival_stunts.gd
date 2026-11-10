extends RefCounted
## Rivals ride the same contact path, gravity and speed integration as the player.
## Each kart owns its transient loop state, so changing races cannot reuse it.
const LOOP = preload("res://scripts/games/kart_physical_loop.gd")
const STATE_KEY: StringName = &"lumo_physical_loop"


static func save_positions(game, config: ConfigFile) -> void:
	var positions: Array[Vector3] = []
	var distances: Array = game.opponent_distances.duplicate()
	var lanes: Array = game.opponent_lanes.duplicate()
	var headings: Array = game.opponent_headings.duplicate()
	for index in range(game.opponents.size()):
		var rival = game.opponents[index]
		var state = rival.get_meta(STATE_KEY) if rival.has_meta(STATE_KEY) else null
		if state != null and state.active:
			# Match the player's safe interrupted-loop policy. A snapshot must not
			# reload a floating kart without its contact solver or award a shortcut.
			var start: float = float(state.layout.start)
			lanes[index] = float(state.layout.lane) + state.lateral
			distances[index] = state.entry_progress
			headings[index] = game._heading(start)
			positions.append(game.world.reset_transform(start, lanes[index]).origin)
		else:
			positions.append(rival.position)
	config.set_value("race", "opponent_positions", positions)
	config.set_value("race", "opponent_distances", distances)
	config.set_value("race", "opponent_lanes", lanes)
	config.set_value("race", "opponent_headings", headings)


static func planned_loop_lane(game, index: int, at: float, fallback: float) -> float:
	var layout: Dictionary = game.world.loop_layout
	if layout.is_empty() or not bool(layout.get("stunt", false)):
		return fallback
	# Two adventurous personalities take the optional stunt route. Beginners
	# keep the easy lane; no rival is teleported into the loop to force a result.
	if game.difficulty == "gemuetlich" or index % 2 == 0:
		return fallback
	var lead: float = float(layout.start) - at
	# Line up before the preceding panorama ramp. Its airborne controller
	# preserves the launch lane; waiting until 55m before the loop leaves fast
	# rivals too little grounded road to cross from the far left after landing.
	return float(layout.lane) if lead >= -2.0 and lead <= 110.0 else fallback


static func update_loop(game, index: int, delta: float) -> bool:
	var layout: Dictionary = game.world.loop_layout
	if layout.is_empty():
		return false
	var rival = game.opponents[index]
	var state = rival.get_meta(STATE_KEY) if rival.has_meta(STATE_KEY) else null
	if state == null or not state.active:
		var local: float = fposmod(game.opponent_distances[index], game.track_length)
		var offset: float = local - float(layout.start)
		if offset < 0.0 or offset > maxf(1.6, float(rival.motion_speed) * delta + 0.2):
			return false
		var road: Dictionary = game.world.sample_road(rival.position, local)
		var lane_offset: float = float(road.lateral) - float(layout.lane)
		if absf(lane_offset) > float(layout.get("lane_tolerance", 0.9)):
			return false
		if float(rival.motion_speed) < float(layout.get("min_entry_speed", 16.0)):
			return false
		state = LOOP.new()
		# Attaching to the ring ends a road drift; its partial charge cannot be
		# cashed in after the stunt by the independent racecraft controller.
		rival.set_meta(&"racecraft_drift_charge", 0.0)
		state.enter(
			layout,
			float(rival.motion_speed),
			game.opponent_distances[index] - offset,
			lane_offset,
			offset
		)
		rival.set_meta(STATE_KEY, state)
	game._update_rival_item_tactics(index, game.player.position - rival.position, delta)
	game.opponent_stuns[index] = maxf(0.0, game.opponent_stuns[index] - delta)
	var braking: float = 0.25 if game.opponent_stuns[index] > 0.0 else 0.0
	rival.transform = state.advance(game.world, delta, 0.0, braking, true)
	game.opponent_distances[index] = maxf(
		game.opponent_distances[index], state.entry_progress + state.progress * LOOP.ADVANCE
	)
	game.opponent_lanes[index] = float(layout.lane) + state.lateral
	rival.set_motion(state.speed, 0.0, false, false)
	if not state.active:
		var exit_distance: float = float(layout.start) + (0.0 if state.failed else LOOP.ADVANCE)
		var exit_lane: float = (
			float(layout.get("fail_lane", 0.0))
			if state.failed
			else float(layout.lane) + state.lateral
		)
		game.opponent_distances[index] = (
			state.entry_progress + (0.0 if state.failed else LOOP.ADVANCE)
		)
		game.opponent_headings[index] = game._heading(exit_distance)
		game.opponent_lanes[index] = exit_lane
		rival.transform = game.world.reset_transform(exit_distance, exit_lane)
		if not state.failed:
			rival.set_meta(
				&"lumo_completed_loops", int(rival.get_meta(&"lumo_completed_loops", 0)) + 1
			)
			game.opponent_boost_times[index] = maxf(game.opponent_boost_times[index], 1.5)
		else:
			rival.set_motion(8.0, 0.0, false, false)
	return true
