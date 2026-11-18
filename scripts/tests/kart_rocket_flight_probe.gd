extends SceneTree
## Befund-/Belegsonde für die Sternraketen im echten Rennen (Fahrerkamera). Kein Gate.
## Das Rennen läuft im echten 60-Hz-Takt (_physics_process), die Bildausgabe wird
## nachgestellt: Bild k erscheint zur Zeit k / fps (+ Taktzittern). Je Bild werden so viele
## Physiktakte gerechnet, wie bis dahin fällig sind – genau wie in Godot auf dem Gerät.
## Gemessen wird, wie weit die Rakete je Bild auf dem Bildschirm springt.
## Modi:
##   measure  – ohne Bilder (auch headless), schreibt JSON
##   frames   – Bildfolge (PNG, 1600x720) aus der Fahrerkamera, 60 Bilder/s; mit
##              --fixed-fps 60 starten, damit jedes Bild genau 1/60 s Spielzeit ist
## Aufruf: LUMO_ROCKET_DIR=/abs/dir godot --path . [--headless] \
##   --script res://scripts/tests/kart_rocket_flight_probe.gd -- measure|frames player|rival \
##   [reduced] [cadence=60|50|45|jitter|120cap] [smooth=off] [tag=name]
const TEARDOWN = preload("res://scripts/tests/helpers/kart_scene_teardown.gd")
const STEP: float = 1.0 / 60.0
const GAP: float = 30.0
## Bilder nach dem Treffer (Bilder nach dem Einschlag).
const POST_HIT: Array = [0, 8, 18, 30, 44, 62]
var game
var smoother
var destination: String = ""
var mode: String = "measure"
var scenario: String = "player"
var cadence: String = "60"
var tag: String = ""
var reduced: bool = false
var smooth: bool = true
var rows: Array = []
var saved: Array[String] = []
var ticks_done: int = 0
var rng := RandomNumberGenerator.new()


func _initialize() -> void:
	call_deferred("_run")


func _tick() -> void:
	if smoother != null:
		smoother.begin_tick()
	game._physics_process(STEP)
	if smoother != null:
		smoother.end_tick()
	ticks_done += 1


## Zeitpunkt (in Physiktakten) des k-ten Bildes für die gewählte Bildfolge.
func _frame_time(k: int) -> float:
	match cadence:
		"50":
			return k * 60.0 / 50.0
		"45":
			return k * 60.0 / 45.0
		"jitter":
			# 60 Bilder/s mit ±3 ms Zittern (Bildratenbremse auf 120-Hz-Anzeige).
			return k + rng.randf_range(-0.18, 0.18)
		"120cap":
			return k * 0.5
	return float(k)


func _present(frame_ticks: float) -> void:
	var due: int = maxi(ticks_done, int(floor(frame_ticks)))
	while ticks_done < due:
		_tick()
	if smoother != null:
		smoother.manual_fraction = clampf(frame_ticks - float(ticks_done), 0.0, 1.0)
		if mode == "frames":
			# Echtes Bild (mit --fixed-fps 60): Partikel, Glätter und Spur laufen selbst.
			return
		smoother._process(0.0)
	if mode == "frames":
		return
	var flight = game.get("rocket_flight")
	if flight != null and is_instance_valid(flight):
		flight._process(
			STEP * (60.0 / 50.0 if cadence == "50" else 60.0 / 45.0 if cadence == "45" else 1.0)
		)


func _rocket() -> Node3D:
	if not is_instance_valid(game.item_runtime):
		return null
	for entry in game.item_runtime.projectiles:
		if str(entry.kind) == "homing" and is_instance_valid(entry.node):
			return entry.node
	return null


func _target() -> Node3D:
	return game.player if scenario == "rival" else game.opponents[0]


