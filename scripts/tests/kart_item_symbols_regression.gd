extends SceneTree
## Actual LUMO racing integration: solid readable item geometry, preserved
## banked gate placement, one simulation-owned effects clock, pause and comfort.

const SYMBOLS = preload("res://scripts/games/kart_item_symbols.gd")
const RESONANCE = preload("res://scripts/games/kart_resonance_system.gd")
const RIVAL_FX = preload("res://scripts/games/kart_rival_item_fx.gd")
var completed: bool = false
var geometry_completed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _poses(node: Node3D) -> Array[Transform3D]:
	var result: Array[Transform3D] = [node.transform]
	for child in node.get_children():
		if child is Node3D:
			result.append_array(_poses(child))
	return result


func _check_front_faces(node: Node3D) -> void:
	if node is MeshInstance3D:
		var mesh: Mesh = node.mesh
		for surface_index in range(mesh.get_surface_count()):
			var arrays: Array = mesh.surface_get_arrays(surface_index)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			for index in range(0, vertices.size(), 3):
				var winding: Vector3 = (vertices[index + 1] - vertices[index]).cross(vertices[index + 2] - vertices[index])
				assert(winding.dot(normals[index]) < 0.0,
					"Godot's clockwise front faces must agree with outward normals for correct PBR lighting.")
	for child in node.get_children():
		if child is Node3D:
			_check_front_faces(child)


func _geometry_and_comfort() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var shape_sizes: Array[Vector3] = []
	for kind in SYMBOLS.KINDS:
		var symbol: Node3D = SYMBOLS.build(kind)
		stage.add_child(symbol)
		var body := symbol.get_node("SymbolMotion/SolidEmblem") as MeshInstance3D
		assert(body != null and body.mesh is ArrayMesh)
		_check_front_faces(symbol)
		var bounds: AABB = body.mesh.get_aabb()
		assert(bounds.size.z >= 0.25 and bounds.size.x > 0.7 and bounds.size.y > 0.7,
			"Held item emblems need a readable silhouette and actual thickness.")
		shape_sizes.append(bounds.size)
		var placement := Transform3D(Basis.from_euler(Vector3(0.2, 0.4, -0.1)), Vector3(3, 4, 5))
		symbol.transform = placement
		SYMBOLS.advance(symbol, 1.0)
		assert(symbol.transform.is_equal_approx(placement))
		SYMBOLS.advance(symbol, 1.0, true)
		var still: Array[Transform3D] = _poses(symbol)
		SYMBOLS.advance(symbol, 9.0, true)
		assert(_poses(symbol) == still, "Reduced motion stops bobbing, turning and pulse crescents.")
	assert(shape_sizes[0] != shape_sizes[1] and shape_sizes[1] != shape_sizes[2],
		"The three powers must be recognisable by shape, not only colour.")
	var frame := Transform3D(Basis.from_euler(Vector3(0.31, 1.2, -0.38)), Vector3(9, 7, -11))
	var gate: Node3D = RESONANCE.build_ring(stage, frame)
	RESONANCE.advance_ring(gate, 1.0)
	var moving: Array[Transform3D] = _poses(gate)
	RESONANCE.advance_ring(gate, 2.0)
	assert(gate.transform.is_equal_approx(frame), "Animation must preserve the banked road's root frame.")
	assert(_poses(gate) != moving, "A running gate must visibly animate descendants.")
	RESONANCE.advance_ring(gate, 2.0, true)
	var still_gate: Array[Transform3D] = _poses(gate)
	RESONANCE.advance_ring(gate, 23.0, true)
	assert(_poses(gate) == still_gate, "Comfort mode keeps the complete gate still.")
	var fx = RIVAL_FX.new()
	fx.set_item("shield")
	stage.add_child(fx)
	assert(fx.visual_state().item_visible and fx.visual_state().symbol_kind == "shield",
		"An item assigned before the visual enters the scene must still appear.")
	assert(not fx.is_processing(), "Only the active race advances rival effects.")
	fx.fire_pulse()
	fx.advance(0.1, false, true)
	var still_fx: Array[Transform3D] = _poses(fx)
	fx.advance(0.1, false, true)
	assert(_poses(fx) == still_fx, "Comfort mode keeps geometry still while lifetimes continue.")
	fx.advance(0.6, false, true)
	assert(not fx.visual_state().pulse_visible, "Comfort mode must not make a pulse effect immortal.")
	stage.free()
	geometry_completed = true


