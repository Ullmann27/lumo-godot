extends RefCounted
## Deterministic first chapter. The familiar treasure island remains its own
## saved adventure; World has a separate, profile-scoped save and lesson receipt.

const VERSION := 1
const SPAWN := Vector3(0.0, 0.1, 6.0)
## Original Sonnendorf parking place. Version-one saves written before kart
## persistence keep resolving their kart here.
const KART_SPAWN := Vector3(77.0, 0.2, 18.0)
## First entry: the kart waits on the island path a few steps ahead of SPAWN,
## inside the default follow-camera view, and points towards the bridge.
const KART_START := Vector3(1.8, 0.2, 2.2)
const KART_START_YAW := -1.692
const BOUNDS := Rect2(-36.0, -238.0, 992.0, 476.0)
const MISSIONS: Array[Dictionary] = [
	{"id": "meet_nelli", "title": "Ein neues Zuhause", "lead": "Über die Brücke zum Sonnendorf: Nelli wartet vor ihrem Haus.", "at": Vector3(90, 0, 20), "kind": "talk"},
	{"id": "safe_crossing", "title": "Gemeinsam zur Schule", "lead": "Gehe zu Fuß zur Ampel. Warte auf Grün und achte auf den Verkehr.", "at": Vector3(110, 0, 7), "kind": "crossing"},
	{"id": "school_numbers", "title": "Der Plan für den Garten", "lead": "In der Schule wartet eine Mathe-Lernrunde. Damit plant ihr den Gemeinschaftsgarten.", "at": Vector3(110, 0, -24), "kind": "lesson"},
	{"id": "garden_delivery", "title": "Der Garten erwacht", "lead": "Bruno braucht deine Hilfe: Wie viele Pflanzen kommen ins Beet?", "at": Vector3(135, 0, -58), "kind": "math"},
	{"id": "city_parcels", "title": "Post für Sternenstadt", "lead": "Fahre oder gehe nach Sternenstadt. Tilda braucht Hilfe mit ihrem Lieferzettel.", "at": Vector3(218, 0, -34), "kind": "reading"},
	{"id": "friendship_picnic", "title": "Ein Platz für alle", "lead": "Trefft euch im Park und plant euer gemeinsames Picknick.", "at": Vector3(239, 0, -63), "kind": "social"}
]

var completed: Array[String] = []
var position: Vector3 = SPAWN
var kart_position: Vector3 = KART_START
var kart_yaw := KART_START_YAW
var pending_lesson: Dictionary = {}
var result_id := ""
var crossing_started := false


func current() -> Dictionary:
	return MISSIONS[completed.size()].duplicate(true) if completed.size() < MISSIONS.size() else {}


func is_complete() -> bool:
	return completed.size() == MISSIONS.size()


func near_current(at: Vector3) -> bool:
	var mission := current()
	return not mission.is_empty() and Vector2(at.x, at.z).distance_to(Vector2(mission.at.x, mission.at.z)) <= 4.5


func meet_friend(at: Vector3) -> bool:
	return _finish("meet_nelli") if near_current(at) else false


func observe_crossing(at: Vector3, green: bool, walking: bool) -> bool:
	if str(current().get("id", "")) != "safe_crossing" or not walking:
		crossing_started = false
		return false
	if absf(at.x - 110.0) > 2.3:
		crossing_started = false
		return false
	if at.z >= 4.4 and at.z < 8.0 and green:
		crossing_started = true
	# A pedestrian who started on green may finish crossing after the phase ends.
	if crossing_started and at.z <= -5.5:
		crossing_started = false
		return _finish("safe_crossing")
	return false


func begin_school_request(request_id: String, grade: int, at: Vector3) -> Dictionary:
	if str(current().get("id", "")) != "school_numbers" or not near_current(at):
		return {}
	var active_grade := clampi(grade, 1, 4)
	if not pending_lesson.is_empty() and int(pending_lesson.get("grade", 0)) == active_grade:
		return pending_lesson.duplicate(true)
	var allowed := RegEx.new()
	allowed.compile("^[A-Za-z0-9_.:-]{8,160}$")
	if allowed.search(request_id) == null:
		return {}
	if request_id == str(pending_lesson.get("requestId", "")):
		return {}
	pending_lesson = {
		"version": 1, "id": "school_numbers", "requestId": request_id,
		"subject": "Mathematik", "grade": active_grade, "returnGame": "world"
	}
	return pending_lesson.duplicate(true)


