## GameSoundscape (Autoload als 'GameSoundscape', nach AudioManager).
##
## Spielt Musik und Atmosphäre passend zur Szene, ohne dass die Spiele etwas
## aufrufen müssen. Erkennung: EventBus.scene_changed (SceneRouter.goto und
## goto_loaded) und zusätzlich SceneTree.scene_changed über den Pfad der
## aktuellen Szene (falls eine Szene ohne Router gewechselt wird).
##
## - weiches Überblenden (FADE_SECONDS) zwischen Stücken und Atmosphären
## - Ducking: Musik/Atmosphäre sinken, solange Lumo spricht (AudioManager.play_voice,
##   Sprachzustand der Lern-Szenen) oder ein Spiel duck() aufruft
## - Pause im Hintergrund (Android: App pausiert / Fokus weg)
## - Stumm: AudioManager-Stumm, stummer Master-Bus oder Startoption soundEnabled=false
## - Lautstärke: Musik-/Effektregler aus user://kart_preferences.cfg (wie Lumo Lauf)
##   mal eigene Regler (set_music_volume / set_ambience_volume)
## - Kart (Route "kart") und Lumo Lauf (Route "run") haben eigene Musik: dort
##   blendet das System nur die eigene Musik aus und tut sonst nichts.
##
## Öffentliche Feinsteuerung (siehe docs/KLANGWELT.md):
##   GameSoundscape.set_layer("tension"|"discovery", on)
##   GameSoundscape.set_layer_level("waterfall", 0..1)
##   GameSoundscape.stinger("treasure_found")
##   GameSoundscape.set_variant("evening"|"day"|"")
##   GameSoundscape.duck(on) / duck_for(seconds)
extends Node

signal route_changed(route: String, music: String, ambience: String)

const MUSIC_PATH: String = "res://assets/audio/klangwelt/music/%s.ogg"
const AMBIENCE_PATH: String = "res://assets/audio/klangwelt/ambience/%s.ogg"
const PREFERENCES: String = "user://kart_preferences.cfg"
const OWN_SETTINGS: String = "user://lumo_soundscape.cfg"
const OWN_AUDIO_ROUTES: Array[String] = ["kart", "run"]
const FADE_SECONDS: float = 1.6
const MUSIC_DB: float = -12.0
const AMBIENCE_DB: float = -6.0
const SILENT_DB: float = -80.0
const DUCK_LEVEL: float = 0.32
const PAUSE_LEVEL: float = 0.5
const STINGER_DIP: float = 0.55
const LEARNING: Dictionary = {"music": "learning", "music_db": -4.0}
const HUB: Dictionary = {"music": "hub", "ambience": "playroom", "ambience_db": -4.0}
const THEME: Dictionary = {"music": "lumo_theme"}
## Route -> Stück, Atmosphäre, synchrone Schichten, Abend-Variante.
const ROUTES: Dictionary = {
	"boot": THEME,
	"intro": THEME,
	"home": THEME,
	"parent": {"music": "lumo_theme", "music_db": -6.0},
	"games": HUB,
	"jump": HUB,
	"stars": HUB,
	"cards": {"music": "cards", "ambience": "playroom"},
	"memory": {"music": "memory", "ambience": "playroom"},
	"chess": {"music": "memory", "ambience": "playroom", "music_db": -3.0},
	"connect_four": {"music": "connect_four", "ambience": "playroom"},
	"quiz": {"music": "quiz", "ambience": "studio", "layers": ["tension"]},
	"treasure": {
		"music": "treasure", "ambience": "island", "layers": ["discovery"],
		"ambience_layer": "waterfall",
	},
	"rhythm": {"music": "", "ambience": "stage", "ambience_db": 2.0},
	"puzzle": {"music": "puzzle", "ambience": "playroom", "ambience_db": -3.0},
	"build": {"music": "build"},
	"settlement": {
		"music": "settlement_day", "ambience": "village_day",
		"evening_music": "settlement_evening", "evening_ambience": "village_evening",
	},
	"learning": LEARNING,
	"tutor": LEARNING,
	"holo": LEARNING,
	"learn": LEARNING,
	"reading_hub": LEARNING,
	"alphabet": LEARNING,
	"word_picture_match": LEARNING,
	"sound_letter_match": LEARNING,
	"word_build": LEARNING,
	"learn_old": LEARNING,
}
## Synchrone Schicht -> Datei (gleiche Länge und gleiches Tempo wie das Grundstück).
const LAYER_FILES: Dictionary = {"tension": "quiz_tension", "discovery": "treasure_discovery"}
const AMBIENCE_LAYER_FILES: Dictionary = {"waterfall": "island_waterfall"}
const DEFAULT_LAYER_LEVEL: Dictionary = {"waterfall": 0.3}


