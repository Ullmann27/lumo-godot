extends SceneTree
## Native renderer-only evidence. The real PackedScene receives known legal
## examples from an earlier real two-process run through a read-only host.
## This fixture does not evaluate rules, produce bot turns, acknowledge actions,
## issue rewards, exercise Dart persistence, or claim an Android measurement.
const SCENE := "res://scenes/games/connect_four_table.tscn"
const SOURCE_PATHS := [
	"res://scripts/tests/connect_four_visual_capture.gd",
	"res://scenes/games/connect_four_table.tscn",
	"res://scripts/games/connect_four/connect_four_table.gd",
	"res://scripts/systems/host_bridge.gd",
	"res://scripts/app/mobile_runtime.gd",
	"res://scripts/app/android_safe_area.gd",
	"res://scripts/characters/lumo/lumo_rigged_actor.gd",
	"res://assets/characters/lumo_animated/Lumo-Animated-Mobile.glb",
]

var output := ""
var checks := 0
var errors: Array[String] = []
var captures: Array[Dictionary] = []
var input_events: Array[Dictionary] = []
var table
var host: FixtureHost
var frame := 0
var previous_touch_emulation := false


class FixtureHost extends RefCounted:
	var state_json := ""
	var rejected_actions: Array[String] = []
	var return_attempts := 0

	func getConnectFourState() -> String:
		return state_json

	func submitConnectFourAction(payload: String) -> bool:
		rejected_actions.append(payload)
		return false

	func returnToApp(_destination: String, _payload: String) -> bool:
		return_attempts += 1
		return false


func _initialize() -> void:
	output = OS.get_environment("LUMO_CAPTURE_DIR")
	call_deferred("_run")


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		errors.append(message)
		push_error("[ConnectFourVisual] " + message)


func _frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	frame += 1


func _frames(count: int) -> void:
	for _index in range(count):
		await _frame()


func _settled() -> Dictionary:
	for _attempt in range(120):
		if FileAccess.file_exists(table.LAYOUT_OBSERVATION):
			var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(table.LAYOUT_OBSERVATION))
			if value is Dictionary and value.get("settled") == true and int(value.get("revision", -1)) == int(table._state.get("revision", -2)) and value.get("token") == table._token:
				_check(true, "Current production layout settled")
				return value
		await _frame()
	_check(false, "Production layout settles within 120 rendered frames")
	return {}


func _physical(control: Control) -> Rect2:
	var transform := control.get_global_transform_with_canvas()
	var factor := Vector2(root.size) / root.get_visible_rect().size
	return Rect2((transform * Vector2.ZERO) * factor, control.size * transform.get_scale() * factor)


func _rect(value: Rect2) -> Array:
	return [value.position.x, value.position.y, value.size.x, value.size.y]


func _target(control: Button, label: String) -> Dictionary:
	var rectangle := _physical(control)
	var exposed := rectangle.intersection(Rect2(Vector2.ZERO, Vector2(root.size)))
	var parent := control.get_parent()
	while parent != null:
		if parent is Control and parent.clip_contents:
			exposed = exposed.intersection(_physical(parent))
		parent = parent.get_parent()
	var dp: Vector2 = exposed.size / table._density
	var safe_pixels: Rect2 = table._safe_rect
	var scale := Vector2(root.size) / root.get_visible_rect().size
	safe_pixels = Rect2(safe_pixels.position * scale, safe_pixels.size * scale)
	_check(control.is_visible_in_tree(), label + " visible")
	_check(exposed.grow(0.1).encloses(rectangle), label + " fully exposed, including scroll clips")
	_check(dp.x >= 47.99 and dp.y >= 47.99, label + " exposed target at least 48dp")
	_check(safe_pixels.grow(0.1).encloses(rectangle), label + " inside the current safe view")
	return {"text":control.text,"rect_px":_rect(rectangle),"hit_rect_px":_rect(exposed),
		"size_dp":[dp.x,dp.y],"enabled":not control.disabled,"frame":frame}


func _pointer(point: Vector2) -> void:
	for position in [Vector2.ZERO, point]:
		var motion := InputEventMouseMotion.new()
		motion.position = position
		Input.parse_input_event(motion)
		Input.flush_buffered_events()


