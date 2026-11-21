extends RefCounted
## Basis eines erweiterten Item-Verhaltens. Ein Verhalten verwaltet alle laufenden
## Einsätze seines Items (Daten im Streckenraum: Fortschritt + Querlage), baut die
## Darstellung aus gepoolten Knoten und meldet Treffer über den Wirt (kart_item_ext.gd),
## der Schild, Schonzeit, Statistik und Rückmeldung einheitlich verrechnet.
##
## Pflichten einer Unterklasse:
##  use(owner, item_id, row) -> bool        Einsatz starten (false = Item bleibt erhalten)
##  rival_wants(index, item_id, context) -> bool  KI-Entscheidung „jetzt sinnvoll?“
##  tick(delta)                              Simulation + Darstellung je Physiktakt
##  incoming(key) -> float                   Sekunden bis zum Einschlag auf `key` (INF = nichts)
##  save() -> Array / restore(data)          Laufende Einsätze für Speichern/Fortsetzen
##  clear()                                  Alles sofort entfernen

var host
var behaviour: String = ""
## Laufende Einsätze (Dictionaries mit reinen Daten + Knotenverweis "rig").
var active: Array[Dictionary] = []
## Wiederverwendbare Darstellungen (Pool); nie mehr als `pool_cap` gleichzeitig.
var pool: Array[Node3D] = []
var pool_cap: int = 3
## true: Anflug von hinten/oben -> rote Warnanzeige des Kindes; Gefahren, die vorn liegen
## (Falle, Zeitblüte), sieht das Kind selbst und bekommen nur eine Textwarnung.
var rear_warning: bool = true
var stats: Dictionary = {
	"used": 0, "hits": 0, "blocked": 0, "grace": 0, "fizzled": 0, "safety_skipped": 0
}


func setup(owner_host, behaviour_id: String) -> void:
	host = owner_host
	behaviour = behaviour_id


func use(_owner: int, _item_id: String, _row: Dictionary) -> bool:
	return false


func rival_wants(_index: int, _item_id: String, _context: Dictionary) -> bool:
	return false


func tick(_delta: float) -> void:
	pass


func incoming(_key: int) -> float:
	return INF


## Gespeichert werden nur Daten (keine Knoten).
func save() -> Array:
	var result: Array = []
	for entry in active:
		var copy: Dictionary = entry.duplicate()
		copy.erase("rig")
		result.append(copy)
	return result


func restore(data: Variant) -> void:
	clear()
	if not data is Array:
		return
	for entry in data:
		if entry is Dictionary and _valid_saved(entry):
			active.append(entry)


func _valid_saved(entry: Dictionary) -> bool:
	return entry.has("age") and entry.has("owner")


func clear() -> void:
	for entry in active:
		release(entry)
	active.clear()


## Darstellung aus dem Pool holen (oder neu bauen, solange der Pool nicht voll ist).
func acquire(entry: Dictionary) -> Node3D:
	if entry.has("rig") and is_instance_valid(entry.rig):
		return entry.rig
	for rig in pool:
		if not bool(rig.get_meta("busy", false)):
			rig.set_meta("busy", true)
			rig.visible = true
			reset_rig(rig, entry)
			entry.rig = rig
			return rig
	if pool.size() >= pool_cap:
		return null
	var built: Node3D = build_rig()
	built.set_meta("busy", true)
	host.add_child(built)
	pool.append(built)
	reset_rig(built, entry)
	entry.rig = built
	return built


func release(entry: Dictionary) -> void:
	if entry.has("rig") and is_instance_valid(entry.rig):
		var rig: Node3D = entry.rig
		rig.set_meta("busy", false)
		rig.visible = false
	entry.erase("rig")


func build_rig() -> Node3D:
	return Node3D.new()


func reset_rig(_rig: Node3D, _entry: Dictionary) -> void:
	pass
