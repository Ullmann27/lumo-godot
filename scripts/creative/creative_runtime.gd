extends RefCounted
## Shared landscape viewport and native safe-area handling for creative games.


static func enter(node: Node, density_layout: bool = false) -> Dictionary:
	var window := node.get_window()
	var tree := node.get_tree()
	var previous := {
		"scale": window.content_scale_size,
		"orientation": DisplayServer.screen_get_orientation(),
		"quit": tree.quit_on_go_back,
		"accept": tree.auto_accept_quit
	}
	node.set_meta("creative_density_layout", density_layout)
	if density_layout:
		_fit_density(node)
	else:
		window.content_scale_size = Vector2i(1280, 720)
	tree.quit_on_go_back = false
	tree.auto_accept_quit = false
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)
	return previous


static func restore(node: Node, previous: Dictionary) -> void:
	unwatch_safe_area(node)
	if previous.is_empty():
		return
	node.set_meta("creative_density_layout", false)
	node.get_window().content_scale_size = previous.scale
	node.get_tree().quit_on_go_back = previous.quit
	node.get_tree().auto_accept_quit = previous.accept
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(previous.orientation)


static func watch_safe_area(node: Node, layout: Callable) -> void:
	unwatch_safe_area(node)
	node.set_meta("creative_safe_area_callback", layout)
	MobileRuntime.safe_area_changed.connect(layout)


static func unwatch_safe_area(node: Node) -> void:
	if not node.has_meta("creative_safe_area_callback"):
		return
	var layout: Callable = node.get_meta("creative_safe_area_callback")
	if MobileRuntime.safe_area_changed.is_connected(layout):
		MobileRuntime.safe_area_changed.disconnect(layout)
	node.remove_meta("creative_safe_area_callback")


static func safe_area(node: Node, control: Control) -> void:
	if not node.is_inside_tree() or not is_instance_valid(control) or not control.is_inside_tree():
		return
	if bool(node.get_meta("creative_density_layout", false)):
		_fit_density(node)
	var physical := Vector2(node.get_window().size)
	var logical := node.get_viewport().get_visible_rect().size
	if physical.x <= 0 or physical.y <= 0:
		return
	var insets := Rect2()
	if OS.has_feature("mobile") or MobileRuntime.requires_safe_area_observation():
		insets = MobileRuntime.get_safe_area_insets()
		# A real View observation already accounts for Android padding. The
		# engine's origin-zero rectangle must not add a false right/bottom edge.
		if not MobileRuntime.requires_safe_area_observation():
			var screen := DisplayServer.screen_get_size()
			var safe := DisplayServer.get_display_safe_area()
			if screen.x > 0 and screen.y > 0 and safe.has_area():
				insets.position.x = maxf(insets.position.x, safe.position.x)
				insets.position.y = maxf(insets.position.y, safe.position.y)
				insets.size.x = maxf(insets.size.x, screen.x - safe.end.x)
				insets.size.y = maxf(insets.size.y, screen.y - safe.end.y)
	control.visible = MobileRuntime.safe_area_is_ready()
	var factor := logical / physical
	control.offset_left = insets.position.x * factor.x
	control.offset_top = insets.position.y * factor.y
	control.offset_right = -insets.size.x * factor.x
	control.offset_bottom = -insets.size.y * factor.y


static func _fit_density(node: Node) -> void:
	var window := node.get_window()
	var density: float = MobileRuntime.get_ui_density()
	var logical := Vector2i(Vector2(window.size) / density)
	if logical.x > 0 and logical.y > 0 and window.content_scale_size != logical:
		window.content_scale_size = logical
