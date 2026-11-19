extends Node3D
## Sichtbare Nachbardörfer: ihre echten Gebäude aus dem Spielmodell, Ortsschild,
## Banner in ihrer Farbe, ihre Roster-Figur auf dem Händlerwagen, Mauern beim
## Burgenbauer und Karawanen auf den Wegen, wenn gehandelt oder geholfen wird.
## Reine Darstellung – liest nur build_village_neighbors.gd.
const NEIGHBORS = preload("res://scripts/creative/build_village_neighbors.gd")
const VISUAL = preload("res://scripts/creative/build_settlement_visual.gd")
const ART = preload("res://scripts/creative/build_village_art.gd")
const TERRAIN = preload("res://scripts/creative/build_village_terrain.gd")
const REGION = preload("res://scripts/creative/build_settlement_region.gd")
const ROSTER = preload("res://scripts/games/lumo_opponent_roster.gd")
const VIEW_RANGE := 240.0
const VHUD_FONT = preload("res://assets/fonts/Nunito-Black.ttf")
var model
var facilities: Dictionary = {}
var walls: Dictionary = {}
var caravans: Array[Dictionary] = []
var _focus := Vector3(INF, 0, 0)
var clock := 0.0
## Optional: Gelände-Malschicht der Region (Gassen und Höfe der Nachbarstädte).
var landscape: Node3D
var project_signs: Dictionary = {}
var _fort_key := ""
var _painted: Dictionary = {}


func setup(neighbors) -> void:
	model = neighbors
	name = "NeighborVillages"
	for entry in NEIGHBORS.NEIGHBORS:
		_build_site(entry)
		_build_border(entry)
	_build_sources()
	sync()


## Grenzsteine in der Stadtfarbe: hier beginnt fremdes Stadtgebiet.
func _build_border(entry: Dictionary) -> void:
	if not ART.exists("lantern"):
		return
	var site: Vector2 = TERRAIN.NEIGHBOR_SITES.get(str(entry.id), Vector2.ZERO)
	var half := TERRAIN.NEIGHBOR_HALF + 2.65
	var transforms: Array = []
	for side in range(4):
		for step in range(9):
			var along := -half + float(step) * half * 2.0 / 8.0
			var local: Vector2 = [Vector2(along, -half), Vector2(half, along), Vector2(-along, half), Vector2(-half, -along)][side]
			var x := site.x + local.x
			var z := site.y + local.y
			if TERRAIN.is_water(x, z):
				continue
			transforms.append(Transform3D(Basis().scaled(Vector3.ONE * 0.8), Vector3(x, TERRAIN.height(x, z), z)))
	var holder := get_node("Neighbor_" + str(entry.id)) as Node3D
	ART.batch(holder, "Border", "lantern", transforms, 260.0, false)
	var label := Label3D.new()
	label.name = "TerritoryLabel"
	label.text = "Stadtgebiet %s" % str(entry.town)
	label.position = Vector3(site.x, TERRAIN.height(site.x, site.y - half) + 3.2, site.y - half)
	label.font_size = 40
	label.pixel_size = 0.016
	label.outline_size = 10
	label.modulate = Color(str(entry.color)).lightened(0.4)
	label.outline_modulate = Color("142629")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.visibility_range_end = 200.0
	holder.add_child(label)
	var sign := Label3D.new()
	sign.name = "ProjectSign"
	sign.font = VHUD_FONT
	sign.font_size = 38
	sign.pixel_size = 0.0006
	sign.fixed_size = true
	sign.outline_size = 14
	sign.modulate = Color("fff0b8")
	sign.outline_modulate = Color("3a2412")
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.no_depth_test = true
	sign.render_priority = 2
	sign.visibility_range_end = 700.0
	sign.visible = false
	holder.add_child(sign)
	project_signs[str(entry.id)] = sign