func _record(label: String, frame: int, tick_count: int) -> Dictionary:
	var rocket: Node3D = _rocket()
	var cam: Camera3D = game.camera
	var row := {"frame": frame, "label": label, "ticks": tick_count}
	var target: Node3D = _target()
	var road_d: float = float(game.distance if scenario == "rival" else game.opponent_distances[0])
	var road_lane: float = float(game.lane if scenario == "rival" else game.opponent_lanes[0])
	row["target_lift"] = snappedf(
		target.global_position.y - game._track_position(road_d, road_lane).y, 0.001
	)
	row["target_on_screen"] = cam.is_position_in_frustum(target.global_position + Vector3.UP * 0.6)
	var flight = game.get("rocket_flight")
	if flight != null and is_instance_valid(flight):
		row["display_lift"] = snappedf(flight.tumble_lift(-1 if scenario == "rival" else 0), 0.001)
		row["trail_points"] = flight.trail_point_total()
		row["pip"] = flight.pip_visible()
		row["assist"] = snappedf(flight.assist, 0.01)
	if rocket != null and rocket.is_inside_tree():
		var p: Vector3 = rocket.global_position
		row["rocket"] = [snappedf(p.x, 0.001), snappedf(p.y, 0.001), snappedf(p.z, 0.001)]
		row["on_screen"] = cam.is_position_in_frustum(p)
		var s: Vector2 = (
			cam.unproject_position(p) if not cam.is_position_behind(p) else Vector2(-1, -1)
		)
		row["screen"] = [snappedf(s.x, 0.1), snappedf(s.y, 0.1)]
		row["cam_dist"] = snappedf(cam.global_position.distance_to(p), 0.01)
		row["to_target"] = snappedf(p.distance_to(target.global_position), 0.01)
		# Dieselbe Szene ohne Glättung: Lage nach dem letzten Physiktakt (wie vorher).
		var raw_rocket: Variant = _raw_global(rocket)
		var raw_cam: Variant = _raw_global(cam)
		if raw_rocket is Transform3D and raw_cam is Transform3D:
			var shown_cam: Transform3D = cam.global_transform
			cam.global_transform = raw_cam
			var rp: Vector3 = (raw_rocket as Transform3D).origin
			var rs: Vector2 = (
				cam.unproject_position(rp) if not cam.is_position_behind(rp) else Vector2(-1, -1)
			)
			cam.global_transform = shown_cam
			row["raw_rocket"] = [
				snappedf(rp.x, 0.001), snappedf(rp.y, 0.001), snappedf(rp.z, 0.001)
			]
			row["raw_screen"] = [snappedf(rs.x, 0.1), snappedf(rs.y, 0.1)]
	var particles: int = 0
	for child in game.item_runtime.find_children("*", "CPUParticles3D", true, false):
		if (child as CPUParticles3D).emitting:
			particles += (child as CPUParticles3D).amount
	row["runtime_particles"] = particles
	row["player_speed"] = snappedf(float(game.speed), 0.01)
	row["spin"] = snappedf(
		float(game.player_spin_time) if scenario == "rival" else float(game.opponent_spin_times[0]),
		0.001
	)
	row["laps"] = [game.checkpoint_index, snappedf(float(game.distance), 0.01)]
	return row


func _raw_global(node: Node3D) -> Variant:
	if smoother == null or not smoother._entries.has(node.get_instance_id()):
		return null
	var local: Transform3D = smoother._entries[node.get_instance_id()].curr
	var parent := node.get_parent() as Node3D
	return parent.global_transform * local if parent != null else local


func _shot(name: String) -> void:
	RenderingServer.render_loop_enabled = true
	await process_frame
	await RenderingServer.frame_post_draw
	var file := destination.path_join("%s.png" % name)
	if root.get_texture().get_image().save_png(file) == OK:
		saved.append(file)
	RenderingServer.render_loop_enabled = false