func _run() -> void:
	_geometry_and_comfort()
	if not geometry_completed:
		push_error("[KartItemSymbols] FAIL: geometry checks did not complete")
		quit(1)
		return
	var scene: PackedScene = load("res://scenes/games/kart_island.tscn")
	var game = scene.instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	await process_frame
	game._start_selected_race({
		"mode": "race", "driver": "fox", "kart": "comet",
		"track": "sonnenhafen", "difficulty": "gemuetlich",
	})
	game._end_preview()
	game.countdown = 0.0
	game.preview_left = 0.0
	game.racing = true
	game.paused = false
	game.reduced_motion = false
	game.auto_gas = false
	await process_frame
	assert(game.opponents.size() == 5 and game.opponent_item_fx.size() == 5,
		"The complete playable race must assemble before its effects can be tested.")
	var fx = game.opponent_item_fx[0]
	assert(not fx.is_processing(), "The real island must not have a second FX clock.")
	fx.fire_pulse()
	var gate_frames: Array[Transform3D] = []
	for gate in game.item_boxes:
		gate_frames.append(gate.transform)
	var before: float = fx.elapsed
	game._physics_process(0.05)
	assert(is_equal_approx(fx.elapsed, before + 0.05),
		"One real island physics step advances rival visuals exactly once.")
	assert(is_equal_approx(fx.pulse_age, 0.05))
	for index in range(game.item_boxes.size()):
		assert(game.item_boxes[index].transform.is_equal_approx(gate_frames[index]),
			"The real island keeps each gate at its exact sampled road orientation.")
	var clock: float = fx.elapsed
	var pulse: float = fx.pulse_age
	var gate_pose: Array[Transform3D] = _poses(game.item_boxes[0])
	var fx_pose: Array[Transform3D] = _poses(fx)
	game.paused = true
	game._physics_process(0.3)
	for _frame in range(4):
		await process_frame
	assert(fx.elapsed == clock and fx.pulse_age == pulse,
		"Pausing the actual island freezes both FX and pulse lifetime, including render frames.")
	assert(_poses(fx) == fx_pose and _poses(game.item_boxes[0]) == gate_pose)
	game.paused = false
	game.menu_active = true
	game._physics_process(0.3)
	assert(fx.elapsed == clock and fx.pulse_age == pulse, "Menus do not run rival FX.")
	game.menu_active = false
	game.racing = false
	game.countdown = 2.0
	game.preview_left = 1.0
	game._physics_process(0.1)
	assert(fx.elapsed == clock and fx.pulse_age == pulse, "The preview does not run rival FX.")
	game.preview_left = 0.0
	game.countdown = 0.0
	game.finished = true
	game.finish_cine_left = 1.0
	game._physics_process(0.1)
	assert(fx.elapsed == clock and fx.pulse_age == pulse, "The finish camera does not run rival FX.")
	game.finished = false
	game.finish_cine_left = 0.0
	game.racing = true
	game.reduced_motion = true
	game._physics_process(0.05)
	var quiet_gate: Array[Transform3D] = _poses(game.item_boxes[0])
	var quiet_fx: Array[Transform3D] = _poses(fx)
	game._physics_process(0.05)
	assert(_poses(game.item_boxes[0]) == quiet_gate and _poses(fx) == quiet_fx,
		"The actual island passes comfort preferences to both gate and rival effects.")
	assert(is_equal_approx(fx.elapsed, clock + 0.10))
	completed = true
	game.abandoned = true
	game.queue_free()
	for _frame in range(6):
		await process_frame
	await create_timer(1.3).timeout
	scene = null
	game = null
	assert(completed)
	print("[KartItemSymbols] PASS: distinct solid emblems, gate frame integrity, actual island clock/pause/preview/finish, reduced motion")
	quit(0)