class Deck:
	extends RefCounted
	var player: AudioStreamPlayer
	var key: String = ""
	var level: float = 0.0
	var target: float = 0.0
	var sync: AudioStreamSynchronized
	var layer_names: Array[String] = []


var auto_events: bool = true
var auto_ui_clicks: bool = true
var route: String = ""
var music_key: String = ""
var ambience_key: String = ""
var variant_override: String = ""
var muted: bool = false
var host_sound_enabled: bool = true
var backgrounded: bool = false
var duck_level: float = 1.0
var pause_level: float = 1.0
var stinger_level: float = 1.0
var music_volume: float = 1.0
var effects_volume: float = 1.0
var own_music_volume: float = 1.0
var own_ambience_volume: float = 1.0
var layer_targets: Dictionary = {}
var layer_levels: Dictionary = {}
var _music: Array[Deck] = []
var _ambience: Array[Deck] = []
var _ambience_layer: Deck
var _streams: Dictionary = {}
var _manual_duck: bool = false
var _duck_until: float = -1.0
var _stinger_until: float = -1.0
var _layer_until: Dictionary = {}
var _clock: float = 0.0
var _observe_clock: float = 0.0
var _seen: Dictionary = {}
var _route_entry: Dictionary = {}
var _was_silent: bool = false
var _auto_off: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for index in range(2):
		_music.append(_deck("Music%d" % index))
		_ambience.append(_deck("Ambience%d" % index))
	_ambience_layer = _deck("AmbienceLayer")
	_load_own_settings()
	_refresh_settings()
	EventBus.scene_changed.connect(_on_scene_changed)
	get_tree().scene_changed.connect(_on_tree_scene_changed)
	get_tree().node_added.connect(_on_node_added)
	if AudioManager.has_signal("voice_started"):
		AudioManager.voice_started.connect(func(seconds: float): duck_for(seconds + 0.3))
	_on_tree_scene_changed.call_deferred()
	print("[Soundscape] ready")


func _deck(label: String) -> Deck:
	var deck := Deck.new()
	deck.player = AudioStreamPlayer.new()
	deck.player.name = label
	deck.player.bus = "Master"
	deck.player.volume_db = SILENT_DB
	deck.player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(deck.player)
	return deck


# ── Öffentliche API ───────────────────────────────────────────────────────

## Route setzen (macht das System automatisch; öffentlich für Tests/Sonderfälle).
func enter_route(route_id: String) -> void:
	if route_id.is_empty() or route_id == "loading":
		return
	var changed := route_id != route
	route = route_id
	_refresh_settings()
	if changed:
		_seen.clear()
		layer_targets.clear()
		_layer_until.clear()
		_manual_duck = false
	_apply_route()


## Automatische Ereigniserkennung für eine Route abschalten, sobald das Spiel
## selbst stinger()/play_sfx() aufruft (sonst klingt es doppelt).
func set_auto_events(route_id: String, on: bool) -> void:
	if on:
		_auto_off.erase(route_id)
	else:
		_auto_off[route_id] = true


func is_own_audio_route(route_id: String = route) -> bool:
	return route_id in OWN_AUDIO_ROUTES


## Synchrone Schicht des laufenden Stücks ein-/ausblenden ("tension", "discovery").
func set_layer(layer: String, on: bool) -> void:
	set_layer_level(layer, 1.0 if on else 0.0)


## Pegel einer Schicht 0..1 (auch "waterfall" für die Atmosphäre der Insel).
func set_layer_level(layer: String, level: float) -> void:
	layer_targets[layer] = clampf(level, 0.0, 1.0)
	_layer_until.erase(layer)


## Schicht für einige Sekunden einblenden, danach von selbst wieder aus.
func pulse_layer(layer: String, seconds: float) -> void:
	layer_targets[layer] = 1.0
	_layer_until[layer] = _clock + seconds


