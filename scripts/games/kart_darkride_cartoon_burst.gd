extends Node3D
## Child-safe arcade "explosion": three opaque emissive torus shockwaves.
## Visual-only GeometryInstance3D. No Alpha overdraw or physical projectiles.
const EVENT_FRACTION: float = 0.745
const DURATION: float = 1.50
var _rings: Array[MeshInstance3D] = []
var _low_detail: bool = false
var _reduce_motion: bool = false
var _age: float = -1.0
var burst_count: int = 0

func setup(world, lightweight: bool) -> void:
	_low_detail = lightweight
	transform = Transform3D(world.frame(world.length * EVENT_FRACTION),
		world.position_at(world.length * EVENT_FRACTION)
		+ world.frame(world.length * EVENT_FRACTION).y * 3.45)
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_rings.clear()
	for i in range(2 if lightweight else 3):
		var ring := MeshInstance3D.new()
		ring.name = "CartoonBurstRing" + str(i)
		var tube := TorusMesh.new()
		tube.inner_radius = 0.80 + 0.06 * float(i)
		tube.outer_radius = 0.98 + 0.08 * float(i)
		tube.rings = 8 if lightweight else 10
		tube.ring_segments = 18 if lightweight else 26
		ring.mesh = tube
		ring.rotation.x = PI * 0.5
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = (
			Color("93f7ff") if i == 0 else
			(Color("fee28c") if i == 1 else Color("b997fc"))
		)
		mat.emission_enabled = true
		mat.emission = mat.albedo_color
		mat.emission_energy_multiplier = 1.5
		mat.roughness = 0.62
		ring.material_override = mat
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.visible = false
		add_child(ring)
		_rings.append(ring)
	visible = false

func fire(reduced_motion: bool) -> void:
	_reduce_motion = reduced_motion
	_age = 0.0
	burst_count += 1
	visible = true
	_update_rings()

## Accessibility changes must affect an explosion that is already running.
## Never restart the timer or allocate new geometries when the setting changes.
func set_reduced_motion(enabled: bool) -> void:
	if _reduce_motion == enabled:
		return
	_reduce_motion = enabled
	if _age >= 0.0:
		_update_rings()


## Teleport, race exit or track rebuild must not leave glowing rings behind.
func cancel() -> void:
	_age = -1.0
	visible = false
	for ring in _rings:
		if is_instance_valid(ring):
			ring.visible = false


func advance(delta: float) -> void:
	if _age < 0.0:
		return
	_age += maxf(delta, 0.0)
	if _age >= DURATION:
		_age = -1.0
		visible = false
		for ring in _rings:
			ring.visible = false
		return
	_update_rings()

func _update_rings() -> void:
	var maximum: float = 1.85 if _reduce_motion else 4.7
	for i in range(_rings.size()):
		var delay: float = float(i) * (0.20 if _reduce_motion else 0.13)
		var local_t: float = _age - delay
		var ring: MeshInstance3D = _rings[i]
		ring.visible = local_t >= 0.0
		if not ring.visible:
			continue
		var t: float = clampf(local_t / (DURATION - delay), 0.0, 1.0)
		var ease: float = 1.0 - pow(1.0 - t, 2.0)
		var radius: float = 0.25 + ease * maximum
		ring.scale = Vector3.ONE * radius
		ring.rotation.z = 0.0 if _reduce_motion else t * (0.35 if i % 2 == 0 else -0.28)
