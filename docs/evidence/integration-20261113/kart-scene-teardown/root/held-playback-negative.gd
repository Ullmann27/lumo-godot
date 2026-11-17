extends SceneTree

const TEARDOWN = preload("res://scripts/tests/helpers/kart_scene_teardown.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	for frame in range(6):
		await process_frame
	var held
	for player: Node in game.find_children("*", "AudioStreamPlayer", true, false):
		if player.has_stream_playback():
			held = player.get_stream_playback()
			break
	if held == null:
		push_error("[HeldPlayback] Missing real production playback; invalid negative fixture")
		quit(2)
		return
	var reference: WeakRef = weakref(held)
	var held_class: String = held.get_class()
	var started := Time.get_ticks_msec()
	var released: bool = await TEARDOWN.release_scene(self, game, "[HeldPlayback]")
	game = null
	var elapsed := Time.get_ticks_msec() - started
	print("[HeldPlayback] observed_result=", released, " held_class=", held_class,
		" elapsed_ms=", elapsed, " still_held=", reference.get_ref() != null)
	held = null
	var cleanup_deadline := Time.get_ticks_msec() + 2000
	while reference.get_ref() != null and Time.get_ticks_msec() < cleanup_deadline:
		await process_frame
	if released or elapsed < 2000:
		push_error("[HeldPlayback] Incorrect success or simulation-time deadline")
		quit(2)
		return
	print("[HeldPlayback] EXPECTED_FAILURE: actual retained playback rejected before any PASS")
	quit(1)
