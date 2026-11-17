## MobileSafeArea - Helper fuer UI-Overlays auf Handy.
##
## Anwendung:
##   MobileSafeArea.apply_safe_margins(control_node)
## Setzt offset_top/bottom/left/right entsprechend der Safe-Area
## (Statusbar, Nav-Bar, Camera-Notch). Holt die Werte aus MobileRuntime.
class_name MobileSafeArea
extends RefCounted


static func apply_safe_margins(control: Control) -> void:
	if not is_instance_valid(control) or not control.is_inside_tree():
		return
	# MobileRuntime is a scene-tree autoload, not an Engine native singleton.
	var runtime: Node = control.get_node_or_null("/root/MobileRuntime")
	if runtime == null or not runtime.has_method("get_safe_area_insets"):
		return
	var update := apply_safe_margins.bind(control)
	if not runtime.safe_area_changed.is_connected(update):
		runtime.safe_area_changed.connect(update)
		control.tree_exiting.connect(_disconnect.bind(runtime, update), CONNECT_ONE_SHOT)
	var rect: Rect2 = runtime.get_safe_area_insets()
	var physical := Vector2(control.get_window().size)
	if physical.x <= 0 or physical.y <= 0:
		return
	var factor := control.get_viewport().get_visible_rect().size / physical
	control.offset_left = rect.position.x * factor.x
	control.offset_top = rect.position.y * factor.y
	control.offset_right = -rect.size.x * factor.x
	control.offset_bottom = -rect.size.y * factor.y


static func _disconnect(runtime: Node, update: Callable) -> void:
	if is_instance_valid(runtime) and runtime.safe_area_changed.is_connected(update):
		runtime.safe_area_changed.disconnect(update)
