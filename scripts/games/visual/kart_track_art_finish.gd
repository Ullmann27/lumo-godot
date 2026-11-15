class_name LumoKartTrackArtFinish
extends Node
## One deferred visual pass after the existing world has flushed its MultiMeshes.
## Never owns race state, transforms, colliders, lights, camera or character rigs.
const SHADER = preload("res://assets/shaders/kart_track_art.gdshader")
const MESHES = preload("res://scripts/games/visual/kart_track_art_meshes.gd")
const THEMES: Dictionary = {
	"sonnenhafen": "coastal", "zauberwald": "forest", "bergwelt": "sky",
	"holo_city": "technical", "crystal_canyon": "mineral", "jungle_temple": "jungle",
	"candy_cloud": "candy", "volcano_night": "basalt", "winter_sprint": "winter",
	"galaxy_ringway": "technical", "desert_drift": "sandstone", "learning_lab": "technical"
}
var records: Array[Dictionary] = []
var finishes: Dictionary = {}
var applied := false
var enabled := true
var rounded_batches := 0
var world_ref: WeakRef

static func install(world: Node3D) -> void:
	if world.get_node_or_null("TrackVisualFinish") != null:
		return
	var finish := LumoKartTrackArtFinish.new()
	finish.name = "TrackVisualFinish"
	finish.world_ref = weakref(world)
	world.add_child(finish)
	finish.set_process(false)
	finish.set_physics_process(false)
	finish.call_deferred("_deferred_apply")

func _deferred_apply() -> void:
	if is_inside_tree() and not is_queued_for_deletion():
		apply()

static func _family(node_name: String) -> int:
	if not node_name.begins_with("Decor_") or node_name.contains("_background") or node_name.ends_with("_light"):
		return -1
	for pair in [["box_", 0], ["hull_", 1], ["cylinder_", 2], ["rock_", 3],
		["roof_", 4], ["crown_", 5], ["fir_", 5], ["crystal_", 6]]:
		if node_name.trim_prefix("Decor_").begins_with(str(pair[0])):
			return int(pair[1])
	return -1

func _finish(source: StandardMaterial3D, family: int, low: bool, theme: String) -> ShaderMaterial:
	var key: String = str(family) + ":" + source.albedo_color.to_html()
	if finishes.has(key):
		return finishes[key] as ShaderMaterial
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.resource_name = "LumoArt_" + theme + "_" + str(family)
	material.set_shader_parameter("base_tint", source.albedo_color)
	material.set_shader_parameter("family", family)
	material.set_shader_parameter("detailed", not low)
	material.set_shader_parameter("technical", theme == "technical")
	var roughness: Array[float] = [0.72, 0.82, 0.36, 0.87, 0.69, 0.88, 0.18]
	var metallic: Array[float] = [0.04, 0.0, 0.42, 0.0, 0.02, 0.0, 0.16]
	if theme == "candy":
		roughness[0] = 0.43
		roughness[4] = 0.45
	if theme == "technical":
		metallic[0] = 0.20
		roughness[0] = 0.46
	material.set_shader_parameter("roughness_value", roughness[family])
	material.set_shader_parameter("metallic_value", metallic[family])
	material.set_shader_parameter("grain_strength", 0.09 if theme == "candy" else 0.14)
	finishes[key] = material
	return material

func apply() -> void:
	if applied or world_ref == null:
		return
	var world = world_ref.get_ref()
	if not is_instance_valid(world) or not THEMES.has(str(world.track_id)):
		return
	var low: bool = world.low_detail
	var theme: String = str(THEMES[str(world.track_id)])
	for child in world.get_children():
		if not child is MultiMeshInstance3D:
			continue
		var node := child as MultiMeshInstance3D
		var family: int = _family(str(node.name))
		var original := node.material_override as StandardMaterial3D
		# Existing custom cinema-rock, water, lava and glass shaders are authoritative.
		if family < 0 or original == null or original.emission_enabled or original.normal_enabled:
			continue
		if original.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			continue
		if node.multimesh == null or node.multimesh.mesh == null:
			continue
		var source_mesh: Mesh = node.multimesh.mesh
		var finished_mesh: Mesh = source_mesh
		if not low and source_mesh is BoxMesh and source_mesh.size.is_equal_approx(Vector3.ONE):
			finished_mesh = MESHES.chamfer_box()
			rounded_batches += 1
		var use_family: int = 0 if theme == "candy" and family == 4 else family
		var material: ShaderMaterial = _finish(original, use_family, low, theme)
		records.append({"node": weakref(node), "instances": node.multimesh.instance_count,
			"original_mesh": source_mesh, "mesh": finished_mesh,
			"original_material": original, "material": material, "shadow": node.cast_shadow})
	applied = true
	set_enabled(enabled)
	world.set_meta("track_art_finish", {"revision": 1, "theme": theme,
		"material_families": finishes.size(), "batches": records.size(),
		"rounded_batches": rounded_batches, "low_detail": low,
		"new_draw_calls": 0, "new_colliders": 0, "per_frame_callbacks": 0})

func set_enabled(value: bool) -> void:
	enabled = value
	for record: Dictionary in records:
		var node = record.node.get_ref()
		if not is_instance_valid(node):
			continue
		node.material_override = record.material if enabled else record.original_material
		node.multimesh.mesh = record.mesh if enabled else record.original_mesh
