extends RefCounted
## Open-world mission chains, discovered places and the figure-card album.
## Content comes from open_world_content.json. Progress is an ordered step
## count per chain; cards are never stored as a free list but derived from the
## completed steps, so a card cannot be granted twice or without its mission.
## Like the Freundepost stamps, cards and progress belong only to the World
## save: this model neither issues stars nor consumes school receipts.

const DIALOG = preload("res://scripts/creative/lumo_world_dialog.gd")
const ROSTER = preload("res://scripts/games/lumo_opponent_roster.gd")
const CONTENT_PATH := "res://assets/creative/lumo_world/open_world_content.json"
const VERSION := 1
const TALK_REACH := 3.8
const DRIVE_REACH := 9.0
const STEP_KINDS := ["talk", "show_card", "visit", "drive"]

var content: Dictionary = {}
var errors: Array[String] = []
var progress: Dictionary = {}
var tracked := ""
var visited: Array[String] = []


func _init(raw_content: Variant = null) -> void:
	if raw_content == null:
		raw_content = JSON.parse_string(FileAccess.get_file_as_string(CONTENT_PATH))
	errors = validate_content(raw_content)
	if errors.is_empty():
		content = _prepare(raw_content)
	_reset()


func ready() -> bool:
	return errors.is_empty() and not content.is_empty()


func _reset() -> void:
	progress.clear()
	for mission in content.get("missions", []):
		progress[str(mission.id)] = 0
	tracked = ""
	visited.clear()


static func vec3(raw: Variant) -> Vector3:
	return Vector3(float(raw[0]), float(raw[1]), float(raw[2]))


static func _finite_numbers(raw: Variant, count: int) -> bool:
	if not raw is Array or raw.size() != count:
		return false
	for value in raw:
		if (not value is float and not value is int) or not is_finite(float(value)):
			return false
	return true


