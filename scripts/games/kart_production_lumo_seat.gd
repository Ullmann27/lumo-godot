extends RefCounted
## Fits Original Lumo's unchanged leg chains to the imported kart's real pedals.
## Positions the existing adapter for this bucket seat and solves leg angles only.
## The authored actor, skeleton proportions, clips and chassis remain unchanged.

const ADAPTER_OFFSET := Vector3(0.0, 0.14, -0.10)
const TOE_LIFT := 0.25
const SOLE_CLEARANCE := 0.003
var kart: Node3D
var skeleton: Skeleton3D
var maximum_foot_error := 0.0
var support_points: Array[Vector3] = []
var foot_targets: Array[Vector3] = []
var _legs: Array[PackedInt32Array] = []
var _foot_bases: Array[Basis] = []
var _neutral_rotations: Dictionary = {}
var _lengths: Array[Vector2] = []
var _foot_samples: Array = [[], []]
var _sole_samples: Array = [[], []]
var _skin_bone_poses: Array[Transform3D] = []
var _knee_poles: Array[Vector3] = [Vector3(-0.48, 0.99, -0.60), Vector3(0.48, 0.99, -0.60)]


func bind_visual(vehicle: Node3D, adapter) -> bool:
	if not is_instance_valid(vehicle.get("production_vehicle")) or adapter == null:
		return false
	kart = vehicle
	skeleton = adapter.actor.skeleton
	if skeleton == null or skeleton.get_bone_count() != 65:
		return false
	var coachwork: Node3D = vehicle.production_vehicle.asset_root.find_child("Coachwork", true, false)
	if coachwork == null:
		return false
	# The previous procedural seat sits lower and farther back. Keep its
	# source pose untouched; place this adapter in the imported seat frame.
	adapter.position = ADAPTER_OFFSET
	_capture_foot_samples(adapter.actor)
	for side_name in ["L", "R"]:
		var side := -1.0 if side_name == "L" else 1.0
		var thigh := skeleton.find_bone("Thigh." + side_name)
		var shin := skeleton.find_bone("Shin." + side_name)
		var foot := skeleton.find_bone("Foot." + side_name)
		var toe := skeleton.find_bone("Toe." + side_name)
		var tip := skeleton.find_bone("ToeTip." + side_name)
		if mini(mini(thigh, shin), mini(foot, mini(toe, tip))) < 0:
			return false
		_legs.append(PackedInt32Array([thigh, shin, foot]))
		for bone in [thigh, shin, foot, toe, tip]:
			_neutral_rotations[bone] = skeleton.get_bone_pose_rotation(bone)
		var hip_pose := skeleton.get_bone_global_pose(thigh)
		var knee_pose := skeleton.get_bone_global_pose(shin)
		var foot_pose := skeleton.get_bone_global_pose(foot)
		_lengths.append(Vector2(hip_pose.origin.distance_to(knee_pose.origin), knee_pose.origin.distance_to(foot_pose.origin)))
		var to_kart := kart.global_transform.affine_inverse() * skeleton.global_transform
		var neutral: Transform3D = to_kart * foot_pose
		var toe_point := to_kart * skeleton.get_bone_global_pose(toe).origin
		var forward := toe_point - neutral.origin
		forward.y = 0.0
		if forward.length_squared() < 0.000001:
			return false
		# Straighten the existing outward toe direction, then lift the toe
		# slightly so the long original shoe clears the rounded bonnet.
		var yaw := Basis(Quaternion(forward.normalized(), Vector3.FORWARD))
		var desired := Basis(Quaternion(Vector3.RIGHT, TOE_LIFT)) * yaw * neutral.basis
		_foot_bases.append(desired)
		var samples := _foot_vertices(side_name, neutral)
		if samples.is_empty():
			return false
		var lowest := INF
		for vertex in samples:
			lowest = minf(lowest, (desired * vertex).y)
		var contact := Vector3.ZERO
		var count := 0
		for vertex in samples:
			var offset := desired * vertex
			if offset.y <= lowest + 0.0005:
				contact += offset
				count += 1
		contact /= float(count)
		contact.y = lowest
		# The front rubber grip is at y=.7175,z=-.30 inside Coachwork.
		# Its actual imported stance transform supplies the pedal's X scale.
		var support := kart.to_local(coachwork.to_global(Vector3(side * 0.18, 0.7175, -0.30)))
		support_points.append(support)
		foot_targets.append(support + Vector3.UP * SOLE_CLEARANCE - contact)
	_fit_sole_height()
	_capture_sole_contacts()
	return true


