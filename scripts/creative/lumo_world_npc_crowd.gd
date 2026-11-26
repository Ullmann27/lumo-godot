extends Node3D
## Bodies of the Sonnenhafen residents. Each resident has a brain
## (lumo_world_npc_brain.gd) that chooses what to do; this node walks the body
## along the navigation mesh. Near Lumo a NavigationAgent3D steers with
## collision avoidance (residents give way to each other and to Lumo); far away
## the same path is followed as a cheap polyline without avoidance or
## animation. Every frame a body moves at most speed * delta: no teleporting.
## Walkers use only models with a real walking cycle (village figures with an
## authored Walk clip, or the jointed figures whose limbs swing on authored
## pivots). Seated kart rigs are never used as walking figures.

const BRAIN = preload("res://scripts/creative/lumo_world_npc_brain.gd")
const VILLAGE = preload("res://scripts/creative/build_village_art.gd")
const CONTENT_PATH := "res://assets/creative/lumo_world/sonnenhafen/sonnenhafen_residents.json"
const KIT_DIR := "res://assets/creative/lumo_world/sonnenhafen/kit/"
const ROLE_PREFIX := "Computerfigur"
const WALK_SPEED := 1.35
const NEAR_RANGE := 55.0
const FAR_RANGE := 62.0
const VISIBLE_RANGE := 95.0
const ARRIVE_DISTANCE := 0.45
const CHAT_GAP := 1.7
const BODY_HEIGHT := 2.3
const TALK_SWAP := 3.4
const STUCK_LIMIT := 7.0
const ANIMATED_LIMIT := {"low": 6, "medium": 10, "high": 14}
## Model-size corrections so every headwear covers the baked village hats.
const ACCESSORY_SCALE := {"cap": 1.45, "baker": 1.4, "scarf": 1.75}
const ACCESSORY_DROP := {"baker": 0.03, "cap": 0.01}

var world: Node3D
var town: Node3D
var layout
var content: Dictionary = {}
var actors: Dictionary = {}
var order: Array[String] = []
var map_rid := RID()
var map_ready := false
var reduced_motion := false
var animated_limit := 10
var player_obstacle: NavigationObstacle3D
var kart_obstacle: NavigationObstacle3D
var talk_clock: Dictionary = {}
var stats := {
	"max_step": 0.0, "teleports": 0, "agent_moves": 0, "far_moves": 0, "chats": 0, "greetings": 0
}
var last_delta := 0.016


func setup(owner_world: Node3D, owner_town: Node3D, plan, saved: Variant = {}) -> bool:
	world = owner_world
	town = owner_town
	layout = plan
	name = "SonnenhafenResidents"
	reduced_motion = bool(world.get("reduced_motion")) if world != null else false
	animated_limit = int(ANIMATED_LIMIT.get(LumoQuality.tier(), 10))
	var raw = JSON.parse_string(FileAccess.get_file_as_string(CONTENT_PATH))
	if not raw is Dictionary or raw.get("schemaVersion") != 1 or not raw.get("residents") is Array:
		push_error("[Sonnenhafen] residents content invalid")
		return false
	content = raw
	var restored := true
	var saved_people: Dictionary = (
		saved.get("people", {}) if saved is Dictionary and saved.get("people") is Dictionary else {}
	)
	for entry in content.residents:
		var actor := _spawn(entry)
		if actor.is_empty():
			continue
		actors[str(entry.id)] = actor
		order.append(str(entry.id))
		if saved_people.has(str(entry.id)):
			restored = actor.brain.restore(saved_people[str(entry.id)]) and restored
	if world != null and world.get("player") is Node3D:
		player_obstacle = _obstacle(world.player, 0.75, "SonnenhafenPlayerObstacle")
	if world != null and world.get("kart_body") is Node3D:
		kart_obstacle = _obstacle(world.kart_body, 1.8, "SonnenhafenKartObstacle")
	return restored


func _obstacle(parent: Node3D, radius: float, label: String) -> NavigationObstacle3D:
	var obstacle := NavigationObstacle3D.new()
	obstacle.name = label
	obstacle.radius = radius
	obstacle.height = 2.0
	obstacle.avoidance_enabled = true
	parent.add_child(obstacle)
	return obstacle


