extends Node3D
## Leben in der Dorfwelt: Rauch aus Schornsteinen (ein Draw-Call), Boote mit
## den echten Mitspielern aus dem Roster, ein Fuhrwerk, Tiere auf den Weiden,
## Vogelschwärme und der echte, geriggte Lumo auf seinem Dorfrundgang.
## Reine Darstellung: die Zeit läuft nur im Bild, nie im Spielstand.
const TERRAIN = preload("res://scripts/creative/build_village_terrain.gd")
const REGION = preload("res://scripts/creative/build_settlement_region.gd")
const ART = preload("res://scripts/creative/build_village_art.gd")
const ROSTER = preload("res://scripts/games/lumo_opponent_roster.gd")
const LUMO = preload("res://scripts/characters/lumo/lumo_rigged_actor.gd")
const SMOKE_SHADER = preload("res://assets/creative/village3d/shaders/village_smoke.gdshader")
const BUDGETS := {
	"low": {"smoke": 4, "boats": 1, "birds": 6, "sheep": 6, "cows": 2, "chickens": 4, "riders": 1},
	"medium": {"smoke": 10, "boats": 2, "birds": 12, "sheep": 10, "cows": 4, "chickens": 8, "riders": 3},
	"high": {"smoke": 16, "boats": 3, "birds": 22, "sheep": 16, "cows": 6, "chickens": 12, "riders": 5},
}
const PUFFS_PER_SOURCE := 4
var tier := "medium"
var budget: Dictionary = BUDGETS.medium
var smoke: MultiMeshInstance3D
var smoke_material: ShaderMaterial
var boats: Array[Dictionary] = []
var birds: MultiMeshInstance3D
var bird_state: Array[Dictionary] = []
var herds: Array[Dictionary] = []
var lumo: Node3D
var lumo_path: Array[Vector3] = []
var lumo_target := 0
var cart: Node3D
var cart_path: Array[Vector3] = []
var cart_progress := 0.0
var clock := 0.0
var town_center := Vector3(-100, 0, 0)


func configure(quality: String) -> void:
	if smoke != null:
		return
	name = "VillageLife"
	tier = quality
	budget = BUDGETS.get(tier, BUDGETS.medium)
	_build_smoke()
	_build_boats()
	_build_birds()
	_build_herds()
	_build_cart()
	_build_lumo()
	set_meta("life_budget", budget)


func _build_smoke() -> void:
	smoke = MultiMeshInstance3D.new()
	smoke.name = "ChimneySmoke"
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_custom_data = true
	multi.mesh = quad
	multi.instance_count = int(budget.smoke) * PUFFS_PER_SOURCE
	multi.visible_instance_count = 0
	smoke.multimesh = multi
	smoke_material = ShaderMaterial.new()
	smoke_material.shader = SMOKE_SHADER
	smoke.material_override = smoke_material
	smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	smoke.extra_cull_margin = 8.0
	add_child(smoke)


func set_smoke_sources(points: Array[Vector3]) -> void:
	if smoke == null:
		return
	var count := mini(points.size(), int(budget.smoke))
	var multi := smoke.multimesh
	for source in range(count):
		for puff in range(PUFFS_PER_SOURCE):
			var index := source * PUFFS_PER_SOURCE + puff
			multi.set_instance_transform(index, Transform3D(Basis.IDENTITY, points[source]))
			multi.set_instance_custom_data(
				index, Color(float(puff) / PUFFS_PER_SOURCE + float(source) * 0.137, 0, 0, 0)
			)
	multi.visible_instance_count = count * PUFFS_PER_SOURCE
	set_meta("smoke_sources", count)


func set_night(value: float) -> void:
	if smoke_material != null:
		smoke_material.set_shader_parameter("smoke_color", Color(0.88, 0.88, 0.9).lerp(Color(0.62, 0.58, 0.66), value))


func set_town(town: Dictionary, view_focus: Vector3) -> void:
	town_center = Vector3(-REGION.TOWN_CENTER, 0, 0)
	if lumo != null:
		_plan_lumo_walk(town)
	set_meta("view_focus", view_focus)


## Roster-Figur (sitzende Fahrer-Pose) für Boote, Fuhrwerk und Steg.
func _rider(index: int) -> Node3D:
	var entries := ROSTER.all()
	if entries.is_empty():
		return null
	var entry: Dictionary = entries[posmod(index, entries.size())]
	var path := ROSTER.racing_model_path(str(entry.id), 2)
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var scene: PackedScene = load(path)
	var figure := scene.instantiate() as Node3D
	if figure == null:
		return null
	figure.name = "Rider_" + str(entry.id)
	var player := figure.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player != null:
		var clip := "kart_seated" if player.has_animation("kart_seated") else "idle"
		if player.has_animation(clip):
			player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
			player.play(clip)
			player.seek(float(index) * 0.37, true)
	for mesh in figure.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	figure.set_meta("roster_id", str(entry.id))
	return figure


