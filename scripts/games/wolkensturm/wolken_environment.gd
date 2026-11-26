extends "res://scripts/games/kart_signature/kart_signature_environment.gd"
## Wolkensturm – Himmelsmetropole: Wolkenmeer, schwebende Inseln, Hochhäuser, Glastunnel,
## Holobrücke, Windkanal, Sternenturm, Lufttaxi und das Gewitter in der Ferne.
## Fahrbahn und Kollision: kart_signature_world.gd; Bauwerke: wolken_landmarks.gd.
## Physik der Effekte: Der Blitz ist sofort zu sehen, der Donner kommt Entfernung/343 m/s
## später; Blitze schlagen nur weit weg (≥ 200 m) in die Wolkendecke ein. Wolken ziehen mit
## dem Höhenwind, schwebende Plattformen pendeln langsam (Auftrieb gegen Gewicht).
const DIR: String = "res://assets/kart/signature/wolkensturm/"
const CLOUD_SHADER = preload("res://assets/shaders/signature/signature_cloud_sea.gdshader")
const LANDMARKS = preload("res://scripts/games/wolkensturm/wolken_landmarks.gd")
const PASSAGES = preload("res://scripts/games/kart_passages.gd")
const SOUND_SPEED: float = 343.0
const WIND: Vector3 = Vector3(5.0, 0.0, 1.5)
const LOOK: Dictionary = {
	"zenith": Color("2f74cf"),
	"horizon": Color("d7ebff"),
	"ground": Color("eef4fb"),
	"ground_horizon": Color("dfeaf7"),
	"sun_color": Color("fff3dc"),
	"sun_energy": 1.15,
	"sun_rotation": Vector3(-52, -30, 0),
	"ambient": Color("c9dcf5"),
	"ambient_energy": 0.42,
	"fog": Color("d4e4f6"),
	"fog_density": 0.0005,
	"exposure": 0.86,
	"glow": 0.75,
	"glow_threshold": 1.0,
	"saturation": 1.14,
	"contrast": 1.08,
	"aerial": 0.2,
	"fog_sky": 0.3,
	"fill_color": Color("b6c8ff"),
	"fill_energy": 0.2,
}

## Ansagen [Meter, Schlüssel, Text] – vor Windkanal, Spirale und Wolkentauchgang.
const GUIDE: Array = [
	[180.0, "sprung", "Gleich der Wolkensprung! Gas halten – unten fängt dich die Holo-Rampe."],
	[1020.0, "wind", "Rückenwind im Windkanal! Der Aufwind trägt dich weit über die Schanze."],
	[1330.0, "spirale", "Die Sternenturm-Spirale: einmal rundherum und hoch über die Einfahrt!"],
	[2470.0, "wolken", "Ab in die Wolken! Die Leuchtlinien am Rand zeigen dir den Weg."],
]

var cloud_material: ShaderMaterial
var platforms: Array[Node3D] = []
var platform_rest: Array[Vector3] = []
var rotors: Array[Node3D] = []
var bolts: Array[MeshInstance3D] = []
var flash_light: DirectionalLight3D
var storm_clouds: MultiMeshInstance3D
var taxis: Array[Node3D] = []
var storm_level: float = 0.0
var next_bolt: float = 4.0
var bolt_left: float = 0.0
var pending_thunder: Array[float] = []
var storm_time: float = 0.0


func _scene() -> void:
	_lighting(LOOK)
	_cloud_sea()
	LANDMARKS.build(self)
	_storm()
	_taxi()
	parts["lightning"] = 0


# ------------------------------------------------------------------ Wolken


