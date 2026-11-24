extends RefCounted
## Loads the Blender models of Wolkenhafen (assets/skypost/models, built by
## tools/lumo_skypost_art/build_skypost_models.py) and sets the distances at which
## their three detail levels take over. Walls, roofs, grass and rock get the
## shared materials of the world (colour variants and the island shaders).

const DIR := "res://assets/skypost/models/"
## Distance (m) where LOD1 and LOD2 take over, per profile. LOW starts at LOD1.
const RANGES := {"low": [0.0, 55.0], "medium": [45.0, 120.0], "high": [70.0, 190.0]}
## Above this distance an object is not drawn at all (per profile).
const FAR := {"low": 260.0, "medium": 380.0, "high": 520.0}

static var _scenes: Dictionary = {}


static func scene(name: String) -> PackedScene:
	if not _scenes.has(name):
		var path: String = DIR + name + ".glb"
		_scenes[name] = load(path) as PackedScene if ResourceLoader.exists(path) else null
	return _scenes[name]


## An instance of [param name] with LOD ranges for [param profile] ("low", "medium",
## "high"); [param overrides] maps a material name (e.g. "SP_Wall") to its replacement.
static func instance(
	name: String, profile: String, overrides: Dictionary = {}, far_scale: float = 1.0
) -> Node3D:
	var packed: PackedScene = scene(name)
	if packed == null:
		push_warning("[SkyPost] Modell fehlt: " + name)
		var holder := Node3D.new()
		holder.name = name
		return holder
	var root: Node3D = packed.instantiate()
	apply_lods(root, profile, far_scale)
	if not overrides.is_empty():
		apply_overrides(root, overrides)
	return root


## Profile "hero": always the full detail level (Lumo's own glider next to the camera).
static func apply_lods(root: Node, profile: String, far_scale: float = 1.0) -> void:
	var ranges: Array = RANGES.get(profile, RANGES.medium)
	var far: float = float(FAR.get(profile, FAR.medium)) * far_scale
	var first: float = float(ranges[0]) * far_scale
	var second: float = float(ranges[1]) * far_scale
	if profile == "hero":
		far = 1000.0
		first = far
		second = far
	for node in root.get_children():
		var name: String = str(node.name)
		var level: int = -1
		for index in range(3):
			if name.ends_with("_lod%d" % index):
				level = index
		var begin: float = 0.0
		var end: float = far
		match level:
			0:
				end = first
			1:
				begin = first
				end = second
			2:
				begin = second
			_:
				# Moving parts belong to the closest level.
				end = maxf(first, 0.01) if level < 0 and _is_detail_part(name) else far
		var visible: bool = end > begin + 0.01
		_set_range(node, begin, end, visible)


static func _is_detail_part(name: String) -> bool:
	return name in ["Yoke", "AileronL", "AileronR", "Elevator", "Rudder", "Propeller"]


static func _set_range(node: Node, begin: float, end: float, visible: bool) -> void:
	if node is Node3D:
		(node as Node3D).visible = visible
	if node is GeometryInstance3D:
		var geometry := node as GeometryInstance3D
		geometry.visibility_range_begin = begin
		geometry.visibility_range_end = end
		geometry.visibility_range_begin_margin = 2.0 if begin > 0.0 else 0.0
		geometry.visibility_range_end_margin = 2.0
		geometry.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	for child in node.get_children():
		_set_range(child, begin, end, true)


static func apply_overrides(root: Node, overrides: Dictionary) -> void:
	for mesh_instance in root.find_children("*", "MeshInstance3D", true, false):
		var holder := mesh_instance as MeshInstance3D
		if holder.mesh == null:
			continue
		for surface in range(holder.mesh.get_surface_count()):
			var material: Material = holder.mesh.surface_get_material(surface)
			if material == null:
				continue
			var key: String = material.resource_name
			if overrides.has(key):
				holder.set_surface_override_material(surface, overrides[key])


## Every MeshInstance3D below [param root] whose name contains [param part].
static func part(root: Node, part_name: String) -> Node3D:
	return root.find_child(part_name, true, false) as Node3D


static func set_shadows(root: Node, enabled: bool) -> void:
	for mesh_instance in root.find_children("*", "GeometryInstance3D", true, false):
		(mesh_instance as GeometryInstance3D).cast_shadow = (
			GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			if enabled
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		)
