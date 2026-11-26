extends "res://scripts/creative/lumo_world_open_world.gd"
## A walkable chapter with physical exhibits and the existing World quest,
## character, waypoint and conversation systems. The saved quest step is the
## authority for all changes to exhibits, including after a restart.
const CONTENT := "res://assets/creative/lumo_world/waldheim/auftraege.json"
const ENTRY := Vector3(172, 0, 92)
const FINAL_MISSION := "waldtafel"
const STATION_REACH := 3.6
const LANDS: Array[Rect2] = [
	Rect2(164, 75.8, 16, 20.2),
	Rect2(133, 96, 78, 21),
	Rect2(112, 117, 124, 75),
	Rect2(145, 192, 91, 25),
	Rect2(162, 217, 62, 10),
]
const EXHIBITS := [
	"count", "tracks", "signs", "beams", "lights", "shelter", "gauge", "channels",
	"pots", "seeds", "fest"
]
const INK := Color("e8e0c4")
const WOOD := Color("856345")
const TEAL := Color("83d5be")
const ORANGE := Color("ffca78")

var stations: Dictionary = {}
var station_views: Dictionary = {}
var timber: StandardMaterial3D


func _init() -> void:
	model = QUESTS.new(JSON.parse_string(FileAccess.get_file_as_string(CONTENT)))


func setup(owner_world: Node3D, saved: Variant = {}) -> bool:
	var errors := _validate_stations()
	if not errors.is_empty():
		push_error("[Waldheim] " + ", ".join(errors))
		save_valid = false
		return false
	routines.configure(model.content.get("routines", {}))
	var valid := super.setup(owner_world, saved)
	name = "Waldheim"
	return valid


func _validate_stations() -> Array[String]:
	if not model.ready():
		return model.errors
	var errors: Array[String] = []
	var definitions = model.content.get("stations", [])
	if not definitions is Array or definitions.is_empty():
		return ["Waldheim needs stations"]
	for task in definitions:
		if not task is Dictionary:
			errors.append("invalid station")
			continue
		var id := str(task.get("id", ""))
		var steps: Array = model.mission(id).get("steps", [])
		var options = task.get("choices", [])
		if id.is_empty() or stations.has(id) or steps.size() != 3 or str(steps[1].kind) != "event" 				or str(steps[1].place) != str(task.get("place", "")) or not options is Array 				or options.size() < 2 or int(task.get("answer", -1)) not in range(options.size()) 				or str(task.get("visual", "")) not in EXHIBITS:
			errors.append("station has no valid mission, location or solution: " + id)
			continue
		stations[id] = task
	for id in model.mission_ids():
		var steps: Array = model.mission(id).steps
		if steps.size() != 3:
			errors.append("invalid route length for " + id)
		elif str(steps[1].kind) == "event" and not stations.has(id):
			errors.append("missing station for " + id)
	var profiles = model.content.get("routines", {})
	if not profiles is Dictionary:
		errors.append("Waldheim needs resident routines")
		return errors
	for figure in model.content.figures:
		var profile = profiles.get(str(figure.id), {})
		if (not profile is Dictionary or not profile.get("activities") is Array
				or profile.activities.size() != 4 or not profile.get("details") is Array
				or profile.details.size() != 4):
			errors.append("four daily activities required for " + str(figure.id))
	return errors


static func on_land(at: Vector2) -> bool:
	for area in LANDS:
		if area.grow(0.05).has_point(at):
			return true
	return false


func region_contains(at: Vector3) -> bool:
	return on_land(Vector2(at.x, at.z))


func map_lands() -> Array[Rect2]:
	return LANDS.duplicate()


func map_places() -> Array[Dictionary]:
	return [
		{"id": "waldheim", "title": "Waldheim", "at": Vector3(172, 0, 155), "view": Rect2(99, 67, 151, 165)},
	]


