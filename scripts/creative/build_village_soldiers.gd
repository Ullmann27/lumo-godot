extends RefCounted
## Soldaten-Darstellung: Blender-Menschen (tools/lumo_village_art/build_soldier_models.py)
## mit village_soldier.gdshader. Eine Formation ist EIN MultiMesh (ein Zeichenaufruf)
## mit Bewegung je Figur über INSTANCE_CUSTOM (Zustand, Phase, Tempo).
## Reine Darstellung ohne Dorf-Regeln – auch für ein späteres Strategiespiel nutzbar.
const ART = preload("res://scripts/creative/build_village_art.gd")
const RIG = preload("res://scripts/creative/build_village_soldier_rig.gd")
const SHADER = preload("res://assets/creative/village3d/shaders/village_soldier.gdshader")
const STATES := {"stehen": 0, "marschieren": 1, "abwehr": 2, "jubeln": 3, "zurueck": 4, "senken": 5}
## Wie weit die Arme beim Marschieren schwingen (links, rechts): Waffenarme weniger.
const SWING := {
	"soldier_schild": Vector2(0.08, 0.3),
	"soldier_bogen": Vector2(0.12, 0.35),
	"soldier_speer": Vector2(0.3, 0.06),
	"soldier_reiter": Vector2(0.04, 0.04),
}
static var _materials: Dictionary = {}


static func model_for(kind: String) -> String:
	return "soldier_" + kind


static func material(model_name: String, team := Color(0, 0, 0, 0)) -> ShaderMaterial:
	var key := "%s|%s" % [model_name, team.to_html()]
	var ref: WeakRef = _materials.get(key)
	var shared: ShaderMaterial = ref.get_ref() if ref != null else null
	if shared != null:
		return shared
	shared = ShaderMaterial.new()
	shared.shader = SHADER
	shared.set_shader_parameter("atlas_albedo", load(ART.TEX + "village_atlas_albedo.png"))
	shared.set_shader_parameter("atlas_normal", load(ART.TEX + "village_atlas_normal.png"))
	var rig: Dictionary = RIG.PIVOTS.get(model_name, RIG.PIVOTS.soldier_schild)
	shared.set_shader_parameter("hip", rig.hip)
	shared.set_shader_parameter("shoulder", rig.shoulder)
	shared.set_shader_parameter("neck", rig.neck)
	shared.set_shader_parameter("seated", 1.0 if bool(rig.seated) else 0.0)
	shared.set_shader_parameter("arm_swing", SWING.get(model_name, Vector2(0.2, 0.2)))
	shared.set_shader_parameter("team_color", team)
	_materials[key] = weakref(shared)
	return shared


static func custom(state: String, index: int) -> Color:
	var code := int(STATES.get(state, 0))
	# Phase und Tempo je Figur verschieden, aber fest (kein Zufall zwischen Läufen).
	var phase := fposmod(float(index) * 0.618034, 1.0)
	var tempo := fposmod(float(index) * 0.414214 + 0.25, 1.0)
	return Color(float(code) / 8.0, phase, tempo, 0.0)


## Formation als ein MultiMesh. transforms: Array[Transform3D].
static func formation(
	parent: Node,
	label: String,
	kind: String,
	transforms: Array,
	state := "stehen",
	team := Color(0, 0, 0, 0),
	range_end := 0.0
) -> MultiMeshInstance3D:
	var model_name := model_for(kind)
	if transforms.is_empty() or not ART.exists(model_name):
		return null
	var mesh := ART.main_mesh(model_name)
	if mesh == null:
		return null
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_custom_data = true
	# gl_compatibility liest ohne Instanzfarbe die Zusatzdaten als Farbe: Weiß setzen.
	multi.use_colors = true
	multi.mesh = mesh
	multi.instance_count = transforms.size()
	for index in range(transforms.size()):
		multi.set_instance_transform(index, transforms[index])
		multi.set_instance_custom_data(index, custom(state, index))
		multi.set_instance_color(index, Color.WHITE)
	var node := MultiMeshInstance3D.new()
	node.name = label
	node.multimesh = multi
	node.material_override = material(model_name, team)
	node.set_meta("village_art_bundle", ART.bundle(model_name))
	node.set_meta("state", state)
	node.set_meta("kind", kind)
	if range_end > 0.0:
		node.visibility_range_end = range_end
		node.visibility_range_end_margin = 10.0
	parent.add_child(node)
	return node


## Zustand aller Figuren einer Formation wechseln (stehen, marschieren, abwehr ...).
static func set_state(node: MultiMeshInstance3D, state: String) -> void:
	if node == null or node.multimesh == null:
		return
	for index in range(node.multimesh.instance_count):
		node.multimesh.set_instance_custom_data(index, custom(state, index))
	node.set_meta("state", state)


## Einzelne Figur (Vorschau, Tafelbild): MeshInstance mit Soldaten-Material.
static func figure(kind: String, state := "stehen", team := Color(0, 0, 0, 0)) -> Node3D:
	var root := Node3D.new()
	root.name = "Soldier_" + kind
	var holder := formation(root, "Figure", kind, [Transform3D.IDENTITY], state, team)
	if holder == null:
		return root
	return root
