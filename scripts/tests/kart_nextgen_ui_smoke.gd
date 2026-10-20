extends SceneTree
## Non-destructive smoke test for the REAL Godot game hub and reusable 3D UI.
## Execute with Godot 4.6.3: godot --headless --path . --script res://scripts/tests/kart_nextgen_ui_smoke.gd
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
	var hub := load("res://scenes/games/game_hub.tscn").instantiate()
	root.add_child(hub)
	await process_frame
	assert(hub.find_child("OriginalAnimatedLumo", true, false) != null,
		"Original 3D Lumo character missing from the new hub")
	for id in ["kart", "jump", "stars"]:
		var button := hub.find_child("GameRoute_" + id, true, false) as Button
		assert(button != null, "Missing real game launch for: " + id)
		assert(not button.disabled, "Game route unexpectedly disabled: " + id)
		assert(button.custom_minimum_size.y >= 48.0, "Touch target too small: " + id)
	assert(hub.find_child("GradeChoice", true, false) is OptionButton,
		"Existing grade selector not preserved")
	assert(hub.find_child("SubjectChoice", true, false) is OptionButton,
		"Existing subject selector not preserved")
	assert(hub.find_child("ReturnToHome", true, false) is Button,
		"Navigation back to Home missing")
	hub.queue_free()
	print("[KartNextGenUI] PASS: live fox, real routes, grade/subject, contrast and touch targets")
	quit(0)
