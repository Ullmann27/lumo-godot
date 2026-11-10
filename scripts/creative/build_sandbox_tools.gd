extends RefCounted
## Atomic multi-piece editing helpers for the Bauwelt sandbox.
##
## Every successful operation creates exactly one undo snapshot. A failed
## operation restores both pieces and next_id, so partial fills/copies can
## never leak into a child's saved world.

const CATALOG = preload("res://scripts/creative/build_catalog.gd")
const MAX_BATCH: int = 256


static func fill_rect(
	state: RefCounted, part_id: String, corner_a: Vector3i, corner_b: Vector3i, turn: int = 0
) -> Dictionary:
	if corner_a.y != corner_b.y:
		return _failure("Füllen arbeitet immer auf genau einer Ebene.")
	if CATALOG.part(part_id).is_empty():
		return _failure("Dieses Bauteil gibt es nicht.")
	var low := Vector3i(mini(corner_a.x, corner_b.x), corner_a.y, mini(corner_a.z, corner_b.z))
	var high := Vector3i(maxi(corner_a.x, corner_b.x), corner_a.y, maxi(corner_a.z, corner_b.z))
	var size: Vector3i = CATALOG.size_of(part_id, turn)
	var specs: Array[Dictionary] = []
	var x := low.x
	while x + size.x - 1 <= high.x:
		var z := low.z
		while z + size.z - 1 <= high.z:
			(
				specs
				. append(
					{
						"part": part_id,
						"at": Vector3i(x, low.y, z),
						"turn": posmod(turn, 4),
					}
				)
			)
			z += maxi(1, size.z)
		x += maxi(1, size.x)
	return _apply_batch(state, specs)


static func copy_region(
	state: RefCounted, corner_a: Vector3i, corner_b: Vector3i, offset: Vector3i
) -> Dictionary:
	if offset == Vector3i.ZERO:
		return _failure("Wähle für die Kopie einen anderen Zielbereich.")
	var bounds: Array[Vector3i] = _bounds(corner_a, corner_b)
	var specs: Array[Dictionary] = []
	for piece in state.pieces:
		if not _piece_inside(piece, bounds[0], bounds[1]):
			continue
		(
			specs
			. append(
				{
					"part": str(piece.part),
					"at": Vector3i(int(piece.x), int(piece.y), int(piece.z)) + offset,
					"turn": int(piece.turn),
				}
			)
		)
	if specs.is_empty():
		return _failure("Im gewählten Bereich steht nichts zum Kopieren.")
	return _apply_batch(state, specs)


static func mirror_copy_region(
	state: RefCounted, corner_a: Vector3i, corner_b: Vector3i, axis: String, offset: Vector3i
) -> Dictionary:
	if axis not in ["x", "z"]:
		return _failure("Spiegelachse muss x oder z sein.")
	var bounds: Array[Vector3i] = _bounds(corner_a, corner_b)
	var low: Vector3i = bounds[0]
	var high: Vector3i = bounds[1]
	var specs: Array[Dictionary] = []
	for piece in state.pieces:
		if not _piece_inside(piece, low, high):
			continue
		var turn := int(piece.turn)
		var size: Vector3i = CATALOG.size_of(str(piece.part), turn)
		var at := Vector3i(int(piece.x), int(piece.y), int(piece.z))
		var mirrored_turn := turn
		if axis == "x":
			at.x = low.x + high.x - (at.x + size.x - 1)
			mirrored_turn = posmod(4 - turn, 4)
		else:
			at.z = low.z + high.z - (at.z + size.z - 1)
			mirrored_turn = posmod(2 - turn, 4)
		(
			specs
			. append(
				{
					"part": str(piece.part),
					"at": at + offset,
					"turn": mirrored_turn,
				}
			)
		)
	if specs.is_empty():
		return _failure("Im gewählten Bereich steht nichts zum Spiegeln.")
	return _apply_batch(state, specs)


static func _apply_batch(state: RefCounted, specs: Array[Dictionary]) -> Dictionary:
	if specs.is_empty():
		return _failure("Der gewählte Bereich enthält keine passenden Felder.")
	if specs.size() > MAX_BATCH:
		return _failure("Der Bereich ist zu groß. Wähle höchstens %d neue Teile." % MAX_BATCH)
	if state.pieces.size() + specs.size() > state.LIMIT:
		return _failure("Deine Welt hat nicht genug freie Bauplätze für diese Aktion.")

	var before: Array = state.pieces.duplicate(true)
	var before_next: int = int(state.next_id)
	for spec in specs:
		var at: Vector3i = spec.at
		var turn: int = posmod(int(spec.turn), 4)
		var problem: String = state.placement_error(str(spec.part), at, turn)
		if not problem.is_empty():
			state.pieces.assign(before)
			state.next_id = before_next
			return _failure(problem)
		(
			state
			. pieces
			. append(
				{
					"uid": state.next_id,
					"part": str(spec.part),
					"x": at.x,
					"y": at.y,
					"z": at.z,
					"turn": turn,
				}
			)
		)
		state.next_id += 1

	state.undo_stack.append(before)
	if state.undo_stack.size() > 64:
		state.undo_stack.pop_front()
	state.redo_stack.clear()
	return {"ok": true, "count": specs.size(), "error": ""}


static func _piece_inside(piece: Dictionary, low: Vector3i, high: Vector3i) -> bool:
	var size: Vector3i = CATALOG.size_of(str(piece.part), int(piece.turn))
	var at := Vector3i(int(piece.x), int(piece.y), int(piece.z))
	var far := at + size - Vector3i.ONE
	return (
		at.x >= low.x
		and at.y >= low.y
		and at.z >= low.z
		and far.x <= high.x
		and far.y <= high.y
		and far.z <= high.z
	)


static func _bounds(a: Vector3i, b: Vector3i) -> Array[Vector3i]:
	return [
		Vector3i(mini(a.x, b.x), mini(a.y, b.y), mini(a.z, b.z)),
		Vector3i(maxi(a.x, b.x), maxi(a.y, b.y), maxi(a.z, b.z)),
	]


static func _failure(message: String) -> Dictionary:
	return {"ok": false, "count": 0, "error": message}
