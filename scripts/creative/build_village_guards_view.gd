extends Node3D
## Verbände auf der Karte: je Tor eine Formation aus den Blender-Menschen
## (build_village_soldiers.gd: je Art EIN MultiMesh, bis 12 Figuren, Bewegung im
## Shader), vorn Schildwachen, dahinter Speerträger und Bogenschützen, Reiter
## am Ende. Über jedem Tor eine Standarte in Stadtfarbe und ein Banner mit den
## echten Zahlen, das aus jeder Entfernung gleich groß und lesbar bleibt; aus
## der Ferne verschwinden die Figuren, das Banner bleibt. Antippen des Banners
## öffnet die Verbände-Tafel. 1.000 Soldaten = wenige Gruppen, nie 1.000 Figuren.
## Reine Darstellung – liest build_village_guards.gd.
const GUARDS = preload("res://scripts/creative/build_village_guards.gd")
const REGION = preload("res://scripts/creative/build_settlement_region.gd")
const TERRAIN = preload("res://scripts/creative/build_village_terrain.gd")
const TROOPS = preload("res://scripts/creative/build_village_troops.gd")
const SOLDIERS = preload("res://scripts/creative/build_village_soldiers.gd")
const VHUD = preload("res://scripts/creative/build_village_hud.gd")
const ART = preload("res://scripts/creative/build_village_art.gd")
## Ausbildungsstätten stehen vor dem Tor ihrer Truppe (Blender-Modelle site_*).
const SITE_GATES := {"schiessplatz": "nord", "kaserne": "west", "stall": "sued"}
const MAX_SHOWN := 24
const MAX_PER_KIND := 12
## Reihenfolge von vorn nach hinten: Schild hält, Speer stützt, Bogen schießt darüber.
const RANKS := ["schild", "speer", "bogen", "reiter"]
const ABREAST := {"schild": 4, "speer": 4, "bogen": 4, "reiter": 3}
const SCALE := 1.1
const FIGURE_RANGE := 150.0
const SHORT := {"schild": "Schild", "bogen": "Bogen", "speer": "Speer", "reiter": "Reiter"}
const TEAM := Color("36589c")
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
	# Auf der äußersten Gasse um den erschlossenen Ort (nie im Wald davor).
	var ring := roundi(REGION.extent_for_plots(int(model._player.plots)) / REGION.SPACING - 0.8)
	var edge := (float(ring) + 0.5) * REGION.SPACING
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
			spot = Vector2(
				-REGION.TOWN_CENTER + edge if bridged else minf(-REGION.TOWN_CENTER + edge, shore),
				center.y
			)
		_:
			spot = Vector2(center.x, center.y + REGION.SPACING * 2.0)
	return Vector3(spot.x, TERRAIN.height(spot.x, spot.y), spot.y)


## Blickrichtung der Formation: hinaus vor das Tor (Mitte schaut nach Süden).
static func facing(post: String) -> Vector3:
	match post:
		"nord":
			return Vector3(0, 0, -1)
		"ost":
			return Vector3(1, 0, 0)
		"west":
			return Vector3(-1, 0, 0)
	return Vector3(0, 0, 1)


## Zustand der Figuren: Abwehrhaltung am Tor, auf das eine Bedrohung zukommt.
func post_state(post: String) -> String:
	if raids == null or raids.pending.is_empty():
		return "stehen"
	var side := str(GUARDS.THREAT_SIDE.get(str(raids.pending.get("threat", "")), ""))
	return "abwehr" if side == post else "stehen"


func sync() -> void:
	if model == null or raids == null:
		return
	var info: Dictionary = GUARDS.overview(model, raids)
	var states := PackedStringArray()
	for post in GUARDS.POST_ORDER:
		states.append(post_state(post))
	var key := (
		"%s|%d|%s|%s"
		% [
			JSON.stringify(info.mix),
			int(model._player.plots),
			",".join(states),
			str(raids.troop_sites)
		]
	)
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
		var front := facing(post)
		var lateral := Vector3(-front.z, 0, front.x)
		var yaw := atan2(front.x, front.z)
		var state := post_state(post)
		var shown := 0
		var depth := 0.0
		var parts := PackedStringArray()
		var leading := ""
		var leading_count := 0
		for kind in RANKS:
			var of_kind := int(info.mix.get("%s|%s" % [post, kind], 0))
			if of_kind <= 0:
				continue
			parts.append("%d %s" % [of_kind, SHORT[kind]])
			if of_kind > leading_count:
				leading = kind
				leading_count = of_kind
			var figures := mini(of_kind, MAX_PER_KIND)
			var abreast: int = ABREAST[kind]
			var across := (1.5 if kind == "reiter" else 0.95) * SCALE
			var behind := (2.6 if kind == "reiter" else 1.05) * SCALE
			var transforms: Array = []
			for index in range(figures):
				var row := index / abreast
				var in_row := mini(abreast, figures - row * abreast)
				var column := float(index % abreast) - float(in_row - 1) * 0.5
				# Leicht versetzte Reihen wirken wie eine echte Aufstellung.
				var offset := (
					lateral * (column * across + (0.18 if row % 2 == 1 else 0.0))
					- front * (depth + float(row) * behind)
				)
				var at := base + offset
				at.y = TERRAIN.height(at.x, at.z)
				var turn := yaw + sin(float(index) * 1.7) * 0.06
				transforms.append(
					Transform3D(Basis(Vector3.UP, turn).scaled(Vector3.ONE * SCALE), at)
				)
			var batch := SOLDIERS.formation(
				holder,
				"Formation_" + kind,
				kind,
				transforms,
				state,
				Color(0, 0, 0, 0),
				FIGURE_RANGE
			)
			if batch != null:
				batch.set_meta("count", of_kind)
				batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			depth += float((figures + abreast - 1) / abreast) * behind + 0.8
			shown += figures
		shown_total += shown
		_standard(holder, base + lateral * 3.2 * SCALE - front * 0.6)
		var units := 0
		for unit in raids.units:
			if str(unit.post) == post:
				units += 1
		var food := (
			count
			+ TROOPS.upkeep(
				raids.units.filter(func(u: Dictionary) -> bool: return str(u.post) == post)
			)
		)
		var sign := Label3D.new()
		sign.name = "Sign"
		sign.text = "%s · %d Soldaten\n%s" % [str(GUARDS.POSTS[post]), count, " · ".join(parts)]
		sign.position = base + Vector3(0, 10.5 if post == "mitte" else 6.5, 0)
		sign.font = VHUD.FONT
		sign.font_size = 46
		sign.outline_size = 14
		sign.pixel_size = 0.00042
		sign.fixed_size = true
		sign.modulate = Color("fff6dc")
		sign.outline_modulate = Color("1a2c48")
		sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sign.no_depth_test = true
		sign.render_priority = 3
		sign.outline_render_priority = 2
		holder.add_child(sign)
		var icon := Sprite3D.new()
		icon.name = "Banner"
		icon.texture = VHUD.texture("troop_" + leading)
		icon.position = base + Vector3(0, 10.5 if post == "mitte" else 6.5, 0)
		icon.offset = Vector2(0, 170)
		icon.pixel_size = 0.0002
		icon.fixed_size = true
		icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		icon.no_depth_test = true
		icon.render_priority = 2
		holder.add_child(icon)
		holder.set_meta("count", count)
		holder.set_meta("shown", shown)
		holder.set_meta("units", units)
		holder.set_meta("food", food)
		holder.set_meta("anchor", sign.position)
	set_meta("shown_figures", shown_total)
	set_meta("total", int(info.total))
	_sites()


