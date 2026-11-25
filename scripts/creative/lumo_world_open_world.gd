extends Node3D
## Open-world layer of Lumo World: additional places, paths, computer-controlled
## figures with conversations, mission chains and the figure-card album.
## All content is data in open_world_content.json; this node only builds,
## presents and forwards actions to the mission model. Figures use the original
## production models of the shared rival roster. Walk-in halls, plazas and path
## strips are self-built prototype geometry (meta "prototype_material").

const QUESTS = preload("res://scripts/creative/lumo_world_quests.gd")
const DIALOG = preload("res://scripts/creative/lumo_world_dialog.gd")
const ROUTINES = preload("res://scripts/creative/lumo_world_routines.gd")
const ROSTER = preload("res://scripts/games/lumo_opponent_roster.gd")
const VILLAGE = preload("res://scripts/creative/build_village_art.gd")
const KIT = preload("res://scripts/creative/creative_kit.gd")
const ADVENTURE = preload("res://scripts/creative/adventure_kit.gd")
const ROLE_PREFIX := "Computerfigur"
const FIGURE_HEIGHT := 2.05
const WALL_HEIGHT := 3.0
const WALL_THICKNESS := 0.35
const DOOR_WIDTH := 3.6
const OBSERVE_INTERVAL := 0.2
const ANIMATION_RANGE := 70.0
const QUEST_COLOR := Color("c9a7ff")

var model = QUESTS.new()
var routines = ROUTINES.new()
var figure_homes: Dictionary = {}
var figure_walk_clips: Dictionary = {}
var figure_gesture_slots: Dictionary = {}
var figure_indices: Dictionary = {}
var routine_phase := -1
var walking_shape := CapsuleShape3D.new()
var world: Node3D
var kit = KIT.new()
var save_valid := true
var figures: Dictionary = {}
var figure_players: Dictionary = {}
var mission_signs: Dictionary = {}
var quest_marker: MeshInstance3D
var runner = null
var dialog_mission := ""
var dialog_step := ""
var dialog_figure := ""
var observe_clock := 0.0
var animation_time := 0.0


## Ground rectangles that the authored tree scatter keeps free.
static func clear_areas() -> Array[Rect2]:
	var areas: Array[Rect2] = []
	var raw = JSON.parse_string(FileAccess.get_file_as_string(QUESTS.CONTENT_PATH))
	if not raw is Dictionary:
		return areas
	for place in raw.get("places", []):
		if place is Dictionary and place.get("at") is Array and place.get("size") is Array:
			var size := Vector2(float(place.size[0]), float(place.size[1])) + Vector2(6, 6)
			areas.append(Rect2(Vector2(float(place.at[0]), float(place.at[2])) - size * 0.5, size))
	for path in raw.get("paths", []):
		if not path is Dictionary or not path.get("points") is Array:
			continue
		var points: Array = path.points
		for index in range(points.size() - 1):
			var first := Vector2(float(points[index][0]), float(points[index][1]))
			var last := Vector2(float(points[index + 1][0]), float(points[index + 1][1]))
			areas.append(Rect2(first, Vector2.ZERO).expand(last).grow(float(path.get("width", 4.0)) * 0.5 + 2.0))
	return areas


func setup(owner_world: Node3D, saved: Variant = {}) -> bool:
	world = owner_world
	name = "OpenWorld"
	if not model.ready():
		push_error("[LumoOpenWorld] content invalid: " + ", ".join(model.errors))
		save_valid = false
		return false
	save_valid = model.restore(saved)
	_build_paths()
	_build_places()
	walking_shape.radius = 0.32
	walking_shape.height = 1.5
	_build_figures()
	_update_routine_signs()
	_build_marker()
	refresh()
	return save_valid


func unlocked() -> bool:
	return save_valid and model.ready() and is_instance_valid(world) and not world.save_blocked


func available(at: Vector3) -> bool:
	return unlocked() and not world.driving and not model.figure_at(at).is_empty()


func to_data() -> Dictionary:
	return model.to_data()


func hud_line() -> String:
	return model.hud_line() if unlocked() else ""


## World target of the followed mission step, for wisps and map.
func tracked_route() -> Dictionary:
	return model.tracked_target() if unlocked() else {}


# --- Construction ---------------------------------------------------------

