extends SceneTree
## Measures the actual home controls, including the LAN controller's real button.
const HUB = preload("res://scripts/games/kart_neon_hub.gd")
const LAN = preload("res://scripts/games/kart_friends/kart_lan_race.gd")
var failures: Array[String] = []
var checks := 0


class MenuOwner:
	extends Node
	var safe_ui: Control
	var reference_landing: Control
	var menu_active := true


func _initialize() -> void:
	_run.call_deferred()


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var owner := MenuOwner.new()
	root.add_child(owner)
	owner.safe_ui = Control.new()
	root.add_child(owner.safe_ui)
	owner.safe_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	owner.reference_landing = HUB.new()
	owner.safe_ui.add_child(owner.reference_landing)
	var lan := LAN.new()
	owner.add_child(lan)
	lan.setup(owner, "Test")
	for dimensions in [Vector2i(390, 844), Vector2i(640, 360), Vector2i(884, 920), Vector2i(1384, 1400), Vector2i(1280, 720)]:
		root.size = dimensions
		for frame in range(4):
			await process_frame
		var hub = owner.reference_landing
		var rect: Rect2 = lan.entry.get_global_rect()
		var density: float = hub._layout_scale
		_check(lan.entry.visible, "%s: together button visible" % dimensions)
		_check(Rect2(Vector2.ZERO, Vector2(dimensions)).encloses(rect), "%s: together button inside viewport" % dimensions)
		_check(rect.size.x / density >= 48.0 and rect.size.y / density >= 47.9, "%s: 48dp touch target" % dimensions)
		for other in [hub._back, hub._logo, hub._player, hub._stars_chip, hub._highlight, hub._dock, hub._progress]:
			_check(not rect.intersects(other.get_global_rect()), "%s: no overlap with %s" % [dimensions, other.name])
		for tile in hub._mode_tiles.values():
			_check(not rect.intersects(tile.get_global_rect()), "%s: no mode overlap" % dimensions)
		_check(rect.size.y + 0.1 >= lan.entry.get_combined_minimum_size().y, "%s: complete button text fits" % dimensions)
	owner.reference_landing._open_overlay("rewards")
	await process_frame
	await process_frame
	_check(not lan.entry.visible, "modal overlay owns its input area")
	owner.reference_landing._close_overlay()
	await process_frame
	await process_frame
	_check(lan.entry.visible, "closing overlay restores together button")
	owner.menu_active = false
	await process_frame
	_check(not lan.entry.visible, "button hidden during race")
	owner.queue_free()
	await process_frame
	owner = null
	print("[KartLanEntryLayout] %s %d checks" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)
