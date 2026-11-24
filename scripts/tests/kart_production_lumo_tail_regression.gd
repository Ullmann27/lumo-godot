extends SceneTree
const VEHICLE = preload("res://scripts/games/kart_vehicle.gd")
## Run with Godot --headless --path . --script res://scripts/tests/kart_production_lumo_tail_regression.gd.
## The separate Blender checker validates this evaluated skin against the authored chassis.
var sample_directory := "/tmp/lumo-original-tail-validation"
const EVIDENCE_DIRECTORY := "res://evidence/lumo_kart_runtime/karts"
func _initialize() -> void:
	call_deferred("_run")

func _skin_data(kart) -> Array:
	var skeleton: Skeleton3D = kart.lumo_animation.actor.skeleton
	var rows: Array = []
	for item in kart.lumo_animation.actor.find_children("*", "MeshInstance3D", true, false):
		var mesh := item as MeshInstance3D
		if mesh.skin == null:
			continue
		var transforms: Array[Transform3D] = []
		var names: Array[String] = []
		for bind in range(mesh.skin.get_bind_count()):
			var bone := mesh.skin.get_bind_bone(bind)
			if bone < 0:
				bone = skeleton.find_bone(mesh.skin.get_bind_name(bind))
			transforms.append(skeleton.get_bone_global_pose(bone) * mesh.skin.get_bind_pose(bind))
			names.append(skeleton.get_bone_name(bone))
		for surface in range(mesh.mesh.get_surface_count()):
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var joints: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var stride: int = joints.size() / positions.size()
			var points: Array = []
			var skin_weights: Array = []
			var tail: Array[bool] = []
			var attached: Array[bool] = []
			var pelvis: Array[bool] = []
			for vertex in range(positions.size()):
				var posed := Vector3.ZERO
				var tail_weight := 0.0
				var pelvis_weight := 0.0
				var base_weight := 0.0
				var distal_weight := 0.0
				var dominant_weight := -1.0
				var dominant_bone := ""
				for influence in range(stride):
					var offset := vertex * stride + influence
					var weight := weights[offset]
					if weight <= 0.0:
						continue
					var joint := joints[offset]
					posed += (transforms[joint] * positions[vertex]) * weight
					if weight > dominant_weight:
						dominant_weight = weight
						dominant_bone = names[joint]
					if names[joint] == "TailBase":
						base_weight += weight
					elif names[joint] in ["Tail1", "Tail2", "Tail3", "TailTip"]:
						distal_weight += weight
					if names[joint].begins_with("Tail"):
						tail_weight += weight
					if names[joint] == "Pelvis":
						pelvis_weight += weight
				var point: Vector3 = kart.to_local(skeleton.to_global(posed))
				points.append([point.x, point.y, point.z])
				skin_weights.append({"tailbase": base_weight, "distal_tail": distal_weight, "dominant_bone": dominant_bone, "dominant_weight": dominant_weight})
				tail.append(tail_weight > 0.5)
				attached.append(tail_weight > 0.05)
				pelvis.append(pelvis_weight > 0.5)
			var selected := {"tail_faces": [], "pelvis_faces": [], "body_faces": []}
			var remap := {}
			var vertices: Array = []
			var vertex_weights: Array = []
			for offset in range(0, indices.size(), 3):
				var face := [indices[offset], indices[offset + 1], indices[offset + 2]]
				var include_tail: bool = tail[face[0]] or tail[face[1]] or tail[face[2]]
				var include_pelvis: bool = pelvis[face[0]] or pelvis[face[1]] or pelvis[face[2]]
				var include_body: bool = not attached[face[0]] and not attached[face[1]] and not attached[face[2]]
				if not include_tail and not include_pelvis and not include_body:
					continue
				var compact_face: Array = []
				for index in face:
					if not remap.has(index):
						remap[index] = vertices.size()
						vertices.append(points[index])
						vertex_weights.append(skin_weights[index])
					compact_face.append(remap[index])
				if include_tail:
					selected.tail_faces.append(compact_face)
				if include_pelvis:
					selected.pelvis_faces.append(compact_face)
				if include_body:
					selected.body_faces.append(compact_face)
			if not vertices.is_empty():
				rows.append({"vertices": vertices, "vertex_weights": vertex_weights, "mesh": mesh.name, "tail_faces": selected.tail_faces,
					"pelvis_faces": selected.pelvis_faces, "body_faces": selected.body_faces, "surface": surface})
	return rows

const VARIANTS := ["comet", "glider", "turbo"]
const PHASES := ["driving", "left", "right", "jump", "landing", "finish"]
const SAMPLE_FRAMES := [12, 13, 42, 90]
var records: Array = []
var topology_saved := false
var helper_sha_start := ""
var checks := 0
var failures: Array[String] = []

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _store_geometry(rows: Array, file: FileAccess) -> void:
	file.store_32(rows.size())
	for row in rows:
		file.store_32(row.vertices.size())
		for vertex in row.vertices:
			for value in vertex:
				file.store_float(value)

