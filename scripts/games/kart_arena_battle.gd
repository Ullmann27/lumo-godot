extends Node3D
## Six free-driving karts, two kinds of recharge bay and one point per real contact.

const POD = preload("res://scripts/games/kart_items/kart_rocket_pods.gd")
const FX = preload("res://scripts/games/kart_items/ext/kart_item_ext_fx.gd")
const ROCKET := "star_rocket"
const METEOR := "fire_meteor"
const SECONDS := 60.0
const SAFE_SECONDS := 3.0
const IMPACT_RADIUS := 5.2
var shots: Array[Dictionary] = []
var ring_mesh := TorusMesh.new()
var glow := StandardMaterial3D.new()
var ice := StandardMaterial3D.new()
var rocket_scene: PackedScene
var rocket_material: Material
var meteor_mesh: Mesh
var markers: Array[MeshInstance3D] = []
var aim_marker: MeshInstance3D


func build(game) -> void:
	name = "Trefferjagd"
	rocket_scene = load(POD.ROCKET_SCENE_PATH)
	rocket_material = POD.prop_material()
	meteor_mesh = FX.crystal_mesh(0.72, 1.1)
	glow.albedo_color = Color("ff8c38")
	glow.emission_enabled = true
	glow.emission = Color("ff7025")
	ice.albedo_color = Color("69ddff")
	ice.emission_enabled = true
	ice.emission = Color("28a9db")
	ring_mesh.inner_radius = 0.91
	ring_mesh.outer_radius = 1.0
	ring_mesh.rings = 32
	ring_mesh.ring_segments = 6
	aim_marker = _ring(Vector3.ZERO, 1.65, glow)
	aim_marker.hide()
	for i in 6:
		var outward := Vector3(sin(TAU * i / 6 + 0.38), 0, cos(TAU * i / 6 + 0.38))
		var cover := outward * 19.5
		game.arena.obstacles.append(cover)
		game.arena._cylinder(cover + Vector3.UP * 1.1, 2.2, 2.2, Color("245a78"))
		game.arena._cylinder(cover + Vector3.UP * 2.22, 2.25, 0.10, Color("86e2e6"))
		var at := outward * 24.0
		var kind := ROCKET if i % 2 == 0 else METEOR
		var token := _model(kind)
		add_child(token)
		token.position = at + Vector3.UP * 0.95
		token.rotation.x = -0.35
		game.gems.append(token)
		game.arena_pickup_timers.append(0.0)
		_ring(at, 2.5, ice if kind == ROCKET else glow)
		markers.append(_ring(Vector3.ZERO, 1.8, ice))


func start(game) -> void:
	game.item = ROCKET
	game.item_charges = 1
	for i in game.opponents.size():
		game.opponent_items[i] = ROCKET if i % 2 == 0 else METEOR
		game.opponent_item_cooldowns[i] = 2.0 + i * 0.34


