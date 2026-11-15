extends Node3D
## Authored Blender guidance on the existing tunnel shoulder. No gameplay bodies,
## extra lights or per-frame updates; two instanced meshes share four materials.

const LATERAL: float = 6.50
const CLEAR_HALF_WIDTH: float = 5.90
const ROLES: Array[String] = ["guide_body", "guide_trim", "guide_inset", "guide_signal"]
const ASSET_ROOT: String = "res://assets/kart/production/details/"
const PALETTES: Dictionary = {
	"zauberwald": ["536c59", "d0ad65", "263d34", "a5f0ca"],
	"bergwelt": ["626582", "d7a646", "303648", "ffd17a"],
	"holo_city": ["233951", "c6a46b", "101c29", "72e6ed"],
	"crystal_canyon": ["665c85", "d4b0da", "29243e", "7ce0ee"],
	"jungle_temple": ["806945", "cbab70", "354534", "c8e6b4"],
	"candy_cloud": ["b69bdc", "ed94b4", "51466b", "ffd17e"],
	"volcano_night": ["242a3d", "947462", "171c2d", "ee9548"],
	"winter_sprint": ["6d7a8d", "cbdced", "344d7e", "ffc570"],
	"galaxy_ringway": ["263452", "d6ab58", "152b52", "b5a2f5"],
	"desert_drift": ["b88950", "edc681", "245a9b", "ffe0a0"],
	"learning_lab": ["397db4", "edf2fa", "243959", "6ddcec"],
}

var batches: Array[MultiMeshInstance3D] = []
var placements: Array[Dictionary] = []
var statistics: Dictionary = {}
var _materials: Dictionary = {}


func build(world, layout: Dictionary, curve_map) -> bool:
	name = "BlenderShoulderGuidance"
	if not PALETTES.has(str(world.track_id)) or not batches.is_empty():
		push_error("Invalid production guidance theme or repeated build")
		return false
	var poses: Dictionary = {"beacon": [], "ribbon": []}
	# Original straight-module ribs stand at .36, 4.12, 7.88 and 11.64 m.
	# The three midpoints leave room for the authored ribs and wall dressing.
	# Alternating tall and flat pieces also keeps their own geometry separated.
	for module in layout.modules:
		if str(module.kind) != "straight_12m":
			continue
		var span: float = float(module.length)
		var ribs: int = maxi(2, int(round(span / 4.0)) + 1)
		for index in range(ribs - 1):
			var local_distance: float = 0.36 + (float(index) + 0.5) * (span - 0.72) / float(ribs - 1)
			var distance: float = float(module.start) + local_distance
			var kind: String = "ribbon" if index % 2 == 1 else "beacon"
			var road_frame: Transform3D = curve_map.sample(distance)
			for side in [-1.0, 1.0]:
				var pose := Transform3D(road_frame.basis,
					road_frame.origin + road_frame.basis.x * LATERAL * side)
				poses[kind].append(pose)
				placements.append({"kind": kind, "road_distance": distance,
					"lateral_m": LATERAL * side, "module_start": float(module.start)})
	statistics = {"theme": str(world.track_id), "lod": 1 if world.low_detail else 0,
		"instances": placements.size(), "beacons": poses.beacon.size(),
		"ribbons": poses.ribbon.size(), "lateral_m": LATERAL,
		"reserved_clear_half_width_m": CLEAR_HALF_WIDTH,
		"surface_batches": 0, "triangles": 0, "dynamic_lights": 0,
		"collision_objects": 0, "per_frame_updates": false}
	if placements.is_empty():
		push_error("Production tunnel has no usable shoulder-guidance stations")
		return false
	for kind in ["beacon", "ribbon"]:
		if not _build_batch(kind, poses[kind], str(world.track_id), bool(world.low_detail)):
			return false
	statistics["shared_materials"] = _materials.size()
	set_meta("production_guidance", statistics.duplicate(true))
	return true


