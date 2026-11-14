extends SceneTree
## Production Cards with an isolated display-inset boundary and genuine touch input.
## The 136/63 and 145/63 portrait insets were observed in the original API35 log;
## they are not a measurement of the final screenshot's Godot window-inset state.

const TABLE = "res://scenes/games/cards_table.tscn"
const FIXTURE = preload("res://scripts/tests/cards_table_regression.gd")
const SAFE_AREA = preload("res://scripts/app/android_safe_area.gd")
const PROFILES := [
	["android35_portrait", Vector2i(1080, 2400), 2.625, Rect2(0, 136, 0, 63)],
	["android35_portrait_earlier_inset", Vector2i(1080, 2400), 2.625, Rect2(0, 145, 0, 63)],
	["landscape_cutout_fixture", Vector2i(2400, 1080), 2.625, Rect2(136, 63, 0, 63)],
	["short_landscape_fixture", Vector2i(640, 360), 1.0, Rect2(0, 32, 0, 24)],
	["desktop_without_insets", Vector2i(1280, 720), 1.0, Rect2()],
]

var table
var density := 1.0
var safe_pixels := Rect2()
var profile_name := ""
var checks := 0
var failures: Array[String] = []
var requests: Array[Dictionary] = []
var targets: Array[Dictionary] = []
var inputs: Array[Dictionary] = []
var images: Array[Dictionary] = []
var projected_views: Array[Dictionary] = []
var capture := false
var output := "res://exports/cards-safe-area"


func _initialize() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	if not OS.get_environment("LUMO_CAPTURE_DIR").is_empty():
		output = OS.get_environment("LUMO_CAPTURE_DIR")
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(profile_name + ": " + label)
		push_error("[CardsSafeArea] " + profile_name + ": " + label)


func _settle(frames: int = 5) -> void:
	for frame in range(frames):
		await process_frame


func _physical_rect(control: Control) -> Rect2:
	var factor := Vector2(root.size) / root.get_visible_rect().size
	var transform := control.get_global_transform_with_canvas()
	var rect := Rect2((transform * Vector2.ZERO) * factor, Vector2.ZERO)
	for point in [Vector2(control.size.x, 0), control.size, Vector2(0, control.size.y)]:
		rect = rect.expand((transform * point) * factor)
	return rect


func _array(rect: Rect2) -> Array:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]


func _target(control: Control, label: String) -> void:
	var pixels := _physical_rect(control)
	var dp := pixels.size / density
	_check(control.is_visible_in_tree(), label + " is visible")
	_check(minf(dp.x, dp.y) >= 47.99, "%s actual touch target is %s dp" % [label, dp])
	_check(safe_pixels.grow(0.51).encloses(pixels),
		"%s must be wholly outside system insets: target=%s safe=%s" % [label, pixels, safe_pixels])
	targets.append({"profile": profile_name, "label": label, "rect_px": _array(pixels),
		"dp": [dp.x, dp.y], "safe_rect_px": _array(safe_pixels)})


func _button(caption: String) -> Button:
	for node in table.ui.find_children("*", "Button", true, false):
		if node.text == caption and node.is_visible_in_tree():
			return node
	return null


func _touch(point: Vector2) -> void:
	for down in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 2
		event.position = point
		event.pressed = down
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await process_frame
	await _settle(2)


func _tap(control: Button, label: String, edge: bool = false) -> void:
	_check(is_instance_valid(control), label + " exists")
	if not is_instance_valid(control):
		return
	_target(control, label)
	_check(not control.disabled, label + " is enabled")
	var point := _physical_rect(control).get_center()
	if edge:
		point.y += 22.0 * density
	inputs.append({"profile": profile_name, "label": label,
		"screen_touch_px": [point.x, point.y], "edge_22_dp": edge})
	await _touch(point)


func _ack(paused: bool = false) -> void:
	var next: Dictionary = table._state.duplicate(true)
	next["revision"] = int(next.revision) + 1
	next["ack"] = table._sequence
	next["paused"] = paused
	table.apply_state(JSON.parse_string(JSON.stringify(next)))
	await _settle()