## Kurzes Ereignis mit Klang (AudioManager-Ton), Musik weicht kurz zurück.
func stinger(sound: String) -> void:
	if _silenced() or is_own_audio_route():
		return
	AudioManager.play_sfx(sound)
	_stinger_until = _clock + (2.4 if sound in ["treasure_found", "level_up", "celebrate", "applause"] else 1.2)


## "evening" / "day" erzwingen; "" = nach Uhrzeit (Abend ab 18 Uhr bis 6 Uhr).
func set_variant(variant: String) -> void:
	variant_override = variant
	_apply_route()


func duck(on: bool) -> void:
	_manual_duck = on


func duck_for(seconds: float) -> void:
	_duck_until = maxf(_duck_until, _clock + seconds)


func set_music_volume(linear: float) -> void:
	own_music_volume = clampf(linear, 0.0, 1.0)
	_save_own_settings()


func set_ambience_volume(linear: float) -> void:
	own_ambience_volume = clampf(linear, 0.0, 1.0)
	_save_own_settings()


## Hintergrund-Zustand (Android meldet ihn über Notifications; öffentlich für Tests).
func set_backgrounded(on: bool) -> void:
	backgrounded = on
	_apply_pause_state()


## Zustand für Tests und Diagnose.
func debug_state() -> Dictionary:
	var active_music := _active(_music)
	var active_amb := _active(_ambience)
	return {
		"route": route,
		"music": music_key,
		"ambience": ambience_key,
		"music_level": active_music.level if active_music != null else 0.0,
		"ambience_level": active_amb.level if active_amb != null else 0.0,
		"music_db": active_music.player.volume_db if active_music != null else SILENT_DB,
		"ambience_db": active_amb.player.volume_db if active_amb != null else SILENT_DB,
		"music_decks": _music.map(func(d: Deck): return {"key": d.key, "level": d.level, "target": d.target,
			"playing": d.player.playing, "paused": d.player.stream_paused, "db": d.player.volume_db}),
		"ambience_decks": _ambience.map(func(d: Deck): return {"key": d.key, "level": d.level,
			"target": d.target, "playing": d.player.playing, "paused": d.player.stream_paused,
			"db": d.player.volume_db}),
		"ambience_layer": _ambience_layer.key,
		"layers": layer_levels.duplicate(),
		"silenced": _silenced(),
		"backgrounded": backgrounded,
		"duck": duck_level,
	}


## Ein Zeitschritt (wird von _process aufgerufen; Tests können ihn direkt nutzen).
func step(delta: float) -> void:
	_clock += delta
	var silent := _silenced()
	if silent != _was_silent:
		_was_silent = silent
		_apply_pause_state()
	_update_levels(delta)
	_observe_clock += delta
	if _observe_clock >= 0.1:
		_observe_clock = 0.0
		_observe_scene()
	_mix()


# ── Szenen-Erkennung ──────────────────────────────────────────────────────

func _on_scene_changed(_from: String, to: String) -> void:
	enter_route(to)


func _on_tree_scene_changed() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var found := _route_for_path(scene.scene_file_path)
	if not found.is_empty():
		enter_route(found)


func _route_for_path(path: String) -> String:
	if path.is_empty():
		return ""
	if path == str(SceneRouter.SCENES.get(SceneRouter.current_scene_id, "")):
		return SceneRouter.current_scene_id
	for id in SceneRouter.SCENES:
		if str(SceneRouter.SCENES[id]) == path:
			return str(id)
	return ""


func _evening() -> bool:
	if variant_override == "evening":
		return true
	if variant_override == "day":
		return false
	var hour := int(Time.get_datetime_dict_from_system().get("hour", 12))
	return hour >= 18 or hour < 6


func _apply_route() -> void:
	if is_own_audio_route():
		_route_entry = {}
		_switch(_music, "", MUSIC_PATH, [])
		_switch(_ambience, "", AMBIENCE_PATH, [])
		_set_ambience_layer("")
		music_key = ""
		ambience_key = ""
		route_changed.emit(route, "", "")
		return
	if not ROUTES.has(route):
		return  # unbekannte Route: laufende Musik bleibt einfach stehen
	_route_entry = ROUTES[route]
	var evening := _evening() and _route_entry.has("evening_music")
	music_key = str(_route_entry.get("evening_music" if evening else "music", ""))
	ambience_key = str(_route_entry.get("evening_ambience" if evening else "ambience", ""))
	var layers: Array[String] = []
	for layer in _route_entry.get("layers", []):
		layers.append(str(layer))
	_switch(_music, music_key, MUSIC_PATH, layers)
	_switch(_ambience, ambience_key, AMBIENCE_PATH, [])
	_set_ambience_layer(str(_route_entry.get("ambience_layer", "")))
	route_changed.emit(route, music_key, ambience_key)


