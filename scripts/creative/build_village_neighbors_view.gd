extends Node3D
## Sichtbare Nachbardörfer: ihre echten Gebäude aus dem Spielmodell, Ortsschild,
## Banner in ihrer Farbe, ihre Roster-Figur auf dem Händlerwagen, Mauern beim
## Burgenbauer und Karawanen auf den Wegen, wenn gehandelt oder geholfen wird.
## Reine Darstellung – liest nur build_village_neighbors.gd.
const NEIGHBORS = preload("res://scripts/creative/build_village_neighbors.gd")
const VISUAL = preload("res://scripts/creative/build_settlement_visual.gd")
const ART = preload("res://scripts/creative/build_village_art.gd")
const TERRAIN = preload("res://scripts/creative/build_village_terrain.gd")
const ROSTER = preload("res://scripts/games/lumo_opponent_roster.gd")
const VIEW_RANGE := 240.0
var model
var facilities: Dictionary = {}
var walls: Dictionary = {}
var caravans: Array[Dictionary] = []
var _focus := Vector3(INF, 0, 0)
var clock := 0.0


func setup(neighbors) -> void:
	model = neighbors
	name = "NeighborVillages"
	for entry in NEIGHBORS.NEIGHBORS:
		_build_site(entry)
	_build_sources()
	sync()


func _build_site(entry: Dictionary) -> void:
	var holder := Node3D.new()
	holder.name = "Neighbor_" + str(entry.id)
	add_child(holder)
	var center: Vector3 = NEIGHBORS.plot_world(str(entry.id), 4)
	var sign := Label3D.new()
	sign.text = "%s · %s" % [str(entry.town).to_upper(), str(entry.name)]
	# Gut lesbar aus der Übersicht: groß, hell, dunkler Rand, nie verdeckt.
	sign.position = center + Vector3(0, 12.0, -9.0)
	sign.font_size = 72
	sign.pixel_size = 0.026
	sign.outline_size = 20
	sign.modulate = Color(str(entry.color)).lightened(0.6)
	sign.outline_modulate = Color("142629")
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.no_depth_test = true
	sign.render_priority = 2
	sign.visibility_range_end = 320.0
	holder.add_child(sign)
	if ART.exists("watchtower"):
		var banner := ART.instance("watchtower")
		var spot := center + Vector3(-12.0, 0, -11.0)
		banner.position = Vector3(spot.x, TERRAIN.height(spot.x, spot.z) - 0.3, spot.z)
		banner.scale = Vector3.ONE * 0.8
		holder.add_child(banner)
	if ART.exists("cart"):
		var wagon := ART.instance("cart")
		var spot := center + Vector3(0, 0, 9.0)
		wagon.position = Vector3(spot.x, TERRAIN.height(spot.x, spot.z), spot.z)
		wagon.rotation.y = 0.6
		holder.add_child(wagon)
		var figure := _figure(str(entry.animal))
		if figure != null:
			figure.scale = Vector3.ONE * 0.62
			figure.position = Vector3(0, 0.55, 1.15)
			figure.rotation.y = PI
			wagon.add_child(figure)


func _figure(animal: String) -> Node3D:
	var path := ROSTER.racing_model_path(animal, 2)
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var figure := (load(path) as PackedScene).instantiate() as Node3D
	var player := figure.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player != null:
		var clip := "kart_seated" if player.has_animation("kart_seated") else "idle"
		if player.has_animation(clip):
			player.play(clip)
	for mesh in figure.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	figure.set_meta("roster_id", animal)
	return figure


func _build_sources() -> void:
	for key in NEIGHBORS.SOURCES:
		var source: Dictionary = NEIGHBORS.SOURCES[key]
		var at: Vector2 = source.at
		var sign := Label3D.new()
		sign.name = "Source_" + key
		sign.position = Vector3(at.x, TERRAIN.height(at.x, at.y) + 4.5, at.y)
		sign.font_size = 44
		sign.pixel_size = 0.012
		sign.outline_size = 8
		sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sign.visibility_range_end = 160.0
		add_child(sign)