func tick(at: Vector3, driving: bool, delta: float) -> void:
	if at.z >= 48.0 and at.z <= 245.0 and at.x >= 92.0 and at.x <= 255.0:
		routines.elapsed = world.open_world.routines.elapsed
		super.tick(at, driving, delta)


func _build_paths() -> void:
	var terrain := _static(self, "WaldheimGround")
	var material: StandardMaterial3D = kit.textured("grass", Color("aabb85"))
	material.albedo_texture = ADVENTURE.texture("grass_albedo.jpg")
	material.normal_enabled = true
	material.normal_texture = ADVENTURE.texture("grass_normal.jpg")
	material.normal_scale = 0.48
	material.uv1_scale = Vector3.ONE * 0.22
	timber = ADVENTURE.material("wood").duplicate() as StandardMaterial3D
	timber.albedo_color = Color("c8ad8e")
	timber.uv1_triplanar = true
	timber.uv1_world_triplanar = true
	timber.uv1_scale = Vector3(0.69, 0.40, 0.69)
	for area in LANDS:
		var center := area.get_center()
		var deck := Vector3(area.size.x, 1.0, area.size.y)
		var floor := Vector3(center.x, -0.5, center.y)
		var visual := _solid(terrain, floor, deck, Color.WHITE)
		visual.material_override = material
	var bridge := _static(self, "Waldsteg")
	for index in range(19):
		var plank := kit.box(bridge, Vector3(172, 0.015, 77.0 + float(index)), Vector3(15.5, 0.025, 0.95), WOOD)
		plank.material_override = timber
	for x in [164.7, 179.3]:
		kit.collision(bridge, Vector3(x, 0.65, 86), Vector3(0.30, 1.3, 20.0))
		for z in [77.0, 83.0, 89.0, 95.0]:
			kit.box(bridge, Vector3(x, 0.65, z), Vector3(0.23, 1.3, 0.23), WOOD).material_override = timber
		kit.box(bridge, Vector3(x, 0.86, 86), Vector3(0.22, 0.20, 20.0), WOOD).material_override = timber
	for x in [168.2, 175.8]:
		_solid(bridge, Vector3(x, 1.85, 98), Vector3(0.42, 3.7, 0.43), WOOD).material_override = timber
	kit.box(bridge, Vector3(172, 3.60, 98), Vector3(8.0, 0.38, 0.6), WOOD).material_override = timber
	for x in [168.2, 175.8]:
		kit.cylinder(bridge, Vector3(x, 2.76, 98.48), 0.175, 0.39, Color("c79357"), 12).material_override = ADVENTURE.material("brass")
		kit.sphere(bridge, Vector3(x, 2.79, 98.52), Vector3(0.24, 0.31, 0.24), ORANGE, true)
	_sign_at(self, "WALDHEIM", Vector3(172, 3.11, 98), TEAL)
	_sign_at(self, "Waldheim · über den Steg", Vector3(165, 2.5, 65), ORANGE)
	super._build_paths()
	var path_material: Material = kit.textured("stone", Color("bcb091"))
	for strip in get_node("OpenWorldPaths").get_children():
		strip.material_override = path_material
		if strip.name == "Path_waldsteg_0":
			strip.hide()
	for xz in [Vector2(68.3, 14.6), Vector2(102.8, 13.6)]:
		var approach := kit.box(self, Vector3(172, 0.03, xz.x), Vector3(5.8, 0.04, xz.y), Color.WHITE)
		approach.material_override = path_material
		approach.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_places() -> void:
	_build_woods()
	_build_creek()
	_hut("Werkstatt", Vector3(124, 0, 152), Color("426878"))
	_hut("Wasserhaus", Vector3(225, 0, 143), Color("4c7277"))
	_hut("Gartenhaus", Vector3(181, 0, 191), Color("9c644a"))
	for item in model.content.places:
		if str(item.id) == "wh_waldpost":
			_build_turnaround(item.position)
	for id in stations:
		var station: Dictionary = stations[id]
		_build_station(station, model.place(str(station.place)).position)
	_refresh_stations()


