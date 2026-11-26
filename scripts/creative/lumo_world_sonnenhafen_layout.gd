extends RefCounted
## Deterministic town plan of Sonnenhafen (harbour town south of the mainland).
## Reads sonnenhafen_layout.json, fills the authored house rows with modular
## buildings from a fixed seed and derives the walkable navigation polygons.
## Pure data: no nodes, so the plan is testable headless and identical on
## every device and every visit.

const PATH := "res://assets/creative/lumo_world/sonnenhafen/sonnenhafen_layout.json"
const BAY := 3.2
const STOREY := 4.0
const WALL := 0.4
const DEPTH := 9.6
const HALL_DEPTH := 12.8
## Free space kept between walking figures and walls, water edges and props.
const CLEARANCE := 0.5
const EDGE := 0.6
const PLASTER_COLORS := [
	"f2c4a0", "f7e3a1", "a8d4e6", "f4ead2", "c9e4c5", "f2b8b0", "e6d3f0", "fbe8c8", "b9dfe0"
]
const BRICK_COLORS := ["c96a4a", "b5543a", "a8624a"]
const SHUTTER_COLORS := ["3f7fb0", "3f9a5a", "c0503a", "2f5f7a", "e0a030", "7a5aa0"]
const ROOF_TINTS := ["ffffff", "e8b8a0", "c89080", "f0d0b8"]
const PROP_FOOTPRINTS := {
	"stall_fish": Vector2(6.2, 2.8),
	"stall_fruit": Vector2(6.2, 2.8),
	"stall_bread": Vector2(6.2, 2.8),
	"fountain": Vector2(6.2, 6.2),
	"crane": Vector2(3.2, 3.2),
	"net_rack": Vector2(3.6, 0.6),
	"fish_crates": Vector2(1.8, 1.0),
	"rope_coil": Vector2(1.1, 1.1),
	"anchor": Vector2(1.4, 0.5),
	"crate_stack": Vector2(2.0, 2.0),
	"barrel_group": Vector2(1.6, 1.6),
	"bench": Vector2(2.4, 0.8),
	"flower_tub": Vector2(1.6, 1.6)
}

var data: Dictionary = {}
var errors: Array[String] = []
var buildings: Array[Dictionary] = []
var walkable: Array[Rect2] = []
var blocked: Array[Rect2] = []
var interior_rects: Dictionary = {}
var spots: Dictionary = {}
var lamps: Array[Vector3] = []


func _init(raw: Variant = null) -> void:
	if raw == null:
		raw = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not raw is Dictionary or raw.get("schemaVersion") != 1:
		errors.append("layout schema version 1 required")
		return
	data = raw
	for field in ["platform", "canal", "water", "bridges", "streets", "rows", "buildings", "spots"]:
		if not data.has(field):
			errors.append("layout needs " + field)
	if not errors.is_empty():
		return
	for id in data.spots:
		var point: Array = data.spots[id]
		spots[str(id)] = Vector3(float(point[0]), 0.0, float(point[1]))
	_generate_rows()
	for entry in data.buildings:
		buildings.append(_landmark(entry))
	_place_lamps()
	_derive_walkable()


func ready() -> bool:
	return errors.is_empty() and not data.is_empty()


static func rect(raw: Variant) -> Rect2:
	return Rect2(float(raw[0]), float(raw[1]), float(raw[2]), float(raw[3]))


func platform() -> Rect2:
	return rect(data.platform)


## Whole region including harbour water, for map views and LOD decisions.
func region_rect() -> Rect2:
	return rect(data.water).merge(rect(data.canal))


static func facing_yaw(facing: String) -> float:
	match facing:
		"s":
			return PI
		"e":
			return PI * 0.5
		"w":
			return -PI * 0.5
	return 0.0


## Building frame: origin at the front-centre on the ground, local +Z = facing,
## the building extends towards local -Z by its depth.
static func frame(building: Dictionary) -> Transform3D:
	var front: Vector2 = building.front
	return Transform3D(Basis(Vector3.UP, float(building.yaw)), Vector3(front.x, 0.0, front.y))


