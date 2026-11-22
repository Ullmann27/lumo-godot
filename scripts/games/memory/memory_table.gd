extends Node3D
## Presentation-only Memory table. The Dart controller owns the deck, opponent,
## timing, score, settings, persistence and wallet. Hidden motifs never arrive.

const LUMO = preload("res://scripts/characters/lumo/lumo_rigged_actor.gd")
const LOOK = preload("res://scripts/games/memory/memory_table_look.gd")
const KIT = preload("res://scripts/games/table_room/table_room_kit.gd")
const SEAT = preload("res://scripts/games/cards/cards_seat.gd")
## Echte 3D-Tischszene: Tischplatte waagrecht, Kamera schräg von vorn oben.
const CAMERA_ELEVATION := 56.0
const CAMERA_FOV := 30.0
const TABLE_HEIGHT := 0.98
## Längste Seite der Tischplatte in Metern.
## Großer Spieltisch: so bleibt Lumo neben den Karten in natürlicher Größe.
const TABLE_SPAN := 3.2
## Die hinteren Karten erscheinen in der Schrägsicht kleiner; die Rasterwahl
## plant dafür Reserve ein, damit jede Karte ≥ 48 dp bleibt.
const PERSPECTIVE_RESERVE := 1.3
## Karten liegen mit der Rückseite knapp auf dem Filz (Brett-Einheiten).
const CARD_Z := 0.058
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
## Felt margin and wooden rim around the grid, in world units (1 = 100 px).
const TABLE_MARGIN := 0.10
const TABLE_RIM := 0.09
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
var lumo_seat: Node3D
var room_root: Node3D
var _board: Node3D
var _legs: Array[MeshInstance3D] = []
var _chair: Node3D
var _room_light: SpotLight3D
var _lumo_pairs_seen := -1
var _lumo_turn := false
var _was_complete := false
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
var _budget: Dictionary = {}
var _back_material: ShaderMaterial
var _backdrop_material: ShaderMaterial
var _felt_material: ShaderMaterial
var _shadows: MultiMeshInstance3D
var _mat: MeshInstance3D
var _rim: MeshInstance3D
var _mat_size := Vector2.ZERO
var _table_scale := 1.0
var _sparkles: Array[CPUParticles3D] = []
var _next_sparkle := 0
var _kind_pairs_seen := -1
var _sun: DirectionalLight3D
var _fill: DirectionalLight3D
var turn_chip: Label
var progress: ProgressBar
var _scoreboard: HBoxContainer
var _selected_style: StyleBoxFlat


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
	# Erste Einführung je Kind (nur wenn das Kind am Zug ist): scripts/games/guides/memory_guide.gd
	load("res://scripts/games/guides/memory_guide.gd").attach(self)
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
	_update_shadows()
	if is_instance_valid(lumo_seat): lumo_seat.advance(delta)
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
	var kind_pairs := int(value.kindPairs)
	if not new_round and kind_pairs > _kind_pairs_seen and _kind_pairs_seen >= 0 and \
			not bool(value.reduceMotion) and is_instance_valid(lumo_seat):
		# Lumo freut sich mit, wenn das Kind ein Paar findet.
		lumo_seat.react("happy")
	_kind_pairs_seen = kind_pairs
	_react_lumo(value,new_round)
	_invalidate()
	_update_ui()
	if value.exit and _pending == 0 and is_instance_valid(_host):
		_closed = HostBridge.durable_ack(_host.call("returnToApp","games",""))
	return true