func _build_batch(kind: String, poses: Array, theme: String, low_detail: bool) -> bool:
	var stem: String = "lumo_guide_beacon" if kind == "beacon" else "lumo_guide_ribbon_2m"
	var path: String = ASSET_ROOT + stem + ("_lod1" if low_detail else "") + ".glb"
	var scene: PackedScene = load(path) as PackedScene
	if scene == null:
		push_error("Missing imported Blender guidance: " + path)
		return false
	var source: Node3D = scene.instantiate() as Node3D
	var pieces: Array[Dictionary] = []
	_collect_meshes(source, Transform3D.IDENTITY, pieces)
	if pieces.size() != 1:
		push_error("Blender guidance must retain exactly one mesh per LOD: " + path)
		source.free()
		return false
	var original: Mesh = pieces[0].mesh
	var local: Transform3D = pieces[0].transform
	var bounds: AABB = local * original.get_aabb()
	var half_width: float = 0.24 if kind == "beacon" else 0.14
	var height: float = 1.32 if kind == "beacon" else 0.22
	var half_length: float = 0.34 if kind == "beacon" else 1.0
	var envelope := AABB(Vector3(-half_width, 0.0, -half_length),
		Vector3(half_width * 2.0, height, half_length * 2.0))
	if not bounds.position.is_finite() or not bounds.size.is_finite() or not envelope.grow(0.001).encloses(bounds):
		push_error("Blender guidance exceeds its measured shoulder envelope: " + path)
		source.free()
		return false
	var mesh: ArrayMesh = original.duplicate(false) as ArrayMesh
	if mesh == null or mesh.get_surface_count() != ROLES.size():
		push_error("Blender guidance lost its four material surfaces: " + path)
		source.free()
		return false
	var triangles: int = 0
	for surface in mesh.get_surface_count():
		var imported: StandardMaterial3D = mesh.surface_get_material(surface) as StandardMaterial3D
		if imported == null or not imported.resource_name in ROLES:
			push_error("Unrecognized Blender guidance material in " + path)
			source.free()
			return false
		mesh.surface_set_material(surface, _material(imported, theme))
		var arrays: Array = mesh.surface_get_arrays(surface)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		triangles += int((indices.size() if not indices.is_empty() else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = poses.size()
	var visible_bounds := AABB()
	for index in poses.size():
		var transform: Transform3D = (poses[index] as Transform3D) * local
		multimesh.set_instance_transform(index, transform)
		var instance_bounds: AABB = transform * mesh.get_aabb()
		visible_bounds = instance_bounds if index == 0 else visible_bounds.merge(instance_bounds)
	multimesh.custom_aabb = visible_bounds.grow(0.02)
	var batch := MultiMeshInstance3D.new()
	batch.name = "Guidance_" + kind
	batch.multimesh = multimesh
	batch.visibility_range_end = 145.0 if low_detail else 185.0
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if low_detail else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	batch.set_meta("source_asset", path.trim_prefix("res://"))
	batch.set_meta("instance_kind", kind)
	add_child(batch)
	batches.append(batch)
	statistics.surface_batches += mesh.get_surface_count()
	statistics.triangles += triangles * poses.size()
	source.free()
	return true


func _material(imported: StandardMaterial3D, theme: String) -> StandardMaterial3D:
	var role: String = imported.resource_name
	if not _materials.has(role):
		var copy: StandardMaterial3D = imported.duplicate(false) as StandardMaterial3D
		var color := Color(str(PALETTES[theme][ROLES.find(role)]))
		copy.albedo_color = color
		if role == "guide_signal":
			copy.emission_enabled = true
			copy.emission = color
			copy.emission_energy_multiplier = 1.1
		_materials[role] = copy
	return _materials[role] as StandardMaterial3D


func _collect_meshes(node: Node, inherited: Transform3D, pieces: Array[Dictionary]) -> void:
	var local: Transform3D = inherited
	if node is Node3D:
		local = inherited * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		pieces.append({"mesh": (node as MeshInstance3D).mesh, "transform": local})
	for child in node.get_children():
		_collect_meshes(child, local, pieces)
