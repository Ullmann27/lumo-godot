extends "res://scripts/tests/kart_item_ext_regression.gd"
## Drive the real item button, projectile simulation, fairness gate, mixer and
## presentation clock. --out=/path writes four phases of every actual contact.
const CUES := {"star_rocket":"rocket_hit","whirlwind":"whirl_hit","thunder_star":"thunder_strike","star_magnet":"magnet_pull"}
var out := ""


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
			DirAccess.make_dir_recursive_absolute(out)
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	game.reduced_motion = false
	await _start("sonnenhafen")
	for layer in game.find_children("*","CanvasLayer",true,false):
		layer.visible = false
	root.content_scale_size = Vector2i(640,360)
	root.size = Vector2i(640,360)
	game.frame_smoother.manual = true
	game.kart_audio.set_volumes(0.0,1.0)
	for id in CUES:
		for target in [0,-1]:
			await _contact(id,target)
	game.gas_held = true
	game.auto_gas = false
	var previous: float = game.distance
	for i in 70:
		game._physics_process(STEP)
	_check(game.speed > 1.0 and game.distance > previous, "Child drives forward after the last landing")
	game.gas_held = false
	for key in [0,-1]:
		_fresh()
		_place(0.0,[[0,0,0],[1,1]])
		_check(ext.resolve(key, 0 if key == -1 else -1, "thunder_star", ext.kart_centre(key)) == "grace", "Finish line protected")
		_check(not game.rocket_flight.tumbles.has(key), "Finish line keeps both wheels down")
	_fresh()
	_place(safe_d,[[0,0,0],[1,1]])
	game.rocket_fairness.observe(game.reset_count+1,game.elapsed)
	_check(ext.resolve(-1,0,"whirlwind",ext.kart_centre(-1)) == "grace", "Rescue protection")
	game.opponent_shield_times[0] = 3.0
	_check(ext.resolve(0,-1,"star_magnet",ext.kart_centre(0)) == "blocked", "Magnet bounces from shield")
	for id in CUES:
		var cue: String = CUES[id]
		game.kart_audio._last_effect.erase(cue)
		game.reduced_motion = true
		game._sound_effect(cue)
		_check(not game.kart_audio._last_effect.has(cue), "Reduced effects skip " + cue)
		game.reduced_motion = false
		game.kart_audio.set_muted(true)
		game._sound_effect(cue)
		_check(not game.kart_audio._last_effect.has(cue), "Muted contact is silent " + cue)
		game.kart_audio.set_muted(false)
	game.abandoned = true
	game.queue_free()
	await process_frame
	await create_timer(.15).timeout
	print("[KartContact] checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)


func _contact(id: String, target: int) -> void:
	_fresh()
	game.frame_smoother.restore_all()
	var cue: String = CUES[id]
	var owner := 0 if target == -1 else -1
	var gap := 3.8 if id == "star_magnet" else 14.0
	var offsets := [[0,0,0],[gap if target == 0 else -gap,1.1]]
	_place(safe_d,offsets)
	game.kart_audio._last_effect.erase(cue)
	var victim = ext.kart(target)
	var base: Transform3D = victim.global_transform
	var center: Vector3 = base * Vector3(0,.8,0)
	game.camera.fov = 38
	game.camera.look_at_from_position(base * Vector3(4.8,2.9,-5.0), center)
	if id == "star_rocket":
		if owner == -1:
			_player_use(id)
			game.lock_target = target
			game.lock_progress = 1.0
			game._use_item()
		else:
			game.item_runtime.fire_homing(id,owner,ext.progress(owner),ext.lateral(owner),target)
	elif owner == -1:
		_player_use(id)
	else:
		game.opponent_items[owner] = id
		game._rival_use_catalog_item(owner,victim.global_position - ext.kart(owner).global_position)
	var frames := 0
	while not game.rocket_flight.tumbles.has(target) and frames < 220:
		_tick(STEP,safe_d,offsets)
		frames += 1
	var hit: bool = game.rocket_flight.tumbles.has(target)
	_check(hit,"%s actual contact from %d to %d" % [id,owner,target])
	if not hit:
		return
	_check(game.kart_audio._last_effect.has(cue), id + " plays specific sample through audio node")
	var total: float = game.rocket_flight.tumbles[target].total
	var last := 0.0
	for phase in [.08,.37,.77,1.05]:
		for frame in maxi(1,roundi((float(phase)-last)*total/STEP)):
			_tick(STEP,safe_d,offsets)
		last = phase
		var offset: Variant = game.rocket_flight.offset_for(victim)
		if phase == .37:
			_check(offset is Transform3D and offset.origin.length() > .1, id+" visible air/turn")
		if phase == 1.05:
			_check(offset == null, id+" fully settled")
		if not out.is_empty():
			game.frame_smoother.end_tick()
			game.frame_smoother.manual_fraction = 1.0
			game.frame_smoother._process(0.0)
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(out.path_join("%s_%d_%03d.png" % [id,target,roundi(100*phase)]))
			game.frame_smoother.begin_tick()
