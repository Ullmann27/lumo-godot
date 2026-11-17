extends SceneTree
## Non-destructive smoke test for the REAL Godot game hub and reusable 3D UI.
## Run headless with Godot 4.6.3 and --script res://scripts/tests/kart_nextgen_ui_smoke.gd
const UI = preload("res://scripts/games/kart_ui_theme.gd")
# Scenes with autoload-backed scripts must be loaded after project initialization.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var pane := UI.premium_panel(UI.CYAN, true)
	assert(pane is StyleBoxFlat and pane.border_width_left >= 2, "Premium card border missing")
	var preview := UI.premium_panel(UI.GOLD)
	assert(preview.bg_color.r < 0.20, "Premium UI unexpectedly became a light card")
	var hub: Node3D = (
		(load("res://scenes/games/game_hub.tscn") as PackedScene).instantiate() as Node3D
	)
	root.add_child(hub)
	for frame in range(12):
		await process_frame
	assert(
		hub.find_child("OriginalAnimatedLumo", true, false) != null,
		"Original 3D Lumo character missing from the new hub"
	)
	for id in ["kart", "jump", "stars"]:
		var button := hub.find_child("GameRoute_" + id, true, false) as Button
		assert(button != null, "Missing real game launch for: " + id)
		assert(not button.disabled, "Game route unexpectedly disabled: " + id)
		assert(button.custom_minimum_size.y >= 48.0, "Touch target too small: " + id)
	for pixels in [Vector2i(640, 360), Vector2i(320, 740), Vector2i(690, 829), Vector2i(1280, 720)]:
		root.size = pixels
		for frame in range(12):
			await process_frame
		var actions := hub.find_child("ScrollableRealGameActions", true, false) as ScrollContainer
		assert(
			actions != null and actions.size.y >= 48.0,
			"Real game routes are clipped by a collapsed scroll area"
		)
		for id in ["kart", "jump", "stars"]:
			var route := hub.find_child("GameRoute_" + id, true, false) as Button
			actions.ensure_control_visible(route)
			for frame in range(4):
				await process_frame
			assert(
				actions.get_global_rect().grow(1).encloses(route.get_global_rect()),
				"Real game route must be visible inside its scroll viewport: " + id
			)
			assert(
				root.get_visible_rect().grow(1).encloses(route.get_global_rect()),
				"Real game route must remain on screen: " + id
			)
	assert(
		hub.find_child("GradeChoice", true, false) is OptionButton,
		"Existing grade selector not preserved"
	)
	assert(
		hub.find_child("SubjectChoice", true, false) is OptionButton,
		"Existing subject selector not preserved"
	)
	assert(hub.find_child("ReturnToHome", true, false) is Button, "Navigation back to Home missing")
	hub.queue_free()
	print(
		"[KartNextGenUI] PASS: live fox, visible scrollable routes, grade/subject and touch targets"
	)
	quit(0)