func _exit_tree() -> void:
	for obstacle in [player_obstacle, kart_obstacle]:
		if is_instance_valid(obstacle):
			obstacle.queue_free()


# --- Construction -----------------------------------------------------------------


func _spawn(entry: Dictionary) -> Dictionary:
	var body_path := str(content.get("bodies", {}).get(str(entry.body), ""))
	var scene := load(body_path) as PackedScene if ResourceLoader.exists(body_path) else null
	if scene == null:
		push_warning("[Sonnenhafen] body missing for " + str(entry.id))
		return {}
	var brain = BRAIN.new(entry)
	var root := Node3D.new()
	root.name = "Resident_" + str(entry.id)
	add_child(root)
	var visual := scene.instantiate() as Node3D
	visual.name = "Body"
	root.add_child(visual)
	var bounds := AABB()
	for node in visual.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var box: AABB = (
			visual.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
		)
		bounds = box if bounds.size == Vector3.ZERO else bounds.merge(box)
	var height := BODY_HEIGHT * float(entry.get("scale", 1.0))
	var factor := height / maxf(bounds.size.y, 0.1)
	visual.scale = Vector3.ONE * factor
	visual.position.y = -bounds.position.y * factor
	var tint := Color(str(entry.get("tint", "ffffff")))
	var material_cache: Dictionary = {}
	for node in visual.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		mesh.visibility_range_end = VISIBLE_RANGE
		var source := mesh.get_active_material(0)
		if source is StandardMaterial3D:
			if not material_cache.has(source):
				var copy := (source as StandardMaterial3D).duplicate() as StandardMaterial3D
				copy.albedo_color = copy.albedo_color * tint
				material_cache[source] = copy
			mesh.material_override = material_cache[source]
	var animation := visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var walk_clip := ""
	if animation != null:
		animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		for clip in animation.get_animation_list():
			if str(clip).to_lower().begins_with("walk"):
				walk_clip = str(clip)
				animation.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
				break
	var skeleton := visual.find_child("Skeleton3D", true, false) as Skeleton3D
	var limbs: Array[Node3D] = []
	for limb_name in ["ForeL", "ForeR", "HindL", "HindR", "Tail"]:
		var limb := visual.find_child(limb_name, true, false) as Node3D
		if limb != null:
			limbs.append(limb)
	_accessory(entry, visual, skeleton, bounds)
	var agent := NavigationAgent3D.new()
	agent.name = "Agent"
	agent.radius = 0.55
	agent.height = 2.0
	agent.max_speed = WALK_SPEED * 1.4
	agent.path_desired_distance = 0.6
	agent.target_desired_distance = ARRIVE_DISTANCE
	agent.neighbor_distance = 8.0
	agent.max_neighbors = 8
	agent.time_horizon_agents = 1.4
	agent.time_horizon_obstacles = 0.6
	agent.avoidance_enabled = false
	root.add_child(agent)
	var labels := _labels(root, entry, height)
	var home: Vector3 = layout.home_door(str(entry.get("home", "")))
	if not home.is_finite():
		home = layout.spot(str(entry.get("work", "")))
	var angle := float(str(entry.id).hash() % 628) / 100.0
	var actor := {
		"id": str(entry.id),
		"brain": brain,
		"root": root,
		"visual": visual,
		"anim": animation,
		"walk_clip": walk_clip,
		"skeleton": skeleton,
		"limbs": limbs,
		"agent": agent,
		"labels": labels,
		"home": home,
		"offset": Vector3(cos(angle), 0, sin(angle)) * 0.9,
		"target": Vector3.INF,
		"agent_target": Vector3.INF,
		"path": PackedVector3Array(),
		"path_index": 0,
		"near": false,
		"safe_velocity": Vector3.ZERO,
		"velocity": Vector3.ZERO,
		"height": height,
		"stuck": 0.0,
		"progress_at": Vector3.ZERO,
		"progress_clock": 0.0,
		"travelled": 0.0,
		"spots_reached": {},
		"idle_time": 0.0,
		"max_idle": 0.0,
		"chat_started": 0.0,
		"anim_time": 0.0,
		"facing": 0.0,
		"gesture": 0.0,
		"last_tick_position": Vector3.ZERO,
		"stuck_events": 0,
		"shuffling": false,
		"shuffle_after": 11.0,
		"skip_move": false,
		"last_step": 0.0
	}
	agent.velocity_computed.connect(_on_velocity.bind(str(entry.id)))
	# Warm start: the day begins with each resident at its first morning spot.
	var first: Dictionary = brain.plan(BRAIN.DAY_START, [])
	brain.begin(first)
	var start := _spot_position(actor, str(first.get("spot", "home")))
	root.position = start
	actor.target = start
	actor.last_tick_position = start
	brain.arrived()
	actor.progress_at = start
	return actor


