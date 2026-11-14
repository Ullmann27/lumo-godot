extends SceneTree
## Presentation fixture only. The real Dart authority is exercised separately.
## This fixture never writes a saved round and never awards a wallet result.
const TABLE := "res://scripts/games/memory/memory_table.gd"
const TOKEN := "cccccccccccccccccccccccccccccccc"
const OWNER := "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
var table
var bridge
var output := ""
var capture := false
var checks := 0
var errors: Array[String] = []
var inputs: Array[Dictionary] = []
var captures: Array[Dictionary] = []
var observations: Array[Dictionary] = []
var original_touch := false

class ObservedTransport extends RefCounted:
	var state: Dictionary = {}
	var requests: Array[Dictionary] = []
	var accept := true
	var returns := 0
	func getTableState() -> String:
		return JSON.stringify(state)
	func submitTableAction(payload: String) -> bool:
		requests.append(JSON.parse_string(payload))
		return accept
	func returnToApp(destination: String,payload: String) -> bool:
		if destination != "games" or payload != "" or not state.get("exit",false):
			return false
		returns += 1
		return true


func _initialize() -> void:
	output = OS.get_environment("LUMO_MEMORY_CAPTURE_DIR")
	capture = "--capture" in OS.get_cmdline_user_args()
	call_deferred("_run")


func _check(value: bool,message: String) -> void:
	checks += 1
	if not value:
		errors.append(message)
		push_error("[MemoryView] "+message)


func _state(level: String="leicht") -> Dictionary:
	var count: int = [8,12,16,20,24][["leicht","mittel","schwer","knifflig","profi"].find(level)]
	var cards := []
	for index in range(count):
		cards.append({"index":index,"faceUp":false,"matched":false,"motif":null})
	return {"schema":1,"game":"memory","token":TOKEN,"owner":OWNER,"roundId":"d".repeat(32),
		"revision":1,"recordRevision":1,"ack":0,"rejected":0,"paused":false,"exit":false,
		"reduceMotion":false,"rewarded":false,"difficulty":level,"pack":"alle","count":count,
		"cards":cards,"turn":"kind","phase":"select","kindPairs":0,"lumoPairs":0,"kindMoves":0,
		"kindStreak":0,"line":"Lass uns Memory spielen! Du fängst an.","remainingMs":0,
		"complete":false,"stars":0,"canFlip":true,"best":{},"error":null}


func _frames(count: int) -> void:
	for index in range(count):
		await process_frame
		if capture: await RenderingServer.frame_post_draw


func _physical(control: Control) -> Rect2:
	var factor := Vector2(root.size)/root.get_visible_rect().size
	var transform := control.get_global_transform_with_canvas()
	return Rect2(transform*Vector2.ZERO*factor,control.size*transform.get_scale()*factor)


