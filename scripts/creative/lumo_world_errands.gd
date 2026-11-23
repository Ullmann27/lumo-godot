extends RefCounted
## Optional errands after World's first chapter. A delivery is an actual visit,
## never a multiple-choice shortcut. Stamps belong only to the World save;
## this model neither issues stars nor consumes school receipts.

const VERSION := 1
const REACH := 4.5
const FRIENDS := {
	"nelli": {"name": "Nelli", "at": Vector3(90, 0, 20), "place": "vor ihrem Haus im Sonnendorf"},
	"bruno": {"name": "Bruno", "at": Vector3(135, 0, -58), "place": "bei den Gartenbeeten"},
	"tilda": {"name": "Tilda", "at": Vector3(218, 0, -34), "place": "bei der Post in Sternenstadt"}
}
const ERRANDS: Array[Dictionary] = [
	{
		"id": "seeds_for_bruno", "sender": "nelli", "recipient": "bruno",
		"title": "Die geheimnisvolle Gartenpost", "parcel": "Samenpäckchen", "stamp": "Gartenfreund",
		"introduction": "Nelli hat Samen für euren Gemeinschaftsgarten. Auf dem Päckchen steht ein Hinweis statt einer Adresse.",
		"clues": [
			"Bringe die Samen zu Bruno. Er wartet bei den Gartenbeeten.",
			"Gesucht ist der Freund bei den Beeten. Er pflanzt Blumen und ist kein Hase.",
			"Das Päckchen gehört nicht Nelli und nicht Tilda. Der Empfänger pflegt den Gemeinschaftsgarten.",
			"Nelli kümmert sich um ihr Haus, Tilda um die Post, Bruno um den Garten. Die Samen braucht der Freund, der Pflanzen großzieht."
		],
		"thanks": "Bruno freut sich: Jetzt können wir die Samen gemeinsam einpflanzen! Du erhältst den Freundschaftsstempel Gartenfreund."
	},
	{
		"id": "invitation_for_tilda", "sender": "bruno", "recipient": "tilda",
		"title": "Eine Einladung auf Reisen", "parcel": "Gartenfest-Einladung", "stamp": "Brückenbauer",
		"introduction": "Bruno lädt eine Freundin zum Gartenfest ein. Hilf der Einladung, ihren Weg zu finden.",
		"clues": [
			"Tilda ist die Ente in Sternenstadt. Bringe ihr die Einladung.",
			"Die Einladung geht zur Ente. Sie wartet bei der Post in Sternenstadt.",
			"Nelli ist zu Hause, Bruno bleibt bei den Beeten. Eingeladen ist die Freundin bei der Post in Sternenstadt.",
			"Die Empfängerin verteilt Briefe. Sie arbeitet weder im Garten noch bei Nellis Haus. Suche dort, wo die Post für Sternenstadt ankommt."
		],
		"thanks": "Tilda freut sich auf das Gartenfest. Du hast Dorf und Stadt verbunden und erhältst den Freundschaftsstempel Brückenbauer."
	},
	{
		"id": "picnic_for_nelli", "sender": "tilda", "recipient": "nelli",
		"title": "Ein Korb voller Dank", "parcel": "Picknickkorb", "stamp": "Guter Nachbar",
		"introduction": "Tilda hat einen Picknickkorb gepackt. Eine Freundin im Sonnendorf wartet schon darauf.",
		"clues": [
			"Bringe den Korb zu Nelli. Die Häsin wartet vor ihrem Haus.",
			"Der Korb ist für die Häsin im Sonnendorf. Sie wartet vor ihrem Haus, nicht im Garten.",
			"Bruno hat bereits seine Samen, Tilda bleibt bei der Post. Wer hat das Samenpäckchen losgeschickt? Diese Freundin bekommt den Korb.",
			"Den Korb erhält die Freundin, bei der deine erste Lieferung begonnen hat. Sie ist weder der Gärtner noch die Postbotin. Erinnere dich an den Anfang deiner Runde."
		],
		"thanks": "Nelli teilt den Picknickkorb mit ihren Freunden. Alle drei Lieferungen sind angekommen. Dein dritter Freundschaftsstempel heißt Guter Nachbar."
	}
]

var completed: Array[String] = []
var active_id := ""
var destination_shown := false