func _reveal(control: Button, prefer_menu_top: bool = false) -> void:
	var scroll: ScrollContainer = table.overlay.get_child(0)
	for attempt in range(6):
		var clip := _physical(scroll)
		var target := _physical(control)
		if clip.grow(0.1).encloses(target) and (not prefer_menu_top or scroll.scroll_vertical == 0):
			return
		var overlap := clip.intersection(target)
		var start := overlap.get_center() if overlap.has_area() else clip.get_center()
		var delta := target.end.y - clip.end.y + 2.0 if target.end.y > clip.end.y else target.position.y - clip.position.y - 2.0
		if prefer_menu_top and scroll.scroll_vertical > 0:
			delta = -maxf(24.0, float(scroll.scroll_vertical))
		delta = clampf(delta, -clip.size.y * 0.55, clip.size.y * 0.55)
		var finish := start - Vector2(0, delta)
		_pointer(start)
		var touch := InputEventScreenTouch.new()
		touch.index = 3
		touch.position = start
		touch.pressed = true
		Input.parse_input_event(touch)
		Input.flush_buffered_events()
		input_events.append({"kind":"ScreenTouch","pressed":true,"point":[start.x,start.y],"frame":frame,"target":control.text})
		await _frame()
		var previous := start
		for step in range(1, 9):
			var point := start.lerp(finish, float(step) / 8.0)
			var drag := InputEventScreenDrag.new()
			drag.index = 3
			drag.position = point
			drag.relative = point - previous
			drag.screen_relative = drag.relative
			drag.velocity = drag.relative * 24.0 if step < 8 else Vector2.ZERO
			drag.screen_velocity = drag.velocity
			Input.parse_input_event(drag)
			Input.flush_buffered_events()
			input_events.append({"kind":"ScreenDrag","point":[point.x,point.y],"frame":frame,"target":control.text})
			previous = point
			await _frame()
		touch = InputEventScreenTouch.new()
		touch.index = 3
		touch.position = finish
		touch.pressed = false
		Input.parse_input_event(touch)
		Input.flush_buffered_events()
		input_events.append({"kind":"ScreenTouch","pressed":false,"point":[finish.x,finish.y],"frame":frame,"target":control.text})
		await _frames(12)
	_check(_physical(scroll).grow(0.1).encloses(_physical(control)), "Bounded real swipe reveals complete " + control.text)


func _source_hashes() -> Dictionary:
	var hashes := {}
	for path in SOURCE_PATHS:
		_check(FileAccess.file_exists(path), "Production source exists: " + path)
		hashes[path] = FileAccess.get_sha256(path)
	return hashes


func _geometry(example: Dictionary) -> Dictionary:
	var board: MeshInstance3D = table.get_node("PerforatedBoard")
	_check(board.mesh is ArrayMesh and board.mesh.get_surface_count() == 1, "Actual perforated board geometry is present")
	var arrays := board.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	_check(vertices.size() > 1000 and indices.size() > 1000, "Indexed three-dimensional board, not a flat image")
	_check(board.mesh.get_aabb().size.z > 0.3, "Real board thickness")
	_check(table._discs.size() == example.occupied.size(), "Actual disc count equals the recorded example")
	var measured: Array[Dictionary] = []
	for expected in example.occupied:
		var center := Vector3(expected.world_center[0],expected.world_center[1],expected.world_center[2])
		var found: MeshInstance3D = null
		for disc in table._discs:
			if disc.position.distance_to(center) < 0.001:
				found = disc
				break
		_check(found != null, "Actual disc center matches the original recorded cell")
		if found == null:
			continue
		_check(found.mesh is CylinderMesh and is_equal_approx(found.mesh.height,0.22), "Disc has physical cylinder depth")
		var expected_color := Color("53ddfd") if int(expected.piece) == 1 else Color("ffd166")
		_check(found.material_override is StandardMaterial3D and found.material_override.albedo_color.is_equal_approx(expected_color), "Disc uses recorded player material")
		var projected: Vector2 = table.camera.unproject_position(found.global_position)
		_check(Rect2(Vector2.ZERO,root.get_visible_rect().size).has_point(projected), "Disc projects into the real viewport")
		measured.append({"piece":int(expected.piece),"position":[found.position.x,found.position.y,found.position.z],"projected":[projected.x,projected.y],"mesh_class":found.mesh.get_class()})
	var rings: Array[Dictionary] = []
	_check(table._win_root.get_child_count() == example.state.winningLine.size(), "Actual win ring count equals the recorded winning line")
	for ring in table._win_root.get_children():
		_check(ring is MeshInstance3D and ring.mesh is TorusMesh, "Winning cell marked by real torus geometry")
		rings.append({"position":[ring.position.x,ring.position.y,ring.position.z],"mesh_class":ring.mesh.get_class()})
	_check(table.fox.is_usable(), "Original Lumo character is attached")
	return {"board_vertices":vertices.size(),"board_indices":indices.size(),"board_depth":board.mesh.get_aabb().size.z,
		"disc_count":table._discs.size(),"discs":measured,"win_ring_count":rings.size(),"win_rings":rings,"original_lumo_visible":table.fox.visible}


