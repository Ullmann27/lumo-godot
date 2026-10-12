extends SceneTree
const KIT = preload("res://scripts/creative/creative_kit.gd")
const CATALOG = preload("res://scripts/creative/build_catalog.gd")
const STATE = preload("res://scripts/creative/build_state.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var state = STATE.new()
	assert(state.place("lantern", Vector3i(-4, 0, 0)).is_empty())
	var restored = STATE.new()
	assert(restored.restore(state.to_data()) and restored.pieces[0].part == "lantern")
	var kit = KIT.new()
	var lamp: StaticBody3D = kit.part_node(CATALOG.part("lantern"))
	assert(lamp.get_meta("part") == "lantern")
	var collider: CollisionShape3D = null
	for child in lamp.get_children():
		if child is CollisionShape3D:
			collider = child
	assert(collider != null and collider.shape is BoxShape3D)
	assert(collider.shape.size == Vector3(0.5, 2, 0.5))
	assert(collider.position == Vector3(0.5, 1, 0.5))
	lamp.free()
	for name in ["lumo_lantern", "lumo_treasure_chest"]:
		var packed: PackedScene = load("res://assets/creative/models/" + name + ".glb")
		var model: Node3D = packed.instantiate()
		var meshes := model.find_children("*", "MeshInstance3D", true, false)
		assert(meshes.size() == 1, "Merged mesh avoids multiplying scene/draw nodes")
		var mesh: Mesh = meshes[0].mesh
		assert(mesh.get_surface_count() == 3, "Three shared PBR materials only")
		for surface in range(mesh.get_surface_count()):
			var arrays: Array = mesh.surface_get_arrays(surface)
			assert(arrays[Mesh.ARRAY_TEX_UV].size() == arrays[Mesh.ARRAY_VERTEX].size())
			assert(mesh.surface_get_material(surface) is StandardMaterial3D)
		model.free()
	print("[CreativeAssets] PASS: actual GLB UV/PBR meshes, native part collision and saved-ID compatibility")
	quit(0)
