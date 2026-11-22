extends Node3D
## Original village friends and a bounded crowd, driven by the saved town state.
## Animation time is advanced by the world, so pause cannot move residents or deliveries.
const REGION = preload("res://scripts/creative/build_settlement_region.gd")
const KIT = preload("res://scripts/creative/creative_kit.gd")
const ART = preload("res://scripts/creative/build_village_art.gd")
const FRIENDS := [
	preload("res://assets/creative/village/nelli_rabbit.glb"),
	preload("res://assets/creative/village/bruno_beaver.glb"),
	preload("res://assets/creative/village/tilda_duck.glb")
]
const YARDS = preload("res://scripts/creative/build_village_yards.gd")
const FOUNDER_SCENES := [
	preload("res://assets/creative/village/carpenter_village.glb"),
	preload("res://assets/creative/village/lion_village.glb"),
]
const ROLES := ["Nelli · Gärtnerin", "Bruno · Baumeister", "Tilda · Händlerin", "Mara · Zimmerin", "Ari · Löwe"]
const MAX_VISIBLE_RESIDENTS := 18
const VISIBLE_RADIUS := 72.0
var _limit := MAX_VISIBLE_RESIDENTS
var _kit := KIT.new()
var _town: Dictionary = {}
var _opponent := false
var _focus := Vector3(-100, 0, 0)
var _actors: Array[Dictionary] = []
var _crossed_yards := {}
var _signature := ""
var _time := 0.0
var _cart: Node3D
var _wheels: Array[Node3D] = []
var _cart_home := Vector3.ZERO
var _cart_moving := false
var _crowd: Node3D


func configure(quality := "high") -> void:
	if _crowd != null:
		return
	_limit = {"low": 8, "medium": 12, "high": MAX_VISIBLE_RESIDENTS}.get(quality, 12)
	_crowd = Node3D.new()
	_crowd.name = "VillageFamilies"
	add_child(_crowd)


func sync(town: Dictionary, opponent := false) -> void:
	configure()
	_town = town.duplicate(true)
	_opponent = opponent
	_refresh()


func set_focus(at: Vector3) -> void:
	if _focus.distance_squared_to(at) < 36.0:
		return
	_focus = at
	_refresh()


func _refresh() -> void:
	if _town.is_empty():
		return
	var houses: Array[Dictionary] = []
	var market_plot := -1
	for value in _town.get("buildings", []):
		if not value is Dictionary:
			continue
		if str(value.get("kind", "")) == "market":
			market_plot = int(value.get("plot", 4))
		if str(value.get("kind", "")) != "house":
			continue
		var home := YARDS.building_at(value, _opponent)
		if (
			Vector2(home.x - _focus.x, home.z - _focus.z).length_squared()
			<= VISIBLE_RADIUS * VISIBLE_RADIUS
		):
			houses.append(value)
	houses.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return (
				YARDS.building_at(a, _opponent).distance_squared_to(_focus)
				< YARDS.building_at(b, _opponent).distance_squared_to(_focus)
			)
	)
	var signature := (
		str(houses)
		+ str(_town.get("households", []))
		+ str(_town.get("population", 2))
		+ str(_town.get("yards", []))
		+ str(market_plot)
		+ str(_opponent)
	)
	_cart_moving = not _town.get("deliveries", []).is_empty()
	if signature == _signature:
		return
	_signature = signature
	for child in _crowd.get_children():
		_crowd.remove_child(child)
		child.queue_free()
	_actors.clear()
	_crossed_yards.clear()
	_wheels.clear()
	_cart = null
	var represented := 0
	var population := maxi(0, int(_town.get("population", 2)))
	for house in houses:
		if represented >= mini(_limit, population):
			break
		var home := YARDS.building_at(house, _opponent)
		var adults := 1
		var children := 0
		for household in _town.get("households", []):
			if (
				household is Dictionary
				and str(household.get("building_id", "")) == str(house.get("id", ""))
			):
				adults = clampi(int(household.get("adults", 1)), 1, 2)
				children = clampi(int(household.get("children", 0)), 0, 3)
				break
		for member in range(adults + children):
			if represented >= mini(_limit, population):
				break
			var identity := posmod(int(str(house.id).trim_prefix("b")) - 1 + member, ROLES.size())
			_add_resident(home, identity, member >= adults, represented)
			represented += 1
	# The two founders still live at camp while the households occupy their own homes.
	var center := Vector3(REGION.TOWN_CENTER if _opponent else -REGION.TOWN_CENTER, 0, 5.3)
	if center.distance_squared_to(_focus) < VISIBLE_RADIUS * VISIBLE_RADIUS:
		for member in range(mini(2, mini(population, _limit) - represented)):
			_add_resident(center, 3 + member, false, represented + member)
	if market_plot >= 0:
		_cart_home = (
			REGION.plot_position(market_plot, _opponent) + Vector3(0, 0.08, REGION.SPACING * 0.5)
		)
		if _cart_home.distance_squared_to(_focus) <= VISIBLE_RADIUS * VISIBLE_RADIUS:
			_build_cart()
	set_meta("visible_residents", _actors.size())
	set_meta("total_population", population)
	set_meta("crowd_is_representative", population > _actors.size())


