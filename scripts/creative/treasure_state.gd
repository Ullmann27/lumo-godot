extends RefCounted
## Clues are gated by actual exploration and inventory, with durable chapter progress.
const CLUES = [
	{
		"id": "tree",
		"name": "Der alte Sternenbaum",
		"at": Vector3(-12, 0, -8),
		"lead": "Suche den großen Baum links vom Lager.",
		"question": "Was hilft einem Baum beim Wachsen?",
		"answers": ["Ein Tropfen Wasser", "Ein Stein im Ast", "Ein leerer Becher"],
		"correct": 0,
		"item": "Blattschlüssel"
	},
	{
		"id": "waterfall",
		"name": "Das flüsternde Wasser",
		"at": Vector3(13, 0, -19),
		"lead": "Folge dem Wasser zum leuchtenden Wasserfall.",
		"question": "Sonne, Mond, Sonne, Mond … Was kommt als Nächstes?",
		"answers": ["Eine Wolke", "Die Sonne", "Der Mond"],
		"correct": 1,
		"item": "Sonnenkompass"
	},
	{
		"id": "bridge",
		"name": "Die Blätterbrücke",
		"at": Vector3(0, 0, -28),
		"lead": "Mit dem Blattschlüssel öffnest du das Tor an der Brücke.",
		"question": "Welcher Gegenstand öffnet dieses Tor?",
		"answers": ["Sonnenkompass", "Blattschlüssel", "Ein Kieselstein"],
		"correct": 1,
		"item": "Brückenwappen"
	},
	{
		"id": "crystals",
		"name": "Die vier Wächter",
		"at": Vector3(-15, 0, -39),
		"lead": "Hinter dem Tor stehen vier leuchtende Kristalle.",
		"question": "Wie viele Kristalle bewachen diesen Platz?",
		"answers": ["Drei", "Vier", "Fünf"],
		"correct": 1,
		"item": "Kristallstern"
	},
	{
		"id": "garden",
		"name": "Der Mondgarten",
		"at": Vector3(16, 0, -48),
		"lead": "Suche den Garten mit den goldenen Blumen.",
		"question": "Welches Blatt passt nicht zu den anderen: rund, rund, spitz?",
		"answers": ["Das erste runde", "Das zweite runde", "Das spitze"],
		"correct": 2,
		"item": "Mondblüte"
	},
	{
		"id": "castle",
		"name": "Das Sternenschloss",
		"at": Vector3(0, 0, -57),
		"lead": "Bringe Kristallstern und Mondblüte zum Schloss.",
		"question": "Zwei Freunde teilen vier Sterne. Wie viele bekommt jeder?",
		"answers": ["Zwei", "Drei", "Vier"],
		"correct": 0,
		"item": "Schatzschlüssel"
	},
	{
		"id": "chest",
		"name": "Lumos Sternenschatz",
		"at": Vector3(0, 0, -65),
		"lead": "Der Schatzschlüssel öffnet die Truhe im Schlosshof.",
		"question": "Welcher Schlüssel öffnet den Sternenschatz?",
		"answers": ["Blattschlüssel", "Schatzschlüssel", "Ein gewöhnlicher Stein"],
		"correct": 1,
		"item": "Sternenschatz"
	}
]
var chapter: int = 0
var inventory: Array[String] = []
var found: Array[String] = []
var completed: bool = false
var position := Vector3(0, 0.05, 6)
var result_id: String = ""
var wrong_attempts: int = 0
var discoveries: Array[String] = []
var streak: int = 0
var best_streak: int = 0
var last_cheer: int = 0
const DISCOVERIES = [
	{"id": "arch", "name": "Willkommensbogen", "at": Vector3(0, 0, 1.35)},
	{"id": "compass", "name": "Kompass-Sockel", "at": Vector3(2.45, 0, 4.55)},
	{"id": "falls", "name": "Start-Wasserfall", "at": Vector3(-12.5, 0, 2.2)}
]
const STREAK_MILESTONES: Array[int] = [3, 7]
const CLUE_REQUIREMENTS := {
	"tree": [],
	"waterfall": ["tree"],
	"bridge": ["tree", "waterfall"],
	"crystals": ["bridge"],
	"garden": ["bridge"],
	"castle": ["crystals", "garden"],
	"chest": ["castle"]
}


func current() -> Dictionary:
	var available := available_clues()
	return available[0] if not available.is_empty() else CLUES[-1]


func available_clues() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for clue in CLUES:
		if str(clue.id) not in found and _requirements_met(str(clue.id), found):
			result.append(clue)
	return result


