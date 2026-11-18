class_name LumoKartRocketPods
extends Node3D
## Fold-out Sternraketen pods on a kart (player and rivals): one pod left and right,
## two rockets each (Blender props in assets/kart/items/models). States:
##   stowed -> deploy() unfolds (0.45 s) -> ready -> arm() fire position + ignition
##   flames -> take_pair() hands the two nozzle transforms to the launcher and hides
##   one rocket per side -> stow() folds the empty pods away again.
## All rocket and rack meshes share one vertex-colour material (one draw call each).

const POD_SCENE_PATH := "res://assets/kart/items/models/lumo_rocket_pod.glb"
const ROCKET_SCENE_PATH := "res://assets/kart/items/models/lumo_star_rocket.glb"
const FLAME_SHADER = preload("res://assets/shaders/kart_rocket_flame.gdshader")
const DEPLOY_SECONDS: float = 0.45
const NOZZLE_Z: float = 0.31
## Hinge on the cockpit shoulder per authored body (x, y, z) in kart space.
const MOUNTS: Dictionary = {
	"comet": Vector3(0.47, 0.60, 0.06),
	"glider": Vector3(0.44, 0.60, 0.06),
	"turbo": Vector3(0.50, 0.62, 0.08),
	"code": Vector3(0.52, 0.64, 0.04),
}
## Readability on a phone: the props are authored at real size and shown larger.
const PROP_SCALE: float = 1.45
const SLOT_ORDER: Array[String] = ["Slot_B", "Slot_A"]

static var _pod_scene: PackedScene
static var _rocket_scene: PackedScene

var body: String = "code"
var reduced_motion: bool = false
var rockets_left: int = 0
var deployed: float = 0.0
var armed: float = 0.0
var recoil: float = 0.0
var target_deployed: bool = false
var target_armed: bool = false
var pods: Array[Node3D] = []
## rockets[side] -> Array of rocket MeshInstance3D (outer slot first, fired first).
var rockets: Array = [[], []]
var flames: Array[MeshInstance3D] = []
var _time: float = 0.0
var _material: StandardMaterial3D
var _flame_material: ShaderMaterial


static func load_scenes() -> bool:
	if _pod_scene == null and ResourceLoader.exists(POD_SCENE_PATH):
		_pod_scene = load(POD_SCENE_PATH) as PackedScene
	if _rocket_scene == null and ResourceLoader.exists(ROCKET_SCENE_PATH):
		_rocket_scene = load(ROCKET_SCENE_PATH) as PackedScene
	return _pod_scene != null and _rocket_scene != null


## Shared look for every Lumo rocket prop (also used by flying rockets).
static func prop_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.34
	material.metallic = 0.15
	material.metallic_specular = 0.6
	material.emission_enabled = true
	material.emission = Color("ffffff")
	material.emission_energy_multiplier = 0.08
	return material


static func flame_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = FLAME_SHADER
	return material


## First mesh of a GLB prop, re-parented as a plain MeshInstance3D.
static func instance_prop(scene: PackedScene, material: Material) -> MeshInstance3D:
	if scene == null:
		return null
	var source: Node = scene.instantiate()
	var found: Array[Node] = source.find_children("*", "MeshInstance3D", true, false)
	var result := MeshInstance3D.new()
	if found.is_empty():
		source.free()
		return null
	var mesh_node := found[0] as MeshInstance3D
	result.mesh = mesh_node.mesh
	result.name = str(mesh_node.name)
	for marker in source.find_children("*", "Node3D", true, false):
		if marker is MeshInstance3D:
			continue
		if str(marker.name).begins_with("Slot_") or str(marker.name) == "Nozzle":
			result.set_meta(str(marker.name), (marker as Node3D).transform.origin)
	source.free()
	result.material_override = material
	result.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return result