func _sample(kart, variant: String, phase: String, frame: int) -> void:
	var corrected := _skin_data(kart)
	var fit = kart.production_lumo_seat
	var skeleton: Skeleton3D = kart.lumo_animation.actor.skeleton
	var corrected_rotations: Array[Quaternion] = []
	for name in ["TailBase", "Tail1"]:
		corrected_rotations.append(skeleton.get_bone_pose_rotation(skeleton.find_bone(name)))
	fit.prepare_animation_frame()
	var baseline := _skin_data(kart)
	fit._apply_tail_clearance()
	for i in range(2):
		var index := skeleton.find_bone(["TailBase", "Tail1"][i])
		_check(skeleton.get_bone_pose_rotation(index).is_equal_approx(corrected_rotations[i]), "%s %s frame %d restores sampled corrected bone %d" % [variant, phase, frame, i])
	if not topology_saved:
		var topology: Array = []
		for row in corrected:
			var record: Dictionary = row.duplicate()
			record.erase("vertices")
			record["vertex_count"] = row.vertices.size()
			topology.append(record)
		var topology_file := FileAccess.open(sample_directory + "/topology.json", FileAccess.WRITE)
		topology_file.store_string(JSON.stringify(topology))
		topology_file.close()
		topology_saved = true
	var key := "%s_%s_%03d" % [variant, phase, frame]
	var path := sample_directory + "/" + key + ".bin"
	var output := FileAccess.open(path, FileAccess.WRITE)
	_store_geometry(corrected, output)
	_store_geometry(baseline, output)
	output.close()
	records.append({"variant": variant, "phase": phase, "frame": frame, "seconds": float(frame) / 60.0, "geometry": key + ".bin",
		"file_sha256": FileAccess.get_sha256(path),
		"clip": kart.lumo_animation.actor.current_behavior,
		"clip_seconds": kart.lumo_animation.actor.player.current_animation_position})
	print("[OriginalTailDynamic] sampled ", key)

func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--samples="):
			sample_directory = argument.trim_prefix("--samples=")
	DirAccess.make_dir_recursive_absolute(sample_directory)
	helper_sha_start = FileAccess.get_sha256("res://scripts/games/kart_production_lumo_seat.gd")
	for variant in VARIANTS:
		var kart = VEHICLE.new()
		kart.configure("fox", Color.WHITE, variant)
		kart.set_animated_lumo_enabled(true)
		root.add_child(kart)
		kart.set_process(false)
		kart.position = Vector3(3.0, 1.0, -5.0)
		kart.quaternion = Quaternion(Vector3.UP, 0.37)
		_check(kart.lumo_animation.actor.skeleton.get_bone_count() == 65, variant + " preserves original 65-bone rig")
		for phase in PHASES:
			var steering := -1.0 if phase == "left" else (1.0 if phase == "right" else 0.0)
			kart.set_motion(18.0, steering, phase == "driving", phase in ["left", "right"])
			kart.set_driver_runtime_state(phase == "jump", false, false)
			if phase == "finish":
				kart.celebrate(1)
			for frame in range(1, 91):
				kart._process(1.0 / 60.0)
				if frame in SAMPLE_FRAMES:
					_sample(kart, variant, phase, frame)
		kart.free()
	_check(helper_sha_start == FileAccess.get_sha256("res://scripts/games/kart_production_lumo_seat.gd"), "Adapter source remains unchanged throughout capture")
	var report := {"status": "PASS" if failures.is_empty() else "FAIL", "checks": checks, "failures": failures,
		"engine": Engine.get_version_info().string, "samples": records,
		"seat_adapter_sha256": helper_sha_start,
		"vehicle_script_sha256": FileAccess.get_sha256("res://scripts/games/kart_vehicle.gd"),
		"model_sha256": FileAccess.get_sha256("res://assets/characters/lumo_facial/Lumo-Facial-Mobile.glb"),
		"original_model_sha256": FileAccess.get_sha256("res://assets/characters/lumo_animated/Lumo-Animated-Mobile.glb"),
		"topology_sha256": FileAccess.get_sha256(sample_directory + "/topology.json"),
		"geometry_format": "little endian uint32 row count, per-row uint32 vertex count, xyz float32; first corrected then same-pose original tail",
		"scope": "Actual runtime skin with final adapter, paired with exact same body/animation pose after removing only adapter tail deltas. BVH evaluated separately."}
	var output := FileAccess.open(sample_directory + "/captures.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t") + "\n")
	output.close()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(EVIDENCE_DIRECTORY))
	var evidence := FileAccess.open(EVIDENCE_DIRECTORY + "/original_lumo_tail_contacts.json", FileAccess.WRITE)
	evidence.store_string(JSON.stringify(report, "\t") + "\n")
	evidence.close()
	print("[OriginalTailDynamic] ", report.status, " ", records.size(), " paired poses; ", checks, " checks")
	quit(0 if failures.is_empty() else 1)
