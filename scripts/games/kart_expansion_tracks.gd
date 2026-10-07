extends RefCounted
## Original circuits following the ten supplied track boards. Existing four worlds stay intact.
const IDS: Array[String] = [
	"crystal_canyon",
	"jungle_temple",
	"candy_cloud",
	"volcano_night",
	"winter_sprint",
	"galaxy_ringway",
	"desert_drift",
	"learning_lab"
]
const CATALOG: Array[Dictionary] = [
	{
		"id": "crystal_canyon",
		"name": "Kristall-Canyon",
		"tag": "KRISTALLE · SCHLUCHTEN · SPRUNG",
		"color": Color("ae99ff"),
		"description": "Durch violette Schluchten, leuchtende Höhlen und über die Kristallrampe."
	},
	{
		"id": "jungle_temple",
		"name": "Dschungel-Tempel",
		"tag": "RUINEN · WASSER · BRÜCKEN",
		"color": Color("7ae4ac"),
		"description":
		"Palmen, uralte Tore und die große Tempelbrücke führen tief in den Dschungel."
	},
	{
		"id": "candy_cloud",
		"name": "Candy Cloud Circuit",
		"tag": "REGENBOGEN · DONUTS · WOLKEN",
		"color": Color("f5a9dc"),
		"description": "Durch Zuckerpaläste, bunte Donuts und Wolkenbögen auf der Regenbogenstraße."
	},
	{
		"id": "volcano_night",
		"name": "Volcano Night Run",
		"tag": "LAVA · NACHT · TURBORAMPE",
		"color": Color("ffac60"),
		"description":
		"Über dunkle Vulkanbrücken, durch Festungstore und an glühenden Lavafällen vorbei."
	},
	{
		"id": "winter_sprint",
		"name": "Winter-Sprint",
		"tag": "SCHNEE · EIS · STERNENSPRUNG",
		"color": Color("beeaff"),
		"description": "Schneebedeckte Tannen, gläserne Eiskristalle und die frostige Sternenrampe."
	},
	{
		"id": "galaxy_ringway",
		"name": "Galaxy Ringway",
		"tag": "PLANETEN · STERNE · WELTRAUM",
		"color": Color("b8a4ff"),
		"description": "Eine leuchtende Ringstraße zwischen Planeten und wandernden Sternen."
	},
	{
		"id": "desert_drift",
		"name": "Desert Dune Drift",
		"tag": "DÜNEN · OASE · HAARNADELN",
		"color": Color("ffe0a2"),
		"description": "Goldene Dünen, eine Palmenoase und weite Kurven zum Driften."
	},
	{
		"id": "learning_lab",
		"name": "Funkel-Labor",
		"tag": "ROBOTER · LICHT · ZUKUNFT",
		"color": Color("83f4e0"),
		"description":
		"Fahre durch das große Lumo-Labor: bunte Moleküle, Roboter und gläserne Tunnel."
	}
]