func sync() -> void:
	if model == null:
		return
	var active: Dictionary = {}
	for entry in NEIGHBORS.NEIGHBORS:
		var id: String = entry.id
		var town: Dictionary = model.towns[id]._player
		var holder := get_node("Neighbor_" + id) as Node3D
		for building in town.buildings:
			var key := "%s_%s" % [id, str(building.id)]
			active[key] = true
			if facilities.has(key):
				continue
			var facility: StaticBody3D = VISUAL.create(str(building.kind), true, int(entry.variant))
			facility.position = NEIGHBORS.plot_world(id, int(building.plot)) + Vector3.UP * 0.06
			facility.rotation.y = (float(posmod(int(building.plot) * 13, 5)) - 2.0) * 0.04
			facility.collision_layer = 0
			holder.add_child(facility)
			facilities[key] = facility
		_walls(entry, town, holder)
	for key in facilities.keys():
		if not active.has(key):
			facilities[key].queue_free()
			facilities.erase(key)
	for key in NEIGHBORS.SOURCES:
		var sign := get_node_or_null("Source_" + key) as Label3D
		if sign == null:
			continue
		var owner := str(model.sources.get(key, ""))
		var who := "frei" if owner.is_empty() else ("deine" if owner == "player" else str(NEIGHBORS.spec(owner).name))
		sign.text = "%s (%s)" % [str(NEIGHBORS.SOURCES[key].title), who]
		sign.modulate = Color("b6ec8c") if owner == "player" else (Color("fff3d2") if owner.is_empty() else Color("ffcf9a"))
	set_meta("neighbor_buildings", facilities.size())


## The castle builder rings his village with a fence once he has two quarries.
func _walls(entry: Dictionary, town: Dictionary, holder: Node3D) -> void:
	var id: String = entry.id
	if str(entry.trait) != "burgenbauer" or walls.has(id) or not ART.exists("fence"):
		return
	var quarries := 0
	for building in town.buildings:
		if str(building.kind) == "quarry":
			quarries += 1
	if quarries < 2:
		return
	var transforms: Array = []
	var center: Vector3 = NEIGHBORS.plot_world(id, 4)
	var half := REGION_HALF
	for side in range(4):
		for step in range(5):
			var along := -half + 4.0 + float(step) * 4.0 * half / 10.0
			var local: Vector2 = [Vector2(along, -half), Vector2(half, along), Vector2(-along, half), Vector2(-half, -along)][side]
			var x: float = center.x + local.x
			var z: float = center.z + local.y
			var yaw: float = [0.0, PI * 0.5, PI, -PI * 0.5][side]
			transforms.append(Transform3D(Basis(Vector3.UP, yaw), Vector3(x, TERRAIN.height(x, z), z)))
	walls[id] = ART.batch(holder, "Walls", "fence", transforms, 220.0, true)


const REGION_HALF := 10.6


func start_caravan(from: Vector3, to: Vector3, label: String) -> void:
	if not ART.exists("cart"):
		return
	var cart := ART.instance("cart")
	cart.name = "Caravan"
	add_child(cart)
	var sign := Label3D.new()
	sign.text = label
	sign.position = Vector3(0, 2.6, 0)
	sign.font_size = 40
	sign.pixel_size = 0.01
	sign.outline_size = 8
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	cart.add_child(sign)
	caravans.append({"node": cart, "from": from, "to": to, "t": 0.0})


func advance(delta: float, view_focus: Vector3) -> void:
	clock += delta
	if view_focus.distance_squared_to(_focus) > 100.0:
		_focus = view_focus
		for key in facilities:
			var node: Node3D = facilities[key]
			node.visible = Vector2(node.position.x - view_focus.x, node.position.z - view_focus.z).length() < VIEW_RANGE
	for index in range(caravans.size() - 1, -1, -1):
		var trip: Dictionary = caravans[index]
		trip.t = float(trip.t) + delta / 14.0
		var node: Node3D = trip.node
		if float(trip.t) >= 1.0:
			node.queue_free()
			caravans.remove_at(index)
			continue
		var at: Vector3 = (trip.from as Vector3).lerp(trip.to, float(trip.t))
		at.y = TERRAIN.height(at.x, at.z) + 0.02
		node.position = at
		var dir: Vector3 = (trip.to as Vector3) - (trip.from as Vector3)
		node.rotation.y = atan2(dir.x, dir.z)