func _build_site(entry: Dictionary) -> void:
	var holder := Node3D.new()
	holder.name = "Neighbor_" + str(entry.id)
	add_child(holder)
	var center: Vector3 = NEIGHBORS.plot_world(str(entry.id), 4)
	var sign := Label3D.new()
	sign.name = "TownSign"
	sign.text = "%s\n%s" % [str(entry.town).to_upper(), str(entry.name)]
	# Gut lesbar aus jeder Entfernung: feste Bildschirmgröße, hell, dunkler Rand, nie verdeckt.
	sign.position = center + Vector3(0, 12.0, -9.0)
	sign.font = VHUD_FONT
	sign.font_size = 54
	sign.line_spacing = -8.0
	sign.pixel_size = 0.0006
	sign.fixed_size = true
	sign.outline_size = 18
	sign.modulate = Color(str(entry.color)).lightened(0.6)
	sign.outline_modulate = Color("142629")
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.no_depth_test = true
	sign.render_priority = 2
	sign.outline_render_priority = 1
	sign.visibility_range_end = 700.0
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
		var building_now: Dictionary = {}
		for item in model.sites.get(id, []):
			if int(item.done_day) > int(model.day):
				building_now[str(item.building)] = item
		for building in town.buildings:
			var under := building_now.has(str(building.id))
			var key := "%s_%s%s" % [id, str(building.id), "_bau" if under else ""]
			active[key] = true
			if facilities.has(key):
				continue
			var facility: StaticBody3D = VISUAL.create(str(building.kind), true, int(entry.variant))
			facility.position = NEIGHBORS.plot_world(id, int(building.plot)) + Vector3.UP * 0.06
			facility.rotation.y = (float(posmod(int(building.plot) * 13, 5)) - 2.0) * 0.04
			facility.collision_layer = 0
			if under:
				# Sichtbare Baustelle: Gerüst, halbhoher Rohbau.
				facility.set_meta("under_construction", true)
				var visual := facility.get_node_or_null("Visual") as Node3D
				if visual != null:
					visual.scale = Vector3(1.0, 0.45, 1.0)
				if ART.exists("scaffold"):
					var scaffold := ART.instance("scaffold")
					scaffold.name = "Scaffold"
					facility.add_child(scaffold)
			holder.add_child(facility)
			facilities[key] = facility
		_project_sign(entry, town)
		_paint_site(entry, town)
	_fort()
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


## Schild über der Baustelle: „BURGHEIM BAUT: …“ mit echten Resttagen.
func _project_sign(entry: Dictionary, _town: Dictionary) -> void:
	var id := str(entry.id)
	var sign: Label3D = project_signs.get(id)
	if sign == null:
		return
	var project: Dictionary = model.current_project(id)
	sign.visible = not project.is_empty()
	if project.is_empty():
		return
	var days := int(project.days_left)
	# Kurz und schmal, damit drei Städte nebeneinander lesbar bleiben (Begründung im Dialog).
	sign.text = "baut: %s\nnoch %s" % [str(project.title), "1 Tag" if days == 1 else "%d Tage" % days]
	# Direkt unter dem Ortsschild: Name und Bau-Hinweis gehören zusammen.
	sign.position = NEIGHBORS.plot_world(id, 4) + Vector3(0, 12.0, -9.0)
	sign.offset = Vector2(0, -112)


## Halbe Kantenlänge des bebauten Ortskerns eines Nachbarn.
func _town_half(town: Dictionary) -> float:
	var ring := 1
	for building in town.buildings:
		var cell := REGION.plot_coordinate(int(building.plot))
		ring = maxi(ring, maxi(absi(cell.x), absi(cell.y)))
	return (float(ring) + 0.9) * REGION.SPACING


