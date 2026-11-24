extends SceneTree

const PRODUCTION = preload("res://scripts/games/kart_production_vehicle.gd")
const FLEET = preload("res://scripts/games/kart_fleet.gd")
const GARAGE = preload("res://scripts/games/kart_garage_interior.gd")
const TEARDOWN = preload("res://scripts/tests/helpers/kart_scene_teardown.gd")

var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		print("[MeshyKart] FAIL: ", label)


func _close_vec(a: Vector3, b: Vector3, epsilon := 0.002) -> bool:
	return (
		absf(a.x - b.x) <= epsilon
		and absf(a.y - b.y) <= epsilon
		and absf(a.z - b.z) <= epsilon
	)


func _settle_frame() -> void:
	# Same-callback build/free destroys materials before Compatibility processes
	# their deferred updates. Exercise each LOD through a frame before teardown.
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw


func _vehicle(id: String) -> void:
	var stock: Dictionary = FLEET.entry(id).look.duplicate(true)
	var kart = PRODUCTION.new()
	root.add_child(kart)
	_check(kart.build(id, stock, stock), id + " production build")
	_check(kart.design == id, id + " identity preserved")
	_check(kart.variant == PRODUCTION.body_of(id), id + " mechanical platform preserved")
	_check(kart.wheel_pivots.size() == 4, id + " four wheel pivots")
	_check(kart.wheel_rotors.size() == 4, id + " four wheel rotors")
	_check(kart.wheel_rest_grips.size() == 2, id + " driver grip anchors")
	_check(kart.boost_positions.size() == 2, id + " boost anchors")
	_check(is_instance_valid(kart.steering_wheel), id + " steering wheel")
	_check(is_instance_valid(kart.meshy_close_mesh), id + " Meshy close shell")
	_check(is_instance_valid(kart.stock_close_mesh), id + " stock close fallback")
	_check(kart.meshy_shell_path == "res://assets/kart/production/meshy/%s.glb" % id,
		id + " exact Meshy path")
	_check(kart.source_paths.has(kart.meshy_shell_path), id + " source provenance")
	if is_instance_valid(kart.meshy_close_mesh):
		var source_size: Vector3 = kart.meshy_close_mesh.get_meta("fit_source_size", Vector3.ZERO)
		var target_size: Vector3 = kart.meshy_close_mesh.get_meta("fit_target_size", Vector3.ZERO)
		var fit_scale: Vector3 = kart.meshy_close_mesh.get_meta("fit_scale", Vector3.ZERO)
		_check(source_size.x > 0.001 and source_size.y > 0.001 and source_size.z > 0.001,
			id + " source bounds")
		_check(target_size.x > 0.001 and target_size.y > 0.001 and target_size.z > 0.001,
			id + " target bounds")
		_check(fit_scale.x > 0.0 and fit_scale.y > 0.0 and fit_scale.z > 0.0,
			id + " positive fit")
		_check(
			is_finite(fit_scale.x) and is_finite(fit_scale.y) and is_finite(fit_scale.z),
			id + " finite fit"
		)
		# Measure the actual rendered transform, independently of fit metadata.
		# Metadata-only multiplication missed both the parent-axis scale bug and
		# the discarded authored LOD0 pivot in the delivered Android build.
		var stock_mesh: MeshInstance3D = kart.stock_close_mesh
		var close_mesh: MeshInstance3D = kart.meshy_close_mesh
		var stock_box := stock_mesh.get_aabb()
		var source_box := close_mesh.get_aabb()
		var into_stock := stock_mesh.global_transform.affine_inverse() * close_mesh.global_transform
		var fitted := AABB(into_stock * source_box.get_endpoint(0), Vector3.ZERO)
		for corner in range(1, 8):
			fitted = fitted.expand(into_stock * source_box.get_endpoint(corner))
		_check(_close_vec(fitted.size, stock_box.size * PRODUCTION.MESHY_CLOSE_MARGIN, 0.003),
			id + " actual transformed shell fits proven body envelope")
		_check(_close_vec(fitted.get_center(), stock_box.get_center(), 0.003),
			id + " actual transformed shell retains authored chassis pivot")
		var nose := (close_mesh.global_basis * Vector3.LEFT).normalized()
		var chassis_forward := (stock_mesh.global_basis * Vector3.FORWARD).normalized()
		_check(nose.dot(chassis_forward) > 0.999,
			id + " shell nose follows chassis forward axis")
		_check(bool(kart.meshy_close_mesh.get_meta("mechanics_preserved", false)),
			id + " visual-only mechanics marker")
	kart.set_lod(0)
	await _settle_frame()
	_check(kart.meshy_close_mesh.visible, id + " new shell visible at LOD0")
	_check(not kart.stock_close_mesh.visible, id + " old LOD0 hidden under new shell")
	_check(kart.visible_surface_count() > 0, id + " close surfaces")
	kart.set_lod(1)
	await _settle_frame()
	_check(not kart.meshy_close_mesh.visible, id + " Meshy shell leaves far LOD")
	_check(kart.visible_surface_count() > 0, id + " proven LOD1 fallback")
	kart.set_lod(2)
	await _settle_frame()
	_check(kart.visible_surface_count() > 0, id + " proven LOD2 fallback")
	_check(await TEARDOWN.release_scene(self, kart, "[MeshyKart] " + id),
		id + " scene released after rendering")
	await _settle_frame()


func _garage(profile: String) -> void:
	var stage := Node3D.new()
	var platter_parent := Node3D.new()
	stage.add_child(platter_parent)
	root.add_child(stage)
	var result: Dictionary = GARAGE.build(stage, platter_parent, profile)
	await _settle_frame()
	_check(result.has("root") and is_instance_valid(result.root), profile + " garage root")
	if profile == "high":
		_check(is_instance_valid(result.get("meshy_tool_bench")), "high Meshy tool workbench")
		_check(is_instance_valid(result.get("meshy_turntable")), "high Meshy presentation turntable")
		if is_instance_valid(result.get("meshy_tool_bench")):
			_check(
				str(result.meshy_tool_bench.get_meta("source_path", "")).ends_with("meshy_tool_workbench.glb"),
				"high workbench source"
			)
		if is_instance_valid(result.get("meshy_turntable")):
			_check(
				str(result.meshy_turntable.get_meta("source_path", "")).ends_with("meshy_turntable.glb"),
				"high turntable source"
			)
		var old_cabinet := result.root.find_child("ToolCabinet", true, false) as Node3D
		_check(old_cabinet == null or not old_cabinet.visible, "high old cabinet hidden")
	else:
		_check(not is_instance_valid(result.get("meshy_tool_bench")), "low omits Meshy workbench")
		_check(not is_instance_valid(result.get("meshy_turntable")), "low omits Meshy turntable")
	_check(await TEARDOWN.release_scene(self, stage, "[MeshyKart] " + profile + " garage"),
		profile + " garage released after rendering")
	await _settle_frame()


func _run() -> void:
	_check(FLEET.ids().size() == 14, "fourteen canonical Karts")
	for id in FLEET.ids():
		await _vehicle(id)
	await _garage("high")
	await _garage("low")
	print("[MeshyKart] checks=", checks, " failures=", failures.size())
	if failures.is_empty():
		print("[MeshyKart] PASS: 14 fitted close shells, preserved chassis/LODs and high-detail garage props")
	quit(0 if failures.is_empty() else 1)
