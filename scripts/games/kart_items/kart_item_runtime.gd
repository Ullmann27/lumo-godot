extends Node3D
## Live item objects on the track: homing Sternraketen (fired in pairs), bouncing
## Funkenkugeln and dropped Blubberblasen. Simulated in track space (race progress +
## lateral offset), so it is cheap on mid-range phones and independent of physics bodies.
## Hits are child-friendly: the target only spins once and keeps driving.
## Visuals: Blender rocket prop + flame + one smoke/spark trail per rocket; a rocket
## that meets a shield visibly bounces off before it pops into sparkles.

const CATALOG = preload("res://scripts/games/kart_items/kart_item_catalog.gd")
const PODS = preload("res://scripts/games/kart_items/kart_rocket_pods.gd")
const PLAYER_KEY: int = -1
const MAX_PROJECTILES: int = 12
const MAX_TRAPS: int = 10
const MAX_DEBRIS: int = 6
const HIT_PROGRESS: float = 1.5
const HIT_LATERAL: float = 1.3
const OWNER_GRACE_SECONDS: float = 0.6
const HOMING_LOCK_DISTANCE: float = 28.0
const HOMING_LATERAL_SPEED: float = 7.0
## Launch: the rocket leaves its pod nozzle and merges into the track path.
const LAUNCH_BLEND_SECONDS: float = 0.28
const SPIRAL_RADIUS: float = 0.32
const SPIRAL_RATE: float = 8.5
## Flying rockets are shown larger than the pod rockets so they stay readable at range.
const ROCKET_SCALE: float = 2.1
## The child's rockets inherit the kart's speed and fly this much faster (m/s), so they
## visibly pull away and reach a rival 30 m ahead in about 1.4 s (eye can follow).
## Before, they flew a fixed 33 m/s – slower than the kart at race pace (~34 m/s).
const PLAYER_CLOSING_SPEED: float = 21.0
## Visual arc of a homing rocket over its flight (m above the corkscrew line).
const FLIGHT_ARC: float = 0.85

var track_length: float = 1.0
var wall_lateral: float = 4.6
var placer: Callable
var reduced_motion: bool = false
## "low" | "medium" | "high": trail particle budget.
var quality: String = "medium"
var projectiles: Array[Dictionary] = []
var traps: Array[Dictionary] = []
## Bounced rockets and fading trails (world-space, purely visual).
var debris: Array[Dictionary] = []
var stats := {"fired": 0, "dropped": 0, "hits": 0, "blocked": 0, "expired": 0, "intercepted": 0, "pairs": 0}
## Small presentation cues for the race (wall bounce of a Funkenkugel, a Blubberblase
## that times out). Purely visual/sound; consumed with take_feedback().
var feedback: Array[Dictionary] = []
var _next_pair: int = 1
var _meshes: Dictionary = {}
var _materials: Dictionary = {}


func setup(length: float, wall: float, frame_at: Callable) -> void:
	track_length = maxf(1.0, length)
	wall_lateral = wall
	placer = frame_at


func clear() -> void:
	for entry in projectiles + traps + debris:
		if is_instance_valid(entry.node):
			entry.node.queue_free()
		if entry.has("trail") and is_instance_valid(entry.trail):
			entry.trail.queue_free()
	projectiles.clear()
	traps.clear()
	debris.clear()
	feedback.clear()


func active_count() -> int:
	return projectiles.size() + traps.size()


func wrapped(delta_progress: float) -> float:
	return fposmod(delta_progress + track_length * 0.5, track_length) - track_length * 0.5


func fire_homing(item: String, owner: int, progress: float, lateral: float, target: int) -> bool:
	return _launch(item, "homing", owner, progress + 1.8, lateral, 0.0, target)