func setup(body_variant: String, stance: float = 1.0) -> bool:
	body = body_variant if MOUNTS.has(body_variant) else "code"
	name = "RocketPods"
	if not load_scenes():
		return false
	_material = prop_material()
	_flame_material = flame_material()
	var mount: Vector3 = MOUNTS[body]
	for side_index in range(2):
		var side: float = -1.0 if side_index == 0 else 1.0
		var hinge := Node3D.new()
		hinge.name = "PodHingeLeft" if side < 0 else "PodHingeRight"
		hinge.position = Vector3(mount.x * side * stance, mount.y, mount.z)
		# Mirror the authored right-hand pod for the left side.
		hinge.scale = Vector3(side, 1.0, 1.0) * PROP_SCALE
		add_child(hinge)
		var pod: MeshInstance3D = instance_prop(_pod_scene, _material)
		if pod == null:
			return false
		pod.name = "Pod"
		hinge.add_child(pod)
		pods.append(hinge)
		for slot in SLOT_ORDER:
			var rocket: MeshInstance3D = instance_prop(_rocket_scene, _material)
			if rocket == null:
				return false
			rocket.name = "Rocket" + slot.trim_prefix("Slot")
			rocket.position = pod.get_meta(slot, Vector3(0.25, 0.135, 0.0))
			pod.add_child(rocket)
			rockets[side_index].append(rocket)
			var flame := MeshInstance3D.new()
			var cone := CylinderMesh.new()
			cone.top_radius = 0.055
			cone.bottom_radius = 0.0
			cone.height = 0.42
			cone.radial_segments = 10
			cone.rings = 2
			cone.cap_top = false
			cone.cap_bottom = false
			flame.mesh = cone
			flame.name = "IgnitionFlame"
			flame.material_override = _flame_material
			flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			flame.rotation.x = -PI * 0.5
			flame.position = Vector3(0.0, 0.0, NOZZLE_Z + 0.21)
			flame.visible = false
			rocket.add_child(flame)
			flames.append(flame)
	_apply_pose()
	return true


## Fill the racks with `pairs` salvos (1 pair = one rocket per side) and unfold.
func deploy(pairs: int) -> void:
	rockets_left = clampi(pairs, 0, 2) * 2
	for side_index in range(2):
		var list: Array = rockets[side_index]
		for i in range(list.size()):
			(list[i] as Node3D).visible = i < rockets_left / 2
	target_deployed = rockets_left > 0
	if not target_deployed:
		target_armed = false


func arm(value: bool = true) -> void:
	target_armed = value and rockets_left > 0


func stow() -> void:
	target_armed = false
	target_deployed = false


func pairs_left() -> int:
	return rockets_left / 2


func is_deployed() -> bool:
	return deployed > 0.98


## Hide the next rocket on each side; returns their world transforms (nose = -Z).
func take_pair() -> Array[Transform3D]:
	var launches: Array[Transform3D] = []
	if rockets_left <= 0:
		return launches
	for side_index in range(2):
		var list: Array = rockets[side_index]
		for i in range(list.size() - 1, -1, -1):
			var rocket := list[i] as Node3D
			if rocket.visible:
				launches.append(rocket.global_transform.orthonormalized())
				rocket.visible = false
				break
	rockets_left = maxi(0, rockets_left - 2)
	recoil = 0.0 if reduced_motion else 1.0
	if rockets_left <= 0:
		target_armed = false
	return launches


func advance(delta: float) -> void:
	_time += delta
	var deploy_rate: float = delta / DEPLOY_SECONDS
	deployed = (1.0 if target_deployed else 0.0) if reduced_motion else move_toward(deployed, 1.0 if target_deployed else 0.0, deploy_rate)
	armed = (1.0 if target_armed else 0.0) if reduced_motion else move_toward(armed, 1.0 if target_armed else 0.0, delta * 4.0)
	recoil = move_toward(recoil, 0.0, delta * 5.0)
	_apply_pose()


static func _back_out(t: float) -> float:
	var c: float = 1.9
	var u: float = t - 1.0
	return 1.0 + (c + 1.0) * u * u * u + c * u * u


func _apply_pose() -> void:
	visible = deployed > 0.001
	if not visible:
		return
	var unfold: float = _back_out(clampf(deployed, 0.0, 1.0)) if not reduced_motion else deployed
	for hinge in pods:
		var pod := hinge.get_child(0) as Node3D
		# Folded: tucked down against the flank; unfolded: level; armed: nose up, pushed out.
		pod.rotation = Vector3(-0.12 * armed, 0.0, -1.35 * (1.0 - unfold))
		pod.position = Vector3(0.06 * armed, 0.04 * armed, -0.05 * armed + recoil * 0.07)
		pod.scale = Vector3.ONE * lerpf(0.55, 1.0, clampf(unfold, 0.0, 1.2))
	var flicker: float = 1.0 if reduced_motion else 0.88 + 0.12 * sin(_time * 9.0)
	for flame in flames:
		var rocket := flame.get_parent() as Node3D
		flame.visible = armed > 0.05 and rocket.visible
		flame.scale = Vector3(1.0, 0.35 + 0.65 * armed * flicker, 1.0)
		flame.position.z = NOZZLE_Z + 0.21 * flame.scale.y
