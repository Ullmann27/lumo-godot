extends SceneTree
## Musik und Ton: neue Original-Stücke laden als Schleife, getrennte Lautstärken
## für Musik und Effekte (Pausenmenü), Speicherung und sofortige Wirkung.

const AUDIO = preload("res://scripts/games/kart_audio.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for track in ["garage", "sonnenhafen", "zauberwald", "bergwelt", "holo_city"]:
		var stream = load("res://assets/audio/kart/%s.ogg" % track)
		assert(stream is AudioStreamOggVorbis, track + " lädt als Ogg Vorbis")
		assert(stream.get_length() > 55.0, track + " ist ein ausgearbeitetes Stück (> 55 s)")
	var audio = AUDIO.new()
	root.add_child(audio)
	await process_frame
	audio.set_volumes(0.5, 0.0)
	assert(absf(audio.music_db() - (audio.MUSIC_DB - 6.0206)) < 0.01, "50 % Musik = −6 dB")
	assert(audio.effect_db() == audio.QUIET_DB, "Effekte auf 0 sind stumm")
	audio.set_volumes(2.0, -1.0)
	assert(audio.music_volume == 1.0 and audio.effects_volume == 0.0, "Werte werden begrenzt")
	audio.queue_free()

	DirAccess.remove_absolute("user://kart_preferences.cfg")
	var game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	game._start_selected_race({"mode": "race", "driver": "fox", "kart": "comet", "track": "sonnenhafen", "difficulty": "flott"})
	await process_frame
	game.countdown = 0
	game._physics_process(1.0 / 60.0)
	game._pause()
	await process_frame
	var music_row: Node = game.modal_column.find_child("VolumeMusik", true, false)
	var effects_row: Node = game.modal_column.find_child("VolumeEffekte", true, false)
	assert(music_row != null and effects_row != null, "Pausenmenü hat getrennte Regler für Musik und Effekte")
	var music_slider: HSlider = music_row.get_node("Slider")
	var effects_slider: HSlider = effects_row.get_node("Slider")
	assert(music_slider.get_combined_minimum_size().y >= 44, "Regler sind fingerfreundlich groß")
	music_slider.value = 30
	effects_slider.value = 70
	assert(absf(game.music_volume - 0.3) < 0.001 and absf(game.effects_volume - 0.7) < 0.001)
	assert(absf(game.kart_audio.music_volume - 0.3) < 0.001, "Musik ändert sich sofort")
	assert(absf(game.kart_audio.effects_volume - 0.7) < 0.001, "Effekte ändern sich sofort")
	game.abandoned = true
	game.queue_free()
	await process_frame
	var reopened = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(reopened)
	await process_frame
	assert(absf(reopened.music_volume - 0.3) < 0.001 and absf(reopened.effects_volume - 0.7) < 0.001, "Lautstärken bleiben gespeichert")
	assert(absf(reopened.kart_audio.music_volume - 0.3) < 0.001, "Gespeicherte Lautstärke gilt beim nächsten Start")
	reopened.abandoned = true
	reopened.queue_free()
	await process_frame
	DirAccess.remove_absolute("user://kart_preferences.cfg")
	print("[KartAudio] PASS: fünf neue Schleifen > 55 s, Musik/Effekte getrennt regelbar, sofort wirksam, gespeichert")
	await create_timer(0.2).timeout
	quit(0)