## Full referential validation of the content file. Any error disables the
## open-world layer instead of running half-valid missions.
static func validate_content(raw: Variant) -> Array[String]:
	var found: Array[String] = []
	if not raw is Dictionary or raw.get("schemaVersion") != 1:
		return ["content schema version 1 required"]
	# Reject malformed containers before iterating or indexing them.
	for field in ["places", "paths", "figures", "cards", "missions"]:
		if not raw.get(field) is Array or raw[field].is_empty():
			found.append("%s must be a nonempty array" % field)
	if not raw.get("dialogs") is Dictionary or not raw.get("smalltalk", {}) is Dictionary:
		found.append("dialogs and smalltalk must be objects")
	if not found.is_empty():
		return found
	var places: Dictionary = {}
	for place in raw.get("places", []):
		if not place is Dictionary or str(place.get("id", "")).is_empty() or places.has(str(place.id)):
			found.append("invalid or duplicate place")
			continue
		if not _finite_numbers(place.get("at"), 3) or not _finite_numbers(place.get("size"), 2) or str(place.get("title", "")).is_empty():
			found.append("place %s needs title, at and size" % str(place.id))
		if str(place.get("kind", "")) not in ["walk_in", "plaza", "landmark"] or str(place.get("material", "")) not in ["prototype", "original"]:
			found.append("place %s has unknown kind or material" % str(place.id))
		places[str(place.id)] = place
	for path in raw.get("paths", []):
		if not path is Dictionary or not path.get("points") is Array or path.points.size() < 2:
			found.append("path needs two points")
			continue
		for point in path.points:
			if not _finite_numbers(point, 2):
				found.append("path %s has an invalid point" % str(path.get("id", "")))
	var roster_ids: Array[String] = []
	for entry in ROSTER.all():
		roster_ids.append(str(entry.id))
	var figures: Dictionary = {}
	for figure in raw.get("figures", []):
		if not figure is Dictionary or str(figure.get("id", "")).is_empty() or figures.has(str(figure.id)):
			found.append("invalid or duplicate figure")
			continue
		if str(figure.get("source", "")) != "roster" or str(figure.id) not in roster_ids:
			found.append("figure %s is not an original roster figure" % str(figure.id))
		if not places.has(str(figure.get("place", ""))) or not _finite_numbers(figure.get("at"), 3) or str(figure.get("role", "")).is_empty():
			found.append("figure %s needs role, place and position" % str(figure.id))
		figures[str(figure.id)] = figure
	var cards: Dictionary = {}
	for card in raw.get("cards", []):
		if not card is Dictionary or str(card.get("id", "")).is_empty() or cards.has(str(card.id)):
			found.append("invalid or duplicate card")
			continue
		if not figures.has(str(card.get("figure", ""))) or str(card.get("text", "")).is_empty():
			found.append("card %s needs a known figure and text" % str(card.id))
		cards[str(card.id)] = card
	for id in figures:
		if not cards.has(str(figures[id].get("card", ""))):
			found.append("figure %s has no card" % id)
	var dialogs = raw.get("dialogs", {})
	if not dialogs is Dictionary:
		return found + ["dialogs must be an object"]
	var rewarded: Dictionary = {}
	var mission_ids: Dictionary = {}
	for mission in raw.get("missions", []):
		if not mission is Dictionary or str(mission.get("id", "")).is_empty() or mission_ids.has(str(mission.id)):
			found.append("invalid or duplicate mission")
			continue
		mission_ids[str(mission.id)] = true
		var steps = mission.get("steps")
		if not steps is Array or steps.is_empty() or str(mission.get("title", "")).is_empty():
			found.append("mission %s needs title and steps" % str(mission.id))
			continue
		if not steps[0] is Dictionary or not figures.has(str(mission.get("giver", ""))) or str(steps[0].get("figure", "")) != str(mission.get("giver", "")):
			found.append("mission %s must start with its giver" % str(mission.id))
		var step_ids: Dictionary = {}
		for step in steps:
			if not step is Dictionary or str(step.get("id", "")).is_empty() or step_ids.has(str(step.id)):
				found.append("mission %s has an invalid step" % str(mission.id))
				continue
			step_ids[str(step.id)] = true
			var kind := str(step.get("kind", ""))
			if kind not in STEP_KINDS or str(step.get("lead", "")).is_empty():
				found.append("step %s needs kind and lead" % str(step.id))
			if kind in ["talk", "show_card"]:
				if not figures.has(str(step.get("figure", ""))):
					found.append("step %s needs a known figure" % str(step.id))
				var dialog_errors := DIALOG.validate(dialogs.get(str(step.get("dialog", ""))), true)
				if not dialog_errors.is_empty():
					found.append("step %s dialog: %s" % [str(step.id), dialog_errors[0]])
			elif not places.has(str(step.get("place", ""))):
				found.append("step %s needs a known place" % str(step.id))
			if kind == "show_card" and not cards.has(str(step.get("requiresCard", ""))):
				found.append("step %s requires an unknown card" % str(step.id))
			if not step.get("rewardCards", []) is Array:
				found.append("step %s rewards must be an array" % str(step.id))
				continue
			for card_id in step.get("rewardCards", []):
				if not cards.has(str(card_id)) or rewarded.has(str(card_id)):
					found.append("card %s is unknown or rewarded twice" % str(card_id))
				rewarded[str(card_id)] = true
	for card_id in cards:
		if not rewarded.has(card_id):
			found.append("card %s is not reachable through any mission" % card_id)
	return found


func _prepare(raw: Dictionary) -> Dictionary:
	var prepared: Dictionary = raw.duplicate(true)
	var names: Dictionary = {}
	for entry in ROSTER.all():
		names[str(entry.id)] = str(entry.get("name", entry.id))
	prepared["placeIndex"] = {}
	for place in prepared.places:
		place["position"] = vec3(place.at)
		place["radius"] = maxf(float(place.size[0]), float(place.size[1])) * 0.5 + 1.5
		prepared.placeIndex[str(place.id)] = place
	prepared["figureIndex"] = {}
	for figure in prepared.figures:
		figure["position"] = vec3(figure.at)
		figure["name"] = names.get(str(figure.id), str(figure.id))
		prepared.figureIndex[str(figure.id)] = figure
	prepared["cardIndex"] = {}
	for card in prepared.cards:
		prepared.cardIndex[str(card.id)] = card
	prepared["missionIndex"] = {}
	for mission in prepared.missions:
		prepared.missionIndex[str(mission.id)] = mission
	return prepared


func place(id: String) -> Dictionary:
	return content.get("placeIndex", {}).get(id, {})


func figure(id: String) -> Dictionary:
	return content.get("figureIndex", {}).get(id, {})


func card(id: String) -> Dictionary:
	return content.get("cardIndex", {}).get(id, {})