func _run() -> void:
	destination = OS.get_environment("LUMO_ROCKET_DIR")
	if destination.is_empty():
		printerr("[RocketProbe] braucht LUMO_ROCKET_DIR")
		quit(1)
		return
	rng.seed = 20261118
	for argument in OS.get_cmdline_user_args():
		if argument in ["measure", "frames"]:
			mode = argument
		elif argument in ["player", "rival"]:
			scenario = argument
		elif argument == "reduced":
			reduced = true
		elif argument.begins_with("cadence="):
			cadence = argument.substr(8)
		elif argument == "smooth=off":
			smooth = false
		elif argument.begins_with("tag="):
			tag = argument.substr(4)
	if mode == "frames" and DisplayServer.get_name() == "headless":
		printerr("[RocketProbe] frames braucht ein Fenster")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(destination)
	var window_size := Vector2i(1600, 720)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size(window_size)
	root.size = window_size
	DirAccess.remove_absolute("user://kart_item_hints.cfg")
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.lightweight = false
	game.graphics_profile = "medium"
	game.reduced_motion = reduced
	await process_frame
	await process_frame
	game._start_selected_race(
		{
			"mode": "race",
			"driver": "fox",
			"kart": "comet",
			"track": "sonnenhafen",
			"difficulty": "gemuetlich"
		}
	)
	game._end_preview()
	game.set_physics_process(false)
	await process_frame
	game.countdown = 0.0
	game.racing = true
	game.auto_gas = true
	game.message.text = ""
	smoother = game.get("frame_smoother")
	if smoother != null:
		smoother.manual = true
		smoother.enabled = smooth
	RenderingServer.render_loop_enabled = mode != "frames"
	# Anfahren, bis das Kart Renntempo hat.
	for i in range(300):
		_tick()
		if i % 30 == 0:
			await process_frame
	var d: float = float(game.distance)
	for i in range(game.opponents.size()):
		var od: float = d - 60.0 - i * 6.0
		if i == 0:
			od = d + GAP if scenario == "player" else d - 24.0
		var od_lane: float = float(game.lane) if i == 0 else 3.0
		game.opponents[i].transform = game.world.reset_transform(od, od_lane)
		game.opponent_distances[i] = od
		game.opponent_lanes[i] = od_lane
		game.opponent_headings[i] = game._heading(od)
		game.opponents[i].motion_speed = float(game.speed) * (0.85 if i == 0 else 0.5)
		# Befund ohne Zufall: niemand hält gerade ein Item oder einen Schild.
		game.opponent_items[i] = ""
		game.opponent_item_cooldowns[i] = 30.0
		game.opponent_shield_times[i] = 0.0
		game.opponent_aurora_times[i] = 0.0
		game.opponent_grace_times[i] = 0.0
	for _i in range(4):
		_tick()
	await process_frame
	if scenario == "player":
		game._grant_item("star_rocket")
		game.item_hint = ""
		game._use_item()
		var guard: int = 0
		while game.lock_progress < 0.6 and guard < 240:
			_tick()
			guard += 1
		game._use_item()
	else:
		game.item = ""
		game.shield_time = 0.0
		game.player_grace_time = 0.0
		game.opponent_items[0] = "star_rocket"
		game.opponent_item_charges[0] = 2
		game.opponent_rocket_hold[0] = 99.0
		game.opponent_item_cooldowns[0] = 0.0
		var guard_rival: int = 0
		while _rocket() == null and guard_rival < 600:
			_tick()
			guard_rival += 1
		# Das Kind rollt aus (z. B. nach einem Rempler): erst dann holt die Rakete es ein.
		game.auto_gas = false
		game.speed = minf(float(game.speed), 16.0)
	var start_ticks: int = ticks_done
	var shot_at: Array = [1, 8, 20, 38, 70, 110, 170, 240, 320, 380]
	var post_index: int = -1
	var hit_frame: int = -1
	var frame: int = 0
	var landed_frame: int = -1
	var last_ticks: int = ticks_done
	var tick_offset: float = float(ticks_done)
	while frame < 400:
		frame += 1
		await _present_async(tick_offset + _frame_time(frame))
		var spinning: bool = (
			game.player_spin_time > 0.0
			if scenario == "rival"
			else game.opponent_spin_times[0] > 0.0
		)
		if spinning and hit_frame < 0:
			hit_frame = frame
		if frame == 3 and not OS.get_environment("LUMO_ROCKET_DEBUG").is_empty():
			for node in game.race_root.find_children("*", "GeometryInstance3D", true, false):
				var g := node as GeometryInstance3D
				if (
					g.is_visible_in_tree()
					and g.global_position.distance_to(game.camera.global_position) < 14.0
					and not "Kart_" in str(g.get_path())
				):
					print(
						(
							"[RocketDebug] %s %s d=%.2f"
							% [
								g.get_path(),
								g.get_class(),
								g.global_position.distance_to(game.player.global_position)
							]
						)
					)
		var label: String = "flight" if hit_frame < 0 else "after_hit"
		rows.append(_record(label, frame, ticks_done - last_ticks))
		last_ticks = ticks_done
		if mode == "frames" and saved.size() < shot_at.size():
			var due: bool = frame >= int(shot_at[saved.size()])
			if hit_frame >= 0:
				# Nach dem Treffer: Einschlag, Wirbel, Landung im festen Abstand.
				if post_index < 0:
					post_index = 0
				due = (
					post_index < POST_HIT.size() and frame - hit_frame >= int(POST_HIT[post_index])
				)
				if due:
					post_index += 1
			if due:
				await _shot(
					(
						"%s%s%s_%02d_f%03d_%s"
						% [
							scenario,
							"_reduced" if reduced else "",
							"_" + tag if not tag.is_empty() else "",
							saved.size() + 1,
							frame,
							label,
						]
					)
				)
		if hit_frame >= 0 and not spinning and landed_frame < 0:
			landed_frame = frame
		var pictures_done: bool = saved.size() >= shot_at.size() or post_index >= POST_HIT.size()
		if landed_frame >= 0 and frame - landed_frame > 30 and (mode == "measure" or pictures_done):
			break
	RenderingServer.render_loop_enabled = true
	var summary := _summarise(hit_frame, start_ticks)
	var name: String = (
		"%s_%s%s_c%s%s%s"
		% [
			mode,
			scenario,
			"_reduced" if reduced else "",
			cadence,
			"" if smooth else "_nosmooth",
			"_" + tag if not tag.is_empty() else "",
		]
	)
	var file := FileAccess.open(destination.path_join(name + ".json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"summary": summary, "rows": rows}, "\t"))
	file.close()
	print("[RocketProbe] %s" % JSON.stringify(summary))
	for path in saved:
		print("[RocketProbe] bild %s" % path)
	var released: bool = await TEARDOWN.release_scene(self, game, "[RocketProbe]")
	quit(0 if released else 1)


func _present_async(frame_ticks: float) -> void:
	_present(frame_ticks)
	if mode == "frames" or rows.size() % 20 == 0:
		await process_frame


func _summarise(hit_frame: int, start_ticks: int) -> Dictionary:
	var flight: Array = rows.filter(func(r): return r.label == "flight" and r.has("rocket"))
	var steps: Array[float] = []
	var screen_steps: Array[float] = []
	var raw_steps: Array[float] = []
	var raw_screen_steps: Array[float] = []
	var ticks_hist: Dictionary = {}
	var visible_frames: int = 0
	for i in range(flight.size()):
		var r: Dictionary = flight[i]
		ticks_hist[str(r.ticks)] = int(ticks_hist.get(str(r.ticks), 0)) + 1
		if bool(r.get("on_screen", false)):
			visible_frames += 1
		if i == 0:
			continue
		var a: Array = flight[i - 1].rocket
		var b: Array = r.rocket
		steps.append(Vector3(a[0], a[1], a[2]).distance_to(Vector3(b[0], b[1], b[2])))
		if r.has("raw_rocket") and flight[i - 1].has("raw_rocket"):
			var ra: Array = flight[i - 1].raw_rocket
			var rb: Array = r.raw_rocket
			raw_steps.append(Vector3(ra[0], ra[1], ra[2]).distance_to(Vector3(rb[0], rb[1], rb[2])))
			var rsa: Array = flight[i - 1].raw_screen
			var rsb: Array = r.raw_screen
			if rsa[0] >= 0 and rsb[0] >= 0 and bool(r.get("on_screen", false)):
				raw_screen_steps.append(
					Vector2(rsa[0], rsa[1]).distance_to(Vector2(rsb[0], rsb[1]))
				)
		var sa: Array = flight[i - 1].screen
		var sb: Array = r.screen
		if sa[0] >= 0 and sb[0] >= 0 and bool(r.get("on_screen", false)):
			screen_steps.append(Vector2(sa[0], sa[1]).distance_to(Vector2(sb[0], sb[1])))
	var max_lift: float = 0.0
	var end_lift: float = 0.0
	var max_display: float = 0.0
	for r in rows:
		if r.label == "after_hit":
			max_lift = maxf(max_lift, float(r.target_lift))
			end_lift = float(r.target_lift)
			max_display = maxf(max_display, float(r.get("display_lift", 0.0)))
	var fps: float = (
		60.0 if cadence in ["60", "jitter"] else (120.0 if cadence == "120cap" else float(cadence))
	)
	return {
		"mode": mode,
		"scenario": scenario,
		"reduced": reduced,
		"cadence": cadence,
		"smooth": smooth,
		"smoother_present": smoother != null,
		"flight_frames": flight.size(),
		"flight_seconds": snappedf(flight.size() / fps, 0.001),
		"hit_frame": hit_frame,
		"visible_frames": visible_frames,
		"visible_seconds": snappedf(visible_frames / fps, 0.001),
		"ticks_per_render_frame": ticks_hist,
		"world_step_m": _stats(steps),
		"screen_step_px": _stats(screen_steps),
		"raw_world_step_m": _stats(raw_steps),
		"raw_screen_step_px": _stats(raw_screen_steps),
		"target_max_lift_m": snappedf(max_lift, 0.001),
		"target_end_lift_m": snappedf(end_lift, 0.001),
		"max_display_lift_m": snappedf(max_display, 0.001),
		"player_speed": rows[0].player_speed if not rows.is_empty() else 0.0,
		"start_gap_m": rows[0].get("to_target", -1.0) if not rows.is_empty() else -1.0,
		"max_runtime_particles":
		rows.map(func(r): return int(r.runtime_particles)).max() if not rows.is_empty() else 0,
		"max_trail_points":
		rows.map(func(r): return int(r.get("trail_points", 0))).max() if not rows.is_empty() else 0,
		"pip_frames": rows.filter(func(r): return bool(r.get("pip", false))).size(),
		"ticks_total": ticks_done - start_ticks,
		"runtime_stats": game.item_runtime.stats.duplicate(),
		"flight_stats":
		game.rocket_flight.stats.duplicate() if game.get("rocket_flight") != null else {},
		"smoother":
		(
			{
				"frames": smoother.interpolated_frames,
				"adopted": smoother.adopted_writes,
			}
			if smoother != null
			else {}
		),
	}


func _stats(values: Array[float]) -> Dictionary:
	if values.is_empty():
		return {}
	var total: float = 0.0
	var zeros: int = 0
	for v in values:
		total += v
		if v < 0.0001:
			zeros += 1
	var mean: float = total / values.size()
	var variance: float = 0.0
	for v in values:
		variance += (v - mean) * (v - mean)
	var sorted: Array[float] = values.duplicate()
	sorted.sort()
	return {
		"n": values.size(),
		"mean": snappedf(mean, 0.001),
		"min": snappedf(sorted[0], 0.001),
		"max": snappedf(sorted[-1], 0.001),
		"p95": snappedf(sorted[int(sorted.size() * 0.95)], 0.001),
		"cv": snappedf(sqrt(variance / values.size()) / maxf(mean, 0.0001), 0.001),
		"zero": zeros,
	}