## Two rockets at once (left + right pod). `launches` are the pod nozzle transforms;
## both chase the same target, and the pair counts as ONE hit.
func fire_pair(
	item: String, owner: int, progress: float, lateral: float, target: int, launches: Array = [],
	carrier_speed: float = 0.0
) -> bool:
	if projectiles.size() + 2 > MAX_PROJECTILES:
		return false
	var pair: int = _next_pair
	_next_pair += 1
	for side_index in range(2):
		var side: float = -1.0 if side_index == 0 else 1.0
		var launch: Variant = launches[side_index] if side_index < launches.size() else null
		_launch(item, "homing", owner, progress + 1.2, lateral + side * 0.55, 0.0, target, pair, side, launch)
		if owner == PLAYER_KEY and carrier_speed > 0.0:
			var rocket: Dictionary = projectiles[-1]
			rocket.speed = maxf(float(rocket.speed), carrier_speed + PLAYER_CLOSING_SPEED)
	stats.pairs += 1
	return true


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
		# Traps are single objects; rockets fly in pairs (pair > 0).
		"pair": 0,
	}
	traps.append(entry)
	stats.dropped += 1
	_place(entry)
	return true


func _launch(
	item: String, kind: String, owner: int, progress: float, lateral: float, lateral_velocity: float,
	target: int, pair: int = 0, side: float = 0.0, launch: Variant = null
) -> bool:
	if projectiles.size() >= MAX_PROJECTILES:
		return false
	var node := _make_visual(kind, CATALOG.color(item))
	var entry := {
		"item": item, "kind": kind, "owner": owner, "progress": progress, "lateral": lateral,
		"lateral_velocity": lateral_velocity, "target": target, "age": 0.0, "pair": pair, "side": side,
		"phase": randf() * TAU if pair == 0 else (0.0 if side < 0.0 else PI),
		"speed": CATALOG.number(item, "speed", 36.0), "life": CATALOG.number(item, "life", 4.5), "node": node,
		"launch": launch, "previous": Vector3.INF,
	}
	if kind == "homing":
		entry.trail = _make_trail(node)
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


## World position of the nearest rocket chasing `key` (for the HUD warning).
func incoming_position(key: int) -> Variant:
	for entry in projectiles:
		if entry.kind == "homing" and int(entry.target) == key and is_instance_valid(entry.node) and entry.node.is_inside_tree():
			return entry.node.global_position
	return null