func _build_creek() -> void:
	var creek := Node3D.new()
	creek.name = "WaldheimerBach"
	add_child(creek)
	var water := kit.material(Color("64a6a7"))
	water.roughness = 0.28
	var bed := kit.box(creek, Vector3(234.0, 0.012, 150.0), Vector3(3.4, 0.025, 64.0), Color.WHITE)
	bed.material_override = water
	var stones: Array[Transform3D] = []
	var reeds: Array[Transform3D] = []
	for index in range(19):
		var z := 119.0 + float(index) * 3.4
		var x := 232.15 + cos(float(index) * 2.1) * 0.20
		stones.append(ADVENTURE.xf(Vector3(x, 0, z), float(index) * 0.71, 0.28 + float(index % 3) * 0.12))
		reeds.append(ADVENTURE.xf(Vector3(x + 0.38, 0, z + 0.5), float(index) * 0.83, 0.55))
		if index % 2 == 0:
			kit.box(creek, Vector3(x + 1.0, 0.029, z), Vector3(1.3, 0.008, 0.031), Color("a5d4c6"))
	VILLAGE.batch(creek, "Bachsteine", "rock_a", stones, 80, false)
	VILLAGE.batch(creek, "Schilf", "reeds", reeds, 65, false)
	_sign_at(creek, "Waldheimer Bach", Vector3(231, 2.2, 152), TEAL)


func _build_turnaround(at: Vector3) -> void:
	var circle := kit.cylinder(self, at + Vector3.UP * 0.028, 8.4, 0.035, Color("bcae95"), 40)
	circle.material_override = kit.textured("stone", Color("c4b792"))
	var ring := TorusMesh.new()
	ring.inner_radius = 7.4
	ring.outer_radius = 7.58
	var mesh := kit.mesh(self, ring, at + Vector3.UP * 0.04, ORANGE, true)
	mesh.name = "WaldpostWendekreis"
	_sign_at(self, "WALDPOST · Wendekreis", at + Vector3(0, 2.8, -8.6), ORANGE)


func _build_woods() -> void:
	var tree_transforms: Array[Transform3D] = []
	var birch_transforms: Array[Transform3D] = []
	var flowers: Array[Transform3D] = []
	var rocks: Array[Transform3D] = []
	var ferns: Array[Transform3D] = []
	var solid_trees := _static(self, "WaldheimTrees")
	var density := float(LumoQuality.budget().get("decor_density", 1.0))
	for index in range(roundi(166 * clampf(density, 0.5, 1.0))):
		var x := 113.0 + fposmod(float(index) * 39.73, 122.0)
		var z := 103.0 + fposmod(float(index) * 22.91, 123.0)
		var at := Vector3(x, 0, z)
		if not on_land(Vector2(x,z)) or _reserved_ground(at):
			continue
		var size := 1.15 + float(index % 6) * 0.17
		var tree := ADVENTURE.xf(at, float(index) * 1.61, size)
		if index % 3 == 0:
			birch_transforms.append(tree)
		else:
			tree_transforms.append(tree)
		kit.collision(solid_trees, at + Vector3.UP * 1.65, Vector3(0.37, 3.3, 0.37) * size)
		if index % 2 == 0:
			rocks.append(ADVENTURE.xf(at + Vector3(2, 0, 1), float(index) * 0.73, 0.55))
		flowers.append(ADVENTURE.xf(at + Vector3(-1, 0, 0.9), float(index) * 0.7, 0.76))
		if index % 4 != 0:
			ferns.append(ADVENTURE.xf(at + Vector3(1.35, 0, 1.35), float(index) * 0.65, 1.2))
	for at in [Vector3(126, 0, 126), Vector3(136, 0, 180), Vector3(222, 0, 121), Vector3(200, 0, 222), Vector3(228, 0, 219)]:
		rocks.append(ADVENTURE.xf(at, at.z * 0.17, 1.8))
	VILLAGE.batch(self, "WaldheimFichten", "tree_fir", tree_transforms, 156, true)
	VILLAGE.batch(self, "WaldheimBirken", "tree_birch", birch_transforms, 156, true)
	VILLAGE.batch(self, "WaldheimFindlinge", "rock_b", rocks, 100, false)
	VILLAGE.batch(self, "WaldheimBlueten", "flowers", flowers, 75, false)
	VILLAGE.batch(self, "WaldheimUnterholz", "bush", ferns, 88, false)