func _capture_case(example: Dictionary) -> void:
	root.size = Vector2i(int(example.size[0]),int(example.size[1]))
	root.position = Vector2i(40,40)
	root.grab_focus()
	root.get_node("HostBridge")._options = {"displayDensity":1.0,"connectFourToken":example.state.token,"reduceAnimations":false}
	await _frames(3)
	host = FixtureHost.new()
	host.state_json = JSON.stringify(example.state)
	var immutable_state := host.state_json
	var packed: PackedScene = load(SCENE)
	table = packed.instantiate()
	table._host = host
	root.add_child(table)
	await _frames(12)
	var layout: Dictionary = await _settled()
	_check(not layout.is_empty() and table._state == example.state, "Production scene consumes the exact read-only example")
	_check(not table._dropping and table._drop_queue.is_empty(), "Restored example is visually settled")
	var targets := [_target(table.return_button,"Back"),_target(table.pause_button,"Pause/menu")]
	for button in table.column_buttons:
		targets.append(_target(button,"Column " + button.text))
	var menu_targets: Array[Dictionary] = []
	if bool(example.state.paused):
		_check(table.overlay.visible and table.detail.text == "Spiel pausiert. Deine Runde bleibt gespeichert.", "Actual pause caption visible")
		for button in [table.resume_button,table.restart_button,table.mode_button]:
			await _reveal(button)
			menu_targets.append(_target(button,"Pause menu " + button.text))
		await _reveal(table.resume_button, true)
		menu_targets.append(_target(table.resume_button,"Final visible Fortsetzen"))
		var pause_scroll: ScrollContainer = table.overlay.get_child(0)
		_check(pause_scroll.scroll_vertical == 0 and _physical(pause_scroll).grow(0.1).encloses(_physical(table.detail)), "Original pause explanation fully visible at final captured scroll position")
		_check(table.resume_button.text == "Fortsetzen" and not table.resume_button.disabled, "Real Fortsetzen control is enabled and fully exposed")
		_check(not input_events.is_empty(), "Small pause menu actually exercised with screen swipes")
	else:
		_check(not table.overlay.visible, "Recorded unpaused board remains unobscured by modal")
		_check(table.status.text == ("Cyan gewinnt!" if example.state.phase == "won" else "Gespeichert · Cyan ist dran"), "Actual board caption matches the recorded state")
	layout = await _settled()
	var geometry := _geometry(example)
	_check(host.state_json == immutable_state and host.rejected_actions.is_empty() and host.return_attempts == 0, "Fixture host never accepts or simulates a game action")
	await _frames(2)
	var image := root.get_texture().get_image()
	_check(image != null and image.get_size() == root.size, "Renderer output has exact requested pixel dimensions")
	var colors := {}
	for y in range(0,image.get_height(),maxi(1,image.get_height()/48)):
		for x in range(0,image.get_width(),maxi(1,image.get_width()/48)):
			colors[image.get_pixel(x,y).to_rgba32()] = true
	_check(colors.size() > 80, "Real raster has scene variation")
	var path: String = output.path_join(str(example.name)+".png")
	_check(not FileAccess.file_exists(path), "Capture never replaces an existing evidence image")
	_check(image.save_png(path) == OK, "Actual framebuffer PNG saved")
	captures.append({"file":str(example.name)+".png","sha256":FileAccess.get_sha256(path),"size_px":[image.get_width(),image.get_height()],
		"scope":"visual_fixture_only","fixture_source":example.source_file,"fixture_source_sha256":example.source_sha256,
		"fixture_state":example.state,"fixture_state_sha256":immutable_state.sha256_text(),"geometry":geometry,
		"caption":table.status.text,"pause_caption":table.detail.text if table.overlay.visible else "",
		"targets":targets,"reachable_menu_targets":menu_targets,"production_layout":layout,
		"input_requests_rejected":host.rejected_actions,"host_return_attempts":host.return_attempts,"raster_unique_samples":colors.size()})
	root.remove_child(table)
	table.queue_free()
	await _frames(3)