func _ring(at: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = ring_mesh
	node.material_override = material
	node.scale = Vector3(radius, 0.35, radius)
	node.position = at + Vector3.UP * 0.07
	add_child(node)
	return node


func _model(kind: String) -> Node3D:
	if kind == ROCKET:
		var rocket := POD.instance_prop(rocket_scene, rocket_material)
		if rocket != null:
			rocket.scale = Vector3.ONE * 2.4
			return rocket
	var node := MeshInstance3D.new()
	node.mesh = meteor_mesh
	node.material_override = glow
	return node


func _kart(game, id: int) -> Node3D:
	return game.player if id == 0 else game.opponents[id - 1]


func _shield(game, id: int) -> float:
	return game.shield_time if id == 0 else game.opponent_shield_times[id - 1]


func _target(game, owner: int) -> int:
	var best := -1
	var best_distance := INF
	for id in range(6):
		if id == owner or _shield(game, id) > 0:
			continue
		var driver := _kart(game, owner)
		var offset := _kart(game, id).position - driver.position
		var d := offset.length() + 15.0 * (1.0 + driver.basis.z.dot(offset.normalized()))
		if d < best_distance:
			best_distance = d
			best = id
	return best


func fire(game, owner: int, kind: String) -> bool:
	var target := _target(game, owner)
	if target < 0 or kind not in [ROCKET, METEOR]:
		return false
	var from := _kart(game, owner).position + Vector3.UP * 0.8
	var aim := _kart(game, target).position + Vector3.UP * 0.8
	var shot := {"owner": owner, "target": target, "kind": kind, "at": from, "aim": aim, "age": 0.0,
		"direction": from.direction_to(aim)}
	_spawn_shot(shot)
	game._sound_effect("meteor_launch" if kind == METEOR else "rocket_launch")
	if owner == 0:
		game._consume_item()
		game.message.text = "Meteor im Zielkreis!" if kind == METEOR else "Sternrakete unterwegs!"
	else:
		game.opponent_items[owner - 1] = ""
		if target == 0:
			game.message.text = "Raus aus dem orangenen Kreis!" if kind == METEOR else "Sternrakete! Nutze die Deckung."
	return true


func _spawn_shot(data: Dictionary) -> void:
	var model := _model(data.kind)
	add_child(model)
	model.position = data.at
	data["node"] = model
	if data.kind == METEOR:
		data["warning"] = _ring(Vector3(data.aim.x, 0, data.aim.z), IMPACT_RADIUS, glow)
	shots.append(data)


func tick(game, dt: float) -> void:
	for i in game.gems.size():
		game.arena_pickup_timers[i] = maxf(0, game.arena_pickup_timers[i] - dt)
		game.gems[i].visible = game.arena_pickup_timers[i] <= 0
		if game.gems[i].visible and game.item.is_empty() and game.player.position.distance_to(game.gems[i].position) < 3.2:
			_load_bay(game, 0, i)
	for i in game.opponents.size():
		game.opponent_shield_times[i] = maxf(0, game.opponent_shield_times[i] - dt)
		game.opponent_item_cooldowns[i] = maxf(0, game.opponent_item_cooldowns[i] - dt)
		_drive_rival(game, i, dt)
	for i in range(shots.size() - 1, -1, -1):
		if _advance_shot(game, shots[i], dt):
			var shot := shots[i]
			shot.node.queue_free()
			if shot.has("warning"):
				shot.warning.queue_free()
			shots.remove_at(i)
	var aimed := _target(game, 0) if not game.item.is_empty() else -1
	aim_marker.visible = aimed >= 0
	if aimed >= 0:
		aim_marker.position = _kart(game, aimed).position + Vector3.UP * 0.15
	for id in markers.size():
		markers[id].position = _kart(game, id).position + Vector3.UP * 0.07
		markers[id].visible = _shield(game, id) > 0


func _load_bay(game, id: int, bay: int) -> void:
	var kind := ROCKET if bay % 2 == 0 else METEOR
	if id == 0:
		game.item = kind
		game.item_charges = 1
		game._sound_effect("item")
	else:
		game.opponent_items[id-1] = kind
		game.opponent_item_cooldowns[id-1] = 1.15
	game.arena_pickup_timers[bay] = 3.0
	game.gems[bay].hide()


func _drive_rival(game, i: int, dt: float) -> void:
	var rival := _kart(game, i + 1)
	var bay := 0
	var best := INF
	for j in game.gems.size():
		var distance := rival.position.distance_to(game.gems[j].position) + float(game.arena_pickup_timers[j]) * 8.0
		if distance < best:
			best = distance
			bay = j
	var aim: Vector3 = game.gems[bay].position
	var held: String = game.opponent_items[i]
	if not held.is_empty():
		var target := _target(game, i + 1)
		if target >= 0:
			aim = _kart(game, target).position
			if game.opponent_item_cooldowns[i] <= 0 and rival.position.distance_to(aim) < 32:
				fire(game, i + 1, held)
	elif best < 3.2 and game.arena_pickup_timers[bay] <= 0:
		_load_bay(game, i + 1, bay)
	for s in shots:
		if s.kind == METEOR and rival.position.distance_to(s.aim) < IMPACT_RADIUS + 2 and i % 3 != 2:
			var away: Vector3 = rival.position - s.aim
			aim = rival.position + (away + Vector3(0.6, 0, 0.7)).normalized() * 10.0
	for cover: Vector3 in game.arena.obstacles:
		var to := Vector3(aim.x - rival.position.x, 0, aim.z - rival.position.z).normalized()
		if rival.position.distance_to(cover) < 7.5 and (cover - rival.position).dot(to) > 0:
			var side := Vector3(to.z, 0, -to.x)
			aim = cover + side * (4.4 if (rival.position - cover).dot(side) >= 0 else -4.4)
			break
	var direction := aim - rival.position
	var heading := rotate_toward(float(game.opponent_headings[i]), atan2(-direction.x, -direction.z), dt * 2.5)
	var pace := (8.8 + i * 0.26) * float(game.CATALOG.entry(game.CATALOG.DIFFICULTIES, game.difficulty).rival)
	rival.position += Vector3(-sin(heading), 0, -cos(heading)) * pace * dt
	for cover: Vector3 in game.arena.obstacles:
		var away := Vector3(rival.position.x - cover.x, 0, rival.position.z - cover.z)
		if away.length_squared() < 9.0:
			rival.position = cover + away.normalized() * 3.05
	rival.position = Vector3(rival.position.x, 0, rival.position.z).limit_length(37.5) + Vector3.UP * 0.035
	game.opponent_headings[i] = heading
	rival.rotation.y = heading
	rival.set_motion(pace, 0.0, false, false)


func _advance_shot(game, s: Dictionary, dt: float) -> bool:
	s.age += dt
	if s.kind == METEOR:
		s.node.position = s.aim + Vector3.UP * maxf(0, 11.0 * (1.0 - float(s.age) / 1.25))
		if s.age < 1.25:
			return false
		game._fx("meteor_hit", s.aim)
		for id in 6:
			if id != s.owner and _kart(game, id).position.distance_to(s.aim) < IMPACT_RADIUS:
				_hit(game, s.owner, id)
		return true
	var from: Vector3 = s.at
	var toward := from.direction_to(_kart(game, s.target).position + Vector3.UP * 0.8)
	var previous: Vector3 = s.direction
	s.direction = previous.slerp(toward, minf(dt * 1.6, 1.0)).normalized() if not toward.is_zero_approx() else previous
	var end: Vector3 = from + s.direction * 29.0 * dt
	for cover: Vector3 in game.arena.obstacles:
		if Geometry3D.get_closest_point_to_segment(cover + Vector3.UP * 0.8, from, end).distance_to(cover + Vector3.UP * 0.8) < 2.3:
			game._fx("rocket_hit", end)
			return true
	for id in 6:
		if id == s.owner:
			continue
		var body := _kart(game, id).position + Vector3.UP * 0.8
		if Geometry3D.get_closest_point_to_segment(body, from, end).distance_to(body) < 1.7:
			_hit(game, s.owner, id)
			return true
	s.at = end
	s.node.position = end
	if from.distance_squared_to(end) > 0.0001:
		s.node.look_at(end + s.direction)
	return s.age >= 2.8 or end.length() >= 40.0


func _hit(game, shooter: int, victim: int) -> void:
	if _shield(game, victim) > 0.0:
		return
	if shooter == 0:
		game.arena_scores += 1
		game.message.text = "Treffer! +1 Punkt"
	else:
		game.opponent_scores[shooter-1] += 1
	var kart := _kart(game, victim)
	game._fx("rocket_hit", kart.position + Vector3.UP * 0.8)
	var safest := Vector3.ZERO
	var margin := -1.0
	for n in 12:
		var p := Vector3(cos(TAU*n/12), 0.035, sin(TAU*n/12))*31.0
		var nearest := INF
		for id in 6:
			if id != victim:
				nearest = minf(nearest, p.distance_squared_to(_kart(game, id).position))
		if nearest > margin:
			margin = nearest
			safest = p
	kart.position = safest
	var heading := atan2(safest.x, safest.z)
	kart.rotation.y = heading
	if victim == 0:
		game.speed = 0.0
		game.physical_velocity = Vector3.ZERO
		game.player_heading = heading
		game.shield_time = SAFE_SECONDS
		game.message.text = "Weiter geht’s! Drei Sekunden Schutz."
	else:
		game.opponent_headings[victim-1] = heading
		game.opponent_shield_times[victim-1] = SAFE_SECONDS


func save_shots() -> Array:
	var result := []
	for s in shots:
		var copy := s.duplicate()
		copy.erase("node")
		copy.erase("warning")
		result.append(copy)
	return result


func restore_shots(saved: Array) -> void:
	for data in saved:
		if data is Dictionary and data.get("kind") in [ROCKET, METEOR] and int(data.get("owner", -1)) in range(6) and int(data.get("target", -1)) in range(6) and data.has_all(["at","aim","age","direction"]):
			_spawn_shot(data.duplicate())
