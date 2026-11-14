extends RefCounted
## Inspect the actual loaded resource and skin; a node named Lumo is not proof.
const ADAPTER := "res://scripts/characters/lumo/lumo_rigged_actor.gd"
const MODEL := "res://assets/characters/lumo_facial/Lumo-Facial-Mobile.glb"


static func inspect(hub: Node) -> Dictionary:
	var failures: Array[String] = []
	var result := {"failures": failures, "model": "", "adapter": "", "bones": 0,
		"skinned_meshes": 0, "vertices": 0, "visible_vertices": 0,
		"clips": [], "mesh_resources": [], "actual_production_scene": hub.scene_file_path,
		"headless": DisplayServer.get_name() == "headless"}
	var actor := hub.find_child("OriginalAnimatedLumo", true, false) as Node3D
	if actor == null:
		failures.append("Original Lumo actor is absent")
		return result
	var source: Script = actor.get_script()
	result.adapter = source.resource_path if source != null else ""
	if result.adapter != ADAPTER:
		failures.append("Hub must use the same original rig adapter as the learning world")
		return result
	if not actor.call("is_usable"):
		failures.append("The original model did not load a usable rig")
		return result
	var visual := actor.get("visual") as Node3D
	var skeleton := actor.get("skeleton") as Skeleton3D
	var player := actor.get("player") as AnimationPlayer
	result.model = visual.scene_file_path
	result.load_kind = str(actor.get("model_load_kind"))
	result.bones = skeleton.get_bone_count()
	if result.model != MODEL or result.load_kind != "imported_packed_scene":
		failures.append("Hub must instantiate the imported original facial GLB")
	if result.bones != 65:
		failures.append("The original 65-bone skeleton is required")
	for bone in ["Head", "Hand.L", "Hand.R", "Foot.L", "Foot.R"]:
		if skeleton.find_bone(bone) < 0:
			failures.append("Original semantic bone is missing: " + bone)
	for clip in ["idle", "greeting_wave", "celebrate", "point_portal", "agree_nod",
		"kart_seated", "kart_steer_left", "kart_steer_right", "kart_jump"]:
		if not player.has_animation(clip):
			failures.append("Original animation is missing: " + clip)
		else:
			result.clips.append(clip)
	for node in visual.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null or mesh.skin == null:
			continue
		if not mesh.mesh.resource_path.begins_with(MODEL + "::"):
			failures.append("A visible skin is not sourced from the original GLB")
		if mesh.get_node_or_null(mesh.skeleton) != skeleton:
			failures.append("Original mesh is not bound to the real skeleton")
		result.skinned_meshes += 1
		result.mesh_resources.append(mesh.mesh.resource_path)
		for surface in range(mesh.mesh.get_surface_count()):
			var arrays: Array = mesh.mesh.surface_get_arrays(surface)
			result.vertices += arrays[Mesh.ARRAY_VERTEX].size()
			if mesh.is_visible_in_tree():
				result.visible_vertices += arrays[Mesh.ARRAY_VERTEX].size()
	# The existing facial adapter hides its eyelid skin between actual blinks.
	if result.skinned_meshes < 2 or result.visible_vertices < 1000:
		failures.append("Original body and facial skin geometry are missing")
	return result


static func projected_mesh_bounds(hub: Node) -> Rect2:
	var actor := hub.find_child("OriginalAnimatedLumo", true, false) as Node3D
	var camera := hub.find_child("LumoHeroCamera", true, false) as Camera3D
	var result := Rect2()
	var first := true
	if actor == null or camera == null:
		return result
	# Conservative authored mesh bounds include ears, boots and tail. Raster
	# review additionally checks the actual animated silhouette in both layouts.
	for node in actor.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null or not mesh.is_visible_in_tree():
			continue
		for corner in range(8):
			var point := camera.unproject_position(mesh.to_global(mesh.get_aabb().get_endpoint(corner)))
			result = Rect2(point, Vector2.ZERO) if first else result.expand(point)
			first = false
	return result