static func definition(id: String) -> Dictionary:
	var index := IDS.find(id)
	if index < 0:
		return {}
	var entry: Dictionary = CATALOG[index]
	var points := PackedVector3Array()
	# Distinct circuits include different hairpins, hills and technical return legs.
	var outlines := [
		[
			Vector2(0, 112),
			Vector2(64, 108),
			Vector2(115, 64),
			Vector2(84, 9),
			Vector2(136, -43),
			Vector2(90, -112),
			Vector2(34, -137),
			Vector2(5, -90),
			Vector2(-48, -126),
			Vector2(-130, -70),
			Vector2(-84, -13),
			Vector2(-135, 33),
			Vector2(-88, 103),
			Vector2(-36, 125)
		],
		[
			Vector2(0, 108),
			Vector2(74, 94),
			Vector2(124, 42),
			Vector2(79, 7),
			Vector2(113, -64),
			Vector2(72, -123),
			Vector2(12, -108),
			Vector2(-19, -60),
			Vector2(-75, -106),
			Vector2(-123, -47),
			Vector2(-108, 25),
			Vector2(-46, 19),
			Vector2(-75, 82),
			Vector2(-30, 116)
		],
		[
			Vector2(0, 118),
			Vector2(74, 102),
			Vector2(133, 60),
			Vector2(127, 8),
			Vector2(76, -10),
			Vector2(137, -69),
			Vector2(86, -130),
			Vector2(23, -115),
			Vector2(-23, -72),
			Vector2(-77, -123),
			Vector2(-140, -75),
			Vector2(-100, -17),
			Vector2(-146, 28),
			Vector2(-102, 90),
			Vector2(-40, 128)
		],
		[
			Vector2(0, 112),
			Vector2(82, 96),
			Vector2(132, 40),
			Vector2(86, -3),
			Vector2(126, -66),
			Vector2(68, -129),
			Vector2(17, -106),
			Vector2(-11, -51),
			Vector2(-63, -108),
			Vector2(-137, -67),
			Vector2(-118, 3),
			Vector2(-70, 26),
			Vector2(-104, 82),
			Vector2(-39, 126)
		],
		[
			Vector2(0, 117),
			Vector2(58, 110),
			Vector2(120, 79),
			Vector2(133, 12),
			Vector2(93, -45),
			Vector2(124, -110),
			Vector2(54, -133),
			Vector2(-7, -94),
			Vector2(-59, -125),
			Vector2(-135, -66),
			Vector2(-114, -3),
			Vector2(-145, 48),
			Vector2(-81, 107),
			Vector2(-30, 128)
		],
		[
			Vector2(0, 128),
			Vector2(76, 100),
			Vector2(130, 47),
			Vector2(116, -25),
			Vector2(61, -21),
			Vector2(108, -101),
			Vector2(30, -135),
			Vector2(-27, -96),
			Vector2(-62, -124),
			Vector2(-126, -68),
			Vector2(-86, -14),
			Vector2(-137, 49),
			Vector2(-60, 120)
		],
		[
			Vector2(0, 116),
			Vector2(83, 101),
			Vector2(139, 37),
			Vector2(95, -12),
			Vector2(132, -74),
			Vector2(69, -129),
			Vector2(16, -89),
			Vector2(-38, -135),
			Vector2(-119, -93),
			Vector2(-140, -27),
			Vector2(-89, 19),
			Vector2(-123, 75),
			Vector2(-46, 125)
		],
		[
			Vector2(0, 114),
			Vector2(72, 114),
			Vector2(134, 72),
			Vector2(123, 7),
			Vector2(70, -13),
			Vector2(123, -84),
			Vector2(50, -131),
			Vector2(-6, -89),
			Vector2(-75, -121),
			Vector2(-139, -54),
			Vector2(-97, 2),
			Vector2(-128, 70),
			Vector2(-61, 114)
		]
	]
	for i in range(outlines[index].size()):
		var p: Vector2 = outlines[index][i]
		var height: float = (
			8.0 + sin(float(i) * 0.85 + index) * 4.0 + (8.0 if i in [3, 4, 5] else 0.0)
		)
		points.append(Vector3(p.x, height, p.y))
	var sky: Color = [
		Color("102145"),
		Color("193f54"),
		Color("5067c0"),
		Color("080f2b"),
		Color("304779"),
		Color("050a26"),
		Color("9b624e"),
		Color("081e3c")
	][index]
	var ground: Color = [
		Color("343660"),
		Color("315d48"),
		Color("c986cd"),
		Color("292735"),
		Color("c6dce7"),
		Color("14113b"),
		Color("d9ab6e"),
		Color("173749")
	][index]
	return {
		"id": id,
		"name": entry.name,
		"subtitle": entry.tag,
		"accent": entry.color,
		"asphalt": Color("283b59") if id != "volcano_night" else Color("1e2536"),
		"sky": sky,
		"horizon": sky.lightened(0.24),
		"fog": sky.lightened(0.18),
		"sun": Color("ecdcff") if index != 3 else Color("c9d2ff"),
		"ground": ground,
		"seed": 81623 + index * 997,
		"points": points
	}
