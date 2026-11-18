extends Node3D
## Sichtbare Seite von Teil 3: Mauerring, Türme, Tor mit Zugbrücke, Graben und
## Netzfallen um das Dorf des Kindes, Wachen am Tor, Krummzahns Räuberlager und
## Funkels Höhle auf der großen Karte, Baugerüste an beschädigten Gebäuden und
## die kurze Angriffsszene (Angreifer kommen, purzeln und flüchten – oder
## schleppen Säcke weg). Reine Darstellung: liest build_village_raids.gd.
## Alle Bauteile kommen aus Blender (tools/lumo_village_art/build_defense_models.py),
## Wiederholtes (Mauer, Graben, Fallen) als MultiMesh – ein Draw-Call je Art.
signal scene_finished
const RAIDS = preload("res://scripts/creative/build_village_raids.gd")
const SCHEDULE = preload("res://scripts/creative/build_village_schedule.gd")
const REGION = preload("res://scripts/creative/build_settlement_region.gd")
const ART = preload("res://scripts/creative/build_village_art.gd")
const TERRAIN = preload("res://scripts/creative/build_village_terrain.gd")
const NEIGHBORS = preload("res://scripts/creative/build_village_neighbors.gd")
const SOLDIERS = preload("res://scripts/creative/build_village_soldiers.gd")
const SEGMENT := 5.0
const SCENE_SECONDS := 9.0
const MAX_GUARDS_SHOWN := 8
var model
var raids
var ring: Node3D
var damage_root: Node3D
var camp: Node3D
var nest: Node3D
var dragon_home: Node3D
var actors: Array[Dictionary] = []
var scene_time := -1.0
var scene_result: Dictionary = {}
var gate_position := Vector3.ZERO
var gate_bridge: Node3D
## Wachen am Tor: Blender-Menschen als eine Formation (Bewegung im Shader).
var gate_guards: MultiMeshInstance3D
var _key := ""
var clock := 0.0
var shadows := true


func setup(village_model, raid_rules, quality := "medium") -> void:
	model = village_model
	raids = raid_rules
	shadows = quality == "high"
	name = "VillageDefense"
	ring = Node3D.new()
	ring.name = "DefenseRing"
	add_child(ring)
	damage_root = Node3D.new()
	damage_root.name = "DamagedBuildings"
	add_child(damage_root)
	_build_enemy_homes()
	sync()


static func ground(x: float, z: float) -> Vector3:
	return Vector3(x, TERRAIN.height(x, z), z)


func center() -> Vector3:
	return Vector3(-REGION.TOWN_CENTER, 0.0, 0.0)


func half_extent() -> float:
	return REGION.extent_for_plots(int(model._player.plots)) + 4.5


func _label(text: String, size := 56, color := Color("fff3d2")) -> Label3D:
	var sign := Label3D.new()
	sign.text = text
	sign.font_size = size
	sign.pixel_size = 0.02
	sign.outline_size = 14
	sign.modulate = color
	sign.outline_modulate = Color("1d2b33")
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.no_depth_test = true
	sign.fixed_size = false
	sign.visibility_range_end = 300.0
	return sign