func _paint_site(entry: Dictionary, town: Dictionary) -> void:
	if landscape == null or not landscape.has_method("paint_site"):
		return
	var id := str(entry.id)
	var key := "%d|%d" % [int(town.plots), town.buildings.size()]
	if _painted.get(id, "") == key:
		return
	_painted[id] = key
	var cells: Array = []
	var built: Dictionary = {}
	var ring := 1
	for index in range(mini(int(town.plots), NEIGHBORS.MAX_SITES)):
		if not NEIGHBORS.plot_ok(id, index):
			continue
		var at := NEIGHBORS.plot_world(id, index)
		cells.append(Vector2(at.x, at.z))
		var cell := REGION.plot_coordinate(index)
		ring = maxi(ring, maxi(absi(cell.x), absi(cell.y)))
	for building in town.buildings:
		var at := NEIGHBORS.plot_world(id, int(building.plot))
		built[Vector2(at.x, at.z)] = true
	landscape.paint_site(TERRAIN.NEIGHBOR_SITES[id], cells, built, TERRAIN.NEIGHBOR_RING)


## Burgheims Befestigung in Stufen: Palisade, Steinmauer, Wehrtürme. Eine
## laufende Stufe steht als halbhohe Baustelle mit Gerüsten am Ortsrand.
func _fort() -> void:
	var id := "leo"
	var town: Dictionary = model.towns[id]._player
	var half := _town_half(town) + 1.5
	var stage := int(model.fort.stage)
	var building := int(model.fort.building)
	var key := "%d|%d|%.1f" % [stage, building, half]
	if key == _fort_key:
		return
	_fort_key = key
	var holder := get_node("Neighbor_" + id) as Node3D
	if walls.has(id) and is_instance_valid(walls[id]):
		walls[id].queue_free()
	walls.erase(id)
	var shown := maxi(stage, building + 1)
	if shown <= 0:
		return
	var fort := Node3D.new()
	fort.name = "Fortification"
	holder.add_child(fort)
	walls[id] = fort
	var center: Vector3 = NEIGHBORS.plot_world(id, 4)
	var kind := "palisade" if shown == 1 else "castle_wall"
	if not ART.exists(kind):
		kind = "fence"
	var segment := 4.0
	var transforms: Array = []
	var scaffolds: Array = []
	var count := maxi(2, int(half * 2.0 / segment))
	for side in range(4):
		for step in range(count):
			var along := -half + (float(step) + 0.5) * half * 2.0 / float(count)
			var local: Vector2 = [Vector2(along, -half), Vector2(half, along), Vector2(-along, half), Vector2(-half, -along)][side]
			# Ein Tor zur Straße auf jeder Seite.
			if absf(along) < 2.6:
				continue
			var x: float = center.x + local.x
			var z: float = center.z + local.y
			var yaw: float = [0.0, PI * 0.5, PI, -PI * 0.5][side]
			var under := building >= 0 and shown == building + 1 and step % 2 == 1
			var xform := Transform3D(Basis(Vector3.UP, yaw), Vector3(x, TERRAIN.height(x, z) - 0.1, z))
			if under:
				xform = xform.scaled_local(Vector3(1.0, 0.45, 1.0))
				scaffolds.append(Transform3D(Basis(Vector3.UP, yaw), xform.origin))
			transforms.append(xform)
	ART.batch(fort, "Walls", kind, transforms, 260.0, true)
	if not scaffolds.is_empty() and ART.exists("scaffold"):
		ART.batch(fort, "Scaffolds", "scaffold", scaffolds, 200.0, false)
	if shown >= 3 and ART.exists("wall_tower"):
		var towers: Array = []
		for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			var x: float = center.x + corner.x * half
			var z: float = center.z + corner.y * half
			var xform := Transform3D(Basis(), Vector3(x, TERRAIN.height(x, z) - 0.1, z))
			if building == 2:
				xform = xform.scaled_local(Vector3(1.0, 0.45, 1.0))
			towers.append(xform)
		ART.batch(fort, "Towers", "wall_tower", towers, 280.0, true)
	fort.set_meta("stage", stage)
	fort.set_meta("building", building)


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