func _add_resident(home: Vector3, friend_index: int, child: bool, index: int) -> void:
	var holder := Node3D.new()
	holder.name = ("Child_" if child else "Resident_") + str(index)
	_crowd.add_child(holder)
	var scene: PackedScene = FRIENDS[friend_index] if friend_index < 3 else FOUNDER_SCENES[friend_index - 3]
	var actor := scene.instantiate() as Node3D
	holder.add_child(actor)
	actor.scale = Vector3.ONE * ((0.65 if child else 1.0) if friend_index >= 3 else (0.52 if child else 0.79))
	var animation := actor.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animation != null:
		animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		for animation_name in animation.get_animation_list():
			if "Walk" in animation_name:
				# Imported resources are shared by all residents; loop metadata is immutable.
				animation.get_animation(animation_name).loop_mode = Animation.LOOP_LINEAR
				animation.play(animation_name)
				animation.advance(float(index % 8) * 0.11)
				break
	var base := home + Vector3(-1.3 + float(index % 3) * 0.95, 0.06, REGION.SPACING * 0.5)
	var axis := Vector3.RIGHT
	for yard in _town.get("yards", []):
		var enclosure := YARDS.bounds(yard)
		if enclosure.grow(0.5).has_point(Vector2(base.x, base.z)) or enclosure.has_point(Vector2(home.x, home.z)):
			var door := YARDS.gate(yard)
			var camp := Vector2(-REGION.TOWN_CENTER, 5.3)
			var key := int(yard.a)
			if not _crossed_yards.has(key) and (friend_index == 4 or not enclosure.has_point(camp)):
				base = Vector3(door.x, 0, door.y)
				axis = Vector3.BACK
				_crossed_yards[key] = true
			else:
				# Interior lanes leave the entrance to the resident who is passing through.
				var lane := enclosure.grow(-.48)
				base.x = clampf(base.x, lane.position.x + 1.3, lane.end.x - 1.3)
				base.z = clampf(base.z, lane.position.y, lane.end.y)
				if Vector2(base.x, base.z).distance_to(door) < 2.4:
					base.x = lane.end.x - 1.3 if door.x < lane.get_center().x else lane.position.x + 1.3
			break
	base.y = REGION.ground(base.x, base.z)
	var limbs: Array[Node3D] = []
	for limb_name in ["ForeL", "ForeR", "HindL", "HindR", "Tail"]:
		var limb := actor.find_child(limb_name, true, false) as Node3D
		if limb != null:
			limbs.append(limb)
	holder.position = base
	holder.set_meta("village_role", ROLES[friend_index])
	holder.set_meta("is_child", child)
	_actors.append(
		{
			"holder": holder,
			"animation": animation,
			"base": base,
			"axis": axis,
			"limbs": limbs,
			"phase": float(index) * 1.37,
			"child": child
		}
	)


func _build_cart() -> void:
	_cart = Node3D.new()
	_cart.name = "TildasLieferwagen"
	_crowd.add_child(_cart)
	_cart.position = _cart_home
	if ART.exists("cart"):
		# The authored Blender hay cart (with shafts and wheels) from the village set.
		var wagon := ART.instance("cart")
		wagon.rotation.y = PI * 0.5
		_cart.add_child(wagon)
	else:
		_kit.box(_cart, Vector3(0, 0.53, 0), Vector3(1.8, 0.70, 0.95), Color("e9b24e"))
	var merchant := FRIENDS[2].instantiate() as Node3D
	merchant.name = "Tilda"
	merchant.scale = Vector3.ONE * 0.64
	merchant.position = Vector3(-1.35, 0, 0)
	_cart.add_child(merchant)
	var sign := Label3D.new()
	sign.text = "TILDA · FRISCHE LIEFERUNG"
	sign.position = Vector3(0, 2.1, 0)
	sign.font_size = 34
	sign.pixel_size = 0.008
	sign.modulate = Color("fff5d6")
	sign.outline_modulate = Color("314954")
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.visibility_range_end = 38
	_cart.add_child(sign)


func advance(delta: float, paused := false) -> void:
	if paused or delta <= 0:
		return
	var step := minf(delta, 0.1)
	_time += step
	for entry in _actors:
		var holder: Node3D = entry.holder
		var phase := _time * 0.38 + float(entry.phase)
		var displacement := sin(phase) * 1.25
		var axis: Vector3 = entry.axis
		holder.position = entry.base + axis * displacement
		holder.position.y = REGION.ground(holder.position.x, holder.position.z)
		holder.rotation.y = atan2(axis.x, axis.z) + (PI if cos(phase) < 0 else 0.0)
		var stride := sin(_time * 5.4 + entry.phase) * clampf(absf(cos(phase)) * 1.5, 0, 1)
		var limbs: Array = entry.limbs
		for i in range(mini(4, limbs.size())):
			limbs[i].rotation.x = stride * (.20 if i in [0, 3] else -.20)
		if limbs.size() > 4:
			limbs[4].rotation.y = sin(_time * 1.7 + entry.phase) * .18
		var animation: AnimationPlayer = entry.animation
		if animation != null:
			animation.advance(step * (0.65 if bool(entry.child) else 0.48))
	if _cart != null and _cart_moving:
		_cart.position = _cart_home + Vector3(sin(_time * 0.20) * 3.0, 0, 0)
		for wheel in _wheels:
			wheel.rotate_y(step * 2.2)


func debug_snapshot() -> Dictionary:
	return {
		"visible_residents": _actors.size(),
		"resident_limit": _limit,
		"has_delivery_cart": _cart != null,
		"clock": _time
	}
