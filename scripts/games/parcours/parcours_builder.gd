extends Node3D
## Sichtbare Parcours-Welt aus den Kursdaten: Himmel, Licht, Fahrbahn (aus denselben
## Platten wie der Boden des Karts), bewegliche Teile, Tore, Sterne, Ziel und Kulisse.
## Mobil: statische Fahrbahn in wenigen Flächen, Sterne/Wolken/Pfosten als MultiMesh,
## Kulisse mit Sichtweite (visibility_range) und ohne Schatten.

const MESHES = preload("res://scripts/games/parcours/parcours_meshes.gd")
const SURFACE_SHADER = preload("res://assets/shaders/parcours_surface.gdshader")
const GLASS_SHADER = preload("res://assets/shaders/parcours_glass.gdshader")
const KIT = preload("res://scripts/games/parcours/parcours_kit.gd")

## Oberflächenstil je Plattenstil: [Shaderstil, Grundfarbe-Schlüssel, Linienfarbe, Leuchtfarbe]
const STYLE_TABLE := {
	"deck": [0, "deck_top", "deck_line", "edge"], "ramp": [0, "deck_top", "deck_line", "edge"],
	"bridge": [1, "bridge", "bridge_line", "edge"], "float": [2, "float", "float_line", "float_glow"],
	"lift": [5, "deck_top", "metal", "edge"], "wait": [5, "deck_top", "deck_line", "accent"],
	"disc": [0, "disc", "deck_line", "edge"], "boostband": [6, "deck_top", "deck_line", "boost"],
	"secret": [1, "secret", "bridge_line", "secret_glow"], "ice": [3, "ice", "ice_line", "ice_glow"],
	"glass": [3, "glass", "ice_line", "ice_glow"], "stone": [4, "stone", "stone_line", "edge"],
	"moss": [7, "moss", "stone_line", "edge"], "wood": [1, "bridge", "bridge_line", "edge"],
	"stairs": [4, "stone", "stone_line", "edge"], "sun_disc": [4, "stone", "stone_line", "edge"]
}

var course
var lightweight: bool = false
var reduced_motion: bool = false
var materials: Dictionary = {}
var moving_slabs: Array[Dictionary] = []
var blocker_nodes: Array[Dictionary] = []
var star_multimesh: MultiMesh
var star_node: MultiMeshInstance3D
var checkpoint_nodes: Array[Node3D] = []
var animated: Array[Dictionary] = []
var lift_lamps: Array[Dictionary] = []
var finish_node: Node3D
var stats: Dictionary = {}


func build(target_course, light: bool, calm: bool) -> void:
	course = target_course
	lightweight = light
	reduced_motion = calm
	name = "ParcoursWorld_" + str(course.id)
	_environment()
	_materials()
	_course_geometry()
	_blockers()
	_stars()
	_gates()
	_signs()
	KIT.scenery(self, course, lightweight)
	_count()


func color(key: String, fallback: Color = Color.WHITE) -> Color:
	return Color(course.theme.get(key, fallback))


func _environment() -> void:
	var environment := WorldEnvironment.new()
	environment.name = "ParcoursEnvironment"
	var env := Environment.new()
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = color("sky_top")
	sky_material.sky_horizon_color = color("sky_horizon")
	sky_material.ground_horizon_color = color("sky_horizon")
	sky_material.ground_bottom_color = color("ground")
	sky_material.sun_angle_max = 18.0
	sky_material.sky_curve = 0.12
	sky.sky_material = sky_material
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = color("ambient")
	env.ambient_light_sky_contribution = 0.55
	env.ambient_light_energy = float(course.theme.get("ambient_energy", 0.6))
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = float(course.theme.get("exposure", 1.0))
	env.fog_enabled = true
	env.fog_light_color = color("fog")
	env.fog_density = float(course.theme.get("fog_density", 0.004))
	env.fog_sky_affect = float(course.theme.get("fog_sky", 0.0))
	env.glow_enabled = not lightweight
	env.glow_intensity = 0.55
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.05
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.06
	environment.environment = env
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = course.theme.get("sun_rotation", Vector3(-40, 30, 0))
	sun.light_color = color("sun")
	sun.light_energy = float(course.theme.get("sun_energy", 1.4))
	sun.shadow_enabled = not lightweight
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 70.0
	sun.shadow_blur = 1.5
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.name = "FillLight"
	fill.rotation_degrees = Vector3(-25, 210, 0)
	fill.light_color = color("fill", Color("9fc4ff"))
	fill.light_energy = float(course.theme.get("fill_energy", 0.35))
	fill.shadow_enabled = false
	add_child(fill)


