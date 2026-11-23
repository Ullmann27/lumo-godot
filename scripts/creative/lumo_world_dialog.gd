extends RefCounted
## Branching conversation with a local computer-controlled World figure.
## A tree is plain data: nodes with text and choices; a choice either leads to
## another node or ends with the action "complete" (the mission step succeeds)
## or "close". Nodes may carry grade-specific text and choices under "byGrade".
## The runner never awards anything itself; the mission model decides.

const ACTIONS := ["complete", "close"]
const MAX_NODES := 24
const MAX_CHOICES := 4

var tree: Dictionary = {}
var grade := 1
var owned_cards: Array = []
var node_id := ""


func _init(dialog: Dictionary = {}, school_grade := 1, cards: Array = []) -> void:
	tree = dialog
	grade = clampi(school_grade, 1, 4)
	owned_cards = cards.duplicate()
	node_id = str(tree.get("start", ""))


func active() -> bool:
	return not node_id.is_empty() and _node(node_id).has("choices")


## The visible text and choices of the current node. Choices that need a card
## the child does not own stay visible but disabled, so the requirement is clear.
func view() -> Dictionary:
	var node := _node(node_id)
	if node.is_empty():
		return {}
	var choices: Array[Dictionary] = []
	var raw_choices: Array = node.get("choices", [])
	for index in range(raw_choices.size()):
		var choice: Dictionary = raw_choices[index]
		var needed := str(choice.get("requiresCard", ""))
		choices.append({"index": index, "label": str(choice.get("label", "")), "enabled": needed.is_empty() or needed in owned_cards, "requiresCard": needed})
	return {"id": node_id, "text": str(node.get("text", "")), "choices": choices}


## Returns "next", "complete", "close" or "" for a rejected choice.
func choose(index: int) -> String:
	var node := _node(node_id)
	var raw_choices: Array = node.get("choices", [])
	if index < 0 or index >= raw_choices.size():
		return ""
	var choice: Dictionary = raw_choices[index]
	var needed := str(choice.get("requiresCard", ""))
	if not needed.is_empty() and needed not in owned_cards:
		return ""
	if choice.has("next"):
		node_id = str(choice.next)
		return "next"
	var action := str(choice.get("action", ""))
	if action in ACTIONS:
		node_id = ""
		return action
	return ""


func _node(id: String) -> Dictionary:
	var nodes: Dictionary = tree.get("nodes", {})
	if not nodes.has(id) or not nodes[id] is Dictionary:
		return {}
	var node: Dictionary = nodes[id]
	if node.has("byGrade"):
		var variants: Dictionary = node.byGrade
		return variants.get(str(grade), {})
	return node


## Structural validation used by the content loader and regressions.
## Every grade must reach "complete" from the start when require_complete.
static func validate(dialog: Variant, require_complete: bool) -> Array[String]:
	var errors: Array[String] = []
	if not dialog is Dictionary or not dialog.get("nodes") is Dictionary:
		return ["dialog needs nodes"]
	var nodes: Dictionary = dialog.nodes
	if nodes.is_empty() or nodes.size() > MAX_NODES:
		errors.append("dialog node count out of range")
	if not nodes.has(str(dialog.get("start", ""))):
		errors.append("dialog start node missing")
	for id in nodes:
		var node = nodes[id]
		if not node is Dictionary:
			errors.append("node %s is not an object" % id)
			continue
		var variants: Array = []
		if node.has("byGrade"):
			if not node.byGrade is Dictionary:
				errors.append("node %s byGrade is not an object" % id)
				continue
			for school_grade in ["1", "2", "3", "4"]:
				if not node.byGrade.has(school_grade):
					errors.append("node %s misses grade %s" % [id, school_grade])
				else:
					variants.append(node.byGrade[school_grade])
		else:
			variants.append(node)
		for variant in variants:
			if not variant is Dictionary or str(variant.get("text", "")).strip_edges().is_empty():
				errors.append("node %s needs text" % id)
				continue
			var choices = variant.get("choices")
			if not choices is Array or choices.is_empty() or choices.size() > MAX_CHOICES:
				errors.append("node %s needs 1-%d choices" % [id, MAX_CHOICES])
				continue
			for choice in choices:
				if not choice is Dictionary or str(choice.get("label", "")).strip_edges().is_empty():
					errors.append("node %s has a choice without label" % id)
				elif choice.has("next") == choice.has("action"):
					errors.append("node %s choice needs exactly one of next/action" % id)
				elif choice.has("next") and not nodes.has(str(choice.next)):
					errors.append("node %s points to missing node %s" % [id, str(choice.next)])
				elif choice.has("action") and str(choice.action) not in ACTIONS:
					errors.append("node %s has unknown action" % id)
	if errors.is_empty() and require_complete:
		for school_grade in range(1, 5):
			if not _reaches_complete(dialog, school_grade):
				errors.append("grade %d cannot complete the dialog" % school_grade)
	return errors


static func _reaches_complete(dialog: Dictionary, school_grade: int) -> bool:
	var runner = load("res://scripts/creative/lumo_world_dialog.gd").new(dialog, school_grade, ["*"])
	var queue: Array[String] = [str(dialog.start)]
	var seen: Dictionary = {}
	while not queue.is_empty():
		var id: String = queue.pop_front()
		if seen.has(id):
			continue
		seen[id] = true
		var node: Dictionary = runner._node(id)
		for choice in node.get("choices", []):
			if str(choice.get("action", "")) == "complete":
				return true
			if choice.has("next"):
				queue.append(str(choice.next))
	return false
