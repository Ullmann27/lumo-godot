extends RefCounted
## Felder zusammenziehen: Ein Fingerzug von Bauplatz A nach Bauplatz B legt im
## Rechteck dazwischen auf jedem freien, bebaubaren und erschlossenen Platz
## einen Hof an – ein Zug statt hundertmal tippen. Bezahlt wird jeder Hof
## einzeln zum normalen Preis; fehlen Rohstoffe, endet die Reihe dort.
const REGION = preload("res://scripts/creative/build_settlement_region.gd")
## Höchstens so viele Plätze in einem Zug (25 × 25 Zellen).
const MAX_CELLS := 625


## Rechteck in Rasterzellen zwischen zwei Bauplätzen (beide eingeschlossen).
static func rect(from: int, to: int) -> Rect2i:
	var a := REGION.plot_coordinate(from)
	var b := REGION.plot_coordinate(to)
	var low := Vector2i(mini(a.x, b.x), mini(a.y, b.y))
	var high := Vector2i(maxi(a.x, b.x), maxi(a.y, b.y))
	return Rect2i(low, high - low + Vector2i.ONE)


## Freie, bebaubare, erschlossene Plätze im Rechteck, Reihe für Reihe vom
## Startpunkt aus (so wächst das Feld sichtbar vom Finger weg).
static func area(model, from: int, to: int) -> Array[int]:
	var result: Array[int] = []
	if from < 0 or to < 0:
		return result
	var town: Dictionary = model._player
	var occupied: Dictionary = {}
	for building: Dictionary in town.buildings:
		occupied[int(building.plot)] = true
	var box := rect(from, to)
	if box.size.x * box.size.y > MAX_CELLS:
		return result
	var start := REGION.plot_coordinate(from)
	var step_x := 1 if REGION.plot_coordinate(to).x >= start.x else -1
	var step_z := 1 if REGION.plot_coordinate(to).y >= start.y else -1
	var z := start.y
	for _row in range(box.size.y):
		var x := start.x
		for _column in range(box.size.x):
			var index := REGION.plot_index_at(Vector2i(x, z))
			if (
				index >= 0
				and index < int(town.plots)
				and not occupied.has(index)
				and model.plot_buildable(index)
			):
				result.append(index)
			x += step_x
		z += step_z
	return result


## Was ein Zug kosten würde (für die Vorschau): Plätze und Gesamtpreis.
static func quote(model, kind: String, plots: Array) -> Dictionary:
	var unit: Dictionary = model.building_cost(kind)
	var total := {}
	for resource in unit:
		total[resource] = int(unit[resource]) * plots.size()
	return {"count": plots.size(), "cost": total}