## Lumo spielt mit: überlegt an seinem Zug, schaut auf aufgedeckte Karten,
## ärgert sich kurz über ein verpasstes Paar, jubelt über sein eigenes.
func _react_lumo(value: Dictionary,new_round: bool) -> void:
	if not is_instance_valid(lumo_seat) or not lumo_seat.usable(): return
	var lumo_pairs := int(value.lumoPairs)
	if not new_round and lumo_pairs > _lumo_pairs_seen and _lumo_pairs_seen >= 0:
		lumo_seat.react("happy")
	_lumo_pairs_seen = lumo_pairs
	var lumo_turn := str(value.turn) == "lumo" and not bool(value.complete)
	if lumo_turn and not _lumo_turn:
		lumo_seat.react("think")
	elif not lumo_turn and _lumo_turn:
		lumo_seat.calm()
	_lumo_turn = lumo_turn
	# Blick auf die zuletzt aufgedeckte, noch offene Karte – sonst zum Kind.
	var focus := -1
	for index in range(mini(_cards.size(),value.cards.size())):
		if bool(value.cards[index].faceUp) and not bool(value.cards[index].matched) and _cards[index].root.visible:
			focus = index
	if focus >= 0:
		lumo_seat.look_at_point(_cards[focus].root.global_position)
	elif is_instance_valid(camera):
		lumo_seat.look_at_point(camera.global_position)
	if bool(value.complete) and not _was_complete and not new_round:
		lumo_seat.react("happy" if int(value.kindPairs) >= lumo_pairs else "wave")
	_was_complete = bool(value.complete)


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
	_board.add_child(root)
	var body := MeshInstance3D.new()
	body.material_override = LOOK.card_body()
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
	# One shared LUMO star back for every card keeps the board batched.
	back.material_override = _back_material
	root.add_child(back)
	# A real raised check mark remains legible independently of font glyphs
	# and of the transparent motif texture's render order.
	var matched := Node3D.new()
	matched.position = Vector3(0,-0.29,0.13)
	var badge := MeshInstance3D.new()
	badge.mesh = _rounded_mesh(0.40,0.34,0.025)
	badge.material_override = _material(Color("1c8f5e"),0.4)
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
	return {"root":root,"body":body,"front":front,"back":back,"matched":matched,
		"button":button,"tween":null,"pop":null,"was_matched":false,"face":false,"motif":"",
		"size":Vector2.ZERO,"target":Rect2()}


func _clear_cards() -> void:
	for card in _cards:
		if is_instance_valid(card.tween): card.tween.kill()
		if is_instance_valid(card.pop): card.pop.kill()
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
	var matched: bool = public_card.matched
	card.matched.visible = matched
	var body: StandardMaterial3D = card.body.material_override
	body.albedo_color = (Color("ffd76a") if matched else Color("eec35a")).srgb_to_linear()
	if matched and not bool(card.was_matched) and not immediate and not bool(_state.reduceMotion):
		_celebrate(index, 0.46 if bool(card.face) != showing else 0.0)
	elif not is_instance_valid(card.pop):
		body.emission_energy_multiplier = 0.35 if matched else 0.0
		card.root.scale = Vector3.ONE
	card.was_matched = matched
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
		# The card lifts off the felt while it turns and settles back flat.
		tween.parallel().tween_method(_lift.bind(card.root),0.0,1.0,0.46)
		tween.finished.connect(_flip_finished.bind(index,showing,_round))
	if is_instance_valid(card.tween):
		if _state.paused: card.tween.pause()
		else: card.tween.play()


func _flip_finished(index: int,showing: bool,round_id: String) -> void:
	if round_id != _round or index >= _cards.size(): return
	var card := _cards[index]
	card.tween = null
	if not is_instance_valid(card.pop): card.root.scale = Vector3.ONE
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


func _lift(t: float,root: Node3D) -> void:
	if not is_instance_valid(root): return
	# Beim Umdrehen hebt die Karte vom Filz ab und setzt wieder auf.
	var arc := sin(t*PI)
	root.scale = Vector3.ONE*(1.0+0.06*arc)
	root.position.z = CARD_Z+arc*maxf(0.35,root.get_meta("height",0.6)*0.55)


func _celebrate(index: int,delay: float) -> void:
	var card := _cards[index]
	if is_instance_valid(card.pop): card.pop.kill()
	var round_id := _round
	var body: StandardMaterial3D = card.body.material_override
	var pop := create_tween()
	card.pop = pop
	if delay > 0.0: pop.tween_interval(delay)
	pop.tween_callback(_burst.bind(index,round_id))
	pop.tween_method(_pop_scale.bind(card.root),0.0,1.0,0.42)
	pop.parallel().tween_property(body,"emission_energy_multiplier",1.4,0.16)
	pop.tween_property(body,"emission_energy_multiplier",0.35,0.5)
	pop.finished.connect(func():
		if index < _cards.size() and round_id == _round:
			_cards[index].pop = null
			_cards[index].root.scale = Vector3.ONE)
	if _state.paused: pop.pause()


func _pop_scale(t: float,root: Node3D) -> void:
	if is_instance_valid(root): root.scale = Vector3.ONE*(1.0+0.16*sin(t*PI)*(1.0-t*0.35))