## Krummzahns Lager (Räuber) and Funkels Höhle (Drache) stand on the map from
## the start, so the child sees where an attack would come from.
func _build_enemy_homes() -> void:
	camp = Node3D.new()
	camp.name = "RobberCamp"
	camp.position = ground(RAIDS.ROBBER_CAMP.x, RAIDS.ROBBER_CAMP.y)
	add_child(camp)
	if ART.exists("robber_camp"):
		var tents := ART.instance("robber_camp", shadows)
		tents.rotation.y = atan2(center().x - camp.position.x, center().z - camp.position.z)
		tents.scale = Vector3.ONE * 1.4
		camp.add_child(tents)
	for index in range(3):
		var bandit := _actor("raccoon")
		if bandit != null:
			bandit.position = Vector3(-2.0 + index * 2.0, 0.0, 3.5 + (index % 2) * 0.8)
			bandit.rotation.y = 0.6 * (index - 1)
			camp.add_child(bandit)
	var camp_sign := _label("KRUMMZAHNS LAGER", 60, Color("ffd9a8"))
	camp_sign.position = Vector3(0, 9.0, 0)
	camp.add_child(camp_sign)
	nest = Node3D.new()
	nest.name = "DragonNest"
	nest.position = ground(RAIDS.DRAGON_NEST.x, RAIDS.DRAGON_NEST.y)
	add_child(nest)
	if ART.exists("dragon_nest"):
		var rocks := ART.instance("dragon_nest", shadows)
		rocks.scale = Vector3.ONE * 1.6
		rocks.rotation.y = atan2(center().x - nest.position.x, center().z - nest.position.z)
		nest.add_child(rocks)
	dragon_home = _actor("dragon")
	if dragon_home != null:
		dragon_home.position = Vector3(0, 0.3, 2.2)
		dragon_home.rotation.y = atan2(center().x - nest.position.x, center().z - nest.position.z)
		nest.add_child(dragon_home)
	var nest_sign := _label("FUNKELS HÖHLE", 60, Color("b6f2e4"))
	nest_sign.position = Vector3(0, 10.0, 0)
	nest.add_child(nest_sign)


func _actor(kind: String) -> Node3D:
	if not ART.exists(kind):
		return null
	var node := ART.instance(kind, shadows)
	node.set_meta("actor_kind", kind)
	return node


## Rebuild the ring when parts or the village size changed; damage markers always.
func sync() -> void:
	if model == null or raids == null:
		return
	var key := "%s|%d|%d" % [JSON.stringify(raids.parts), int(model._player.plots), mini(raids.guards, MAX_GUARDS_SHOWN)]
	if key != _key:
		_key = key
		_build_ring()
	_sync_damage()
	_sync_sender()


## Absender auf der Karte: über der Nachbarstadt, dem Lager oder der Höhle
## steht ein Warnschild mit Anlass, solange eine Herausforderung angekündigt ist.
func _sync_sender() -> void:
	var sign := get_node_or_null("SenderSign") as Label3D
	if raids.pending.is_empty():
		if sign != null:
			sign.queue_free()
		return
	if sign == null:
		sign = _label("", 64, Color("ffd25a"))
		sign.name = "SenderSign"
		add_child(sign)
	var threat := str(raids.pending.threat)
	var from := _origin(threat, str(raids.pending.get("by", "")))
	sign.position = Vector3(from.x, maxf(from.y, ground(from.x, from.z).y) + 9.0, from.z)
	sign.text = "⚠ %s\n%s" % [raids.threat_title(raids.pending), str(raids.pending.get("reason", ""))]
	sign.width = 900.0
	sign.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	set_meta("sender", str(raids.pending.get("by", threat)))


func _ring_points(half: float) -> Array:
	# Square ring, walked clockwise; returns [position, yaw, side] per segment.
	var points: Array = []
	var c := center()
	var count := maxi(2, int(ceil(half * 2.0 / SEGMENT)))
	var length := half * 2.0 / float(count)
	for side in range(4):
		for index in range(count):
			var along := -half + length * (float(index) + 0.5)
			var local: Vector2 = [Vector2(along, -half), Vector2(half, along), Vector2(-along, half), Vector2(-half, -along)][side]
			var yaw: float = [0.0, PI * 0.5, PI, -PI * 0.5][side]
			points.append([Vector3(c.x + local.x, 0, c.z + local.y), yaw, side, index, count, length])
	return points


