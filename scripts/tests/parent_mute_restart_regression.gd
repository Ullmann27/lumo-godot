extends SceneTree
## Run twice with the same isolated XDG_DATA_HOME. First with
## --mute and then with --unmute to test two real process starts and the UI.

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if not ("--mute" in args or "--unmute" in args):
		quit(2)
		return
	var expected := "--unmute" in args
	var audio := root.get_node("AudioManager")
	var store := root.get_node("SettingsStore")
	assert(audio.is_muted() == expected and AudioServer.is_bus_mute(0) == expected)
	assert(store.is_audio_muted() == expected)
	var router := root.get_node("SceneRouter")
	router.goto("parent")
	await scene_changed
	await process_frame
	var panel := current_scene
	assert(panel.scene_file_path == router.SCENES.parent)
	var button: Button = panel.get_node("%Sound")
	assert(button.button_pressed != expected)
	button.pressed.emit()
	assert(audio.is_muted() != expected and AudioServer.is_bus_mute(0) != expected)
	store.load_now()
	assert(store.is_audio_muted() != expected)
	assert(button.button_pressed == expected)
	var quality: OptionButton = panel.get_node("%Quality")
	assert(quality.item_count == 4)
	quality.select(0)
	quality.item_selected.emit(0)
	assert(root.get_node("PerformanceManager").get_graphics_choice() == "low")
	panel.back.pressed.emit()
	await scene_changed
	assert(current_scene.scene_file_path == router.SCENES.home)
	root.get_node("GameSoundscape").release_audio()
	for i in 10:
		await process_frame
	print("[ParentMuteRestart] PASS initial_muted=", expected, " and button saved ", not expected)
	quit(0)