## Advance every object. `racers`: [{key, progress, lateral, protected}] with
## cumulative race progress. Returns hit/blocked events for the race to apply.
func step(delta: float, racers: Array) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var keep: Array[Dictionary] = []
	var resolved_pairs: Dictionary = {}
	for entry in projectiles:
		entry.age += delta
		if int(entry.pair) > 0 and resolved_pairs.has(int(entry.pair)):
			# The partner already hit (or bounced): this one bursts beside it.
			var partner_event: Dictionary = resolved_pairs[int(entry.pair)]
			if str(partner_event.type) == "blocked":
				_deflect(entry, partner_event)
			else:
				_retire(entry, true)
			continue
		var target_racer: Dictionary = _racer(racers, int(entry.target))
		if entry.kind == "homing" and not target_racer.is_empty():
			var to_target: float = float(target_racer.progress) - float(entry.progress)
			if not entry.has("gap0"):
				entry.gap0 = maxf(1.0, to_target)
			entry.to_target = to_target
			if to_target < -HIT_PROGRESS * 2.0:
				# The target dropped behind the rocket: it fizzles harmlessly.
				entry.life = 0.0
			elif to_target < HOMING_LOCK_DISTANCE:
				var aim: float = float(target_racer.lateral) + float(entry.side) * 0.35 * clampf(to_target / HOMING_LOCK_DISTANCE, 0.0, 1.0)
				entry.lateral = move_toward(float(entry.lateral), aim, HOMING_LATERAL_SPEED * delta)
		elif entry.kind == "bouncing":
			entry.lateral = float(entry.lateral) + float(entry.lateral_velocity) * delta
			if absf(float(entry.lateral)) > wall_lateral:
				entry.lateral = signf(entry.lateral) * (wall_lateral * 2.0 - absf(entry.lateral))
				entry.lateral_velocity = -float(entry.lateral_velocity)
				_cue("wall_bounce", entry)
		entry.progress = float(entry.progress) + float(entry.speed) * delta
		var catcher: Dictionary = _trap_in_path(entry)
		if not catcher.is_empty():
			# A Blubberblase swallows the projectile: both pop harmlessly.
			stats.intercepted = int(stats.get("intercepted", 0)) + 1
			var event := {
				"type": "intercepted", "target": int(catcher.owner), "source": int(entry.owner),
				"item": str(entry.item), "spin": 0.0, "pair": int(entry.pair),
				"position": _node_position(catcher.node),
			}
			events.append(event)
			if int(entry.pair) > 0:
				resolved_pairs[int(entry.pair)] = event
			traps.erase(catcher)
			_retire(catcher)
			_retire(entry, true)
			continue
		var hit: Dictionary = _first_contact(entry, racers)
		if not hit.is_empty():
			var event: Dictionary = _resolve(entry, hit)
			events.append(event)
			if int(entry.pair) > 0:
				resolved_pairs[int(entry.pair)] = event
			if str(event.type) == "blocked" and entry.kind == "homing":
				_deflect(entry, event)
			else:
				_retire(entry, true)
			continue
		if float(entry.age) >= float(entry.life):
			stats.expired += 1
			if entry.kind == "homing":
				events.append({
					"type": "expired", "target": int(entry.target), "source": int(entry.owner),
					"item": str(entry.item), "spin": 0.0, "pair": int(entry.pair), "position": _node_position(entry.node),
				})
			_retire(entry, true)
			continue
		_place(entry)
		keep.append(entry)
	# A partner that resolved after its twin was already kept this frame bursts now.
	var still_flying: Array[Dictionary] = []
	for entry in keep:
		if int(entry.pair) > 0 and resolved_pairs.has(int(entry.pair)):
			if str(resolved_pairs[int(entry.pair)].type) == "blocked":
				_deflect(entry, resolved_pairs[int(entry.pair)])
			else:
				_retire(entry, true)
		else:
			still_flying.append(entry)
	projectiles = still_flying
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
			_cue("trap_pop", entry)
			_retire(entry)
			continue
		_place(entry)
		keep_traps.append(entry)
	traps = keep_traps
	_advance_debris(delta)
	return events


func _cue(kind: String, entry: Dictionary) -> void:
	if feedback.size() < 8:
		feedback.append({"kind": kind, "owner": int(entry.owner), "position": _node_position(entry.node)})


func take_feedback() -> Array[Dictionary]:
	var result: Array[Dictionary] = feedback.duplicate()
	feedback.clear()
	return result


func _node_position(node: Variant) -> Vector3:
	if is_instance_valid(node) and (node as Node3D).is_inside_tree():
		return (node as Node3D).global_position
	return Vector3.ZERO


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
	return {
		"type": "blocked" if blocked else "hit", "target": int(racer.key), "source": int(entry.owner),
		"item": str(entry.item), "spin": CATALOG.number(str(entry.item), "spin_seconds", 1.0),
		"position": _node_position(entry.node), "pair": int(entry.get("pair", 0)),
	}


## The trail keeps smoking for a moment after its rocket is gone.
func _release_trail(entry: Dictionary) -> void:
	if not entry.has("trail") or not is_instance_valid(entry.trail):
		return
	var trail: CPUParticles3D = entry.trail
	var at: Transform3D = trail.global_transform if trail.is_inside_tree() else Transform3D()
	trail.get_parent().remove_child(trail)
	add_child(trail)
	trail.global_transform = at
	trail.emitting = false
	debris.append({"node": null, "trail": trail, "age": 0.0, "life": trail.lifetime + 0.1, "velocity": Vector3.ZERO, "spin": 0.0})
	entry.erase("trail")


