extends RefCounted
## Keeps the normal gameplay sight corridor clear of foreground vegetation.
## GeometryInstance3D.transparency is ignored by Compatibility/Mobile, so this
## World-only adapter temporarily parks individual MultiMesh draws below the
## world and restores their exact transforms. It never changes a tree's saved
## position, collision, parent visibility, or the source mesh/material.

const CELL_SIZE := 16.0
const BODY_RADIUS := 1.15
const RESTORE_MARGIN := 0.55
const NEAR_DEPTH := 1.8
const PARK_DEPTH := 100000.0

var roots: Array[Node3D] = []
var owners: Dictionary = {}
var entries: Dictionary = {}
var cells: Dictionary = {}
var hidden: Dictionary = {}
var next_id := 0
var tree: SceneTree
var attached := false
var last_target := 0
var refresh_clock := 0.0
var last_near_volume := AABB()
var last_candidates := 0


func attach(sources: Array[Node3D]) -> void:
	detach()
	roots = sources.duplicate()
	if roots.is_empty():
		return
	tree = roots[0].get_tree()
	attached = true
	tree.node_added.connect(_node_added)
	tree.node_removed.connect(_node_removed)
	for source in roots:
		for node in source.find_children("*", "GeometryInstance3D", true, false):
			_register(node)


func detach() -> void:
	restore_all()
	attached = false
	if is_instance_valid(tree):
		if tree.node_added.is_connected(_node_added):
			tree.node_added.disconnect(_node_added)
		if tree.node_removed.is_connected(_node_removed):
			tree.node_removed.disconnect(_node_removed)
	for id in owners.keys():
		_remove_owner(id)
	roots.clear()
	cells.clear()
	entries.clear()
	last_target = 0
	tree = null


func _node_added(node: Node) -> void:
	if node is GeometryInstance3D:
		_register_weak.call_deferred(weakref(node))


func _register_weak(reference: WeakRef) -> void:
	var node = reference.get_ref()
	if is_instance_valid(node):
		_register(node)


func _node_removed(node: Node) -> void:
	if owners.has(node.get_instance_id()):
		_remove_owner(node.get_instance_id())


func _belongs(node: Node) -> bool:
	for source in roots:
		if is_instance_valid(source) and source.is_ancestor_of(node):
			return true
	return false


func _register(node: Node) -> void:
	if not attached or not is_instance_valid(node) or not node.is_inside_tree() or not _belongs(node):
		return
	var name := str(node.name).to_lower()
	if not ("tree" in name or "bush" in name or "hedge" in name or "foliage" in name or "fir_low" in name):
		return
	if not node is MultiMeshInstance3D and not node is MeshInstance3D:
		return
	var owner_id := node.get_instance_id()
	if owners.has(owner_id):
		return
	var owner := {"node": weakref(node), "ids": []}
	if node is MultiMeshInstance3D:
		if node.multimesh == null or node.multimesh.mesh == null or node.multimesh.instance_count == 0:
			return
		owner["source"] = node.multimesh
		# MultiMesh is a Resource: retain a private draw buffer even if a future
		# region implementation shares a resource with another presentation.
		var working := _copy_draw_buffer(node.multimesh)
		node.multimesh = working
		owner["working"] = working
		owners[owner_id] = owner
		var mesh_bounds := working.mesh.get_aabb()
		for index in range(working.instance_count):
			var original: Transform3D = working.get_meta("authored_transforms")[index]
			_add_entry(owner_id, index, original, node.global_transform * original * mesh_bounds)
	else:
		if node.mesh == null:
			return
		owner["visible"] = node.visible
		owners[owner_id] = owner
		_add_entry(owner_id, -1, Transform3D.IDENTITY, node.global_transform * node.get_aabb())