static func footprint(building: Dictionary) -> Rect2:
	var width := float(building.bays) * BAY
	var depth := float(building.depth)
	var xform := frame(building)
	var result := Rect2()
	var first := true
	for corner in [
		Vector3(-width * 0.5, 0, 0),
		Vector3(width * 0.5, 0, 0),
		Vector3(-width * 0.5, 0, -depth),
		Vector3(width * 0.5, 0, -depth)
	]:
		var at: Vector3 = xform * corner
		var point := Vector2(snappedf(at.x, 0.01), snappedf(at.z, 0.01))
		result = Rect2(point, Vector2.ZERO) if first else result.expand(point)
		first = false
	return result


## Walking target just outside a building's main door (bay index door_bay).
static func door_point(building: Dictionary, outside := 1.4) -> Vector3:
	var width := float(building.bays) * BAY
	var local_x := -width * 0.5 + BAY * (float(building.door_bay) + 0.5)
	return frame(building) * Vector3(local_x, 0.0, outside)


func building(id: String) -> Dictionary:
	for entry in buildings:
		if str(entry.id) == id:
			return entry
	return {}


func spot(id: String) -> Vector3:
	return spots.get(id, Vector3.INF)


## Resident homes are addressed as "<row id>:<house index>" or a landmark id.
func home_door(address: String) -> Vector3:
	var entry := building(address)
	return Vector3.INF if entry.is_empty() else door_point(entry)


func _generate_rows() -> void:
	var shop_names: Array = data.get("shop_names", [])
	var shop_index := 0
	for row in data.rows:
		var rng := RandomNumberGenerator.new()
		rng.seed = int(row.seed)
		var x0 := float(row.x[0])
		var x1 := float(row.x[1])
		var houses: Array[Dictionary] = []
		var cursor := 0.0
		var since_alley := 0
		while x1 - x0 - cursor >= BAY * 2.0 - 0.01:
			var room := x1 - x0 - cursor
			var kind: String = ["eave", "eave", "gable", "stepped", "eave"][rng.randi_range(0, 4)]
			var bays := 3 if kind != "eave" else rng.randi_range(2, 4)
			while float(bays) * BAY > room + 0.01 and bays > 2:
				bays -= 1
				kind = "eave"
			if float(bays) * BAY > room + 0.01:
				break
			houses.append({"kind": kind, "bays": bays, "offset": cursor})
			cursor += float(bays) * BAY
			since_alley += 1
			# A narrow alley now and then lets figures pass between the rows.
			if since_alley >= 3 and x1 - x0 - cursor >= BAY * 3.0:
				cursor += BAY
				since_alley = 0
		var slack := (x1 - x0 - cursor) * 0.5
		var shop_slots: Array[int] = []
		var wanted := int(row.get("shops", 0))
		var candidates: Array[int] = []
		for index in range(houses.size()):
			candidates.append(index)
		while shop_slots.size() < mini(wanted, houses.size()):
			var pick := candidates[rng.randi_range(0, candidates.size() - 1)]
			candidates.erase(pick)
			shop_slots.append(pick)
		for index in range(houses.size()):
			var house: Dictionary = houses[index]
			var width := float(house.bays) * BAY
			var center_x := x0 + slack + float(house.offset) + width * 0.5
			var facing := str(row.facing)
			var kind := str(house.kind)
			var style := "brick" if kind == "stepped" or rng.randf() < 0.2 else "plaster"
			var color: String = (
				BRICK_COLORS[rng.randi_range(0, BRICK_COLORS.size() - 1)]
				if style == "brick"
				else PLASTER_COLORS[rng.randi_range(0, PLASTER_COLORS.size() - 1)]
			)
			var storeys := int(row.storeys)
			if kind == "eave" and rng.randf() < 0.3:
				storeys = maxi(2, storeys - 1) if storeys == 3 else storeys + 1
			var entry := {
				"id": "%s:%d" % [str(row.id), index],
				"kind": "house",
				"title": "",
				"front": Vector2(center_x, float(row.front)),
				"facing": facing,
				"yaw": facing_yaw(facing),
				"bays": int(house.bays),
				"depth": DEPTH,
				"storeys": storeys,
				"style": style,
				"color": Color(color),
				"roof": "slate" if rng.randf() < 0.25 else "clay",
				"roof_tint": Color(ROOF_TINTS[rng.randi_range(0, ROOF_TINTS.size() - 1)]),
				"shutters": Color(SHUTTER_COLORS[rng.randi_range(0, SHUTTER_COLORS.size() - 1)]),
				"gable": kind,
				"door_bay": int(house.bays) / 2 if int(house.bays) != 2 else rng.randi_range(0, 1),
				"shop": "",
				"enterable": false,
				"open_front": false,
				"seed": int(row.seed) * 100 + index,
			}
			if index in shop_slots and shop_index < shop_names.size():
				entry.shop = str(shop_names[shop_index])
				shop_index += 1
			buildings.append(entry)


