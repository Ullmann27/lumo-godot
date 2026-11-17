extends Node3D
## Live item objects on the track: homing Sternraketen, bouncing Funkenkugeln and
## dropped Blubberblasen. Simulated in track space (race progress + lateral offset),
## so it is cheap on mid-range phones and independent of physics bodies.
## Hits are child-friendly: the target only spins once and keeps driving.

const CATALOG = preload("res://scripts/games/kart_items/kart_item_catalog.gd")
const PLAYER_KEY: int = -1
const MAX_PROJECTILES: int = 12
const MAX_TRAPS: int = 10
const HIT_PROGRESS: float = 1.5
const HIT_LATERAL: float = 1.3
const OWNER_GRACE_SECONDS: float = 0.6
const HOMING_LOCK_DISTANCE: float = 28.0
const HOMING_LATERAL_SPEED: float = 7.0

var track_length: float = 1.0
var wall_lateral: float = 4.6
var placer: Callable
var reduced_motion: bool = false
var projectiles: Array[Dictionary] = []
var traps: Array[Dictionary] = []
var stats := {"fired": 0, "dropped": 0, "hits": 0, "blocked": 0, "expired": 0, "intercepted": 0}

static var _rocket_mesh: Mesh
static var _ball_mesh: Mesh
static var _bubble_mesh: Mesh
static var _trail_mesh: Mesh


func setup(length: float, wall: float, frame_at: Callable) -> void:
	track_length = maxf(1.0, length)
	wall_lateral = wall
	placer = frame_at


func clear() -> void:
	for entry in projectiles + traps:
		if is_instance_valid(entry.node):
			entry.node.queue_free()
	projectiles.clear()
	traps.clear()


func active_count() -> int:
	return projectiles.size() + traps.size()


func wrapped(delta_progress: float) -> float:
	return fposmod(delta_progress + track_length * 0.5, track_length) - track_length * 0.5


func fire_homing(item: String, owner: int, progress: float, lateral: float, target: int) -> bool:
	return _launch(item, "homing", owner, progress + 1.8, lateral, 0.0, target)


func fire_bouncing(item: String, owner: int, progress: float, lateral: float, lateral_velocity: float) -> bool:
	return _launch(item, "bouncing", owner, progress + 1.8, lateral, lateral_velocity, -99)


func drop_trap(item: String, owner: int, progress: float, lateral: float) -> bool:
	if traps.size() >= MAX_TRAPS:
		var oldest: Dictionary = traps.pop_front()
		if is_instance_valid(oldest.node):
			oldest.node.queue_free()
	var node := _make_visual("trap", CATALOG.color(item))
	var entry := {
		"item": item, "kind": "trap", "owner": owner, "progress": progress - 2.2,
		"lateral": lateral, "age": 0.0, "life": CATALOG.number(item, "life", 25.0), "node": node,
	}
	traps.append(entry)
	stats.dropped += 1
	_place(entry)
	return true


func _launch(item: String, kind: String, owner: int, progress: float, lateral: float, lateral_velocity: float, target: int) -> bool:
	if projectiles.size() >= MAX_PROJECTILES:
		return false
	var node := _make_visual(kind, CATALOG.color(item))
	var entry := {
		"item": item, "kind": kind, "owner": owner, "progress": progress, "lateral": lateral,
		"lateral_velocity": lateral_velocity, "target": target, "age": 0.0,
		"speed": CATALOG.number(item, "speed", 36.0), "life": CATALOG.number(item, "life", 4.5), "node": node,
	}
	projectiles.append(entry)
	stats.fired += 1
	_place(entry)
	return true


## Seconds until the nearest rocket aimed at `key` arrives (INF if none).
func incoming_for(key: int, racer_progress: float) -> float:
	var best: float = INF
	for entry in projectiles:
		if entry.kind == "homing" and int(entry.target) == key:
			var gap: float = racer_progress - float(entry.progress)
			if gap >= -HIT_PROGRESS:
				best = minf(best, maxf(0.0, gap) / maxf(1.0, float(entry.speed)))
	return best


