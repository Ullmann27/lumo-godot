extends SceneTree
## Execute the actual Android adapter against narrow public Java API boundaries.
## This is an interface/geometry contract, not an Android runtime measurement.
const ADAPTER = preload("res://scripts/app/android_safe_area.gd")


class PublicField extends RefCounted:
	var api
	var field_name: String

	func _init(boundary, name: String) -> void:
		api = boundary
		field_name = name

	func getInt(object: Object) -> Variant:
		return api.answer("getInt:" + field_name, object.edges.get(field_name))


class JavaObjectBoundary extends RefCounted:
	var api
	var kind: String
	var edges := {}

	func _init(boundary, type: String) -> void:
		api = boundary
		kind = type

	func getWindow() -> Variant:
		return api.answer("getWindow", JavaObjectBoundary.new(api, "window"))

	func getDecorView() -> Variant:
		return api.answer("getDecorView", JavaObjectBoundary.new(api, "decor"))

	func getRootWindowInsets() -> Variant:
		return api.answer("getRootWindowInsets", JavaObjectBoundary.new(api, "rootInsets"))

	func getGodot() -> Variant:
		return api.answer("getGodot", JavaObjectBoundary.new(api, "godot"))

	func getRenderView() -> Variant:
		return api.answer("getRenderView", JavaObjectBoundary.new(api, "renderView"))

	func getView() -> Variant:
		return api.answer("getView", JavaObjectBoundary.new(api, "surfaceView"))

	func isAttachedToWindow() -> Variant:
		return api.answer("isAttachedToWindow", api.attached)

	func getWidth() -> Variant:
		return api.answer("getWidth", int(api.decor_size.x if kind == "decor" else api.render_rect.size.x))

	func getHeight() -> Variant:
		return api.answer("getHeight", int(api.decor_size.y if kind == "decor" else api.render_rect.size.y))

	func systemBars() -> Variant:
		return api.answer("systemBars", 7)

	func displayCutout() -> Variant:
		return api.answer("displayCutout", 128)

	func getInsets(mask: int) -> Variant:
		api.requested_mask = mask
		var result := JavaObjectBoundary.new(api, "insets")
		result.edges = {"left": api.system.position.x, "top": api.system.position.y,
			"right": api.system.size.x, "bottom": api.system.size.y}
		return api.answer("getInsets", result)

	func getClass() -> Variant:
		return api.answer("getClass", self)

	func getField(name: String) -> Variant:
		return api.answer("getField:" + name, PublicField.new(api, name))

	# Godot JavaClass uses the actual Java class name for its constructor.
	# Deliberately provide no method named `new` at the API boundary.
	func Rect(left: int, top: int, right: int, bottom: int) -> Variant:
		api.constructor_arguments = [left, top, right, bottom]
		var result := JavaObjectBoundary.new(api, "rect")
		result.edges = {"left": left, "top": top, "right": right, "bottom": bottom}
		return api.answer("Rect", result)

	func offsetDescendantRectToMyCoords(view: Object, rect: Object) -> void:
		api.descendant_kind = view.kind
		api.answer("offsetDescendantRectToMyCoords", null)
		if api.exception != null:
			return
		rect.edges = {"left": api.render_rect.position.x, "top": api.render_rect.position.y,
			"right": api.render_rect.end.x, "bottom": api.render_rect.end.y}


class AndroidBoundary extends RefCounted:
	var decor_size := Vector2(1080, 2400)
	var render_rect := Rect2(0, 0, 1080, 2400)
	var system := Rect2(0, 136, 0, 63)
	var attached: Variant = 1
	var exception: Variant = null
	var fail_at := ""
	var missing_at := ""
	var calls: Array[String] = []
	var requested_mask := 0
	var constructor_arguments: Array = []
	var descendant_kind := ""

	func answer(method: String, value: Variant) -> Variant:
		calls.append(method)
		exception = "public Java boundary failure: " + method if method == fail_at else null
		return null if method == missing_at else value

	func wrap(name: String) -> Object:
		return JavaObjectBoundary.new(self, name)

	func get_exception() -> Variant:
		return exception

	func activity() -> Object:
		return JavaObjectBoundary.new(self, "activity")


var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("[CardsAndroidInsets] " + label)


func _run() -> void:
	var api := AndroidBoundary.new()
	var observation: Dictionary = ADAPTER._read_window(api, api.activity())
	_check(not observation.is_empty(), "actual adapter traverses the public API boundary")
	if not observation.is_empty():
		_check(observation.insets == Rect2(0, 136, 0, 63), "JNI integer jboolean preserves real edge-to-edge insets")
		_check(observation.view_size == Vector2(1080, 2400), "actual SurfaceView dimensions accompany the result")
	_check(api.requested_mask == (7 | 128), "both system bars and display cutout are requested")
	_check(api.constructor_arguments == [0, 0, 1080, 2400] and "Rect" in api.calls,
		"actual JavaClass Rect constructor is used with the measured View size")
	_check(api.descendant_kind == "surfaceView", "actual render View is mapped into decor coordinates")
	_check("getField:top" in api.calls and "getInt:top" in api.calls,
		"public instance fields are read through public Field.getInt")
	api.render_rect = Rect2(0, 136, 1080, 2201)
	api.attached = true
	observation = ADAPTER._read_window(api, api.activity())
	_check(not observation.is_empty() and observation.insets == Rect2(),
		"already padded View has no second inset and boolean attached remains valid")
	api.render_rect = Rect2(0, 0, 1080, 2400)
	for missing in ["getRootWindowInsets", "getView", "getField:top"]:
		api.missing_at = missing
		_check(ADAPTER._read_window(api, api.activity()).is_empty(),
			"missing " + missing + " is not a fabricated zero-inset measurement")
	api.missing_at = ""
	for failure in ["Rect", "getInt:top", "offsetDescendantRectToMyCoords"]:
		api.fail_at = failure
		_check(ADAPTER._read_window(api, api.activity()).is_empty(),
			"Java exception from " + failure + " invalidates the observation")
	api.fail_at = ""
	api.exception = "previous failure"
	_check(not ADAPTER._read_window(api, api.activity()).is_empty(),
		"next successful Java read recovers from a previous exception")
	for detached in [false, 0, 2, null]:
		api.attached = detached
		_check(ADAPTER._read_window(api, api.activity()).is_empty(),
			"unattached or invalid JNI flag is not accepted: " + str(detached))
	api.attached = 1
	api.render_rect.size = Vector2.ZERO
	_check(ADAPTER._read_window(api, api.activity()).is_empty(), "unlaid-out View is retried instead of dividing by zero")
	print("CARDS_ANDROID_INSETS_%s checks=%d failures=%d scope=public_api_boundary_not_device" % [
		"PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