func _switch(decks: Array[Deck], key: String, pattern: String, layers: Array[String]) -> void:
	var active := _active(decks)
	if active != null and active.key == key and not key.is_empty():
		active.target = 1.0
		return
	for deck in decks:
		deck.target = 0.0
	if key.is_empty():
		return
	var free_deck: Deck = decks[0] if decks[0] != active else decks[1]
	var base := _stream(pattern % key)
	if base == null:
		return
	free_deck.key = key
	free_deck.level = 0.0
	free_deck.target = 1.0
	free_deck.layer_names = layers
	free_deck.sync = null
	if layers.is_empty():
		free_deck.player.stream = base
	else:
		var sync := AudioStreamSynchronized.new()
		sync.stream_count = 1 + layers.size()
		sync.set_sync_stream(0, base)
		sync.set_sync_stream_volume(0, 0.0)
		for index in range(layers.size()):
			var layer_stream := _stream(MUSIC_PATH % str(LAYER_FILES.get(layers[index], "")))
			sync.set_sync_stream(index + 1, layer_stream)
			sync.set_sync_stream_volume(index + 1, SILENT_DB)
			layer_levels[layers[index]] = 0.0
		free_deck.sync = sync
		free_deck.player.stream = sync
	free_deck.player.volume_db = SILENT_DB
	free_deck.player.play()
	free_deck.player.stream_paused = _paused_now()


func _set_ambience_layer(layer: String) -> void:
	var file := str(AMBIENCE_LAYER_FILES.get(layer, ""))
	if file.is_empty():
		_ambience_layer.target = 0.0
		return
	if _ambience_layer.key != layer:
		var stream := _stream(AMBIENCE_PATH % file)
		if stream == null:
			return
		_ambience_layer.key = layer
		_ambience_layer.level = 0.0
		_ambience_layer.player.stream = stream
		_ambience_layer.player.play()
		_ambience_layer.player.stream_paused = _paused_now()
	_ambience_layer.target = 1.0
	if not layer_targets.has(layer):
		layer_targets[layer] = float(DEFAULT_LAYER_LEVEL.get(layer, 0.5))
	layer_levels[layer] = float(layer_levels.get(layer, layer_targets[layer]))


func _stream(path: String) -> AudioStream:
	if _streams.has(path):
		return _streams[path]
	if not ResourceLoader.exists(path):
		push_warning("[Soundscape] missing: %s" % path)
		return null
	var stream := load(path) as AudioStreamOggVorbis
	if stream == null:
		return null
	stream.loop = true
	_streams[path] = stream
	return stream


func _active(decks: Array[Deck]) -> Deck:
	var best: Deck = null
	for deck in decks:
		if deck.target > 0.0 and not deck.key.is_empty():
			best = deck
	return best


# ── Pegel ─────────────────────────────────────────────────────────────────

func _update_levels(delta: float) -> void:
	var fade := delta / FADE_SECONDS
	for deck in _music + _ambience + [_ambience_layer]:
		deck.level = move_toward(deck.level, deck.target, fade)
		if deck.level <= 0.0 and deck.target <= 0.0 and deck.player.playing:
			deck.player.stop()
			deck.key = ""
	var speaking := _manual_duck or _clock < _duck_until or _scene_speaking() or AudioManager.is_voice_playing()
	var duck_target := DUCK_LEVEL if speaking else 1.0
	duck_level = move_toward(duck_level, duck_target, delta * (3.0 if speaking else 0.9))
	var paused := _scene_paused()
	pause_level = move_toward(pause_level, PAUSE_LEVEL if paused else 1.0, delta * 1.2)
	var dipped := _clock < _stinger_until
	stinger_level = move_toward(stinger_level, STINGER_DIP if dipped else 1.0, delta * (4.0 if dipped else 0.8))
	for layer in _layer_until.keys():
		if _clock >= float(_layer_until[layer]):
			layer_targets[layer] = 0.0
			_layer_until.erase(layer)
	for layer in layer_targets:
		var current := float(layer_levels.get(layer, 0.0))
		layer_levels[layer] = move_toward(current, float(layer_targets[layer]), delta / 1.2)