func current(grade := 1) -> Dictionary:
	if completed.size() >= ERRANDS.size():
		return {}
	var delivery: Dictionary = ERRANDS[completed.size()].duplicate(true)
	var destination := str(delivery.recipient if carrying() else delivery.sender)
	delivery.at = FRIENDS[destination].at
	delivery.kind = "friend_post"
	delivery.lead = str(delivery.clues[clampi(grade, 1, 4) - 1]) if carrying() else str(delivery.introduction)
	return delivery


func is_complete() -> bool:
	return completed.size() == ERRANDS.size()


func carrying() -> bool:
	return not active_id.is_empty()


static func friend_at(at: Vector3) -> String:
	if not is_finite(at.x) or not is_finite(at.y) or not is_finite(at.z):
		return ""
	for id in FRIENDS:
		if at.distance_squared_to(FRIENDS[id].at) <= REACH * REACH:
			return str(id)
	return ""


func clue(grade: int) -> String:
	var delivery := current()
	return str(delivery.clues[clampi(grade, 1, 4) - 1]) if not delivery.is_empty() else "Alle drei Lieferungen sind angekommen."


func pickup(at: Vector3, chapter_complete: bool) -> bool:
	var delivery := current()
	if not chapter_complete or carrying() or delivery.is_empty():
		return false
	if friend_at(at) != str(delivery.sender):
		return false
	active_id = str(delivery.id)
	destination_shown = false
	return true


func deliver(at: Vector3, chapter_complete: bool) -> bool:
	var delivery := current()
	if not chapter_complete or delivery.is_empty() or active_id != str(delivery.id):
		return false
	if friend_at(at) != str(delivery.recipient):
		return false
	completed.append(active_id)
	active_id = ""
	destination_shown = false
	return true


func show_destination(chapter_complete: bool) -> bool:
	if not chapter_complete or not carrying():
		return false
	destination_shown = true
	return true


## Show the sender before collection. While carrying, the child reads the clue;
## the exact destination is marked only after explicitly asking for help.
func guidance(chapter_complete: bool) -> Dictionary:
	var delivery := current()
	if not chapter_complete or delivery.is_empty() or (carrying() and not destination_shown):
		return {}
	var id := str(delivery.recipient if carrying() else delivery.sender)
	return {"id": str(delivery.id), "at": FRIENDS[id].at, "title": str(FRIENDS[id].name)}


func summary(grade: int, chapter_complete: bool) -> String:
	if not chapter_complete:
		return ""
	var heading := "FREUNDEPOST · %d / %d Stempel" % [completed.size(), ERRANDS.size()]
	if is_complete():
		return heading + "\nDrei Lieferungen, drei Freunde. Danke, Lumo!"
	var delivery := current()
	if carrying():
		return heading + "\n" + str(delivery.parcel) + "\n" + clue(grade)
	var sender: Dictionary = FRIENDS[str(delivery.sender)]
	return heading + "\n" + str(delivery.title) + "\nBesuche " + str(sender.name) + " " + str(sender.place) + "."


func stamps() -> Array[String]:
	var result: Array[String] = []
	for index in range(completed.size()):
		result.append(str(ERRANDS[index].stamp))
	return result


func to_data() -> Dictionary:
	return {"version": VERSION, "completed": completed.duplicate(), "active": active_id, "destinationShown": destination_shown}


## Validate before changing any field. A missing section is an older World save.
## Prefix order and the one active ID prevent skipped or duplicated stamps.
func restore(raw: Variant) -> bool:
	if not raw is Dictionary:
		return false
	if raw.is_empty():
		completed.clear()
		active_id = ""
		destination_shown = false
		return true
	if typeof(raw.get("version")) not in [TYPE_INT, TYPE_FLOAT] or raw.get("version") != VERSION:
		return false
	if not raw.get("completed") is Array:
		return false
	var saved: Array = raw.completed
	if saved.size() > ERRANDS.size():
		return false
	var checked: Array[String] = []
	for index in range(saved.size()):
		if not saved[index] is String or saved[index] != ERRANDS[index].id:
			return false
		checked.append(saved[index])
	if not raw.get("active", "") is String or typeof(raw.get("destinationShown", false)) != TYPE_BOOL:
		return false
	var candidate := str(raw.get("active", ""))
	if not candidate.is_empty() and (checked.size() == ERRANDS.size() or candidate != ERRANDS[checked.size()].id):
		return false
	if bool(raw.get("destinationShown", false)) and candidate.is_empty():
		return false
	completed = checked
	active_id = candidate
	destination_shown = bool(raw.get("destinationShown", false))
	return true
