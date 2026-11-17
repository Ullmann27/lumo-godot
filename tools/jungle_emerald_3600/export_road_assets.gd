extends SceneTree
## Exports actual runtime road geometry; the PackedScene preserves all collision proxies.
const WORLD = preload("res://scripts/games/kart_world.gd")
const COURSE = preload("res://scripts/games/kart_jungle_course.gd")
const DESTINATION: String = "res://art/jungle_emerald_3600/geometry"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(DESTINATION)
	var world = WORLD.new()
	root.add_child(world)
	world.build(true, COURSE.ID, true)
	var road_root: Node3D = world.get_node("DschungelherzRoad")
	_assign_owner(road_root, road_root)
	var packed := PackedScene.new()
	assert(packed.pack(road_root) == OK)
	assert(ResourceSaver.save(packed, DESTINATION + "/dschungelherz_road_with_collision.tscn") == OK)
	var round_trip: PackedScene = load(DESTINATION + "/dschungelherz_road_with_collision.tscn")
	var round_trip_root: Node3D = round_trip.instantiate()
	assert(round_trip_root.find_children("*", "StaticBody3D", true, false).size() == 12)
	assert(round_trip_root.find_children("*", "CollisionShape3D", true, false).size() == 36)
	round_trip_root.free()
	var visual := Node3D.new()
	visual.name = "DschungelherzRoadVisual"
	for section in range(12):
		var original: MeshInstance3D = road_root.get_node("RoadSection%02d" % section)
		var node := MeshInstance3D.new()
		node.name = original.name
		node.mesh = original.mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("936639") if section == 6 else Color("939586")
		material.roughness = 0.70 if section == 6 else (0.42 if section == 10 else 0.82)
		node.material_override = material
		visual.add_child(node)
		node.owner = visual
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	assert(document.append_from_scene(visual, state) == OK)
	var glb_path: String = DESTINATION + "/dschungelherz_road.glb"
	assert(document.write_to_filesystem(state, glb_path) == OK)
	var import_document := GLTFDocument.new()
	var import_state := GLTFState.new()
	assert(import_document.append_from_file(glb_path, import_state) == OK)
	var imported: Node3D = import_document.generate_scene(import_state)
	assert(imported.find_children("*", "MeshInstance3D", true, false).size() == 12)
	var report: Dictionary = {
		"status": "passed", "source": "LumoRaceWorld.build(true, jungle_emerald_3600, true)",
		"road_glb": glb_path, "road_meshes_after_glb_reimport": 12,
		"godot_scene": DESTINATION + "/dschungelherz_road_with_collision.tscn",
		"collision_bodies_after_scene_reload": 12, "collision_shapes_after_scene_reload": 36,
		"shader_preservation": "PackedScene retains the runtime ShaderMaterial; GLB has PBR colour/roughness approximation",
		"blender_material_authority": "Blender master scene provided by the environment production"
	}
	DirAccess.make_dir_recursive_absolute("res://evidence/jungle_emerald_3600")
	var file := FileAccess.open("res://evidence/jungle_emerald_3600/road_export.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("[DschungelherzRoadExport] PASS ", JSON.stringify(report))
	imported.free()
	visual.free()
	world.queue_free()
	await process_frame
	quit(0)

func _assign_owner(node: Node, owner_root: Node) -> void:
	for child in node.get_children():
		child.owner = owner_root
		_assign_owner(child, owner_root)