## Advance every object. `racers`: [{key, progress, lateral, protected}] with
## cumulative race progress. Returns hit/blocked events for the race to apply.
func step(delta: float, racers: Array) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var keep: Array[Dictionary] = []
	for entry in projectiles:
		entry.age += delta
		var target_racer: Dictionary = _racer(racers, int(entry.target))
		if entry.kind == "homing" and not target_racer.is_empty():
			var to_target: float = float(target_racer.progress) - float(entry.progress)
			if to_target < -HIT_PROGRESS * 2.0:
				# The target dropped behind the rocket: it fizzles harmlessly.
				entry.life = 0.0
			elif to_target < HOMING_LOCK_DISTANCE:
				entry.lateral = move_toward(float(entry.lateral), float(target_racer.lateral), HOMING_LATERAL_SPEED * delta)
		elif entry.kind == "bouncing":
			entry.lateral = float(entry.lateral) + float(entry.lateral_velocity) * delta
			if absf(float(entry.lateral)) > wall_lateral:
				entry.lateral = signf(entry.lateral) * (wall_lateral * 2.0 - absf(entry.lateral))
				entry.lateral_velocity = -float(entry.lateral_velocity)
		entry.progress = float(entry.progress) + float(entry.speed) * delta
		var catcher: Dictionary = _trap_in_path(entry)
		if not catcher.is_empty():
			# A Blubberblase swallows the projectile: both pop harmlessly.
			stats.intercepted = int(stats.get("intercepted", 0)) + 1
			events.append({
				"type": "intercepted", "target": int(catcher.owner), "source": int(entry.owner),
				"item": str(entry.item), "spin": 0.0,
				"position": catcher.node.global_position if is_instance_valid(catcher.node) and catcher.node.is_inside_tree() else Vector3.ZERO,
			})
			traps.erase(catcher)
			_retire(catcher)
			_retire(entry)
			continue
		var hit: Dictionary = _first_contact(entry, racers)
		if not hit.is_empty():
			events.append(_resolve(entry, hit))
			_retire(entry)
			continue
		if float(entry.age) >= float(entry.life):
			stats.expired += 1
			_retire(entry)
			continue
		_place(entry)
		keep.append(entry)
	projectiles = keep
	var keep_traps: Array[Dictionary] = []
	for entry in traps:
		entry.age += delta
		var hit: Dictionary = _first_contact(entry, racers)
		if not hit.is_empty():
			events.append(_resolve(entry, hit))
			_retire(entry)
			continue
		if float(entry.age) >= float(entry.life):
			stats.expired += 1
			_retire(entry)
			continue
		_place(entry)
		keep_traps.append(entry)
	traps = keep_traps
	return events


func _trap_in_path(entry: Dictionary) -> Dictionary:
	for trap in traps:
		if int(trap.owner) == int(entry.owner) and float(entry.age) < OWNER_GRACE_SECONDS:
			continue
		if (
			absf(wrapped(float(trap.progress) - float(entry.progress))) <= HIT_PROGRESS
			and absf(float(trap.lateral) - float(entry.lateral)) <= HIT_LATERAL
		):
			return trap
	return {}


func _racer(racers: Array, key: int) -> Dictionary:
	for racer in racers:
		if int(racer.key) == key:
			return racer
	return {}


func _first_contact(entry: Dictionary, racers: Array) -> Dictionary:
	for racer in racers:
		if int(racer.key) == int(entry.owner) and float(entry.age) < OWNER_GRACE_SECONDS:
			continue
		if entry.kind == "homing" and int(racer.key) == int(entry.owner):
			continue
		var along: float = (
			wrapped(float(racer.progress) - float(entry.progress)) if entry.kind == "trap"
			else float(racer.progress) - float(entry.progress)
		)
		if absf(along) <= HIT_PROGRESS and absf(float(racer.lateral) - float(entry.lateral)) <= HIT_LATERAL:
			return racer
	return {}


