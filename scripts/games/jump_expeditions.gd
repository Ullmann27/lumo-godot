extends RefCounted
## Three playable courses share the original twelve-island collision design.
## Optional goals invite exploration; the main route remains completable without
## precision side challenges or a timer. Each course saves independently.
const COURSES: Array[Dictionary] = [
	{
		"name": "Wolkenpfad",
		"description": "Lerne die Inseln kennen und entdecke eine Sprungfeder.",
		"goals":
		[
			{"id": "crystals", "label": "Kristalle", "target": 6},
			{"id": "bounce", "label": "Sprungfeder", "target": 1}
		]
	},
	{
		"name": "Windbrücken",
		"description": "Kurvigere Wege und Sterne auf wandernden Inseln.",
		"goals":
		[
			{"id": "moving", "label": "Wanderstern", "target": 1},
			{"id": "crystals", "label": "Kristalle", "target": 8}
		]
	},
	{
		"name": "Sternenstieg",
		"description": "Mehr Höhenwechsel: Erkunde die geheime Seiteninsel.",
		"goals":
		[
			{"id": "side", "label": "Geheimsterne", "target": 2},
			{"id": "bonus", "label": "Bonussterne", "target": 5}
		]
	},
]


static func point(index: int, course: int) -> Vector3:
	var step: float = float(index)
	match course:
		1:
			return Vector3(-sin(step * 0.81) * 3.6, sin(step * 0.55) * 0.9, -step * 8.15)
		2:
			return Vector3(sin(step * 0.65) * 3.0, sin(step * 0.55) * 1.3, -step * 8.0)
	return Vector3(sin(step * 0.75) * 3.0, sin(step * 0.55) * 0.9, -step * 8.0)


static func stage_target(checkpoint: int) -> int:
	for island in [3, 6, 9, 11]:
		if checkpoint < island:
			return island
	return 11
