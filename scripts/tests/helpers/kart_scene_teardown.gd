extends RefCounted
## Observe the real scene and mixer-owned playbacks before a probe can pass.

const RELEASE_LIMIT_MS := 2000


static func release_scene(tree: SceneTree, scene: Node, label: String) -> bool:
	if not is_instance_valid(scene):
		printerr("%s teardown requires a live production scene" % label)
		return false
	var scene_reference: WeakRef = weakref(scene)
	var playbacks: Array[WeakRef] = []
	for player: Node in scene.find_children("*", "AudioStreamPlayer", true, false):
		if player.has_stream_playback():
			playbacks.append(weakref(player.get_stream_playback()))
	var started := Time.get_ticks_msec()
	scene.queue_free()
	scene = null
	while true:
		var pending := _pending_playbacks(playbacks)
		var scene_retained := scene_reference.get_ref() != null
		var elapsed := Time.get_ticks_msec() - started
		if elapsed >= RELEASE_LIMIT_MS:
			printerr(
				"%s teardown retained_scene=%s retained_audio=%s elapsed_ms=%d"
				% [label, scene_retained, pending, elapsed]
			)
			return false
		if not scene_retained and pending.is_empty():
			print(
				"%s teardown tracked=%d scene_released=true audio_released=true elapsed_ms=%d"
				% [label, playbacks.size(), elapsed]
			)
			return true
		await tree.process_frame
	return false


static func _pending_playbacks(references: Array[WeakRef]) -> Array[String]:
	# Keep temporary strong references inside this synchronous call, never
	# across the process_frame await in the caller.
	var pending: Array[String] = []
	for reference: WeakRef in references:
		var playback = reference.get_ref()
		if playback != null:
			pending.append(playback.get_class())
	return pending
