extends SceneTree
## Export actual roadside modules with local origin, materials and separate pieces.
const WORLD = preload("res://scripts/games/kart_world.gd")
const DRESSING = preload("res://scripts/games/kart_fleet_dressing.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://exports/fleet-props")
	var inventory: Array[Dictionary] = []
	for kind in DRESSING.KINDS:
		var model := build_model(kind)
		var piece_count: int = model.get_child_count()
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		assert(document.append_from_scene(model, state) == OK)
		var path: String = "res://exports/fleet-props/" + kind + ".glb"
		assert(document.write_to_filesystem(state, path) == OK)
		var check := GLTFDocument.new()
		var reimport := GLTFState.new()
		assert(check.append_from_file(path, reimport) == OK)
		var loaded: Node = check.generate_scene(reimport)
		assert(loaded != null)
		inventory.append(
			{
				"id": kind,
				"file": kind + ".glb",
				"pieces": piece_count,
				"origin": "ground centre",
				"source": "actual runtime module",
				"collision": "visual prop, placed outside the race lane"
			}
		)
		loaded.free()
		model.free()
	var report := FileAccess.open("res://exports/fleet-props/modules.json", FileAccess.WRITE)
	report.store_string(JSON.stringify(inventory, "  "))
	report.close()
	print("[FleetProps] PASS: 6 actual modular GLBs exported and re-imported")
	quit()


static func build_model(kind: String) -> Node3D:
	var world = WORLD.new()
	DRESSING.add_prop(world, kind, Vector3.ZERO)
	var model := Node3D.new()
	model.name = "Lumo_" + kind
	var piece_count: int = 0
	for group in world.groups.values():
		for index in range(group.transforms.size()):
			var piece := MeshInstance3D.new()
			piece.name = str(group.kind) + "_" + str(piece_count)
			piece.mesh = world._shape(str(group.kind))
			piece.material_override = world._material(group.colors[index], bool(group.glow))
			piece.transform = group.transforms[index]
			model.add_child(piece)
			piece_count += 1
	assert(piece_count > 0)
	world.free()
	return model