func _burst(index: int,round_id: String) -> void:
	if round_id != _round or index >= _cards.size() or _sparkles.is_empty(): return
	var emitter := _sparkles[_next_sparkle % _sparkles.size()]
	_next_sparkle += 1
	emitter.global_position = _cards[index].root.global_position+Vector3(0,0.08,0)
	emitter.restart()


func _update_shadows() -> void:
	if not is_instance_valid(_shadows): return
	var multimesh := _shadows.multimesh
	if multimesh.instance_count != _cards.size(): multimesh.instance_count = _cards.size()
	for index in range(_cards.size()):
		var card := _cards[index]
		var root: Node3D = card.root
		if not root.visible:
			multimesh.set_instance_transform(index,Transform3D(Basis().scaled(Vector3(0.001,0.001,1)),Vector3(0,0,-0.4)))
			continue
		var lift := clampf((root.position.z-CARD_Z)/maxf(0.01,card.size.y),0.0,1.0)
		var spread := 1.08+lift*0.5
		var size: Vector2 = card.size*spread
		# Die Lampe steht hinten oben: der Schatten fällt leicht nach vorn.
		var offset := Vector2(0.0,-0.04-lift*0.25*card.size.y)
		multimesh.set_instance_transform(index,Transform3D(Basis().scaled(Vector3(size.x,size.y,1)),
			Vector3(root.position.x+offset.x,root.position.y+offset.y,0.004)))
		multimesh.set_instance_color(index,Color(1,1,1,clampf(0.55-lift*0.6,0.15,0.55)))


func _build_room() -> void:
	_budget = LumoQuality.budget()
	var tier := KIT.tier()
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("120d1c")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("8a7fc0")
	environment.ambient_light_energy = 0.5
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.1
	environment.glow_enabled = tier != "low"
	environment.glow_intensity = 0.5
	environment.glow_hdr_threshold = 1.0
	environment.adjustment_enabled = true
	environment.adjustment_saturation = 1.08
	if tier == "high" and RenderingServer.get_current_rendering_method() == "forward_plus":
		environment.ssao_enabled = true
		environment.ssao_radius = 0.5
	world.environment = environment
	add_child(world)
	room_root = Node3D.new()
	room_root.name = "Room"
	add_child(room_root)
	# Warmes Lampenlicht von hinten oben über den Tisch, dazu kühles Fensterlicht.
	_room_light = SpotLight3D.new()
	_room_light.name = "LampLight"
	_room_light.position = Vector3(0.0,2.3,-1.1)
	_room_light.light_color = Color("ffd9a0")
	_room_light.light_energy = 3.0
	_room_light.spot_range = 6.0
	_room_light.spot_angle = 52.0
	_room_light.spot_angle_attenuation = 1.1
	_room_light.shadow_enabled = bool(_budget.get("shadows",false))
	_room_light.shadow_blur = 1.6
	_room_light.shadow_normal_bias = 1.2
	room_root.add_child(_room_light)
	_room_light.look_at(Vector3(0,0,0.2))
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-34,-150,0)
	_sun.light_energy = 0.45
	_sun.light_color = Color("9cbcff")
	_sun.shadow_enabled = false
	room_root.add_child(_sun)
	_fill = DirectionalLight3D.new()
	_fill.rotation_degrees = Vector3(-30,10,0)
	_fill.light_energy = 0.42
	_fill.light_color = Color("ffd0b0")
	room_root.add_child(_fill)
	_build_room_set(tier)
	# Das Spielbrett: Brett-Raum XY mit Kartenseite +Z, auf die waagrechte
	# Tischplatte gedreht. Karten, Filz und Kanten bleiben im Brett-Raum.
	_board = Node3D.new()
	_board.name = "Board"
	_board.rotation.x = -PI*0.5
	add_child(_board)
	# The wooden rim and felt mat follow the actual card grid in _layout.
	_rim = MeshInstance3D.new()
	_rim.name = "WoodenRim"
	_rim.material_override = KIT.material("oak")
	_board.add_child(_rim)
	_felt_material = LOOK.material(LOOK.FELT)
	_mat = MeshInstance3D.new()
	_mat.name = "FeltMat"
	_mat.material_override = _felt_material
	_board.add_child(_mat)
	for corner in range(4):
		var leg := MeshInstance3D.new()
		leg.name = "TableLeg%d" % corner
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.045
		mesh.bottom_radius = 0.032
		mesh.height = TABLE_HEIGHT-0.07
		mesh.radial_segments = 12
		leg.mesh = mesh
		leg.material_override = KIT.material("walnut")
		room_root.add_child(leg)
		_legs.append(leg)
	_back_material = LOOK.material(LOOK.CARD_BACK)
	# All contact shadows are a single MultiMesh draw.
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	multimesh.mesh = quad
	_shadows = MultiMeshInstance3D.new()
	_shadows.name = "CardShadows"
	_shadows.multimesh = multimesh
	_shadows.material_override = LOOK.material(LOOK.SHADOW)
	_shadows.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_board.add_child(_shadows)
	var sparkles := int(_budget.get("sparkles",0))
	if sparkles > 0:
		for i in range(2):
			var emitter := LOOK.sparkle_emitter(mini(sparkles,40))
			emitter.direction = Vector3(0,1,0.3)
			add_child(emitter)
			_sparkles.append(emitter)
	# Lumo sitzt als Mitspieler am Tisch: das echte Modell auf seinem Platz.
	lumo_seat = SEAT.new()
	lumo_seat.name = "LumoSeat"
	add_child(lumo_seat)
	lumo_seat.setup("lumo",Transform3D.IDENTITY,0)
	fox = lumo_seat.model
	_chair = KIT.prop("chair")
	if _chair != null:
		room_root.add_child(_chair)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = CAMERA_FOV
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.near = 0.05
	camera.far = 40.0
	camera.current = true
	add_child(camera)


