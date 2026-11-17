extends RefCounted
## Read-only Android window observations. No window mode or system-bar mutation.
## Godot 4.6 can report a zero safe-area origin when Android enforces edge-to-edge
## independently of Godot's own flag. Read the actual View insets in that case.


static func supported() -> bool:
	if not OS.has_feature("android"):
		return false
	if not Engine.has_singleton("AndroidRuntime") or not Engine.has_singleton("JavaClassWrapper"):
		return false
	var wrapper: Object = Engine.get_singleton("JavaClassWrapper")
	var version: Variant = wrapper.call("wrap", "android.os.Build$VERSION")
	if version == null:
		return false
	var sdk: Variant = version.get("SDK_INT")
	return sdk != null and int(sdk) >= 30


static func request(completed: Callable) -> bool:
	var runtime: Object = Engine.get_singleton("AndroidRuntime")
	var wrapper: Object = Engine.get_singleton("JavaClassWrapper")
	var activity: Variant = runtime.call("getActivity")
	if activity == null:
		return false
	# All View/Window/Insets access stays on Android's UI thread. The callback
	# only schedules a result; the shared cache and Controls stay on Godot's thread.
	var read := func():
		var result: Dictionary = _read_window(wrapper, activity)
		if completed.is_valid():
			completed.call_deferred(result)
	var runnable: Variant = runtime.call("createRunnableFromGodotCallable", read)
	if runnable == null:
		return false
	activity.call("runOnUiThread", runnable)
	return wrapper.call("get_exception") == null


static func _java(wrapper: Object, object: Object, method: String, arguments: Array = []) -> Variant:
	if object == null:
		return null
	var result: Variant = object.callv(method, arguments)
	# get_exception belongs to JavaClassWrapper, not the returned JavaObject.
	if wrapper.call("get_exception") != null:
		return null
	return result


static func _public_edges(wrapper: Object, object: Object) -> Dictionary:
	var type: Variant = _java(wrapper, object, "getClass")
	if type == null:
		return {}
	var edges := {}
	for name in ["left", "top", "right", "bottom"]:
		# Insets and Rect expose public instance fields. Godot's Java wrapper
		# only exposes static fields directly; public reflection reads these.
		var field: Variant = _java(wrapper, type, "getField", [name])
		var value: Variant = _java(wrapper, field, "getInt", [object])
		if value == null:
			return {}
		edges[name] = float(value)
	return edges


static func _read_window(wrapper: Object, activity: Object) -> Dictionary:
	var window: Variant = _java(wrapper, activity, "getWindow")
	var decor: Variant = _java(wrapper, window, "getDecorView")
	var root_insets: Variant = _java(wrapper, decor, "getRootWindowInsets")
	var engine: Variant = _java(wrapper, activity, "getGodot")
	var render: Variant = _java(wrapper, engine, "getRenderView")
	var view: Variant = _java(wrapper, render, "getView")
	var attached: Variant = _java(wrapper, view, "isAttachedToWindow")
	# Godot's Android JNI wrapper may expose jboolean as integer 0/1.
	var is_attached: bool = ((typeof(attached) == TYPE_BOOL and attached == true)
		or (typeof(attached) == TYPE_INT and attached == 1))
	if root_insets == null or view == null or not is_attached:
		return {}
	var width: Variant = _java(wrapper, view, "getWidth")
	var height: Variant = _java(wrapper, view, "getHeight")
	var decor_width: Variant = _java(wrapper, decor, "getWidth")
	var decor_height: Variant = _java(wrapper, decor, "getHeight")
	if width == null or height == null or decor_width == null or decor_height == null:
		return {}
	if mini(int(width), int(height)) <= 0 or mini(int(decor_width), int(decor_height)) <= 0:
		return {}
	var types: Variant = wrapper.call("wrap", "android.view.WindowInsets$Type")
	var bars: Variant = _java(wrapper, types, "systemBars")
	var cutout: Variant = _java(wrapper, types, "displayCutout")
	if bars == null or cutout == null:
		return {}
	var inset: Variant = _java(wrapper, root_insets, "getInsets", [int(bars) | int(cutout)])
	var system_edges := _public_edges(wrapper, inset)
	var rect_type: Variant = wrapper.call("wrap", "android.graphics.Rect")
	# JavaClass constructors use the actual class name (Rect.Rect(...)).
	var rect: Variant = _java(wrapper, rect_type, "Rect", [0, 0, int(width), int(height)])
	if system_edges.is_empty() or rect == null:
		return {}
	decor.call("offsetDescendantRectToMyCoords", view, rect)
	if wrapper.call("get_exception") != null:
		return {}
	var render_edges := _public_edges(wrapper, rect)
	if render_edges.is_empty():
		return {}
	var system := Rect2(system_edges.left, system_edges.top, system_edges.right, system_edges.bottom)
	var render_rect := Rect2(render_edges.left, render_edges.top,
		render_edges.right - render_edges.left, render_edges.bottom - render_edges.top)
	var decor_size := Vector2(float(decor_width), float(decor_height))
	return {
		"insets": insets_inside_view(decor_size, render_rect, system),
		"view_size": Vector2(float(width), float(height)),
		"decor_size": decor_size,
		"render_rect": render_rect,
		"system_insets": system,
	}


static func insets_inside_view(decor_size: Vector2, render_rect: Rect2, system: Rect2) -> Rect2:
	# Subtract only the portion actually covering Godot's SurfaceView. Android
	# may already have padded or offset this view; subtracting twice loses UI.
	var left := clampf(system.position.x - render_rect.position.x, 0, render_rect.size.x)
	var top := clampf(system.position.y - render_rect.position.y, 0, render_rect.size.y)
	var right := clampf(render_rect.end.x - (decor_size.x - system.size.x),
		0, render_rect.size.x - left)
	var bottom := clampf(render_rect.end.y - (decor_size.y - system.size.y),
		0, render_rect.size.y - top)
	return Rect2(left, top, right, bottom)