func _reserved_ground(at: Vector3) -> bool:
	for place in model.content.places:
		if at.distance_squared_to(place.position) < 90.0:
			return true
	for path in model.content.paths:
		var points: Array = path.points
		for index in range(points.size() - 1):
			var from := Vector2(float(points[index][0]), float(points[index][1]))
			var to := Vector2(float(points[index + 1][0]), float(points[index + 1][1]))
			var nearest := Geometry2D.get_closest_point_to_segment(Vector2(at.x, at.z), from, to)
			if nearest.distance_to(Vector2(at.x, at.z)) < float(path.width) * 0.5 + 2.6:
				return true
	for hut in [Vector3(124, 0, 152), Vector3(225, 0, 143), Vector3(181, 0, 191)]:
		if at.distance_squared_to(hut) < 64.0:
			return true
	return false


func _hut(title: String, at: Vector3, roof_color: Color) -> void:
	var hut := _static(self, title)
	hut.position = at
	kit.box(hut, Vector3(0, 0.025, 0), Vector3(8.0, 0.04, 7.4), Color.WHITE).material_override = kit.textured("stone")
	_solid(hut, Vector3(0, 1.75, -3.3), Vector3(7.6, 3.0, 0.35), WOOD).material_override = timber
	for x in [-3.65, 3.65]:
		_solid(hut, Vector3(x, 1.7, 0), Vector3(0.35, 3.0, 6.9), WOOD).material_override = timber
		var roof := kit.box(hut, Vector3(x * 0.55, 4.18, 0), Vector3(4.6, 0.28, 8.3), roof_color)
		roof.rotation.z = -signf(x) * 0.43
		kit.box(hut, Vector3(x * 0.96, 1.9, 3.52), Vector3(0.35, 3.2, 0.38), WOOD)
		kit.box(hut, Vector3(x * 0.86, 0.75, 2.6), Vector3(1.25, 0.35, 1.2), WOOD)
		for z in [-2.9, 2.9]:
			kit.box(hut, Vector3(x * 0.97, 1.8, z), Vector3(0.42, 3.2, 0.38), WOOD).material_override = timber
		for z in [-1.8, 0.0, 1.8]:
			kit.box(hut, Vector3(x * 1.02, 1.85, z), Vector3(0.055, 0.075, 1.55), Color("abbf96"))
	kit.box(hut, Vector3(0, 3.24, 3.48), Vector3(7.4, 0.35, 0.36), WOOD)
	kit.box(hut, Vector3(0, 5.11, 0), Vector3(0.23, 0.20, 8.45), Color("714c32"))
	kit.box(hut, Vector3(0, 1.08, -2.42), Vector3(4.8, 0.20, 1.35), WOOD).material_override = timber
	for x in [-2.2, 2.2]:
		kit.box(hut, Vector3(x, 0.51, -2.42), Vector3(0.22, 1.0, 1.20), WOOD)
	for index in range(4):
		var x := -1.4 + float(index) * 0.66
		kit.box(hut, Vector3(x, 1.2, -2.36), Vector3(0.44, 0.12, 0.54), Color("c9ad71")).material_override = timber
	_sign_at(self, title, at + Vector3(0, 2.82, 3.92), ORANGE)


func _sign_at(parent: Node3D, title: String, at: Vector3, color: Color) -> Label3D:
	var label: Label3D = world.art._sign(parent, title, at, color)
	label.visibility_range_end = 32.0
	label.visibility_range_end_margin = 6.0
	return label