func _run() -> void:
	if DisplayServer.get_name() == "headless" or "--headless" in OS.get_cmdline_args():
		push_error("CONNECT_FOUR_VISUAL_REQUIRES_REAL_RENDERER")
		quit(2)
		return
	if output.is_empty() or not "--capture" in OS.get_cmdline_user_args():
		push_error("Explicit LUMO_CAPTURE_DIR and --capture are required")
		quit(2)
		return
	if FileAccess.file_exists(output.path_join("visual-state.json")):
		push_error("Refusing to replace existing visual-state.json evidence")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	previous_touch_emulation = Input.emulate_touch_from_mouse
	Input.emulate_touch_from_mouse = true
	var source_before := _source_hashes()
	_check(FIXTURE_JSON.sha256_text() == FIXTURE_JSON_SHA256, "Embedded original-state fixture hash")
	var examples: Variant = JSON.parse_string(FIXTURE_JSON)
	_check(examples is Array and examples.size() == 4, "Exactly four recorded visual examples")
	for example in examples:
		await _capture_case(example)
	_check(captures.size() == 4, "All four actual framebuffers captured")
	var source_after := _source_hashes()
	_check(source_after == source_before, "All measured production source bytes unchanged")
	var file := FileAccess.open(output.path_join("visual-state.json"),FileAccess.WRITE)
	_check(file != null, "Visual evidence report can be written")
	if file != null:
		file.store_string(JSON.stringify({"schema":1,"kind":"connect_four_visual_fixture","scope":"Native renderer-only; no Dart, bot, reward, save, Android or FPS acceptance",
			"read_only_fixture_host":true,"fixture_json_sha256":FIXTURE_JSON_SHA256,"source_revision":OS.get_environment("GITHUB_SHA"),
			"display_driver":DisplayServer.get_name(),"rendering_method":RenderingServer.get_current_rendering_method(),
			"video_adapter":RenderingServer.get_video_adapter_name(),"density":1.0,"platform_insets":"desktop safe-area; no physical Android measurement",
			"checks":checks,"errors":errors,"captures":captures,"input_events":input_events,"source_before":source_before,"source_after":source_after},"\t"))
		file.close()
	Input.emulate_touch_from_mouse = previous_touch_emulation
	if errors.is_empty():
		print("CONNECT_FOUR_VISUAL_PASS checks=%d captures=4 fixture=true" % checks)
	else:
		print("CONNECT_FOUR_VISUAL_FAIL checks=%d errors=%d" % [checks,errors.size()])
	quit(0 if errors.is_empty() else 1)