func mission(id: String) -> Dictionary:
	return content.get("missionIndex", {}).get(id, {})


func dialog(id: String) -> Dictionary:
	return content.get("dialogs", {}).get(id, {})


func mission_ids() -> Array[String]:
	var ids: Array[String] = []
	for entry in content.get("missions", []):
		ids.append(str(entry.id))
	return ids


func state(mission_id: String) -> String:
	var steps: Array = mission(mission_id).get("steps", [])
	var done := int(progress.get(mission_id, 0))
	if steps.is_empty():
		return ""
	if done >= steps.size():
		return "done"
	return "active" if done > 0 else "available"


func current_step(mission_id: String) -> Dictionary:
	var steps: Array = mission(mission_id).get("steps", [])
	var done := int(progress.get(mission_id, 0))
	return steps[done] if done < steps.size() else {}


func step_target(step: Dictionary) -> Vector3:
	if step.has("figure"):
		return figure(str(step.figure)).get("position", Vector3.ZERO)
	return place(str(step.get("place", ""))).get("position", Vector3.ZERO)


## Cards follow from completed steps, in album order.
func cards() -> Array[String]:
	var owned: Dictionary = {}
	for mission_id in mission_ids():
		var steps: Array = mission(mission_id).get("steps", [])
		for index in range(mini(int(progress.get(mission_id, 0)), steps.size())):
			for card_id in steps[index].get("rewardCards", []):
				owned[str(card_id)] = true
	var ordered: Array[String] = []
	for entry in content.get("cards", []):
		if owned.has(str(entry.id)):
			ordered.append(str(entry.id))
	return ordered


func has_card(card_id: String) -> bool:
	return card_id in cards()


func card_source(card_id: String) -> String:
	for mission_id in mission_ids():
		for step in mission(mission_id).get("steps", []):
			if card_id in step.get("rewardCards", []):
				return mission_id
	return ""


func figure_at(at: Vector3) -> String:
	if not at.is_finite():
		return ""
	var best := ""
	var best_distance := TALK_REACH * TALK_REACH
	for entry in content.get("figures", []):
		var offset: Vector3 = entry.position - at
		var distance := Vector2(offset.x, offset.z).length_squared()
		if distance <= best_distance and absf(offset.y) < 3.0:
			best = str(entry.id)
			best_distance = distance
	return best


func place_at(at: Vector3, reach_padding := 0.0) -> String:
	if not at.is_finite():
		return ""
	for entry in content.get("places", []):
		var offset: Vector3 = entry.position - at
		if Vector2(offset.x, offset.z).length() <= float(entry.radius) + reach_padding:
			return str(entry.id)
	return ""