## Spielzimmer rund um den Tisch: Dielen, Teppich, Bretterwand mit Fenster,
## Regal, Wanduhr, Pflanze. Alles liegt hinter bzw. unter dem Brett.
func _build_room_set(tier: String) -> void:
	var floor_y := -TABLE_HEIGHT
	var ground := MeshInstance3D.new()
	ground.name = "Floor"
	var plane := PlaneMesh.new()
	plane.size = Vector2(14,14)
	ground.mesh = plane
	var floor_material: StandardMaterial3D = (KIT.material("floor") as StandardMaterial3D).duplicate()
	floor_material.uv1_scale = Vector3(5,5,1)
	ground.material_override = floor_material
	ground.position.y = floor_y
	room_root.add_child(ground)
	var rug := MeshInstance3D.new()
	rug.name = "Rug"
	var rug_quad := QuadMesh.new()
	rug_quad.size = Vector2(3.6,3.6)
	rug_quad.orientation = PlaneMesh.FACE_Y
	rug.mesh = rug_quad
	rug.material_override = KIT.material("rug")
	rug.position = Vector3(0,floor_y+0.005,0)
	rug.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	room_root.add_child(rug)
	var wall := MeshInstance3D.new()
	wall.name = "BackWall"
	var wall_box := BoxMesh.new()
	wall_box.size = Vector3(12,4.2,0.16)
	wall.mesh = wall_box
	wall.material_override = KIT.material("wall")
	wall.position = Vector3(0,floor_y+2.1,-2.6)
	room_root.add_child(wall)
	for entry: Array in [["shelf",Vector3(2.0,floor_y,-2.33),0.0],["window",Vector3(-1.35,floor_y+0.3,-2.5),0.0],
			["clock",Vector3(0.55,floor_y+2.55,-2.47),0.0],["plant",Vector3(-2.7,floor_y,-1.9),0.0],
			["scoreboard",Vector3(3.4,floor_y+1.2,-2.48),0.0]]:
		if tier == "low" and entry[0] in ["plant","scoreboard"]: continue
		var node := KIT.prop(str(entry[0]))
		if node == null: continue
		node.position = entry[1]
		node.rotation.y = float(entry[2])
		room_root.add_child(node)
	var snacks := KIT.prop("snacks")
	if snacks != null:
		snacks.name = "Snacks"
		room_root.add_child(snacks)


