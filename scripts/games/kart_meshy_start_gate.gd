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
	visual.position.y = -SOURCE_BOTTOM * ARCH_HEIGHT + 0.025
	arch.add_child(visual)
	# The two columns are outside both the playable lane (5.4 m from centre)
	# and the existing continuous rail (6.05 m). Physical bodies are for
	# compatible physics consumers; the kart retains its own rail collision.
	for side in [-1.0, 1.0]:
		var pillar := StaticBody3D.new()
		pillar.name = "RightColumn" if side > 0.0 else "LeftColumn"
		pillar.collision_layer = 1
		pillar.collision_mask = 1
		pillar.position = Vector3(side * (COLLIDER_INNER_X + 3.7), 3.5, 0.0)
		arch.add_child(pillar)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(7.4, 7.0, 5.3)
		shape.shape = box
		pillar.add_child(shape)
	arch.set_meta("meshy_gate_asset", file)
	arch.set_meta("visual_only_lap_logic", true)
	world.set_meta("meshy_gate_installed", true)
	return true