func _build_station(data: Dictionary, at: Vector3) -> void:
	var id := str(data.id)
	var station := Node3D.new()
	station.name = "Station_" + id
	station.position = at
	add_child(station)
	var exhibit := Node3D.new()
	exhibit.name = "Exhibit"
	exhibit.position = Vector3(0, 0, -1.9)
	station.add_child(exhibit)
	var furnishings := _static(exhibit, "Bench")
	_solid(furnishings, Vector3(0, 0.47, 0), Vector3(6.4, 0.94, 1.31), WOOD).material_override = timber
	kit.box(exhibit, Vector3(0, 0.97, 0), Vector3(6.6, 0.16, 1.48), Color.WHITE).material_override = timber
	for x in [-3.1, 3.1]:
		kit.box(exhibit, Vector3(x, 0.78, 0.68), Vector3(0.11, 0.22, 0.05), TEAL, true)
	var name_label := _sign_at(station, str(data.title), Vector3(0, 2.95, -2), ORANGE)
	name_label.name = "StationTitle"
	name_label.font_size = 33
	var status := _sign_at(station, "Untersuchen", Vector3(0, 2.45, -2), INK)
	status.name = "StationState"
	status.font_size = 28
	station_views[id] = {"root": station, "exhibit": exhibit, "status": status, "solved": false}
	_decorate(exhibit, data, false)


func _sample_label(root: Node3D, title: String, x: float) -> void:
	var label := _sign_at(root, title, Vector3(x, 1.25, 0.8), INK)
	label.font_size = 25


func _decorate(where: Node3D, data: Dictionary, solved: bool) -> void:
	var display := Node3D.new()
	display.name = "Samples"
	where.add_child(display)
	var values: Array = data.values
	match str(data.visual):
		"count", "tracks", "pots", "seeds":
			_display_groups(display, str(data.visual), values, solved)
		"beams", "lights", "channels":
			_display_measurements(display, str(data.visual), values, solved)
		"signs":
			_display_map_symbols(display, solved)
		"gauge":
			for index in range(3):
				var y := 1.2 + float(index) * 0.35
				kit.box(display, Vector3(0, y, 0), Vector3(2.5, 0.08, 0.16), ORANGE if index != 1 else Color("68cbea"), index == 1)
				var label := _sign_at(display, ["Niedrig", "Mittel", "Hoch"][index], Vector3(1.9, y, 0.1), INK)
				label.font_size = 20
		"shelter":
			for x in [-2.0, 0.0, 2.0]:
				kit.box(display, Vector3(x, 1.3, -0.38), Vector3(1.45, 0.45, 0.12), Color("6a5555"))
				var bench_x: float = x - 0.6 if x == 2.0 else x
				kit.box(display, Vector3(bench_x, 1.15, 0.35), Vector3(0.38, 0.2, 0.52), TEAL if solved and x == 2.0 else WOOD)
			_sample_label(display, "Tür", -2.0)
			_sample_label(display, "Vor dem Tisch", 0.0)
			_sample_label(display, "Seitenwand", 2.0)
		"fest":
			kit.box(display, Vector3(0, 1.65, -0.1), Vector3(4.9, 1.0, 0.18), Color("456451"), solved)
			var label := _sign_at(display, "WALDHEIM · Wir haben es geschafft!" if solved else "Gemeinsam wachsen", Vector3(0, 1.68, 0.1), TEAL)
			label.font_size = 31