func consume_learning_receipt(receipt: Dictionary) -> bool:
	if pending_lesson.is_empty() or str(current().get("id", "")) != "school_numbers":
		return false
	if typeof(receipt.get("completed")) != TYPE_BOOL or receipt.get("completed") != true:
		return false
	if str(receipt.get("missionId", "")) != "school_numbers":
		return false
	if str(receipt.get("requestId", "")) != str(pending_lesson.get("requestId", "")):
		return false
	if receipt.get("version") != 1 or receipt.get("subject") != "Mathematik" or receipt.get("returnGame") != "world":
		return false
	if receipt.get("grade") != pending_lesson.get("grade"):
		return false
	pending_lesson.clear()
	return _finish("school_numbers")


func task(grade: int) -> Dictionary:
	var index := clampi(grade, 1, 4) - 1
	match str(current().get("id", "")):
		"garden_delivery":
			return [
				{"question": "Im Beet stehen 4 Blumen. Bruno pflanzt noch 3. Wie viele sind es dann?", "choices": ["6", "7", "8"], "correct": 1, "explanation": "Vier Blumen und drei Blumen zusammen sind sieben Blumen."},
				{"question": "Bruno pflanzt 3 Reihen mit jeweils 4 Blumen. Wie viele Blumen braucht er?", "choices": ["7", "14", "12"], "correct": 2, "explanation": "4 + 4 + 4 = 12. Drei gleich große Reihen kannst du auch mit 3 × 4 rechnen."},
				{"question": "24 Setzlinge werden gleichmäßig auf 4 Beete verteilt. Wie viele kommen in jedes Beet?", "choices": ["6", "8", "4"], "correct": 0, "explanation": "24 : 4 = 6. Mit 4 × 6 = 24 kannst du das Ergebnis prüfen."},
				{"question": "Für 6 Beete werden jeweils 12 Pflanzen gebraucht. 28 sind schon da. Wie viele fehlen?", "choices": ["54", "44", "40"], "correct": 1, "explanation": "Zuerst 6 × 12 = 72. Dann 72 − 28 = 44 fehlende Pflanzen."}
			][index].duplicate(true)
		"city_parcels":
			return [
				{"question": "Tildas Zettel sagt: Die POST geht zum HAUS. Wohin bringst du sie?", "choices": ["Zum Haus", "Zum Baum", "Zum See"], "correct": 0, "explanation": "Auf dem Zettel steht HAUS. Gut, dass du den Zielort gelesen hast."},
				{"question": "Auf dem Paket steht: Für Nelli. Bitte bei ihrer Haustür abgeben. Wo ist der richtige Platz?", "choices": ["Bei Bruno im Garten", "Bei Nellis Haustür", "Am Spielplatz"], "correct": 1, "explanation": "Der Name und der Ort gehören zusammen: Nelli – ihre Haustür."},
				{"question": "Lies genau: Zuerst die Bücher zur Schule, danach das Brot zu Nelli. Was lieferst du zuerst?", "choices": ["Das Brot zu Nelli", "Beides zum Markt", "Die Bücher zur Schule"], "correct": 2, "explanation": "Das Wort zuerst legt die Reihenfolge fest: Bücher zur Schule, danach das Brot."},
				{"question": "Tilda schreibt: Das Paket ist für Bruno, der heute statt im Garten in der Werkstatt arbeitet. Wo suchst du ihn?", "choices": ["In der Werkstatt", "Im Garten", "In der Schule"], "correct": 0, "explanation": "Die zusätzliche Information ändert den Zielort: Heute arbeitet Bruno in der Werkstatt."}
			][index].duplicate(true)
		"friendship_picnic":
			return {"question": "Nelli ist still und sitzt allein. Was könnte ihr beim Picknick helfen?", "choices": ["Freundlich fragen, ob sie mitmachen möchte", "Für Nelli entscheiden, was sie fühlen muss", "So tun, als wäre sie nicht da"], "correct": 0, "explanation": "Fragen lässt Nelli selbst entscheiden. Zuhören hilft dir, ihre Wünsche zu verstehen."}
	return {}