func _landmark(raw: Dictionary) -> Dictionary:
	var facing := str(raw.get("facing", "n"))
	var style := str(raw.get("style", "plaster"))
	var bays := int(raw.get("bays", 3))
	return {
		"id": str(raw.id),
		"kind": str(raw.get("kind", "house")),
		"title": str(raw.get("title", "")),
		"front": Vector2(float(raw.front[0]), float(raw.front[1])),
		"facing": facing,
		"yaw": facing_yaw(facing),
		"bays": bays,
		"depth": float(raw.get("depth", DEPTH)),
		"storeys": int(raw.get("storeys", 2)),
		"style": style,
		"color": Color(str(raw.get("color", "f4ead2"))),
		"roof": str(raw.get("roof", "slate")),
		"roof_tint": Color("ffffff"),
		"shutters": Color("3f5d6a"),
		"gable": "eave",
		"door_bay": bays / 2,
		"shop": str(raw.get("sign", "")),
		"enterable": bool(raw.get("enterable", false)),
		"open_front": bool(raw.get("open_front", false)),
		"seed": str(raw.id).hash() & 0xffff,
	}


func _place_lamps() -> void:
	var plat := platform()
	var x := plat.position.x + 7.0
	while x < plat.end.x - 3.0:
		lamps.append(Vector3(x, 0.0, plat.position.y + 0.42))
		lamps.append(Vector3(x + 7.0, 0.0, plat.end.y - 0.42))
		x += 14.0
	for lane_x in [96.0, 136.0, 168.0, 186.0, 214.0, 236.0, 258.0]:
		lamps.append(Vector3(lane_x, 0.0, -137.45))
	for market in [Vector2(174.6, -145.6), Vector2(225.4, -145.6)]:
		lamps.append(Vector3(market.x, 0.0, market.y))
	var mole: Dictionary = data.get("mole", {})
	if not mole.is_empty():
		var mole_rect := rect(mole.rect)
		var z := mole_rect.end.y - 6.0
		while z > mole_rect.position.y:
			lamps.append(Vector3(mole_rect.position.x + 0.42, 0.0, z))
			z -= 12.0