func _resolve(entry: Dictionary, racer: Dictionary) -> Dictionary:
	var blocked: bool = bool(racer.get("protected", false))
	if blocked:
		stats.blocked += 1
	else:
		stats.hits += 1
	var at: Vector3 = entry.node.global_position if is_instance_valid(entry.node) and entry.node.is_inside_tree() else Vector3.ZERO
	return {
		"type": "blocked" if blocked else "hit", "target": int(racer.key), "source": int(entry.owner),
		"item": str(entry.item), "spin": CATALOG.number(str(entry.item), "spin_seconds", 1.0), "position": at,
	}


func _retire(entry: Dictionary) -> void:
	if is_instance_valid(entry.node):
		entry.node.queue_free()


func _place(entry: Dictionary) -> void:
	if not placer.is_valid() or not is_instance_valid(entry.node):
		return
	var frame: Transform3D = placer.call(fposmod(float(entry.progress), track_length), float(entry.lateral))
	var lift: float = 0.75 if entry.kind != "trap" else 0.85
	var bob: float = 0.0 if reduced_motion else sin(float(entry.age) * 5.0) * 0.12
	entry.node.global_transform = Transform3D(frame.basis, frame.origin + frame.basis.y * (lift + bob))
	if entry.kind == "bouncing" and not reduced_motion:
		entry.node.rotate_object_local(Vector3.RIGHT, -float(entry.age) * 14.0)
	elif entry.kind == "homing" and not reduced_motion:
		entry.node.rotate_object_local(Vector3.FORWARD, float(entry.age) * 9.0)


func _glow(color: Color, energy: float, alpha: float = 1.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color, alpha)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	material.roughness = 0.3
	if alpha < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _make_visual(kind: String, color: Color) -> Node3D:
	_ensure_meshes()
	var node := Node3D.new()
	node.name = {"homing": "StarRocket", "bouncing": "SparkBall", "trap": "BubbleTrap"}.get(kind, "Item")
	add_child(node)
	match kind:
		"homing":
			var body := MeshInstance3D.new()
			body.mesh = _rocket_mesh
			body.rotation.x = -PI / 2
			body.material_override = _glow(color, 1.4)
			node.add_child(body)
			var trail := MeshInstance3D.new()
			trail.mesh = _trail_mesh
			trail.position.z = 0.75
			trail.rotation.x = PI / 2
			trail.material_override = _glow(Color("fff2b0"), 2.2, 0.55)
			trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.add_child(trail)
		"bouncing":
			var ball := MeshInstance3D.new()
			ball.mesh = _ball_mesh
			ball.material_override = _glow(color, 1.8)
			node.add_child(ball)
		"trap":
			var bubble := MeshInstance3D.new()
			bubble.mesh = _bubble_mesh
			bubble.material_override = _glow(color, 0.6, 0.42)
			bubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.add_child(bubble)
			var core := MeshInstance3D.new()
			core.mesh = _ball_mesh
			core.scale = Vector3.ONE * 0.35
			core.material_override = _glow(Color.WHITE, 1.2)
			node.add_child(core)
	return node


static func _ensure_meshes() -> void:
	if _rocket_mesh != null:
		return
	var rocket := CapsuleMesh.new()
	rocket.radius = 0.22
	rocket.height = 1.15
	rocket.radial_segments = 12
	rocket.rings = 4
	_rocket_mesh = rocket
	var trail := CylinderMesh.new()
	trail.top_radius = 0.16
	trail.bottom_radius = 0.0
	trail.height = 0.9
	trail.radial_segments = 10
	_trail_mesh = trail
	var ball := SphereMesh.new()
	ball.radius = 0.42
	ball.height = 0.84
	ball.radial_segments = 16
	ball.rings = 8
	_ball_mesh = ball
	var bubble := SphereMesh.new()
	bubble.radius = 0.85
	bubble.height = 1.7
	bubble.radial_segments = 20
	bubble.rings = 10
	_bubble_mesh = bubble
