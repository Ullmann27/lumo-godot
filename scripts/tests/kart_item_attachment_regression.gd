extends SceneTree
## Das gehaltene Item (Symbol und Schwebering) darf keinen echten Fahrer berühren.
## Geprüft werden alle sieben Fahrer mit ihren echten Produktionsmodellen im
## Kart-Koordinatensystem, in der tiefsten Schwebe-Stellung des Items. Die Höhe des
## Fahrers ist das Maximum aus Mesh-Hülle (Ruhepose) und den Knochen der aktuellen
## Sitzpose – so bleibt die Prüfung gültig, wenn eine Figur neu gebaut wird.

const VEHICLE = preload("res://scripts/games/kart_vehicle.gd")
const FX = preload("res://scripts/games/kart_rival_item_fx.gd")
const SYMBOLS = preload("res://scripts/games/kart_item_symbols.gd")
const DRIVERS: Array[String] = ["lumo", "rabbit", "lion", "owl", "squirrel", "turtle", "frog"]
const MIN_CLEARANCE: float = 0.10

var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures.append(text)
		print("[KartItemAttachment] FAIL ", text)


func _vertical_bounds(node: Node3D, reference: Node3D) -> Vector2:
	var bounds := Vector2(INF, -INF)
	if not node.visible:
		return bounds
	var to_reference: Transform3D = (
		reference.global_transform.affine_inverse() * node.global_transform
	)
	if node is MeshInstance3D and node.mesh != null:
		var box: AABB = to_reference * node.mesh.get_aabb()
		bounds = Vector2(box.position.y, box.end.y)
	if node is Skeleton3D:
		for bone in range(node.get_bone_count()):
			var height: float = (to_reference * node.get_bone_global_pose(bone).origin).y
			bounds.x = minf(bounds.x, height)
			bounds.y = maxf(bounds.y, height)
	for child in node.get_children():
		if child is Node3D:
			var child_bounds: Vector2 = _vertical_bounds(child, reference)
			bounds.x = minf(bounds.x, child_bounds.x)
			bounds.y = maxf(bounds.y, child_bounds.y)
	return bounds


func _run() -> void:
	var tallest: float = 0.0
	for driver in DRIVERS:
		var vehicle = VEHICLE.new()
		vehicle.configure(driver, Color("b5b3ff"), "glider")
		vehicle.reduced_motion = true
		root.add_child(vehicle)
		vehicle.set_process(false)
		for _frame in range(4):
			await process_frame
		var kart_top: float = 1.2
		var driver_top: float = _vertical_bounds(vehicle, vehicle).y
		tallest = maxf(tallest, driver_top)
		_check(
			driver_top > kart_top and driver_top < 3.0,
			"%s: echte Fahrerfigur ragt über das Kart (Höhe %.2f)" % [driver, driver_top]
		)
		var fx = FX.new()
		vehicle.add_child(fx)
		fx.advance(PI * 0.75, false, false)
		var lowest: float = INF
		for kind in SYMBOLS.KINDS:
			fx.set_item(kind)
			var symbol_bottom: float = _vertical_bounds(fx.item_orb, vehicle).x
			var rail_bottom: float = _vertical_bounds(fx.item_ring, vehicle).x
			var clearance: float = minf(symbol_bottom, rail_bottom) - driver_top
			lowest = minf(lowest, clearance)
			_check(
				clearance >= MIN_CLEARANCE,
				"%s: Item %s hält %.2f m Abstand zum Fahrer" % [driver, kind, clearance]
			)
		print(
			(
				"[KartItemAttachment] %s driver_top=%.2f minimum_clearance=%.2f"
				% [driver, driver_top, lowest]
			)
		)
		vehicle.queue_free()
		for _frame in range(4):
			await process_frame
	_check(tallest > 1.8, "mindestens ein Fahrer ist hoch (Ohren), gemessen %.2f" % tallest)
	await create_timer(0.3).timeout
	if failures.is_empty():
		print(
			(
				"[KartItemAttachment] PASS: %d checks – jedes gehaltene Item bleibt über allen %d Fahrern"
				% [checks, DRIVERS.size()]
			)
		)
	else:
		print("[KartItemAttachment] FAIL: %d von %d" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)