func _build_ring() -> void:
	for child in ring.get_children():
		child.queue_free()
	gate_bridge = null
	var half := half_extent()
	var wall_level := int(raids.parts.wall)
	var gate_level := int(raids.parts.gate)
	var walls: Array = []
	var moats: Array = []
	var points := _ring_points(half)
	var gate_index := -1
	for entry in points:
		if int(entry[2]) == 3 and int(entry[3]) == int(entry[4]) / 2:
			gate_index = points.find(entry)
	for index in range(points.size()):
		var entry: Array = points[index]
		var at: Vector3 = entry[0]
		var height := TERRAIN.height(at.x, at.z)
		if height < TERRAIN.WATER_LEVEL + 0.4:
			continue
		var stretch := float(entry[5]) / SEGMENT
		var basis := Basis(Vector3.UP, float(entry[1])).scaled(Vector3(stretch * 1.02, 1.0 if wall_level < 3 else 1.35, 1.0))
		if index == gate_index and gate_level > 0:
			gate_position = Vector3(at.x, height, at.z)
		elif wall_level > 0:
			walls.append(Transform3D(basis, Vector3(at.x, height - 0.15, at.z)))
		if int(raids.parts.ditch) > 0 and index != gate_index:
			var normal: Vector3 = [Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0)][int(entry[2])]
			var moat_at := at + normal * 3.6
			moats.append(Transform3D(Basis(Vector3.UP, float(entry[1])).scaled(Vector3(stretch * 1.02, 1, 1)),
				Vector3(moat_at.x, TERRAIN.height(moat_at.x, moat_at.z) + 0.05, moat_at.z)))
	if gate_index >= 0 and gate_position == Vector3.ZERO:
		var gate_entry: Array = points[gate_index]
		gate_position = ground((gate_entry[0] as Vector3).x, (gate_entry[0] as Vector3).z)
	if wall_level > 0:
		ART.batch(ring, "Walls", "palisade" if wall_level == 1 else "castle_wall", walls, 320.0, shadows)
	if not moats.is_empty():
		ART.batch(ring, "Moat", "moat", moats, 260.0, false)
	if gate_level > 0 and ART.exists("gatehouse"):
		var gate := ART.instance("gatehouse", shadows)
		gate.name = "Gate"
		gate.position = gate_position
		gate.rotation.y = -PI * 0.5
		ring.add_child(gate)
		gate_bridge = gate.get_node_or_null("Spin_Bridge") as Node3D
		if gate_bridge != null:
			gate_bridge.visible = gate_level >= 2
	var towers := int(raids.parts.tower)
	var c := center()
	var corners := [Vector3(-half, 0, -half), Vector3(half, 0, -half), Vector3(half, 0, half), Vector3(-half, 0, half)]
	for index in range(mini(towers, 4)):
		var spot: Vector3 = c + corners[index]
		var tower := ART.instance("wall_tower", shadows) if ART.exists("wall_tower") else null
		if tower == null:
			break
		tower.name = "Tower%d" % index
		tower.position = ground(spot.x, spot.z) + Vector3.DOWN * 0.2
		ring.add_child(tower)
	var traps := int(raids.parts.trap)
	var trap_transforms: Array = []
	for index in range(traps):
		var lateral := (float(index) - float(traps - 1) * 0.5) * 5.5
		var spot := c + Vector3(-half - 9.0, 0, lateral)
		trap_transforms.append(Transform3D(Basis(Vector3.UP, 0.4 * index), ground(spot.x, spot.z)))
	if not trap_transforms.is_empty():
		ART.batch(ring, "Traps", "net_trap", trap_transforms, 200.0, false)
	var guard_count := mini(int(raids.guards), MAX_GUARDS_SHOWN)
	var guard_spots: Array = []
	for index in range(guard_count):
		var side := -1.0 if index % 2 == 0 else 1.0
		var spot := (gate_position if gate_position != Vector3.ZERO else c + Vector3(-half, 0, 0)) + Vector3(2.2 + float(index / 2) * 1.4, 0, side * (3.6 + float(index / 2) * 0.4))
		guard_spots.append(Transform3D(Basis(Vector3.UP, -PI * 0.5).scaled(Vector3.ONE * 1.1), ground(spot.x, spot.z)))
	gate_guards = SOLDIERS.formation(ring, "GateGuards", "schild", guard_spots, "stehen") if not guard_spots.is_empty() else null
	ring.set_meta("walls", walls.size())
	ring.set_meta("towers", mini(towers, 4))
	ring.set_meta("guards", guard_count)


func _sync_damage() -> void:
	for child in damage_root.get_children():
		child.queue_free()
	for plot in model.damaged_plots:
		var at: Vector3 = REGION.plot_position(int(plot))
		at.y = TERRAIN.height(at.x, at.z)
		if ART.exists("scaffold"):
			var scaffold := ART.instance("scaffold", false)
			scaffold.position = at + Vector3(0, 0.05, 0)
			scaffold.scale = Vector3.ONE * 0.9
			damage_root.add_child(scaffold)
		var sign := _label("Reparieren!", 44, Color("ffcf6a"))
		sign.position = at + Vector3(0, 6.2, 0)
		damage_root.add_child(sign)
	damage_root.set_meta("damaged", model.damaged_plots.size())