## Hats sit over the baked headwear of the village bodies (per-body anchor
## from sonnenhafen_residents.json → accessoryAnchors), scarves at the neck.
func _accessory(entry: Dictionary, visual: Node3D, skeleton: Skeleton3D, bounds: AABB) -> void:
	var kind := str(entry.get("accessory", ""))
	var anchors: Dictionary = content.get("accessoryAnchors", {}).get(str(entry.body), {})
	if kind.is_empty() or anchors.is_empty():
		return
	var bundle = VILLAGE.bundle_at(KIT_DIR + "acc_" + kind + ".glb", "sonnenhafen_acc_" + kind)
	if bundle.parts.is_empty():
		return
	var hat := MeshInstance3D.new()
	hat.name = "Accessory_" + kind
	hat.mesh = bundle.parts[0].mesh
	hat.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var scarf := kind == "scarf"
	var height_share := float(anchors.get("neck" if scarf else "hat", 0.9))
	var anchor := Vector3(
		bounds.get_center().x,
		bounds.position.y + bounds.size.y * height_share,
		bounds.get_center().z + float(anchors.get("forward", 0.0)) * bounds.size.z
	)
	var size := bounds.size.x * float(anchors.get("scarf_scale" if scarf else "hat_scale", 0.7))
	size *= float(ACCESSORY_SCALE.get(kind, 1.0))
	anchor.y -= bounds.size.y * float(ACCESSORY_DROP.get(kind, 0.0))
	var placed := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * size), anchor)
	var bone_name := "body" if scarf else "head"
	if skeleton != null and skeleton.find_bone(bone_name) >= 0:
		var attach := BoneAttachment3D.new()
		attach.name = "AccessoryMount"
		attach.bone_name = bone_name
		skeleton.add_child(attach)
		var rest := skeleton.get_bone_global_rest(skeleton.find_bone(bone_name))
		var to_skeleton := skeleton.global_transform.affine_inverse() * visual.global_transform
		hat.transform = rest.affine_inverse() * to_skeleton * placed
		attach.add_child(hat)
	else:
		var body := visual.find_child("Body", true, false) as Node3D
		var holder: Node3D = body if body != null else visual
		hat.transform = holder.global_transform.affine_inverse() * visual.global_transform * placed
		holder.add_child(hat)


func _labels(root: Node3D, entry: Dictionary, height: float) -> Dictionary:
	var made := {}
	for spec in [
		["name", str(entry.name), 32, Color("fff1c8"), height + 0.75, 42.0],
		["role", ROLE_PREFIX + " · " + str(entry.role), 22, Color("d8ecef"), height + 0.42, 24.0],
		["bubble", "", 26, Color("ffffff"), height + 1.25, 30.0]
	]:
		var label := Label3D.new()
		label.name = "Label_" + str(spec[0])
		label.text = str(spec[1])
		label.font_size = int(spec[2])
		label.pixel_size = 0.008
		label.modulate = spec[3]
		label.outline_modulate = Color("163249")
		label.outline_size = 8
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = Vector3(0, float(spec[4]), 0)
		label.visibility_range_end = float(spec[5])
		label.width = 520.0
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		root.add_child(label)
		made[spec[0]] = label
		# The World caps the near size of its signs so a close camera never
		# hides Lumo behind a huge name tag; residents use the same rule.
		if spec[0] != "bubble" and world != null and world.get("art") != null:
			world.art.signs.append(label)
	return made


# --- Planning ----------------------------------------------------------------------