func _capture(name: String) -> void:
	if not capture:
		return
	await _settle()
	await RenderingServer.frame_post_draw
	var rendered := root.get_texture().get_image()
	_check(not rendered.is_empty() and rendered.get_size() == root.size,
		"capture is the actual full-size viewport")
	var path := output.path_join(name + ".png")
	_check(rendered.save_png(path) == OK, "actual viewport PNG was saved")
	var snapshot := (FileAccess.get_file_as_string("user://cards_layout_v1.json")
		if FileAccess.file_exists("user://cards_layout_v1.json") else "")
	var layout_file := FileAccess.open(output.path_join(name + ".layout.json"), FileAccess.WRITE)
	_check(layout_file != null and not snapshot.is_empty(), "capture includes the actual settled native layout readback")
	if layout_file != null:
		layout_file.store_string(snapshot)
		layout_file.close()
	images.append({"path": path, "profile": profile_name,
		"size": [root.size.x, root.size.y], "safe_rect_px": _array(safe_pixels)})


func _hand_layout() -> void:
	var factor := Vector2(root.size) / root.get_visible_rect().size
	var projected_hand := []
	for id in table._cards:
		var card: Node3D = table._cards[id]
		var projected := Rect2()
		var first := true
		var quad := []
		for corner in [Vector3(-0.415, 0.017, -0.59), Vector3(0.415, 0.017, -0.59),
			Vector3(0.415, 0.017, 0.59), Vector3(-0.415, 0.017, 0.59)]:
			var point: Vector2 = table.camera.unproject_position(card.to_global(corner)) * factor
			projected = Rect2(point, Vector2.ZERO) if first else projected.expand(point)
			quad.append([point.x, point.y])
			first = false
		projected_hand.append({"id": id, "quad": quad})
		_check(safe_pixels.grow(1).encloses(projected), "card face remains inside safe bounds: " + id)
		_check(not projected.intersects(_physical_rect(table.footer)),
			"card face does not overlap the relocated footer: " + id)
	_check(FIXTURE.face_texture_errors(table).is_empty(), "original face textures remain bound")
	var snapshot: Variant = (JSON.parse_string(FileAccess.get_file_as_string("user://cards_layout_v1.json"))
		if FileAccess.file_exists("user://cards_layout_v1.json") else null)
	_check(snapshot is Dictionary, "stable production layout is atomically readable")
	if snapshot is Dictionary:
		_check(snapshot.token == table._state.token and int(snapshot.revision) == int(table._state.revision)
			and int(snapshot.ack) == int(table._state.ack), "layout readback belongs to the actual mailbox state")
		_check(snapshot.settled and snapshot.ui_visible and snapshot.observation_source == "fixture",
			"desktop inset fixture is explicitly distinguished from an Android observation")
		_check(snapshot.hand.size() == projected_hand.size(), "readback includes every visible hand face")
		for index in range(mini(snapshot.hand.size(), projected_hand.size())):
			_check(snapshot.hand[index].id == projected_hand[index].id, "readback preserves public hand order")
			for corner in range(4):
				var a: Array = snapshot.hand[index].quad[corner]
				var b: Array = projected_hand[index].quad[corner]
				_check(Vector2(a[0], a[1]).distance_to(Vector2(b[0], b[1])) < 0.1,
					"published actual mesh projection agrees with independent camera readback")
	projected_views.append({"profile": profile_name, "hand": projected_hand,
		"ui_rect": _array(_physical_rect(table.ui)), "native_layout": snapshot})


