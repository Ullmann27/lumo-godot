extends Node3D
## Presentation-only Memory table. The Dart controller owns the deck, opponent,
## timing, score, settings, persistence and wallet. Hidden motifs never arrive.

const LUMO = preload("res://scripts/characters/lumo/lumo_rigged_actor.gd")
const OBSERVATION := "user://memory_layout_v1.json"
const LEVELS := ["leicht", "mittel", "schwer", "knifflig", "profi"]
const COUNTS := [8, 12, 16, 20, 24]
const PACKS := ["alle", "tiere", "weltall", "garten"]
const MOTIFS := {
	"panda":["Panda","face_panda"], "giraffe":["Giraffe","face_giraffe"],
	"lumo":["Lumo","fox_avatar"], "hase":["Hase","face_bunny"],
	"pinguin":["Pinguin","face_penguin"], "stern":["Sternchen","sticker_star"],
	"laterne":["Laterne","sticker_lantern"], "truhe":["Schatztruhe","sticker_chest"],
	"note":["Notenfreund","sticker_note"], "fahne":["Sternenfahne","sticker_flag"],
	"pilz":["Pilz","sticker_mushroom"], "stein":["Stachelstein","sticker_rock"]
}
const CARD_ASPECT := 0.76
var _host: Object
var _token := ""
var _state: Dictionary = {}
var _previous: Dictionary = {}
var _sequence := 0
var _pending := 0
var _poll := 0.0
var _closed := false
var _round := ""
var _page := 0
var _page_size := 24
var _columns := 4
var _rows := 6
var _cards: Array[Dictionary] = []
var _textures: Dictionary = {}
var _dirty := true
var _layout_frames := 2
var _layout_sequence := 0
var _retry_at := 0
var _density := 1.0
var _safe_rect := Rect2()
var _board_rect := Rect2()
var _dismissed_result := ""
var camera: Camera3D
var fox: Node3D
var ui: Control
var safe: Control
var header: PanelContainer
var footer: PanelContainer
var overlay: PanelContainer
var menu_scroll: ScrollContainer
var title: Label
var scores: Label
var status: Label
var detail: Label
var page_label: Label
var back_button: Button
var pause_button: Button
var resume_button: Button
var restart_button: Button
var previous_button: Button
var next_button: Button
var level_buttons: Array[Button] = []
var pack_buttons: Array[Button] = []
var _theme: Theme


func _ready() -> void:
	var window := get_window()
	_previous = {"scale":window.content_scale_size,"mode":window.content_scale_mode,
		"quit":get_tree().quit_on_go_back,"accept":get_tree().auto_accept_quit,
		"orientation":DisplayServer.screen_get_orientation()}
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_tree().quit_on_go_back = false
	get_tree().auto_accept_quit = false
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR)
	if _host == null and Engine.has_singleton("LumoHost"):
		_host = Engine.get_singleton("LumoHost")
	_token = str(HostBridge.launch_options().get("tableToken", ""))
	_build_room()
	_build_ui()
	window.size_changed.connect(_layout)
	MobileRuntime.safe_area_changed.connect(_layout)
	_layout()
	_poll_state()


func _exit_tree() -> void:
	_closed = true
	DirAccess.remove_absolute(OBSERVATION)
	DirAccess.remove_absolute(OBSERVATION + ".tmp")
	_clear_cards()
	if MobileRuntime.safe_area_changed.is_connected(_layout):
		MobileRuntime.safe_area_changed.disconnect(_layout)
	if get_window().size_changed.is_connected(_layout):
		get_window().size_changed.disconnect(_layout)
	if not _previous.is_empty():
		get_window().content_scale_size = _previous.scale
		get_window().content_scale_mode = _previous.mode
		get_tree().quit_on_go_back = _previous.quit
		get_tree().auto_accept_quit = _previous.accept
		if OS.has_feature("mobile"):
			DisplayServer.screen_set_orientation(_previous.orientation)


func _notification(what: int) -> void:
	if what in [NOTIFICATION_WM_GO_BACK_REQUEST, NOTIFICATION_WM_CLOSE_REQUEST]:
		_send("pause")