func _spot_position(actor: Dictionary, spot_id: String) -> Vector3:
	var base: Vector3 = actor.home if spot_id == "home" else layout.spot(spot_id)
	if not base.is_finite():
		base = actor.home
	if spot_id == "home":
		return _snap(base)
	# A personal offset keeps residents at the same spot from overlapping.
	for share in [1.0, 0.5, 0.0]:
		var probe: Vector3 = base + (actor.offset as Vector3) * float(share)
		if layout.is_walkable(Vector2(probe.x, probe.z)):
			return Vector3(probe.x, 0.0, probe.z)
	return _snap(base)


func _snap(at: Vector3) -> Vector3:
	if not layout.is_walkable(Vector2(at.x, at.z)) and map_ready:
		var closest := NavigationServer3D.map_get_closest_point(map_rid, at)
		return Vector3(closest.x, 0.0, closest.z)
	return Vector3(at.x, 0.0, at.z)


func _plan(actor: Dictionary, hour: float) -> void:
	var brain = actor.brain
	var friends: Array = []
	for other_id in order:
		if other_id == actor.id:
			continue
		var other: Dictionary = actors[other_id]
		var other_brain = other.brain
		if other_brain.state != BRAIN.State.IDLE or not other_brain.partner.is_empty():
			continue
		if (other.root.position as Vector3).distance_to(actor.root.position) <= BRAIN.CHAT_RANGE:
			friends.append(other_id)
	var from: Vector3 = actor.root.position
	var distance_of := func(spot_id: String) -> float:
		var spot_at: Vector3 = actor.home if spot_id == "home" else layout.spot(spot_id)
		return from.distance_to(spot_at) if spot_at.is_finite() else 200.0
	var plan_data: Dictionary = brain.plan(hour, friends, distance_of)
	if str(plan_data.kind) == "chat":
		var partner: Dictionary = actors[str(plan_data.partner)]
		plan_data["partner_name"] = partner.brain.first_name()
		brain.begin(plan_data)
		var partner_brain = partner.brain
		partner_brain.state = BRAIN.State.TALK
		partner_brain.partner = actor.id
		partner_brain.timer = float(plan_data.duration) + 30.0
		var toward: Vector3 = actor.root.position - partner.root.position
		toward.y = 0.0
		var meet: Vector3 = (
			partner.root.position
			+ (toward.normalized() if toward.length() > 0.1 else Vector3.FORWARD) * CHAT_GAP
		)
		actor.target = _snap(meet)
		actor.chat_started = 0.0
	else:
		brain.begin(plan_data)
		actor.target = (
			actor.home
			if str(plan_data.spot) == "home"
			else _spot_position(actor, str(plan_data.spot))
		)
	actor.path = PackedVector3Array()
	actor.path_index = 0
	actor.stuck = 0.0
	_show(actor, true)


# --- Per frame ----------------------------------------------------------------------


func tick(delta: float, hour: float, player_at: Vector3, driving: bool) -> void:
	var step := clampf(delta, 0.0, 0.1)
	if step <= 0.0:
		return
	last_delta = step
	if not map_ready:
		map_rid = get_world_3d().navigation_map
		map_ready = NavigationServer3D.map_get_iteration_id(map_rid) > 0
	if is_instance_valid(player_obstacle) and world.get("player") is CharacterBody3D:
		player_obstacle.velocity = (world.player as CharacterBody3D).velocity
	var ranked: Array = []
	for id in order:
		var actor: Dictionary = actors[id]
		var distance := (
			Vector2(actor.root.position.x - player_at.x, actor.root.position.z - player_at.z)
			. length()
		)
		ranked.append([distance, id])
	ranked.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for rank in range(ranked.size()):
		var actor: Dictionary = actors[ranked[rank][1]]
		_tick_actor(
			actor, step, hour, player_at, float(ranked[rank][0]), driving, rank < animated_limit
		)


