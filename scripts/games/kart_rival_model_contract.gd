extends RefCounted
## Contract for authored seated rival GLBs. No retargeting or generated stand-ins.
## Geometry uses Godot metres, Y up, -Z forward, and the kart's local seat space.
const MAX_TRIANGLES := 60000
const MAX_BONES := 128
const MAX_SURFACES := 16
const CLIPS := ["kart_seated", "kart_steer_left", "kart_steer_right", "kart_hit", "kart_celebrate"]


static func model_path_allowed(path: String) -> bool:
	return path.begins_with("res://assets/characters/rivals/") and path.ends_with(".glb") and not ".." in path


static func _belongs_to(node: Node, model: Node) -> bool:
	return node != null and (node == model or model.is_ancestor_of(node))


static func _safe_clip(player: AnimationPlayer, animation: Animation, model: Node3D) -> bool:
	if animation == null or animation.length <= 0.0 or not is_finite(animation.length):
		return false
	var origin: Node = player.get_node_or_null(player.root_node)
	if not _belongs_to(origin, model):
		return false
	var tracks := 0
	var skeletal_track := false
	for index in range(animation.get_track_count()):
		if not animation.track_is_enabled(index):
			continue
		var kind: int = animation.track_get_type(index)
		if kind not in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D, Animation.TYPE_BLEND_SHAPE]:
			return false
		var path: NodePath = animation.track_get_path(index)
		var target: Node = origin.get_node_or_null(NodePath(path.get_concatenated_names()))
		if not _belongs_to(target, model):
			return false
		if kind == Animation.TYPE_BLEND_SHAPE:
			if not target is MeshInstance3D or path.get_subname_count() != 1:
				return false
		elif target is Skeleton3D:
			if path.get_subname_count() != 1 or target.find_bone(str(path.get_subname(0))) < 0:
				return false
			skeletal_track = skeletal_track or animation.track_get_key_count(index) > 0
		elif not target is Node3D or path.get_subname_count() != 0:
			return false
		tracks += animation.track_get_key_count(index)
	return tracks > 0 and skeletal_track


static func _valid_skin(part: MeshInstance3D, skeleton: Skeleton3D) -> bool:
	var binds: int = part.skin.get_bind_count()
	if binds < 1 or binds > MAX_BONES:
		return false
	for bind in range(binds):
		var named: StringName = part.skin.get_bind_name(bind)
		var bone: int = skeleton.find_bone(str(named)) if not str(named).is_empty() else part.skin.get_bind_bone(bind)
		if bone < 0 or bone >= skeleton.get_bone_count():
			return false
	for surface in range(part.mesh.get_surface_count()):
		var arrays: Array = part.mesh.surface_get_arrays(surface)
		if arrays[Mesh.ARRAY_BONES] == null or arrays[Mesh.ARRAY_WEIGHTS] == null:
			return false
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var vertices: int = arrays[Mesh.ARRAY_VERTEX].size()
		if vertices < 1 or bones.size() != weights.size() or bones.size() not in [vertices * 4, vertices * 8]:
			return false
		var stride: int = bones.size() / vertices
		for vertex in range(vertices):
			var total := 0.0
			for influence in range(stride):
				var index: int = vertex * stride + influence
				if not is_finite(weights[index]) or weights[index] < 0.0 or (weights[index] > 0.0 and (bones[index] < 0 or bones[index] >= binds)):
					return false
				total += weights[index]
			if total < 0.98 or total > 1.02:
				return false
	return true


static func inspect(model: Node) -> Dictionary:
	if not model is Node3D:
		return {"valid": false, "reason": "The model root must be Node3D."}
	var nodes: Array[Node] = [model]
	nodes.append_array(model.find_children("*", "", true, false))
	var players: Array[AnimationPlayer] = []
	var skinned := 0
	var triangles := 0
	var surfaces := 0
	for node in nodes:
		# Imported GLB content is visual data. Scripts and scene-side gameplay
		# nodes are outside the contract and never enter the kart hierarchy.
		if node.get_script() != null or node is CollisionObject3D or node is AudioStreamPlayer or node is AudioStreamPlayer3D or node is AnimationTree:
			return {"valid": false, "reason": "Only imported visual nodes are accepted."}
		if node is AnimationPlayer:
			players.append(node)
		if node is MeshInstance3D and node.mesh != null:
			for surface in range(node.mesh.get_surface_count()):
				if node.mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
					return {"valid": false, "reason": "Triangle mesh required."}
				var arrays: Array = node.mesh.surface_get_arrays(surface)
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
				triangles += (indices.size() if not indices.is_empty() else arrays[Mesh.ARRAY_VERTEX].size()) / 3
				surfaces += 1
			if node.skin != null and node.skin.get_bind_count() > 0:
				var skeleton: Node = node.get_node_or_null(node.skeleton)
				if not skeleton is Skeleton3D or not _belongs_to(skeleton, model) or skeleton.get_bone_count() < 1 or skeleton.get_bone_count() > MAX_BONES:
					return {"valid": false, "reason": "A local valid skeleton is required for every skin."}
				if not _valid_skin(node, skeleton):
					return {"valid": false, "reason": "The skin must bind real normalized vertex weights to its local skeleton."}
				skinned += 1
	if skinned == 0 or triangles == 0 or triangles > MAX_TRIANGLES or surfaces > MAX_SURFACES:
		return {"valid": false, "reason": "Rival must contain a real skinned mesh within the mobile geometry budget."}
	for player in players:
		var clips: Dictionary = {}
		for name: StringName in player.get_animation_list():
			var key: String = str(name).get_file()
			if key not in CLIPS:
				continue
			if _safe_clip(player, player.get_animation(name), model):
				clips[key] = name
		if clips.has("kart_seated"):
			return {"valid": true, "player": player, "clips": clips, "triangles": triangles, "surfaces": surfaces, "skinned_meshes": skinned}
	return {"valid": false, "reason": "A scoped kart_seated skeletal animation is required."}
