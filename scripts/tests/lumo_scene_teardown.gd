extends RefCounted
## Close the actual scene and observe mixer-owned playbacks being released
## before terminating an engine integration test. Reuse the existing bounded
## weak-reference teardown; errors remain visible to the strict probe runner.
const OBSERVED = preload("res://scripts/tests/helpers/kart_scene_teardown.gd")


static func release(tree: SceneTree, label: String) -> bool:
	var scene_released := true
	if is_instance_valid(tree.current_scene):
		scene_released = await OBSERVED.release_scene(tree, tree.current_scene, label)
	var soundscape := tree.root.get_node_or_null("GameSoundscape")
	if soundscape != null:
		soundscape.set_process(false)
	var audio_released: bool = await OBSERVED.release_audio(tree, tree.root, label)
	if soundscape != null:
		soundscape.release_audio()
	return scene_released and audio_released