static func _requirements_met(id: String, solved: Array[String]) -> bool:
	if not CLUE_REQUIREMENTS.has(id):
		return false
	for required in CLUE_REQUIREMENTS[id]:
		if str(required) not in solved:
			return false
	return true


func clue_at(at: Vector3) -> Dictionary:
	var nearest: Dictionary = {}
	var distance := 3.8
	for clue in available_clues():
		var separation := Vector2(at.x, at.z).distance_to(Vector2(clue.at.x, clue.at.z))
		if separation <= distance:
			nearest = clue
			distance = separation
	return nearest


func can_interact(at: Vector3) -> bool:
	return not completed and not clue_at(at).is_empty()


func answer(choice: int, at: Vector3) -> bool:
	var clue := clue_at(at)
	if completed or clue.is_empty():
		return false
	if choice != int(clue.correct):
		wrong_attempts += 1
		streak = 0
		last_cheer = 0
		return false
	found.append(str(clue.id))
	inventory.append(str(clue.item))
	# Preserve the old chapter meaning for existing saves: it is the completed
	# linear prefix, never an unsolved location skipped by taking the other path.
	chapter = _prefix_length(found)
	completed = found.size() == CLUES.size()
	streak += 1
	best_streak = maxi(best_streak, streak)
	last_cheer = streak if streak in STREAK_MILESTONES else 0
	return true


static func _prefix_length(solved: Array[String]) -> int:
	var prefix := 0
	for clue in CLUES:
		if str(clue.id) not in solved:
			break
		prefix += 1
	return prefix


func to_data() -> Dictionary:
	return {
		"version": 1,
		"chapter": chapter,
		"solved_clues": found.duplicate(),
		"position": [position.x, position.y, position.z],
		"result_id": result_id,
		"wrong_attempts": wrong_attempts,
		"discoveries": discoveries.duplicate(),
		"streak": streak,
		"best_streak": best_streak
	}


func restore(data: Dictionary) -> bool:
	if int(data.get("version", 0)) != 1:
		return false
	var next: int = int(data.get("chapter", -1))
	var point = data.get("position", [])
	if next < 0 or next > CLUES.size() or not point is Array or point.size() != 3:
		return false
	var pos := Vector3(float(point[0]), float(point[1]), float(point[2]))
	if not pos.is_finite() or absf(pos.x) > 36 or pos.z < -72 or pos.z > 14:
		return false
	var next_found: Array[String] = []
	if data.has("solved_clues"):
		if not data.solved_clues is Array or data.solved_clues.size() > CLUES.size():
			return false
		for id in data.solved_clues:
			if not id is String or id in next_found or not _requirements_met(id, next_found):
				return false
			next_found.append(id)
		if _prefix_length(next_found) != next:
			return false
	else:
		# Version-1 family saves only stored the completed linear prefix.
		for i in range(next):
			next_found.append(str(CLUES[i].id))
	chapter = next
	inventory.clear()
	found = next_found
	for id in found:
		for clue in CLUES:
			if str(clue.id) == id:
				inventory.append(str(clue.item))
	completed = found.size() == CLUES.size()
	position = pos
	result_id = str(data.get("result_id", ""))
	wrong_attempts = maxi(0, int(data.get("wrong_attempts", 0)))
	discoveries.clear()
	var saved_finds = data.get("discoveries", [])
	if saved_finds is Array:
		for item in saved_finds:
			var sid := str(item)
			if _known_discovery(sid) and sid not in discoveries:
				discoveries.append(sid)
	streak = maxi(0, int(data.get("streak", 0)))
	best_streak = maxi(streak, int(data.get("best_streak", 0)))
	last_cheer = 0
	return true


func _known_discovery(sid: String) -> bool:
	for spot in DISCOVERIES:
		if str(spot.id) == sid:
			return true
	return false


func try_discover(at: Vector3) -> String:
	for spot in DISCOVERIES:
		var sid := str(spot.id)
		if sid in discoveries:
			continue
		if Vector2(at.x, at.z).distance_to(Vector2(spot.at.x, spot.at.z)) <= 2.6:
			discoveries.append(sid)
			return str(spot.name)
	return ""


func streak_xp() -> int:
	if best_streak >= 7:
		return 8
	if best_streak >= 3:
		return 3
	return 0


func discovery_xp() -> int:
	return discoveries.size() * 2


func reward_xp() -> int:
	return 40 + streak_xp() + discovery_xp()
