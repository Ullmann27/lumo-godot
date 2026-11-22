extends Node3D
## Die Modelle benutzen echte Meter und dieselben drei Detailstufen wie die Werkstatt-Bilder.
## Module für die beweglichen Hindernisse und die Streckenkulisse teilen ihre Mesh-Ressourcen.
const DIRECTORY := "res://assets/kart/production/windwerk/"
const NEAR := 42.0
const MID := 105.0
const FAR := 420.0
static var _models: Dictionary = {}

var _rotors: Array[Node3D] = []
var _rotor_rates: Array[float] = []
var _whales: Array[Node3D] = []
var _whale_rest: Array[Transform3D] = []


static func module(id: String, lightweight: bool = false) -> Node3D:
	if not _models.has(id):
		_models[id] = load(DIRECTORY + id + ".glb")
	var packed := _models[id] as PackedScene
	var part := packed.instantiate() as Node3D
	var near_limit := 24.0 if lightweight else NEAR
	var mid_limit := 68.0 if lightweight else MID
	var far_limit := 230.0 if lightweight else FAR
	for mesh: MeshInstance3D in part.find_children("*", "MeshInstance3D", true, false):
		var level := str(mesh.name).right(1).to_int()
		mesh.visibility_range_begin = [0.0, near_limit, mid_limit][level]
		mesh.visibility_range_end = [near_limit, mid_limit, far_limit][level]
		# Precise cuts avoid two opaque surfaces fighting each other during a fade.
		mesh.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		if level == 2 or lightweight and level == 1:
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return part


static func build(world) -> void:
	var art := new()
	art.name = "WindwerkKulissen"
	world.add_child(art)
	art._arrange(world)


func _place(world, id: String, metres: float, lateral: float, size: float, yaw: float,
		surface: String, ground: Callable) -> Node3D:
	var at: Vector3 = world.position_at(metres, lateral)
	var track_basis: Basis = world.frame(metres)
	var basis := track_basis
	if surface != "road":
		# Raised machines and workshops stand on timber wharves. Trees and the
		# distant wind farm stay upright on the valley floor even on banked bends.
		basis = Basis(Vector3.UP, track_basis.get_euler().y)
		var floor_y: float = ground.call(at.x, at.z)
		if surface == "valley":
			at.y = floor_y - .12
		else:
			at.y -= 1.3
			_wharf(world, at, basis, size, floor_y, id)
	var part := module(id, world.low_detail)
	part.name = id + "_%d_%d" % [roundi(metres), roundi(lateral)]
	part.transform = Transform3D(basis.rotated(basis.y, yaw).scaled_local(Vector3.ONE * size), at)
	add_child(part)
	var rotor := part.find_child("Rotor", true, false) as Node3D
	if rotor != null:
		_rotors.append(rotor)
		_rotor_rates.append(.65 + fposmod(metres * .013, .55) if id == "turbine" else -.74)
		rotor.rotation.z = fposmod(metres * .091, TAU)
	return part


func _wharf(world, pos: Vector3, basis: Basis, scale_factor: float, floor_y: float, id: String) -> void:
	var w := (9.2 if id == "mill" else 6.0) * scale_factor
	var depth := (7.0 if id == "mill" else 5.0) * scale_factor
	world._prop("box", pos - Vector3.UP * .28, Vector3(w, .58, depth), Color("966545"), basis)
	for s in [-1, 1]:
		for end in [-1, 1]:
			var top := pos + basis * Vector3(s * w * .41, -.49, end * depth * .41)
			var bottom := Vector3(top.x, floor_y - 1.0, top.z)
			world._beam(bottom, top, .50 * scale_factor, Color("756047"))
		var a := pos + basis * Vector3(s * w * .41, -.62, -depth * .41)
		var b := pos + basis * Vector3(s * w * .41, -minf(6, pos.y - floor_y), depth * .41)
		world._beam(a,b,.31 * scale_factor,Color("916d4c"))


func _arrange(world) -> void:
	var terrain = load("res://scripts/games/windwerk/kart_windwerk_world.gd")
	var ground := Callable(terrain, "ground_height")
	for at: float in [22.0,2810.0]:
		var station := _place(world,"station",at,0,1,0,"road",ground)
		var sign := Label3D.new()
		sign.name = "Bahnhofsschild"
		sign.font = preload("res://assets/fonts/Nunito-Black.ttf")
		sign.font_size = 68
		sign.pixel_size = .010
		sign.text = "LUMOS WINDWERK" if at < 100 else "MÜHLENBAHNHOF"
		sign.modulate = Color("ffdf99")
		sign.outline_size = 0
		sign.position = Vector3(0,8.48,1.313)
		sign.double_sided = false
		sign.visibility_range_end = 130
		station.add_child(sign)
	for i in range(14):
		_place(world,"bridge",1270.0 + i * 12.6,0,1,0,"road",ground)
	_place(world,"mill",155,-19,1.52,.86,"wharf",ground)
	_place(world,"mill",2730,21,1.73,-.92,"wharf",ground)
	for station: Vector3 in [Vector3(85,17,1.13),Vector3(537,-18,1.26),Vector3(705,18,1.36),
			Vector3(935,-16,1.20),Vector3(1125,19,1.28),Vector3(1620,-20,1.16),
			Vector3(2048,17,1.31),Vector3(2170,-19,1.22),Vector3(2473,17,1.30),
			Vector3(2870,-18,1.20)]:
		_place(world,"workshop",station.x,station.y,station.z,-signf(station.y)*.98,"wharf",ground)
	# Tethered festival balloons beside the three approaches, at driver's eye
	# level on the viaduct. The camera can see the last one after the third gate.
	for site in [Vector3(750, -17, 5), Vector3(1525, 21, 7), Vector3(2485, -16, 5)]:
		var whale := _place(world, "wind_whale", site.x, site.y, 1.60, -signf(site.y) * .86, "road", ground)
		whale.position.y += site.z
		_whales.append(whale)
		_whale_rest.append(whale.transform)
	for district: float in [245.0,1690.0]:
		for i in range(7):
			var at := district + 48.0 * i
			var direction := -1.0 if i % 2 == 0 else 1.0
			_place(world,"turbine",at,direction * (23.0 + i % 3 * 5),1.50 + .12 * (i % 3),
				-direction * .63,"valley",ground)
			if i % 2 == 0:
				_place(world,"turbine",at + 20,-direction * (55.0+i),1.85,
						direction * .51,"valley",ground)
	for i in range(68):
		if world.low_detail and i % 4 >= 2:
			continue
		var at := i * 43.4
		var side := -1.0 if i % 2 == 0 else 1.0
		var width := 23.0 + fposmod(17.0*i,42.0)
		_place(world,"orchard",at,side*width,1.32+fposmod(.63*i,1.49),
				fposmod(.73*i,TAU),"valley",ground)
	set_process(not _rotors.is_empty())


func _process(delta: float) -> void:
	for i in _rotors.size():
		_rotors[i].rotate_z(_rotor_rates[i] * delta)


## A gentle bob at the side of the course. Each balloon tips its nose after
## the child's three-signal combo, watching the same race clock as the gates.
func update_wind_whales(seconds: float, celebration: float, reduced_motion: bool) -> void:
	for i in _whales.size():
		var rest := _whale_rest[i]
		if not reduced_motion:
			var wave := sin(seconds * .82 + i * 2.4)
			rest.origin.y += wave * .42
			var nod := sin(clampf(celebration / 2.1, 0.0, 1.0) * PI) * .28
			rest.basis = rest.basis.rotated(rest.basis.z.normalized(), wave * .035 + nod)
		_whales[i].transform = rest