## Gebaute Ausbildungsstätten als echte Gebäude vor ihrem Tor, seitlich der Formation.
func _sites() -> void:
	var placed := 0
	for site in SITE_GATES:
		if not bool(raids.troop_sites.get(site, false)):
			continue
		var model_name := "site_" + str(site)
		if not ART.exists(model_name):
			continue
		var front := facing(str(SITE_GATES[site]))
		var node := ART.instance(model_name)
		node.name = "Site_" + str(site)
		node.position = site_position(site)
		# Die Vorderseite schaut zur Straße vor dem Tor.
		node.rotation.y = atan2(front.x, front.z) + PI * 0.5
		node.set_meta("site", site)
		add_child(node)
		placed += 1
	set_meta("sites", placed)


func site_position(site: String) -> Vector3:
	var gate := str(SITE_GATES.get(site, "sued"))
	var front := facing(gate)
	var lateral := Vector3(-front.z, 0, front.x)
	var at := post_position(gate) - lateral * 16.0 + front * 7.0
	at.y = TERRAIN.height(at.x, at.z) - 0.05
	return at


## Standarte: Stange mit Tuch in Stadtfarbe und goldenem Stern (nah sichtbar).
func _standard(holder: Node3D, at: Vector3) -> void:
	at.y = TERRAIN.height(at.x, at.z)
	var pole := MeshInstance3D.new()
	pole.name = "StandardPole"
	var stick := CylinderMesh.new()
	stick.top_radius = 0.05
	stick.bottom_radius = 0.06
	stick.height = 4.6
	pole.mesh = stick
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("6b4a2f")
	wood.roughness = 0.8
	pole.material_override = wood
	pole.position = at + Vector3(0, 2.3, 0)
	pole.visibility_range_end = FIGURE_RANGE
	holder.add_child(pole)
	var cloth := MeshInstance3D.new()
	cloth.name = "StandardCloth"
	var quad := QuadMesh.new()
	quad.size = Vector2(1.3, 1.7)
	cloth.mesh = quad
	var fabric := StandardMaterial3D.new()
	fabric.albedo_color = TEAM
	fabric.cull_mode = BaseMaterial3D.CULL_DISABLED
	fabric.roughness = 0.9
	cloth.material_override = fabric
	cloth.position = at + Vector3(0, 3.6, 0)
	cloth.rotation.y = PI * 0.25
	cloth.position += Basis(Vector3.UP, PI * 0.25) * Vector3(0.68, 0, 0)
	cloth.visibility_range_end = FIGURE_RANGE
	holder.add_child(cloth)
	var hem := MeshInstance3D.new()
	var band := QuadMesh.new()
	band.size = Vector2(1.3, 0.22)
	hem.mesh = band
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color("f0c64a")
	gold.cull_mode = BaseMaterial3D.CULL_DISABLED
	hem.material_override = gold
	hem.position = Vector3(0, -0.78, 0.005)
	hem.visibility_range_end = FIGURE_RANGE
	cloth.add_child(hem)


## Welcher Standort liegt unter einem Bildschirmpunkt (Banner oder Formation)? "" = keiner.
func post_at_screen(camera: Camera3D, point: Vector2, reach := 90.0) -> String:
	if camera == null:
		return ""
	var best := ""
	var best_distance := reach
	for holder in get_children():
		if not holder.has_meta("anchor"):
			continue
		var anchor: Vector3 = holder.get_meta("anchor")
		var post := str(holder.name).trim_prefix("Post_")
		for spot in [anchor, post_position(post)]:
			if camera.is_position_behind(spot):
				continue
			var distance := camera.unproject_position(spot).distance_to(point)
			if distance < best_distance:
				best_distance = distance
				best = post
	return best
