extends RefCounted
## Shared landscape viewport and native safe-area handling for creative games.


static func enter(node: Node) -> Dictionary:
	var window := node.get_window()
	var tree := node.get_tree()
	var previous := {
		"scale": window.content_scale_size,
		"orientation": DisplayServer.screen_get_orientation(),
		"quit": tree.quit_on_go_back,
		"accept": tree.auto_accept_quit
	}
	window.content_scale_size = Vector2i(1280, 720)
	tree.quit_on_go_back = false
	tree.auto_accept_quit = false
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)
	return previous


static func restore(node: Node, previous: Dictionary) -> void:
	if previous.is_empty():
		return
	node.get_window().content_scale_size = previous.scale
	node.get_tree().quit_on_go_back = previous.quit
	node.get_tree().auto_accept_quit = previous.accept
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(previous.orientation)


static func safe_area(node: Node, control: Control) -> void:
	var physical := Vector2(node.get_window().size)
	var logical := node.get_viewport().get_visible_rect().size
	if physical.x <= 0 or physical.y <= 0:
		return
	var insets := Rect2()
	if OS.has_feature("mobile"):
		insets = MobileRuntime.get_safe_area_insets()
		var screen := DisplayServer.screen_get_size()
		var safe := DisplayServer.get_display_safe_area()
		if screen.x > 0 and screen.y > 0 and safe.has_area():
			insets.position.x = maxf(insets.position.x, safe.position.x)
			insets.position.y = maxf(insets.position.y, safe.position.y)
			insets.size.x = maxf(insets.size.x, screen.x - safe.end.x)
			insets.size.y = maxf(insets.size.y, screen.y - safe.end.y)
	var factor := logical / physical
	control.offset_left = insets.position.x * factor.x
	control.offset_top = insets.position.y * factor.y
	control.offset_right = -insets.size.x * factor.x
	control.offset_bottom = -insets.size.y * factor.y
