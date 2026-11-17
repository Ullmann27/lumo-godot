extends RefCounted
## Owns a complete touch gesture after the second contact. Releasing one finger
## cannot turn the remaining contact into a click or a fresh one-finger drag.
var contacts: Dictionary = {}
var captured := false
var _previous_distance := 0.0


func reset() -> void:
	contacts.clear()
	captured = false
	_previous_distance = 0.0


func consume(event: InputEvent) -> Dictionary:
	var result := {"consumed": false, "started": false, "scale": 1.0}
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled:
			contacts[event.index] = event.position
			if contacts.size() >= 2 and not captured:
				captured = true
				result.started = true
				_previous_distance = _distance()
		else:
			contacts.erase(event.index)
		result.consumed = captured
		if contacts.is_empty():
			reset()
		elif captured:
			_previous_distance = _distance()
	elif event is InputEventScreenDrag:
		if contacts.has(event.index):
			contacts[event.index] = event.position
		result.consumed = captured
		if captured and contacts.size() == 2:
			var distance := _distance()
			if _previous_distance >= 12.0 and distance >= 12.0:
				# Limit individual packet jumps without losing the gesture's ownership.
				result.scale = clampf(_previous_distance / distance, 0.65, 1.5)
			_previous_distance = distance
	return result


func _distance() -> float:
	if contacts.size() != 2:
		return 0.0
	var points: Array = contacts.values()
	return (points[0] as Vector2).distance_to(points[1] as Vector2)