## Walking areas minus walls, props and water edges, all axis aligned.
func _derive_walkable() -> void:
	var plat := platform().grow(-EDGE)
	walkable.append(plat)
	for bridge in data.bridges:
		var area := rect(bridge.rect)
		var rail := 0.8 if str(bridge.kind) == "road" else 0.55
		walkable.append(
			Rect2(area.position.x + rail, area.position.y, area.size.x - rail * 2.0, area.size.y)
		)
	for path in data.get("mainland_paths", []):
		walkable.append(rect(path.rect))
	for pier in data.get("piers", []):
		var area := rect(pier.rect)
		walkable.append(
			Rect2(
				area.position.x + EDGE,
				area.position.y + EDGE,
				area.size.x - EDGE * 2.0,
				area.size.y - EDGE + 1.2
			)
		)
	var mole: Dictionary = data.get("mole", {})
	if not mole.is_empty():
		var area := rect(mole.rect)
		walkable.append(
			Rect2(
				area.position.x + EDGE, area.position.y, area.size.x - EDGE * 2.0, area.size.y + 1.2
			)
		)
		var tower: Vector2 = Vector2(float(mole.lighthouse[0]), float(mole.lighthouse[1]))
		walkable.append(Rect2(tower - Vector2(8, 8), Vector2(16, 16)).grow(-EDGE))
		blocked.append(Rect2(tower - Vector2(4, 4), Vector2(8, 8)).grow(CLEARANCE))
	for entry in buildings:
		if bool(entry.enterable) or bool(entry.open_front):
			_room_obstacles(entry)
		else:
			blocked.append(footprint(entry).grow(CLEARANCE))
	for prop in data.get("props", []):
		var size: Vector2 = PROP_FOOTPRINTS.get(str(prop.kind), Vector2.ZERO)
		if size == Vector2.ZERO:
			continue
		var yaw := float(prop.get("yaw", 0.0))
		var turned := absf(sin(yaw)) > 0.7
		var extent := Vector2(size.y, size.x) if turned else size
		var center := Vector2(float(prop.at[0]), float(prop.at[1]))
		blocked.append(Rect2(center - extent * 0.5, extent).grow(CLEARANCE * 0.6))
	for tree in data.get("trees", []):
		blocked.append(
			Rect2(Vector2(float(tree[0]), float(tree[1])) - Vector2(0.7, 0.7), Vector2(1.4, 1.4))
		)


## Enterable and open buildings: walls are obstacles, the doorway stays open.
func _room_obstacles(entry: Dictionary) -> void:
	var width := float(entry.bays) * BAY
	var depth := float(entry.depth)
	var xform := frame(entry)
	var door_x := -width * 0.5 + BAY * (float(entry.door_bay) + 0.5)
	var gap := 1.6
	var pieces: Array[Rect2] = [
		Rect2(-width * 0.5, -depth, width, WALL),
		Rect2(-width * 0.5, -depth, WALL, depth),
		Rect2(width * 0.5 - WALL, -depth, WALL, depth)
	]
	if bool(entry.open_front):
		for bay in range(int(entry.bays) + 1):
			var post_x := -width * 0.5 + float(bay) * BAY
			pieces.append(Rect2(post_x - 0.3, -0.6, 0.6, 0.6))
	else:
		pieces.append(Rect2(-width * 0.5, -WALL, door_x - gap + width * 0.5, WALL))
		pieces.append(Rect2(door_x + gap, -WALL, width * 0.5 - door_x - gap, WALL))
	for piece in pieces:
		blocked.append(_world_rect(xform, piece).grow(CLEARANCE))
	interior_rects[str(entry.id)] = _world_rect(
		xform, Rect2(-width * 0.5 + WALL, -depth + WALL, width - WALL * 2.0, depth - WALL)
	)
	var furniture: Dictionary = data.get("interiors", {}).get(str(entry.id), {})
	for key in ["counter", "desk"]:
		if furniture.has(key):
			var at: Array = furniture[key]
			blocked.append(
				_turned_rect(Vector2(float(at[0]), float(at[1])), Vector2(4.2, 1.2), float(at[2]))
			)
	for key in ["shelves", "pallets"]:
		for at in furniture.get(key, []):
			var size := Vector2(3.2, 0.9) if key == "shelves" else Vector2(2.0, 1.6)
			blocked.append(_turned_rect(Vector2(float(at[0]), float(at[1])), size, float(at[2])))
	if furniture.has("board"):
		var board: Array = furniture.board
		blocked.append(
			_turned_rect(
				Vector2(float(board[0]), float(board[1])), Vector2(3.0, 0.4), float(board[2])
			)
		)


static func _turned_rect(center: Vector2, size: Vector2, yaw: float) -> Rect2:
	var extent := Vector2(size.y, size.x) if absf(sin(yaw)) > 0.7 else size
	return Rect2(center - extent * 0.5, extent).grow(CLEARANCE * 0.6)


static func _world_rect(xform: Transform3D, local: Rect2) -> Rect2:
	var result := Rect2()
	var first := true
	for corner in [
		local.position,
		Vector2(local.end.x, local.position.y),
		local.end,
		Vector2(local.position.x, local.end.y)
	]:
		var at: Vector3 = xform * Vector3(corner.x, 0.0, corner.y)
		var point := Vector2(snappedf(at.x, 0.01), snappedf(at.z, 0.01))
		result = Rect2(point, Vector2.ZERO) if first else result.expand(point)
		first = false
	return result