func _tick_actor(
	actor: Dictionary,
	step: float,
	hour: float,
	player_at: Vector3,
	distance: float,
	driving: bool,
	animate: bool
) -> void:
	var brain = actor.brain
	var was_home: bool = brain.state == BRAIN.State.HOME
	if brain.tick(step, hour):
		if was_home:
			_show(actor, true)
		if brain.state != BRAIN.State.HOME:
			_plan(actor, hour)
	_update_mode(actor, distance)
	if brain.state == BRAIN.State.WALK:
		if map_ready:
			if actor.near:
				_walk_agent(actor, step)
			else:
				_walk_polyline(actor, step)
		_check_progress(actor, step)
	else:
		if actor.near:
			(actor.agent as NavigationAgent3D).velocity = Vector3.ZERO
		actor.velocity = Vector3.ZERO
	if (
		brain.state == BRAIN.State.TALK
		and not brain.partner.is_empty()
		and actors.has(brain.partner)
	):
		_face(actor, (actors[brain.partner].root as Node3D).position, step)
		_talk_bubbles(actor, step)
	elif (
		not driving
		and distance <= BRAIN.GREET_RANGE
		and brain.state in [BRAIN.State.IDLE, BRAIN.State.WALK]
	):
		var known: bool = brain.knows("met")
		if not brain.greet(known).is_empty():
			brain.remember("met")
			stats.greetings += 1
	if brain.state == BRAIN.State.GREET:
		_face(actor, player_at, step)
	elif brain.state == BRAIN.State.IDLE:
		actor.idle_time += step
		actor.max_idle = maxf(actor.max_idle, actor.idle_time)
		if actor.idle_time >= float(actor.shuffle_after) and _shuffle(actor):
			actor.idle_time = 0.0
	if brain.state != BRAIN.State.IDLE:
		actor.idle_time = 0.0
	# Movement since the previous tick, including the avoidance callback move.
	var moved: Vector3 = actor.root.position - actor.last_tick_position
	actor.last_tick_position = actor.root.position
	moved.y = 0.0
	var length := moved.length()
	stats.max_step = maxf(stats.max_step, length)
	# The avoidance callback after the previous tick moved with that tick's delta.
	var allowed := WALK_SPEED * 1.5 * maxf(step, float(actor.last_step)) + 0.05
	actor.last_step = step
	if length > allowed:
		stats.teleports += 1
		stats["last_teleport"] = (
			"%s %.3f m step %.4f state %d near %s skip %s frame %d"
			% [
				actor.id,
				length,
				step,
				brain.state,
				str(actor.near),
				str(actor.skip_move),
				Engine.get_physics_frames()
			]
		)
	actor.travelled += length
	if length > 0.0005:
		actor.facing = lerp_angle(actor.facing, atan2(moved.x, moved.z), 1.0 - exp(-8.0 * step))
		actor.root.rotation.y = actor.facing
	_animate(actor, step, length / step, animate and distance < VISIBLE_RANGE)
	_update_labels(actor, distance)


func _update_mode(actor: Dictionary, distance: float) -> void:
	var agent: NavigationAgent3D = actor.agent
	if actor.near and distance > FAR_RANGE:
		actor.near = false
		agent.avoidance_enabled = false
		actor.path = PackedVector3Array()
		# The avoidance callback may already have moved the body this frame.
		actor.skip_move = true
	elif not actor.near and distance < NEAR_RANGE:
		actor.near = true
		agent.avoidance_enabled = true
		actor.agent_target = Vector3.INF


func _walk_agent(actor: Dictionary, _step: float) -> void:
	var agent: NavigationAgent3D = actor.agent
	var target: Vector3 = actor.target
	var retarget := not (actor.agent_target as Vector3).is_equal_approx(target)
	if retarget:
		agent.target_position = target
		actor.agent_target = target
	var position: Vector3 = actor.root.position
	# The path is refreshed lazily by get_next_path_position(); arrival is
	# decided by the real distance, never by a stale "finished" flag.
	var next := agent.get_next_path_position()
	if retarget:
		var reachable := agent.get_final_position()
		if (
			reachable.is_finite()
			and Vector2(reachable.x - target.x, reachable.z - target.z).length() > 0.3
		):
			target = Vector3(reachable.x, 0.0, reachable.z)
			actor.target = target
			actor.agent_target = target
			agent.target_position = target
	if Vector2(position.x - target.x, position.z - target.z).length() <= ARRIVE_DISTANCE:
		_arrive(actor)
		return
	var direction := next - position
	direction.y = 0.0
	if direction.length() < 0.05:
		# Standing on a path corner: look one corner further along the path.
		var path := agent.get_current_navigation_path()
		var index := agent.get_current_navigation_path_index() + 1
		if index < path.size():
			direction = path[index] - position
			direction.y = 0.0
	if direction.length() < 0.05:
		actor.velocity = Vector3.ZERO
		agent.velocity = Vector3.ZERO
		return
	var desired := direction.normalized() * WALK_SPEED
	actor.velocity = desired
	agent.velocity = desired