func playing() -> bool:
	return scene_time >= 0.0


## Where the attackers come from and the point in front of the wall they aim at.
func _origin(threat: String, by: String) -> Vector3:
	match threat:
		"raeuber":
			return camp.position
		"drache":
			return nest.position + Vector3(0, 14.0, 0)
	return NEIGHBORS.plot_world(by, 4)


func _front(from: Vector3) -> Vector3:
	var c := center()
	var direction := Vector3(from.x - c.x, 0, from.z - c.z).normalized()
	var half := half_extent()
	var scale := half / maxf(absf(direction.x), absf(direction.z))
	var at := c + direction * (scale + 6.5)
	return ground(at.x, at.z)


## The short, readable raid scene. Purely visual; the result is already decided.
func play(result: Dictionary) -> void:
	_clear_actors()
	scene_result = result.duplicate(true)
	scene_time = 0.0
	var threat := str(result.threat)
	var from := _origin(threat, str(result.get("by", "")))
	var front := _front(from)
	var won := str(result.outcome) == "abgewehrt"
	SOLDIERS.set_state(gate_guards, "abwehr")
	# One property per stage (build_village_schedule.gd): group size or sides.
	var stage: Dictionary = SCHEDULE.stage(int(result.get("level", 1)))
	var count := 1 if threat == "drache" else clampi(int(stage.group), 3, 12)
	var sides := 1 if threat == "drache" else clampi(int(stage.sides), 1, 4)
	set_meta("scene_sides", sides)
	for index in range(count):
		var node: Node3D
		if threat == "drache":
			node = dragon_home
			if node != null:
				var keep := node.global_transform
				node.get_parent().remove_child(node)
				add_child(node)
				node.global_transform = keep
		else:
			node = _actor("raccoon") if threat == "raeuber" else _rival_figure(str(result.get("by", "")))
			if node != null:
				add_child(node)
		if node == null:
			continue
		var side := index % sides
		var lane_from := from
		var lane_front := front
		if side > 0:
			# Further arrival directions: the same group splits around the village.
			var c := center()
			var turned := Vector3(from.x - c.x, 0, from.z - c.z).rotated(Vector3.UP, PI * 0.5 * float(side))
			lane_from = Vector3(c.x + turned.x, from.y, c.z + turned.z)
			lane_front = _front(lane_from)
		var slot := index / sides
		var offset := Vector3((float(slot % 3) - 1.0) * 1.6, 0, float(slot / 3) * 1.8)
		actors.append({"node": node, "from": lane_from + offset, "front": lane_front + offset * 0.8, "won": won,
			"spin": 0.0, "phase": float(index) * 0.13, "flying": threat == "drache", "start": node.transform})
	set_meta("scene_actors", actors.size())