func _build_paths() -> void:
	var root := Node3D.new()
	root.name = "OpenWorldPaths"
	root.set_meta("prototype_material", true)
	add_child(root)
	for path in model.content.paths:
		var points: Array = path.points
		for index in range(points.size() - 1):
			var first := Vector3(float(points[index][0]), 0.0, float(points[index][1]))
			var last := Vector3(float(points[index + 1][0]), 0.0, float(points[index + 1][1]))
			var span := last - first
			var strip := kit.box(root, (first + last) * 0.5 + Vector3.UP * 0.03, Vector3(float(path.width), 0.04, span.length() + float(path.width)), Color("ddc8a0"))
			strip.name = "Path_%s_%d" % [str(path.id), index]
			strip.rotation.y = atan2(span.x, span.z)
			strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_places() -> void:
	for place in model.content.places:
		var root := Node3D.new()
		root.name = "Place_" + str(place.id)
		root.position = place.position
		root.set_meta("prototype_material", str(place.material) == "prototype")
		add_child(root)
		var size := Vector2(float(place.size[0]), float(place.size[1]))
		var accent := Color(str(place.get("accent", "ffffff")))
		match str(place.kind):
			"walk_in":
				_walk_in(root, size, accent)
			"plaza":
				var paving := kit.box(root, Vector3(0, 0.035, 0), Vector3(size.x, 0.05, size.y), Color("d9c9a6"))
				paving.name = "Paving"
				paving.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		match str(place.get("props", "none")):
			"library":
				_library(root, size)
			"card_tables":
				_card_tables(root)
			"kart_garage":
				_kart_garage(root, size, accent)
			"harbour":
				_harbour(root)
			"farm":
				_farm(root)
		if str(place.kind) != "landmark":
			var sign_at: Vector3 = place.position + Vector3(0, 4.3, -size.y * 0.5)
			var sign: Label3D = world.art._sign(self, str(place.title), sign_at, accent.lightened(0.25))
			sign.name = "PlaceSign_" + str(place.id)


func _static(root: Node3D, node_name: String) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	root.add_child(body)
	return body