func _surface_material(style_id: String) -> ShaderMaterial:
	var spec: Array = STYLE_TABLE.get(style_id, STYLE_TABLE.deck)
	var material := ShaderMaterial.new()
	material.shader = SURFACE_SHADER
	material.set_shader_parameter("style", int(spec[0]))
	material.set_shader_parameter("base_color", color(str(spec[1]), Color("dfe7f2")))
	material.set_shader_parameter("line_color", color(str(spec[2]), Color("4a5f80")))
	material.set_shader_parameter("glow_color", color(str(spec[3]), Color("ffc642")))
	material.set_shader_parameter("panel", float(course.theme.get("panel", 3.0)))
	material.set_shader_parameter("time_scale", 0.0 if reduced_motion else 1.0)
	material.set_shader_parameter("glow_strength", float(course.theme.get("glow", 1.0)))
	return material


static func lit(c: Color, rough: float = 0.6, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static func glow(c: Color, energy: float = 1.6) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	m.roughness = 0.4
	return m


func _materials() -> void:
	for style_id in STYLE_TABLE:
		materials["surface:" + style_id] = _surface_material(style_id)
	materials["body"] = lit(color("deck"), 0.55, 0.25)
	materials["trim"] = glow(color("trim", color("edge")), 0.9)
	materials["rail"] = lit(color("rail"), 0.35, 0.6)
	materials["rail_post"] = lit(color("rail_post", color("metal")), 0.4, 0.6)
	materials["support"] = lit(color("support", color("metal")), 0.6, 0.35)
	materials["frame"] = lit(color("metal"), 0.45, 0.55)
	materials["accent"] = lit(color("accent"), 0.5, 0.2)
	materials["teeth"] = lit(color("gear", color("metal")), 0.4, 0.7)
	materials["solid"] = lit(color("deck").darkened(0.1), 0.7, 0.1)
	var glass := ShaderMaterial.new()
	glass.shader = GLASS_SHADER
	glass.set_shader_parameter("base_color", color("glass", Color("9fdcff")))
	glass.set_shader_parameter("glow_color", color("ice_glow", Color("8ff0ff")))
	materials["surface:glass"] = glass
	var glass_body := ShaderMaterial.new()
	glass_body.shader = GLASS_SHADER
	glass_body.set_shader_parameter("base_color", color("glass", Color("9fdcff")).darkened(0.2))
	glass_body.set_shader_parameter("opacity", 0.6)
	materials["glass_body"] = glass_body


func _style_of(slab: Dictionary) -> String:
	var style_id: String = str(slab.get("style", "deck"))
	if style_id == "ramp":
		return "deck"
	return style_id


func _course_geometry() -> void:
	var static_mesh = MESHES.new()
	var support_mesh = MESHES.new()
	for index in range(course.slabs.size()):
		var slab: Dictionary = course.slabs[index]
		var style_id: String = _style_of(slab)
		if style_id == "none":
			continue
		var moving: bool = not (slab.get("motion", {}) as Dictionary).is_empty()
		var target = MESHES.new() if moving else static_mesh
		target.xform = Transform3D.IDENTITY if moving else (slab.base as Transform3D)
		support_mesh.xform = slab.base as Transform3D
		var thickness: float = float(slab.get("thickness", 0.45 if style_id in ["bridge", "secret", "wood"] else 0.7))
		var solid_to: float = INF
		if bool(slab.get("solid", false)):
			solid_to = minf(0.0, float(slab.rise)) - 0.05
		var narrow: bool = float(slab.width) < 6.0
		var body_key: String = "glass_body" if style_id == "glass" else "body"
		target.slab(slab, "surface:" + style_id, thickness, narrow and style_id != "secret", solid_to, body_key)
		if style_id in ["disc", "sun_disc"]:
			KIT.disc_teeth(target, slab)
		if style_id == "lift":
			KIT.lift_cage(target, slab)
		if moving:
			var node := MeshInstance3D.new()
			node.name = "Moving_%d" % index
			node.mesh = target.commit(materials)
			add_child(node)
			node.transform = course.slab_transform(index, 0.0, course.mechanisms)
			moving_slabs.append({"node": node, "slab": index})
			if style_id == "float":
				KIT.float_jets(node, slab, color("float_glow"))
		elif not bool(slab.get("no_supports", false)) and float(course.theme.get("support_depth", 0.0)) > 0.0:
			var copy: Dictionary = slab.duplicate()
			support_mesh.supports(copy, float(course.theme.support_depth), 26.0)
		if style_id == "lift":
			KIT.lift_tower(self, course, slab, materials)
	var world_mesh := MeshInstance3D.new()
	world_mesh.name = "StaticCourse"
	world_mesh.mesh = static_mesh.commit(materials)
	add_child(world_mesh)
	if not support_mesh.is_empty():
		var supports := MeshInstance3D.new()
		supports.name = "Supports"
		supports.mesh = support_mesh.commit(materials)
		supports.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(supports)


func _blockers() -> void:
	for index in range(course.blockers.size()):
		var blocker: Dictionary = course.blockers[index]
		var node: Node3D = KIT.blocker_visual(blocker, materials, color("accent"))
		if node == null:
			continue
		add_child(node)
		node.transform = course.blocker_transform(index, 0.0, course.mechanisms)
		blocker_nodes.append({"node": node, "index": index})


func _stars() -> void:
	star_multimesh = MultiMesh.new()
	star_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	star_multimesh.use_colors = true
	star_multimesh.mesh = KIT.star_mesh()
	star_multimesh.instance_count = course.stars.size()
	for i in range(course.stars.size()):
		var star: Dictionary = course.stars[i]
		star_multimesh.set_instance_transform(i, Transform3D(Basis(), star.pos as Vector3))
		star_multimesh.set_instance_color(
			i, color("secret_star", Color("ff9b2e")) if bool(star.secret) else Color("ffd84a")
		)
	star_node = MultiMeshInstance3D.new()
	star_node.name = "Stars"
	star_node.multimesh = star_multimesh
	var m := glow(Color.WHITE, 1.4)
	m.vertex_color_use_as_albedo = true
	m.emission = Color("ffb52e")
	m.metallic = 0.6
	m.roughness = 0.25
	star_node.material_override = m
	star_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(star_node)


func _gates() -> void:
	for index in range(course.checkpoints.size()):
		var c: Dictionary = course.checkpoints[index]
		var gate: Node3D = KIT.checkpoint_arch(index == 0, color("accent"), color("edge"))
		gate.position = (c.pos as Vector3) + Vector3.DOWN * 0.4
		gate.rotation.y = float(c.heading)
		add_child(gate)
		checkpoint_nodes.append(gate)
	finish_node = KIT.finish_arch(color("accent"))
	finish_node.position = (course.finish.pos as Vector3) + Vector3.DOWN * 0.5
	finish_node.rotation.y = float(course.finish.heading)
	add_child(finish_node)


func _signs() -> void:
	for skill in course.skills:
		var sign: Node3D = KIT.skill_sign(str(skill.name), color("accent"))
		var ahead: Vector3 = Vector3(-sin(float(skill.heading)), 0, -cos(float(skill.heading)))
		var side: Vector3 = Vector3(cos(float(skill.heading)), 0, -sin(float(skill.heading)))
		sign.position = (skill.pos as Vector3) + ahead * 4.0 + side * 3.2 + Vector3.UP * 1.6
		sign.rotation.y = float(skill.heading)
		add_child(sign)
	for plate in course.plates:
		var disc: Node3D = KIT.pressure_plate(color("plate", Color("ffcf4a")))
		disc.position = plate.pos as Vector3
		add_child(disc)
		animated.append({"kind": "plate", "node": disc, "mechanism": str(plate.mechanism)})
	for station in course.stations:
		var marker: Node3D = KIT.station_marker(color("accent"))
		marker.position = station.kart_pos as Vector3
		add_child(marker)
		if station.has("levers"):
			for i in range(station.levers.size()):
				var entry: Dictionary = station.levers[i]
				var puzzle_lever: Node3D = KIT.lever(Color(entry.color))
				puzzle_lever.name = "Lever_%s_%d" % [station.id, i]
				puzzle_lever.position = entry.pos as Vector3
				puzzle_lever.rotation.y = float(entry.get("heading", 0.0))
				add_child(puzzle_lever)
				animated.append({"kind": "lever", "node": puzzle_lever, "mechanism": "%s_lever_%d" % [station.id, i]})
			continue
		var lever: Node3D = KIT.lever(color("accent"))
		lever.name = "Lever_" + str(station.id)
		lever.position = station.lever as Vector3
		lever.rotation.y = float(station.get("lever_heading", 0.0))
		add_child(lever)
		animated.append({"kind": "lever", "node": lever, "mechanism": str(station.mechanism)})


## Ein Bild: bewegliche Teile auf die Kurszeit, Tore auf den Zustand, Sterne einsammeln.
func advance(t: float, state: Dictionary, run) -> void:
	for entry in moving_slabs:
		(entry.node as Node3D).transform = course.slab_transform(int(entry.slab), t, state)
	for entry in blocker_nodes:
		var node: Node3D = entry.node
		var index: int = int(entry.index)
		node.transform = course.blocker_transform(index, t, state)
		var closed: bool = course.blocker_active(index, state)
		KIT.set_gate_open(node, not closed)
	if run != null:
		for index in run.stars_taken:
			star_multimesh.set_instance_transform(int(index), Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))
		for i in range(course.stars.size()):
			if run.stars_taken.has(i):
				continue
			var spin: float = 0.0 if reduced_motion else t * 1.8 + i * 0.4
			var bob: float = 0.0 if reduced_motion else sin(t * 2.2 + i) * 0.12
			star_multimesh.set_instance_transform(
				i, Transform3D(Basis(Vector3.UP, spin).scaled(Vector3.ONE * 1.5), (course.stars[i].pos as Vector3) + Vector3.UP * bob)
			)
		for index in range(checkpoint_nodes.size()):
			KIT.set_checkpoint_lit(checkpoint_nodes[index], run.reached.has(index))
	for entry in animated:
		match str(entry.kind):
			"spin":
				if not reduced_motion:
					(entry.node as Node3D).rotate_object_local(entry.axis as Vector3, float(entry.speed) / 60.0)
			"lever":
				KIT.set_lever(entry.node, bool(state.get(str(entry.mechanism), false)))
			"plate":
				KIT.set_plate(entry.node, bool(state.get(str(entry.mechanism), false)))


func _count() -> void:
	var triangles: int = 0
	var surfaces: int = 0
	var nodes: Array[Node] = find_children("*", "MeshInstance3D", true, false)
	for node in nodes:
		var mesh: Mesh = (node as MeshInstance3D).mesh
		if mesh == null:
			continue
		surfaces += mesh.get_surface_count()
		for s in range(mesh.get_surface_count()):
			var arrays: Array = mesh.surface_get_arrays(s)
			var indices: Variant = arrays[Mesh.ARRAY_INDEX]
			if indices != null and (indices as PackedInt32Array).size() > 0:
				triangles += (indices as PackedInt32Array).size() / 3
			else:
				triangles += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	var multimesh_instances: int = 0
	for node in find_children("*", "MultiMeshInstance3D", true, false):
		var mm: MultiMesh = (node as MultiMeshInstance3D).multimesh
		surfaces += mm.mesh.get_surface_count()
		multimesh_instances += mm.instance_count
	stats = {"mesh_nodes": nodes.size(), "surfaces": surfaces, "triangles": triangles, "instances": multimesh_instances}
