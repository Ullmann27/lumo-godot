extends RefCounted
## Geometry-independent placement, structural support, undo and goal checks.
const CATALOG = preload("res://scripts/creative/build_catalog.gd")
const LIMIT: int = 768
const SAVE_VERSION: int = 1
var pieces: Array[Dictionary] = []
var undo_stack: Array = []
var redo_stack: Array = []
var completed: Array[String] = []
var free_build: bool = false
var next_id: int = 1


static func ground_at(x: int, z: int) -> bool:
	return abs(x) <= 16 and abs(z) <= 16 and not (x >= 0 and x <= 3)


static func cells(piece: Dictionary) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	var size: Vector3i = CATALOG.size_of(str(piece.part), int(piece.turn))
	var origin := Vector3i(int(piece.x), int(piece.y), int(piece.z))
	for x in range(size.x):
		for y in range(size.y):
			for z in range(size.z):
				result.append(origin + Vector3i(x, y, z))
	return result


func occupied(exclude_id: int = -1) -> Dictionary:
	var result: Dictionary = {}
	for piece in pieces:
		if int(piece.uid) == exclude_id:
			continue
		for cell in cells(piece):
			result[cell] = int(piece.uid)
	return result


func placement_error(part_id: String, at: Vector3i, turn: int = 0) -> String:
	if CATALOG.part(part_id).is_empty():
		return "Dieses Bauteil gibt es nicht."
	if pieces.size() >= LIMIT:
		return "Deine Welt ist voll. Entferne zuerst ein Bauteil."
	var piece: Dictionary = {
		"part": part_id, "x": at.x, "y": at.y, "z": at.z, "turn": posmod(turn, 4)
	}
	var taken: Dictionary = occupied()
	var size: Vector3i = CATALOG.size_of(part_id, turn)
	for cell in cells(piece):
		if abs(cell.x) > 16 or abs(cell.z) > 16 or cell.y < 0 or cell.y > 19:
			return "Baue innerhalb deiner Insel und unter der Höhenmarkierung."
		if taken.has(cell):
			return "Hier steht schon ein Bauteil. Wähle einen freien Platz."
	if free_build:
		return ""
	var supports: int = 0
	for x in range(size.x):
		for z in range(size.z):
			var foot := at + Vector3i(x, 0, z)
			if (foot.y == 0 and ground_at(foot.x, foot.z)) or taken.has(foot + Vector3i.DOWN):
				supports += 1
	if supports > 0:
		return ""
	# Bridges may connect horizontally to a supported deck; ordinary blocks cannot float.
	if part_id == "bridge":
		for cell in cells(piece):
			for direction in [Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK]:
				if taken.has(cell + direction):
					return ""
	return "Das Bauteil braucht Boden oder ein tragendes Bauteil darunter."


func _remember() -> void:
	undo_stack.append(pieces.duplicate(true))
	if undo_stack.size() > 64:
		undo_stack.pop_front()
	redo_stack.clear()


func place(part_id: String, at: Vector3i, turn: int = 0) -> String:
	var problem: String = placement_error(part_id, at, turn)
	if not problem.is_empty():
		return problem
	_remember()
	pieces.append(
		{"uid": next_id, "part": part_id, "x": at.x, "y": at.y, "z": at.z, "turn": posmod(turn, 4)}
	)
	next_id += 1
	return ""


func remove(uid: int) -> bool:
	for i in range(pieces.size()):
		if int(pieces[i].uid) == uid:
			if not free_build and _removal_loses_support(uid):
				return false
			_remember()
			pieces.remove_at(i)
			return true
	return false


func _removal_loses_support(uid: int) -> bool:
	var taken := occupied(uid)
	for piece in pieces:
		if int(piece.uid) == uid:
			continue
		var at := Vector3i(piece.x, piece.y, piece.z)
		var size: Vector3i = CATALOG.size_of(str(piece.part), int(piece.turn))
		var supported := false
		for x in range(size.x):
			for z in range(size.z):
				var foot := at + Vector3i(x, 0, z)
				supported = (
					supported
					or (foot.y == 0 and ground_at(foot.x, foot.z))
					or taken.has(foot + Vector3i.DOWN)
				)
		if not supported and piece.part == "bridge":
			for cell in cells(piece):
				for direction in [Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK]:
					supported = supported or taken.has(cell + direction)
		if not supported:
			return true
	return false