func _header_observation_is_applied_once() -> void:
	# The integrated 993c header refresh remains callable after the complete UI
	# has acquired the measured safe area. It must not inset the header twice.
	var before_state: Dictionary = table._state.duplicate(true)
	var before_page: int = table._page
	var before_cards: Array = table._cards.keys()
	var observed := Rect2(safe_pixels.position, Vector2(root.size) - safe_pixels.end)
	table._apply_header_safe_area(observed, Vector2(root.size))
	await _settle(2)
	var expected_origin := safe_pixels.position + Vector2(12, 8) * density
	var header_rect := _physical_rect(table.header)
	_check(header_rect.position.distance_to(expected_origin) < 0.51,
		"integrated header applies the actual safe-area origin exactly once")
	_check(absf(header_rect.end.x - (safe_pixels.end.x - 12 * density)) < 0.51,
		"integrated header applies the actual right edge exactly once")
	table._update_header_safe_area()
	await _settle(2)
	_check(_physical_rect(table.header).position.distance_to(expected_origin) < 0.51,
		"later header refresh preserves the same measured UI origin")
	_check(table._state == before_state and table._page == before_page
		and table._cards.keys() == before_cards,
		"header refresh preserves authoritative state, hand identities and page")


func _exercise() -> void:
	await _header_observation_is_applied_once()
	for control in table.ui.find_children("*", "Button", true, false):
		if control.is_visible_in_tree():
			_target(control, "initial " + control.text)
	_check(table.inset_reads > 0, "production layout reads the platform safe-area boundary")
	_check(safe_pixels.grow(0.51).encloses(_physical_rect(table.header)), "whole header clears the system insets")
	_hand_layout()
	if profile_name in ["android35_portrait", "landscape_cutout_fixture"]:
		await _capture(profile_name + "-playing")
	var before := requests.size()
	await _tap(table.pause_button, "Pause edge touch", true)
	_check(requests.size() == before + 1 and requests.back().action == "pause", "real Pause touch emits one pause request")
	_check(not bool(table._state.paused), "touch does not invent an authoritative paused state")
	_check(table._pending > 0, "pause still waits for host acknowledgement")
	_check(not FileAccess.file_exists("user://cards_layout_v1.json"),
		"pending input immediately invalidates the previous settled observation")
	await _ack(true)
	_check(table.modal.visible, "host pause opens the actual pause panel")
	_check(safe_pixels.grow(0.51).encloses(_physical_rect(table.modal)), "pause panel is inside safe bounds")
	if profile_name == "android35_portrait":
		await _capture(profile_name + "-paused")
	before = requests.size()
	await _tap(_button("Weiterspielen"), "Resume touch", true)
	_check(requests.size() == before + 1 and requests.back().action == "resume", "real Resume touch preserves the request protocol")
	await _ack(false)
	if table._page_size < 7:
		await _tap(_button("›"), "Next-page touch", true)
		_check(table._page == 1, "real page touch advances the existing hand page")
		await _tap(_button("‹"), "Previous-page touch", true)
		_check(table._page == 0, "real page touch restores the first hand page")
	before = requests.size()
	var hand_before: Array = table._state.hand.duplicate(true)
	await _tap(table.draw_button, "Draw edge touch", true)
	_check(requests.size() == before + 1 and requests.back().action == "draw", "real Draw touch emits one request")
	_check(table._state.hand == hand_before, "drawing keeps the authoritative hand unchanged until host ack")
	await _ack(false)
	var point: Vector2 = table.camera.unproject_position(table._cards["r1"].global_position)
	await _touch(point * Vector2(root.size) / root.get_visible_rect().size)
	_check(table._selected == "r1", "real card-face touch still selects the original projected card")
	# The existing desktop touch-to-mouse emulation may also submit the card.
	# Complete the fixture's host roundtrip before measuring the Play button;
	# this test does not claim a new single-tap/double-tap gameplay contract.
	await _ack(false)
	before = requests.size()
	await _tap(table.play_button, "Play selected card touch")
	_check(requests.size() == before + 1 and requests.back().action == "play"
		and requests.back().cardId == "r1", "relocated Play emits the original selected-card request")
	await _ack(false)
	var call_state: Dictionary = table._state.duplicate(true)
	call_state.canCall = true
	table.apply_state(call_state)
	await _settle()
	for control in table.actions.get_children():
		if control is Button and control.is_visible_in_tree():
			_target(control, "three-action footer " + control.text)
	before = requests.size()
	await _tap(table.call_button, "LUMO call touch")
	_check(requests.size() == before + 1 and requests.back().action == "call", "optional LUMO action remains reachable")
	await _ack(false)
	await _tap(_button("Zurück"), "Back edge touch", true)
	_check(table.return_calls == 1, "actual Back hit reaches the existing return callback")
	for request in requests:
		_check(request.token == FIXTURE.fixture().token, "touch requests retain the original session token")
		_check(int(request.revision) >= 4 and int(request.sequence) > 0, "touch requests retain revision and sequence binding")


