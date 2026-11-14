extends SceneTree
## Native user-visible navigation contract. The baseline with three routes fails.
const REQUIRED := [
	"kart", "settlement", "jump", "puzzle", "treasure", "rhythm", "build", "stars"
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failed: Array[String] = []
	var router: Node = root.get_node("SceneRouter")
	var before := {
		"childKey": "game-hub-regression",
		"buildSlot": 2,
		"grade": 3,
		"subject": "Deutsch",
		"reduceAnimations": true,
	}
	router.set("launch_options", before.duplicate(true))
	root.size = Vector2i(420, 900)
	var hub: Node3D = load("res://scenes/games/game_hub.tscn").instantiate()
	root.add_child(hub)
	await process_frame
	await process_frame
	var grid := hub.find_child("LiveGameRoutes", true, false) as GridContainer
	if grid == null:
		failed.append("Game portal controls are not a responsive GridContainer")
	else:
		# Headless Godot's root window may not honor our requested 420px size.
		# Compare the actual viewport and physical pixel density rather than
		# asserting a simulated phone size we did not actually obtain.
		var width_dp: float = hub.get_viewport().get_visible_rect().size.x / maxf(
			1.0, MobileRuntime.get_ui_density()
		)
		var expected_columns := 3 if width_dp >= 1120 else (2 if width_dp >= 650 else 1)
		if grid.columns != expected_columns:
			failed.append("Hub uses incorrect card columns for current viewport")
	for route in REQUIRED:
		var button := hub.find_child("GameRoute_" + route, true, false) as Button
		if button == null:
			failed.append("The child cannot directly open " + route)
		elif button.custom_minimum_size.y < 48.0:
			failed.append("Touch target is smaller than 48 px: " + route)
	var stage: Node = hub.find_child("LumoDreamStage", true, false)
	if stage == null:
		failed.append("There is no actual 3D dream stage")
	else:
		if stage.get("reduced_motion") != true:
			failed.append("Reduced-motion mode must freeze decoration")
		if stage.find_child("LumoDreamPortalRing", true, false) == null:
			failed.append("3D portal arch missing")
		var fireflies := stage.find_child("LumoDreamFireflies", true, false) as MultiMeshInstance3D
		if fireflies == null or fireflies.multimesh == null:
			failed.append("Real instanced 3D fireflies are missing")
		elif fireflies.multimesh.instance_count < 12:
			failed.append("3D portal has too few actual light instances")
	var village := hub.find_child("GameRoute_settlement", true, false) as Button
	if village != null:
		village.pressed.emit()
		var after: Dictionary = router.get("launch_options")
		if after.get("livingVillage", false) != true:
			failed.append("Village route does not enable economic play")
		if after.get("settlementMode") != "settlement":
			failed.append("Village route lost the settlement mode")
		for key in ["childKey", "buildSlot", "grade", "subject", "reduceAnimations"]:
			if after.get(key) != before[key]:
				failed.append("Village route corrupted original launch option " + key)
	hub.queue_free()
	if not failed.is_empty():
		for reason in failed:
			printerr("[LumoHub] FAIL " + reason)
		quit(1)
		return
	print("[LumoHub] PASS 8 visible native game entrances, active village route, preserved child settings and 3D reduced-motion portal")
	quit(0)