## Mission steps a figure can serve right now. The tracked chain comes first.
func steps_for_figure(figure_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var order := mission_ids()
	if not tracked.is_empty():
		order.erase(tracked)
		order.push_front(tracked)
	for mission_id in order:
		var step := current_step(mission_id)
		if str(step.get("kind", "")) in ["talk", "show_card"] and str(step.get("figure", "")) == figure_id:
			result.append({"mission": mission_id, "step": step})
	return result


func can_complete(mission_id: String, step_id: String, at: Vector3, driving: bool) -> bool:
	var step := current_step(mission_id)
	if step.is_empty() or str(step.id) != step_id or not at.is_finite():
		return false
	match str(step.kind):
		"talk", "show_card":
			if driving or figure_at(at) != str(step.figure):
				return false
			return str(step.kind) != "show_card" or has_card(str(step.requiresCard))
		"visit":
			return place_at(at) == str(step.place)
		"drive":
			var target: Vector3 = place(str(step.place)).position
			return driving and Vector2(at.x - target.x, at.z - target.z).length() <= DRIVE_REACH
	return false


## Completes exactly the current step. Returns the cards that are new now.
func complete(mission_id: String, step_id: String, at: Vector3, driving: bool) -> Dictionary:
	if not can_complete(mission_id, step_id, at, driving):
		return {"ok": false, "cards": []}
	var before := cards()
	progress[mission_id] = int(progress[mission_id]) + 1
	var gained: Array[String] = []
	for card_id in cards():
		if card_id not in before:
			gained.append(card_id)
	if state(mission_id) == "done":
		tracked = ""
		for other in mission_ids():
			if state(other) == "active":
				tracked = other
				break
	else:
		tracked = mission_id
	return {"ok": true, "cards": gained, "done": state(mission_id) == "done"}


## Visit and drive steps finish by arriving; places are discovered on foot or by kart.
func observe(at: Vector3, driving: bool) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var here := place_at(at)
	if not here.is_empty() and here not in visited:
		visited.append(here)
		events.append({"type": "discovered", "place": here})
	var order := mission_ids()
	if not tracked.is_empty():
		order.erase(tracked)
		order.push_front(tracked)
	for mission_id in order:
		var step := current_step(mission_id)
		if str(step.get("kind", "")) not in ["visit", "drive"] or state(mission_id) != "active":
			continue
		var result := complete(mission_id, str(step.id), at, driving)
		if bool(result.ok):
			events.append({"type": "step", "mission": mission_id, "step": step, "cards": result.cards, "done": result.done})
	return events


## Active and not yet started missions can be followed; a fresh one guides to its giver.
func track(mission_id: String) -> bool:
	if state(mission_id) not in ["active", "available"]:
		return false
	tracked = mission_id
	return true


func tracked_target() -> Dictionary:
	if tracked.is_empty() or state(tracked) not in ["active", "available"]:
		return {}
	var step := current_step(tracked)
	return {"id": tracked + ":" + str(step.id), "at": step_target(step), "title": str(mission(tracked).title), "lead": str(step.lead)}


func hud_line() -> String:
	var done := 0
	for mission_id in mission_ids():
		if state(mission_id) == "done":
			done += 1
	var target := tracked_target()
	if target.is_empty():
		var hint := "Sprich mit Figuren mit dem Auftrags-Schild." if done < mission_ids().size() else "Alle Missionen geschafft!"
		return "◆ Missionen %d/%d · Karten %d/%d · %s" % [done, mission_ids().size(), cards().size(), content.get("cards", []).size(), hint]
	var steps: Array = mission(tracked).steps
	return "◆ %s · Schritt %d/%d\n%s" % [str(target.title), int(progress[tracked]) + 1, steps.size(), str(target.lead)]


func to_data() -> Dictionary:
	return {"version": VERSION, "progress": progress.duplicate(), "tracked": tracked, "visited": visited.duplicate(), "cards": cards()}


## Validate the whole section before changing any field. An empty section is an
## older World save without open-world progress.
func restore(raw: Variant) -> bool:
	if not ready() or not raw is Dictionary:
		return false
	if raw.is_empty():
		_reset()
		return true
	if typeof(raw.get("version")) not in [TYPE_INT, TYPE_FLOAT] or raw.get("version") != VERSION:
		return false
	var saved_progress = raw.get("progress")
	if not saved_progress is Dictionary:
		return false
	var checked: Dictionary = {}
	for mission_id in mission_ids():
		var value = saved_progress.get(mission_id, 0)
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)) or float(value) != floorf(float(value)):
			return false
		if float(value) < 0.0 or float(value) > float(mission(mission_id).steps.size()):
			return false
		checked[mission_id] = int(value)
	for key in saved_progress:
		if not checked.has(str(key)):
			return false
	var saved_visited = raw.get("visited", [])
	if not saved_visited is Array:
		return false
	var places: Array[String] = []
	for id in saved_visited:
		if not id is String or place(id).is_empty() or id in places:
			return false
		places.append(id)
	var previous_progress := progress.duplicate()
	progress = checked
	var derived := cards()
	var consistent := true
	# A card prerequisite that was passed must be satisfied by the save itself.
	for mission_id in mission_ids():
		var steps: Array = mission(mission_id).steps
		for index in range(int(checked[mission_id])):
			if str(steps[index].kind) == "show_card" and str(steps[index].requiresCard) not in derived:
				consistent = false
	var saved_cards = raw.get("cards", derived)
	if not saved_cards is Array or saved_cards.size() != derived.size():
		consistent = false
	else:
		var seen_cards: Dictionary = {}
		for card_id in saved_cards:
			if not card_id is String or card_id not in derived or seen_cards.has(card_id):
				consistent = false
			else:
				seen_cards[card_id] = true
	var saved_tracked = raw.get("tracked", "")
	if not saved_tracked is String or (not saved_tracked.is_empty() and state(saved_tracked) not in ["active", "available"]):
		consistent = false
	if not consistent:
		progress = previous_progress
		return false
	tracked = saved_tracked
	visited = places
	return true