func _fit_table(grid_rect: Rect2,pixel_factor: Vector2) -> void:
	var size := grid_rect.size/100.0
	var margin := TABLE_MARGIN*_table_scale
	var mat_size := size+Vector2.ONE*margin*2.0
	# Breite Holzkante: Platz für Kakao und Kekse an den hinteren Ecken.
	var rim := mat_size+Vector2.ONE*(TABLE_RIM*_table_scale*2.0+0.6)
	# Echte Tischgröße: die längste Seite misst TABLE_SPAN Meter.
	var scale := TABLE_SPAN/maxf(rim.x,rim.y)
	var slab := 0.07/scale
	_board.scale = Vector3.ONE*scale
	_mat.position = Vector3(0,0,-0.03)
	_rim.position = Vector3(0,0,0.012-slab*0.5)
	if not mat_size.is_equal_approx(_mat_size):
		_mat_size = mat_size
		_mat.mesh = _rounded_mesh(mat_size.x,mat_size.y,0.06)
		_rim.mesh = _rounded_mesh(rim.x,rim.y,slab)
		_felt_material.set_shader_parameter("extent",mat_size*0.5)
	var half := rim*0.5*scale
	for corner in range(4):
		var x := (half.x-0.12)*(1 if corner in [0,3] else -1)
		var z := (half.y-0.12)*(1 if corner in [0,1] else -1)
		_legs[corner].position = Vector3(x,-0.07-(TABLE_HEIGHT-0.07)*0.5,z)
	_place_props(half)
	_frame_camera(size,pixel_factor)


## Querformat: Lumo sitzt rechts neben dem Tisch; Hochformat: hinter dem Tisch.
func _lumo_beside() -> bool:
	return _safe_rect.size.x > _safe_rect.size.y


## Kamera so stellen, dass das projizierte Kartenraster in die Brettfläche passt.
func _frame_camera(grid_size: Vector2,pixel_factor: Vector2) -> void:
	var elevation := deg_to_rad(CAMERA_ELEVATION)
	var back := Vector3(0,sin(elevation),cos(elevation))
	camera.global_basis = Basis.looking_at(-back,Vector3.UP)
	var corners: Array[Vector3] = []
	for corner in [Vector2(-0.5,-0.5),Vector2(0.5,-0.5),Vector2(0.5,0.5),Vector2(-0.5,0.5)]:
		corners.append(_board.to_global(Vector3(corner.x*grid_size.x,corner.y*grid_size.y,CARD_Z)))
	var target := _board_rect
	var pan := Vector2.ZERO
	var distance := 4.0
	for iteration in range(3):
		var near := 0.5
		var far := 60.0
		for step in range(24):
			distance = (near+far)*0.5
			var box := _projected(corners,back,distance,pan,pixel_factor)
			if box.size.x <= target.size.x and box.size.y <= target.size.y: far = distance
			else: near = distance
		distance = far
		var fitted := _projected(corners,back,distance,pan,pixel_factor)
		var per_px := 2.0*distance*tan(deg_to_rad(CAMERA_FOV)*0.5)/maxf(1.0,get_viewport().get_visible_rect().size.y/pixel_factor.y)
		var delta := target.get_center()-fitted.get_center()
		pan += Vector2(-delta.x,delta.y)*per_px
	_projected(corners,back,distance,pan,pixel_factor)


func _projected(corners: Array[Vector3],back: Vector3,distance: float,pan: Vector2,pixel_factor: Vector2) -> Rect2:
	camera.global_position = back*distance+camera.global_basis.x*pan.x+camera.global_basis.y*pan.y
	var box := Rect2(camera.unproject_position(corners[0])/pixel_factor,Vector2.ZERO)
	for point in corners: box = box.expand(camera.unproject_position(point)/pixel_factor)
	return box


## Stuhl, Lumo, Kakao und Kekse wandern mit der Tischgröße mit.
func _place_props(half: Vector2) -> void:
	var side := _lumo_beside()
	var seat: Transform3D
	if side:
		# Breites Querformat: Lumo sitzt rechts am Tisch, Blick zur Mitte.
		# Vorn rechts am Tisch: so steht sein Kopf tief genug im Bild und frei.
		var at := Vector3(half.x+0.24,-TABLE_HEIGHT,half.y*0.3)
		# Schräg zum Tisch und zum Kind gedreht: man sieht sein Gesicht.
		seat = Transform3D(Basis.IDENTITY,at).looking_at(Vector3(0,-TABLE_HEIGHT,half.y*1.6),Vector3.UP)
	else:
		# Sonst sitzt er hinten am Tisch und schaut zum Kind.
		var at := Vector3(0.35,-TABLE_HEIGHT,-half.y-0.14)
		seat = Transform3D(Basis.IDENTITY,at).looking_at(Vector3(0.35,-TABLE_HEIGHT,2.0),Vector3.UP)
	lumo_seat.transform = seat
	if is_instance_valid(_chair):
		_chair.global_transform = seat.translated_local(Vector3(0,0,0.08))
	var snacks := room_root.get_node_or_null("Snacks")
	if snacks != null:
		# Nur an den hinteren Ecken: dort verdeckt nichts eine Karte.
		for child in snacks.get_children():
			if child is Node3D:
				match str(child.name):
					"Mug": child.position = Vector3(half.x-0.07,0.0,-half.y+0.07)
					"CookiePlate": child.position = Vector3(-half.x+0.1,0.0,-half.y+0.09)
					_: child.visible = false