func _mix() -> void:
	var silent := _silenced()
	var route_music_db := float(_route_entry.get("music_db", 0.0))
	var route_amb_db := float(_route_entry.get("ambience_db", 0.0))
	var common := duck_level * pause_level
	for deck in _music:
		var lin := deck.level * music_volume * own_music_volume * common * stinger_level
		deck.player.volume_db = _db(lin, MUSIC_DB + route_music_db, silent)
		if deck.sync != null:
			for index in range(deck.layer_names.size()):
				var level := float(layer_levels.get(deck.layer_names[index], 0.0))
				deck.sync.set_sync_stream_volume(index + 1, linear_to_db(maxf(level, 0.0001)))
	for deck in _ambience:
		var lin := deck.level * music_volume * own_ambience_volume * (0.5 + 0.5 * common)
		deck.player.volume_db = _db(lin, AMBIENCE_DB + route_amb_db, silent)
	var layer_level := float(layer_levels.get(_ambience_layer.key, 0.0))
	var amb_lin := _ambience_layer.level * layer_level * music_volume * own_ambience_volume * (0.5 + 0.5 * common)
	_ambience_layer.player.volume_db = _db(amb_lin, AMBIENCE_DB + route_amb_db, silent)


func _db(lin: float, base_db: float, silent: bool) -> float:
	if silent or lin <= 0.001:
		return SILENT_DB
	return maxf(SILENT_DB, base_db + linear_to_db(lin))


func _silenced() -> bool:
	muted = AudioManager.is_muted() or AudioServer.is_bus_mute(0)
	return muted or not host_sound_enabled


func _paused_now() -> bool:
	return backgrounded or _silenced()


func _apply_pause_state() -> void:
	var pause := _paused_now()
	for deck in _music + _ambience + [_ambience_layer]:
		if deck.player.stream != null:
			deck.player.stream_paused = pause


# ── Einstellungen ─────────────────────────────────────────────────────────

func _refresh_settings() -> void:
	var options: Dictionary = {}
	options.merge(SceneRouter.launch_options, true)
	options.merge(HostBridge.launch_options(), true)
	var sound: Variant = options.get("soundEnabled", true)
	host_sound_enabled = not (sound == false or str(sound).to_lower() in ["false", "0", "off", "no"])
	var config := ConfigFile.new()
	if config.load(PREFERENCES) == OK:
		music_volume = clampf(float(config.get_value("race", "music_volume", 1.0)), 0.0, 1.0)
		effects_volume = clampf(float(config.get_value("race", "effects_volume", 1.0)), 0.0, 1.0)
		if AudioManager.has_method("set_sfx_volume"):
			AudioManager.set_sfx_volume(effects_volume)
	_apply_pause_state()


func _load_own_settings() -> void:
	var config := ConfigFile.new()
	if config.load(OWN_SETTINGS) == OK:
		own_music_volume = clampf(float(config.get_value("soundscape", "music_volume", 1.0)), 0.0, 1.0)
		own_ambience_volume = clampf(float(config.get_value("soundscape", "ambience_volume", 1.0)), 0.0, 1.0)


func _save_own_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("soundscape", "music_volume", own_music_volume)
	config.set_value("soundscape", "ambience_volume", own_ambience_volume)
	config.save(OWN_SETTINGS)


# ── Laufzeit ──────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	step(delta)


## Beim Beenden alle Wiedergaben lösen, damit der Audio-Thread keine
## Stream-Ressourcen über das Programmende hinaus festhält.
func release_audio() -> void:
	for deck in _music + _ambience + [_ambience_layer]:
		if deck == null:
			continue
		deck.player.stop()
		deck.player.stream = null
		deck.sync = null
		deck.key = ""
		deck.level = 0.0
		deck.target = 0.0
	_streams.clear()