func _retire(entry: Dictionary, keep_trail: bool = false) -> void:
	if keep_trail:
		_release_trail(entry)
	if is_instance_valid(entry.node):
		entry.node.queue_free()


## A rocket that met a shield flips away, spinning, and pops a moment later.
func _deflect(entry: Dictionary, event: Dictionary) -> void:
	_release_trail(entry)
	if not is_instance_valid(entry.node) or debris.size() >= MAX_DEBRIS:
		_retire(entry)
		return
	var node: Node3D = entry.node
	# Engine out: the bounced rocket tumbles away without fire or glow.
	for part in ["Exhaust", "NozzleGlow"]:
		var piece := node.get_node_or_null(part) as Node3D
		if piece != null:
			piece.visible = false
	var away: Vector3 = node.global_basis.z.normalized()
	var side: Vector3 = node.global_basis.x.normalized() * (1.0 if float(entry.side) >= 0.0 else -1.0)
	var velocity: Vector3 = (away * 9.0 + side * 6.0 + Vector3.UP * 7.5) * (0.4 if reduced_motion else 1.0)
	debris.append({"node": node, "age": 0.0, "life": 0.62, "velocity": velocity, "spin": 13.0, "deflected": true})
	event["deflect_from"] = node.global_position


func _advance_debris(delta: float) -> void:
	var keep: Array[Dictionary] = []
	for entry in debris:
		entry.age += delta
		var node: Variant = entry.node
		if is_instance_valid(node):
			entry.velocity += Vector3.DOWN * 14.0 * delta
			(node as Node3D).global_position += entry.velocity * delta
			if not reduced_motion:
				(node as Node3D).rotate_object_local(Vector3.RIGHT, float(entry.spin) * delta)
				(node as Node3D).rotate_object_local(Vector3.FORWARD, float(entry.spin) * 0.6 * delta)
		if float(entry.age) >= float(entry.life):
			if is_instance_valid(node):
				(node as Node3D).queue_free()
			if entry.has("trail") and is_instance_valid(entry.trail):
				entry.trail.queue_free()
			continue
		keep.append(entry)
	debris = keep


## Positions of rockets that just bounced and should pop now (consumed by the race FX).
func popped_debris() -> Array[Vector3]:
	var result: Array[Vector3] = []
	for entry in debris:
		if bool(entry.get("deflected", false)) and not bool(entry.get("popped", false)) and float(entry.age) + 0.05 >= float(entry.life):
			entry.popped = true
			if is_instance_valid(entry.node):
				result.append((entry.node as Node3D).global_position)
	return result