func _display_map_symbols(root: Node3D, solved: bool) -> void:
	for x in [-2.0, 0.0, 2.0]:
		kit.box(root, Vector3(x, 1.51, 0), Vector3(1.5, 0.84, 0.13), Color("436568"))
	var left := kit.box(root, Vector3(-2.25, 1.59, 0.10), Vector3(0.57, 0.09, 0.06), ORANGE)
	left.rotation.z = 0.58
	var right := kit.box(root, Vector3(-1.75, 1.59, 0.10), Vector3(0.57, 0.09, 0.06), ORANGE)
	right.rotation.z = -0.58
	kit.box(root, Vector3(0, 1.41, 0.10), Vector3(0.13, 0.30, 0.06), ORANGE)
	kit.sphere(root, Vector3(0, 1.65, 0.11), Vector3(0.52, 0.38, 0.10), TEAL)
	for index in range(5):
		var wave := kit.box(root, Vector3(1.56 + float(index) * 0.22, 1.51 + sin(float(index) * PI * 0.5) * 0.10, 0.1),
			Vector3(0.25, 0.055, 0.045), Color("8de0ee"), solved)
		wave.rotation.z = cos(float(index) * PI * 0.5) * 0.4
	if solved:
		_sample_label(root, "Bach", 2.0)


func _display_groups(root: Node3D, visual: String, original: Array, solved: bool) -> void:
	var counts: Array = original
	if visual == "pots" and solved:
		counts = [3, 3, 3]
	elif visual == "seeds" and solved:
		counts = [4, 4, 4]
	for index in range(3):
		var x := float(index - 1) * 2.0
		var count := int(counts[index])
		var color: Color = [TEAL, ORANGE, Color("abcc88")][index]
		kit.box(root, Vector3(x, 1.075, 0), Vector3(1.64, 0.12, 0.98), Color("5d6649"))
		for item in range(count):
			var point := Vector3(x - 0.58 + float(item % 4) * 0.37, 1.21, -0.29 + floorf(float(item) / 4.0) * 0.24)
			if visual == "pots":
				kit.cylinder(root, point, 0.052, 0.31, Color("5f794a"), 8)
				kit.sphere(root, point + Vector3.UP * 0.18, Vector3(0.16, 0.12, 0.1), color)
			elif visual == "tracks":
				if index == 2:
					kit.sphere(root, point, Vector3(0.15, 0.095, 0.14), color)
					for toe in range(4):
						kit.sphere(root, point + Vector3(-0.095 + float(toe) * 0.06, 0, -0.095), Vector3.ONE * 0.047, color)
				else:
					for side in [-0.04, 0.04]:
						kit.sphere(root, point + Vector3(side, 0, 0), Vector3(0.065, 0.075, 0.19), color)
			else:
				kit.box(root, point, Vector3(0.16, 0.20, 0.16), color)
		if visual in ["count", "seeds"]:
			_sample_label(root, str(count), x)
		else:
			_sample_label(root, ["Links", "Mitte", "Rechts"][index], x)


func _display_measurements(root: Node3D, visual: String, values: Array, solved: bool) -> void:
	if visual == "beams":
		for x in [-0.49, 0.49]:
			kit.box(root, Vector3(x, 1.33, -0.48), Vector3(0.21, 0.56, 0.36), WOOD)
		if solved:
			kit.box(root, Vector3(0, 1.69, -0.48), Vector3(1.32, 0.17, 0.44), TEAL)
	for index in range(3):
		var x := float(index - 1) * 2.0
		var ink := TEAL if solved and index == (2 if visual == "channels" else 1) else ORANGE
		match visual:
			"beams":
				var length := float(values[index]) * 0.33
				kit.box(root, Vector3(x, 1.22, 0), Vector3(length, 0.24, 0.43), ink)
				_sample_label(root, "%d m" % int(values[index]), x)
			"lights":
				kit.cylinder(root, Vector3(x, 1.35, 0), 0.06, 0.61, WOOD, 8)
				kit.sphere(root, Vector3(x, 1.7, 0), Vector3.ONE * 0.18, ink, solved and index == 1)
				_sample_label(root, "%d m" % int(values[index]), x)
			"channels":
				var rail := kit.box(root, Vector3(x, 1.47, 0), Vector3(1.56, 0.12, 0.34), ink)
				rail.rotation.z = float(1 - index) * 0.28
				var bucket := kit.cylinder(root, Vector3(x + 0.61, 1.21, 0), 0.17, 0.24, ORANGE, 12)
				if solved and index == 2:
					bucket.material_override = kit.material(Color("63bcd4"), true)
				_sample_label(root, ["Bergauf", "Gerade", "Bergab"][index], x)


