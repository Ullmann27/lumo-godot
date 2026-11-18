extends SceneTree
## Klangwelt: Musik/Atmosphäre je Route, Überblenden, Stumm, Ducking, Hintergrund,
## Kart/Lauf unberührt und echte Samples für jeden im Projekt benutzten play_sfx-Namen.
## Headless: --audio-driver Dummy.

# Erwartung unabhängig von der Tabelle im System (Route -> [Musik, Atmosphäre]).
const EXPECTED: Dictionary = {
	"boot": ["lumo_theme", ""], "intro": ["lumo_theme", ""], "home": ["lumo_theme", ""],
	"games": ["hub", "playroom"], "cards": ["cards", "playroom"], "memory": ["memory", "playroom"],
	"connect_four": ["connect_four", "playroom"], "quiz": ["quiz", "studio"],
	"treasure": ["treasure", "island"], "rhythm": ["", "stage"], "puzzle": ["puzzle", "playroom"],
	"build": ["build", ""], "learning": ["learning", ""], "tutor": ["learning", ""],
	"reading_hub": ["learning", ""],
}

var checks: int = 0
var failures: int = 0
var gs: Node
var audio: Node


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("[SoundscapeRegression] " + message)


func _advance(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		var dt := minf(0.05, left)
		gs.step(dt)
		left -= dt


func _state() -> Dictionary:
	return gs.debug_state()


func _run() -> void:
	await process_frame
	gs = root.get_node_or_null("GameSoundscape")
	audio = root.get_node_or_null("AudioManager")
	_check(gs != null and audio != null, "GameSoundscape and AudioManager are autoloads")
	if gs == null or audio == null:
		_finish()
		return
	audio._muted = false
	gs.variant_override = "day"
	gs.auto_ui_clicks = true

	# 1. Jede Route: richtiges Stück, richtige Atmosphäre, volle Lautstärke nach dem Einblenden.
	for route in EXPECTED:
		gs.enter_route(route)
		_advance(2.5)
		var s := _state()
		var want: Array = EXPECTED[route]
		_check(s.music == want[0], "%s plays music %s (got %s)" % [route, want[0], s.music])
		_check(s.ambience == want[1], "%s plays ambience %s (got %s)" % [route, want[1], s.ambience])
		if not str(want[0]).is_empty():
			_check(is_equal_approx(float(s.music_level), 1.0), "%s music faded in" % route)
			_check(float(s.music_db) > -40.0 and float(s.music_db) < -6.0, "%s music level sensible: %s dB" % [route, s.music_db])
		if not str(want[1]).is_empty():
			_check(float(s.ambience_db) > -50.0 and float(s.ambience_db) < 0.0, "%s ambience audible" % route)
	_check(_state().ambience_layer == "", "no waterfall outside the island")

	# 2. Überblenden: alte Musik sinkt, neue steigt, nach dem Fade läuft nur die neue.
	gs.enter_route("cards")
	_advance(2.5)
	gs.enter_route("memory")
	_advance(0.6)
	var decks: Array = _state().music_decks
	var old_deck: Dictionary = {}
	var new_deck: Dictionary = {}
	for deck in decks:
		if deck.key == "cards":
			old_deck = deck
		elif deck.key == "memory":
			new_deck = deck
	_check(not old_deck.is_empty() and not new_deck.is_empty(), "both songs present during crossfade")
	if not old_deck.is_empty() and not new_deck.is_empty():
		_check(old_deck.level > 0.4 and old_deck.level < 0.8 and old_deck.target == 0.0, "old song fading out: %s" % old_deck)
		_check(new_deck.level > 0.2 and new_deck.level < 0.6 and new_deck.target == 1.0, "new song fading in: %s" % new_deck)
	_advance(2.0)
	var playing_keys: Array = []
	for deck in _state().music_decks:
		if deck.playing:
			playing_keys.append(deck.key)
	_check(playing_keys == ["memory"], "only memory plays after the crossfade: %s" % [playing_keys])
	# Gleiche Musik in Folgerouten (Boot -> Intro -> Home) läuft durch statt neu zu starten.
	gs.enter_route("intro")
	_advance(2.5)
	var theme_deck: Dictionary = (_state().music_decks as Array).filter(func(d): return d.key == "lumo_theme")[0]
	gs.enter_route("home")
	_advance(0.1)
	var after: Array = (_state().music_decks as Array).filter(func(d): return d.key == "lumo_theme")
	_check(after.size() == 1 and is_equal_approx(float(after[0].level), float(theme_deck.level)), "home continues the intro theme")

	# 3. Szenenwechsel über EventBus wird erkannt.
	root.get_node("EventBus").scene_changed.emit("home", "puzzle")
	_advance(2.5)
	_check(_state().route == "puzzle" and _state().music == "puzzle", "EventBus.scene_changed switches the route")

	# 4. Stumm: AudioManager-Stumm und Startoption soundEnabled=false schalten alles stumm.
	gs.enter_route("treasure")
	_advance(2.5)
	audio._muted = true
	_advance(0.2)
	_check(_all_silent(), "AudioManager mute silences music, ambience and waterfall")
	_check(_all_paused(), "muted players are paused (no decoding)")
	audio._muted = false
	_advance(0.2)
	_check(float(_state().music_db) > -40.0, "unmute restores music")
	root.get_node("SceneRouter").launch_options["soundEnabled"] = false
	gs.enter_route("games")
	_advance(2.5)
	_check(_state().silenced and _all_silent(), "host soundEnabled=false silences everything")
	root.get_node("SceneRouter").launch_options.erase("soundEnabled")
	gs.enter_route("games")
	_advance(0.2)
	_check(not _state().silenced and float(_state().music_db) > -40.0, "sound returns with soundEnabled")

	# 5. Ducking bei Sprache.
	gs.enter_route("learning")
	_advance(3.0)
	var normal_db := float(_state().music_db)
	audio.voice_started.emit(1.5)
	_advance(0.8)
	var ducked_db := float(_state().music_db)
	_check(normal_db - ducked_db > 8.0, "voice ducks music by >8 dB (%.1f -> %.1f)" % [normal_db, ducked_db])
	_advance(4.0)
	_check(absf(float(_state().music_db) - normal_db) < 0.5, "music returns after speech")
	gs.duck(true)
	_advance(1.0)
	_check(float(_state().duck) < 0.4, "manual duck works")
	gs.duck(false)
	_advance(3.0)

	# 6. Hintergrund pausiert alles, Rückkehr setzt fort.
	gs._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	_check(_state().backgrounded and _all_paused(), "app pause pauses every player")
	gs._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	var resumed := true
	for deck in _state().music_decks:
		if deck.playing and deck.paused:
			resumed = false
	_check(not _state().backgrounded and resumed, "resume continues music")

	# 7. Kart und Lauf bleiben unberührt: eigene Musik aus, keine Atmosphäre, keine Klicks.
	for own in ["kart", "run"]:
		gs.enter_route("games")
		_advance(2.5)
		gs.enter_route(own)
		_advance(2.5)
		var s := _state()
		var any_playing := false
		for deck in (s.music_decks as Array) + (s.ambience_decks as Array):
			any_playing = any_playing or deck.playing
		_check(s.music == "" and s.ambience == "" and not any_playing, "%s: soundscape stays silent" % own)
		var before_name: String = audio.last_sfx_name
		audio.last_sfx_msec = -100000
		gs._click_if_quiet(Time.get_ticks_msec())
		gs.stinger("celebrate")
		_check(audio.last_sfx_name == before_name, "%s: no automatic clicks or stingers" % own)

	# 8. Schichten, Varianten, Stinger.
	gs.enter_route("quiz")
	_advance(2.5)
	var quiz_deck: Array = (_state().music_decks as Array).filter(func(d): return d.key == "quiz")
	_check(quiz_deck.size() == 1, "quiz deck exists")
	gs.set_layer("tension", true)
	_advance(2.0)
	_check(is_equal_approx(float(_state().layers.get("tension", 0.0)), 1.0), "tension layer fades in")
	gs.set_layer("tension", false)
	_advance(2.0)
	_check(float(_state().layers.get("tension", 1.0)) == 0.0, "tension layer fades out")
	gs.enter_route("treasure")
	_advance(2.5)
	_check(_state().ambience_layer == "waterfall", "island has a waterfall layer")
	gs.pulse_layer("discovery", 1.0)
	_advance(0.9)
	_check(float(_state().layers.get("discovery", 0.0)) > 0.5, "discovery pulse rises")
	_advance(3.0)
	_check(float(_state().layers.get("discovery", 1.0)) == 0.0, "discovery pulse ends by itself")
	gs.stinger("treasure_found")
	_check(audio.last_sfx_name == "treasure_found", "stinger plays the treasure sound")
	gs.enter_route("settlement")
	gs.set_variant("evening")
	_advance(2.5)
	_check(_state().music == "settlement_evening" and _state().ambience == "village_evening", "evening variant")
	gs.set_variant("day")
	_advance(2.5)
	_check(_state().music == "settlement_day" and _state().ambience == "village_day", "day variant")

	# 9. Jeder im Projekt benutzte play_sfx-Name hat echte Samples; keine Datei fehlt.
	var names := _used_sfx_names()
	print("[SoundscapeRegression] used sfx: %s" % ", ".join(names))
	_check(names.size() >= 15, "found %d used sfx names" % names.size())
	for name in names:
		_check(audio.has_sample(name), "sfx '%s' has samples" % name)
		for path in audio.sample_paths(name):
			_check(ResourceLoader.exists(path) and load(path) is AudioStream, "sample loads: %s" % path)
	for name in audio.SFX_PRESETS:
		_check(audio.has_sample(name), "legacy preset '%s' now has a sample" % name)
	for name in audio.SFX_SAMPLES:
		for path in audio.sample_paths(name):
			_check(ResourceLoader.exists(path), "sample file exists: %s" % path)
	for key in ["lumo_theme", "hub", "cards", "memory", "connect_four", "quiz", "quiz_tension", "treasure",
			"treasure_discovery", "puzzle", "build", "settlement_day", "settlement_evening", "learning"]:
		var stream := load(gs.MUSIC_PATH % key) as AudioStream
		_check(stream != null and stream.get_length() >= 39.9 and stream.get_length() <= 90.5, "music %s loops 40-90 s" % key)
	for key in ["playroom", "island", "island_waterfall", "village_day", "village_evening", "stage", "studio"]:
		_check(load(gs.AMBIENCE_PATH % key) is AudioStream, "ambience %s exists" % key)
	var quiz_len := (load(gs.MUSIC_PATH % "quiz") as AudioStream).get_length()
	var tension_len := (load(gs.MUSIC_PATH % "quiz_tension") as AudioStream).get_length()
	_check(absf(quiz_len - tension_len) < 0.01, "synchronous layer has the same length")
	audio.play_sfx("ui_click")
	_check(audio.last_sfx_name == "ui_click", "play_sfx plays a sample")
	audio.play_sfx("does_not_exist")
	_check(audio.last_sfx_name == "ui_click", "unknown sfx stays silent (warning only)")
	_finish()


func _all_silent() -> bool:
	var s := _state()
	for deck in (s.music_decks as Array) + (s.ambience_decks as Array):
		if float(deck.db) > -79.0:
			return false
	return float(gs._ambience_layer.player.volume_db) <= -79.0


func _all_paused() -> bool:
	for player in [gs._music[0].player, gs._music[1].player, gs._ambience[0].player, gs._ambience[1].player,
			gs._ambience_layer.player]:
		if player.stream != null and player.playing and not player.stream_paused:
			return false
	return true


func _used_sfx_names() -> PackedStringArray:
	var found := {}
	var patterns: Array[RegEx] = []
	for source in ['play_sfx\\("([a-z_]+)"\\)', '[^a-z_]_sfx\\("([a-z_]+)"', '_sound\\("[a-z_0-9]+", "([a-z_]+)"\\)',
			'_sfx\\("([a-z_]+)" if', 'else "([a-z_]+)"\\)']:
		var regex := RegEx.new()
		regex.compile(source)
		patterns.append(regex)
	var stack: Array[String] = ["res://scripts"]
	while not stack.is_empty():
		var dir_path: String = stack.pop_back()
		if dir_path.ends_with("/tests"):
			continue
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		for sub in dir.get_directories():
			stack.append(dir_path.path_join(sub))
		for file in dir.get_files():
			if not file.ends_with(".gd"):
				continue
			var text := FileAccess.get_file_as_string(dir_path.path_join(file))
			if not (text.contains("play_sfx") or text.contains("_sfx(")):
				continue
			for line in text.split("\n"):
				if not (line.contains("play_sfx(") or line.contains("_sfx(") or line.contains("_sound(")):
					continue
				for regex in patterns:
					for hit in regex.search_all(line):
						found[hit.get_string(1)] = true
	var names := PackedStringArray()
	for name in found:
		names.append(str(name))
	return names


func _finish() -> void:
	print("[SoundscapeRegression] checks=%d failures=%d" % [checks, failures])
	quit(1 if failures > 0 else 0)
