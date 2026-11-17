extends SceneTree
## Exact-source art gate. The missing-hook assertion is the initial RED test.
const WORLD = preload("res://scripts/games/kart_world.gd")
const TRACKS = preload("res://scripts/games/kart_tracks.gd")
var track_id := "sonnenhafen"
var low := true

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--track="):
			track_id = arg.trim_prefix("--track=")
		if arg == "--high":
			low = false
	call_deferred("_run")

func _snapshot(world) -> Dictionary:
	var buffers: Dictionary = {}
	for node in world.get_children():
		if node is MultiMeshInstance3D:
			buffers[str(node.name)] = hash(node.multimesh.buffer)
	return {"points": hash(world.curve.get_baked_points()), "length": world.length,
		"checkpoints": hash(world.checkpoint_positions), "instances": buffers,
		"decorations": world.decoration_count}

func _check_geometry(mesh: Mesh) -> void:
	assert(mesh.get_surface_count() == 1)
	var a: Array = mesh.surface_get_arrays(0)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	assert(v.size() == 132, "Chamfered box must contain exactly 44 triangles")
	var bounds: AABB = mesh.get_aabb()
	assert(bounds.position.is_equal_approx(Vector3.ONE * -0.5))
	assert(bounds.size.is_equal_approx(Vector3.ONE))
	for index in range(0, v.size(), 3):
		var cross: Vector3 = (v[index + 1] - v[index]).cross(v[index + 2] - v[index])
		assert(cross.dot(n[index]) < -0.000001, "Invalid face winding")
		for corner in range(3):
			assert(v[index + corner].is_finite() and n[index + corner].is_finite())
			assert(absf(n[index + corner].length() - 1.0) < 0.001)

func _run() -> void:
	assert(track_id in TRACKS.IDS)
	var world = WORLD.new()
	root.add_child(world)
	world.build(low, track_id, true)
	var original: Dictionary = _snapshot(world)
	var finish = world.get_node_or_null("TrackVisualFinish")
	assert(finish != null, "Missing production TrackVisualFinish hook")
	await process_frame
	assert(finish.applied, "Queued art pass was never applied")
	assert(finish.records.size() > 0, "No actual production materials upgraded")
	assert(_snapshot(world) == original, "Art pass changed driving/placement data")
	var upgraded_count: int = finish.records.size()
	for record: Dictionary in finish.records:
		var node: MultiMeshInstance3D = record.node.get_ref()
		assert(node.material_override is ShaderMaterial)
		assert(node.material_override.shader != null)
		assert(node.multimesh.instance_count == int(record.instances))
		assert(node.cast_shadow == record.shadow)
		assert(not bool(record.original_material.emission_enabled))
		if record.mesh != record.original_mesh:
			assert(not low, "Low detail must retain its original mesh budget")
			_check_geometry(record.mesh)
	finish.apply()
	assert(finish.records.size() == upgraded_count, "Repeated application duplicates records")
	finish.set_enabled(false)
	for record: Dictionary in finish.records:
		var node: MultiMeshInstance3D = record.node.get_ref()
		assert(node.material_override == record.original_material)
		assert(node.multimesh.mesh == record.original_mesh)
	assert(_snapshot(world) == original)
	finish.set_enabled(true)
	assert(_snapshot(world) == original)
	print("[KartTrackArt] PASS track=", track_id, " low=", low,
		" upgraded_batches=", upgraded_count, " materials=", finish.finishes.size(),
		" rounded_batches=", finish.rounded_batches, " physics_unchanged=true")
	world.free()
	await process_frame
	quit(0)
