extends Node3D
## Production workshop furniture and the original standing host. The existing
## material families, GLB and clips are reused; no reward or vehicle state lives here.
const ACTOR = preload("res://scripts/characters/lumo/lumo_rigged_actor.gd")
const INTERIOR = preload("res://scripts/games/kart_garage_interior.gd")
const BALANCER_X := -2.95
const BALANCER_Z := 1.25
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
	INTERIOR._box(
		self,
		"BalancerBase",
		Vector3(0.78, 0.10, 0.78),
		Vector3(BALANCER_X, -0.28, BALANCER_Z),
		materials.recess,
		true
	)
	INTERIOR._box(
		self,
		"BalancerColumn",
		Vector3(0.38, 0.78, 0.42),
		Vector3(BALANCER_X, 0.16, BALANCER_Z),
		materials.wall,
		true
	)
	INTERIOR._box(
		self,
		"BalancerHead",
		Vector3(0.69, 0.28, 0.64),
		Vector3(BALANCER_X, 0.68, BALANCER_Z),
		materials.ivory,
		true
	)
	var axle := INTERIOR._cylinder(
		self,
		"BalancerAxle",
		0.065,
		0.56,
		Vector3(BALANCER_X, 0.93, BALANCER_Z - 0.38),
		materials.steel
	)
	axle.rotation.x = PI * 0.5
	balance_wheel = Node3D.new()
	balance_wheel.name = "BalancedWheel"
	balance_wheel.position = Vector3(BALANCER_X, 0.93, BALANCER_Z - 0.60)
	add_child(balance_wheel)
	_ring(balance_wheel, "Tyre", 0.24, 0.43, materials.rubber)
	_ring(balance_wheel, "Rim", 0.205, 0.245, materials.steel)
	var spokes: Array[Transform3D] = []
	for spoke in range(6):
		var angle := TAU * spoke / 6.0
		spokes.append(
			Transform3D(
				Basis(Vector3.FORWARD, angle).scaled(Vector3(0.045, 0.20, 0.045)),
				Vector3(sin(angle) * 0.12, cos(angle) * 0.12, -0.02)
			)
		)
	INTERIOR._batch_boxes(balance_wheel, "RimSpokes", spokes, materials.ivory, false)
	var hub := INTERIOR._cylinder(
		balance_wheel, "WheelHub", 0.065, 0.08, Vector3(0, 0, -0.015), materials.orange
	)
	hub.rotation.x = PI * 0.5
	_status_material = materials.cyan.duplicate() as StandardMaterial3D
	INTERIOR._box(
		self,
		"BalancerStatus",
		Vector3(0.45, 0.065, 0.03),
		Vector3(BALANCER_X, 0.72, BALANCER_Z - 0.34),
		_status_material,
		false
	)
	# Pegboard behind the existing cabinet. All handles/shafts share two batches.
	INTERIOR._box(
		self,
		"ToolPegboard",
		Vector3(1.72, 1.12, 0.07),
		Vector3(-3.95, 1.85, 3.85),
		materials.recess,
		true
	)
	# Einzeln erkennbare Werkzeuge: Schraubenschlüssel (Chromstiel + Maulring), Schrauben-
	# dreher mit bunten Griffen, Hammer und Zange. Je Material ein Stapel (MultiMesh).
	var metal_parts: Array[Transform3D] = []
	var grips := {"red": [] as Array[Transform3D], "yellow": [] as Array[Transform3D], "blue": [] as Array[Transform3D]}
	var colours := ["red", "yellow", "blue"]
	for tool in range(4):
		var x := -4.62 + tool * 0.13
		var length := 0.24 + tool * 0.05
		metal_parts.append(INTERIOR._box_transform(Vector3(0.028, length, 0.025), Vector3(x, 1.98 - length * 0.5, 3.79)))
		var ring := MeshInstance3D.new()
		ring.name = "WrenchHead"
		var torus := TorusMesh.new()
		torus.inner_radius = 0.022
		torus.outer_radius = 0.042
		torus.rings = 12
		torus.ring_segments = 6
		ring.mesh = torus
		ring.rotation.x = PI * 0.5
		ring.position = Vector3(x, 2.0, 3.79)
		ring.material_override = materials.steel
		add_child(ring)
	for tool in range(5):
		var x := -4.0 + tool * 0.14
		metal_parts.append(INTERIOR._box_transform(Vector3(0.014, 0.2, 0.014), Vector3(x, 2.02, 3.79)))
		grips[colours[tool % 3]].append(INTERIOR._box_transform(Vector3(0.05, 0.14, 0.05), Vector3(x, 1.85, 3.785)))
	# Hammer und Zange unten auf dem Brett.
	grips.red.append(INTERIOR._box_transform(Vector3(0.2, 0.07, 0.06), Vector3(-4.45, 1.58, 3.785)))
	metal_parts.append(INTERIOR._box_transform(Vector3(0.03, 0.3, 0.03), Vector3(-4.45, 1.42, 3.79)))
	for side in [-1.0, 1.0]:
		var jaw := Transform3D(Basis(Vector3.BACK, side * 0.18).scaled(Vector3(0.025, 0.28, 0.025)), Vector3(-3.58 + side * 0.03, 1.5, 3.79))
		metal_parts.append(jaw)
		grips.blue.append(Transform3D(Basis(Vector3.BACK, side * 0.18).scaled(Vector3(0.04, 0.14, 0.04)), Vector3(-3.58 + side * 0.055, 1.38, 3.785)))
	INTERIOR._batch_boxes(self, "ToolSteel", metal_parts, materials.steel, false)
	var grip_materials := {"red": INTERIOR._mat(Color("e8423a"), 0.1, 0.4), "yellow": INTERIOR._mat(Color("ffc532"), 0.1, 0.4), "blue": INTERIOR._mat(Color("2f7bff"), 0.1, 0.4)}
	for key in grips:
		INTERIOR._batch_boxes(self, "ToolGrips_" + key, grips[key], grip_materials[key], false)
	# Ruhende Möbel und Werkzeuge je Material zusammenfassen; das drehende Rad, der
	# Werkzeug-Stapel und Lumo bleiben eigene Knoten.
	INTERIOR.SHOWROOM.merge_static(self, [balance_wheel, find_child("ToolSteel", false, false)])
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
	# Neben und etwas hinter dem Kart, Blick schräg zum Kart: verdeckt es nicht.
	host.rotation.y = PI - 0.55
	host.position = Vector3(-1.5, -0.31 - lowest * scale_factor, 1.0)
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
		_status_material.emission_energy_multiplier = (
			0.48 + 0.65 * sin(PI * minf(selection_time / 1.6, 1.0))
		)


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


func workbench_points() -> Array[Vector3]:
	var points: Array[Vector3] = []
	if not _active or not is_instance_valid(balance_wheel):
		return points
	# Renderer review exposed that the original left placement was behind the
	# choice drawer. The active right-side wheel belongs in the clear stage too.
	var tyre: MeshInstance3D = balance_wheel.get_node("Tyre")
	var bounds := tyre.get_aabb()
	for corner in range(8):
		points.append(tyre.to_global(bounds.get_endpoint(corner)))
	return points


func _ring(
	parent: Node3D, node_name: String, inner: float, outer: float, material: Material
) -> void:
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