func answer(choice: int, grade: int, at: Vector3) -> bool:
	var question := task(grade)
	if question.is_empty() or not near_current(at) or choice != int(question.correct):
		return false
	return _finish(str(current().id))


func _finish(id: String) -> bool:
	if str(current().get("id", "")) != id or id in completed:
		return false
	completed.append(id)
	return true


func remember_kart(at: Vector3, yaw: float, on_floor: bool) -> bool:
	# The caller supplies actual post-move_and_slide contact, not a height guess.
	if not on_floor or not at.is_finite() or not is_finite(yaw) or not BOUNDS.has_point(Vector2(at.x, at.z)) or at.y < -0.5 or at.y > 180.0:
		return false
	kart_position = at
	kart_yaw = wrapf(yaw, -PI, PI)
	return true


func to_data() -> Dictionary:
	return {"version": VERSION, "completed": completed.duplicate(), "position": [position.x, position.y, position.z], "pendingLesson": pending_lesson.duplicate(true), "resultId": result_id,
		"kart": {"position": [kart_position.x, kart_position.y, kart_position.z], "yaw": kart_yaw}}


func restore(data: Dictionary) -> bool:
	if data.get("version") != VERSION or not data.get("completed") is Array:
		return false
	var saved: Array = data.completed
	if saved.size() > MISSIONS.size():
		return false
	var checked: Array[String] = []
	for index in range(saved.size()):
		if not saved[index] is String or saved[index] != MISSIONS[index].id:
			return false
		checked.append(saved[index])
	var xyz = data.get("position")
	if not xyz is Array or xyz.size() != 3:
		return false
	for value in xyz:
		if (not value is float and not value is int) or not is_finite(float(value)):
			return false
	var at := Vector3(float(xyz[0]), float(xyz[1]), float(xyz[2]))
	if not BOUNDS.has_point(Vector2(at.x, at.z)) or at.y < -1.0 or at.y > 180.0:
		return false
	# Version-one saves written before kart persistence remain readable.
	var saved_kart_position := KART_SPAWN
	var saved_kart_yaw := 0.0
	if data.has("kart"):
		var kart = data.kart
		if not kart is Dictionary:
			return false
		var kart_xyz = kart.get("position")
		if not kart_xyz is Array or kart_xyz.size() != 3:
			return false
		for value in kart_xyz:
			if (not value is float and not value is int) or not is_finite(float(value)):
				return false
		saved_kart_position = Vector3(float(kart_xyz[0]), float(kart_xyz[1]), float(kart_xyz[2]))
		var yaw = kart.get("yaw")
		if (not yaw is float and not yaw is int) or not is_finite(float(yaw)):
			return false
		if not BOUNDS.has_point(Vector2(saved_kart_position.x, saved_kart_position.z)) or saved_kart_position.y < -0.5 or saved_kart_position.y > 180.0:
			return false
		saved_kart_yaw = wrapf(float(yaw), -PI, PI)
	var pending = data.get("pendingLesson", {})
	if not pending is Dictionary:
		return false
	if not pending.is_empty():
		if checked.size() != 2 or pending.get("version") != 1 or pending.get("id") != "school_numbers":
			return false
		var request_pattern := RegEx.new()
		request_pattern.compile("^[A-Za-z0-9_.:-]{8,160}$")
		if not pending.get("requestId") is String or request_pattern.search(str(pending.requestId)) == null:
			return false
		if pending.get("subject") != "Mathematik" or pending.get("returnGame") != "world":
			return false
		if not pending.get("grade") is int and not pending.get("grade") is float:
			return false
		if float(pending.grade) != floorf(float(pending.grade)) or int(pending.grade) not in [1, 2, 3, 4]:
			return false
	if not data.get("resultId", "") is String:
		return false
	completed = checked
	position = at
	kart_position = saved_kart_position
	kart_yaw = saved_kart_yaw
	pending_lesson = pending.duplicate(true)
	result_id = str(data.get("resultId", "")).substr(0, 160)
	crossing_started = false
	return true