func refresh() -> void:
	super.refresh()
	_refresh_stations()


func _refresh_stations() -> void:
	for id in station_views:
		var view: Dictionary = station_views[id]
		var solved := int(model.progress.get(id, 0)) >= 2
		view.status.visible = model.state(id) != "available"
		view.status.text = "Geschafft" if solved else "Untersuchen"
		view.status.modulate = TEAL if solved else INK
		if solved == bool(view.solved):
			continue
		var exhibit: Node3D = view.exhibit
		var previous := exhibit.get_node_or_null("Samples")
		if previous != null:
			for label in previous.find_children("*", "Label3D", true, false):
				world.art.signs.erase(label)
				world.art.sign_extents.erase(label.get_instance_id())
			exhibit.remove_child(previous)
			previous.queue_free()
		_decorate(exhibit, stations[id], solved)
		view.solved = solved


func _active_station(at: Vector3) -> String:
	if not unlocked() or world.driving or not at.is_finite():
		return ""
	for id in stations:
		var step := model.current_step(id)
		if str(step.get("kind", "")) != "event":
			continue
		var target := model.step_target(step)
		if at.distance_squared_to(target) <= STATION_REACH * STATION_REACH:
			return id
	return ""


func available(at: Vector3) -> bool:
	return not _active_station(at).is_empty() or super.available(at)


func action_label(at: Vector3) -> String:
	if not _active_station(at).is_empty():
		return "Untersuchen"
	return "Ansprechen" if super.available(at) else ""


func interact(at: Vector3) -> bool:
	if not unlocked() or world.paused or world.driving:
		return false
	var id := _active_station(at)
	if id.is_empty():
		return super.interact(at)
	_open_station(id)
	return true


func _open_station(id: String, hint := false) -> void:
	var task: Dictionary = stations[id]
	var body := str(task.prompt)
	if hint:
		body += "\n\nTipp: " + str(task.hint)
	var show_options := true
	if id == FINAL_MISSION and _unfinished_count() > 0:
		body = "Die gemeinsame Tafel wartet noch auf %d Waldaufträge. Im Journal findest du deine nächsten Schritte." % _unfinished_count()
		show_options = false
	world._open_dialog(str(task.title), body)
	if show_options:
		for index in range(task.choices.size()):
			var button := KIT.button(str(task.choices[index]), _submit_station.bind(id, index), 195)
			button.name = "WaldheimChoice_%d" % index
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			world.modal_box.add_child(button)
	var close := KIT.button("Weiter erkunden", world._close_dialog, 180, Color("1b7d63"))
	close.name = "WaldheimClose"
	world.modal_box.add_child(close)


func _unfinished_count() -> int:
	var count := 0
	for id in model.mission_ids():
		if id != FINAL_MISSION and model.state(id) != "done":
			count += 1
	return count


func _submit_station(id: String, index: int) -> void:
	if _active_station(world.player.position) != id or not world.paused:
		return
	if id == FINAL_MISSION and _unfinished_count() > 0:
		return
	var task: Dictionary = stations[id]
	if int(task.answer) != index:
		_open_station(id, true)
		return
	var events := model.notify_event("solve_" + id)
	if events.size() != 1:
		return
	world._close_dialog()
	world.fox.gesture("celebrate")
	_commit(_step_message(id, false))


func append_journal() -> void:
	world.modal_box.add_child(KIT.label("Waldheim · Waldwege und Werkstätten", 21))
	var journal := KIT.button("Waldheim-Aufträge und Album", _open_waldheim_journal, 190, Color("426d60"))
	journal.name = "OpenWaldheimJournal"
	world.modal_box.add_child(journal)


func _open_waldheim_journal() -> void:
	world._close_dialog()
	open_journal()
