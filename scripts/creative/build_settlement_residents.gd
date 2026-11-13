extends Node3D
## Original village friends and a bounded crowd, driven by the saved town state.
## Animation time is advanced by the world, so pause cannot move residents or deliveries.
const REGION = preload("res://scripts/creative/build_settlement_region.gd")
const KIT = preload("res://scripts/creative/creative_kit.gd")
const FRIENDS := [
	preload("res://assets/creative/village/nelli_rabbit.glb"),
	preload("res://assets/creative/village/bruno_beaver.glb"),
	preload("res://assets/creative/village/tilda_duck.glb")
]
const MAX_VISIBLE_RESIDENTS := 18
const VISIBLE_RADIUS := 72.0
var _kit := KIT.new()
var _town: Dictionary = {}
var _opponent := false
var _focus := Vector3(-100, 0, 0)
var _actors: Array[Dictionary] = []
var _signature := ""
var _time := 0.0
var _cart: Node3D
var _wheels: Array[Node3D] = []
var _cart_home := Vector3.ZERO
var _cart_moving := false
var _crowd: Node3D


func configure() -> void:
	if _crowd != null:
		return
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
		var home := REGION.plot_position(int(value.get("plot", 4)), _opponent)
		if Vector2(home.x - _focus.x, home.z - _focus.z).length_squared() <= VISIBLE_RADIUS * VISIBLE_RADIUS:
			houses.append(value)
	houses.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return REGION.plot_position(int(a.plot), _opponent).distance_squared_to(_focus) < REGION.plot_position(int(b.plot), _opponent).distance_squared_to(_focus))
	var signature := str(houses) + str(_town.get("households", [])) + str(_town.get("population", 2)) + str(market_plot) + str(_opponent)
	_cart_moving = not _town.get("deliveries", []).is_empty()
	if signature == _signature:
		return
	_signature = signature
	for child in _crowd.get_children():
		_crowd.remove_child(child)
		child.queue_free()
	_actors.clear()
	_wheels.clear()
	_cart = null
	var represented := 0
	var population := maxi(0, int(_town.get("population", 2)))
	for house in houses:
		if represented >= mini(MAX_VISIBLE_RESIDENTS, population):
			break
		var home := REGION.plot_position(int(house.plot), _opponent)
		var adults := 1
		var children := 0
		for household in _town.get("households", []):
			if household is Dictionary and str(household.get("building_id", "")) == str(house.get("id", "")):
				adults = clampi(int(household.get("adults", 1)), 1, 2)
				children = clampi(int(household.get("children", 0)), 0, 3)
				break
		for member in range(adults + children):
			if represented >= mini(MAX_VISIBLE_RESIDENTS, population):
				break
			_add_resident(home, represented % 2, member >= adults, represented)
			represented += 1
	# The founders have a visible camp before their first completed home.
	var center := Vector3(REGION.TOWN_CENTER if _opponent else -REGION.TOWN_CENTER, 0, 5.3)
	if houses.is_empty() and center.distance_squared_to(_focus) < VISIBLE_RADIUS * VISIBLE_RADIUS:
		for member in range(mini(2, population)):
			_add_resident(center, member, false, member)
	if market_plot >= 0:
		_cart_home = REGION.plot_position(market_plot, _opponent) + Vector3(0, 0.08, REGION.SPACING * 0.5)
		if _cart_home.distance_squared_to(_focus) <= VISIBLE_RADIUS * VISIBLE_RADIUS:
			_build_cart()
	set_meta("visible_residents", _actors.size())
	set_meta("total_population", population)
	set_meta("crowd_is_representative", population > _actors.size())


func _add_resident(home: Vector3, friend_index: int, child: bool, index: int) -> void:
	var holder := Node3D.new()
	holder.name = ("Child_" if child else "Resident_") + str(index)
	_crowd.add_child(holder)
	var actor := FRIENDS[friend_index].instantiate() as Node3D
	holder.add_child(actor)
	actor.scale = Vector3.ONE * (0.52 if child else 0.79)
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
	var base := home + Vector3(-1.5 + float(index % 3) * 0.75, 0.06, REGION.SPACING * 0.5)
	holder.position = base
	holder.set_meta("village_role", "Nelli · Anbauen" if friend_index == 0 else "Bruno · Bauen")
	holder.set_meta("is_child", child)
	_actors.append({"holder": holder, "animation": animation, "base": base, "phase": float(index) * 1.37, "child": child})


func _build_cart() -> void:
	_cart = Node3D.new()
	_cart.name = "TildasLieferwagen"
	_crowd.add_child(_cart)
	_cart.position = _cart_home
	_kit.box(_cart, Vector3(0, 0.53, 0), Vector3(1.8, 0.70, 0.95), Color("e9b24e"))
	_kit.box(_cart, Vector3(0.52, 1.03, 0), Vector3(0.70, 0.70, 0.90), Color("67b8b9"))
	_kit.box(_cart, Vector3(0.55, 1.11, -0.46), Vector3(0.52, 0.37, 0.025), Color("b7e1e5"))
	_kit.box(_cart, Vector3(-0.40, 0.91, 0), Vector3(0.68, 0.11, 0.93), Color("9f7543"))
	for x in [-0.62, 0.62]:
		for z in [-0.51, 0.51]:
			var wheel := _kit.cylinder(_cart, Vector3(x, 0.27, z), 0.24, 0.14, Color("445661"))
			wheel.rotation.x = PI * 0.5
			_wheels.append(wheel)
	for x in [-0.58, -0.20]:
		_kit.box(_cart, Vector3(x, 1.09, 0.03), Vector3(0.32, 0.34, 0.58), Color("c5975b"))
		for z in [-0.14, 0.12]:
			_kit.sphere(_cart, Vector3(x, 1.29, z), Vector3(0.14, 0.15, 0.14), Color("ed913d"))
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
		holder.position = entry.base + Vector3(displacement, 0, 0)
		holder.rotation.y = PI * 0.5 if cos(phase) > 0 else -PI * 0.5
		var animation: AnimationPlayer = entry.animation
		if animation != null:
			animation.advance(step * (0.65 if bool(entry.child) else 0.48))
	if _cart != null and _cart_moving:
		_cart.position = _cart_home + Vector3(sin(_time * 0.20) * 3.0, 0, 0)
		for wheel in _wheels:
			wheel.rotate_y(step * 2.2)


func debug_snapshot() -> Dictionary:
	return {"visible_residents": _actors.size(), "resident_limit": MAX_VISIBLE_RESIDENTS, "has_delivery_cart": _cart != null, "clock": _time}
