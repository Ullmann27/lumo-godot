## MobileSafeArea - Helper fuer UI-Overlays auf Handy.
##
## Anwendung:
##   MobileSafeArea.apply_safe_margins(control_node)
## Setzt offset_top/bottom/left/right entsprechend der Safe-Area
## (Statusbar, Nav-Bar, Camera-Notch). Holt die Werte aus MobileRuntime.
class_name MobileSafeArea
extends RefCounted


static func apply_safe_margins(control: Control) -> void:
	if control == null:
		return
	if not Engine.has_singleton("MobileRuntime"):
		return
	var runtime: Node = Engine.get_singleton("MobileRuntime")
	if runtime == null or not runtime.has_method("get_safe_area_insets"):
		return
	var rect: Rect2 = runtime.get_safe_area_insets()
	control.offset_left = rect.position.x
	control.offset_top = rect.position.y
	control.offset_right = -rect.size.x
	control.offset_bottom = -rect.size.y
