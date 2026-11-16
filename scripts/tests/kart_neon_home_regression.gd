extends SceneTree
## Runtime regression for native clickable LUMO Kart neon screen.
const HUB = preload("res://scripts/games/kart_neon_hub.gd")
const ARENA = preload("res://scripts/games/kart_neon_arena.gd")
var checks := 0
var failures: Array[String] = []
var routes: Array[String] = []
var rotations: Array[float] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)

func _run() -> void:
	var hub = HUB.new()
	hub.total_stars = 17
	hub.current_mode = "race"
	hub.mode_selected.connect(func(route: String): routes.append(route))
	hub.preview_rotate_requested.connect(func(angle: float): rotations.append(angle))
	root.add_child(hub)
	await process_frame
	hub.size = Vector2(1280, 720)
	await process_frame
	_check(hub._highlight != null and hub._highlight.is_visible_in_tree(), "real native featured track panel")
	_check(hub._track_buttons.size() == 4, "four source-backed playable tracks")
	for id in ["volcano_night", "jungle_emerald_3600", "desert_drift", "sonnenhafen"]:
		_check(hub._track_buttons.has(id), "track exists in current real catalog: " + id)
		_check(ResourceLoader.exists("res://assets/kart/neon_previews/" + id + ".webp", "Texture2D"),
			"actual engine artwork: " + id)
	hub._track_buttons["jungle_emerald_3600"].pressed.emit()
	_check(hub._featured_track == "jungle_emerald_3600", "track preview responds to actual tap")
	hub._highlight_pick.pressed.emit()
	_check(routes == ["jungle_emerald_3600", "world"], "selecting Dschungelherz navigates into real track chooser")
	hub._rotation_left.pressed.emit()
	hub._rotation_right.pressed.emit()
	_check(rotations.size() == 2 and is_equal_approx(rotations[0] + rotations[1], 0),
		"turntable touch emits balanced left and right 3D rotations")
	_check(hub._navigation.get_child_count() == 9, "nine working bottom navigation entries")
	_check(hub._progress_label.text.contains("17"), "season banner uses real star source, not fake XP")
	var arena = ARENA.new()
	root.add_child(arena)
	arena.build()
	arena.set_active(true, false)
	arena.advance(1.0 / 60.0)
	_check(arena.elapsed > 0 and arena.get_node_or_null("KartTurntable") != null,
		"real live neon 3D showroom animation and wheel platform")
	_check(arena.find_children("*", "CollisionObject3D", true, false).is_empty(),
		"new showroom cannot alter race physics")
	arena.free()
	hub.free()
	print("[NeonHome] ", JSON.stringify({"checks": checks, "failures": failures, "status": "PASS" if failures.is_empty() else "FAIL"}))
	quit(0 if failures.is_empty() else 1)
