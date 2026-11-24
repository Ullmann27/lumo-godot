class_name LumoDreamAmbience
extends Node3D
## Bounded, real 3D life around the existing play space.
## Two opaque MultiMesh batches share one shader; there are no collision or
## input nodes, no per-frame geometry uploads and no replacement world art.
## The local shader clock follows scene pause and reduceAnimations.

const MOTION_SHADER = preload("res://assets/shaders/lumo_dream_ambience.gdshader")
const NODE_NAME := "LumoDreamAmbience"
const MAX_MOTES := 64
const MAX_BUTTERFLIES := 12
const WORLD_SEED := 20261114
const TIER_DENSITY := {"low": 0.2, "medium": 0.6, "high": 1.0}

var preset_id: String = ""
var quality_tier: String = "medium"
var animation_time: float = 0.0
var reduced_motion: bool = false
var _follow_quality: bool = true
var _motion_override: bool = false
var _application_paused: bool = false
var _profile: Dictionary = {}
var _motes: MultiMeshInstance3D
var _butterflies: MultiMeshInstance3D
var _mote_material: ShaderMaterial
var _butterfly_material: ShaderMaterial


static func attach(world_root: Node3D, preset: String, tier: String = "") -> LumoDreamAmbience:
	if world_root == null or _profile_for(preset).is_empty():
		return null
	var existing := world_root.get_node_or_null(NODE_NAME)
	if existing != null:
		if existing is LumoDreamAmbience:
			existing.configure(preset, tier)
			return existing
		push_warning("[LumoDreamAmbience] named child already belongs to another component")
		return null
	var ambience := LumoDreamAmbience.new()
	ambience.name = NODE_NAME
	ambience.process_mode = Node.PROCESS_MODE_PAUSABLE
	ambience.configure(preset, tier)
	world_root.add_child(ambience)
	return ambience


func configure(preset: String, tier: String = "") -> void:
	var next_profile: Dictionary = _profile_for(preset)
	if next_profile.is_empty():
		return
	_follow_quality = tier not in TIER_DENSITY
	var rebuild_layout: bool = preset_id != preset or _motes == null
	preset_id = preset
	_profile = next_profile
	if _motes == null:
		_create_batches()
	if rebuild_layout:
		_distribute(_motes, MAX_MOTES, false)
		_distribute(_butterflies, MAX_BUTTERFLIES, true)
		_apply_palette()
	set_quality_tier(tier if tier in TIER_DENSITY else LumoQuality.tier())


func _ready() -> void:
	var router := get_node_or_null("/root/SceneRouter")
	if router != null and not _motion_override:
		var options: Variant = router.get("launch_options")
		if options is Dictionary:
			set_reduced_motion(bool(options.get("reduceAnimations", false)))
	var events := get_node_or_null("/root/EventBus")
	if events != null and events.has_signal("quality_profile_changed"):
		events.connect("quality_profile_changed", _on_quality_profile_changed)
	visibility_changed.connect(_update_processing)
	_update_processing()


func _on_quality_profile_changed(tier: String) -> void:
	if _follow_quality:
		set_quality_tier(tier)


func set_quality_tier(tier: String) -> void:
	quality_tier = tier if tier in TIER_DENSITY else "medium"
	if _motes == null:
		return
	var density: float = float(TIER_DENSITY[quality_tier])
	_motes.multimesh.visible_instance_count = maxi(1, int(round(float(_profile.motes) * density)))
	_butterflies.multimesh.visible_instance_count = int(round(float(_profile.butterflies) * density))


func set_reduced_motion(value: bool) -> void:
	_motion_override = true
	reduced_motion = value
	_update_processing()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		_application_paused = true
		_update_processing()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		_application_paused = false
		_update_processing()


func _update_processing() -> void:
	set_process(
		is_inside_tree()
		and is_visible_in_tree()
		and not reduced_motion
		and not _application_paused
	)


func _process(delta: float) -> void:
	if reduced_motion or not is_visible_in_tree():
		return
	animation_time += clampf(delta, 0.0, 0.1)
	_mote_material.set_shader_parameter("animation_time", animation_time)
	_butterfly_material.set_shader_parameter("animation_time", animation_time)


func render_state() -> Dictionary:
	return {
		"preset": preset_id,
		"tier": quality_tier,
		"motes": _motes.multimesh.visible_instance_count,
		"butterflies": _butterflies.multimesh.visible_instance_count,
		"animation_time": animation_time,
		"reduced_motion": reduced_motion,
		"batches": 2,
	}


func _create_batches() -> void:
	_mote_material = ShaderMaterial.new()
	_mote_material.shader = MOTION_SHADER
	_mote_material.set_shader_parameter("wing_weight", 0.0)
	_mote_material.set_shader_parameter("drift_scale", 0.7)
	_butterfly_material = ShaderMaterial.new()
	_butterfly_material.shader = MOTION_SHADER
	_butterfly_material.set_shader_parameter("wing_weight", 1.0)
	_butterfly_material.set_shader_parameter("drift_scale", 1.0)
	var mote_mesh := SphereMesh.new()
	mote_mesh.radius = 0.045
	mote_mesh.height = 0.09
	mote_mesh.radial_segments = 6
	mote_mesh.rings = 3
	_motes = _batch("DreamMotes", mote_mesh, _mote_material, MAX_MOTES)
	_butterflies = _batch("GardenButterflies", _butterfly_mesh(), _butterfly_material, MAX_BUTTERFLIES)