func _cloud_sea() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(4000, 4000)
	cloud_material = shader_material(CLOUD_SHADER, {"drift": Vector2(WIND.x, WIND.z)})
	var sea := mesh_node("Wolkenmeer", plane, cloud_material, 0.0, false)
	sea.position = Vector3(
		world.position_at(1600.0).x, float(course.CLOUD_DECK), world.position_at(1600.0).z
	)
	# Haufenwolken, die aus dem Wolkenmeer ragen, und Wolkenbänke im Tauchgang.
	var tops: Array = []
	for i in range(28):
		var d: float = float(i) * float(world.length) / 28.0 + 37.0
		var side: float = 1.0 if i % 2 == 0 else -1.0
		var at: Vector3 = world.position_at(d, side * (60.0 + fposmod(d * 0.37, 90.0)))
		tops.append(Vector4(at.x, float(course.CLOUD_DECK) + 4.0, at.z, 18.0))
	puffs("Wolkenberge", tops, 7, Color(1.0, 1.0, 1.0, 0.85), 42.0, 26.0, 0.012, false, WIND)
	var bank: Array = []
	for d in range(2530, 2810, 24):
		for side in [-1.0, 1.0]:
			# Seitlich der Fahrbahn und leicht darunter: die Straße bleibt lesbar.
			var at: Vector3 = world.position_at(float(d), side * 15.0)
			bank.append(Vector4(at.x, at.y - 3.0, at.z, 5.0))
	puffs("Wolkenbank", bank, 3, Color(0.97, 0.98, 1.0, 0.3), 14.0, 8.0, 0.03, false, WIND * 0.3)


# ------------------------------------------------------------------ Gewitter


func _storm() -> void:
	# Gewitterfront im Westen: dunkle Türme aus Wolken, 230–300 m neben der Strecke.
	var dark: Array = []
	for i in range(8):
		var d: float = float(i) * float(world.length) / 8.0 + 120.0
		var at: Vector3 = world.position_at(d, -250.0)
		dark.append(Vector4(at.x, float(course.CLOUD_DECK) + 20.0, at.z, 30.0))
	storm_clouds = puffs(
		"Gewitterwolken",
		dark,
		9,
		Color(0.4, 0.43, 0.56, 0.7),
		90.0,
		55.0,
		0.008,
		false,
		WIND * 0.5
	)
	var bolt_material := StandardMaterial3D.new()
	bolt_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bolt_material.albedo_color = Color(0.85, 0.92, 1.0)
	bolt_material.emission_enabled = true
	bolt_material.emission = Color(0.7, 0.85, 1.0)
	bolt_material.emission_energy_multiplier = 6.0
	bolt_material.disable_fog = true
	bolt_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i in range(3):
		var bolt := mesh_node("Blitz%d" % i, _bolt_mesh(i), bolt_material, 0.0, false)
		bolt.visible = false
		bolts.append(bolt)
	flash_light = DirectionalLight3D.new()
	flash_light.name = "Blitzlicht"
	flash_light.light_color = Color("dfe9ff")
	flash_light.light_energy = 0.0
	flash_light.shadow_enabled = false
	flash_light.rotation_degrees = Vector3(-60, 90, 0)
	add_child(flash_light)


## Zickzack-Blitz von 140 m Höhe hinab in die Wolkendecke (lokal, wird verschoben).
func _bolt_mesh(seed_value: int) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 8800 + seed_value
	var top := Vector3(0, 140, 0)
	var points: Array[Vector3] = [top]
	var p := top
	while p.y > 0.0:
		p += Vector3(rng.randf_range(-7, 7), -rng.randf_range(9, 16), rng.randf_range(-5, 5))
		points.append(p)
	for i in range(points.size() - 1):
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var width: float = lerpf(2.2, 0.8, float(i) / float(points.size()))
		var base: int = i * 4
		for q in [
			a + Vector3(-width, 0, 0),
			a + Vector3(width, 0, 0),
			b + Vector3(-width, 0, 0),
			b + Vector3(width, 0, 0)
		]:
			surface.add_vertex(q)
		for index in [base, base + 2, base + 1, base + 1, base + 2, base + 3]:
			surface.add_index(index)
	return surface.commit()


