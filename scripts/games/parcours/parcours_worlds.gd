extends RefCounted
## Verzeichnis der Abenteuer-Parcours-Welten. Nur Welten in PLAYABLE erscheinen im Menü:
## eine Welt kommt erst hinein, wenn ihr Bot-Test Start bis Ziel besteht.

const WOLKEN = preload("res://scripts/games/parcours/worlds/parcours_world_wolken.gd")
const EIS = preload("res://scripts/games/parcours/worlds/parcours_world_eis.gd")
const DSCHUNGEL = preload("res://scripts/games/parcours/worlds/parcours_world_dschungel.gd")

const ENTRIES: Array[Dictionary] = [
	{
		"id": "wolkenwerkstatt",
		"name": "Wolkenwerkstatt",
		"letter": "A",
		"tag": "BRÜCKEN · SCHWEBER · AUFZUG",
		"color": Color("8fd3ff"),
		"description": "Schmale Brücken, schwebende Plattformen und ein Aufzug über den Wolken."
	},
	{
		"id": "eisturm",
		"name": "Eis-Turm",
		"letter": "B",
		"tag": "SPIRALEN · EISBRÜCKEN · RÄTSEL",
		"color": Color("9fe6ff"),
		"description": "Spiralrampen, durchsichtige Eisbrücken und ein Kristallrätsel zu Fuß."
	},
	{
		"id": "dschungeltempel",
		"name": "Dschungel-Tempel",
		"letter": "C",
		"tag": "LIANENTORE · STEINWALZEN · SÄULENSPRUNG",
		"color": Color("9dcb6b"),
		"description":
		"Wurzelwege, die Lianenhalle, rollende Steinwalzen und eine alte Steinbrücke."
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
		"eisturm":
			return EIS.build()
		"dschungeltempel":
			return DSCHUNGEL.build()
	return WOLKEN.build()
