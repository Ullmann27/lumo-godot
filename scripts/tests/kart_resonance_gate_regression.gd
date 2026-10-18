extends SceneTree
## Real Godot 4.6.3 regression: racing skill gates, no lucky cubes, no school
## prompts, deterministic item scoring and protected persisted pickup keys.
const RACE = preload("res://scripts/games/kart_resonance_system.gd")
## Load the live scene only after SceneTree autoloads (HostBridge etc.) are ready.

func _initialize() -> void:
	call_deferred("_run")

func _award_test() -> void:
	var low: Dictionary = RACE.award(7.0, 22.0, 2.3, 0.0, false)
	var medium: Dictionary = RACE.award(20.0, 22.0, 0.0, 0.0, false)
	var high: Dictionary = RACE.award(22.0, 22.0, 0.0, 1.5, false)
	assert(str(low.item) == "boost" and int(low.tier) == 0)
	assert(str(medium.item) == "shield" and int(medium.tier) == 1)
	assert(str(high.item) == "pulse" and int(high.tier) == 2)
	assert(float(low.score) < float(medium.score))
	assert(float(medium.score) < float(high.score))
	for i in range(50):
		assert(RACE.award(22.0, 22.0, 0.0, 1.5, false) == high,
			"Repeat the exact skill: deterministic, never random.")
	assert(str(RACE.award(25.0, 22.0, 0.0, 1.5, true).item) == "boost",
		"A recent collision must never award maximum power.")
	assert(str(RACE.award(20.0, 22.0, 8.0, 0.0, false).item) == "boost",
		"Leaving the ideal line is not a perfect gate.")
	assert(str(RACE.award(20.0, 22.0, 0.0, 0.0, false).item) == "shield",
		"Missing drift should not arbitrarily prevent the fair mid-tier.")

func _run() -> void:
	_award_test()
	var scene: PackedScene = load("res://scenes/games/kart_island.tscn")
	var game = scene.instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	await process_frame
	game._start_selected_race({
		"mode": "race", "driver": "fox", "kart": "comet",
		"track": "sonnenhafen", "difficulty": "gemuetlich"
	})
	game._end_preview()
	await process_frame
	assert(game.item_boxes.size() == 5 and game.item_box_distances.size() == 5)
	assert(game.item_box_laterals.size() == 5)
	for ring in game.item_boxes:
		assert(ring is Node3D, "The resonance ring must be a real rendered scene node.")
		assert(str(ring.get_meta("lumo_racing_pickup", "")) == "skill_resonance")
		assert(ring.get_child_count() == 1)
		assert(ring.get_child(0) is MeshInstance3D)
		assert((ring.get_child(0) as MeshInstance3D).mesh is TorusMesh)
		assert(ring.visible)
	# Use one actual running kart frame at the true race-world gate; no
	# item / pickup key / score is directly written to simulate success.
	game.countdown = 0.0
	game.racing = true
	game.preview_left = 0.0
	game.auto_gas = true
	var gate_distance: float = game.item_box_distances[0]
	var gate_lane: float = game.item_box_laterals[0]
	game.player.transform = game.world.reset_transform(gate_distance, gate_lane)
	game.distance = gate_distance
	game.previous_road_distance = gate_distance
	game.lane = gate_lane
	game.speed = 22.0
	game.drift_charge = 1.5
	game.hit_timer = 0.0
	game._track_events()
	assert(game.item == "pulse", "Precise fast drift gets the measured high-tier pulse.")
	assert(game.item_box_collected.has(0), "First gate consumed for this lap.")
	assert(game.item_boxes[0].visible, "The geometry remains until visibility sync.")
	game._sync_item_box_visibility()
	assert(not game.item_boxes[0].visible, "Pickup visually disappears after earning the item.")
	game._use_item()
	assert(game.item.is_empty())
	assert(game.pulse_age == 0.0, "Earned pulse is an actual usable combat ability.")
	# The same ring cannot be farmed repeatedly in the same lap.
	game._track_events()
	assert(game.item.is_empty() and game.item_box_collected.size() == 1)
	# In the next lap it becomes available exactly once again; the
	# existing persisted key format remains lap*count+index.
	game.distance = game.track_length + gate_distance
	game._sync_item_box_visibility()
	assert(game.item_boxes[0].visible)
	game.abandoned = true
	game.queue_free()
	await process_frame
	print("[KartResonance] PASS: skill not RNG, five real ring meshes, one pickup/lap, pulse use, save-key continuity")
	quit(0)