func _advance_storm(game: Node, delta: float) -> void:
	var local: float = fposmod(float(game.get("distance")), float(world.length))
	var lap: int = int(float(game.get("distance")) / float(world.length))
	# Runde 2: die Front zieht näher vorbei (angekündigt), Blitze häufiger, Himmel dunkler.
	var want: float = 1.0 if lap >= 1 else 0.35
	if lap >= 1 and local > float(course.STORM_CALL) - 400.0:
		_announce(
			game,
			"gewitter",
			"Die Gewitterfront zieht vorbei! Die Blitze bleiben weit weg – volle Fahrt!",
			"thunder",
			-8.0
		)
	storm_level = move_toward(storm_level, want, delta * 0.2)
	cloud_material.set_shader_parameter("storm", storm_level * 0.6)
	environment.fog_light_color = Color(LOOK.fog).lerp(Color("8d97ad"), storm_level * 0.5)
	environment.ambient_light_energy = float(LOOK.ambient_energy) * (1.0 - storm_level * 0.2)
	storm_time += delta
	bolt_left = maxf(0.0, bolt_left - delta)
	if bolt_left <= 0.0:
		for bolt in bolts:
			bolt.visible = false
		flash_light.light_energy = 0.0
	next_bolt -= delta
	if next_bolt <= 0.0:
		next_bolt = lerpf(9.0, 4.0, storm_level) + fposmod(storm_time * 1.7, 3.0)
		_strike(game)
	for i in range(pending_thunder.size() - 1, -1, -1):
		pending_thunder[i] -= delta
		if pending_thunder[i] <= 0.0:
			pending_thunder.remove_at(i)
			if audio != null:
				audio.cue("thunder", -10.0 + storm_level * 6.0)


## Ein Blitz seitlich voraus, 210–250 m vom Kart entfernt (immer neben der Strecke).
func _strike(game: Node) -> void:
	var player: Node3D = game.get("player")
	if not is_instance_valid(player):
		return
	var d: float = fposmod(float(game.get("distance")) + 60.0, float(world.length))
	var side: float = -1.0 if int(storm_time) % 3 != 0 else 1.0
	var reach: float = lerpf(250.0, 210.0, storm_level)
	var base: Vector3 = world.position_at(d, side * reach)
	var bolt: MeshInstance3D = bolts[int(storm_time * 10.0) % bolts.size()]
	bolt.position = Vector3(base.x, float(course.CLOUD_DECK) - 4.0, base.z)
	bolt.rotation.y = storm_time
	bolt.visible = true
	bolt_left = 0.16
	flash_light.light_energy = 0.6 + storm_level * 0.6
	pending_thunder.append(
		player.global_position.distance_to(bolt.position + Vector3.UP * 60.0) / SOUND_SPEED
	)
	parts["lightning"] = int(parts.get("lightning", 0)) + 1


# ------------------------------------------------------------------ Lufttaxi


func _taxi() -> void:
	# Die Kreuzung nutzt das Band des Transportroboters (kart_passages.robot_lateral); hier
	# wird nur sein Aussehen gegen ein Schwebetaxi getauscht.
	for k in range(2):
		var mover: Node3D = world.get_node_or_null("Passage_lufttaxi/GateObject%d/Mover" % k)
		if mover == null:
			continue
		for child in mover.get_children():
			if child is GeometryInstance3D:
				child.visible = false
		var taxi: Node3D = module(DIR + "air_taxi.glb", 1.2)
		taxi.name = "Lufttaxi"
		taxi.scale = Vector3.ONE * 1.15
		taxi.rotation_degrees.y = 90.0
		mover.add_child(taxi)
		taxis.append(taxi)


# ------------------------------------------------------------------ Rennen


func _race_tick(game: Node, delta: float) -> void:
	var t: float = float(game.get("elapsed"))
	for i in range(platforms.size()):
		var rest: Vector3 = platform_rest[i]
		platforms[i].position = rest + Vector3(0.0, sin(t * 0.6 + float(i) * 1.3) * 2.2, 0.0)
	for rotor in rotors:
		rotor.rotation.y += delta * 1.6
	for taxi in taxis:
		taxi.position.y = 1.0 + sin(t * 3.0) * 0.25
	if bool(game.get("racing")) or bool(game.get("finished")):
		_advance_storm(game, delta)
		_guide(game)


## Kurze Ansagen vor den großen Stellen (einmal je Runde): was gleich kommt und wie es geht.
func _guide(game: Node) -> void:
	var local: float = fposmod(float(game.get("distance")), float(world.length))
	for entry in GUIDE:
		if local > float(entry[0]) and local < float(entry[0]) + 60.0:
			_announce(game, str(entry[1]), str(entry[2]))


func celebrate_finish() -> void:
	next_bolt = 0.2