func undo() -> bool:
	if undo_stack.is_empty():
		return false
	redo_stack.append(pieces.duplicate(true))
	pieces.assign(undo_stack.pop_back())
	return true


func redo() -> bool:
	if redo_stack.is_empty():
		return false
	undo_stack.append(pieces.duplicate(true))
	pieces.assign(redo_stack.pop_back())
	return true


func clear() -> void:
	_remember()
	pieces.clear()


func bridge_path() -> Array[Vector3i]:
	# Ground-to-ground crossing on one connected deck elevation, not a piece counter.
	var decks: Dictionary = {}
	for piece in pieces:
		if piece.part not in ["bridge", "path", "platform", "stone", "wood", "sand", "grass"]:
			continue
		var size: Vector3i = CATALOG.size_of(str(piece.part), int(piece.turn))
		for x in range(size.x):
			for z in range(size.z):
				decks[Vector3i(int(piece.x) + x, int(piece.y) + size.y - 1, int(piece.z) + z)] = true
	for elevation in range(4):
		var queue: Array[Vector3i] = []
		var previous: Dictionary = {}
		for cell: Vector3i in decks:
			if cell.x == -1 and cell.y == elevation:
				queue.append(cell)
				previous[cell] = cell
		var index: int = 0
		while index < queue.size():
			var current: Vector3i = queue[index]
			index += 1
			if current.x == 4:
				var path: Array[Vector3i] = [current]
				while previous[path[-1]] != path[-1]:
					path.append(previous[path[-1]])
				path.reverse()
				return path
			for direction in [Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK]:
				var neighbor: Vector3i = current + direction
				if decks.has(neighbor) and not previous.has(neighbor):
					previous[neighbor] = current
					queue.append(neighbor)
	return []


func challenge_passes(id: String) -> bool:
	if id == "bridge":
		return not bridge_path().is_empty()
	if id == "house":
		for roof in pieces:
			if not str(roof.part).begins_with("roof") or int(roof.y) < 2:
				continue
			var walls: int = 0
			var door: bool = false
			var roof_size: Vector3i = CATALOG.size_of(str(roof.part), int(roof.turn))
			for support in pieces:
				if support.part not in ["wall", "door"]:
					continue
				if (
					int(support.x) >= int(roof.x)
					and int(support.x) < int(roof.x) + roof_size.x
					and int(support.z) >= int(roof.z)
					and int(support.z) < int(roof.z) + roof_size.z
					and int(support.y) + 2 == int(roof.y)
				):
					walls += 1
					door = door or support.part == "door"
			if walls >= 4 and door:
				return true
	if id == "tower":
		var taken: Dictionary = occupied()
		for piece in pieces:
			if piece.part == "lantern" and int(piece.y) >= 5:
				var continuous: bool = true
				for y in range(int(piece.y)):
					continuous = continuous and taken.has(Vector3i(int(piece.x), y, int(piece.z)))
				if continuous:
					return true
	if id == "garden":
		var kinds: Dictionary = {}
		for piece in pieces:
			if piece.part in ["tree", "flowers", "bench", "lantern"]:
				kinds[piece.part] = true
		return kinds.size() == 4
	if id == "castle":
		var towers := 0
		for piece in pieces:
			if piece.part == "roof_round" and int(piece.y) >= 6:
				towers += 1
		return towers >= 4 and challenge_passes("house")
	if id == "village":
		var doors := 0
		for piece in pieces:
			if piece.part == "door":
				doors += 1
		return (
			doors >= 3
			and challenge_passes("house")
			and challenge_passes("garden")
			and challenge_passes("bridge")
		)

	return false


func to_data() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"pieces": pieces.duplicate(true),
		"completed": completed.duplicate(),
		"next_id": next_id,
		"free_build": free_build
	}