func _copy_draw_buffer(source: MultiMesh) -> MultiMesh:
	var working := MultiMesh.new()
	working.transform_format = source.transform_format
	working.use_colors = source.use_colors
	working.use_custom_data = source.use_custom_data
	working.mesh = source.mesh
	working.instance_count = source.instance_count
	working.visible_instance_count = source.visible_instance_count
	var authored: Array = source.get_meta("authored_transforms", [])
	var transforms: Array[Transform3D] = []
	var bounds := AABB()
	for index in range(source.instance_count):
		var original: Transform3D = authored[index] if authored.size() == source.instance_count else source.get_instance_transform(index)
		transforms.append(original)
		working.set_instance_transform(index, original)
		if source.use_colors:
			working.set_instance_color(index, source.get_instance_color(index))
		if source.use_custom_data:
			working.set_instance_custom_data(index, source.get_instance_custom_data(index))
		var instance_bounds := original * source.mesh.get_aabb()
		bounds = instance_bounds if index == 0 else bounds.merge(instance_bounds)
	working.set_meta("authored_transforms", transforms)
	# The original bounds must stay fixed when a foreground draw is parked.
	# Building them from authoring data also avoids a renderer/GPU readback.
	working.custom_aabb = bounds
	return working


func _add_entry(owner_id: int, index: int, original: Transform3D, bounds: AABB) -> void:
	var id := next_id
	next_id += 1
	var occupied: Array[Vector2i] = []
	var lower := Vector2i(floori(bounds.position.x / CELL_SIZE), floori(bounds.position.z / CELL_SIZE))
	var upper := Vector2i(floori(bounds.end.x / CELL_SIZE), floori(bounds.end.z / CELL_SIZE))
	for x in range(lower.x, upper.x + 1):
		for z in range(lower.y, upper.y + 1):
			var cell := Vector2i(x, z)
			if not cells.has(cell):
				cells[cell] = []
			cells[cell].append(id)
			occupied.append(cell)
	entries[id] = {"owner": owner_id, "index": index, "original": original, "bounds": bounds, "cells": occupied}
	owners[owner_id].ids.append(id)


func _remove_owner(owner_id: int) -> void:
	if not owners.has(owner_id):
		return
	var owner: Dictionary = owners[owner_id]
	for id in owner.ids:
		_set_hidden(id, false)
		if not entries.has(id):
			continue
		for cell in entries[id].cells:
			cells[cell].erase(id)
			if cells[cell].is_empty():
				cells.erase(cell)
		entries.erase(id)
	var node = owner.node.get_ref()
	if is_instance_valid(node) and node is MultiMeshInstance3D and node.multimesh == owner.working:
		node.multimesh = owner.source
	owners.erase(owner_id)


func _set_hidden(id: int, value: bool) -> void:
	if not entries.has(id) or hidden.has(id) == value:
		return
	var entry: Dictionary = entries[id]
	var owner: Dictionary = owners[entry.owner]
	var node = owner.node.get_ref()
	if is_instance_valid(node):
		if node is MultiMeshInstance3D:
			if node.multimesh == owner.working and int(entry.index) < node.multimesh.instance_count:
				var transform: Transform3D = entry.original
				if value:
					transform.origin.y -= PARK_DEPTH
				node.multimesh.set_instance_transform(int(entry.index), transform)
		else:
			# Restore only the local visibility owned here, never an LOD parent.
			node.visible = false if value else bool(owner.visible)
	if value:
		hidden[id] = true
	else:
		hidden.erase(id)


func restore_all() -> void:
	for id in hidden.keys():
		_set_hidden(id, false)


func _refresh_rebuilt_buffers(delta: float) -> void:
	refresh_clock += delta
	if refresh_clock < 0.5:
		return
	refresh_clock = 0.0
	for id in owners.keys():
		var owner: Dictionary = owners[id]
		var node = owner.node.get_ref()
		if not is_instance_valid(node):
			_remove_owner(id)
		elif node is MultiMeshInstance3D and node.multimesh != owner.working:
			_remove_owner(id)
			_register(node)


