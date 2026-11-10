extends SceneTree
## Bauwelt 2013 identity: new landmarks stay real placeable parts with
## snap, undo/redo and save, and expose the expected combined meshes.
const CATALOG = preload("res://scripts/creative/build_catalog.gd")
const STATE = preload("res://scripts/creative/build_state.gd")
const KIT = preload("res://scripts/creative/creative_kit.gd")


func _initialize() -> void:
	call_deferred("_run")


func _meshes_and_colliders(body: Node) -> Vector2i:
	var meshes := 0
	var colliders := 0
	for node in body.get_children():
		if node is MeshInstance3D:
			meshes += 1
		if node is CollisionShape3D:
			colliders += 1
	return Vector2i(meshes, colliders)


func _run() -> void:
	assert(not CATALOG.part("cottage").is_empty())
	assert(str(CATALOG.part("cottage").name) == "Werkstatt")
	assert(CATALOG.part("cottage").size == Vector3i(3, 3, 3))
	var observatory: Dictionary = CATALOG.part("observatory")
	assert(not observatory.is_empty())
	assert(str(observatory.name) == "Sternwarte")
	assert(observatory.size == Vector3i(3, 4, 3))
	assert(bool(observatory.get("premium", false)))

	var kit = KIT.new()
	var workshop: StaticBody3D = kit.part_node(CATALOG.part("cottage"))
	var counts: Vector2i = _meshes_and_colliders(workshop)
	assert(counts.x >= 5 and counts.y > 0, "Werkstatt needs combined meshes + collider")
	assert(workshop.get_node_or_null("LEmblem") != null, "Werkstatt carries the L emblem")
	assert(workshop.get_node_or_null("WorkshopTimber") != null, "Fachwerk timber missing")
	workshop.free()

	var stern: StaticBody3D = kit.part_node(observatory)
	counts = _meshes_and_colliders(stern)
	assert(counts.x >= 4 and counts.y > 0, "Sternwarte needs dome meshes + collider")
	assert(stern.get_node_or_null("ObservatoryGlass") != null)
	assert(stern.get_node_or_null("LEmblem") != null)
	stern.free()

	var tree: StaticBody3D = kit.part_node(CATALOG.part("tree"))
	assert(tree.get_node_or_null("Trunk") != null and tree.get_node_or_null("Crown") != null)
	var collider: CollisionShape3D = null
	for child in tree.get_children():
		if child is CollisionShape3D:
			collider = child
	assert(collider != null and collider.shape is BoxShape3D)
	assert(collider.shape.size == Vector3(0.4, 2, 0.4))
	assert(collider.position == Vector3(1, 1, 1))
	tree.free()

	var magic_mat: StandardMaterial3D = BuildVoxelStyle.material("magic", Color("7a8bff"))
	assert(magic_mat.albedo_texture != null)
	assert(magic_mat.uv1_triplanar == false)

	var state = STATE.new()
	assert(state.place("cottage", Vector3i(7, 0, 5)).is_empty(), "Werkstatt must sit on the right bank")
	assert(state.place("observatory", Vector3i(8, 0, -10)).is_empty(), "Sternwarte placement")
	assert(state.place("tree", Vector3i(11, 0, 4)).is_empty())
	assert(state.place("bridge", Vector3i(-1, 0, 6)).is_empty())
	assert(state.place("bridge", Vector3i(2, 0, 6)).is_empty())
	assert(state.place("magic", Vector3i(5, 0, 5)).is_empty())
	assert(not state.place("cottage", Vector3i(7, 0, 5)).is_empty(), "overlap rejected")
	assert(state.pieces.size() == 6)
	assert(state.undo() and state.pieces.size() == 5)
	assert(state.redo() and state.pieces.size() == 6)
	var restored = STATE.new()
	assert(restored.restore(state.to_data()), "save/restore landmarks")
	var ids: Array[String] = []
	for piece in restored.pieces:
		ids.append(str(piece.part))
	assert("cottage" in ids and "observatory" in ids and "tree" in ids)
	assert("bridge" in ids and "magic" in ids)
	# Existing templates still build and pass their goals.
	var templates = STATE.new()
	templates.template("castle")
	assert(templates.challenge_passes("castle"))
	assert(templates.pieces.size() > 140)
	templates.template("house")
	assert(templates.challenge_passes("house"))
	templates.template("bridge")
	assert(templates.challenge_passes("bridge"))

	# Expanded footprint: 33x33 (HALF=16) -> 49x49 (HALF=24), 2.20x the old square.
	# Old cells stay valid; river stays open; river islands are buildable.
	assert(STATE.HALF == 24)
	assert(STATE.LIMIT >= 1536)
	assert(STATE.ground_at(-16, 0) and STATE.ground_at(16, 5))
	assert(STATE.ground_at(-24, 0) and STATE.ground_at(24, 24) and STATE.ground_at(20, -24))
	assert(not STATE.ground_at(-25, 0) and not STATE.ground_at(0, 25))
	assert(not STATE.ground_at(0, 0) and not STATE.ground_at(3, 6), "river channel stays open")
	assert(STATE.ground_at(1, -12) and STATE.ground_at(2, 19), "river islands are buildable")
	var bounds = STATE.new()
	assert(bounds.place("stone", Vector3i(22, 0, 20)).is_empty(), "new land is placeable")
	assert(bounds.place("sand", Vector3i(1, 0, -12)).is_empty(), "river island is placeable")
	assert(not bounds.place("stone", Vector3i(25, 0, 0)).is_empty(), "outside the new rim rejected")
	assert(not bounds.place("stone", Vector3i(0, 0, 0)).is_empty(), "open river rejected")
	# Old-save compatibility: a snapshot taken on the original castle cells still restores.
	var legacy = STATE.new()
	assert(legacy.place("cottage", Vector3i(7, 0, 5)).is_empty())
	assert(legacy.place("lantern", Vector3i(-4, 0, -4)).is_empty())
	var saved: Dictionary = legacy.to_data()
	assert(int(saved.version) == STATE.SAVE_VERSION)
	var reloaded = STATE.new()
	assert(reloaded.restore(saved), "legacy save must load on the larger island")
	assert(reloaded.pieces.size() == 2)
	assert(int(reloaded.pieces[0].x) == 7 and int(reloaded.pieces[0].z) == 5)
	assert(int(reloaded.pieces[1].x) == -4 and int(reloaded.pieces[1].z) == -4)
	# Starter plots place on the new land without touching old IDs.
	for plot_id in ["plot_garden", "plot_harbor", "plot_island"]:
		var plot = STATE.new()
		plot.template(plot_id)
		assert(plot.pieces.size() >= 6, plot_id)
		if plot_id == "plot_garden":
			assert(int(plot.pieces[0].x) <= -18)
		if plot_id == "plot_island":
			assert(STATE.river_island_at(int(plot.pieces[0].x), int(plot.pieces[0].z)))

	print("[BauweltIdentity2013] PASS workshop, observatory, branched tree, L emblem, place/undo/save, templates, expanded grid")
	quit(0)