func _fit_sole_height() -> void:
	# A few heel vertices blend across the ankle/shin. Fit their actual skin
	# after IK once at bind time; rigid-foot bounds alone are insufficient.
	for iteration in range(14):
		advance_tick()
		var error := 0.0
		for side in range(2):
			var points := _foot_vertices("L" if side == 0 else "R", Transform3D.IDENTITY)
			var lowest := INF
			for point in points:
				lowest = minf(lowest, point.y)
			var correction := support_points[side].y + SOLE_CLEARANCE - lowest
			error = maxf(error, absf(correction))
			foot_targets[side].y += correction
		if error < 0.00005:
			break
	advance_tick()


func _capture_foot_samples(actor: Node3D) -> void:
	for item in actor.find_children("*", "MeshInstance3D", true, false):
		var mesh := item as MeshInstance3D
		if mesh.skin == null:
			continue
		var bones: Array[int] = []
		var bind_poses: Array[Transform3D] = []
		var selected: Array[int] = []
		for bind in range(mesh.skin.get_bind_count()):
			var bone := mesh.skin.get_bind_bone(bind)
			if bone < 0:
				bone = skeleton.find_bone(mesh.skin.get_bind_name(bind))
			bones.append(bone)
			bind_poses.append(mesh.skin.get_bind_pose(bind))
			var bone_name := str(skeleton.get_bone_name(bone))
			var is_foot := bone_name.begins_with("Foot.") or bone_name.begins_with("Toe.") or bone_name.begins_with("ToeTip.")
			selected.append((0 if bone_name.ends_with(".L") else 1) if is_foot else -1)
		for surface in range(mesh.mesh.get_surface_count()):
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var joints: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var influences: int = joints.size() / vertices.size()
			var labels: Array[Vector2] = []
			for index in range(vertices.size()):
				var foot_weight := Vector2.ZERO
				for slot in range(influences):
					var offset := index * influences + slot
					var weight := weights[offset]
					if weight <= 0.0:
						continue
					var joint := joints[offset]
					if selected[joint] >= 0:
						foot_weight[selected[joint]] += weight
				labels.append(foot_weight)
			var included: Array[PackedByteArray] = [PackedByteArray(), PackedByteArray()]
			for side in range(2):
				included[side].resize(vertices.size())
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			for offset in range(0, indices.size(), 3):
				for side in range(2):
					if labels[indices[offset]][side] >= 0.49 or labels[indices[offset + 1]][side] >= 0.49 or labels[indices[offset + 2]][side] >= 0.49:
						for corner in range(3):
							included[side][indices[offset + corner]] = 1
			for index in range(vertices.size()):
				if included[0][index] or included[1][index]:
					var record := {"bones": PackedInt32Array(), "points": PackedVector3Array(), "weights": PackedFloat32Array()}
					for slot in range(influences):
						var offset := index * influences + slot
						if weights[offset] > 0.0:
							var joint := joints[offset]
							record.bones.append(bones[joint])
							record.points.append(bind_poses[joint] * vertices[index])
							record.weights.append(weights[offset])
					for side in range(2):
						if included[side][index]:
							_foot_samples[side].append(record)


func _foot_vertices(side_name: String, foot_in_kart: Transform3D) -> Array[Vector3]:
	var result: Array[Vector3] = []
	var to_foot := foot_in_kart.affine_inverse() * kart.global_transform.affine_inverse() * skeleton.global_transform
	var matrices: Array[Transform3D] = []
	for bone in range(skeleton.get_bone_count()):
		matrices.append(skeleton.get_bone_global_pose(bone))
	for record in _foot_samples[0 if side_name == "L" else 1]:
		var posed := Vector3.ZERO
		for index in range(record.bones.size()):
			posed += (matrices[record.bones[index]] * record.points[index]) * record.weights[index]
		result.append(to_foot * posed)
	return result


func _capture_sole_contacts() -> void:
	_skin_bone_poses.resize(skeleton.get_bone_count())
	_read_skin_poses()
	var to_kart := kart.global_transform.affine_inverse() * skeleton.global_transform
	for side in range(2):
		# Retain the underside band, including weighted ankle/heel transitions.
		# Animation changes the nearby blend slightly; it cannot make upper-shoe
		# vertices become the lowest surface while this fixed foot basis is held.
		for record in _foot_samples[side]:
			var point := to_kart * _skin_point(record)
			if point.y < support_points[side].y + SOLE_CLEARANCE + 0.03:
				_sole_samples[side].append(record)