func _panel(color: Color,radius: int=18,border: Color=Color("f2c25a"),border_width: int=2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(border_width)
	style.shadow_color = Color(0,0,0,0.35)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0,3)
	style.anti_aliasing = true
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


## Chunky kid button: bright face, darker bottom edge that sinks when pressed.
func _button_style(face: Color,edge: Color,pressed: bool=false) -> StyleBoxFlat:
	var style := _panel(face,20,edge,0)
	style.border_width_bottom = 2 if pressed else 6
	style.border_width_top = 4 if pressed else 0
	style.border_color = edge
	style.shadow_size = 2 if pressed else 7
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


func _button(caption: String,callback: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(64,60)
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
	_theme.default_font_size = 19
	for colour in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
		_theme.set_color(colour,"Button",Color("fffaf0"))
	_theme.set_color("font_disabled_color","Button",Color(1,1,1,0.45))
	_theme.set_color("font_outline_color","Button",Color("0b3a46"))
	_theme.set_constant("outline_size","Button",4)
	_theme.set_font_size("font_size","Button",21)
	_theme.set_color("font_color","Label",Color("fff7e3"))
	_theme.set_color("font_outline_color","Label",Color("08202c"))
	_theme.set_constant("outline_size","Label",3)
	_theme.set_stylebox("normal","Button",_button_style(Color("1fa3b5"),Color("0d6070")))
	_theme.set_stylebox("hover","Button",_button_style(Color("33b8c9"),Color("0d6070")))
	_theme.set_stylebox("focus","Button",StyleBoxEmpty.new())
	_theme.set_stylebox("pressed","Button",_button_style(Color("168999"),Color("0a4c59"),true))
	_theme.set_stylebox("disabled","Button",_button_style(Color("3b5660"),Color("27393f")))
	ui.theme = _theme
	_selected_style = _button_style(Color("ffd25e"),Color("b9822a"))
	safe = Control.new()
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(safe)
	header = PanelContainer.new()
	header.add_theme_stylebox_override("panel",_panel(Color("0c2236eb")))
	safe.add_child(header)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",6)
	header.add_child(row)
	back_button = _button("‹ Zurück",_send.bind("exit"))
	row.add_child(back_button)
	title = _label("Lumo Memory",25)
	title.add_theme_color_override("font_color",Color("ffd76a"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	pause_button = _button("Pause",_send.bind("pause"))
	pause_button.add_theme_stylebox_override("normal",_button_style(Color("f39a2b"),Color("a85a12")))
	pause_button.add_theme_stylebox_override("hover",_button_style(Color("ffad45"),Color("a85a12")))
	pause_button.add_theme_stylebox_override("pressed",_button_style(Color("d8831c"),Color("8a4a0e"),true))
	row.add_child(pause_button)
	# Scoreboard: whose turn it is, the real scores and pair progress.
	scores = _label("Du 0  ·  Lumo 0",17)
	scores.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scores.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	turn_chip = _label("Du bist dran",16)
	turn_chip.custom_minimum_size = Vector2(132,0)
	progress = ProgressBar.new()
	progress.name = "PairProgress"
	progress.show_percentage = false
	progress.custom_minimum_size = Vector2(96,12)
	progress.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var track := _panel(Color("0a1c2b"),6,Color("f2c25a"),1)
	track.shadow_size = 0
	track.set_content_margin_all(0)
	var fill := _panel(Color("ffc93c"),6,Color("fff1b0"),0)
	fill.shadow_size = 0
	fill.set_content_margin_all(0)
	progress.add_theme_stylebox_override("background",track)
	progress.add_theme_stylebox_override("fill",fill)
	var board := HBoxContainer.new()
	board.name = "Scoreboard"
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_theme_constant_override("separation",10)
	board.add_child(turn_chip)
	board.add_child(scores)
	board.add_child(progress)
	_scoreboard = board
	safe.add_child(board)
	footer = PanelContainer.new()
	footer.add_theme_stylebox_override("panel",_panel(Color("0c2236eb")))
	safe.add_child(footer)
	var lower := VBoxContainer.new()
	footer.add_child(lower)
	status = _label("Deine Memory-Runde wird geladen …",19)
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
	overlay.add_theme_stylebox_override("panel",_panel(Color("0c2236f5"),24,Color("f2c25a"),3))
	safe.add_child(overlay)
	menu_scroll = ScrollContainer.new()
	menu_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu_scroll.get_v_scroll_bar().value_changed.connect(func(_v): _invalidate())
	overlay.add_child(menu_scroll)
	var menu := VBoxContainer.new()
	menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu.add_theme_constant_override("separation",8)
	menu_scroll.add_child(menu)
	detail = _label("",22)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu.add_child(detail)
	resume_button = _button("Fortsetzen",_resume)
	menu.add_child(resume_button)
	restart_button = _button("Neue Runde",_send.bind("restart"))
	menu.add_child(restart_button)
	menu.add_child(_label("Brettgröße",19))
	for i in range(LEVELS.size()):
		var button := _button("%s · %d Karten" % [LEVELS[i].capitalize(),COUNTS[i]],_send.bind("difficulty",{"difficulty":LEVELS[i]}))
		menu.add_child(button)
		level_buttons.append(button)
	menu.add_child(_label("Kartenmotive",19))
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
			# Schrägsicht: hintere Reihen wirken kleiner, daher Reserve.
			if cw < 50.0*PERSPECTIVE_RESERVE: continue
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
	# Short landscape phones get slimmer bars so the board keeps its room.
	var compact := safe.size.y < 460.0
	var chunky := 54.0 if compact else 60.0
	for button in [back_button,pause_button,previous_button,next_button]:
		button.custom_minimum_size.y = chunky
	var header_height := 66.0 if compact else 76.0
	header.position = Vector2(8,5)
	header.size = Vector2(safe.size.x-16,header_height)
	_scoreboard.position = Vector2(18,header_height+8)
	_scoreboard.size = Vector2(safe.size.x-36,26 if compact else 30)
	var board_top := _scoreboard.position.y+_scoreboard.size.y+(6.0 if compact else 10.0)
	var narrow := safe.size.x < 560.0
	title.text = "Memory" if narrow else "Lumo Memory"
	progress.custom_minimum_size.x = 44.0 if narrow else 120.0
	turn_chip.custom_minimum_size.x = 0.0 if narrow else 132.0
	scores.add_theme_font_size_override("font_size",15 if narrow else 17)
	var footer_height := 92.0 if compact else 104.0
	footer.position = Vector2(8,safe.size.y-footer_height-5)
	footer.size = Vector2(safe.size.x-16,footer_height)
	# The grid leaves room for the felt margin and rim inside the board area.
	_table_scale = 0.5 if compact else 1.0
	var inset := (TABLE_MARGIN+TABLE_RIM)*_table_scale*100.0+2.0
	_board_rect = Rect2(safe.position+Vector2(14+inset,board_top+inset),
		Vector2(maxf(50,safe.size.x-28-inset*2.0),maxf(66,safe.size.y-board_top-footer_height-14-inset*2.0)))
	var fox_room := _lumo_beside()
	# Querformat: rechts bleibt Platz für Lumo auf seinem Stuhl neben dem Tisch.
	if fox_room: _board_rect.size.x -= clampf(safe.size.x*0.26,150.0,280.0)
	elif _board_rect.size.y > _board_rect.size.x*1.25:
		# Hochformat: oben bleibt Platz für Lumo hinter dem Tisch – so viel, dass sein Kopf
		# unter der Kopfzeile frei steht, solange das Brett hochformatig bleibt.
		var lumo_room := clampf(_board_rect.size.y-_board_rect.size.x*1.25,110.0,210.0)
		_board_rect.position.y += lumo_room
		_board_rect.size.y -= lumo_room
	overlay.position = Vector2(8,header_height+10)
	overlay.size = Vector2(safe.size.x-16,maxf(80,safe.size.y-header_height-18))
	camera.size = logical.y/100.0
	var count: int = int(_state.get("count",8))
	var grid := _choose_grid(count,_board_rect.size.x,_board_rect.size.y)
	var grid_center := Vector2.ZERO
	_page_size = int(grid.page_size)
	_columns = int(grid.cols)
	_rows = int(grid.rows)
	_page = clampi(_page,0,maxi(0,ceili(float(count)/_page_size)-1))
	var grid_size := Vector2(_columns*grid.width+8*(_columns-1),_rows*grid.height+8*(_rows-1))
	var start := _board_rect.get_center()-grid_size/2
	grid_center = _board_rect.get_center()
	var pixel_factor := get_viewport().get_visible_rect().size/logical
	_fit_table(Rect2(start,grid_size),pixel_factor)
	_back_material.set_shader_parameter("aspect",CARD_ASPECT)
	_back_material.set_shader_parameter("shine",0.0 if bool(_state.get("reduceMotion",false)) else 1.0)
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
		var centre := target.get_center()-grid_center
		card.root.position = Vector3(centre.x/100.0,-centre.y/100.0,CARD_Z)
		card.root.set_meta("height",card.size.y)
		card.body.mesh = _rounded_mesh(card.size.x,card.size.y,0.11)
		# The motif sits inset so the gold frame stays visible all around it.
		card.front.mesh.size = card.size*0.86
		card.back.mesh.size = card.size*0.92
		card.matched.position.y = -card.size.y*0.35
		card.matched.scale = Vector3.ONE*minf(card.size.x/0.95,1.4)
		# Bounds come from the actual projected face. No fixed device tap point.
		var quad := _card_quad(card)
		var rect := Rect2(quad[0],Vector2.ZERO)
		for point in quad: rect = rect.expand(point)
		card.button.position = rect.position-safe.position
		card.button.size = rect.size
	_update_shadows()
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
	var kid_turn: bool = str(_state.turn) == "kind"
	turn_chip.text = "Du bist dran" if kid_turn else "Lumo ist dran"
	var chip := _panel(Color("f39a2b") if kid_turn else Color("2a8fd6"),14,Color("fff1c9"),2)
	chip.shadow_size = 3
	chip.content_margin_top = 2
	chip.content_margin_bottom = 2
	turn_chip.add_theme_stylebox_override("normal",chip)
	progress.max_value = maxi(1,int(_state.count)/2)
	progress.value = int(_state.kindPairs)+int(_state.lumoPairs)
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
		_mark_selected(level_buttons[i],_state.difficulty == LEVELS[i])
	for i in range(pack_buttons.size()):
		pack_buttons[i].disabled = waiting or _state.pack == PACKS[i] or (complete and not bool(_state.rewarded))
		_mark_selected(pack_buttons[i],_state.pack == PACKS[i])
	for i in range(_cards.size()):
		_cards[i].button.disabled = waiting or paused or complete or not bool(_state.canFlip) or _animating() or bool(_state.cards[i].faceUp) or bool(_state.cards[i].matched)
	lumo_seat.set_reduced_motion(bool(_state.reduceMotion))
	lumo_seat.set_suspended(paused)


## The current board size and motif pack read as a golden, chosen tile.
func _mark_selected(button: Button,selected: bool) -> void:
	if selected:
		button.add_theme_stylebox_override("disabled",_selected_style)
		button.add_theme_color_override("font_disabled_color",Color("5a3208"))
	else:
		button.remove_theme_stylebox_override("disabled")
		button.remove_theme_color_override("font_disabled_color")


func _invalidate() -> void:
	DirAccess.remove_absolute(OBSERVATION)
	_dirty = true
	_layout_frames = 2


func _card_quad(card: Dictionary) -> Array[Vector2]:
	var result: Array[Vector2] = []
	# Axis-aligned rest geometry, independent of its animated flip transform.
	for corner in [Vector2(-0.5,0.5),Vector2(0.5,0.5),Vector2(0.5,-0.5),Vector2(-0.5,-0.5)]:
		var local: Vector3 = Vector3(card.root.position.x,card.root.position.y,CARD_Z)+Vector3(corner.x*card.size.x,corner.y*card.size.y,0.057)
		result.append(camera.unproject_position(_board.to_global(local)))
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
		"camera":{"projection":"perspective","fov":camera.fov,"keep_aspect":int(camera.keep_aspect),
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