## Belagerer eines Nachbarn: Speerträger in der Farbe seiner Stadt (eigene,
## unterscheidbare Gegner; dieselben Menschen wie die eigenen Soldaten).
func _rival_figure(id: String) -> Node3D:
	var colour := Color(str(NEIGHBORS.spec(id).get("color", "c94a3a")))
	var figure := SOLDIERS.figure("speer", "marschieren", Color(colour.r, colour.g, colour.b, 1.0))
	if figure.get_child_count() == 0:
		figure.free()
		return _actor("guard")
	figure.set_meta("soldier", true)
	figure.set_meta("actor_kind", "belagerer")
	(figure.get_child(0) as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return figure


func _clear_actors() -> void:
	for actor in actors:
		var node: Node3D = actor.node
		if not is_instance_valid(node):
			continue
		if node == dragon_home:
			node.get_parent().remove_child(node)
			nest.add_child(node)
			node.transform = actor.start
		else:
			node.queue_free()
	actors.clear()


func focus_point() -> Vector3:
	if actors.is_empty():
		return gate_position if gate_position != Vector3.ZERO else center()
	return (actors[0].front as Vector3)


func _advance_scene(delta: float) -> void:
	scene_time += delta
	var t := scene_time / SCENE_SECONDS
	for actor in actors:
		var node: Node3D = actor.node
		if not is_instance_valid(node):
			continue
		var from: Vector3 = actor.from
		var front: Vector3 = actor.front
		var local := clampf(t * 1.1 - float(actor.phase) * 0.2, 0.0, 1.0)
		var at: Vector3
		if local < 0.45:
			# approach
			if node.has_meta("soldier") and str((node.get_child(0) as Node).get_meta("state", "")) != "marschieren":
				SOLDIERS.set_state(node.get_child(0) as MultiMeshInstance3D, "marschieren")
			at = from.lerp(front, local / 0.45)
			node.rotation = Vector3(0, atan2(front.x - from.x, front.z - from.z), 0)
		elif local < 0.6:
			at = front
			var bump := (local - 0.45) / 0.15
			if bool(actor.won):
				# bounce off the defences and tumble (purzeln) – nobody is hurt
				node.rotation.x = bump * TAU
				at += Vector3.UP * sin(bump * PI) * 1.4
			else:
				at = front.lerp(center(), bump * 0.35)
		else:
			var back := (local - 0.6) / 0.4
			if node.has_meta("soldier") and str((node.get_child(0) as Node).get_meta("state", "")) != "zurueck":
				SOLDIERS.set_state(node.get_child(0) as MultiMeshInstance3D, "zurueck" if bool(actor.won) else "marschieren")
			var start: Vector3 = front if bool(actor.won) else front.lerp(center(), 0.35)
			at = start.lerp(from, back)
			node.rotation = Vector3(0, atan2(from.x - start.x, from.z - start.z), 0)
			if bool(actor.won):
				node.rotation.z = sin(clock * 18.0) * 0.25
		if bool(actor.flying):
			var wings := [node.get_node_or_null("Spin_WingL"), node.get_node_or_null("Spin_WingR")]
			for index in range(2):
				if wings[index] != null:
					(wings[index] as Node3D).rotation.z = sin(clock * 9.0) * 0.6 * (1.0 if index == 0 else -1.0)
			at.y = maxf(at.y, TERRAIN.height(at.x, at.z) + 8.0 + sin(clock * 2.0))
		else:
			at.y = TERRAIN.height(at.x, at.z) + absf(sin(clock * 12.0 + float(actor.phase) * 9.0)) * 0.18 + maxf(0.0, at.y - TERRAIN.height(at.x, at.z))
		node.position = at
	if gate_bridge != null and gate_bridge.visible:
		# The drawbridge goes up while the attackers are at the gate.
		var up := clampf(1.0 - absf(t - 0.5) * 3.0, 0.0, 1.0)
		gate_bridge.rotation.x = -up * 1.3
	if is_instance_valid(gate_guards) and t > 0.62:
		var mood := "jubeln" if str(scene_result.get("outcome", "")) == "abgewehrt" else "senken"
		if str(gate_guards.get_meta("state", "")) != mood:
			SOLDIERS.set_state(gate_guards, mood)
	if scene_time >= SCENE_SECONDS:
		scene_time = -1.0
		SOLDIERS.set_state(gate_guards, "stehen")
		_clear_actors()
		if gate_bridge != null:
			gate_bridge.rotation.x = 0.0
		sync()
		scene_finished.emit()


func finish_now() -> void:
	if playing():
		scene_time = SCENE_SECONDS - 0.001
		_advance_scene(0.01)


func advance(delta: float) -> void:
	clock += delta
	if playing():
		_advance_scene(delta)
	elif dragon_home != null and dragon_home.get_parent() == nest:
		# Funkel naps on its coin pile and breathes slowly.
		var breath := 1.0 + sin(clock * 1.6) * 0.03
		dragon_home.scale = Vector3(1.0, breath, 1.0)
		for wing_name in ["Spin_WingL", "Spin_WingR"]:
			var wing := dragon_home.get_node_or_null(wing_name) as Node3D
			if wing != null:
				wing.rotation.z = (0.25 if wing_name == "Spin_WingL" else -0.25) + sin(clock * 0.8) * 0.05
