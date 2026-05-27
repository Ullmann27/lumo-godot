## SettingsStore (Autoload als 'SettingsStore').
##
## Persistenz fuer Quality-Profile + Audio-Toggle. Liest beim Start aus
## user://settings.cfg, schreibt nach jedem set_*.
##
## API:
##   SettingsStore.load_now()             # passiert auto im _ready
##   SettingsStore.get_profile() -> String   # "low"|"medium"|"high"
##   SettingsStore.set_profile(name)
##   SettingsStore.is_audio_muted() -> bool
##   SettingsStore.set_audio_muted(b)
extends Node

const FILE_PATH: String = "user://settings.cfg"
const SECTION: String = "lumo"
const DEFAULT_PROFILE: String = "medium"

var _profile: String = DEFAULT_PROFILE
var _audio_muted: bool = false
var _loaded: bool = false


func _ready() -> void:
	load_now()


func load_now() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(FILE_PATH) == OK:
		_profile = cfg.get_value(SECTION, "profile", DEFAULT_PROFILE)
		_audio_muted = cfg.get_value(SECTION, "audio_muted", false)
		print("[Settings] loaded profile:%s audio_muted:%s" % [_profile, _audio_muted])
	else:
		print("[Settings] no settings.cfg yet, defaults used")
	_loaded = true


func save_now() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value(SECTION, "profile", _profile)
	cfg.set_value(SECTION, "audio_muted", _audio_muted)
	var err: Error = cfg.save(FILE_PATH)
	if err != OK:
		push_warning("[Settings] save failed: %d" % err)


func get_profile() -> String:
	return _profile


func set_profile(name: String) -> void:
	if name == _profile:
		return
	_profile = name
	save_now()


func is_audio_muted() -> bool:
	return _audio_muted


func set_audio_muted(b: bool) -> void:
	if b == _audio_muted:
		return
	_audio_muted = b
	save_now()
