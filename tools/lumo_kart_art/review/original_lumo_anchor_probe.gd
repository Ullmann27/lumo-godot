extends SceneTree
## Read-only comparison of the unchanged Original-Lumo adapter on both chassis paths.
const VEHICLE = preload("res://scripts/games/kart_vehicle.gd")

class ProceduralKart:
	extends LumoRaceKart
	func _build_production_vehicle() -> bool:
		return false

func _initialize() -> void:
	call_deferred("_run")

func _v(point: Vector3) -> Array:
	return [point.x, point.y, point.z]

func _bounds(vertices: Array[Vector3]) -> Dictionary:
	if vertices.is_empty():
		return {}
	var value := AABB(vertices[0], Vector3.ZERO)
	for vertex in vertices:
		value = value.expand(vertex)
	return {"minimum": _v(value.position), "maximum": _v(value.end), "vertices": vertices.size()}

func _skin_bounds(kart, dump: bool = false) -> Dictionary:
	var skeleton: Skeleton3D = kart.lumo_animation.actor.skeleton
	var groups := {"all": [], "pelvis": [], "feet": []}
	var exported: Array[Dictionary] = []
	for item in kart.lumo_animation.actor.find_children("*", "MeshInstance3D", true, false):
		var mesh := item as MeshInstance3D
		if mesh.skin == null:
			continue
		var matrices: Array[Transform3D] = []
		var names: Array[String] = []
		for bind in range(mesh.skin.get_bind_count()):
			var index := mesh.skin.get_bind_bone(bind)
			if index < 0:
				index = skeleton.find_bone(mesh.skin.get_bind_name(bind))
			matrices.append(skeleton.get_bone_global_pose(index) * mesh.skin.get_bind_pose(bind))
			names.append(skeleton.get_bone_name(index))
		for surface in range(mesh.mesh.get_surface_count()):
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var joints: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var influences: int = joints.size() / positions.size()
			var posed_vertices: Array = []
			var foot_selected: Array[bool] = []
			var leg_selected: Array[bool] = []
			for vertex in range(positions.size()):
				var posed := Vector3.ZERO
				var pelvis := 0.0
				var feet := 0.0
				var legs := 0.0
				for influence in range(influences):
					var offset := vertex * influences + influence
					var weight := weights[offset]
					if weight <= 0.0:
						continue
					var joint := joints[offset]
					posed += (matrices[joint] * positions[vertex]) * weight
					if names[joint] == "Pelvis":
						pelvis += weight
					if names[joint].begins_with("Foot.") or names[joint].begins_with("Toe.") or names[joint].begins_with("ToeTip."):
						feet += weight
						legs += weight
					elif names[joint].begins_with("Thigh.") or names[joint].begins_with("Shin."):
						legs += weight
				var point: Vector3 = kart.to_local(skeleton.to_global(posed))
				groups.all.append(point)
				if pelvis > 0.5:
					groups.pelvis.append(point)
				if feet > 0.5:
					groups.feet.append(point)
				if dump:
					posed_vertices.append(_v(point))
					foot_selected.append(feet > 0.5)
					leg_selected.append(legs > 0.5)
			if dump:
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				var foot_faces: Array = []
				var leg_faces: Array = []
				for offset in range(0, indices.size(), 3):
					var face := [indices[offset], indices[offset + 1], indices[offset + 2]]
					if foot_selected[face[0]] or foot_selected[face[1]] or foot_selected[face[2]]:
						foot_faces.append(face)
					if leg_selected[face[0]] or leg_selected[face[1]] or leg_selected[face[2]]:
						leg_faces.append(face)
				var remap := {}
				var compact: Array = []
				for face in leg_faces + foot_faces:
					for corner in range(3):
						var source: int = face[corner]
						if not remap.has(source):
							remap[source] = compact.size()
							compact.append(posed_vertices[source])
				# Map each face list separately: an overlapping triangle appears
				# in both selections but each list owns its own corner array.
				var mapped_feet: Array = []
				var mapped_legs: Array = []
				for face in foot_faces:
					mapped_feet.append([remap[face[0]], remap[face[1]], remap[face[2]]])
				for face in leg_faces:
					mapped_legs.append([remap[face[0]], remap[face[1]], remap[face[2]]])
				exported.append({"vertices": compact, "foot_faces": mapped_feet, "leg_faces": mapped_legs})
	if dump:
		var file := FileAccess.open("/tmp/lumo-original-fit-comet.json", FileAccess.WRITE)
		file.store_string(JSON.stringify(exported))
		file.close()
	var result := {}
	for group in groups:
		var typed: Array[Vector3] = []
		typed.assign(groups[group])
		result[group] = _bounds(typed)
	return result

func _one(imported: bool, reduced: bool = true) -> Dictionary:
	var kart = VEHICLE.new() if imported else ProceduralKart.new()
	kart.configure("fox", Color("76d9ff"), "comet")
	kart.set_animated_lumo_enabled(true)
	root.add_child(kart)
	kart.set_process(false)
	kart.reduced_motion = reduced
	kart.set_motion(64.0 / 3.6, 0.0, false, false)
	for frame in range(30):
		kart._process(1.0 / 30.0)
	var skeleton: Skeleton3D = kart.lumo_animation.actor.skeleton
	var bones := {}
	for bone in ["Pelvis", "Spine", "Chest", "Head", "Thigh.L", "Shin.L", "Foot.L", "Toe.L", "Thigh.R", "Shin.R", "Foot.R", "Toe.R"]:
		var index := skeleton.find_bone(bone)
		if index >= 0:
			bones[bone] = _v(kart.to_local(skeleton.to_global(skeleton.get_bone_global_pose(index).origin)))
	var actor: Node3D = kart.lumo_animation.actor
	var frames := {}
	for bone in ["Thigh.L", "Shin.L", "Foot.L"]:
		var index := skeleton.find_bone(bone)
		var parent := skeleton.get_bone_global_pose(skeleton.get_bone_parent(index))
		var actual := skeleton.get_bone_global_pose(index).basis.get_rotation_quaternion()
		frames[bone] = {"direct_pose_error": actual.angle_to((parent * skeleton.get_bone_pose(index)).basis.get_rotation_quaternion()),
			"rest_pose_error": actual.angle_to((parent * skeleton.get_bone_rest(index) * skeleton.get_bone_pose(index)).basis.get_rotation_quaternion())}
	var result := {"imported_chassis": imported, "reduced_motion": reduced, "adapter_position": _v(kart.lumo_animation.position),
		"actor_position": _v(actor.position), "actor_scale": _v(actor.scale),
		"bones_in_kart_metres": bones, "skin_bounds_in_kart_metres": _skin_bounds(kart, imported and not reduced), "pose_frames": frames}
	if is_instance_valid(kart.production_lumo_seat):
		result["fit"] = {"maximum_foot_error": kart.production_lumo_seat.maximum_foot_error,
			"targets": [_v(kart.production_lumo_seat.foot_targets[0]), _v(kart.production_lumo_seat.foot_targets[1])]}
	kart.free()
	return result

func _run() -> void:
	var report := {"production": _one(true), "previous_procedural": _one(false),
		"production_moving": _one(true, false), "previous_procedural_moving": _one(false, false),
		"method": "Actual seated Original-Lumo skeleton plus weighted skin vertices; source model and adapter unchanged"}
	var file := FileAccess.open("res://evidence/lumo_kart_runtime/karts/original_lumo_anchor_review.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("[OriginalLumoAnchor] measured actual unchanged adapter on both chassis")
	quit(0)