func restore(data: Dictionary) -> bool:
	if (
		int(data.get("version", 0)) != SAVE_VERSION
		or not data.get("pieces") is Array
		or data.pieces.size() > LIMIT
	):
		return false
	var restored: Array[Dictionary] = []
	var seen: Dictionary = {}
	var used: Dictionary = {}
	var largest: int = 0
	for raw in data.pieces:
		if not raw is Dictionary:
			return false
		for key in ["uid", "part", "x", "y", "z", "turn"]:
			if not raw.has(key):
				return false
		var part_id: String = str(raw.part)
		if CATALOG.part(part_id).is_empty() or int(raw.uid) <= 0 or seen.has(int(raw.uid)):
			return false
		var piece: Dictionary = {
			"uid": int(raw.uid),
			"part": part_id,
			"x": int(raw.x),
			"y": int(raw.y),
			"z": int(raw.z),
			"turn": posmod(int(raw.turn), 4)
		}
		for cell in cells(piece):
			if used.has(cell) or abs(cell.x) > 16 or abs(cell.z) > 16 or cell.y < 0 or cell.y > 19:
				return false
			used[cell] = true
		seen[piece.uid] = true
		largest = maxi(largest, int(piece.uid))
		restored.append(piece)
	pieces = restored
	completed.clear()
	for id in data.get("completed", []):
		if (
			str(id) in ["house", "bridge", "tower", "garden", "castle", "village"]
			and not completed.has(str(id))
		):
			completed.append(str(id))
	next_id = maxi(largest + 1, int(data.get("next_id", 1)))
	free_build = bool(data.get("free_build", false))
	undo_stack.clear()
	redo_stack.clear()
	return true


func template(id: String) -> void:
	clear()
	if id == "house":
		for x in range(3):
			for z in range(3):
				if x == 1 and z == 1:
					continue
				place("door" if x == 1 and z == 2 else "wall", Vector3i(-8 + x, 0, -5 + z))
		place("roof", Vector3i(-8, 2, -5))
	elif id == "castle":
		for origin in [
			Vector3i(-13, 0, -11), Vector3i(-5, 0, -11), Vector3i(-13, 0, -3), Vector3i(-5, 0, -3)
		]:
			for y in range(6):
				for x in range(2):
					for z in range(2):
						place("sand", origin + Vector3i(x, y, z))
			place("roof_round", origin + Vector3i(0, 6, 0))
		for x in range(-11, -5):
			for z in [-11, -2]:
				if z == -2 and x in [-9, -8, -7]:
					continue
				place("wall", Vector3i(x, 0, z))
				place("wall", Vector3i(x, 2, z))
		place("arch", Vector3i(-9, 0, -2))
		for z in range(-1, 4):
			place("path", Vector3i(-8, 0, z))
		for z in range(-9, -3):
			for x in [-13, -4]:
				place("wall", Vector3i(x, 0, z))
				place("wall", Vector3i(x, 2, z))
		for x in range(-10, -7):
			for z in range(-8, -5):
				if x == -9 and z == -7:
					continue
				place("door" if x == -9 and z == -6 else "wall", Vector3i(x, 0, z))
		place("roof", Vector3i(-10, 2, -8))
		place("lantern", Vector3i(-7, 0, -7))
		place("flowers", Vector3i(-6, 0, -8))
	elif id == "village":
		for origin in [Vector3i(-12, 0, -10), Vector3i(-7, 0, -10), Vector3i(7, 0, -7)]:
			for x in range(3):
				for z in range(3):
					if x == 1 and z == 1:
						continue
					place("door" if x == 1 and z == 2 else "wall", origin + Vector3i(x, 0, z))
			place("roof", origin + Vector3i(0, 2, 0))
		place("tree", Vector3i(-11, 0, -2))
		place("flowers", Vector3i(-7, 0, -2))
		place("bench", Vector3i(-9, 0, 1))
		place("lantern", Vector3i(-5, 0, 1))
		place("bridge", Vector3i(-1, 0, 2))
		place("bridge", Vector3i(2, 0, 2))

	elif id == "bridge":
		place("bridge", Vector3i(-1, 0, 2))
		place("bridge", Vector3i(2, 0, 2))
	elif id == "tower":
		for y in range(6):
			place("sand", Vector3i(-6, y, 1))
		place("lantern", Vector3i(-6, 6, 1))
	elif id == "garden":
		place("tree", Vector3i(-9, 0, 1))
		place("flowers", Vector3i(-6, 0, 1))
		place("bench", Vector3i(-8, 0, 4))
		place("lantern", Vector3i(-5, 0, 4))