func _on_velocity(safe: Vector3, id: String) -> void:
	if not actors.has(id):
		return
	var actor: Dictionary = actors[id]
	# Avoidance keeps reporting while the World is paused (dialogs): never move then.
	if actor.brain.state != BRAIN.State.WALK or not actor.near or bool(world.get("paused")):
		return
	var move := Vector3(safe.x, 0.0, safe.z) * last_delta
	var limit := WALK_SPEED * 1.25 * last_delta
	if move.length() > limit:
		move = move.normalized() * limit
	var proposed: Vector3 = actor.root.position + move
	if map_ready:
		var snapped := NavigationServer3D.map_get_closest_point(map_rid, proposed)
		if Vector2(snapped.x - proposed.x, snapped.z - proposed.z).length() > 0.01:
			proposed = Vector3(snapped.x, 0.0, snapped.z)
	proposed.y = 0.0
	# A correction back onto the mesh is limited to one walking step: the
	# body never jumps, it only slides along the edge of the walkable area.
	var current: Vector3 = actor.root.position
	if proposed.distance_to(current) > limit:
		proposed = current + (proposed - current).normalized() * limit
	actor.root.position = proposed
	stats.agent_moves += 1


func _walk_polyline(actor: Dictionary, step: float) -> void:
	if actor.skip_move:
		actor.skip_move = false
		return
	var target: Vector3 = actor.target
	var path: PackedVector3Array = actor.path
	if path.is_empty():
		path = NavigationServer3D.map_get_path(map_rid, actor.root.position, target, true)
		actor.path = path
		actor.path_index = 1
		if path.size() < 2:
			_arrive(actor)
			return
	var remaining := WALK_SPEED * step
	var position: Vector3 = actor.root.position
	var index := int(actor.path_index)
	while remaining > 0.0 and index < path.size():
		var point := Vector3(path[index].x, 0.0, path[index].z)
		var gap := position.distance_to(point)
		if gap <= remaining:
			position = point
			remaining -= gap
			index += 1
		else:
			position += (point - position) / gap * remaining
			remaining = 0.0
	actor.path_index = index
	actor.root.position = position
	stats.far_moves += 1
	if index >= path.size():
		_arrive(actor)


func _shuffle(actor: Dictionary) -> bool:
	var brain = actor.brain
	var base: Vector3 = layout.spot(brain.spot)
	if not base.is_finite():
		return false
	var rng: RandomNumberGenerator = brain.rng
	actor.shuffle_after = rng.randf_range(9.0, 15.0)
	for attempt in range(4):
		var angle := rng.randf() * TAU
		var radius := rng.randf_range(1.2, 2.6)
		var probe := base + Vector3(cos(angle), 0.0, sin(angle)) * radius
		if (
			layout.is_walkable(Vector2(probe.x, probe.z))
			and probe.distance_to(actor.root.position) > 0.9
		):
			if brain.shuffle():
				actor.target = Vector3(probe.x, 0.0, probe.z)
				actor.path = PackedVector3Array()
				actor.shuffling = true
				return true
	return false


func _arrive(actor: Dictionary) -> void:
	var brain = actor.brain
	var was_shuffling: bool = actor.shuffling
	actor.shuffling = false
	brain.arrived()
	actor.velocity = Vector3.ZERO
	(actor.agent as NavigationAgent3D).velocity = Vector3.ZERO
	if not brain.spot.is_empty() and not was_shuffling:
		actor.spots_reached[brain.spot] = int(actor.spots_reached.get(brain.spot, 0)) + 1
	if brain.state == BRAIN.State.HOME:
		_show(actor, false)
	elif brain.state == BRAIN.State.TALK and actors.has(brain.partner):
		var partner: Dictionary = actors[brain.partner]
		var partner_brain = partner.brain
		if partner_brain.partner == actor.id:
			brain.start_chat(partner_brain, true)
			partner_brain.start_chat(brain, false)
			partner_brain.timer = brain.timer
			talk_clock[actor.id] = 0.0
			stats.chats += 1
		else:
			brain.partner = ""
			brain.timer = 0.0
	elif brain.state == BRAIN.State.IDLE:
		var spot_at: Vector3 = layout.spot(brain.spot) if brain.spot != "home" else actor.home
		if spot_at.is_finite():
			_face_instant(actor, spot_at - (actor.offset as Vector3) * 2.0)


