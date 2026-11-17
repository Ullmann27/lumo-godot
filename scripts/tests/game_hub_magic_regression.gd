extends SceneTree
## Native user-visible navigation contract. The baseline with three routes fails.
const REQUIRED := [
	"kart", "settlement", "jump", "puzzle", "treasure", "rhythm", "build", "stars"
]
const IDENTITY = preload("res://scripts/tests/helpers/game_hub_original_identity.gd")


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
	var identity: Dictionary = IDENTITY.inspect(hub)
	for reason in identity.failures:
		failed.append(str(reason))
	if identity.failures.is_empty():
		var actor: Node = hub.find_child("OriginalAnimatedLumo", true, false)
		var player := actor.get("player") as AnimationPlayer
		if actor.get("reduced_motion") != true or player.is_playing():
			failed.append("Reduced motion must freeze the original rig animation")
		var initial_time := player.current_animation_position
		await create_timer(0.05).timeout
		if not is_equal_approx(player.current_animation_position, initial_time):
			failed.append("Reduced motion advanced the original animation clock")
		actor.call("set_reduced_motion", false)
		if not player.is_playing():
			failed.append("The original idle must animate when motion is enabled")
		hub.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
		if player.is_playing() or actor.get("suspended") != true:
			failed.append("Application pause must suspend the real original rig")
		hub.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
		if not player.is_playing() or actor.get("suspended") != false:
			failed.append("Application resume must restore the original idle")
		actor.call("set_reduced_motion", true)
		hub.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
		hub.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
		if player.is_playing():
			failed.append("Resume must preserve the child's reduced-motion preference")
		print("[LumoHubIdentity] ", JSON.stringify(identity))
	var grid := hub.find_child("LiveGameRoutes", true, false) as GridContainer
	if grid == null:
		failed.append("Game portal controls are not a responsive GridContainer")
	else:
		# Headless root viewport sizes differ from requested phone emulation.
		# Test the actual responsive decision function at three known dp widths.
		if grid.columns < 1 or grid.columns > 3:
			failed.append("Hub grid must keep one to three usable columns")
		for scenario in [
			{"width": 420.0, "columns": 1},
			{"width": 900.0, "columns": 2},
			{"width": 1350.0, "columns": 3},
		]:
			if int(hub.call("_columns_for_width", scenario.width)) != int(scenario.columns):
				failed.append("Wrong responsive card layout at %s dp" % scenario.width)
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
