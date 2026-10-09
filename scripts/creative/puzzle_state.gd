extends RefCounted
## Matching jigsaw pieces, original shared edges and validated per-child snapshots.
const COUNTS = [12, 24, 48, 96]
const GRIDS = [Vector2i(4, 3), Vector2i(6, 4), Vector2i(8, 6), Vector2i(12, 8)]
var count: int = 12
var columns: int = 4
var rows: int = 3
var motif: int = 0
var pieces: Array[Dictionary] = []
var result_id: String = ""
var hints: int = 0
var moves: int = 0
var elapsed: float = 0


func setup(total: int, image: int) -> void:
	var choice: int = COUNTS.find(total)
	if choice < 0:
		choice = 0
	count = COUNTS[choice]
	columns = GRIDS[choice].x
	rows = GRIDS[choice].y
	motif = clampi(image, 0, 2)
	pieces.clear()
	hints = 0
	moves = 0
	elapsed = 0
	for i in range(count):
		pieces.append(
			{
				"id": i,
				"locked": false,
				"tray": true,
				"x": -7.0 if i % 2 == 0 else 7.0,
				"z": -2.5 + (i % 12) * 0.5
			}
		)


func board_size() -> Vector2:
	# Keep original artwork square or widescreen, including saved puzzles.
	return Vector2(6.0, 6.0) if motif == 0 else Vector2(9.6, 5.4)


func cell_size() -> Vector2:
	return board_size() / Vector2(columns, rows)


func target(id: int) -> Vector2:
	var cell := cell_size()
	var board := board_size()
	return Vector2(
		(id % columns + 0.5) * cell.x - board.x * 0.5, (id / columns + 0.5) * cell.y - board.y * 0.5
	)


func is_edge(id: int) -> bool:
	return id % columns in [0, columns - 1] or id / columns in [0, rows - 1]


func edge_sign(id: int, side: int) -> int:
	var x: int = id % columns
	var y: int = id / columns
	match side:
		0:
			return 0 if y == 0 else -_shared(x, y - 1, true)
		1:
			return 0 if x == columns - 1 else _shared(x, y, false)
		2:
			return 0 if y == rows - 1 else _shared(x, y, true)
		_:
			return 0 if x == 0 else -_shared(x - 1, y, false)


func _shared(x: int, y: int, horizontal: bool) -> int:
	return 1 if posmod(x * 19 + y * 13 + (7 if horizontal else 2), 3) else -1


func outline(id: int) -> PackedVector2Array:
	var size := cell_size()
	var corners := [
		Vector2(-size.x / 2, -size.y / 2),
		Vector2(size.x / 2, -size.y / 2),
		Vector2(size.x / 2, size.y / 2),
		Vector2(-size.x / 2, size.y / 2)
	]
	var shape := PackedVector2Array()
	for side in range(4):
		var a: Vector2 = corners[side]
		var b: Vector2 = corners[(side + 1) % 4]
		var along: Vector2 = b - a
		var outward := Vector2(along.y, -along.x).normalized()
		var sign: int = edge_sign(id, side)
		shape.append(a)
		if sign == 0:
			continue
		shape.append(a + along * 0.34)
		for i in range(9):
			var angle: float = PI + i * PI / 8
			var radius: float = minf(size.x, size.y) * 0.13
			shape.append(
				(
					a
					+ along * 0.5
					+ along.normalized() * cos(angle) * radius
					+ outward * (-sin(angle)) * radius * sign
				)
			)
		shape.append(a + along * 0.66)
	return shape


func try_snap(id: int, at: Vector2) -> bool:
	if id < 0 or id >= pieces.size() or pieces[id].locked:
		return false
	moves += 1
	pieces[id].x = at.x
	pieces[id].z = at.y
	pieces[id]["tray"] = absf(at.x) > board_size().x * 0.5 or absf(at.y) > board_size().y * 0.5
	if at.distance_to(target(id)) > minf(cell_size().x, cell_size().y) * 0.32:
		return false
	pieces[id].locked = true
	pieces[id].x = target(id).x
	pieces[id].z = target(id).y
	return true


func placed() -> int:
	var amount: int = 0
	for piece in pieces:
		if piece.locked:
			amount += 1
	return amount


func complete() -> bool:
	return not pieces.is_empty() and placed() == count


func to_data() -> Dictionary:
	return {
		"version": 1,
		"count": count,
		"motif": motif,
		"pieces": pieces.duplicate(true),
		"result_id": result_id,
		"hints": hints,
		"moves": moves,
		"elapsed": elapsed
	}


func restore(data: Dictionary) -> bool:
	if (
		int(data.get("version", 0)) != 1
		or int(data.get("count", 0)) not in COUNTS
		or int(data.get("motif", -1)) not in [0, 1, 2]
	):
		return false
	var total: int = int(data.count)
	if not data.get("pieces") is Array or data.pieces.size() != total:
		return false
	var restored: Array[Dictionary] = []
	var seen: Dictionary = {}
	for raw in data.pieces:
		if (
			not raw is Dictionary
			or int(raw.get("id", -1)) < 0
			or int(raw.id) >= total
			or seen.has(int(raw.id))
		):
			return false
		var x: float = float(raw.get("x", INF))
		var z: float = float(raw.get("z", INF))
		if not is_finite(x) or not is_finite(z) or absf(x) > 10 or absf(z) > 8:
			return false
		seen[int(raw.id)] = true
		restored.append(
			{
				"id": int(raw.id),
				"locked": bool(raw.get("locked", false)),
				"tray": bool(raw.get("tray", true)),
				"x": x,
				"z": z
			}
		)
	setup(total, int(data.motif))
	restored.sort_custom(func(a, b): return int(a.id) < int(b.id))
	pieces = restored
	for piece in pieces:
		if piece.locked:
			piece.x = target(int(piece.id)).x
			piece.z = target(int(piece.id)).y
	result_id = str(data.get("result_id", ""))
	hints = clampi(int(data.get("hints", 0)), 0, 10000)
	moves = maxi(0, int(data.get("moves", 0)))
	elapsed = maxf(0, float(data.get("elapsed", 0)))
	return true