func _build_boats() -> void:
	if not ART.exists("boat") or not TERRAIN.available():
		return
	for index in range(int(budget.boats)):
		var holder := Node3D.new()
		holder.name = "RiverBoat_%d" % index
		add_child(holder)
		holder.add_child(ART.instance("boat"))
		if index < int(budget.riders):
			var rider := _rider(index)
			if rider != null:
				rider.scale = Vector3.ONE * 0.72
				rider.position = Vector3(0, -0.28, 0.2)
				holder.add_child(rider)
		boats.append({"node": holder, "phase": float(index) / maxf(1.0, float(budget.boats)), "side": -1.0 if index % 2 else 1.0})


func _build_birds() -> void:
	if not ART.exists("bird"):
		return
	var count := int(budget.birds)
	var transforms: Array = []
	for index in range(count):
		transforms.append(Transform3D.IDENTITY)
		bird_state.append({
			"center": Vector3(-60.0 + float(index % 3) * 70.0, 26.0 + float(index % 5) * 2.5, -30.0 + float(index % 4) * 18.0),
			"radius": 18.0 + float(index % 7) * 4.0,
			"speed": 0.18 + float(index % 5) * 0.03,
			"phase": float(index) * 0.7,
		})
	birds = ART.batch(self, "Birds", "bird", transforms, 0.0, false)
	if birds != null:
		birds.extra_cull_margin = 120.0


## Weiden in flachen Wiesen außerhalb der Ortsteile, nahe am Spieler-Ort.
func _build_herds() -> void:
	if not TERRAIN.available():
		return
	var spots := _pasture_spots()
	var kinds := [["sheep", int(budget.sheep), 0.95], ["cow", int(budget.cows), 1.0], ["chicken", int(budget.chickens), 1.1]]
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	for spec in kinds:
		if not ART.exists(spec[0]) or spots.is_empty():
			continue
		var animals: Array[Dictionary] = []
		var transforms: Array = []
		for index in range(int(spec[1])):
			var spot: Vector3 = spots[(index + kinds.find(spec)) % spots.size()]
			var at := spot + Vector3(rng.randf_range(-7, 7), 0, rng.randf_range(-5, 5))
			at.y = TERRAIN.height(at.x, at.z)
			animals.append({"home": at, "yaw": rng.randf() * TAU, "phase": rng.randf() * 10.0})
			transforms.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * float(spec[2])), at))
		var node := ART.batch(self, "Herd_" + spec[0], spec[0], transforms, 160.0, true)
		if node != null:
			herds.append({"node": node, "animals": animals, "scale": float(spec[2]), "kind": spec[0]})


func _pasture_spots() -> Array[Vector3]:
	var result: Array[Vector3] = []
	for candidate in [
		Vector2(-120, 98), Vector2(-60, 97), Vector2(-196, 20), Vector2(-160, 99), Vector2(-30, -97),
		Vector2(-196, -40), Vector2(-90, -98)
	]:
		var h := TERRAIN.height(candidate.x, candidate.y)
		if h > TERRAIN.WATER_LEVEL + 1.0 and TERRAIN.steepness(candidate.x, candidate.y) < 0.12:
			result.append(Vector3(candidate.x, h, candidate.y))
	return result


## Fuhrwerk mit Roster-Kutscher auf der Landstraße zur mittleren Brücke.
func _build_cart() -> void:
	if not ART.exists("cart") or not TERRAIN.available():
		return
	cart = Node3D.new()
	cart.name = "VillageHayCart"
	add_child(cart)
	cart.add_child(ART.instance("cart"))
	var driver := _rider(3)
	if driver != null:
		driver.scale = Vector3.ONE * 0.62
		driver.position = Vector3(0, 0.55, 1.15)
		driver.rotation.y = PI
		cart.add_child(driver)
	for x in [-62.0, -44.0, -30.0, -18.0, -11.0]:
		cart_path.append(Vector3(x, 0, -2.65))


func _build_lumo() -> void:
	lumo = LUMO.new()
	lumo.name = "VillageLumo"
	add_child(lumo)
	if not lumo.is_usable():
		return
	var skeleton: Skeleton3D = lumo.skeleton
	var lowest := INF
	var highest := -INF
	for bone in range(skeleton.get_bone_count()):
		var rest: Vector3 = skeleton.get_bone_global_rest(bone).origin
		lowest = minf(lowest, rest.y)
		highest = maxf(highest, rest.y)
	var span := highest - lowest
	if span > 0.2 and span <= 15.0:
		var factor := clampf(1.25 / span, 0.08, 3.0)
		lumo.scale = Vector3.ONE * factor
		lumo.set_meta("foot_offset", -lowest * factor)