func _place(entry: Dictionary) -> void:
	if not placer.is_valid() or not is_instance_valid(entry.node):
		return
	var frame: Transform3D = placer.call(fposmod(float(entry.progress), track_length), float(entry.lateral))
	var lift: float = 0.75 if entry.kind != "trap" else 0.85
	var age: float = float(entry.age)
	var bob: float = 0.0 if reduced_motion else sin(age * 5.0) * 0.12
	var node: Node3D = entry.node
	if entry.kind == "homing":
		# Gentle corkscrew around the track line; the pair spirals in opposite phase.
		var swirl: float = 0.0 if reduced_motion else SPIRAL_RADIUS * clampf(age * 3.0, 0.0, 1.0)
		var angle: float = age * SPIRAL_RATE + float(entry.phase)
		# A flat arc over the whole flight: up from the pod, down onto the target.
		var arc: float = 0.0
		if entry.has("gap0"):
			var flown: float = 1.0 - clampf(float(entry.get("to_target", 0.0)) / float(entry.gap0), 0.0, 1.0)
			arc = FLIGHT_ARC * (0.5 if reduced_motion else 1.0) * sin(PI * flown)
		var target_position: Vector3 = (
			frame.origin + frame.basis.y * (0.95 + arc + sin(angle) * swirl * 0.7)
			+ frame.basis.x * cos(angle) * swirl
		)
		var launch: Variant = entry.get("launch")
		if launch is Transform3D and age < LAUNCH_BLEND_SECONDS:
			# Pod nozzles are world transforms; the track frame is local to this runtime.
			var start: Vector3 = (global_transform.affine_inverse() * (launch as Transform3D)).origin if is_inside_tree() else (launch as Transform3D).origin
			var t: float = smoothstep(0.0, 1.0, age / LAUNCH_BLEND_SECONDS)
			target_position = start.lerp(target_position, t)
		var previous: Vector3 = entry.previous
		var heading: Vector3 = -frame.basis.z
		if previous != Vector3.INF and previous.distance_squared_to(target_position) > 0.0004:
			heading = (target_position - previous).normalized()
		entry.previous = target_position
		var up: Vector3 = frame.basis.y if absf(heading.dot(frame.basis.y)) < 0.95 else frame.basis.x
		node.transform = Transform3D(Basis.looking_at(heading, up), target_position)
		if not reduced_motion:
			node.rotate_object_local(Vector3.FORWARD, age * 6.0 * (1.0 if float(entry.side) >= 0.0 else -1.0))
		return
	# The track frame is in race-root space, like this runtime node.
	node.transform = Transform3D(frame.basis, frame.origin + frame.basis.y * (lift + bob))
	if entry.kind == "bouncing" and not reduced_motion:
		node.rotate_object_local(Vector3.RIGHT, -age * 14.0)


func _glow(color: Color, energy: float, alpha: float = 1.0) -> StandardMaterial3D:
	var key: String = "%s/%.2f/%.2f" % [color.to_html(), energy, alpha]
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color, alpha)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	material.roughness = 0.3
	if alpha < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_materials[key] = material
	return material


func _make_trail(rocket: Node3D) -> CPUParticles3D:
	var trail := CPUParticles3D.new()
	trail.name = "SmokeSparkTrail"
	var budget: Dictionary = {"low": 12, "medium": 26, "high": 40}
	trail.amount = int(budget.get(quality, 26)) / (2 if reduced_motion else 1)
	trail.lifetime = 0.8
	trail.local_coords = false
	trail.emitting = true
	trail.direction = Vector3(0, 0, 1)
	trail.spread = 22.0
	trail.initial_velocity_min = 0.6
	trail.initial_velocity_max = 2.2
	trail.gravity = Vector3(0, 0.8, 0)
	trail.damping_min = 1.0
	trail.damping_max = 2.0
	trail.scale_amount_min = 0.55
	trail.scale_amount_max = 1.25
	var size_curve := Curve.new()
	size_curve.add_point(Vector2(0.0, 0.35))
	size_curve.add_point(Vector2(0.35, 1.0))
	size_curve.add_point(Vector2(1.0, 1.6))
	trail.scale_amount_curve = size_curve
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.92, 0.55, 0.95))
	ramp.add_point(0.18, Color(1.0, 0.55, 0.30, 0.75))
	ramp.add_point(0.45, Color(0.95, 0.90, 1.0, 0.45))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.85, 0.86, 1.0, 0.0))
	trail.color_ramp = ramp
	trail.mesh = _mesh("puff")
	trail.position = Vector3(0, 0, PODS.NOZZLE_Z * ROCKET_SCALE + 0.15)
	rocket.add_child(trail)
	return trail


