extends Node3D
## Wachen-Verbände auf der Karte: je Standort eine repräsentative Gruppe (bis
## 24 Figuren in Zweierreihe auf der Straße, EIN Zeichenaufruf je Standort)
## und ein Schild mit der echten Gesamtzahl. 1.000 Wachen = 5 Gruppen, nie
## 1.000 Figuren. Reine Darstellung – liest build_village_guards.gd.
const GUARDS = preload("res://scripts/creative/build_village_guards.gd")
const REGION = preload("res://scripts/creative/build_settlement_region.gd")
const TERRAIN = preload("res://scripts/creative/build_village_terrain.gd")
const ART = preload("res://scripts/creative/build_village_art.gd")
const MAX_SHOWN := 24
const SPACING := 0.95
var model
var raids
var _key := ""


func setup(village_model, village_raids) -> void:
	model = village_model
	raids = village_raids
	name = "GuardUnits"
	sync()


## Wo ein Standort liegt: Tore vor dem erschlossenen Ortsrand, Mitte am Platz.
func post_position(post: String) -> Vector3:
	var edge := REGION.extent_for_plots(int(model._player.plots)) + 3.0
	var center := Vector2(-REGION.TOWN_CENTER + REGION.SPACING * 0.5, REGION.SPACING * 0.5)
	var spot := center
	match post:
		"nord":
			spot = Vector2(center.x, -edge)
		"sued":
			spot = Vector2(center.x, edge)
		"west":
			spot = Vector2(-REGION.TOWN_CENTER - edge, center.y)
		"ost":
			# Nie in den Fluss: das Osttor steht vor der Brücke am Ufer.
			var shore := TERRAIN.river_center(center.y) - 13.0
			var bridged := bool(model._player.get("city_projects", {}).get("bridge", false))
			spot = Vector2(-REGION.TOWN_CENTER + edge if bridged else minf(-REGION.TOWN_CENTER + edge, shore), center.y)
		_:
			spot = Vector2(center.x, center.y + REGION.SPACING * 2.0)
	return Vector3(spot.x, TERRAIN.height(spot.x, spot.y), spot.y)


func sync() -> void:
	if model == null or raids == null:
		return
	var info: Dictionary = GUARDS.overview(model, raids)
	var key := "%s|%d" % [JSON.stringify(info.posts), int(model._player.plots)]
	if key == _key:
		return
	_key = key
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var shown_total := 0
	for post in GUARDS.POST_ORDER:
		var count := int(info.posts[post])
		if count <= 0:
			continue
		var holder := Node3D.new()
		holder.name = "Post_" + post
		add_child(holder)
		var base := post_position(post)
		var along := Vector3(0, 0, 1) if post in ["nord", "sued", "mitte"] else Vector3(1, 0, 0)
		var side := Vector3(1, 0, 0) if along.z != 0.0 else Vector3(0, 0, 1)
		var yaw := 0.0 if along.z != 0.0 else PI * 0.5
		var shown := mini(count, MAX_SHOWN)
		var transforms: Array = []
		for index in range(shown):
			var row := index / 2
			var offset := along * (float(row) - float(shown / 2) * 0.5) * SPACING * 1.2 + side * (float(index % 2) - 0.5) * SPACING
			var at := base + offset
			at.y = TERRAIN.height(at.x, at.z)
			transforms.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * 1.15), at))
		if ART.exists("guard"):
			ART.batch(holder, "Formation", "guard", transforms, 240.0, false)
		shown_total += shown
		var units := 0
		for unit in raids.units:
			if str(unit.post) == post:
				units += 1
		var sign := Label3D.new()
		sign.name = "Sign"
		sign.text = "%s · %d %s\n%d %s · essen %d am Tag" % [
			str(GUARDS.POSTS[post]), count, "Wache" if count == 1 else "Wachen",
			units, "Verband" if units == 1 else "Verbände", count]
		sign.position = base + Vector3(0, 4.2, 0)
		sign.font_size = 44
		sign.pixel_size = 0.02
		sign.outline_size = 12
		sign.modulate = Color("e9f3ff")
		sign.outline_modulate = Color("1d2f4a")
		sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sign.no_depth_test = true
		sign.render_priority = 2
		sign.visibility_range_end = 300.0
		holder.add_child(sign)
		holder.set_meta("count", count)
		holder.set_meta("shown", shown)
	set_meta("shown_figures", shown_total)
	set_meta("total", int(info.total))