func _exit_tree() -> void:
	release_audio()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_PREDELETE:
			release_audio()
		NOTIFICATION_APPLICATION_PAUSED:
			set_backgrounded(true)
		NOTIFICATION_APPLICATION_RESUMED:
			set_backgrounded(false)
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			if OS.has_feature("mobile"):
				set_backgrounded(true)
		NOTIFICATION_APPLICATION_FOCUS_IN:
			if OS.has_feature("mobile"):
				set_backgrounded(false)


# ── Beobachtung der Spiele (ohne Eingriff in deren Dateien) ───────────────

func _scene() -> Node:
	return get_tree().current_scene if is_inside_tree() else null


func _scene_speaking() -> bool:
	var scene := _scene()
	if scene == null:
		return false
	var state: Variant = scene.get("_speech_state")
	return state is String and state in ["preparing", "playing"]


func _scene_paused() -> bool:
	var scene := _scene()
	if scene == null or is_own_audio_route():
		return false
	if scene.get("paused") == true:
		return true
	var state: Variant = scene.get("_state")
	return state is Dictionary and state.get("paused", false) == true


## Erkennt typische Spielereignisse aus dem öffentlichen Zustand der Szenen.
## Fehlt eine Eigenschaft (Spiel umgebaut), passiert einfach nichts.
func _observe_scene() -> void:
	if not auto_events or is_own_audio_route() or _auto_off.has(route):
		return
	var scene := _scene()
	if scene == null:
		return
	match route:
		"rhythm":
			var model: Variant = scene.get("model")
			if model is Object:
				var cheer: Variant = (model as Object).get("last_cheer")
				if cheer is int and _changed("cheer", cheer) and cheer > 0:
					stinger("applause")
		"treasure":
			var model: Variant = scene.get("model")
			if model is Object:
				var found: Variant = (model as Object).get("found")
				if found is Array and _grew("found", found.size()):
					stinger("treasure_found")
					pulse_layer("discovery", 20.0)
				var discoveries: Variant = (model as Object).get("discoveries")
				if discoveries is Array and _grew("discoveries", discoveries.size()):
					pulse_layer("discovery", 12.0)
		"quiz":
			var state: Variant = scene.get("_state")
			if state is Dictionary and not state.is_empty():
				var revealed := bool(state.get("revealed", false))
				var asking := (
					bool(state.get("canSelect", false)) and not revealed
					and not bool(state.get("paused", false)) and not bool(state.get("gameOver", false))
				)
				if not _layer_until.has("tension"):
					layer_targets["tension"] = 1.0 if asking else 0.0
				if _changed("revealed", revealed) and revealed and _seen.has("revealed_ready"):
					var right: bool = state.get("selected") != null and state.get("selected") == state.get("correctIndex")
					stinger("answer_correct" if right else "answer_wrong")
				_seen["revealed_ready"] = true
		"memory":
			var state: Variant = scene.get("_state")
			if state is Dictionary:
				var complete := bool(state.get("complete", false))
				if _changed("complete", complete) and complete and _seen.has("complete_ready"):
					stinger("celebrate")
				_seen["complete_ready"] = true
		"connect_four":
			var discs: Variant = scene.get("_discs")
			if discs is Array and _grew("discs", discs.size()):
				AudioManager.play_sfx("piece_drop")


func _changed(key: String, value: Variant) -> bool:
	var had := _seen.has(key)
	var before: Variant = _seen.get(key)
	_seen[key] = value
	return had and before != value


func _grew(key: String, size: int) -> bool:
	var had := _seen.has(key)
	var before := int(_seen.get(key, size))
	_seen[key] = size
	return had and size > before


# ── Weiche Klicks für Knöpfe ohne eigenen Ton ─────────────────────────────

func _on_node_added(node: Node) -> void:
	if not auto_ui_clicks or not (node is BaseButton):
		return
	var button := node as BaseButton
	if not button.pressed.is_connected(_on_button_pressed):
		button.pressed.connect(_on_button_pressed)


func _on_button_pressed() -> void:
	# Erst am Ende des Frames entscheiden: Hat das Spiel selbst einen Ton gespielt,
	# bleibt der Klick weg (kein Doppelklang).
	_click_if_quiet.call_deferred(Time.get_ticks_msec())


func _click_if_quiet(pressed_msec: int) -> void:
	if is_own_audio_route() or _silenced() or not auto_ui_clicks:
		return
	if AudioManager.last_sfx_msec >= pressed_msec - 30:
		return
	AudioManager.play_sfx("ui_click")
