extends SceneTree
## The tallest actual driver must never intersect its held-item presentation.
## Uses real product meshes in kart-local space, including the lowest bob pose.

const VEHICLE = preload("res://scripts/games/kart_vehicle.gd")
const FX = preload("res://scripts/games/kart_rival_item_fx.gd")
const SYMBOLS = preload("res://scripts/games/kart_item_symbols.gd")


func _initialize() -> void:
	call_deferred("_run")


func _vertical_bounds(node: Node3D, reference: Node3D) -> Vector2:
	var bounds := Vector2(INF, -INF)
	if not node.visible:
		return bounds
	if node is MeshInstance3D and node.mesh != null:
		var relative: Transform3D = reference.global_transform.affine_inverse() * node.global_transform
		var box: AABB = relative * node.mesh.get_aabb()
		bounds = Vector2(box.position.y, box.end.y)
	for child in node.get_children():
		if child is Node3D:
			var child_bounds: Vector2 = _vertical_bounds(child, reference)
			bounds.x = minf(bounds.x, child_bounds.x)
			bounds.y = maxf(bounds.y, child_bounds.y)
	return bounds


func _run() -> void:
	var vehicle = VEHICLE.new()
	vehicle.configure("rabbit", Color("b5b3ff"), "glider")
	vehicle.reduced_motion = true
	root.add_child(vehicle)
	vehicle.set_process(false)
	var driver_top: float = _vertical_bounds(vehicle, vehicle).y
	assert(driver_top > 2.0, "The real tall driver geometry must be present in the fixture.")
	var fx = FX.new()
	vehicle.add_child(fx)
	fx.advance(PI * 0.75, false, false)
	for kind in SYMBOLS.KINDS:
		fx.set_item(kind)
		var symbol_bottom: float = _vertical_bounds(fx.item_orb, vehicle).x
		var rail_bottom: float = _vertical_bounds(fx.item_ring, vehicle).x
		var clearance: float = minf(symbol_bottom, rail_bottom) - driver_top
		assert(clearance >= 0.10,
			"Every held power must clear the real rabbit ears at the lowest animation pose.")
		print("[KartItemAttachment] ", kind, " driver_top=", driver_top,
			" minimum_clearance=", snappedf(clearance, 0.001))
	vehicle.queue_free()
	for _frame in range(6):
		await process_frame
	await create_timer(0.3).timeout
	print("[KartItemAttachment] PASS: all three actual items clear the tallest real driver and their hover rail")
	quit(0)
