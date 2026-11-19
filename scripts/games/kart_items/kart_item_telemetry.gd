extends RefCounted
## Item-Protokoll eines Rennens: Ziehungen aus Prismen, Raketensalven und Treffer.
## Keine Spielwirkung – Tests und die Balance-Messung (kart_item_balance_measure.gd)
## lesen es aus. Begrenzt, damit ein langes Training den Speicher nicht füllt.

const LIMIT: int = 800

## {who (-1 = Kind, 0.. = Rivale), place, item, lap, t}
var draws: Array[Dictionary] = []
## Prisma berührt, aber Inventar voll oder Ziehung läuft: {who, lap, t}
var full_touches: Array[Dictionary] = []
## {who, target, t}
var salvos: Array[Dictionary] = []
## {type ("hit"/"blocked"/"grace"/"intercepted"/"expired"), target, source, item, t}
var events: Array[Dictionary] = []


func clear() -> void:
	draws.clear()
	full_touches.clear()
	salvos.clear()
	events.clear()


func note_draw(who: int, place: int, item: String, lap: int, t: float) -> void:
	_push(draws, {"who": who, "place": place, "item": item, "lap": lap, "t": t})


func note_full(who: int, lap: int, t: float) -> void:
	_push(full_touches, {"who": who, "lap": lap, "t": t})


func note_salvo(who: int, target: int, t: float) -> void:
	_push(salvos, {"who": who, "target": target, "t": t})


func note_event(type: String, event: Dictionary, t: float) -> void:
	_push(
		events,
		{
			"type": type,
			"target": int(event.get("target", -99)),
			"source": int(event.get("source", -99)),
			"item": str(event.get("item", "")),
			"t": t,
		}
	)


func _push(list: Array[Dictionary], row: Dictionary) -> void:
	list.append(row)
	if list.size() > LIMIT:
		list.pop_front()
