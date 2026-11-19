extends RefCounted
## Buchungsbuch: jede Ereignis-Kennung (eid) der Autorität wird höchstens EINMAL gebucht –
## auch wenn das Ereignis nach einem Wiederverbinden erneut ankommt oder die App neu startet.
## Die eigentliche Belohnung bucht das vorhandene System (ProgressStore & Co.), nur wenn
## `book(eid)` true liefert. Gespeichert werden nur Kennungen, keine Kinderdaten.

const KEEP: int = 256

var path: String = ""
var booked: Array[String] = []


func _init(save_path: String = "") -> void:
	path = save_path
	if path.is_empty():
		return
	var config := ConfigFile.new()
	if config.load(path) == OK:
		var stored: Variant = config.get_value("net", "booked", [])
		if stored is Array:
			for eid in stored:
				booked.append(str(eid))


func has(eid: String) -> bool:
	return eid in booked


## true genau beim ersten Mal; leere Kennungen werden nie gebucht.
func book(eid: String) -> bool:
	if eid.is_empty() or eid in booked:
		return false
	booked.append(eid)
	while booked.size() > KEEP:
		booked.pop_front()
	if not path.is_empty():
		var config := ConfigFile.new()
		config.set_value("net", "booked", booked)
		config.save(path)
	return true