func _plan_lumo_walk(_town: Dictionary) -> void:
	if not lumo_path.is_empty():
		return
	# A loop along the painted main lanes around the founders' first plots.
	var c := town_center
	for offset in [Vector2(-7.95, -2.65), Vector2(7.95, -2.65), Vector2(7.95, 2.65), Vector2(2.65, 7.95), Vector2(-2.65, 7.95), Vector2(-7.95, 2.65)]:
		lumo_path.append(Vector3(c.x + offset.x, 0, c.z + offset.y))
	lumo.position = lumo_path[0]


func advance(delta: float, camera_position: Vector3) -> void:
	clock += delta
	_advance_boats()
	_advance_birds()
	_advance_herds()
	_advance_cart(delta)
	_advance_lumo(delta)
	set_meta("camera_position", camera_position)


func _advance_boats() -> void:
	for boat in boats:
		var t := fmod(clock * 0.006 + float(boat.phase), 1.0)
		var forward := t < 0.5
		var u := t * 2.0 if forward else (1.0 - t) * 2.0
		var z := lerpf(-125.0, 112.0, u)
		var x := TERRAIN.river_center(z) + float(boat.side) * 2.4
		var node: Node3D = boat.node
		node.position = Vector3(x, TERRAIN.WATER_LEVEL + 0.05 + sin(clock * 1.7 + float(boat.phase) * 9.0) * 0.04, z)
		var ahead := TERRAIN.river_center(z + (2.0 if forward else -2.0)) + float(boat.side) * 2.4
		node.rotation = Vector3(sin(clock * 1.3) * 0.03, atan2(ahead - x, 2.0 if forward else -2.0), sin(clock * 1.1) * 0.04)


func _advance_birds() -> void:
	if birds == null:
		return
	var multi := birds.multimesh
	for index in range(bird_state.size()):
		var state: Dictionary = bird_state[index]
		var angle := clock * float(state.speed) + float(state.phase)
		var center: Vector3 = state.center
		var at := center + Vector3(cos(angle) * float(state.radius), sin(angle * 2.0) * 1.5, sin(angle) * float(state.radius))
		var heading := Vector3(-sin(angle), 0, cos(angle))
		var flap := 0.55 + 0.45 * absf(sin(clock * 9.0 + float(state.phase) * 3.0))
		var basis := Basis.looking_at(heading, Vector3.UP).scaled(Vector3(flap * 2.4, 2.4, 2.4))
		multi.set_instance_transform(index, Transform3D(basis, at))


func _advance_herds() -> void:
	for herd in herds:
		var multi: MultiMesh = herd.node.multimesh
		var animals: Array = herd.animals
		for index in range(animals.size()):
			var animal: Dictionary = animals[index]
			var phase := clock * 0.12 + float(animal.phase)
			var home: Vector3 = animal.home
			var at := home + Vector3(sin(phase) * 1.4, 0, cos(phase * 0.7) * 1.1)
			at.y = TERRAIN.height(at.x, at.z) + absf(sin(clock * (5.0 if herd.kind == "chicken" else 1.6) + float(animal.phase))) * (0.05 if herd.kind == "chicken" else 0.015)
			var yaw := float(animal.yaw) + sin(phase) * 0.8
			multi.set_instance_transform(index, Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * float(herd.scale)), at))


func _advance_cart(delta: float) -> void:
	if cart == null or cart_path.size() < 2:
		return
	cart_progress = fmod(cart_progress + delta * 0.035, 2.0)
	var u := cart_progress if cart_progress < 1.0 else 2.0 - cart_progress
	var span := float(cart_path.size() - 1)
	var f := u * span
	var i := mini(int(f), cart_path.size() - 2)
	var a: Vector3 = cart_path[i]
	var b: Vector3 = cart_path[i + 1]
	var at := a.lerp(b, f - float(i))
	at.y = TERRAIN.height(at.x, at.z) + 0.02
	cart.position = at
	var dir := (b - a) if cart_progress < 1.0 else (a - b)
	cart.rotation.y = atan2(dir.x, dir.z)


func _advance_lumo(delta: float) -> void:
	if lumo == null or not lumo.is_usable() or lumo_path.is_empty():
		return
	var target: Vector3 = lumo_path[lumo_target]
	var flat := Vector3(target.x - lumo.position.x, 0, target.z - lumo.position.z)
	var distance := flat.length()
	if distance < 0.3:
		lumo_target = (lumo_target + 1) % lumo_path.size()
		return
	var speed := 1.25
	var step := flat.normalized() * minf(distance, speed * delta)
	lumo.position += step
	lumo.position.y = TERRAIN.height(lumo.position.x, lumo.position.z) + float(lumo.get_meta("foot_offset", 0.0))
	lumo.rotation.y = lerp_angle(lumo.rotation.y, atan2(flat.x, flat.z), minf(1.0, delta * 6.0))
	lumo.set_locomotion_speed(speed)
