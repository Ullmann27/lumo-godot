extends RefCounted
## Dedicated, non-destructive Lumo Kart Meshy start/finish arch integration.
## Visual-only to the existing race loop; lap/physics/checkpoints stay unchanged.
const ASSET_HIGH: String = "res://assets/kart/gates/lumo_kart_start_finish_gate_high.glb"
const ASSET_MOBILE: String = "res://assets/kart/gates/lumo_kart_start_finish_gate_mobile.glb"
const ARCH_WIDTH: float = 12.6
const ARCH_HEIGHT: float = 8.4
const ARCH_DEPTH: float = 8.4
const SOURCE_BOTTOM: float = -0.7031
const ROAD_HALF_WIDTH: float = 5.4
const COLLIDER_INNER_X: float = 8.3

# Original GLB has triangle edges under 0.10 local units.
# Broken aggressive decimation produced many spikes > 0.30 units.
const MAX_EDGE_SQUARED: float = 0.09


static func _repair_geometry(node: Node) -> int:
	# Discard impossibly long triangles without touching UVs or materials.
	# The corrupted decimation created edges over 0.30 local units.
	var stack: Array[Node] = [node]
	var found: int = 0
	var discarded: int = 0
	var total: int = 0
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		for child in current.get_children():
			stack.append(child)
		if not current is MeshInstance3D:
			continue
		var mi: MeshInstance3D = current as MeshInstance3D
		if mi.mesh == null:
			continue
		var old_mesh: Mesh = mi.mesh
		var clean_mesh := ArrayMesh.new()
		var altered: bool = false
		for surface in range(old_mesh.get_surface_count()):
			var mode: int = old_mesh.surface_get_primitive_type(surface)
			var arrays: Array = old_mesh.surface_get_arrays(surface)
			if mode == Mesh.PRIMITIVE_TRIANGLES:
				var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				if points.is_empty():
					return -1
				if indices.is_empty():
					for k in range(points.size()):
						indices.append(k)
				var n: int = indices.size()
				if n < 3 or n % 3 != 0:
					return -1
				for offset in range(0, n, 3):
					var a: int = indices[offset]
					var b: int = indices[offset + 1]
					var c: int = indices[offset + 2]
					if mini(a, mini(b, c)) < 0 or maxi(a, maxi(b, c)) >= points.size():
						return -1
					var va: Vector3 = points[a]
					var vb: Vector3 = points[b]
					var vc: Vector3 = points[c]
					if va.distance_squared_to(vb) > MAX_EDGE_SQUARED or vb.distance_squared_to(vc) > MAX_EDGE_SQUARED or vc.distance_squared_to(va) > MAX_EDGE_SQUARED:
						indices[offset + 1] = a
						indices[offset + 2] = a
						discarded += 1
						altered = true
				total += n / 3
				arrays[Mesh.ARRAY_INDEX] = indices
				found += 1
			clean_mesh.add_surface_from_arrays(mode, arrays)
			clean_mesh.surface_set_material(surface, old_mesh.surface_get_material(surface))
		if altered:
			mi.mesh = clean_mesh
	if found == 0 or total == 0 or float(discarded) / float(total) > 0.05:
		return -1
	return discarded


static func is_available() -> bool:
	return ResourceLoader.exists(ASSET_MOBILE) or ResourceLoader.exists(ASSET_HIGH)

static func install(world) -> bool:
	if world == null or world.track_id != "sonnenhafen":
		return false
	if world.has_node("LumoKartMeshyStartFinishGate"):
		return true
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

	var spike_count: int = _repair_geometry(instanced)
	if spike_count < 0:
		instanced.free()
		push_warning("Lumo Meshy gate: irreparable geometry, keeping original arch: " + file)
		return false
	if spike_count > 0:
		print("[MeshyGate] repaired damaged triangles: ", spike_count)
	var arch := Node3D.new()
	arch.name = "LumoKartMeshyStartFinishGate"
	arch.transform = Transform3D(world.frame(0.0), world.position_at(0.0))
	world.add_child(arch)
	var visual: Node3D = instanced as Node3D
	visual.name = "MeshyOriginalGeometry"
	visual.scale = Vector3(ARCH_WIDTH, ARCH_HEIGHT, ARCH_DEPTH)
	# Meshy has the readable LUMO KART face on local -Z. Incoming karts
	# approach from road-frame +Z: rotate the imported mesh towards them.
	visual.rotation.y = PI
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
		pillar.position = Vector3(side * (COLLIDER_INNER_X + 1.55), 3.35, 0.0)
		arch.add_child(pillar)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(3.1, 6.7, 2.1)
		shape.shape = box
		pillar.add_child(shape)
	arch.set_meta("meshy_gate_asset", file)
	arch.set_meta("visual_only_lap_logic", true)
	world.set_meta("meshy_gate_installed", true)
	return true
