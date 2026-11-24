extends Node
## Stable lesson-object IDs. A layout change moves nodes, never their identity.
## This registry does not count objects, judge answers, or persist child data.

signal target_removed(target_id: String)
signal lesson_changed(lesson_id: String, revision: int)

var lesson_id: String = ""
var revision: int = 0
var _targets: Dictionary = {}


func begin_lesson(id: String, next_revision: int = 0) -> bool:
	if not _valid_id(id, 385) or next_revision < 0:
		return false
	if id == lesson_id and next_revision < revision:
		return false
	if id == lesson_id and next_revision == revision:
		return true
	clear_targets()
	lesson_id = id
	revision = next_revision
	lesson_changed.emit(lesson_id, revision)
	return true


func register_target(
	id: String, object: Node3D, local_anchor: Vector3 = Vector3.ZERO, metadata: Dictionary = {}
) -> bool:
	if lesson_id.is_empty() or not _valid_id(id):
		return false
	if not is_instance_valid(object) or not local_anchor.is_finite():
		return false
	if _targets.has(id):
		var previous: Node3D = _targets[id].node.get_ref() as Node3D
		if is_instance_valid(previous) and previous != object:
			# Duplicate IDs must not silently redirect a pending spoken gesture.
			return false
	_targets[id] = {
		"node": weakref(object),
		"local_anchor": local_anchor,
		"metadata": metadata.duplicate(true),
	}
	return true


func unregister_target(id: String, expected_object: Node3D = null) -> bool:
	if not _targets.has(id):
		return false
	if is_instance_valid(expected_object):
		if _targets[id].node.get_ref() != expected_object:
			return false
	_targets.erase(id)
	target_removed.emit(id)
	return true


func clear_targets() -> void:
	var previous: Array = _targets.keys()
	_targets.clear()
	for id: String in previous:
		target_removed.emit(id)


func registered_ids() -> Array[String]:
	var result: Array[String] = []
	for id: String in _targets.keys():
		if not resolve_target(id).is_empty():
			result.append(id)
	result.sort()
	return result


func target_ids() -> Array[String]:
	return registered_ids()


func resolve_target(id: String) -> Dictionary:
	if not _targets.has(id):
		return {}
	var entry: Dictionary = _targets[id]
	var object := entry.node.get_ref() as Node3D
	if not is_instance_valid(object) or object.is_queued_for_deletion():
		unregister_target(id)
		return {}
	if not object.is_inside_tree():
		return {}
	var at: Vector3 = object.to_global(entry.local_anchor)
	if not at.is_finite():
		return {}
	return {
		"id": id,
		"lesson_id": lesson_id,
		"revision": revision,
		"node": object,
		"world_position": at,
		"visible": object.is_visible_in_tree(),
		"metadata": entry.metadata.duplicate(true),
	}


## Null is deliberate: an unavailable target must never become the world origin.
func world_target(id: String) -> Variant:
	var resolved := resolve_target(id)
	return null if resolved.is_empty() else resolved.world_position


## Point visibility only. The owning lesson still fits full meshes and controls.
func viewport_visibility(id: String, camera: Camera3D, usable_rect: Rect2) -> Dictionary:
	var target := resolve_target(id)
	if target.is_empty():
		return {"visible": false, "reason": "missing", "id": id}
	if not target.visible:
		return {"visible": false, "reason": "hidden", "id": id}
	if not is_instance_valid(camera) or not camera.is_inside_tree():
		return {"visible": false, "reason": "missing_camera", "id": id}
	var at: Vector3 = target.world_position
	if camera.is_position_behind(at):
		return {"visible": false, "reason": "behind_camera", "id": id}
	var projected := camera.unproject_position(at)
	var visible := usable_rect.has_point(projected)
	return {
		"visible": visible,
		"reason": "visible" if visible else "outside_active_view",
		"id": id,
		"screen_position": projected,
		"world_position": at,
	}


static func _valid_id(id: String, maximum_length: int = 160) -> bool:
	if id.is_empty() or id.length() > maximum_length or id != id.strip_edges():
		return false
	for i in range(id.length()):
		if id.unicode_at(i) < 32 or id.unicode_at(i) == 127:
			return false
	return true
