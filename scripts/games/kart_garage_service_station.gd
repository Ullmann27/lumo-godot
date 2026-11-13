extends Node3D
## Production workshop furniture and the original standing host. The existing
## material families, GLB and clips are reused; no reward or vehicle state lives here.
const ACTOR = preload("res://scripts/characters/lumo/lumo_rigged_actor.gd")
const INTERIOR = preload("res://scripts/games/kart_garage_interior.gd")
var host
var balance_wheel: Node3D
var selection_time := 0.0
var selection_count := 0
var _reduced_motion := false
var _active := false
var _wheel_angle := 0.0
var _status_material: StandardMaterial3D


func build(materials: Dictionary) -> void:
	name = "GarageServiceStation"
	# A dimensional balancing bench with a real wheel, axle, rim and spokes.
	# Shared instancing batches the repetitive ribs, bolts and pegboard tools.
	INTERIOR._box(self, "BalancerBase", Vector3(0.78, 0.10, 0.78), Vector3(3.35, -0.28, 1.95), materials.recess, true)
	INTERIOR._box(self, "BalancerColumn", Vector3(0.38, 0.78, 0.42), Vector3(3.35, 0.16, 1.95), materials.wall, true)
	INTERIOR._box(self, "BalancerHead", Vector3(0.69, 0.28, 0.64), Vector3(3.35, 0.68, 1.95), materials.ivory, true)
	var axle := INTERIOR._cylinder(self, "BalancerAxle", 0.065, 0.56, Vector3(3.35, 0.93, 1.57), materials.steel)
	axle.rotation.x = PI * 0.5
	balance_wheel = Node3D.new()
	balance_wheel.name = "BalancedWheel"
	balance_wheel.position = Vector3(3.35, 0.93, 1.35)
	add_child(balance_wheel)
	_ring(balance_wheel, "Tyre", 0.24, 0.43, materials.rubber)
	_ring(balance_wheel, "Rim", 0.205, 0.245, materials.steel)
	var spokes: Array[Transform3D] = []
	for spoke in range(6):
		var angle := TAU * spoke / 6.0
		spokes.append(Transform3D(Basis(Vector3.FORWARD, angle).scaled(Vector3(0.045, 0.20, 0.045)),
			Vector3(sin(angle) * 0.12, cos(angle) * 0.12, -0.02)))
	INTERIOR._batch_boxes(balance_wheel, "RimSpokes", spokes, materials.ivory, false)
	var hub := INTERIOR._cylinder(balance_wheel, "WheelHub", 0.065, 0.08, Vector3(0, 0, -0.015), materials.orange)
	hub.rotation.x = PI * 0.5
	_status_material = materials.cyan.duplicate() as StandardMaterial3D
	INTERIOR._box(self, "BalancerStatus", Vector3(0.45, 0.065, 0.03), Vector3(3.35, 0.72, 1.61), _status_material, false)
	# Pegboard behind the existing cabinet. All handles/shafts share two batches.
	INTERIOR._box(self, "ToolPegboard", Vector3(1.72, 1.12, 0.07), Vector3(-3.95, 1.85, 3.85), materials.recess, true)
	var metal_parts: Array[Transform3D] = []
	var handles: Array[Transform3D] = []
	for tool in range(5):
		var x := -4.55 + tool * 0.30
		metal_parts.append(INTERIOR._box_transform(Vector3(0.028, 0.35, 0.035), Vector3(x, 1.92, 3.77)))
		metal_parts.append(INTERIOR._box_transform(Vector3(0.16, 0.055, 0.05), Vector3(x, 2.10, 3.77)))
		handles.append(INTERIOR._box_transform(Vector3(0.070, 0.16, 0.065), Vector3(x, 1.70, 3.76)))
	INTERIOR._batch_boxes(self, "ToolSteel", metal_parts, materials.steel, false)
	INTERIOR._batch_boxes(self, "ToolGrips", handles, materials.orange, false)
	# Original model is instantiated only once and survives all kart replacements.
	host = ACTOR.new()
	host.name = "OriginalWorkshopLumo"
	add_child(host)
	if not host.is_usable() or not _fit_host():
		host.queue_free()
		host = null
		return
	host.hide()
	host.set_suspended(true)
	set_process(false)


func _fit_host() -> bool:
	var skeleton: Skeleton3D = host.skeleton
	var lowest := INF
	var highest := -INF
	for bone in range(skeleton.get_bone_count()):
		var rest := skeleton.get_bone_global_rest(bone).origin
		if not rest.is_finite():
			return false
		lowest = minf(lowest, rest.y)
		highest = maxf(highest, rest.y)
	var span := highest - lowest
	if span <= 0.2 or span > 15.0:
		return false
	var scale_factor := clampf(1.55 / span, 0.08, 3.0)
	host.scale = Vector3.ONE * scale_factor
	host.rotation.y = PI - 0.18
	host.position = Vector3(-1.65, -0.31 - lowest * scale_factor, -0.10)
	return true


func set_active(value: bool, reduced: bool) -> void:
	var changed := value != _active
	_active = value
	if is_instance_valid(host):
		if reduced != _reduced_motion:
			host.set_reduced_motion(reduced)
		host.visible = value
		host.set_suspended(not value)
		if changed and value:
			host.play_behavior("greeting_wave")
	_reduced_motion = reduced
	if not value:
		selection_time = 0.0
		_status_material.emission_energy_multiplier = 0.48


func react_to_selection() -> void:
	if not _active:
		return
	selection_count += 1
	selection_time = 1.6
	if is_instance_valid(host):
		host.play_behavior("point_portal")


func advance(delta: float) -> void:
	if not _active or not is_finite(delta) or delta <= 0.0:
		return
	if _reduced_motion:
		selection_time = 0.0
		_status_material.emission_energy_multiplier = 0.48
		return
	if selection_time > 0.0:
		selection_time = maxf(0.0, selection_time - delta)
		_wheel_angle = fposmod(_wheel_angle + delta * 5.0 * minf(selection_time, 1.0), TAU)
		balance_wheel.rotation.z = _wheel_angle
		_status_material.emission_energy_multiplier = 0.48 + 0.65 * sin(PI * minf(selection_time / 1.6, 1.0))


func subject_points() -> Array[Vector3]:
	var points: Array[Vector3] = []
	if not is_instance_valid(host) or not host.visible:
		return points
	# A stable envelope includes ears, tail, boots and the original waving hand;
	# fit once from bone rest positions so pose transitions do not pump the camera.
	var skeleton: Skeleton3D = host.skeleton
	for bone in range(skeleton.get_bone_count()):
		var point := skeleton.to_global(skeleton.get_bone_global_rest(bone).origin)
		points.append(point + Vector3(0.34, 0.27, 0.25))
		points.append(point - Vector3(0.34, 0.12, 0.25))
	return points


func _ring(parent: Node3D, node_name: String, inner: float, outer: float, material: Material) -> void:
	var ring := MeshInstance3D.new()
	ring.name = node_name
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 24
	mesh.ring_segments = 8
	ring.mesh = mesh
	ring.rotation.x = PI * 0.5
	ring.material_override = material
	parent.add_child(ring)
