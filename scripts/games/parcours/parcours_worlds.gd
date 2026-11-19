extends RefCounted
## Verzeichnis der Abenteuer-Parcours-Welten. Nur Welten in PLAYABLE erscheinen im Menü:
## eine Welt kommt erst hinein, wenn ihr Bot-Test Start bis Ziel besteht.

const WOLKEN = preload("res://scripts/games/parcours/worlds/parcours_world_wolken.gd")

const ENTRIES: Array[Dictionary] = [
	{
		"id": "wolkenwerkstatt",
		"name": "Wolkenwerkstatt",
		"letter": "A",
		"tag": "BRÜCKEN · SCHWEBER · AUFZUG",
		"color": Color("8fd3ff"),
		"description": "Schmale Brücken, schwebende Plattformen und ein Aufzug über den Wolken."
	},
]


static func playable_ids() -> Array[String]:
	var ids: Array[String] = []
	for entry in ENTRIES:
		ids.append(str(entry.id))
	return ids


static func entry(world_id: String) -> Dictionary:
	for item in ENTRIES:
		if str(item.id) == world_id:
			return item
	return ENTRIES[0]


static func build(world_id: String):
	match world_id:
		"wolkenwerkstatt":
			return WOLKEN.build()
	return WOLKEN.build()
