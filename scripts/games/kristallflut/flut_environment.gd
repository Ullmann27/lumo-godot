extends "res://scripts/games/kart_signature/kart_signature_environment.gd"
## Kristallflut – versunkene Abenteuerwelt: Küste, Meer, Klippen, Wasserfälle, Unterwasser-
## tunnel, Ruineninsel, Kristallgrotte, Fontänen, Schiff, Leuchtturm und die Flut in Runde 2.
## Fahrbahn und Kollision: kart_signature_world.gd; Bauwerke: flut_landmarks.gd.
## Physik der Effekte: Wasser fällt (Fallstreifen werden unten schneller), die Flut hebt den
## Meeresspiegel um 1,4 m (die Fahrbahn liegt überall höher oder im dichten Tunnel), unter
## Wasser wird das Licht blau und gedämpft, Sonnenlicht bricht in wandernden Mustern durch.
const DIR: String = "res://assets/kart/signature/kristallflut/"
const WATER_SHADER = preload("res://assets/shaders/signature/signature_water.gdshader")
const LANDMARKS = preload("res://scripts/games/kristallflut/flut_landmarks.gd")
const PASSAGES = preload("res://scripts/games/kart_passages.gd")
const LOOK: Dictionary = {
	"zenith": Color("2c86d6"),
	"horizon": Color("d9f3ef"),
	"ground": Color("2d6a78"),
	"ground_horizon": Color("bfe6e4"),
	"sun_color": Color("fff1d6"),
	"sun_energy": 1.1,
	"sun_rotation": Vector3(-42, 35, 0),
	"ambient": Color("cde7ea"),
	"ambient_energy": 0.4,
	"fog": Color("bfe0e4"),
	"fog_density": 0.0007,
	"exposure": 0.92,
	"glow": 0.6,
	"glow_threshold": 1.05,
	"saturation": 1.12,
	"aerial": 0.2,
	"fog_sky": 0.3,
	"fill_color": Color("a7d8ff"),
	"fill_energy": 0.2,
}
const UNDERWATER_FOG: Color = Color("1f6c86")
## Ansagen [Meter, Schlüssel, Text] vor den großen Stellen (einmal je Runde).
const GUIDE: Array = [
	[150.0, "sprung", "Gleich der Wasserfall-Sprung! Gas halten – unter dir rauscht das Becken."],
	[700.0, "tunnel", "Ab unter das Meer! Im Glastunnel schwimmen die Fische neben dir."],
	[1530.0, "grotte", "Die Kristallgrotte: die leuchtenden Becken zeigen dir den Weg."],
	[2380.0, "vorhang", "Wasserfall-Vorhang! Einfach durchfahren – das Wasser ist nur kühl."],
]

var sea: MeshInstance3D
var tide: float = 0.0
var tide_target: float = 0.0
var underwater: float = 0.0
var beam: Node3D
var fountain_jets: Array[MultiMeshInstance3D] = []
var fountain_gate: Dictionary = {}
var curtains: Array[MeshInstance3D] = []
var _last_phase: String = ""


func _scene() -> void:
	_lighting(LOOK)
	_sea()
	LANDMARKS.build(self)
	_fountains()
	parts["tide"] = 0
	parts["fountain_bursts"] = 0


func _sea() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(4200, 4200)
	plane.subdivide_width = 48 if low() else 96
	plane.subdivide_depth = plane.subdivide_width
	var water: ShaderMaterial = shader_material(
		WATER_SHADER,
		{"deep": Color("0f5c78"), "shallow": Color("38c0c2"), "wave_height": 0.35, "glint": 1.0}
	)
	sea = mesh_node("Meer", plane, water, 0.0, false)
	sea.position = Vector3(
		world.position_at(1400).x, float(course.SEA_LEVEL), world.position_at(1400).z
	)


# ------------------------------------------------------------------ Fontänen


