extends RefCounted
## Dedicated, non-destructive Lumo Kart Meshy start/finish arch integration.
## Visual-only to the existing race loop; lap/physics/checkpoints stay unchanged.
const ASSET_HIGH: String = "res://assets/kart/gates/lumo_kart_start_finish_gate_high.glb"
const ASSET_MOBILE: String = "res://assets/kart/gates/lumo_kart_start_finish_gate_mobile.glb"
const ARCH_WIDTH: float = 15.0
const ARCH_HEIGHT: float = 12.0
const ARCH_DEPTH: float = 9.0
const SOURCE_BOTTOM: float = -0.703021
const ROAD_HALF_WIDTH: float = 5.4
const COLLIDER_INNER_X: float = 7.3
const FOOT_OFFSET_X: float = 11.0
const FOOT_HALF_WIDTH: float = 3.7
const FOOT_HALF_DEPTH: float = 2.65
## Embed the bottom lip into the real ground rather than leave a floating plinth.
const FOOT_EMBED: float = 0.17
const CONTACT_SHADOW_RISE: float = 0.075
const CONTACT_SEGMENTS: int = 24

# Original GLB has triangle edges under 0.10 local units.
# Broken aggressive decimation produced many spikes > 0.30 units.
const MAX_EDGE_SQUARED: float = 0.0225


static func _safe_geometry(node: Node) -> bool:
	var pending: Array[Node] = [node]
	var triangles: int = 0
	while not pending.is_empty():
		var current: Node = pending.pop_back()
		for child in current.get_children():
			pending.append(child)
		if not current is MeshInstance3D:
			continue
		var instance: MeshInstance3D = current as MeshInstance3D
		if instance.mesh == null:
			continue
		for surface in range(instance.mesh.get_surface_count()):
			if instance.mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
				return false
			var arrays: Array = instance.mesh.surface_get_arrays(surface)
			var pos: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var ids: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var count: int = ids.size() if not ids.is_empty() else pos.size()
			if count < 3 or count % 3 != 0:
				return false
			for offset in range(0, count, 3):
				var a: int = ids[offset] if not ids.is_empty() else offset
				var b: int = ids[offset + 1] if not ids.is_empty() else offset + 1
				var c: int = ids[offset + 2] if not ids.is_empty() else offset + 2
				if mini(a, mini(b, c)) < 0 or maxi(a, maxi(b, c)) >= pos.size():
					return false
				var va: Vector3 = pos[a]
				var vb: Vector3 = pos[b]
				var vc: Vector3 = pos[c]
				if va.distance_squared_to(vb) > MAX_EDGE_SQUARED or vb.distance_squared_to(vc) > MAX_EDGE_SQUARED or vc.distance_squared_to(va) > MAX_EDGE_SQUARED:
					return false
				triangles += 1
	return triangles >= 10000



## Imported albedo, roughness, normal and UV data are preserved. Anisotropic
## mip sampling only sharpens oblique details without modifying the GLB mesh.
static func _crisp_imported_materials(root: Node) -> int:
	var pending: Array[Node] = [root]
	var updated: int = 0
	while not pending.is_empty():
		var current: Node = pending.pop_back()
		for child in current.get_children():
			pending.append(child)
		if not current is MeshInstance3D:
			continue
		var instance: MeshInstance3D = current as MeshInstance3D
		if instance.mesh == null:
			continue
		for surface in range(instance.mesh.get_surface_count()):
			var original: Material = instance.get_active_material(surface)
			if not original is BaseMaterial3D:
				continue
			var crisp: BaseMaterial3D = (original as BaseMaterial3D).duplicate() as BaseMaterial3D
			crisp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			instance.set_surface_override_material(surface, crisp)
			updated += 1
	return updated


## The road centre is deliberately higher than the grass. Compute a single
## conservative world-space drop from both FULL foot footprints; simply
## subtracting a fixed 0.85m leaves gaps on banked and uneven road sections.
static func _ground_drop(world) -> float:
	var at: Vector3 = world.position_at(0.0)
	var basis: Basis = world.frame(0.0)
	var lowest_required: float = INF
	for side in [-1.0, 1.0]:
		for dx in [-FOOT_HALF_WIDTH, 0.0, FOOT_HALF_WIDTH]:
			for dz in [-FOOT_HALF_DEPTH, 0.0, FOOT_HALF_DEPTH]:
				var local_x: float = side * FOOT_OFFSET_X + dx
				# Prior visual bottom was 0.025m above the centreline.
				var predicted: Vector3 = at + basis * Vector3(local_x, 0.025, dz)
				var terrain_y: float = world._ground_height(predicted.x, predicted.z)
				lowest_required = minf(lowest_required, terrain_y - predicted.y)
	return lowest_required - FOOT_EMBED


## A feathered, geometry-only ground contact shadow replaces the "sticker"
## effect of a shiny freestanding platform. The mesh follows the true coastal
## ground height at each vertex, stays OUTSIDE the rails and has no collision.
static func _shadow_vertex(surface: SurfaceTool, world, arch: Node3D,
		x: float, z: float, tint: Color) -> void:
	var point: Vector3 = arch.to_global(Vector3(x, 0.0, z))
	point.y = world._ground_height(point.x, point.z) + CONTACT_SHADOW_RISE
	surface.set_color(tint)
	surface.add_vertex(arch.to_local(point))


