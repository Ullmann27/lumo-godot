extends RefCounted
## Original construction kit from Heinz' Bauwelt board. Dimensions are grid cells.

const PARTS: Array[Dictionary] = [
	{
		"id": "stone",
		"name": "Stein",
		"category": "Bauen",
		"size": Vector3i(1, 1, 1),
		"shape": "box",
		"color": Color("b8becd")
	},
	{
		"id": "wood",
		"name": "Holz",
		"category": "Bauen",
		"size": Vector3i(1, 1, 1),
		"shape": "box",
		"color": Color("b88a50")
	},
	{
		"id": "sand",
		"name": "Sandstein",
		"category": "Bauen",
		"size": Vector3i(1, 1, 1),
		"shape": "box",
		"color": Color("edce98")
	},
	{
		"id": "glass",
		"name": "Glas",
		"category": "Bauen",
		"size": Vector3i(1, 1, 1),
		"shape": "glass",
		"color": Color("54d8ff")
	},
	{
		"id": "magic",
		"name": "Magie",
		"category": "Bauen",
		"size": Vector3i(1, 1, 1),
		"shape": "box",
		"color": Color("aa79eb"),
		"glow": true
	},
	{
		"id": "wall",
		"name": "Mauer",
		"category": "Bauen",
		"size": Vector3i(1, 2, 1),
		"shape": "wall",
		"color": Color("dfc99c")
	},
	{
		"id": "arch",
		"name": "Bogen",
		"category": "Bauen",
		"size": Vector3i(3, 3, 1),
		"shape": "arch",
		"color": Color("edce98")
	},
	{
		"id": "door",
		"name": "Haustür",
		"category": "Bauen",
		"size": Vector3i(1, 2, 1),
		"shape": "door",
		"color": Color("8e6848")
	},
	{
		"id": "pillar",
		"name": "Säule",
		"category": "Bauen",
		"size": Vector3i(1, 3, 1),
		"shape": "pillar",
		"color": Color("c5cce0")
	},
	{
		"id": "stairs",
		"name": "Treppe",
		"category": "Bauen",
		"size": Vector3i(1, 2, 3),
		"shape": "stairs",
		"color": Color("d4c7ae")
	},
	{
		"id": "roof",
		"name": "Spitzdach",
		"category": "Dächer",
		"size": Vector3i(3, 2, 3),
		"shape": "roof",
		"color": Color("3b66ca")
	},
	{
		"id": "roof_red",
		"name": "Rotes Dach",
		"category": "Dächer",
		"size": Vector3i(3, 2, 3),
		"shape": "roof",
		"color": Color("c86971")
	},
	{
		"id": "roof_round",
		"name": "Turmdach",
		"category": "Dächer",
		"size": Vector3i(3, 2, 3),
		"shape": "cone",
		"color": Color("5572d8")
	},
	{
		"id": "roof_flat",
		"name": "Flachdach",
		"category": "Dächer",
		"size": Vector3i(3, 1, 3),
		"shape": "box",
		"color": Color("526d9a")
	},
	{
		"id": "path",
		"name": "Weg",
		"category": "Wege",
		"size": Vector3i(1, 1, 1),
		"shape": "paving",
		"color": Color("acb9c9")
	},
	{
		"id": "bridge",
		"name": "Brücke",
		"category": "Wege",
		"size": Vector3i(3, 1, 1),
		"shape": "bridge",
		"color": Color("c4c5cf")
	},
	{
		"id": "platform",
		"name": "Plattform",
		"category": "Wege",
		"size": Vector3i(3, 1, 3),
		"shape": "box",
		"color": Color("cda972")
	},
	{
		"id": "water",
		"name": "Wasser",
		"category": "Natur",
		"size": Vector3i(1, 1, 1),
		"shape": "water",
		"color": Color("32bade")
	},
	{
		"id": "waterfall",
		"name": "Wasserfall",
		"category": "Natur",
		"size": Vector3i(1, 3, 1),
		"shape": "waterfall",
		"color": Color("6addff")
	},
	{
		"id": "grass",
		"name": "Gras",
		"category": "Natur",
		"size": Vector3i(1, 1, 1),
		"shape": "grass",
		"color": Color("79b969")
	},
	{
		"id": "tree",
		"name": "Baum",
		"category": "Natur",
		"size": Vector3i(2, 4, 2),
		"shape": "tree",
		"color": Color("6bb46a")
	},
	{
		"id": "bush",
		"name": "Busch",
		"category": "Natur",
		"size": Vector3i(1, 1, 1),
		"shape": "bush",
		"color": Color("78b868")
	},
	{
		"id": "flowers",
		"name": "Blumen",
		"category": "Natur",
		"size": Vector3i(1, 1, 1),
		"shape": "flowers",
		"color": Color("e691cd")
	},
	{
		"id": "lantern",
		"name": "Laterne",
		"category": "Deko",
		"size": Vector3i(1, 2, 1),
		"shape": "lantern",
		"color": Color("ffd878"),
		"glow": true
	},
	{
		"id": "flag",
		"name": "Flagge",
		"category": "Deko",
		"size": Vector3i(1, 3, 1),
		"shape": "flag",
		"color": Color("7baaff")
	},
	{
		"id": "star",
		"name": "Stern",
		"category": "Deko",
		"size": Vector3i(1, 1, 1),
		"shape": "star",
		"color": Color("ffe296"),
		"glow": true
	},
	{
		"id": "crystal",
		"name": "Kristall",
		"category": "Deko",
		"size": Vector3i(1, 2, 1),
		"shape": "crystal",
		"color": Color("b99bff"),
		"glow": true
	},
	{
		"id": "bench",
		"name": "Bank",
		"category": "Deko",
		"size": Vector3i(2, 1, 1),
		"shape": "bench",
		"color": Color("bc9563")
	},
]


static func part(id: String) -> Dictionary:
	for item in PARTS:
		if item.id == id:
			return item
	return {}


static func size_of(id: String, turns: int) -> Vector3i:
	var item: Dictionary = part(id)
	if item.is_empty():
		return Vector3i.ZERO
	var size: Vector3i = item.size
	return Vector3i(size.z, size.y, size.x) if posmod(turns, 2) == 1 else size
