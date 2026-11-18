extends SceneTree
## Item-Anzeige im Rennen (Auftrag kart-garage, Teil 3) in ihren Zuständen, isoliert über
## einem Rennbild: Suchen, Erfassen mit Entfernungsbalken, Eingerastet (Aufblitzen),
## Raketenhalter nach einer Salve, Schild-Ring + Warnung von hinten. 1600x720 und 720x1600.
## Aufruf: godot --path . --rendering-method gl_compatibility --script
##   res://scripts/tests/kart_item_hud_capture.gd -- <out_dir>

const ITEM_HUD = preload("res://scripts/games/kart_items/kart_item_hud.gd")
const BACKDROP := "res://evidence/lumo_kart_runtime/review/zauberwald_inside.png"

var out_dir := "user://kart_item_hud"


func _initialize() -> void:
	call_deferred("_run")


func _settle(frames: int = 4) -> void:
	for _i in range(frames):
		await process_frame
	await RenderingServer.frame_post_draw


func _state(phase: String, lock: float, charges: int, extra: Dictionary = {}) -> Dictionary:
	var state := {
		"phase": phase, "item": "star_rocket", "charges": charges, "item_color": "#ff6b8b", "roulette": 0.0,
		"has_target": lock >= 0.0, "target": 2 if lock >= 0.0 else -99, "target_world": Vector3(1.6, 0.9, -14.0),
		"target_name": "Milo", "lock": maxf(lock, 0.0), "rearm": 0.0, "popups": [], "warning": 0.0,
		"incoming": false, "shield_ready": false, "shield_left": 0.0, "shield_total": 6.0, "hint": "",
		"item_rect": Rect2(), "target_distance": 30.0, "lock_range": 65.0,
	}
	state.merge(extra, true)
	return state


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	var world := Node3D.new()
	root.add_child(world)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.current = true
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var backdrop := TextureRect.new()
	backdrop.texture = load(BACKDROP)
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(backdrop)
	var hud: Control = ITEM_HUD.new()
	hud.camera = camera
	layer.add_child(hud)
	var shots: Array = [
		["01_search", _state("armed", -1.0, 2), false],
		["02_acquire", _state("armed", 0.45, 2, {"target_distance": 42.0}), false],
		["03_locked_flash", _state("armed", 1.0, 2, {"target_distance": 18.0}), false],
		["04_after_salvo", _state("armed", 1.0, 1, {"target_distance": 12.0}), false],
		["05_shield_warning", _state("", -1.0, 0, {"item": "shield", "shield_left": 3.7, "warning": 1.0, "incoming": true}), false],
		["06_locked_reduced_motion", _state("armed", 1.0, 2, {"target_distance": 18.0}), true],
	]
	for orientation in [Vector2i(1600, 720), Vector2i(720, 1600)]:
		root.size = orientation
		hud.size = Vector2(orientation)
		for shot in shots:
			hud.reduced_motion = bool(shot[2])
			# Erst einen Zustand davor zeigen, damit der Wechsel auf „eingerastet“ den
			# einmaligen Lichtring wirklich auslöst (wie im Rennen).
			hud.push_state(_state("armed", 0.9, 2), 0.016)
			for _k in range(6):
				hud.push_state(shot[1], 0.016)
			await _settle()
			var path := "%s/item_hud_%s_%dx%d.png" % [out_dir, shot[0], orientation.x, orientation.y]
			root.get_texture().get_image().save_png(path)
			print("[ItemHudCapture] ", path, " stage=", hud.lock_stage(), " pods=", hud.pod_rockets_loaded(), " range=", hud.range_fill())
	quit(0)
