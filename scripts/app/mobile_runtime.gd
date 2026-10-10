## MobileRuntime (Autoload als 'MobileRuntime').
##
## Mobile-spezifische Initialisierung + Safe-Area-Helper.
##  - setzt sinnvolle Defaults (max_fps, low_processor_usage_mode)
##  - liefert Safe-Area fuer UI-Layout
##  - kennt die Display-Groesse + Aspect
extends Node

const DEFAULT_SAFE_INSET_TOP: float = 32.0
const DEFAULT_SAFE_INSET_BOTTOM: float = 48.0
const DEFAULT_SAFE_INSET_SIDE: float = 16.0

var screen_size: Vector2i = Vector2i.ZERO


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
	screen_size = DisplayServer.window_get_size()
	var rect: Rect2 = get_safe_area_insets()
	print("[Mobile] runtime ready screen:%s safe-area:%s" % [screen_size, rect])


## Liefert ein Rect2 mit den Safe-Area-Insets:
##   x = links, y = oben, width = -rechts (Inset von rechts), height = -unten
## Wenn die Plattform keine echten Werte liefert, kommt ein konservativer
## Default zurueck (Statusbar 32 px oben, Nav-Bar 48 px unten, 16 px Seiten).
func get_safe_area_insets() -> Rect2:
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