func _run() -> void:
	if capture and DisplayServer.get_name() == "headless":
		push_error("Cards safe-area capture requires an actual renderer")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	var previous_emulation := Input.emulate_touch_from_mouse
	Input.emulate_touch_from_mouse = true
	_check(Input.emulate_mouse_from_touch, "Godot routes actual touch events to GUI buttons")
	# Independent geometry cases for the Android View-offset conversion, not
	# a constant copied from the UI. Existing Android padding must not be added twice.
	var decor := Vector2(1080, 2400)
	var bars := Rect2(0, 136, 0, 63)
	_check(SAFE_AREA.insets_inside_view(decor, Rect2(Vector2.ZERO, decor), bars) == bars,
		"full edge-to-edge View retains both measured system insets")
	_check(SAFE_AREA.insets_inside_view(decor, Rect2(0, 136, 1080, 2201), bars) == Rect2(),
		"fully padded View does not receive the system insets twice")
	_check(SAFE_AREA.insets_inside_view(decor, Rect2(0, 63, 1080, 2337), bars) == Rect2(0, 73, 0, 63),
		"partially padded View receives only the actual remaining overlap")
	_check(SAFE_AREA.insets_inside_view(Vector2(2400, 1080), Rect2(80, 20, 2320, 1060),
		Rect2(136, 63, 0, 63)) == Rect2(56, 43, 0, 63),
		"landscape cutout and partial View offset remain separate physical edges")
	for profile in PROFILES:
		profile_name = profile[0]
		root.size = profile[1]
		density = profile[2]
		var insets: Rect2 = profile[3]
		safe_pixels = Rect2(insets.position, Vector2(root.size) - insets.position - insets.size)
		root.get_node("HostBridge")._options = {"displayDensity": density,
			"cardsToken": FIXTURE.fixture().token, "soundEnabled": false}
		requests.clear()
		table = load(TABLE).instantiate()
		# Load after autoload initialization, as the production scene does.
		table.set_script(load("res://scripts/tests/fixtures/cards_safe_area_table.gd"))
		table.display_insets = insets
		table._android_safe_area = {"view_size": Vector2(root.size), "decor_size": Vector2(root.size),
			"render_rect": Rect2(Vector2.ZERO, Vector2(root.size)), "system_insets": insets,
			"insets": insets, "window_size": root.size}
		root.add_child(table)
		table.action_requested.connect(func(request: Dictionary): requests.append(request))
		await _settle(8)
		table._resize()
		table.apply_state(FIXTURE.wire_fixture())
		await _settle(8)
		await _exercise()
		table.queue_free()
		await _settle()
	Input.emulate_touch_from_mouse = previous_emulation
	var report := FileAccess.open(output.path_join("cards-safe-area.json"), FileAccess.WRITE)
	_check(report != null, "evidence report opens")
	if report != null:
		report.store_string(JSON.stringify({"checks": checks, "failures": failures,
			"renderer": DisplayServer.get_name(), "android_device_measurement": false,
			"fixture_scope": "API35 log-observed portrait insets; explicit synthetic landscape/desktop cases",
			"targets": targets, "input_events": inputs, "images": images,
			"projected_views": projected_views}, "  "))
		report.close()
	print("CARDS_SAFE_AREA_%s checks=%d failures=%d profiles=%d images=%d" % [
		"PASS" if failures.is_empty() else "FAIL", checks, failures.size(), PROFILES.size(), images.size()])
	quit(0 if failures.is_empty() else 1)