func update(camera: Camera3D, focus: Vector3, target_id: int, delta: float) -> void:
	if not attached:
		return
	if target_id != last_target:
		restore_all()
		last_target = target_id
	_refresh_rebuilt_buffers(delta)
	var eye := camera.global_position
	last_near_volume = _near_volume(camera)
	var corridor := AABB(eye, Vector3.ZERO).expand(focus).grow(BODY_RADIUS + RESTORE_MARGIN)
	corridor = corridor.merge(last_near_volume.grow(RESTORE_MARGIN))
	var lower := Vector2i(floori(corridor.position.x / CELL_SIZE), floori(corridor.position.z / CELL_SIZE))
	var upper := Vector2i(floori(corridor.end.x / CELL_SIZE), floori(corridor.end.z / CELL_SIZE))
	var candidates: Dictionary = {}
	for x in range(lower.x, upper.x + 1):
		for z in range(lower.y, upper.y + 1):
			for id in cells.get(Vector2i(x, z), []):
				candidates[id] = true
	# Previously hidden draws must be considered even after leaving their cells.
	for id in hidden:
		candidates[id] = true
	last_candidates = candidates.size()
	for id in candidates:
		var entry: Dictionary = entries[id]
		var owner: Dictionary = owners[entry.owner]
		var node = owner.node.get_ref()
		if not is_instance_valid(node):
			_set_hidden(id, false)
			continue
		var parent_visible: bool = node.get_parent() is Node3D and node.get_parent().is_visible_in_tree()
		var local_visible: bool = node.visible if node is MultiMeshInstance3D else bool(owner.visible)
		var margin := RESTORE_MARGIN if hidden.has(id) else 0.0
		var bounds: AABB = entry.bounds
		var obstructs := bounds.grow(BODY_RADIUS + margin).intersects_segment(eye, focus) != null
		obstructs = obstructs or bounds.grow(margin).intersects(last_near_volume)
		_set_hidden(id, parent_visible and local_visible and obstructs)


func _near_volume(camera: Camera3D) -> AABB:
	var viewport := camera.get_viewport().get_visible_rect().size
	var volume := AABB(camera.global_position, Vector3.ZERO)
	for depth in [maxf(0.05, camera.near), maxf(NEAR_DEPTH, camera.near)]:
		for corner in [Vector2.ZERO, Vector2(viewport.x, 0), viewport, Vector2(0, viewport.y)]:
			volume = volume.expand(camera.project_position(corner, depth))
	return volume.grow(0.2)


func observation() -> Dictionary:
	var cleared: Array[Dictionary] = []
	var renderer_verified := DisplayServer.get_name() != "headless"
	for id in hidden:
		var entry: Dictionary = entries[id]
		var owner: Dictionary = owners[entry.owner]
		var node = owner.node.get_ref()
		if not is_instance_valid(node):
			continue
		if renderer_verified and node is MultiMeshInstance3D:
			var parked: Transform3D = entry.original
			parked.origin.y -= PARK_DEPTH
			renderer_verified = node.multimesh == owner.working and node.multimesh.get_instance_transform(entry.index).is_equal_approx(parked) and owner.source.get_instance_transform(entry.index).is_equal_approx(entry.original)
		var bounds: AABB = entry.bounds
		cleared.append({"node": str(node.get_path()), "instance": entry.index,
			"center": [bounds.get_center().x, bounds.get_center().y, bounds.get_center().z]})
	return {"method": "foreground draw visibility, Compatibility supported", "registered": entries.size(), "rendererVerified": renderer_verified,
		"candidates": last_candidates, "clearedCount": hidden.size(), "cleared": cleared,
		"nearVolume": [last_near_volume.position.x, last_near_volume.position.y, last_near_volume.position.z,
			last_near_volume.size.x, last_near_volume.size.y, last_near_volume.size.z]}
