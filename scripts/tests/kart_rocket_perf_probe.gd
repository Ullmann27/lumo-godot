extends SceneTree
## Leistungsmessung der Raketen-Inszenierung im Container (gl_compatibility, Fenster).
## Kein Gate. Misst je Profil die Bildzeit (Wanduhr je gerendertem Bild), Draw-Calls und
## die Zahl gleichzeitig lebender Effekt-Teilchen: erst ohne Rakete, dann mit einer
## Salve bis nach dem Einschlag. Container-Werte (llvmpipe), keine Handy-Werte.
## Aufruf: xvfb-run godot --path . --rendering-method gl_compatibility \
##   --script res://scripts/tests/kart_rocket_perf_probe.gd -- low|medium|high
const TEARDOWN = preload("res://scripts/tests/helpers/kart_scene_teardown.gd")
const STEP: float = 1.0 / 60.0
var game
var smoother


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


func _sample(frames: int, fire: bool) -> Dictionary:
	var ms: Array[float] = []
	var calls: Array[int] = []
	var peak: int = 0
	var hit_seen: bool = false
	for i in range(frames):
		if fire and i == 2:
			game.lock_target = 0
			game.lock_progress = 1.0
			game._use_item()
		_tick()
		var start: int = Time.get_ticks_usec()
		await process_frame
		await RenderingServer.frame_post_draw
		ms.append((Time.get_ticks_usec() - start) / 1000.0)
		calls.append(
			RenderingServer.get_rendering_info(
				RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME
			)
		)
		peak = maxi(peak, _particles())
		hit_seen = hit_seen or game.opponent_spin_times[0] > 0.0
	ms.sort()
	var total: float = 0.0
	for v in ms:
		total += v
	var call_total: int = 0
	for c in calls:
		call_total += c
	return {
		"frames": frames,
		"mean_ms": snappedf(total / ms.size(), 0.01),
		"median_ms": snappedf(ms[ms.size() / 2], 0.01),
		"p95_ms": snappedf(ms[int(ms.size() * 0.95)], 0.01),
		"draw_calls_mean": call_total / calls.size(),
		"draw_calls_max": calls.max(),
		"peak_effect_particles": peak,
		"hit": hit_seen,
	}


func _run() -> void:
	var profile: String = "medium"
	for argument in OS.get_cmdline_user_args():
		if argument in ["low", "medium", "high"]:
			profile = argument
	var window := Vector2i(906, 408)
	DisplayServer.window_set_size(window)
	root.size = window
	DirAccess.remove_absolute("user://kart_item_hints.cfg")
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.lightweight = false
	game.graphics_profile = profile
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
	smoother = game.frame_smoother
	smoother.manual = true
	smoother.manual_fraction = 0.5
	for i in range(240):
		_tick()
		if i % 40 == 0:
			await process_frame
	var d: float = float(game.distance)
	for i in range(game.opponents.size()):
		var od: float = d + 26.0 if i == 0 else d - 70.0 - i * 6.0
		game.opponents[i].transform = game.world.reset_transform(
			od, float(game.lane) if i == 0 else 3.0
		)
		game.opponent_distances[i] = od
		game.opponent_lanes[i] = float(game.lane) if i == 0 else 3.0
		game.opponent_items[i] = ""
		game.opponent_item_cooldowns[i] = 60.0
		game.opponent_shield_times[i] = 0.0
	game._grant_item("star_rocket")
	game.item_hint = ""
	game._use_item()
	var idle: Dictionary = await _sample(90, false)
	var salvo: Dictionary = await _sample(150, true)
	var result := {
		"profile": profile,
		"window": [window.x, window.y],
		"renderer": RenderingServer.get_current_rendering_method(),
		"ohne_rakete": idle,
		"mit_salve": salvo
	}
	print("[RocketPerf] %s" % JSON.stringify(result))
	await TEARDOWN.release_scene(self, game, "[RocketPerf]")
	quit(0)