func _batch(node_name: String, mesh: Mesh, material: ShaderMaterial, count: int) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = mesh
	multimesh.instance_count = count
	var node := MultiMeshInstance3D.new()
	node.name = node_name
	node.multimesh = multimesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.extra_cull_margin = 3.0
	add_child(node)
	return node


func _distribute(batch: MultiMeshInstance3D, count: int, butterfly: bool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED + preset_id.hash() + (701 if butterfly else 0)
	var span: Vector3 = _profile.span
	var clearance: float = float(_profile.clearance)
	var floor_height: float = float(_profile.floor)
	var bounds := AABB()
	for index in range(count):
		var side: float = -1.0 if index % 2 == 0 else 1.0
		var at := Vector3(
			side * rng.randf_range(clearance, span.x),
			floor_height + rng.randf_range(0.0, span.y),
			rng.randf_range(-span.z, span.z * 0.35)
		)
		var size_value: float = rng.randf_range(0.75, 1.25)
		var yaw: float = rng.randf_range(-PI, PI)
		var transform_value := Transform3D(
			Basis(Vector3.UP, yaw).scaled(Vector3.ONE * size_value), at
		)
		batch.multimesh.set_instance_transform(index, transform_value)
		batch.multimesh.set_instance_custom_data(
			index, Color(rng.randf(), rng.randf(), rng.randf(), 1.0)
		)
		var point_bounds := AABB(at - Vector3.ONE * 2.5, Vector3.ONE * 5.0)
		bounds = point_bounds if index == 0 else bounds.merge(point_bounds)
	batch.multimesh.custom_aabb = bounds


func _apply_palette() -> void:
	for material: ShaderMaterial in [_mote_material, _butterfly_material]:
		material.set_shader_parameter("palette_warm", _profile.warm)
		material.set_shader_parameter("palette_cool", _profile.cool)
	_mote_material.set_shader_parameter("emission_strength", float(_profile.glow))
	_butterfly_material.set_shader_parameter("emission_strength", 0.08)


static func _butterfly_mesh() -> ArrayMesh:
	# Four real wing lobes, each triangulated around the body. The shader folds
	# them about the longitudinal axis; no texture plane or billboard is used.
	var vertices := PackedVector3Array()
	for side in [-1.0, 1.0]:
		var center := Vector3(0, 0, 0)
		var upper := Vector3(side * 0.22, 0, -0.12)
		var tip := Vector3(side * 0.30, 0, 0.04)
		var lower := Vector3(side * 0.16, 0, 0.22)
		vertices.append_array(PackedVector3Array([center, upper, tip, center, tip, lower]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _profile_for(preset: String) -> Dictionary:
	var profile := {
		"span": Vector3(24, 6, 22),
		"clearance": 4.5,
		"floor": 1.6,
		"motes": 48,
		"butterflies": 10,
		"warm": Color("ffd49a"),
		"cool": Color("85d5cf"),
		"glow": 0.35,
	}
	match preset:
		"bauwelt_day":
			profile.span = Vector3(30, 7, 28)
			profile.warm = Color("ffcfaa")
		"treasure_day":
			profile.warm = Color("ffda8d")
			profile.cool = Color("8bdce7")
		"wolkeninseln":
			profile.span = Vector3(24, 12, 45)
			profile.floor = 0.4
			profile.motes = 56
			profile.warm = Color("fff0c3")
			profile.cool = Color("b6e9f3")
		"creative_night":
			profile.span = Vector3(22, 12, 24)
			profile.motes = 64
			profile.butterflies = 6
			profile.warm = Color("ffdda0")
			profile.cool = Color("adbfff")
			profile.glow = 0.9
		"puzzle_atelier":
			profile.span = Vector3(9, 3.0, 8)
			profile.clearance = 4.8
			profile.floor = 1.8
			profile.motes = 20
			profile.butterflies = 4
			profile.warm = Color("ffe4b8")
			profile.cool = Color("d2d8b0")
		"rhythm_party":
			profile.span = Vector3(14, 8, 14)
			profile.motes = 40
			profile.butterflies = 0
			profile.warm = Color("e9a9f0")
			profile.cool = Color("75d6ec")
			profile.glow = 0.8
		"learning_garden":
			profile.span = Vector3(9, 2.8, 8)
			profile.clearance = 6.2
			profile.floor = 1.1
			profile.motes = 28
			profile.butterflies = 8
			profile.warm = Color("f2cf9c")
			profile.cool = Color("a4d3b6")
		"game_hub":
			profile.span = Vector3(3.8, 2.4, 3)
			profile.clearance = 2.3
			profile.floor = 0.5
			profile.motes = 20
			profile.butterflies = 4
			profile.warm = Color("ffdb9c")
			profile.cool = Color("94ccec")
		_:
			return {}
	return profile