func _check_progress(actor: Dictionary, step: float) -> void:
	actor.progress_clock += step
	if actor.progress_clock < 2.0:
		return
	var moved := (actor.root.position as Vector3).distance_to(actor.progress_at)
	actor.progress_at = actor.root.position
	actor.progress_clock = 0.0
	if moved < 0.25:
		actor.stuck += 2.0
	else:
		actor.stuck = 0.0
	var brain = actor.brain
	if not brain.partner.is_empty():
		actor.chat_started += 2.0
	if actor.chat_started > 40.0 and not brain.partner.is_empty():
		# The partner could not be reached in time: both carry on with their day.
		if actors.has(brain.partner):
			var partner_brain = actors[brain.partner].brain
			partner_brain.partner = ""
			partner_brain.timer = 0.0
		brain.partner = ""
		actor.chat_started = 0.0
		brain.arrived()
		return
	if actor.stuck < STUCK_LIMIT:
		return
	# Blocked: first ask for a fresh path; a resident never vanishes or jumps.
	actor.stuck = 0.0
	actor.stuck_events = int(actor.stuck_events) + 1
	actor.agent_target = Vector3.INF
	actor.path = PackedVector3Array()
	if int(actor.stuck_events) % 3 == 0 and brain.spot != "home":
		brain.arrived()


func _talk_bubbles(actor: Dictionary, step: float) -> void:
	if not talk_clock.has(actor.id):
		return
	talk_clock[actor.id] = float(talk_clock[actor.id]) + step
	var clock: float = talk_clock[actor.id]
	var turn := int(clock / TALK_SWAP)
	if int((clock - step) / TALK_SWAP) == turn:
		return
	var brain = actor.brain
	var partner_brain = actors[brain.partner].brain
	var speaker = brain if turn % 2 == 0 else partner_brain
	if speaker.talk_lines.is_empty():
		return
	speaker.say(speaker.talk_lines[(turn / 2) % speaker.talk_lines.size()], TALK_SWAP - 0.2)


func _face(actor: Dictionary, at: Vector3, step: float) -> void:
	var toward: Vector3 = at - actor.root.position
	if Vector2(toward.x, toward.z).length() < 0.2:
		return
	actor.facing = lerp_angle(actor.facing, atan2(toward.x, toward.z), 1.0 - exp(-5.0 * step))
	actor.root.rotation.y = actor.facing


func _face_instant(actor: Dictionary, at: Vector3) -> void:
	var toward: Vector3 = at - actor.root.position
	if Vector2(toward.x, toward.z).length() > 0.2:
		actor.facing = atan2(toward.x, toward.z)


func _show(actor: Dictionary, visible_now: bool) -> void:
	(actor.root as Node3D).visible = visible_now


# --- Presentation -------------------------------------------------------------------


func _animate(actor: Dictionary, step: float, speed: float, animate: bool) -> void:
	if not animate or not (actor.root as Node3D).visible:
		return
	var brain = actor.brain
	var walking := speed > 0.15
	actor.anim_time += step
	var animation: AnimationPlayer = actor.anim
	if animation != null and not str(actor.walk_clip).is_empty():
		if walking:
			if str(animation.current_animation) != str(actor.walk_clip):
				animation.play(str(actor.walk_clip))
			animation.advance(step * clampf(speed / WALK_SPEED, 0.5, 1.4))
		elif animation.is_playing():
			animation.stop()
			if actor.skeleton != null:
				(actor.skeleton as Skeleton3D).reset_bone_poses()
		if not walking and actor.skeleton != null and not reduced_motion:
			_procedural_pose(actor, brain)
	var limbs: Array = actor.limbs
	if not limbs.is_empty():
		var stride := sin(float(actor.anim_time) * 6.2) * (0.38 if walking else 0.0)
		for index in range(mini(4, limbs.size())):
			(limbs[index] as Node3D).rotation.x = stride * (1.0 if index in [0, 3] else -1.0)
		if brain.state == BRAIN.State.GREET and limbs.size() > 1 and not reduced_motion:
			(limbs[1] as Node3D).rotation.x = -1.9 + sin(float(actor.anim_time) * 9.0) * 0.35
		if limbs.size() > 4:
			(limbs[4] as Node3D).rotation.y = sin(float(actor.anim_time) * 1.7) * 0.2
	if not walking and not reduced_motion:
		var breath := 1.0 + sin(float(actor.anim_time) * 2.1 + float(actor.id.hash() % 7)) * 0.012
		(actor.visual as Node3D).scale.y = (actor.visual as Node3D).scale.x * breath
	else:
		(actor.visual as Node3D).scale.y = (actor.visual as Node3D).scale.x


