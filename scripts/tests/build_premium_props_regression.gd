extends SceneTree
## Real Godot geometry and state regressions for twelve Bauwelt props.
const CATALOG = preload("res://scripts/creative/build_catalog.gd")
const STATE = preload("res://scripts/creative/build_state.gd")
const KIT = preload("res://scripts/creative/creative_kit.gd")
const IDS = [
	"cottage", "windmill", "fountain", "swing", "treehouse", "gazebo",
	"mailbox", "vegetable_garden", "slide", "campfire", "fox_statue", "garden_gate"
]
const OUTPUT = "res://exports/creative-build/12_3d_props_gallery.png"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var kit = KIT.new()
	for id in IDS:
		var item: Dictionary = CATALOG.part(id)
		assert(not item.is_empty(), "Missing " + id)
		assert(bool(item.get("premium", false)), "Missing premium tag " + id)
		var body: StaticBody3D = kit.part_node(item)
		var meshes := 0
		var colliders := 0
		for node in body.get_children():
			if node is MeshInstance3D:
				meshes += 1
			if node is CollisionShape3D:
				colliders += 1
		assert(meshes >= 3 and colliders > 0, "Incomplete 3D mesh/collider " + id)
		body.free()
		var state = STATE.new()
		var pos := Vector3i(-12, 0, -12)
		assert(state.place(id, pos, 1).is_empty(), "Cannot place " + id)
		assert(not state.place(id, pos, 1).is_empty(), "Overlapping " + id)
		assert(state.undo() and state.pieces.size() == 0, "Undo " + id)
		assert(state.redo() and state.pieces.size() == 1, "Redo " + id)
		var restored = STATE.new()
		assert(restored.restore(state.to_data()), "Save/restore " + id)
		assert(str(restored.pieces[0].part) == id and int(restored.pieces[0].turn) == 1, "Rotation persisted " + id)
	print("[Bauwelt12] PASS: 12 real 3D meshes, colliders, placement, rotations, undo/redo, state save/restore")
	if "--logic-only" in OS.get_cmdline_user_args():
		quit(0)
		return
	DirAccess.make_dir_recursive_absolute("res://exports/creative-build")
	root.size = Vector2i(1440, 900)
	var stage := Node3D.new()
	root.add_child(stage)
	kit.environment(stage)
	var floor := kit.box(stage, Vector3(7.5, -0.2, 6), Vector3(23.5, 0.35, 19.5), Color("70ad68"))
	floor.material_override = kit.textured("grass", Color("9dd38a"))
	for idx in range(IDS.size()):
		var model: StaticBody3D = kit.part_node(CATALOG.part(IDS[idx]))
		stage.add_child(model)
		model.position = Vector3(float(idx % 4) * 5.0, 0, float(int(idx / 4)) * 6.0)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.fov = 55
	camera.far = 170.0
	camera.position = Vector3(7.5, 16, 30)
	camera.look_at(Vector3(7.5, 1.8, 6), Vector3.UP)
	camera.current = true
	for _i in range(18):
		await process_frame
	var frame: Image = root.get_texture().get_image()
	assert(frame != null and frame.get_width() == 1440 and frame.get_height() == 900)
	assert(frame.save_png(OUTPUT) == OK, "Missing render evidence")
	print("[Bauwelt12] PASS: rendered 1440x900 gallery screenshot " + OUTPUT)
	quit(0)