func _solid(body: StaticBody3D, at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := kit.box(body, at, size, color)
	kit.collision(body, at, size)
	return mesh


func _walk_in(root: Node3D, size: Vector2, accent: Color) -> void:
	var floor_mesh := kit.box(root, Vector3(0, 0.04, 0), Vector3(size.x, 0.06, size.y), Color("c99e6e"))
	floor_mesh.name = "Floor"
	floor_mesh.material_override = ADVENTURE.material("wood")
	var walls := _static(root, "Walls")
	var wall_color := Color("f1e4c8")
	var half := size * 0.5
	var y := WALL_HEIGHT * 0.5
	_solid(walls, Vector3(0, y, half.y), Vector3(size.x, WALL_HEIGHT, WALL_THICKNESS), wall_color)
	for side in [-1.0, 1.0]:
		_solid(walls, Vector3(side * half.x, y, 0), Vector3(WALL_THICKNESS, WALL_HEIGHT, size.y), wall_color)
		# The front wall leaves a centred doorway towards the path (-z).
		var segment := (size.x - DOOR_WIDTH) * 0.5
		_solid(walls, Vector3(side * (DOOR_WIDTH * 0.5 + segment * 0.5), y, -half.y), Vector3(segment, WALL_HEIGHT, WALL_THICKNESS), wall_color)
	for edge in [Vector3(0, WALL_HEIGHT + 0.1, half.y), Vector3(0, WALL_HEIGHT + 0.1, -half.y)]:
		kit.box(root, edge, Vector3(size.x + 0.4, 0.22, WALL_THICKNESS + 0.2), accent)
	for side in [-1.0, 1.0]:
		kit.box(root, Vector3(side * half.x, WALL_HEIGHT + 0.1, 0), Vector3(WALL_THICKNESS + 0.2, 0.22, size.y + 0.4), accent)
	# Open roof beams keep the follow camera's view inside the hall.
	for x in range(-int(half.x) + 2, int(half.x) - 1, 3):
		kit.box(root, Vector3(x, WALL_HEIGHT + 0.25, 0), Vector3(0.22, 0.2, size.y), Color("9b6b45"))
	kit.box(root, Vector3(0, WALL_HEIGHT + 0.25, -half.y), Vector3(DOOR_WIDTH + 0.6, 0.35, 0.5), accent)


func _library(root: Node3D, size: Vector2) -> void:
	var furniture := _static(root, "LibraryFurniture")
	var wood := Color("8a5a3a")
	var book_colors := [Color("e46b5d"), Color("5d9ee4"), Color("f2c14e"), Color("6cc28a"), Color("b28be0")]
	for index in range(3):
		var x := -4.2 + index * 4.2
		_solid(furniture, Vector3(x, 1.1, size.y * 0.5 - 0.55), Vector3(3.0, 2.2, 0.6), wood)
		for shelf in range(3):
			for book in range(6):
				kit.box(root, Vector3(x - 1.2 + book * 0.48, 0.45 + shelf * 0.7, size.y * 0.5 - 0.9), Vector3(0.3, 0.5, 0.12), book_colors[(index + shelf + book) % book_colors.size()])
	_solid(furniture, Vector3(4.0, 0.42, 0.5), Vector3(2.4, 0.84, 1.4), wood)
	var rug := kit.cylinder(root, Vector3(-3.5, 0.08, -0.5), 1.8, 0.02, Color("e9a6c4"))
	rug.name = "ReadingRug"


func _card_tables(root: Node3D) -> void:
	var furniture := _static(root, "CardTables")
	for table in [Vector3(0, 0, 2.8), Vector3(-6.5, 0, 3.5)]:
		var top := kit.cylinder(furniture, table + Vector3(0, 0.82, 0), 1.15, 0.08, Color("2f7d5b"))
		top.name = "CardTableTop"
		kit.cylinder(furniture, table + Vector3(0, 0.4, 0), 0.18, 0.8, Color("6b4a33"))
		kit.collision(furniture, table + Vector3(0, 0.42, 0), Vector3(2.0, 0.84, 2.0))
		for card_index in range(4):
			var card := kit.box(root, table + Vector3(-0.6 + card_index * 0.4, 0.88, 0.1), Vector3(0.28, 0.01, 0.4), Color("fff6e0"))
			card.rotation.y = 0.2 * card_index


func _kart_garage(root: Node3D, size: Vector2, accent: Color) -> void:
	var frame := _static(root, "KartGarage")
	var half := size * 0.5
	for x in [-half.x + 0.5, half.x - 0.5]:
		_solid(frame, Vector3(x, 2.2, half.y - 0.5), Vector3(0.35, 4.4, 0.35), Color("4a5a6a"))
		_solid(frame, Vector3(x, 2.2, -half.y + 0.3), Vector3(0.35, 4.4, 0.35), Color("4a5a6a"))
	kit.box(root, Vector3(0, 4.5, half.y - 1.6), Vector3(size.x, 0.2, 3.0), accent)
	kit.box(root, Vector3(0, 4.5, -half.y + 0.3), Vector3(size.x, 0.6, 0.3), Color("1d2a36"))
	for index in range(8):
		kit.box(root, Vector3(-half.x + 1.2 + index * (size.x - 2.4) / 7.0, 4.5, -half.y + 0.12), Vector3(0.9, 0.5, 0.05), Color.WHITE if index % 2 == 0 else Color("1d2a36"))
	for stack in [Vector3(-half.x + 1.8, 0, half.y - 1.4), Vector3(half.x - 1.8, 0, half.y - 1.4)]:
		for tyre in range(3):
			kit.cylinder(frame, stack + Vector3(0, 0.22 + tyre * 0.42, 0), 0.55, 0.4, Color("23262b"))
		kit.collision(frame, stack + Vector3(0, 0.65, 0), Vector3(1.1, 1.3, 1.1))
	for index in range(6):
		kit.cylinder(root, Vector3(-half.x + 2.0 + index * 2.8, 0.3, half.y - 3.2), 0.18, 0.6, Color("ff8a3d"), 0.03)


func _model(root: Node3D, model_name: String, at: Vector3, width: float, yaw: float, solid: bool) -> void:
	if solid:
		var body: StaticBody3D = world.art._building(root, model_name, at, width, yaw)
		if body != null:
			body.name = "Original_" + model_name
		return
	var entry = VILLAGE.bundle(model_name)
	if entry.aabb.size.x <= 0.01:
		return
	var visual: Node3D = VILLAGE.instance(model_name, false)
	visual.name = "Original_" + model_name
	visual.position = at
	visual.rotation.y = yaw
	visual.scale = Vector3.ONE * (width / entry.aabb.size.x)
	root.add_child(visual)


func _harbour(root: Node3D) -> void:
	_model(root, "dock", Vector3(2, 0, -4.5), 9.0, 0.0, true)
	_model(root, "boat", Vector3(9, 0, -6.5), 4.0, 0.6, false)
	_model(root, "reeds", Vector3(-7, 0, -5), 3.0, 0.0, false)
	_model(root, "reeds", Vector3(-4.5, 0, -6), 2.5, 1.2, false)
	_model(root, "lantern", Vector3(-3, 0, 2.5), 0.9, 0.0, false)
	var crates := _static(root, "HarbourCrates")
	_solid(crates, Vector3(6.0, 0.45, 2.6), Vector3(0.9, 0.9, 0.9), Color("a0723f"))
	_solid(crates, Vector3(7.1, 0.35, 2.4), Vector3(0.7, 0.7, 0.7), Color("b88449"))


func _farm(root: Node3D) -> void:
	_model(root, "farm", Vector3(12, 0, -3), 9.0, PI, true)
	_model(root, "well", Vector3(-11.5, 0, -3), 2.2, 0.0, true)
	_model(root, "grain", Vector3(4, 0, -4.5), 6.0, 0.0, false)
	_model(root, "fence", Vector3(-1, 0, -4.8), 5.0, 0.0, false)
	_model(root, "cow", Vector3(20, 0, 1), 2.4, -0.8, false)
	_model(root, "sheep", Vector3(22.5, 0, -2.5), 1.4, 0.4, false)
	_model(root, "chicken", Vector3(-4, 0, -2), 0.6, 1.0, false)
	_model(root, "chicken", Vector3(-3, 0, -3.1), 0.6, -0.6, false)


func _build_figures() -> void:
	var level := 1 if PerformanceManager.get_profile_name() != "low" else 2
	for entry in model.content.figures:
		var id := str(entry.id)
		var path := ROSTER.racing_model_path(id, level)
		if path.is_empty() or not ResourceLoader.exists(path, "PackedScene"):
			push_warning("[LumoOpenWorld] Figur fehlt: " + id)
			continue
		var root := Node3D.new()
		figure_homes[id] = entry.position
		figure_indices[id] = figures.size()
		root.name = "Figure_" + id
		root.position = entry.position
		root.rotation.y = float(entry.get("yaw", 0.0))
		add_child(root)
		var model_node := (load(path) as PackedScene).instantiate() as Node3D
		model_node.name = "OriginalRosterModel"
		# Roster models face -Z; the root's +Z is turned towards Lumo.
		model_node.rotation.y = PI
		root.add_child(model_node)
		var bounds := AABB()
		for node in model_node.find_children("*", "MeshInstance3D", true, false):
			var mesh := node as MeshInstance3D
			mesh.visibility_range_end = 120.0
			var box: AABB = root.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
			bounds = box if bounds.size == Vector3.ZERO else bounds.merge(box)
		if bounds.size.y > 0.1:
			model_node.scale = Vector3.ONE * (FIGURE_HEIGHT / bounds.size.y)
			model_node.position.y = -bounds.position.y * model_node.scale.y
		for node in model_node.find_children("*", "AnimationPlayer", true, false):
			var animation_player := node as AnimationPlayer
			animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			figure_walk_clips[id] = ROUTINES.walk_clip(animation_player)
			figure_gesture_slots[id] = 0
			if animation_player.has_animation("idle"):
				animation_player.get_animation("idle").loop_mode = Animation.LOOP_LINEAR
				animation_player.play("idle")
				animation_player.seek(fmod(float(figures.size()) * 0.9, 2.0), true)
				if world.reduced_motion:
					animation_player.pause()
				figure_players[id] = animation_player
			break
		figures[id] = root
		var name_sign: Label3D = world.art._sign(self, str(entry.name), entry.position + Vector3.UP * 3.0, Color("fff1c8"))
		name_sign.name = "FigureName_" + id
		var role: Label3D = world.art._sign(self, ROLE_PREFIX + " · " + str(entry.role), entry.position + Vector3.UP * 2.58, Color("d8ecef"))
		role.name = "FigureRole_" + id
		role.font_size = 24
		var mission_sign: Label3D = world.art._sign(self, "★ Auftrag", entry.position + Vector3.UP * 3.45, Color("ffe48a"))
		mission_sign.name = "FigureMission_" + id
		mission_sign.font_size = 30
		mission_signs[id] = mission_sign


func _build_marker() -> void:
	quest_marker = MeshInstance3D.new()
	quest_marker.name = "OpenWorldQuestMarker"
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * 0.7
	quest_marker.mesh = mesh
	quest_marker.material_override = kit.material(QUEST_COLOR, true)
	quest_marker.rotation = Vector3(PI * 0.25, 0, PI * 0.25)
	quest_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(quest_marker)
	quest_marker.hide()


## Signs and markers follow the model after every change.
func refresh() -> void:
	for id in mission_signs:
		(mission_signs[id] as Label3D).visible = unlocked() and not model.steps_for_figure(str(id)).is_empty()
	var target := tracked_route()
	if is_instance_valid(quest_marker):
		quest_marker.visible = not target.is_empty()


# --- Per-frame -------------------------------------------------------------

func tick(at: Vector3, driving: bool, delta: float) -> void:
	if not unlocked() or world.paused:
		return
	if runner != null and not world.modal.visible:
		_clear_conversation()
	var step := ROUTINES.safe_delta(delta)
	if step <= 0.0:
		return
	routines.advance(step)
	animation_time += step
	_update_routine_signs()
	for id in figures:
		var root: Node3D = figures[id]
		var before := root.position
		var offset := at - before
		var distance := Vector2(offset.x, offset.z).length()
		var walking_clip := str(figure_walk_clips.get(id, ""))
		if distance < ANIMATION_RANGE:
			var candidate: Vector3 = routines.candidate(str(id), figure_homes[id], before,
				at, step, not walking_clip.is_empty() and figure_players.has(id), driving, world.reduced_motion)
			if not candidate.is_equal_approx(before):
				root.position = _safe_local_step(before, candidate)
			var movement := root.position - before
			if movement.length_squared() > 0.000001:
				root.rotation.y = lerp_angle(root.rotation.y, atan2(movement.x, movement.z), 1.0 - exp(-6.0 * step))
				_play_figure_clip(str(id), walking_clip, true)
			else:
				if distance < 9.0 and distance > 0.3:
					root.rotation.y = lerp_angle(root.rotation.y, atan2(offset.x, offset.z), 1.0 - exp(-3.0 * step))
				if figure_players.has(id):
					var player: AnimationPlayer = figure_players[id]
					if not walking_clip.is_empty() and str(player.current_animation) == walking_clip:
						_play_figure_clip(str(id), "idle", true)
				var gesture_slot := int(animation_time / 14.0 + float(figure_indices.get(id, 0)) * 0.13)
				if gesture_slot != int(figure_gesture_slots.get(id, 0)):
					figure_gesture_slots[id] = gesture_slot
					_play_figure_clip(str(id), str(routines.activity(str(id)).get("gesture", "idle")), false)
			if not root.position.is_equal_approx(before):
				_sync_figure_position(str(id))
			if figure_players.has(id) and not world.reduced_motion:
				(figure_players[id] as AnimationPlayer).advance(step)
	var target := tracked_route()
	if is_instance_valid(quest_marker) and not target.is_empty():
		var lift := 0.0 if world.reduced_motion else sin(animation_time * 2.2) * 0.15
		quest_marker.position = target.at + Vector3.UP * (4.1 + lift)
		if not world.reduced_motion:
			quest_marker.rotate_y(step * 0.9)
	observe_clock += step
	if observe_clock < OBSERVE_INTERVAL or world.paused:
		return
	observe_clock = 0.0
	var events: Array[Dictionary] = model.observe(at, driving)
	if events.is_empty():
		return
	var messages: Array[String] = []
	var gained: Array[String] = []
	for event in events:
		if str(event.type) == "discovered":
			messages.append("Neuer Ort entdeckt: " + str(model.place(str(event.place)).title) + ".")
		else:
			messages.append(_step_message(str(event.mission), bool(event.done)))
			for card_id in event.cards:
				gained.append(str(card_id))
	_commit(" ".join(messages))
	if not gained.is_empty():
		_show_cards(gained)


## Ordinary pause freezes every NPC. During an open NPC conversation only its
## authored speaking gesture advances; position and the simulated day stay still.
func _process(delta: float) -> void:
	if not is_instance_valid(world) or not world.paused or world.reduced_motion:
		return
	if not is_instance_valid(world.modal) or not world.modal.visible or not world.modal.has_meta("open_world_dialog"):
		return
	# A different dialog may replace the modal content before its old metadata
	# is cleared. Only the actual NPC choices may keep the speaking gesture alive.
	if not world.modal_box.has_node("DialogChoice_0"):
		return
	if figure_players.has(dialog_figure):
		(figure_players[dialog_figure] as AnimationPlayer).advance(ROUTINES.safe_delta(delta))


func _play_figure_clip(figure_id: String, clip: String, loop: bool) -> void:
	if world.reduced_motion or not figure_players.has(figure_id) or clip.is_empty():
		return
	var player: AnimationPlayer = figure_players[figure_id]
	if not player.has_animation(clip):
		return
	if loop and str(player.current_animation) == clip and player.is_playing():
		return
	player.clear_queue()
	player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	player.play(clip, 0.2)
	if not loop and player.has_animation("idle"):
		player.queue("idle")


func _update_routine_signs() -> void:
	if routine_phase == routines.phase_index():
		return
	routine_phase = routines.phase_index()
	for id in figures:
		var entry := model.figure(str(id))
		var activity: Dictionary = routines.activity(str(id))
		var role := get_node_or_null("FigureRole_" + str(id)) as Label3D
		if role != null and not activity.is_empty():
			role.text = "%s · %s\n%s: %s" % [ROLE_PREFIX, str(entry.role), str(activity.phase), str(activity.title)]


func _sync_figure_position(figure_id: String) -> void:
	var at: Vector3 = figures[figure_id].position
	# The shared entry is used by figure_at, mission targets and the map.
	var entry := model.figure(figure_id)
	entry["position"] = at
	for field in [["FigureName_", 3.0], ["FigureRole_", 2.58], ["FigureMission_", 3.45]]:
		var sign := get_node_or_null(str(field[0]) + figure_id) as Node3D
		if sign != null:
			sign.position = at + Vector3.UP * float(field[1])


## Never put a new physics body in a doorway. Walking is visual-only and is
## allowed only through checked free space on the same nearby ground surface.
func _safe_local_step(from: Vector3, to: Vector3) -> Vector3:
	if not from.is_finite() or not to.is_finite() or not is_inside_tree():
		return from
	var space := get_world_3d().direct_space_state
	var floor_query := PhysicsRayQueryParameters3D.create(
		to + Vector3.UP * 0.6, to + Vector3.DOWN * 0.6)
	var floor_hit := space.intersect_ray(floor_query)
	if floor_hit.is_empty():
		return from
	var normal: Vector3 = floor_hit.normal
	if normal.y < 0.75:
		return from
	var ground: Vector3 = floor_hit.position
	if absf(ground.y - from.y) > 0.25:
		return from
	var checked := Vector3(to.x, ground.y, to.z)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = walking_shape
	query.margin = 0.03
	query.transform = Transform3D(Basis.IDENTITY, from + Vector3.UP * 0.95)
	if not space.intersect_shape(query, 1).is_empty():
		return from
	query.motion = checked - from
	var fraction := space.cast_motion(query)
	if fraction.size() != 2 or fraction[0] < 0.999:
		return from
	query.transform = Transform3D(Basis.IDENTITY, checked + Vector3.UP * 0.95)
	query.motion = Vector3.ZERO
	return checked if space.intersect_shape(query, 1).is_empty() else from


func _step_message(mission_id: String, done: bool) -> String:
	var title := str(model.mission(mission_id).title)
	if done:
		return title + ": Mission geschafft!"
	return title + ": Gut gemacht! Weiter: " + str(model.current_step(mission_id).get("lead", ""))


func _commit(message: String) -> void:
	refresh()
	world._update_mission()
	world.status_label.text = message
	if not world._save():
		world.status_label.text = message + " Speichern ist noch nicht möglich. Bitte bleibe in der Welt; wir versuchen es erneut."


# --- Conversations -----------------------------------------------------------

func interact(at: Vector3) -> bool:
	if not available(at) or world.paused:
		return false
	dialog_figure = model.figure_at(at)
	var steps := model.steps_for_figure(dialog_figure)
	_play_figure_clip(dialog_figure, "greeting_wave", false)
	if steps.is_empty():
		dialog_mission = ""
		dialog_step = ""
		runner = DIALOG.new(smalltalk_tree(dialog_figure), int(world.grade), model.cards())
	else:
		dialog_mission = str(steps[0].mission)
		dialog_step = str(steps[0].step.id)
		runner = DIALOG.new(model.dialog(str(steps[0].step.dialog)), int(world.grade), model.cards())
	_render()
	return true


## Conversation for a figure without a pending mission step. It names the figure
## honestly as a computer figure and points to the mission that gives its card.
func smalltalk_tree(figure_id: String) -> Dictionary:
	var entry := model.figure(figure_id)
	var place_title := str(model.place(str(entry.get("place", ""))).get("title", "Lumo World"))
	var card_id := str(entry.get("card", ""))
	var card_text := "Meine Figurenkarte bekommst du in der Mission „%s“." % str(model.mission(model.card_source(card_id)).get("title", ""))
	if model.has_card(card_id):
		var card := model.card(card_id)
		card_text = "Meine Karte ist schon in deinem Album: %s. %s" % [str(card.trait), str(card.text)]
	var greeting := str(model.content.get("smalltalk", {}).get(figure_id, "Schön, dich zu sehen, Lumo!"))
	var activity: Dictionary = routines.activity(figure_id)
	var mission_id := model.card_source(card_id)
	var learning_text := str(activity.get("learning", ""))
	if not mission_id.is_empty():
		learning_text += "\nUnser Lernauftrag: " + str(model.mission(mission_id).get("title", "")) + "."
	learning_text += "\nDu bestimmst das Tempo. Wir können alles in Ruhe besprechen."
	return {"start": "hello", "nodes": {
		"hello": {"text": greeting, "choices": [
			{"label": "Wer bist du?", "next": "who"},
			{"label": "Zeig mir deine Figurenkarte", "next": "card"},
			{"label": "Dein Alltag & Lernen", "next": "routine"},
			{"label": "Tschüss!", "action": "close"}]},
		"who": {"text": "Ich bin %s, %s am Ort %s. Ich bin eine Computerfigur dieser Welt – keine echte Person aus dem Internet und kein Online-Mitspieler." % [str(entry.name), str(entry.role), place_title], "choices": [
			{"label": "Noch etwas fragen", "next": "hello"},
			{"label": "Tschüss!", "action": "close"}]},
		"card": {"text": card_text, "choices": [
			{"label": "Noch etwas fragen", "next": "hello"},
			{"label": "Tschüss!", "action": "close"}]},
		"routine": {"text": "%s · %s\n%s" % [str(activity.get("phase", "")), str(activity.get("title", "")), str(activity.get("detail", ""))], "choices": [
			{"label": "Was interessiert dich?", "next": "routine_interest"},
			{"label": "Wie sieht dein Tag aus?", "next": "routine_day"},
			{"label": "Was können wir gemeinsam lernen?", "next": "routine_learning"},
			{"label": "Noch etwas fragen", "next": "hello"}]},
		"routine_interest": {"text": str(activity.get("interest", greeting)), "choices": [
			{"label": "Was können wir gemeinsam lernen?", "next": "routine_learning"},
			{"label": "Zurück zum Alltag", "next": "routine"}]},
		"routine_day": {"text": routines.day_description(figure_id), "choices": [
			{"label": "Zurück zum Alltag", "next": "routine"}]},
		"routine_learning": {"text": learning_text, "choices": [
			{"label": "Zurück zum Alltag", "next": "routine"},
			{"label": "Weiter erkunden", "action": "close"}]}}}


func _render() -> void:
	var view: Dictionary = runner.view()
	if view.is_empty():
		world._close_dialog()
		return
	var entry := model.figure(dialog_figure)
	var title := "%s · %s" % [str(entry.name), ROLE_PREFIX]
	if not dialog_mission.is_empty():
		title = "%s · %s" % [str(entry.name), str(model.mission(dialog_mission).title)]
	world._open_dialog(title, str(view.text))
	world.modal.set_meta("open_world_dialog", str(view.id))
	for choice in view.choices:
		var label := str(choice.label)
		if not bool(choice.enabled):
			label += " (Karte fehlt noch)"
		var button: Button = KIT.button(label, _choose.bind(int(choice.index)), 200, Color("1b7d63") if bool(choice.enabled) else Color(0, 0, 0, 0))
		button.name = "DialogChoice_%d" % int(choice.index)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.disabled = not bool(choice.enabled)
		world.modal_box.add_child(button)
	if not dialog_mission.is_empty():
		world.modal_box.add_child(KIT.button("Über deinen Alltag sprechen", _open_routine_dialog, 200))
	elif not model.steps_for_figure(dialog_figure).is_empty():
		world.modal_box.add_child(KIT.button("Zum Auftrag", _resume_mission_dialog, 200, Color("1b7d63")))
	if str(view.id) == "routine_learning":
		var mission_id := model.card_source(str(entry.get("card", "")))
		if model.state(mission_id) in ["available", "active"]:
			world.modal_box.add_child(KIT.button("Lernauftrag auf der Karte verfolgen", _follow.bind(mission_id), 200, Color("1b7d63")))


func _open_routine_dialog() -> void:
	if dialog_figure.is_empty():
		return
	dialog_mission = ""
	dialog_step = ""
	runner = DIALOG.new(smalltalk_tree(dialog_figure), int(world.grade), model.cards())
	runner.node_id = "routine"
	_play_figure_clip(dialog_figure, "agree_nod", false)
	_render()


func _resume_mission_dialog() -> void:
	var steps := model.steps_for_figure(dialog_figure)
	if steps.is_empty():
		return
	dialog_mission = str(steps[0].mission)
	dialog_step = str(steps[0].step.id)
	runner = DIALOG.new(model.dialog(str(steps[0].step.dialog)), int(world.grade), model.cards())
	_render()


func _choose(index: int) -> void:
	if runner == null:
		return
	match runner.choose(index):
		"next":
			_render()
		"close":
			_end_conversation()
		"complete":
			if dialog_mission.is_empty():
				_end_conversation()
				return
			var mission_id := dialog_mission
			var result: Dictionary = model.complete(mission_id, dialog_step, world.player.position, world.driving)
			_end_conversation()
			if not bool(result.ok):
				world.status_label.text = "Komm noch einmal näher und sprich in Ruhe mit der Figur."
				return
			world.fox.gesture("celebrate")
			_commit(_step_message(mission_id, bool(result.done)))
			if not result.cards.is_empty():
				_show_cards(result.cards)


func _clear_conversation() -> void:
	runner = null
	dialog_mission = ""
	dialog_step = ""
	dialog_figure = ""
	if world.modal.has_meta("open_world_dialog"):
		world.modal.remove_meta("open_world_dialog")


func _end_conversation() -> void:
	_clear_conversation()
	world._close_dialog()


# --- Cards and journal ---------------------------------------------------------

func _show_cards(card_ids: Array) -> void:
	var names: Array[String] = []
	for card_id in card_ids:
		names.append(str(model.figure(str(model.card(str(card_id)).figure)).name))
	world._open_dialog("Neue Figurenkarte!", "In deinem Album: " + ", ".join(names) + ". Du findest alle Karten unter Weltkarte → Aufträge & Figurenkarten.")
	var row := HFlowContainer.new()
	row.name = "NewCards"
	row.add_theme_constant_override("h_separation", 10)
	row.add_theme_constant_override("v_separation", 10)
	world.modal_box.add_child(row)
	for card_id in card_ids:
		row.add_child(card_panel(str(card_id), true))
	world.modal_box.add_child(KIT.button("Weiter erkunden", world._close_dialog, 180, Color("1b7d63")))


func card_panel(card_id: String, owned: bool) -> PanelContainer:
	var card := model.card(card_id)
	var entry := model.figure(str(card.figure))
	var color := Color("8ca0b0")
	for roster_entry in ROSTER.all():
		if str(roster_entry.id) == str(card.figure):
			color = Color(str(roster_entry.get("color", "#8ca0b0")))
	var panel := PanelContainer.new()
	panel.name = "Card_" + card_id
	panel.custom_minimum_size = Vector2(150, 132)
	panel.add_theme_stylebox_override("panel", KIT.tinted_panel(color.darkened(0.55) if owned else Color("1a2b38"), color if owned else Color("3d5566"), 14))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	var heading := KIT.label(str(entry.name) if owned else "???", 18)
	box.add_child(heading)
	var lines := [ROLE_PREFIX + " · " + str(entry.role), "Stärke: " + str(card.power), str(card.trait)] if owned else ["Noch nicht gesammelt", "Mission: " + str(model.mission(model.card_source(card_id)).get("title", ""))]
	for line in lines:
		var text := KIT.label(str(line), 14)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.custom_minimum_size.x = 132
		box.add_child(text)
	return panel


func open_journal() -> void:
	if not unlocked():
		world._open_dialog("Aufträge & Figurenkarten", "Die Missionen konnten nicht geladen werden. Dein gespeicherter Stand bleibt unverändert.")
		world.modal_box.add_child(KIT.button("Weiter erkunden", world._close_dialog, 180))
		return
	var done := 0
	for mission_id in model.mission_ids():
		if model.state(mission_id) == "done":
			done += 1
	world._open_dialog("Aufträge & Figurenkarten", "Missionen %d/%d · Karten %d/%d · Orte %d/%d\nAlle Figuren hier sind Computerfiguren dieser Welt, keine Online-Mitspieler." % [done, model.mission_ids().size(), model.cards().size(), model.content.cards.size(), model.visited.size(), model.content.places.size()])
	world.modal.set_meta("open_world_journal", true)
	for mission_id in model.mission_ids():
		var entry := model.mission(mission_id)
		var state := model.state(mission_id)
		var step := model.current_step(mission_id)
		var status := "Geschafft" if state == "done" else ("Schritt %d/%d: %s" % [int(model.progress[mission_id]) + 1, entry.steps.size(), str(step.lead)])
		var line := KIT.label("%s (%s)\n%s" % [str(entry.title), str(entry.subject), status], 16)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.name = "JournalMission_" + mission_id
		world.modal_box.add_child(line)
		if state != "done":
			var follow: Button = KIT.button("Wird verfolgt" if model.tracked == mission_id else "Verfolgen", _follow.bind(mission_id), 180)
			follow.name = "JournalFollow_" + mission_id
			follow.disabled = model.tracked == mission_id
			world.modal_box.add_child(follow)
	world.modal_box.add_child(KIT.label("Figurenkarten-Album", 20))
	var grid := HFlowContainer.new()
	grid.name = "CardAlbum"
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	world.modal_box.add_child(grid)
	var owned := model.cards()
	for entry in model.content.cards:
		grid.add_child(card_panel(str(entry.id), str(entry.id) in owned))
	world.modal_box.add_child(KIT.button("Weiter erkunden", world._close_dialog, 180, Color("1b7d63")))


func _follow(mission_id: String) -> void:
	if not model.track(mission_id):
		return
	if runner != null:
		_end_conversation()
	else:
		world._close_dialog()
	_commit("Du verfolgst jetzt: " + str(model.mission(mission_id).title) + ". Der lila Marker zeigt dir das Ziel.")


# --- Map -----------------------------------------------------------------------

func map_places() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for place in model.content.places:
		if str(place.kind) == "landmark":
			continue
		var at: Vector3 = place.position
		result.append({"id": "ow_" + str(place.id), "title": str(place.title), "at": at, "view": Rect2(at.x - 40, at.z - 30, 80, 60)})
	return result


func map_paths() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for path in model.content.paths:
		var points: Array = path.points
		for index in range(points.size() - 1):
			result.append({"from": Vector3(float(points[index][0]), 0, float(points[index][1])), "to": Vector3(float(points[index + 1][0]), 0, float(points[index + 1][1]))})
	return result


func map_figures() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in model.content.figures:
		if figures.has(str(entry.id)):
			result.append({"name": str(entry.name), "at": entry.position})
	return result