## Standing residents talk with their arms and wave at Lumo (skinned figures).
func _procedural_pose(actor: Dictionary, brain) -> void:
	var skeleton: Skeleton3D = actor.skeleton
	var t: float = actor.anim_time
	var arm := skeleton.find_bone("right_arm")
	var other := skeleton.find_bone("left_arm")
	var head := skeleton.find_bone("head")
	if brain.state == BRAIN.State.GREET and arm >= 0:
		var lift := Quaternion(Vector3(0, 0, 1), 2.3 + sin(t * 9.0) * 0.35)
		skeleton.set_bone_pose_rotation(
			arm, skeleton.get_bone_rest(arm).basis.get_rotation_quaternion() * lift
		)
	elif brain.state == BRAIN.State.TALK and arm >= 0 and other >= 0:
		var talk := Quaternion(Vector3(1, 0, 0), -0.4 + sin(t * 3.1) * 0.25)
		skeleton.set_bone_pose_rotation(
			arm, skeleton.get_bone_rest(arm).basis.get_rotation_quaternion() * talk
		)
		var answer := Quaternion(Vector3(1, 0, 0), -0.2 + sin(t * 2.3 + 1.0) * 0.15)
		skeleton.set_bone_pose_rotation(
			other, skeleton.get_bone_rest(other).basis.get_rotation_quaternion() * answer
		)
	else:
		# Working pose: arms back to rest after waving or talking.
		for bone in [arm, other]:
			if bone >= 0:
				skeleton.set_bone_pose_rotation(
					bone, skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()
				)
	if head >= 0:
		var nod := Quaternion(
			Vector3(1, 0, 0),
			sin(t * 1.3) * 0.06 + (sin(t * 6.0) * 0.08 if brain.state == BRAIN.State.TALK else 0.0)
		)
		skeleton.set_bone_pose_rotation(
			head, skeleton.get_bone_rest(head).basis.get_rotation_quaternion() * nod
		)


func _update_labels(actor: Dictionary, distance: float) -> void:
	var labels: Dictionary = actor.labels
	var brain = actor.brain
	var bubble: Label3D = labels.bubble
	bubble.visible = not str(brain.bubble).is_empty()
	if bubble.visible and bubble.text != str(brain.bubble):
		bubble.text = str(brain.bubble)
	if distance < 16.0:
		var role_text := "%s · %s\n%s" % [ROLE_PREFIX, str(brain.profile.role), brain.status_text()]
		var role: Label3D = labels.role
		if role.text != role_text:
			role.text = role_text


# --- Queries ------------------------------------------------------------------------


func nearest(at: Vector3, reach: float) -> String:
	var best := ""
	var best_distance := reach
	for id in order:
		var actor: Dictionary = actors[id]
		if not (actor.root as Node3D).visible:
			continue
		var offset: Vector3 = actor.root.position - at
		var distance := Vector2(offset.x, offset.z).length()
		if distance <= best_distance:
			best = id
			best_distance = distance
	return best


func position_of(id: String) -> Vector3:
	return (actors[id].root as Node3D).position if actors.has(id) else Vector3.INF


func brain_of(id: String):
	return actors[id].brain if actors.has(id) else null


func map_figures() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id in order:
		var actor: Dictionary = actors[id]
		if (actor.root as Node3D).visible:
			result.append({"name": str(actor.brain.profile.name), "at": actor.root.position})
	return result


func to_data() -> Dictionary:
	var people: Dictionary = {}
	for id in order:
		people[id] = actors[id].brain.to_data()
	return {"people": people}