func is_walkable(point: Vector2) -> bool:
	var inside := false
	for area in walkable:
		if area.has_point(point):
			inside = true
			break
	if not inside:
		return false
	for area in blocked:
		if area.has_point(point):
			return false
	return true


## Coordinate-compressed grid: every rectangle edge splits the plane and each
## horizontal run of free cells becomes one convex strip polygon. Strips carry
## every break point of their neighbouring rows as (collinear) vertices, so
## shared edges match exactly and the navigation map connects them without a
## runtime bake.
func nav_polygons() -> Dictionary:
	var xs_set: Dictionary = {}
	var zs_set: Dictionary = {}
	for area in walkable + blocked:
		for value in [area.position.x, area.end.x]:
			xs_set[snappedf(value, 0.25)] = true
		for value in [area.position.y, area.end.y]:
			zs_set[snappedf(value, 0.25)] = true
	var xs: Array = xs_set.keys()
	var zs: Array = zs_set.keys()
	xs.sort()
	zs.sort()
	var runs: Array = []
	for j in range(zs.size() - 1):
		var row_runs: Array[Vector2i] = []
		var start := -1
		for i in range(xs.size()):
			var free := false
			if i < xs.size() - 1:
				free = is_walkable(Vector2((xs[i] + xs[i + 1]) * 0.5, (zs[j] + zs[j + 1]) * 0.5))
			if free and start < 0:
				start = i
			elif not free and start >= 0:
				row_runs.append(Vector2i(start, i))
				start = -1
		runs.append(row_runs)
	var breaks: Array = []
	for line in range(zs.size()):
		var points: Dictionary = {}
		for row in [line - 1, line]:
			if row < 0 or row >= runs.size():
				continue
			for run in runs[row]:
				points[run.x] = true
				points[run.y] = true
		var sorted_points: Array = points.keys()
		sorted_points.sort()
		breaks.append(sorted_points)
	var vertices := PackedVector3Array()
	var index_of: Dictionary = {}
	var polygons: Array[PackedInt32Array] = []
	for j in range(runs.size()):
		for run in runs[j]:
			var bottom: Array[int] = []
			for i in breaks[j]:
				if i >= run.x and i <= run.y:
					bottom.append(_vertex(Vector2i(i, j), xs, zs, vertices, index_of))
			var top: Array[int] = []
			for i in breaks[j + 1]:
				if i >= run.x and i <= run.y:
					top.append(_vertex(Vector2i(i, j + 1), xs, zs, vertices, index_of))
			# Zig-zag triangles between both edges: no degenerate (collinear)
			# triangles, and every break point stays a shared vertex.
			var b := 0
			var t := 0
			while b < bottom.size() - 1 or t < top.size() - 1:
				var advance_bottom := t >= top.size() - 1
				if not advance_bottom and b < bottom.size() - 1:
					advance_bottom = vertices[bottom[b + 1]].x <= vertices[top[t + 1]].x
				if advance_bottom:
					polygons.append(PackedInt32Array([bottom[b], bottom[b + 1], top[t]]))
					b += 1
				else:
					polygons.append(PackedInt32Array([bottom[b], top[t + 1], top[t]]))
					t += 1
	return {"vertices": vertices, "polygons": polygons}


static func _vertex(
	corner: Vector2i, xs: Array, zs: Array, vertices: PackedVector3Array, index_of: Dictionary
) -> int:
	if not index_of.has(corner):
		index_of[corner] = vertices.size()
		vertices.append(Vector3(float(xs[corner.x]), 0.0, float(zs[corner.y])))
	return int(index_of[corner])


## Ground rectangles kept free of the mainland tree scatter.
func clear_areas() -> Array[Rect2]:
	var areas: Array[Rect2] = []
	for path in data.get("mainland_paths", []):
		areas.append(rect(path.rect).grow(3.0))
	for bridge in data.bridges:
		areas.append(rect(bridge.rect).grow(3.0))
	return areas