func _mesh(kind: String) -> Mesh:
	if _meshes.has(kind):
		return _meshes[kind]
	var mesh: Mesh
	match kind:
		"puff":
			var quad: ArrayMesh = preload("res://scripts/systems/particle_quad.gd").make(Vector2(0.55, 0.55))
			var material := StandardMaterial3D.new()
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.vertex_color_use_as_albedo = true
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
			material.albedo_texture = _soft_dot()
			quad.surface_set_material(0, material)
			mesh = quad
		"ball":
			var ball := SphereMesh.new()
			ball.radius = 0.42
			ball.height = 0.84
			ball.radial_segments = 16
			ball.rings = 8
			mesh = ball
		"bubble":
			var bubble := SphereMesh.new()
			bubble.radius = 0.85
			bubble.height = 1.7
			bubble.radial_segments = 20
			bubble.rings = 10
			mesh = bubble
		"glow":
			var sprite := QuadMesh.new()
			sprite.size = Vector2(1.05, 1.05)
			var glow_material := StandardMaterial3D.new()
			glow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			glow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			glow_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			glow_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			glow_material.albedo_color = Color(1.0, 0.78, 0.4, 0.95)
			glow_material.albedo_texture = _soft_dot()
			glow_material.no_depth_test = false
			sprite.material = glow_material
			mesh = sprite
		"rocket_fallback":
			var capsule := CapsuleMesh.new()
			capsule.radius = 0.09
			capsule.height = 0.66
			mesh = capsule
		"flame":
			var cone := CylinderMesh.new()
			cone.top_radius = 0.07
			cone.bottom_radius = 0.0
			cone.height = 0.7
			cone.radial_segments = 10
			cone.rings = 2
			cone.cap_top = false
			cone.cap_bottom = false
			mesh = cone
	_meshes[kind] = mesh
	return mesh


func _soft_dot() -> Texture2D:
	if _materials.has("soft_dot"):
		return _materials["soft_dot"]
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = 32
	texture.height = 32
	_materials["soft_dot"] = texture
	return texture


func _make_visual(kind: String, color: Color) -> Node3D:
	var node := Node3D.new()
	node.name = {"homing": "StarRocket", "bouncing": "SparkBall", "trap": "BubbleTrap"}.get(kind, "Item")
	add_child(node)
	match kind:
		"homing":
			if not _materials.has("prop"):
				_materials["prop"] = PODS.prop_material()
				_materials["flame"] = PODS.flame_material()
			var body: MeshInstance3D = null
			if PODS.load_scenes():
				body = PODS.instance_prop(PODS._rocket_scene, _materials["prop"])
			if body == null:
				body = MeshInstance3D.new()
				body.mesh = _mesh("rocket_fallback")
				body.rotation.x = -PI / 2
				body.material_override = _glow(color, 1.4)
			body.scale = Vector3.ONE * ROCKET_SCALE
			node.add_child(body)
			var flame := MeshInstance3D.new()
			flame.name = "Exhaust"
			flame.mesh = _mesh("flame")
			flame.material_override = _materials["flame"]
			flame.rotation.x = -PI * 0.5
			flame.scale = Vector3(1.5, 1.4, 1.5)
			flame.position.z = PODS.NOZZLE_Z * ROCKET_SCALE + 0.35 * flame.scale.y
			flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.add_child(flame)
			# A bright billboard glow at the nozzle keeps the rocket readable far away.
			var glow := MeshInstance3D.new()
			glow.name = "NozzleGlow"
			glow.mesh = _mesh("glow")
			glow.position.z = PODS.NOZZLE_Z * ROCKET_SCALE + 0.1
			glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.add_child(glow)
		"bouncing":
			var ball := MeshInstance3D.new()
			ball.mesh = _mesh("ball")
			ball.material_override = _glow(color, 1.8)
			node.add_child(ball)
		"trap":
			var bubble := MeshInstance3D.new()
			bubble.mesh = _mesh("bubble")
			bubble.material_override = _glow(color, 0.6, 0.42)
			bubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.add_child(bubble)
			var core := MeshInstance3D.new()
			core.mesh = _mesh("ball")
			core.scale = Vector3.ONE * 0.35
			core.material_override = _glow(Color.WHITE, 1.2)
			node.add_child(core)
	return node
