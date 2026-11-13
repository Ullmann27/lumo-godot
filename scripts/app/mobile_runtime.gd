## MobileRuntime (Autoload als 'MobileRuntime').
##
## Mobile-spezifische Initialisierung + Safe-Area-Helper.
##  - setzt sinnvolle Defaults (max_fps, low_processor_usage_mode)
##  - liefert Safe-Area fuer UI-Layout
##  - kennt die Display-Groesse + Aspect
extends Node

signal safe_area_changed

const ANDROID_SAFE_AREA = preload("res://scripts/app/android_safe_area.gd")
const DEFAULT_SAFE_INSET_TOP: float = 32.0
const DEFAULT_SAFE_INSET_BOTTOM: float = 48.0
const DEFAULT_SAFE_INSET_SIDE: float = 16.0

var screen_size: Vector2i = Vector2i.ZERO
var _android_safe_area_enabled := false
var _safe_area_observation: Dictionary = {}
var _safe_area_generation := 0
var _safe_area_request_id := 0
var _safe_area_request_pending := false
var _safe_area_poll_time := 0.0
var _application_paused := false
# A single asynchronous platform boundary is shared by every scene. Tests
# replace only this boundary, never the layout or cached-result validation.
var _safe_area_reader: Callable = ANDROID_SAFE_AREA.request


## Godot's Android getScreenDPI returns DisplayMetrics.densityDpi.
## UI dimensions are dp, not raw surface pixels. Desktop review defaults to 1.
func get_ui_density() -> float:
	var supplied: Variant = HostBridge.launch_options().get("displayDensity", null)
	if supplied is float or supplied is int:
		var density := float(supplied)
		if is_finite(density) and density > 0.0:
			return clampf(density, 0.75, 4.0)
	if OS.has_feature("android"):
		return clampf(float(DisplayServer.screen_get_dpi()) / 160.0, 0.75, 4.0)
	return 1.0


func _ready() -> void:
	Engine.max_fps = 60
	screen_size = get_window().size
	_android_safe_area_enabled = ANDROID_SAFE_AREA.supported()
	get_window().size_changed.connect(_window_size_changed)
	set_process(_android_safe_area_enabled)
	var rect: Rect2 = get_safe_area_insets()
	print("[Mobile] runtime ready screen:%s safe-area:%s" % [screen_size, rect])
	request_safe_area_refresh()


func requires_safe_area_observation() -> bool:
	return _android_safe_area_enabled


func safe_area_is_ready() -> bool:
	return not _android_safe_area_enabled or not get_safe_area_observation().is_empty()


func get_safe_area_observation() -> Dictionary:
	if not is_inside_tree() or _safe_area_observation.get("window_size") != get_window().size:
		return {}
	return _safe_area_observation.duplicate(true)


func _process(delta: float) -> void:
	if not _android_safe_area_enabled or _application_paused:
		return
	_safe_area_poll_time += delta
	if _safe_area_poll_time >= 0.20:
		_safe_area_poll_time = 0.0
		request_safe_area_refresh()


func request_safe_area_refresh() -> void:
	if not is_inside_tree() or not _android_safe_area_enabled or _application_paused or _safe_area_request_pending:
		return
	_safe_area_request_id += 1
	_safe_area_request_pending = true
	var completed := _accept_safe_area.bind(get_window().size, _safe_area_generation, _safe_area_request_id)
	if not _safe_area_reader.call(completed):
		_safe_area_request_pending = false


func _accept_safe_area(observed: Dictionary, requested_window: Vector2i, generation: int, request_id: int) -> void:
	# An old UI-thread result must neither replace a rotated View nor release a
	# newer request's pending flag. All cache/signal writes run on Godot's thread.
	if not is_inside_tree() or not _android_safe_area_enabled or _application_paused:
		return
	if generation != _safe_area_generation or request_id != _safe_area_request_id:
		return
	_safe_area_request_pending = false
	if requested_window != get_window().size:
		return
	if not _valid_observation(observed):
		if not _safe_area_observation.is_empty():
			_safe_area_observation.clear()
			safe_area_changed.emit()
		return
	var current := observed.duplicate(true)
	current["window_size"] = requested_window
	if current == _safe_area_observation:
		return
	_safe_area_observation = current
	print("[Mobile] actual Android View insets ", current)
	safe_area_changed.emit()