func _tap(button: Button,label: String) -> void:
	_check(button.is_visible_in_tree() and not button.disabled,label+" is currently actionable")
	var rect := _physical(button)
	var dp: Vector2 = rect.size/table._density
	_check(dp.x>=48.0 and dp.y>=48.0,label+" actual size >=48dp")
	var point := rect.get_center()
	for pos in [Vector2.ZERO,point]:
		var motion := InputEventMouseMotion.new()
		motion.position = pos
		Input.parse_input_event(motion)
		Input.flush_buffered_events()
	for down in [true,false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 1
		touch.position = point
		touch.pressed = down
		Input.parse_input_event(touch)
		Input.flush_buffered_events()
		inputs.append({"label":label,"pressed":down,"point":[point.x,point.y],"revision":table._state.revision})
		await _frames(1)


func _apply(value: Dictionary) -> void:
	bridge.state = value.duplicate(true)
	_check(table.apply_state(value),"authoritative fixture accepted")
	await _frames(4)


func _reply(changes: Dictionary) -> Dictionary:
	var next: Dictionary = table._state.duplicate(true)
	next.revision = int(next.revision)+1
	next.recordRevision = int(next.recordRevision)+1
	if not bridge.requests.is_empty(): next.ack = int(bridge.requests.back().sequence)
	next.merge(changes,true)
	return next


func _snap(name: String) -> void:
	await _frames(4)
	_check(FileAccess.file_exists(table.OBSERVATION),"settled observation "+name)
	if not FileAccess.file_exists(table.OBSERVATION): return
	var raw := FileAccess.get_file_as_string(table.OBSERVATION)
	var data: Variant = JSON.parse_string(raw)
	_check(data is Dictionary and data.settled and int(data.revision)==int(table._state.revision),
		"same-state observation "+name)
	var file := FileAccess.open(output+"/"+name+".layout.json",FileAccess.WRITE)
	file.store_string(raw)
	file.close()
	if capture:
		var image := root.get_texture().get_image()
		_check(image != null and not image.is_empty(),"real framebuffer "+name)
		if image != null and not image.is_empty():
			var path := output+"/"+name+".png"
			_check(image.save_png(path)==OK,"PNG saved "+name)
			captures.append({"file":name+".png","sha256":FileAccess.get_sha256(path),"width":image.get_width(),"height":image.get_height()})
	observations.append({"name":name,"layout":data})


func _profile(size: Vector2i,density: float,insets: Rect2) -> void:
	root.size = size
	root.position = Vector2i(32,32)
	root.grab_focus()
	root.get_node("HostBridge")._options = {"displayDensity":density,"tableToken":TOKEN,"scene":"memory"}
	var mobile = root.get_node("MobileRuntime")
	mobile._android_safe_area_enabled = true
	mobile._safe_area_reader = func(_callback): return false
	mobile._safe_area_observation = {"window_size":size,"view_size":Vector2(size),"decor_size":Vector2(size),
		"render_rect":Rect2(Vector2.ZERO,Vector2(size)),"system_insets":insets,"insets":insets}
	mobile.safe_area_changed.emit()
	if is_instance_valid(table): table._layout()
	await _frames(6)


func _visible_targets() -> void:
	var safe_px := Rect2(table._safe_rect.position*table._density,table._safe_rect.size*table._density)
	var count := 0
	var rectangles: Array[Rect2] = []
	for card in table._cards:
		if not card.button.is_visible_in_tree(): continue
		count += 1
		var rect := _physical(card.button)
		_check(rect.size.x/table._density>=48.0 and rect.size.y/table._density>=48.0,"projected card >=48dp")
		_check(safe_px.grow(0.2).encloses(rect),"projected card inside measured safe view")
		_check(not rect.intersects(_physical(table.header)) and not rect.intersects(_physical(table.footer)),
			"card not hidden behind header/footer")
		# Independently intersect the real camera ray with actual room meshes.
		# Touchable rectangles alone did not catch the first tabletop occlusion.
		for corner in [Vector2.ZERO,Vector2(-0.46,0.46),Vector2(0.46,0.46),Vector2(0.46,-0.46),Vector2(-0.46,-0.46)]:
			var world: Vector3 = card.root.global_position+Vector3(corner.x*card.size.x,corner.y*card.size.y,0.057)
			var screen: Vector2 = table.camera.unproject_position(world)
			var origin: Vector3 = table.camera.project_ray_origin(screen)
			var direction: Vector3 = table.camera.project_ray_normal(screen)
			var card_distance := (world-origin).dot(direction)
			for child in table.get_children():
				if not child is MeshInstance3D or not child.visible: continue
				var bounds: AABB = child.global_transform*child.get_aabb()
				var near := 0.0
				var far := INF
				for axis in range(3):
					if absf(direction[axis]) < 0.00001:
						if origin[axis] < bounds.position[axis] or origin[axis] > bounds.end[axis]: far=-1.0
					else:
						var a := (bounds.position[axis]-origin[axis])/direction[axis]
						var b := (bounds.end[axis]-origin[axis])/direction[axis]
						near = maxf(near,minf(a,b))
						far = minf(far,maxf(a,b))
				_check(far < near or near > card_distance+0.02,"actual tabletop cannot occlude a projected card face")
		for earlier in rectangles: _check(not rect.intersects(earlier),"unique non-overlapping card target")
		rectangles.append(rect)
	_check(count>0,"visible board cards exist")
	for button in [table.back_button,table.pause_button,table.previous_button,table.next_button]:
		var rect := _physical(button)
		_check(rect.size.x/table._density>=48.0 and rect.size.y/table._density>=48.0,"toolbar >=48dp")
		_check(safe_px.grow(0.2).encloses(rect),"toolbar inside measured safe view")


func _run() -> void:
	if output.is_empty():
		push_error("LUMO_MEMORY_CAPTURE_DIR is required")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	original_touch = Input.emulate_touch_from_mouse
	Input.emulate_touch_from_mouse = true
	await _profile(Vector2i(960,540),1.0,Rect2())
	bridge = ObservedTransport.new()
	bridge.state = _state()
	var script: GDScript = load(TABLE)
	if script == null or not script.can_instantiate():
		_check(false,"production presenter compiles after autoload initialization")
		quit(1)
		return
	table = script.new()
	table._host = bridge
	root.add_child(table)
	await _frames(8)
	_check(table._state.token==TOKEN,"token bound")
	_visible_targets()
	await _snap("memory-landscape-hidden")
	for card in table._cards:
		_check(not card.front.visible and card.front.material_override.albedo_texture==null,
			"unrevealed card has no motif texture")
	var original: Dictionary = table._state.duplicate(true)
	for property in ["token","owner","roundId"]:
		var bad: Dictionary = original.duplicate(true)
		bad[property] = "x"
		_check(not table.apply_state(bad),"malformed identity refused "+property)
	var hidden_leak := original.duplicate(true)
	hidden_leak.cards[0].motif = "panda"
	_check(not table.apply_state(hidden_leak),"hidden motif leak refused")
	var fractional := original.duplicate(true)
	fractional.revision = 1.5
	_check(not table.apply_state(fractional),"fractional revision refused")
	var same_rev := original.duplicate(true)
	same_rev.line = "different"
	_check(not table.apply_state(same_rev),"different data at same revision refused")
	bridge.accept = false
	await _tap(table._cards[0].button,"rejected actual touch")
	_check(table._pending==0 and not table._cards[0].face,"transport failure never reveals a card")
	bridge.accept = true
	await _tap(table._cards[0].button,"first actual card touch")
	_check(table._pending>0 and bridge.requests.back().action=="flip" and int(bridge.requests.back().index)==0,"actual touch emits bounded intent")
	_check(not table._cards[0].face,"no visual reveal before authority")
	_check(not FileAccess.file_exists(table.OBSERVATION),"pending intent invalidates layout")
	var first := _reply({})
	first.cards[0] = {"index":0,"faceUp":true,"matched":false,"motif":"panda"}
	bridge.state = first.duplicate(true)
	_check(table.apply_state(first),"first confirmed card")
	await _frames(10)
	var angle: float = table._cards[0].root.rotation.y
	_check(angle>0.0 and angle<PI,"actual in-between flip angle")
	_check(not FileAccess.file_exists(table.OBSERVATION),"moving card has no settled layout")
	await _frames(28)
	_check(absf(table._cards[0].root.rotation.y)<0.0001,"flip reaches front")
	await _snap("memory-landscape-one-flipped")
	await _tap(table.pause_button,"actual pause")
	_check(not table.overlay.visible,"pause not inferred before acknowledgement")
	await _apply(_reply({"paused":true,"canFlip":false}))
	_check(table.overlay.visible,"acknowledged pause visible")
	await _snap("memory-landscape-paused")
	await _tap(table.resume_button,"actual resume")
	await _apply(_reply({"paused":false,"canFlip":true}))
	_check(not table.overlay.visible,"same round resumed")
	var matched_pair := _reply({"kindPairs":1,"kindMoves":1,"line":"Paar gefunden! Du bist nochmal dran."})
	matched_pair.cards[0].matched = true
	matched_pair.cards[1] = {"index":1,"faceUp":true,"matched":true,"motif":"panda"}
	await _apply(matched_pair)
	await _frames(32)
	_check(table._cards[0].matched.visible and table._cards[1].matched.visible,"matched pair has lasting shape marks")
	_check(table._cards[0].matched.get_child_count()==3 and table._cards[1].matched.get_child_count()==3,
		"matched check is raised mesh geometry rather than an unavailable glyph")
	await _snap("memory-landscape-matched")
	var profiles := [
		{"name":"phone","size":Vector2i(1080,2400),"density":2.625,"insets":Rect2(0,136,0,63)},
		{"name":"fold","size":Vector2i(2208,1840),"density":2.0,"insets":Rect2(0,72,0,48)},
		{"name":"compact","size":Vector2i(640,320),"density":1.0,"insets":Rect2()},
		{"name":"cutout","size":Vector2i(2400,1080),"density":2.625,"insets":Rect2(136,0,0,63)}
	]
	for profile in profiles:
		await _profile(profile.size,profile.density,profile.insets)
		for level in ["leicht","mittel","schwer","knifflig","profi"]:
			var next := _state(level)
			next.roundId = ("%032x" % (checks+1))
			next.revision = int(table._state.revision)+1
			next.ack = int(table._state.ack)
			next.rejected = int(table._state.rejected)
			await _apply(next)
			_visible_targets()
			var seen := {}
			for page in range(ceili(float(table._cards.size())/table._page_size)):
				for card in table._cards:
					if card.button.is_visible_in_tree(): seen[card.button.name]=true
				if not table.next_button.disabled:
					await _tap(table.next_button,"actual next page")
					await _frames(4)
			_check(seen.size()==int(next.count),"every real card reachable through actual pagination "+str(profile.name)+level)
			if level=="profi":
				table._page=0
				table._layout()
				await _snap("memory-"+profile.name+"-profi")
	var before_return: int = bridge.returns
	await _tap(table.back_button,"actual return")
	_check(bridge.returns==before_return,"no exit before durable authority acknowledgement")
	await _apply(_reply({"paused":true,"canFlip":false,"exit":true}))
	_check(bridge.returns==before_return+1,"only acknowledged return reaches Flutter boundary")
	table.queue_free()
	await _frames(4)
	_check(not FileAccess.file_exists("user://memory_layout_v1.json"),"scene exit removes ephemeral layout")
	Input.emulate_touch_from_mouse = original_touch
	var result := {"status":"PASS" if errors.is_empty() else "FAIL","checks":checks,"errors":errors,
		"scope":"Production Godot presenter; synthetic public-state/transport fixture and actual ScreenTouch events; no Dart, Android, wallet or device FPS claim.",
		"capture":capture,"captures":captures,"inputs":inputs,"observations":observations}
	var file := FileAccess.open(output+"/memory-view-result.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
	file.close()
	print("MEMORY_VIEW_%s checks=%d captures=%d" % ["PASS" if errors.is_empty() else "FAIL",checks,captures.size()])
	quit(0 if errors.is_empty() else 1)
