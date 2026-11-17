extends SceneTree
## The Sonnenhafen gap must be a real empty, readable crystal gorge, not
## flat grass or a hidden collision bridge. All checkpoints and physics stay.
const WORLD = preload("res://scripts/games/kart_world.gd")
const STUNT = preload("res://scripts/games/kart_sonnenhafen_stunt_sequence.gd")


func _initialize() -> void:
	call_deferred("_run")


func _test_profile(low: bool) -> Dictionary:
	var world = WORLD.new()
	root.add_child(world)
	world.build(low, "sonnenhafen", true)
	var kicker: Dictionary = {}
	for candidate in world.action.get("kickers", []):
		if bool(candidate.get("precision_jump", false)):
			kicker = candidate
	assert(not kicker.is_empty(), "The real precision kicker exists")
	var d: float = (float(kicker.gap_start) + float(kicker.gap_end)) * 0.5
	var at: Vector3 = world.position_at(d)
	var cut: float = world._ground_height(at.x, at.z)
	assert(world.in_gap(d), "The road gap remains physically empty")
	assert(cut < -9.0, "Grass must be excavated well below the drop")
	assert(cut < at.y - 4.0, "The gorge must be visibly deep below the racing road")
	assert(float(kicker.gap_end) - float(kicker.gap_start) >= 13.0)
	var decor: int = world.decoration_count
	assert(decor > 0)
	var structures: int = 0
	for child in world.get_children():
		if child is MultiMeshInstance3D:
			structures += 1
	assert(structures > 0, "A genuine batched 3D world is emitted")
	world.queue_free()
	await process_frame
	await process_frame
	return {"height": cut, "decor": decor, "batches": structures}


func _run() -> void:
	var low: Dictionary = await _test_profile(true)
	var high: Dictionary = await _test_profile(false)
	assert(is_equal_approx(float(low.height), float(high.height)),
		"Changing the graphical tier cannot change terrain geography")
	assert(int(high.decor) > int(low.decor),
		"Higher visual tier must add decoration without changing physics")
	print("[CrystalGorge] PASS: carved depth, open physics gap, tiered batched geology")
	quit(0)