func _process(delta: float) -> void:
	_poll += delta
	if _poll >= 0.08:
		_poll = 0.0
		_poll_state()
	_publish_layout()


func _poll_state() -> void:
	if _closed or not is_instance_valid(_host):
		return
	var raw: Variant = JSON.parse_string(str(_host.call("getTableState")))
	if raw is Dictionary:
		apply_state(raw)


func _integer(value: Variant, lo: int, hi: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and value >= lo and value <= hi


func _hex(value: Variant, length: int) -> bool:
	if not value is String or value.length() != length:
		return false
	for character in value:
		if character not in "0123456789abcdef":
			return false
	return true


func _valid_state(value: Dictionary) -> bool:
	if value.get("schema") != 1 or value.get("game") != "memory" or value.get("token") != _token or not _hex(_token,32):
		return false
	if not _hex(value.get("roundId"),32) or not _hex(value.get("owner"),64):
		return false
	for key in ["revision","recordRevision"]:
		if not _integer(value.get(key),1,999999999):
			return false
	for key in ["ack","rejected"]:
		if not _integer(value.get(key),0,1000000000):
			return false
	for key in ["paused","canFlip","exit","reduceMotion","rewarded","complete"]:
		if not value.get(key) is bool:
			return false
	if value.get("difficulty") not in LEVELS or value.get("pack") not in PACKS:
		return false
	var count: int = COUNTS[LEVELS.find(value.difficulty)]
	if value.get("count") != count or not value.get("cards") is Array or value.cards.size() != count:
		return false
	for index in range(count):
		var card: Variant = value.cards[index]
		if not card is Dictionary or card.get("index") != index or not card.get("faceUp") is bool or not card.get("matched") is bool:
			return false
		if card.faceUp:
			if card.get("motif") not in MOTIFS:
				return false
		elif card.get("motif") != null:
			return false
		if card.matched and not card.faceUp:
			return false
	if value.get("turn") not in ["kind","lumo"] or value.get("phase") not in ["select","resolve","botFirst","botSecond","complete"]:
		return false
	for key in ["kindPairs","lumoPairs"]:
		if not _integer(value.get(key),0,count/2):
			return false
	if not _integer(value.get("kindMoves"),0,1000000000) or not _integer(value.get("kindStreak"),0,count/2) or not _integer(value.get("remainingMs"),0,900):
		return false
	return value.get("line") is String and value.line.length() <= 400 and _integer(value.get("stars"),0,5)


func apply_state(value: Dictionary) -> bool:
	if not _valid_state(value):
		return false
	if not _state.is_empty():
		if value.owner != _state.owner or int(value.revision) < int(_state.revision):
			return false
		if int(value.revision) == int(_state.revision):
			return value == _state
		if int(value.ack) < int(_state.ack) or int(value.rejected) < int(_state.rejected):
			return false
	var new_round: bool = value.roundId != _round
	_state = value.duplicate(true)
	_sequence = maxi(_sequence,maxi(int(value.ack),int(value.rejected)))
	if _pending <= maxi(int(value.ack),int(value.rejected)):
		_pending = 0
	if new_round:
		_round = value.roundId
		_page = 0
		_dismissed_result = ""
		_clear_cards()
		for index in range(int(value.count)):
			_cards.append(_create_card(index))
		_layout()
	for index in range(_cards.size()):
		_sync_card(index, new_round)
	_invalidate()
	_update_ui()
	if value.exit and _pending == 0 and is_instance_valid(_host):
		_closed = HostBridge.durable_ack(_host.call("returnToApp","games",""))
	return true


func _send(action: String, extras: Dictionary = {}) -> bool:
	if _closed or _pending > 0 or _state.is_empty() or not is_instance_valid(_host) or not MobileRuntime.safe_area_is_ready():
		return false
	if action == "flip":
		var index := int(extras.get("index",-1))
		if not bool(_state.canFlip) or bool(_state.paused) or index < 0 or index >= _cards.size() or _animating() or not _cards[index].button.is_visible_in_tree():
			return false
		if _state.cards[index].faceUp or _state.cards[index].matched:
			return false
	_sequence += 1
	var request := {"token":_token,"roundId":_state.roundId,"revision":int(_state.revision),
		"sequence":_sequence,"action":action}
	request.merge(extras)
	if not HostBridge.durable_ack(_host.call("submitTableAction",JSON.stringify(request))):
		status.text = "Eingabe noch nicht bestätigt. Bitte erneut versuchen."
		return false
	_pending = _sequence
	_invalidate()
	_update_ui()
	return true


func _material(color: Color, roughness: float = 0.7) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color.srgb_to_linear()
	material.roughness = roughness
	return material


func _box(parent: Node3D, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = at
	mesh.material_override = material
	parent.add_child(mesh)
	return mesh


func _rounded_mesh(width: float,height: float,depth: float) -> ArrayMesh:
	var points: Array[Vector2] = []
	var radius := minf(width,height)*0.12
	for corner in range(4):
		var center := Vector2((width*0.5-radius)*(1 if corner in [0,3] else -1),
			(height*0.5-radius)*(1 if corner in [0,1] else -1))
		for step in range(9):
			var angle := float(corner)*PI*0.5 + float(step)*PI/16.0
			points.append(center+Vector2(cos(angle),sin(angle))*radius)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(points.size()):
		var a := points[i]
		var b := points[(i+1)%points.size()]
		for side in [1.0,-1.0]:
			var verts := [Vector3(0,0,depth*side/2),Vector3(a.x,a.y,depth*side/2),Vector3(b.x,b.y,depth*side/2)]
			if side < 0: verts.reverse()
			for point in verts:
				tool.set_normal(Vector3(0,0,side))
				tool.add_vertex(point)
		var normal := Vector3((a+b).x,(a+b).y,0).normalized()
		var side_vertices := [Vector3(a.x,a.y,-depth/2),Vector3(b.x,b.y,-depth/2),
			Vector3(b.x,b.y,depth/2),Vector3(a.x,a.y,depth/2)]
		for vertex in [0,1,2,0,2,3]:
			tool.set_normal(normal)
			tool.add_vertex(side_vertices[vertex])
	return tool.commit()


func _create_card(index: int) -> Dictionary:
	var root := Node3D.new()
	root.name = "AcknowledgedCard%d" % index
	add_child(root)
	var body := MeshInstance3D.new()
	body.material_override = _material(Color("f2d6a7"),0.62)
	root.add_child(body)
	var front := MeshInstance3D.new()
	var face := QuadMesh.new()
	face.size = Vector2(0.66,0.86)
	front.mesh = face
	front.position.z = 0.057
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color("fff4da")
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	front.material_override = material
	root.add_child(front)
	var back := MeshInstance3D.new()
	back.mesh = face.duplicate()
	back.position.z = -0.057
	back.rotation.y = PI
	back.material_override = _material(Color("207a87"),0.72)
	root.add_child(back)
	var mark := Label3D.new()
	mark.text = "?"
	mark.font_size = 72
	mark.pixel_size = 0.007
	mark.modulate = Color("fff0ba")
	mark.position.z = -0.062
	mark.rotation.y = PI
	mark.outline_size = 0
	root.add_child(mark)
	# A real raised check mark remains legible independently of font glyphs
	# and of the transparent motif texture's render order.
	var matched := Node3D.new()
	matched.position = Vector3(0,-0.29,0.13)
	var badge := MeshInstance3D.new()
	badge.mesh = _rounded_mesh(0.40,0.34,0.025)
	badge.material_override = _material(Color("14533d"))
	matched.add_child(badge)
	var check_material := _material(Color("fff4b3"))
	check_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var short_stroke := _box(matched,Vector3(0.045,0.12,0.025),Vector3(-0.07,-0.025,0.025),check_material)
	short_stroke.rotation.z = PI/4.0
	var long_stroke := _box(matched,Vector3(0.045,0.27,0.025),Vector3(0.055,0.035,0.025),check_material)
	long_stroke.rotation.z = -PI/4.0
	root.add_child(matched)
	var button := Button.new()
	button.name = "MemoryCard%d" % index
	button.flat = true
	for variant in ["normal","hover","pressed","disabled","focus"]:
		button.add_theme_stylebox_override(variant,StyleBoxEmpty.new())
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(_send.bind("flip",{"index":index}))
	safe.add_child(button)
	safe.move_child(button,0)
	return {"root":root,"body":body,"front":front,"back":back,"mark":mark,"matched":matched,
		"button":button,"tween":null,"face":false,"motif":"","size":Vector2.ZERO,"target":Rect2()}


func _clear_cards() -> void:
	for card in _cards:
		if is_instance_valid(card.tween): card.tween.kill()
		if is_instance_valid(card.button):
			card.button.hide()
			card.button.queue_free()
		if is_instance_valid(card.root):
			card.root.hide()
			card.root.queue_free()
	_cards.clear()


func _sync_card(index: int, immediate: bool) -> void:
	var card := _cards[index]
	var public_card: Dictionary = _state.cards[index]
	var showing: bool = public_card.faceUp
	if showing and str(card.motif) != str(public_card.motif):
		var motif: String = public_card.motif
		if not _textures.has(motif):
			_textures[motif] = load("res://assets/games/memory/%s.png" % MOTIFS[motif][1])
		card.front.material_override.albedo_texture = _textures[motif]
		card.front.visible = true
		card.motif = motif
	card.matched.visible = bool(public_card.matched)
	card.body.material_override.albedo_color = (Color("f8d76a") if public_card.matched else Color("f2d6a7")).srgb_to_linear()
	card.button.tooltip_text = "Karte %d · %s" % [index+1, MOTIFS[public_card.motif][0] if showing else "verdeckt"]
	if immediate or bool(_state.reduceMotion):
		if is_instance_valid(card.tween): card.tween.kill()
		card.root.rotation.y = 0.0 if showing else PI
		card.face = showing
		if not showing:
			card.front.hide()
			card.front.material_override.albedo_texture = null
			card.motif = ""
	elif bool(card.face) != showing:
		if is_instance_valid(card.tween): card.tween.kill()
		card.face = showing
		var tween := create_tween()
		card.tween = tween
		tween.tween_property(card.root,"rotation:y",0.0 if showing else PI,0.46).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		tween.finished.connect(_flip_finished.bind(index,showing,_round))
	if is_instance_valid(card.tween):
		if _state.paused: card.tween.pause()
		else: card.tween.play()


func _flip_finished(index: int,showing: bool,round_id: String) -> void:
	if round_id != _round or index >= _cards.size(): return
	var card := _cards[index]
	card.tween = null
	if not showing:
		card.front.hide()
		card.front.material_override.albedo_texture = null
		card.motif = ""
	_invalidate()
	_update_ui()


func _animating() -> bool:
	for card in _cards:
		if is_instance_valid(card.tween) and card.tween.is_valid():
			return true
	return false


func _build_room() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("163b38")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b4d9c5")
	environment.ambient_light_energy = 0.6
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-25,-25,0)
	sun.light_energy = 0.8
	sun.light_color = Color("fff3d6")
	sun.shadow_enabled = true
	add_child(sun)
	_box(self,Vector3(30,30,0.4),Vector3(0,0,-1.1),_material(Color("284e43")))
	# The camera-facing layout plane has a small depth gradient under tilt.
	# Keep the physical tabletop behind every card, including the top corners.
	_box(self,Vector3(14,13,0.30),Vector3(0,0,-0.78),_material(Color("b48b60")))
	_box(self,Vector3(13.6,12.6,0.12),Vector3(0,0,-0.60),_material(Color("32665a")))
	fox = LUMO.new()
	fox.position = Vector3(4.5,-2,1.0)
	fox.rotation = Vector3(0,-0.35,0)
	fox.scale = Vector3.ONE*0.8
	add_child(fox)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.current = true
	camera.position = Vector3(0,0,14)
	camera.rotation = Vector3(-0.035,0.035,0)
	add_child(camera)


func _panel(color: Color,radius: int=14) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


func _button(caption: String,callback: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(52,52)
	button.pressed.connect(callback)
	return button


func _label(caption: String,size: int=18) -> Label:
	var label := Label.new()
	label.text = caption
	label.add_theme_font_size_override("font_size",size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	_theme = Theme.new()
	_theme.default_font_size = 18
	_theme.set_color("font_color","Button",Color("fff6df"))
	for variant in ["normal","hover","pressed","disabled"]:
		_theme.set_stylebox(variant,"Button",_panel(Color("275d59") if variant != "disabled" else Color("334a44")))
	ui.theme = _theme
	safe = Control.new()
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(safe)
	header = PanelContainer.new()
	header.add_theme_stylebox_override("panel",_panel(Color("102e2ef5")))
	safe.add_child(header)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",6)
	header.add_child(row)
	back_button = _button("Zurück",_send.bind("exit"))
	row.add_child(back_button)
	title = _label("Memory",22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	pause_button = _button("Pause",_send.bind("pause"))
	row.add_child(pause_button)
	scores = _label("Du 0  ·  Lumo 0",18)
	scores.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(scores)
	footer = PanelContainer.new()
	footer.add_theme_stylebox_override("panel",_panel(Color("102e2ef5")))
	safe.add_child(footer)
	var lower := VBoxContainer.new()
	footer.add_child(lower)
	status = _label("Deine Memory-Runde wird geladen …",17)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size.y = 24
	lower.add_child(status)
	var pages := HBoxContainer.new()
	lower.add_child(pages)
	previous_button = _button("‹",_change_page.bind(-1))
	pages.add_child(previous_button)
	page_label = _label("",16)
	page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pages.add_child(page_label)
	next_button = _button("›",_change_page.bind(1))
	pages.add_child(next_button)
	overlay = PanelContainer.new()
	overlay.name = "MemoryPauseAndResult"
	overlay.add_theme_stylebox_override("panel",_panel(Color("102e2efa")))
	safe.add_child(overlay)
	menu_scroll = ScrollContainer.new()
	menu_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu_scroll.get_v_scroll_bar().value_changed.connect(func(_v): _invalidate())
	overlay.add_child(menu_scroll)
	var menu := VBoxContainer.new()
	menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu.add_theme_constant_override("separation",8)
	menu_scroll.add_child(menu)
	detail = _label("",19)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu.add_child(detail)
	resume_button = _button("Fortsetzen",_resume)
	menu.add_child(resume_button)
	restart_button = _button("Neue Runde",_send.bind("restart"))
	menu.add_child(restart_button)
	menu.add_child(_label("Brettgröße",17))
	for i in range(LEVELS.size()):
		var button := _button("%s · %d Karten" % [LEVELS[i].capitalize(),COUNTS[i]],_send.bind("difficulty",{"difficulty":LEVELS[i]}))
		menu.add_child(button)
		level_buttons.append(button)
	menu.add_child(_label("Kartenmotive",17))
	for pack in PACKS:
		var button := _button(pack.capitalize(),_send.bind("pack",{"pack":pack}))
		menu.add_child(button)
		pack_buttons.append(button)
	for button in [resume_button,restart_button]+level_buttons+pack_buttons:
		button.mouse_filter = Control.MOUSE_FILTER_PASS
	overlay.hide()


func _resume() -> void:
	if _state.get("complete",false): _dismissed_result = str(_state.roundId)
	_send("resume")


func _choose_grid(count: int,width: float,height: float) -> Dictionary:
	var candidates: Array[int] = [count]
	for limit in [12,8,6,4,2,1]:
		if limit < count: candidates.append(limit)
	for page_count in candidates:
		var best := {}
		var best_area := 0.0
		for cols in range(1,mini(page_count,8)+1):
			var rows := ceili(float(page_count)/cols)
			var cw := minf((width-8*(cols-1))/cols,(height-8*(rows-1))/rows*CARD_ASPECT)
			if cw < 50.0: continue
			if cw*cw > best_area:
				best = {"page_size":page_count,"cols":cols,"rows":rows,"width":cw,"height":cw/CARD_ASPECT}
				best_area = cw*cw
		if not best.is_empty(): return best
	return {"page_size":1,"cols":1,"rows":1,"width":50.0,"height":50.0/CARD_ASPECT}


func _layout() -> void:
	if not is_instance_valid(ui): return
	_invalidate()
	_density = MobileRuntime.get_ui_density()
	get_window().content_scale_size = Vector2i(Vector2(get_window().size)/_density)
	var logical := Vector2(get_window().content_scale_size)
	var insets := Rect2()
	if OS.has_feature("mobile") or MobileRuntime.requires_safe_area_observation():
		insets = MobileRuntime.get_safe_area_insets()
	var factor := logical/Vector2(get_window().size)
	_safe_rect = Rect2(insets.position*factor,logical-(insets.position+insets.size)*factor)
	safe.position = _safe_rect.position
	safe.size = _safe_rect.size
	safe.visible = MobileRuntime.safe_area_is_ready()
	header.position = Vector2(8,5)
	header.size = Vector2(safe.size.x-16,64)
	scores.position = Vector2(8,69)
	scores.size = Vector2(safe.size.x-16,28)
	var footer_height := 92.0
	footer.position = Vector2(8,safe.size.y-footer_height-5)
	footer.size = Vector2(safe.size.x-16,footer_height)
	_board_rect = Rect2(safe.position+Vector2(12,104),Vector2(maxf(50,safe.size.x-24),maxf(66,safe.size.y-210)))
	var fox_room := safe.size.x >= 850.0 and safe.size.y >= 480.0
	if fox_room: _board_rect.size.x -= 170.0
	overlay.position = Vector2(8,75)
	overlay.size = Vector2(safe.size.x-16,maxf(80,safe.size.y-83))
	camera.size = logical.y/100.0
	var count: int = int(_state.get("count",8))
	var grid := _choose_grid(count,_board_rect.size.x,_board_rect.size.y)
	_page_size = int(grid.page_size)
	_columns = int(grid.cols)
	_rows = int(grid.rows)
	_page = clampi(_page,0,maxi(0,ceili(float(count)/_page_size)-1))
	var grid_size := Vector2(_columns*grid.width+8*(_columns-1),_rows*grid.height+8*(_rows-1))
	var start := _board_rect.get_center()-grid_size/2
	var pixel_factor := get_viewport().get_visible_rect().size/logical
	for index in range(_cards.size()):
		var card := _cards[index]
		var offset := index-_page*_page_size
		var visible: bool = offset >= 0 and offset < _page_size
		card.root.visible = visible
		card.button.visible = visible
		if not visible: continue
		var pos := start+Vector2(offset%_columns*(grid.width+8),floori(float(offset)/_columns)*(grid.height+8))
		var target := Rect2(pos,Vector2(grid.width,grid.height))
		card.target = target
		card.size = target.size/100.0
		card.root.position = camera.project_position(target.get_center()*pixel_factor,14.0)
		card.body.mesh = _rounded_mesh(card.size.x,card.size.y,0.11)
		card.front.mesh.size = card.size*0.92
		card.back.mesh.size = card.size*0.92
		card.mark.pixel_size = minf(card.size.x,card.size.y)/110.0
		card.matched.position.y = -card.size.y*0.35
		card.matched.scale = Vector3.ONE*minf(card.size.x/0.95,1.4)
		# Bounds come from the actual projected face. No fixed device tap point.
		var quad := _card_quad(card)
		var rect := Rect2(quad[0],Vector2.ZERO)
		for point in quad: rect = rect.expand(point)
		card.button.position = rect.position-safe.position
		card.button.size = rect.size
	fox.visible = fox_room
	if fox_room:
		fox.position = camera.project_position(Vector2(_safe_rect.end.x-86,_safe_rect.position.y+_safe_rect.size.y*0.72)*pixel_factor,12.8)
		fox.scale = Vector3.ONE*0.74
	_update_ui()


func _change_page(direction: int) -> void:
	if _pending > 0 or _animating(): return
	_page = clampi(_page+direction,0,maxi(0,ceili(float(_cards.size())/_page_size)-1))
	_layout()


func _update_ui() -> void:
	if not is_instance_valid(status): return
	var ready := not _state.is_empty()
	var paused := bool(_state.get("paused",true))
	var complete := bool(_state.get("complete",false))
	var waiting := _pending > 0
	back_button.disabled = not ready or waiting
	pause_button.disabled = not ready or waiting or paused
	previous_button.disabled = _page == 0 or waiting or _animating()
	next_button.disabled = (_page+1)*_page_size >= _cards.size() or waiting or _animating()
	page_label.text = "%d–%d von %d Karten" % [_page*_page_size+1,mini((_page+1)*_page_size,_cards.size()),_cards.size()]
	if not ready: return
	scores.text = "Du %d  ·  Lumo %d  ·  %d %s" % [int(_state.kindPairs),int(_state.lumoPairs),int(_state.kindMoves),"Zug" if int(_state.kindMoves)==1 else "Züge"]
	status.text = "Wird gespeichert …" if waiting else str(_state.line)
	if _state.get("error") != null: status.text = str(_state.error)
	overlay.visible = paused or (complete and _dismissed_result != str(_state.roundId))
	detail.text = "Memory pausiert. Deine Runde bleibt gespeichert." if paused and not complete else str(_state.line)
	if complete: detail.text += "\n%d Sterne · Dein Ergebnis bleibt gespeichert." % int(_state.stars)
	resume_button.text = "Brett ansehen" if complete else "Fortsetzen"
	resume_button.disabled = waiting
	restart_button.disabled = waiting or (complete and not bool(_state.rewarded))
	for i in range(level_buttons.size()):
		level_buttons[i].disabled = waiting or _state.difficulty == LEVELS[i] or (complete and not bool(_state.rewarded))
	for i in range(pack_buttons.size()):
		pack_buttons[i].disabled = waiting or _state.pack == PACKS[i] or (complete and not bool(_state.rewarded))
	for i in range(_cards.size()):
		_cards[i].button.disabled = waiting or paused or complete or not bool(_state.canFlip) or _animating() or bool(_state.cards[i].faceUp) or bool(_state.cards[i].matched)
	fox.set("reduced_motion",bool(_state.reduceMotion))
	fox.set("suspended",paused)


func _invalidate() -> void:
	DirAccess.remove_absolute(OBSERVATION)
	_dirty = true
	_layout_frames = 2


func _card_quad(card: Dictionary) -> Array[Vector2]:
	var result: Array[Vector2] = []
	# Axis-aligned rest geometry, independent of its animated flip transform.
	for corner in [Vector2(-0.5,0.5),Vector2(0.5,0.5),Vector2(0.5,-0.5),Vector2(-0.5,-0.5)]:
		var world: Vector3 = card.root.position+Vector3(corner.x*card.size.x,corner.y*card.size.y,0.057)
		result.append(camera.unproject_position(world))
	return result


func _v2(value: Vector2) -> Array: return [value.x,value.y]
func _v3(value: Vector3) -> Array: return [value.x,value.y,value.z]
func _r4(value: Rect2) -> Array: return [value.position.x,value.position.y,value.size.x,value.size.y]


func _physical(control: Control) -> Rect2:
	var factor := Vector2(get_window().size)/get_viewport().get_visible_rect().size
	var transform := control.get_global_transform_with_canvas()
	return Rect2((transform*Vector2.ZERO)*factor,control.size*transform.get_scale()*factor)


func _button_observation(button: Button,id: String) -> Dictionary:
	var rect := _physical(button)
	var hit := rect.intersection(Rect2(Vector2.ZERO,Vector2(get_window().size)))
	var parent := button.get_parent()
	while parent != null:
		if parent is Control and parent.clip_contents: hit = hit.intersection(_physical(parent))
		parent = parent.get_parent()
	return {"id":id,"text":button.text,"rect_px":_r4(rect),"hit_rect_px":_r4(hit),
		"visible":button.is_visible_in_tree(),"enabled":not button.disabled,"clipped":not hit.grow(0.1).encloses(rect)}


func _publish_layout() -> void:
	if not _dirty or _closed or _state.is_empty() or _pending > 0 or not safe.is_visible_in_tree() or _animating(): return
	if _layout_frames > 0:
		_layout_frames -= 1
		return
	if Time.get_ticks_msec() < _retry_at: return
	var buttons := [_button_observation(back_button,"back"),_button_observation(pause_button,"pause"),
		_button_observation(resume_button,"resume"),_button_observation(restart_button,"restart"),
		_button_observation(previous_button,"previous_page"),_button_observation(next_button,"next_page")]
	for i in range(level_buttons.size()): buttons.append(_button_observation(level_buttons[i],"difficulty_"+LEVELS[i]))
	for i in range(pack_buttons.size()): buttons.append(_button_observation(pack_buttons[i],"pack_"+PACKS[i]))
	var factor := Vector2(get_window().size)/get_viewport().get_visible_rect().size
	var cards := []
	for index in range(_cards.size()):
		var card := _cards[index]
		var row := _button_observation(card.button,"card_%d" % index)
		row["index"] = index
		row["faceUp"] = bool(_state.cards[index].faceUp)
		row["matched"] = bool(_state.cards[index].matched)
		row["motif"] = _state.cards[index].motif
		row["world_center"] = _v3(card.root.position)
		row["world_size"] = _v2(card.size)
		row["quad"] = _card_quad(card).map(func(point): return _v2(point*factor))
		cards.append(row)
	var observed := MobileRuntime.get_safe_area_observation()
	var android := {}
	for key in ["view_size","decor_size"]:
		if observed.has(key): android[key] = _v2(observed[key])
	for key in ["render_rect","system_insets","insets"]:
		if observed.has(key): android[key] = _r4(observed[key])
	_layout_sequence += 1
	var snapshot := {"schema":1,"game":"memory","settled":true,"layout_sequence":int(_layout_sequence),
		"ticks_msec":int(Time.get_ticks_msec()),"pid":int(OS.get_process_id()),"token":_token,
		"owner":str(_state.owner),"roundId":str(_state.roundId),"revision":int(_state.revision),
		"recordRevision":int(_state.recordRevision),"ack":int(_state.ack),"rejected":int(_state.rejected),
		"pending":int(_pending),"paused":bool(_state.paused),"canFlip":bool(_state.canFlip),
		"turn":str(_state.turn),"phase":str(_state.phase),"difficulty":str(_state.difficulty),"pack":str(_state.pack),
		"page":_page,"page_size":_page_size,"density":_density,"window_px":_v2(Vector2(get_window().size)),
		"viewport_px":_v2(get_viewport().get_visible_rect().size),"safe_rect":_r4(Rect2(_safe_rect.position*factor,_safe_rect.size*factor)),
		"coordinate_space":"godot_window_px; map through android_observation.render_rect for decor screenshots",
		"observation_source":"android_window_insets" if OS.has_feature("android") and not observed.is_empty() else "platform_fixture" if MobileRuntime.requires_safe_area_observation() else "platform_safe_area",
		"android_observation":android,"buttons":buttons,"cards":cards,
		"camera":{"projection":"orthogonal","size":camera.size,"keep_aspect":int(camera.keep_aspect),
			"origin":_v3(camera.global_position),"basis":[_v3(camera.global_basis.x),_v3(camera.global_basis.y),_v3(camera.global_basis.z)]}}
	var file := FileAccess.open(OBSERVATION+".tmp",FileAccess.WRITE)
	if file == null:
		_retry_at = Time.get_ticks_msec()+2000
		return
	file.store_string(JSON.stringify(snapshot))
	file.flush()
	var error := file.get_error()
	file.close()
	if error == OK: error = DirAccess.rename_absolute(OBSERVATION+".tmp",OBSERVATION)
	if error == OK: _dirty = false
	else: _retry_at = Time.get_ticks_msec()+2000