const FIXTURE_JSON_SHA256 := "cb2b8d22d32066777698ba4af01eb139e90c2d75bf7a7c2b95ab4b757de7f6c0"
const FIXTURE_JSON := """[{"name":"c4-empty-landscape","size":[960,540],"source_file":"connect_four_empty.layout.json","source_sha256":"4b85b841d4981813dfcd61bc2a1232a9a665ea8be1b69f9ca192d57f2e2eb490","state":{"schema":1,"game":"connect_four","token":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","owner":"831eb2a9e465214a7bad8cebda113466f58af638c3bef2c42b83ec7630a3cbff","roundId":"da1101f7e2966b36aa6be1581ffb0ad6","revision":7,"recordRevision":4,"ack":3,"rejected":0,"paused":false,"canDrop":true,"phase":"playing","turn":1,"twoPlayers":true,"level":"mittel","columns":[],"board":[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],"winningLine":[],"rewarded":false,"exit":false,"reduceMotion":false,"validColumns":[0,1,2,3,4,5,6],"error":null},"occupied":[]},{"name":"c4-playing-phone","size":[412,915],"source_file":"connect_four_phone_bot_response.layout.json","source_sha256":"b871ef7da990d3f31143a80caa9cd4739d91a0dcf0028e56734d61ddfcf56ab6","state":{"schema":1,"game":"connect_four","token":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","owner":"831eb2a9e465214a7bad8cebda113466f58af638c3bef2c42b83ec7630a3cbff","roundId":"7de9a1d339103dc67cf28cff5e0539fd","revision":5,"recordRevision":3,"ack":1,"rejected":0,"paused":false,"canDrop":true,"phase":"playing","turn":1,"twoPlayers":false,"level":"mittel","columns":[3,3],"board":[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,0,0,0,0,0,0,1,0,0,0],"winningLine":[],"rewarded":false,"exit":false,"reduceMotion":false,"validColumns":[0,1,2,3,4,5,6],"error":null},"occupied":[{"piece":2,"world_center":[0.0,1.71000003814697,0.0]},{"piece":1,"world_center":[0.0,0.850000023841858,0.0]}]},{"name":"c4-win-landscape","size":[960,540],"source_file":"connect_four_win.layout.json","source_sha256":"f19e96174c8d970a7d10df04259d05e99e370ef1884a5eda8682da48f09d5cc8","state":{"schema":1,"game":"connect_four","token":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","owner":"831eb2a9e465214a7bad8cebda113466f58af638c3bef2c42b83ec7630a3cbff","roundId":"da1101f7e2966b36aa6be1581ffb0ad6","revision":24,"recordRevision":12,"ack":14,"rejected":0,"paused":false,"canDrop":false,"phase":"won","turn":1,"twoPlayers":true,"level":"mittel","columns":[0,6,1,6,2,5,3],"board":[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,1,1,1,1,0,2,2],"winningLine":[[5,0],[5,1],[5,2],[5,3]],"rewarded":true,"exit":false,"reduceMotion":false,"validColumns":[0,1,2,3,4,5,6],"error":null},"occupied":[{"piece":2,"world_center":[2.57999992370605,1.71000003814697,0.0]},{"piece":1,"world_center":[-2.57999992370605,0.850000023841858,0.0]},{"piece":1,"world_center":[-1.72000002861023,0.850000023841858,0.0]},{"piece":1,"world_center":[-0.860000014305115,0.850000023841858,0.0]},{"piece":1,"world_center":[0.0,0.850000023841858,0.0]},{"piece":2,"world_center":[1.72000002861023,0.850000023841858,0.0]},{"piece":2,"world_center":[2.57999992370605,0.850000023841858,0.0]}]},{"name":"c4-paused-small","size":[640,360],"source_file":"connect_four_pause.layout.json","source_sha256":"6812f85731ce01cf4aed2b34962fa86644ebec07728268f9ff100252e58f99f7","state":{"schema":1,"game":"connect_four","token":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","owner":"831eb2a9e465214a7bad8cebda113466f58af638c3bef2c42b83ec7630a3cbff","roundId":"da1101f7e2966b36aa6be1581ffb0ad6","revision":16,"recordRevision":7,"ack":9,"rejected":0,"paused":true,"canDrop":false,"phase":"playing","turn":2,"twoPlayers":true,"level":"mittel","columns":[0,6,1],"board":[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,0,0,0,0,2],"winningLine":[],"rewarded":false,"exit":false,"reduceMotion":false,"validColumns":[0,1,2,3,4,5,6],"error":null},"occupied":[{"piece":1,"world_center":[-2.57999992370605,0.850000023841858,0.0]},{"piece":1,"world_center":[-1.72000002861023,0.850000023841858,0.0]},{"piece":2,"world_center":[2.57999992370605,0.850000023841858,0.0]}]}]"""
