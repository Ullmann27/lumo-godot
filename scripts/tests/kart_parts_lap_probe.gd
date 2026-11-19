extends SceneTree
## Messgeschirr „Fairness-Grenze der Leistungsteile“: echtes Zeitfahren (keine Rivalen,
## keine Aufholhilfe, keine Items) mit dem Kind-Fahrer aus kart_rival_fairness_probe.gd,
## fester 60-Hz-Takt. Je Teile-Satz eine Zeile: Runden, Gesamtzeit, Höchsttempo, Rücksetzer,
## Landungen. Fahrer „kind“ driftet nie, „drift“ driftet in längeren Kurven.
## Aufruf: --script res://scripts/tests/kart_parts_lap_probe.gd -- --track=sonnenhafen
##   --kart=comet --driver=kind --sets="serie;engine=dauer,wing=flach;…" --out=/abs/datei.jsonl
const RACECRAFT = preload("res://scripts/games/kart_rival_racecraft.gd")
const STEP := 1.0 / 60.0
const REACTION_FRAMES := 11
const THUMB_RATE := 5.0
const MAX_FRAMES := 36000

var game
var track: String = "sonnenhafen"
var kart: String = "comet"
var driver: String = "kind"
var sets: Array[Dictionary] = [{}]
var out_path: String = ""


func _initialize() -> void:
	call_deferred("_run")


func _parse_args() -> void:
	for argument in OS.get_cmdline_user_args():
		var text: String = str(argument)
		if text.begins_with("--track="):
			track = text.trim_prefix("--track=")
		elif text.begins_with("--kart="):
			kart = text.trim_prefix("--kart=")
		elif text.begins_with("--driver="):
			driver = text.trim_prefix("--driver=")
		elif text.begins_with("--out="):
			out_path = text.trim_prefix("--out=")
		elif text.begins_with("--sets="):
			sets.clear()
			for chunk in text.trim_prefix("--sets=").split(";", false):
				var parts: Dictionary = {}
				for pair in chunk.split(",", false):
					var kv: PackedStringArray = pair.split("=")
					if kv.size() == 2:
						parts[kv[0]] = kv[1]
				sets.append(parts)


func _run() -> void:
	_parse_args()
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	await process_frame
	await process_frame
	var workshop = game._ensure_workshop()
	workshop.save_enabled = false
	var unfinished := 0
	for parts in sets:
		var row: Dictionary = await _lap(workshop, parts)
		if not bool(row.finished):
			unfinished += 1
		_write(row)
		print(
			(
				"[PartsLap] %s %s %s %s time=%.2f laps=%s top=%.1f resets=%d walls=%d"
				% [
					track,
					kart,
					driver,
					_label(parts),
					float(row.time),
					str(row.laps),
					float(row.top_kmh),
					int(row.resets),
					int(row.walls)
				]
			)
		)
	game.abandoned = true
	game.queue_free()
	await process_frame
	await create_timer(0.4).timeout
	print("[PartsLap] DONE sets=%d unfinished=%d" % [sets.size(), unfinished])
	quit(0 if unfinished == 0 else 1)


func _label(parts: Dictionary) -> String:
	if parts.is_empty():
		return "serie"
	var keys: Array = parts.keys()
	keys.sort()
	var text: PackedStringArray = []
	for key in keys:
		text.append("%s=%s" % [key, parts[key]])
	return ",".join(text)


func _lap(workshop, parts: Dictionary) -> Dictionary:
	workshop.looks.erase(kart)
	workshop.owned.clear()
	for slot in parts:
		workshop.owned.append("%s:%s" % [slot, parts[slot]])
		workshop.choose(kart, str(slot), str(parts[slot]))
	game.race_seed = 7
	game._start_selected_race(
		{"mode": "time_trial", "driver": "fox", "kart": kart, "track": track, "difficulty": "flott"}
	)
	await process_frame
	game._refresh_kart_factors()
	game.countdown = 0.0
	game.racing = true
	game.auto_gas = false
	game.gas_held = true
	var length: float = float(game.track_length)
	var buffer: Array[float] = []
	var axis: float = 0.0
	var t: float = 0.0
	var frames: int = 0
	var top: float = 0.0
	var laps: Array[float] = []
	while not game.finished and frames < MAX_FRAMES:
		var road_d: float = float(game.previous_road_distance)
		var speed: float = float(game.speed)
		var look: float = clampf(absf(speed) * 0.6, 7.0, 26.0)
		var aim: Vector3 = game.world.position_at(road_d + look, sin(t * 0.23 + 0.7) * 0.9)
		var to_aim: Vector3 = aim - game.player.position
		var wanted: float = atan2(-to_aim.x, -to_aim.z)
		var command: float = clampf(
			-angle_difference(game.player_heading, wanted) * 1.4 + sin(t * 1.7) * 0.06, -1.0, 1.0
		)
		buffer.append(command)
		var delayed: float = buffer[0] if buffer.size() > REACTION_FRAMES else 0.0
		if buffer.size() > REACTION_FRAMES:
			buffer.pop_front()
		var bend: float = absf(RACECRAFT.curvature(game.world, road_d))
		var capacity: float = 1.42 * float(game._factor("turn")) * 2.0
		var brake: float = 0.0
		if speed > 14.0 and bend * speed > capacity * 0.8:
			brake = 0.35
		if driver == "drift" and not bool(game.airborne):
			if not game.drifting and bend > 0.012 and speed > 20.0:
				game._press_drift()
			elif game.drifting and bend < 0.006:
				game._release_drift()
		axis = move_toward(axis, delayed, THUMB_RATE * STEP)
		game.steering = axis
		game.brake = brake
		game.gas_held = true
		game._physics_process(STEP)
		t += STEP
		frames += 1
		top = maxf(top, float(game.speed))
		while laps.size() < int(float(game.distance) / length) and laps.size() < 2:
			laps.append(snappedf(t, 0.01))
	return {
		"track": track,
		"kart": kart,
		"driver": driver,
		"parts": _label(parts),
		"finished": bool(game.finished),
		"time": snappedf(t, 0.01),
		"laps": laps,
		"top_kmh": snappedf(top * 3.6, 0.1),
		"resets": int(game.reset_count),
		"walls": int(game.wall_contacts),
		"landings": int(game.landing_count),
	}


func _write(row: Dictionary) -> void:
	if out_path.is_empty():
		return
	var file := FileAccess.open(out_path, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(out_path, FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	file.store_line(JSON.stringify(row))
	file.close()
