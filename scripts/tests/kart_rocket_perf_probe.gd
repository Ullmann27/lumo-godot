extends SceneTree
## Leistungsmessung der Raketen-Inszenierung im Container. Kein Gate.
## Misst je Profil: CPU-Zeit der neuen Darstellung je Bild (Glätter + Spur/Blitze),
## gleichzeitig lebende Effekt-Teilchen und sichtbare Zeichenobjekte der Inszenierung,
## erst ohne Rakete, dann mit einer Salve bis nach dem Einschlag. Mit Fenster zusätzlich
## die Bildzeit (Wanduhr, llvmpipe – stark lastabhängig). Container-Werte, keine Handy-Werte.
## Aufruf: xvfb-run godot --path . --rendering-method gl_compatibility \
##   --script res://scripts/tests/kart_rocket_perf_probe.gd -- low|medium|high
const TEARDOWN = preload("res://scripts/tests/helpers/kart_scene_teardown.gd")
const STEP: float = 1.0 / 60.0
var game
var smoother
var rendered: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _tick() -> void:
	smoother.begin_tick()
	game._physics_process(STEP)
	smoother.end_tick()


func _particles() -> int:
	var total: int = 0
	for node in game.race_root.find_children("*", "CPUParticles3D", true, false):
		var particles := node as CPUParticles3D
		if particles.emitting and particles.is_visible_in_tree():
			total += particles.amount
	return total + game.rocket_flight.trail_point_total()


## Sichtbare Zeichenobjekte der neuen Inszenierung (Spurbänder, Blitze, Partikel, Licht).
func _presentation_nodes() -> int:
	var count: int = 0
	for node in game.rocket_flight.find_children("*", "Node3D", true, false):
		if (
			(node is GeometryInstance3D or node is Light3D)
			and (node as Node3D).is_visible_in_tree()
			and not (node is CPUParticles3D and not (node as CPUParticles3D).emitting)
		):
			count += 1
	return count


func _fire() -> void:
	game.paused = false
	game._grant_item("star_rocket")
	game.item_roulette_time = 0.0
	game.item_hint = ""
	game._use_item()
	for _i in range(30):
		_tick()
	game.lock_target = 0
	game.lock_progress = 1.0
	game._use_item()


func _sample(frames: int, fire: bool) -> Dictionary:
	var frame_ms: Array[float] = []
	var code_us: Array[float] = []
	var peak: int = 0
	var nodes: int = 0
	var hit_seen: bool = false
	if fire:
		_fire()
	for i in range(frames):
		game.paused = false
		_tick()
		if fire and i == 30 and not game.item_runtime.projectiles.is_empty():
			# Ungünstigster Fall fürs Budget: Spuren noch in der Luft und ein Einschlag.
			game.rocket_flight.impact(game.opponents[0].global_position + Vector3.UP * 0.8)
		# Kosten der neuen Darstellung je Bild: Glätter + Spur/Blitze (CPU, µs).
		var t0: int = Time.get_ticks_usec()
		smoother._process(0.0)
		game.rocket_flight._process(STEP)
		code_us.append(float(Time.get_ticks_usec() - t0))
		if rendered:
			var start: int = Time.get_ticks_usec()
			await process_frame
			await RenderingServer.frame_post_draw
			frame_ms.append((Time.get_ticks_usec() - start) / 1000.0)
		elif i % 20 == 0:
			await process_frame
		peak = maxi(peak, _particles())
		nodes = maxi(nodes, _presentation_nodes())
		hit_seen = hit_seen or game.opponent_spin_times[0] > 0.0
	return {
		"frames": frames,
		"code_us": _stats(code_us),
		"frame_ms": _stats(frame_ms),
		"peak_effect_particles": peak,
		"peak_presentation_nodes": nodes,
		"hit": hit_seen,
	}


func _stats(values: Array[float]) -> Dictionary:
	if values.is_empty():
		return {}
	values.sort()
	var total: float = 0.0
	for v in values:
		total += v
	return {
		"mean": snappedf(total / values.size(), 0.01),
		"median": snappedf(values[values.size() / 2], 0.01),
		"p95": snappedf(values[int(values.size() * 0.95)], 0.01),
		"max": snappedf(values[-1], 0.01),
	}


func _run() -> void:
	var profile: String = "medium"
	for argument in OS.get_cmdline_user_args():
		if argument in ["low", "medium", "high"]:
			profile = argument
	rendered = DisplayServer.get_name() != "headless"
	var window := Vector2i(906, 408)
	if rendered:
		DisplayServer.window_set_size(window)
	root.size = window
	DirAccess.remove_absolute("user://kart_item_hints.cfg")
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.lightweight = false
	game.graphics_profile = profile
	await process_frame
	await process_frame
	var setup := {
		"mode": "race",
		"driver": "fox",
		"kart": "comet",
		"track": "sonnenhafen",
		"difficulty": "gemuetlich"
	}
	game._start_selected_race(setup)
	game._end_preview()
	game.set_physics_process(false)
	await process_frame
	game.countdown = 0.0
	game.racing = true
	game.auto_gas = true
	game.message.text = ""
	smoother = game.frame_smoother
	smoother.manual = true
	smoother.manual_fraction = 0.5
	for i in range(240):
		_tick()
		if i % 40 == 0:
			await process_frame
	var d: float = float(game.distance)
	for i in range(game.opponents.size()):
		var od: float = d + 18.0 if i == 0 else d - 70.0 - i * 6.0
		var lane: float = float(game.lane) if i == 0 else 3.0
		game.opponents[i].transform = game.world.reset_transform(od, lane)
		game.opponent_distances[i] = od
		game.opponent_lanes[i] = lane
		game.opponent_items[i] = ""
		game.opponent_item_cooldowns[i] = 60.0
		game.opponent_shield_times[i] = 0.0
		game.opponent_grace_times[i] = 0.0
		game.opponents[i].motion_speed = float(game.speed) * 0.85
	var idle: Dictionary = await _sample(60 if rendered else 120, false)
	var salvo: Dictionary = await _sample(120 if rendered else 150, true)
	var result := {
		"profile": game.rocket_flight.quality,
		"rendered": rendered,
		"window": [window.x, window.y],
		"renderer": RenderingServer.get_current_rendering_method(),
		"ohne_rakete": idle,
		"mit_salve": salvo,
		"runtime": game.item_runtime.stats.duplicate(),
		"flight": game.rocket_flight.stats.duplicate(),
	}
	print("[RocketPerf] %s" % JSON.stringify(result))
	await TEARDOWN.release_scene(self, game, "[RocketPerf]")
	quit(0)