func _fountains() -> void:
	for entry in world.get_meta("passage_plan", []):
		if str(entry.id) == "fontaenen":
			fountain_gate = entry
	if fountain_gate.is_empty():
		return
	var plane: float = float(fountain_gate.plane)
	# Die Lichtwand des Tors wird zur Wasserwand (gleiches Band, gleiche Zeiten).
	for k in range(2):
		var mover: MeshInstance3D = world.get_node_or_null(
			"Passage_fontaenen/GateObject%d/Mover" % k
		)
		if mover == null:
			continue
		mover.material_override = shader_material(
			LANDMARKS.WATERFALL, {"speed": 7.0, "half_width": 3.2, "opacity": 0.85}
		)
		curtains.append(mover)
	var band := Vector2(float(fountain_gate.lat_min), float(fountain_gate.lat_max))
	for k in range(2):
		var lateral: float = (band.x + band.y) * 0.5 * (1.0 if k == 0 else -1.0)
		var basis: Basis = world.frame(plane)
		var sources: Array = []
		for step in [-2.4, 0.0, 2.4]:
			var at: Vector3 = world.position_at(plane, lateral + step) + basis.y * 0.2
			sources.append(Vector4(at.x, at.y, at.z, 0.4))
		var jets: MultiMeshInstance3D = puffs(
			"Fontaene%d" % k,
			sources,
			22,
			Color(0.85, 0.97, 1.0, 0.8),
			1.1,
			13.0,
			0.7,
			false,
			Vector3(0.3, 0, 0),
			9.81
		)
		jets.material_override.set_shader_parameter("intensity", 0.15)
		fountain_jets.append(jets)


func _advance_fountains(elapsed: float) -> void:
	if fountain_gate.is_empty():
		return
	var state: Dictionary = PASSAGES.swing_state(fountain_gate, elapsed)
	var active: Vector2 = PASSAGES.gate_band(fountain_gate, state)
	var phase: String = str(state.phase)
	if phase == "swing" and _last_phase != "swing":
		parts["fountain_bursts"] = int(parts.get("fountain_bursts", 0)) + 1
	_last_phase = phase
	for k in range(fountain_jets.size()):
		var mine: bool = (k == 0) == (active.x < 0.0)
		var level: float = 0.15
		if mine and phase == "warn":
			level = 0.3 + 0.3 * float(state.progress)
		elif mine and phase == "swing":
			level = 1.0
		fountain_jets[k].material_override.set_shader_parameter("intensity", level)


# ------------------------------------------------------------------ Flut und Licht


func _race_tick(game: Node, delta: float) -> void:
	var distance: float = float(game.get("distance"))
	var local: float = fposmod(distance, float(world.length))
	var lap: int = int(distance / float(world.length))
	if lap >= 1 and local > float(course.TIDE_CALL) and tide_target <= 0.0:
		if _announce(
			game,
			"flut",
			"Die Kristallflut kommt! Das Meer steigt – die Straße bleibt trocken.",
			"tide",
			-4.0
		):
			tide_target = float(course.TIDE_RISE)
			parts["tide"] = int(parts.get("tide", 0)) + 1
	tide = move_toward(tide, tide_target, delta * 0.25)
	sea.position.y = float(course.SEA_LEVEL) + tide
	_advance_fountains(float(game.get("elapsed")))
	for entry in GUIDE:
		if local > float(entry[0]) and local < float(entry[0]) + 60.0:
			_announce(game, str(entry[1]), str(entry[2]))
	# Unter Wasser (im Unterwassertunnel): blaues, gedämpftes Licht, Muster von oben.
	var glass: Vector2 = parts.get("glass", Vector2.ZERO)
	var inside: bool = local > glass.x and local < glass.y
	underwater = move_toward(underwater, 1.0 if inside else 0.0, delta * 1.5)
	environment.fog_light_color = Color(LOOK.fog).lerp(UNDERWATER_FOG, underwater)
	environment.fog_density = lerpf(float(LOOK.fog_density), 0.012, underwater)
	sun.light_energy = lerpf(float(LOOK.sun_energy), 0.55, underwater)
	if beam != null:
		beam.rotation.y += delta * 0.8
	if parts.has("crystal_light"):
		var light: OmniLight3D = parts.crystal_light
		light.light_energy = 2.2 + sin(float(game.get("elapsed")) * 2.4) * 0.8


func celebrate_finish() -> void:
	if fountain_jets.size() > 0:
		for jets in fountain_jets:
			jets.material_override.set_shader_parameter("intensity", 1.0)
		parts["fountain_bursts"] = int(parts.get("fountain_bursts", 0)) + 1