func _valid_observation(observed: Dictionary) -> bool:
	for key in ["view_size", "decor_size"]:
		if typeof(observed.get(key)) != TYPE_VECTOR2:
			return false
		var size: Vector2 = observed[key]
		if not size.is_finite() or size.x <= 0 or size.y <= 0:
			return false
	for key in ["render_rect", "system_insets", "insets"]:
		if typeof(observed.get(key)) != TYPE_RECT2:
			return false
		var rect: Rect2 = observed[key]
		if not rect.position.is_finite() or not rect.size.is_finite():
			return false
	var view: Vector2 = observed.view_size
	var insets: Rect2 = observed.insets
	return (observed.render_rect.has_area() and insets.position.x >= 0 and insets.position.y >= 0
		and insets.size.x >= 0 and insets.size.y >= 0
		and insets.position.x + insets.size.x < view.x
		and insets.position.y + insets.size.y < view.y)


func _invalidate_safe_area() -> void:
	_safe_area_generation += 1
	_safe_area_request_pending = false
	_safe_area_observation.clear()
	safe_area_changed.emit()


func _window_size_changed() -> void:
	if not is_inside_tree() or screen_size == get_window().size:
		return
	screen_size = get_window().size
	if _android_safe_area_enabled:
		_invalidate_safe_area()
		request_safe_area_refresh()


func _notification(what: int) -> void:
	if not is_inside_tree() or not _android_safe_area_enabled:
		return
	if what == NOTIFICATION_APPLICATION_PAUSED:
		_application_paused = true
		_invalidate_safe_area()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		_application_paused = false
		_invalidate_safe_area()
		request_safe_area_refresh()


func _exit_tree() -> void:
	_android_safe_area_enabled = false
	_safe_area_generation += 1
	_safe_area_request_pending = false
	if get_window().size_changed.is_connected(_window_size_changed):
		get_window().size_changed.disconnect(_window_size_changed)


## Liefert ein Rect2 mit den Safe-Area-Insets:
##   x = links, y = oben, width = rechts, height = unten, jeweils positive Pixel.
## Wenn die Plattform keine echten Werte liefert, kommt ein konservativer
## Default zurueck (Statusbar 32 px oben, Nav-Bar 48 px unten, 16 px Seiten).
func get_safe_area_insets() -> Rect2:
	var observed := get_safe_area_observation()
	if not observed.is_empty():
		var insets: Rect2 = observed.insets
		var factor: Vector2 = Vector2(get_window().size) / observed.view_size
		return Rect2(insets.position * factor, insets.size * factor)
	# DisplayServer.screen_get_usable_rect liefert auf Android die
	# nutzbare Flaeche relativ zum Bildschirm. Daraus rechnen wir Insets.
	var full: Vector2i = DisplayServer.screen_get_size()
	var usable: Rect2i = DisplayServer.screen_get_usable_rect()
	if full.x <= 0 or full.y <= 0:
		return Rect2(
			DEFAULT_SAFE_INSET_SIDE,
			DEFAULT_SAFE_INSET_TOP,
			DEFAULT_SAFE_INSET_SIDE,
			DEFAULT_SAFE_INSET_BOTTOM,
		)
	var left: float = float(usable.position.x)
	var top: float = float(usable.position.y)
	var right: float = float(full.x - (usable.position.x + usable.size.x))
	var bottom: float = float(full.y - (usable.position.y + usable.size.y))
	# Fallbacks falls Plattform 0 zurueckmeldet
	if top <= 0.0:
		top = DEFAULT_SAFE_INSET_TOP
	if bottom <= 0.0:
		bottom = DEFAULT_SAFE_INSET_BOTTOM
	return Rect2(left, top, right, bottom)