func _read_skin_poses() -> void:
	for bone in range(_skin_bone_poses.size()):
		_skin_bone_poses[bone] = skeleton.get_bone_global_pose(bone)


func _skin_point(record: Dictionary) -> Vector3:
	var point := Vector3.ZERO
	for index in range(record.bones.size()):
		point += (_skin_bone_poses[record.bones[index]] * record.points[index]) * record.weights[index]
	return point


func _sole_height(side: int) -> float:
	var to_kart := kart.global_transform.affine_inverse() * skeleton.global_transform
	var lowest := INF
	for record in _sole_samples[side]:
		lowest = minf(lowest, (to_kart * _skin_point(record)).y)
	return lowest


func is_usable() -> bool:
	return is_instance_valid(skeleton) and _legs.size() == 2 and foot_targets.size() == 2


func advance_tick() -> void:
	if not is_usable():
		return
	_solve_pose()
	if _sole_samples[0].is_empty() or _sole_samples[1].is_empty():
		return
	# The existing celebration animates the pelvis. A weighted heel therefore
	# needs a small skin-based correction even with an exact ankle endpoint.
	# Reuse the cached underside band and pose array; no full-mesh scan per frame.
	for iteration in range(3):
		_read_skin_poses()
		var largest_error := 0.0
		for side in range(2):
			var correction := support_points[side].y + SOLE_CLEARANCE - _sole_height(side)
			largest_error = maxf(largest_error, absf(correction))
			foot_targets[side].y += correction
		if largest_error < 0.00005:
			break
		_solve_pose()


func _solve_pose() -> void:
	maximum_foot_error = 0.0
	# Every solve starts from the same authored seated leg orientations.
	# Keeping a prior IK rotation accumulates axial twist at 60 Hz and makes
	# the weighted heel skin jump whenever the 30 Hz source clip evaluates.
	for bone in _neutral_rotations:
		skeleton.set_bone_pose_rotation(int(bone), _neutral_rotations[bone])
	skeleton.force_update_all_bone_transforms()
	for side in range(2):
		_solve_leg(side)


func _set_global_rotation(bone: int, desired: Quaternion) -> void:
	var parent := skeleton.get_bone_parent(bone)
	var frame := Quaternion.IDENTITY
	if parent >= 0:
		# Imported Godot poses already contain the local rest orientation.
		frame = skeleton.get_bone_global_pose(parent).basis.get_rotation_quaternion()
	skeleton.set_bone_pose_rotation(bone, (frame.inverse() * desired).normalized())
	skeleton.force_update_all_bone_transforms()


func _solve_leg(side: int) -> void:
	var leg := _legs[side]
	var hip := skeleton.get_bone_global_pose(leg[0]).origin
	var knee := skeleton.get_bone_global_pose(leg[1]).origin
	var target := skeleton.to_local(kart.to_global(foot_targets[side]))
	var direction := target - hip
	var a := _lengths[side].x
	var b := _lengths[side].y
	var distance := clampf(direction.length(), absf(a - b) + 0.00001, a + b - 0.00001)
	direction = direction.normalized()
	var pole := skeleton.to_local(kart.to_global(_knee_poles[side])) - hip
	var bend := (pole - direction * pole.dot(direction)).normalized()
	var along := (a * a - b * b + distance * distance) / (2.0 * distance)
	var height := sqrt(maxf(0.0, a * a - along * along))
	var desired_knee := hip + direction * along + bend * height
	var thigh_delta := Quaternion((knee - hip).normalized(), (desired_knee - hip).normalized())
	_set_global_rotation(leg[0], thigh_delta * skeleton.get_bone_global_pose(leg[0]).basis.get_rotation_quaternion())
	knee = skeleton.get_bone_global_pose(leg[1]).origin

	# The second rotation preserves both bone lengths; only joint angles move.
	var shin_delta := Quaternion((skeleton.get_bone_global_pose(leg[2]).origin - knee).normalized(), (target - knee).normalized())
	_set_global_rotation(leg[1], shin_delta * skeleton.get_bone_global_pose(leg[1]).basis.get_rotation_quaternion())
	var desired_basis := skeleton.global_basis.inverse() * kart.global_basis * _foot_bases[side]
	_set_global_rotation(leg[2], desired_basis.get_rotation_quaternion())
	maximum_foot_error = maxf(maximum_foot_error,
		skeleton.to_global(skeleton.get_bone_global_pose(leg[2]).origin).distance_to(kart.to_global(foot_targets[side])))
