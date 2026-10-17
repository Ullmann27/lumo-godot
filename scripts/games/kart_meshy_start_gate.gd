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

static func is_available() -> bool:
	return ResourceLoader.exists(ASSET_MOBILE) or ResourceLoader.exists(ASSET_HIGH)

static func install(world) -> bool:
	if world == null or world.track_id != "sonnenhafen":
		return false
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
	var arch := Node3D.new()
	arch.name = "LumoKartMeshyStartFinishGate"
	arch.transform = Transform3D(world.frame(0.0), world.position_at(0.0))
	world.add_child(arch)
	var visual: Node3D = instanced as Node3D
	visual.name = "MeshyOriginalGeometry"
	visual.scale = Vector3(ARCH_WIDTH, ARCH_HEIGHT, ARCH_DEPTH)
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
