extends SceneTree
## Every visible garage control must stay at least 48x48 dp after layout.
const MIN_DP: float = 48.0

var game


func _initialize() -> void:
	call_deferred("_run")


func _settle(frames: int = 6) -> void:
	for _i in range(frames):
		await process_frame


func _ui_scale(garage: Control) -> float:
	var viewport_size: Vector2 = garage.get_viewport().get_visible_rect().size
	var window_size: Vector2 = Vector2(garage.get_window().size)
	if window_size.x <= 0.0 or window_size.y <= 0.0:
		return 1.0
	return maxf(viewport_size.x / window_size.x, viewport_size.y / window_size.y)


func _collect_buttons(node: Node, into: Array) -> void:
	if node is BaseButton:
		var button: BaseButton = node
		if button.is_visible_in_tree() and button.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			into.append(button)
	for child in node.get_children():
		_collect_buttons(child, into)


func _assert_targets(label: String, garage: Control) -> int:
	var scale: float = maxf(_ui_scale(garage), 0.001)
	var buttons: Array = []
	_collect_buttons(garage, buttons)
	assert(buttons.size() > 0, "%s: garage must expose tappable controls" % label)
	var checked: int = 0
	for button in buttons:
		var physical: Vector2 = button.size / scale
		assert(
			physical.x + 0.01 >= MIN_DP and physical.y + 0.01 >= MIN_DP,
			"%s: %s is %.1fx%.1f dp (need >= %.0f)"
			% [label, button.name if str(button.name) != "" else str(button.get_path()), physical.x, physical.y, MIN_DP]
		)
		checked += 1
	print("[GarageTargets] %s: %d visible buttons >= 48x48 dp (ui_scale=%.3f)" % [label, checked, scale])
	return checked


func _run() -> void:
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	await _settle()
	game.garage.stars = 60
	var total: int = 0
	for pixels in [Vector2i(1280, 720), Vector2i(412, 915), Vector2i(690, 829)]:
		root.size = pixels
		await _settle(8)
		game.garage._apply_responsive_layout()
		for step in range(5):
			game.garage.step = step
			game.garage._refresh()
			game.garage._apply_responsive_layout()
			await _settle(4)
			total += _assert_targets("%dx%d step %d" % [pixels.x, pixels.y, step], game.garage)
	var playbacks: Array[WeakRef] = []
	for player: Node in game.find_children("*", "AudioStreamPlayer", true, false):
		if player.has_stream_playback():
			playbacks.append(weakref(player.get_stream_playback()))
	var scene: WeakRef = weakref(game)
	game.queue_free()
	await process_frame
	game = null
	if not (await _release_audio(scene, playbacks)):
		push_error("[GarageTargets] FAIL: Scene or audio playback retained after teardown")
		quit(1)
		return
	print("[GarageTargets] PASS: %d visible controls checked at >= 48x48 dp" % total)
	quit(0)


func _release_audio(scene: WeakRef, playbacks: Array[WeakRef]) -> bool:
	# A freed scene can leave mixer-side Ogg fadeout alive beyond one frame.
	# Observe real owners without retaining them; simulation time is not a deadline.
	var started := Time.get_ticks_msec()
	while true:
		var pending := 0
		for playback: WeakRef in playbacks:
			if playback.get_ref() != null:
				pending += 1
		var scene_retained := scene.get_ref() != null
		var elapsed := Time.get_ticks_msec() - started
		if elapsed >= 2000:
			printerr(
				"[GarageTargets] retained_scene=%s retained_audio_playbacks=%d elapsed_ms=%d"
				% [scene_retained, pending, elapsed]
			)
			return false
		if not scene_retained and pending == 0:
			print("[GarageTargets] audio_release tracked=%d scene_released=true elapsed_ms=%d" % [playbacks.size(), elapsed])
			return true
		OS.delay_msec(2)
		await process_frame
	return false