static func _add_foot_contact(world, arch: Node3D, side: float) -> void:
	var foot_x: float = side * FOOT_OFFSET_X
	var inner: Color = Color(0.11, 0.14, 0.13, 0.28)
	var outer: Color = Color(0.11, 0.14, 0.13, 0.0)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for step in range(CONTACT_SEGMENTS):
		var a: float = TAU * float(step) / float(CONTACT_SEGMENTS)
		var b: float = TAU * float(step + 1) / float(CONTACT_SEGMENTS)
		var inner_ax: float = foot_x + cos(a) * (FOOT_HALF_WIDTH - 0.30)
		var inner_az: float = sin(a) * (FOOT_HALF_DEPTH - 0.25)
		var inner_bx: float = foot_x + cos(b) * (FOOT_HALF_WIDTH - 0.30)
		var inner_bz: float = sin(b) * (FOOT_HALF_DEPTH - 0.25)
		var outer_ax: float = foot_x + cos(a) * (FOOT_HALF_WIDTH + 0.48)
		var outer_az: float = sin(a) * (FOOT_HALF_DEPTH + 0.52)
		var outer_bx: float = foot_x + cos(b) * (FOOT_HALF_WIDTH + 0.48)
		var outer_bz: float = sin(b) * (FOOT_HALF_DEPTH + 0.52)
		_shadow_vertex(surface, world, arch, inner_ax, inner_az, inner)
		_shadow_vertex(surface, world, arch, outer_ax, outer_az, outer)
		_shadow_vertex(surface, world, arch, inner_bx, inner_bz, inner)
		_shadow_vertex(surface, world, arch, inner_bx, inner_bz, inner)
		_shadow_vertex(surface, world, arch, outer_ax, outer_az, outer)
		_shadow_vertex(surface, world, arch, outer_bx, outer_bz, outer)
	surface.generate_normals()
	var contact := MeshInstance3D.new()
	contact.name = "FootContactRight" if side > 0.0 else "FootContactLeft"
	contact.mesh = surface.commit()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	contact.material_override = material
	contact.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arch.add_child(contact)

static func is_available() -> bool:
	return ResourceLoader.exists(ASSET_MOBILE) or ResourceLoader.exists(ASSET_HIGH)

static func install(world) -> bool:
	if world == null or world.track_id != "sonnenhafen":
		return false
	if world.has_node("LumoKartMeshyStartFinishGate"):
		return true
	var file: String = ASSET_MOBILE if world.low_detail else ASSET_HIGH
	if not ResourceLoader.exists(file):
		file = ASSET_HIGH if file == ASSET_MOBILE else ASSET_MOBILE
	if not ResourceLoader.exists(file):
		return false
	var source: PackedScene = ResourceLoader.load(file) as PackedScene
	if source == null:
		push_warning("Lumo Meshy gate: GLB could not be loaded: " + file)
		return false
	var instanced: Node = source.instantiate()
	if not instanced is Node3D:
		instanced.free()
		push_warning("Lumo Meshy gate: GLB root is not Node3D: " + file)
		return false

	if not _safe_geometry(instanced):
		instanced.free()
		push_warning("Lumo Meshy gate: invalid triangles, keeping old start arch")
		return false
	var arch := Node3D.new()
	arch.name = "LumoKartMeshyStartFinishGate"
	arch.transform = Transform3D(world.frame(0.0), world.position_at(0.0))
	world.add_child(arch)
	var visual: Node3D = instanced as Node3D
	visual.name = "MeshyOriginalGeometry"
	visual.scale = Vector3(ARCH_WIDTH, ARCH_HEIGHT, ARCH_DEPTH)
	# Meshy readable logo faces local +Z, which is also the road-frame approach.
	visual.rotation.y = 0.0
	var drop: float = _ground_drop(world)
	visual.position.y = -SOURCE_BOTTOM * ARCH_HEIGHT + 0.025 + drop
	arch.add_child(visual)
	var crisp_surfaces: int = _crisp_imported_materials(visual)
	for side in [-1.0, 1.0]:
		_add_foot_contact(world, arch, side)
	# The two columns are outside both the playable lane (5.4 m from centre)
	# and the existing continuous rail (6.05 m). Physical bodies are for
	# compatible physics consumers; the kart retains its own rail collision.
	for side in [-1.0, 1.0]:
		var pillar := StaticBody3D.new()
		pillar.name = "RightColumn" if side > 0.0 else "LeftColumn"
		pillar.collision_layer = 1
		pillar.collision_mask = 1
		pillar.position = Vector3(side * (COLLIDER_INNER_X + 3.7), 3.5 + drop, 0.0)
		arch.add_child(pillar)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(7.4, 7.0, 5.3)
		shape.shape = box
		pillar.add_child(shape)
	arch.set_meta("meshy_gate_asset", file)
	arch.set_meta("foot_ground_drop_m", drop)
	arch.set_meta("crisp_material_surfaces", crisp_surfaces)
	arch.set_meta("terrain_contact_shadow_count", 2)
	arch.set_meta("visual_only_lap_logic", true)
	world.set_meta("meshy_gate_installed", true)
	return true
