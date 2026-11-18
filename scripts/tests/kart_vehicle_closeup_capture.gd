extends SceneTree
## Nahaufnahmen der Fahrzeuge (Auftrag kart-garage, Teil 1): echtes LumoRaceKart mit Lumo,
## Schaustück-Detail, Lack je Design, Startnummer und Aufkleber, in der echten Garagen-Bühne
## (kart_stage.gd + kart_garage_interior.gd). Je Motiv 1600x720 und 720x1600.
## Aufruf: godot --path . --rendering-method gl_compatibility --script
##   res://scripts/tests/kart_vehicle_closeup_capture.gd -- <out_dir> [profile]

const STAGE = preload("res://scripts/games/kart_stage.gd")
const INTERIOR = preload("res://scripts/games/kart_garage_interior.gd")
const VEHICLE = preload("res://scripts/games/kart_vehicle.gd")
const FLEET = preload("res://scripts/games/kart_fleet.gd")

var out_dir: String = "user://kart_vehicle_closeups"
var profile: String = "high"
var camera: Camera3D
var stage: Node3D
var pivot: Node3D

## Motiv: Name, Kamera, Ziel, Blickwinkel (vertikal), Design.
const SHOTS: Array = [
	["comet_three_quarter", Vector3(2.6, 1.35, -2.9), Vector3(0, 0.5, 0), 34.0, "comet"],
	["comet_sidepod_number", Vector3(1.95, 0.72, 0.42), Vector3(0.62, 0.36, 0.0), 30.0, "comet"],
	["comet_wheel_brake", Vector3(1.85, 0.62, -1.45), Vector3(0.77, 0.36, -0.66), 30.0, "comet"],
	["comet_cockpit", Vector3(0.48, 1.42, 0.9), Vector3(0, 0.6, -0.15), 38.0, "comet"],
	["comet_rear_lamps", Vector3(0.9, 0.95, 2.35), Vector3(0, 0.55, 1.0), 32.0, "comet"],
	["phantom_pearl", Vector3(-2.5, 1.2, -2.6), Vector3(0, 0.5, 0), 36.0, "phantom"],
	["terra_matte", Vector3(2.6, 1.3, 2.4), Vector3(0, 0.5, 0), 36.0, "terra"],
	["gecko_velo_nose", Vector3(-0.9, 1.2, -2.5), Vector3(0, 0.35, -0.9), 32.0, "gecko_velo"],
]


func _initialize() -> void:
	call_deferred("_run")


func _settle(frames: int = 10) -> void:
	for _i in range(frames):
		await process_frame
	await RenderingServer.frame_post_draw


func _kart(design: String) -> Node3D:
	for child in pivot.get_children():
		child.queue_free()
	await process_frame
	var kart = VEHICLE.new()
	kart.set_preview_detail(true)
	var look: Dictionary = FLEET.entry(design).get("look", {})
	kart.set_look(look)
	kart.configure("fox", Color("76d9ff"), design)
	kart.set_animated_lumo_enabled(true)
	kart.set_graphics_quality(profile)
	pivot.add_child(kart)
	return kart


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	if args.size() > 1:
		profile = args[1]
	DirAccess.make_dir_recursive_absolute(out_dir)
	stage = Node3D.new()
	root.add_child(stage)
	var built: Dictionary = STAGE.build(stage, Color("56e7ff"), false)
	for child in stage.get_children():
		if child is WorldEnvironment and child.environment:
			child.environment.background_mode = Environment.BG_COLOR
			child.environment.background_color = Color("071018")
			child.environment.ambient_light_color = Color("3d536d")
			child.environment.ambient_light_energy = 0.46
	INTERIOR.build(stage, built.pivot, profile)
	pivot = built.pivot
	camera = built.camera
	camera.current = true
	var report: Array = []
	var current := ""
	var kart: Node3D
	for shot in SHOTS:
		if str(shot[4]) != current:
			current = str(shot[4])
			kart = await _kart(current)
			await _settle(20)
		for orientation in [Vector2i(1600, 720), Vector2i(720, 1600)]:
			root.size = orientation
			camera.fov = float(shot[3]) * (1.0 if orientation.x > orientation.y else 1.9)
			camera.position = shot[1]
			camera.look_at(shot[2])
			await _settle(8)
			var image: Image = root.get_texture().get_image()
			var path := "%s/%s_%dx%d.png" % [out_dir, shot[0], orientation.x, orientation.y]
			image.save_png(path)
			print("[VehicleCloseup] ", path)
		var production = kart.get("production_vehicle")
		if production != null:
			report.append({"shot": shot[0], "design": current, "lod": production.lod_level,
				"showcase_meshes": production.showcase_mesh_count(), "dressing": production.dressing_nodes().size(),
				"finish": production._finish})
	print("[VehicleCloseup] REPORT ", JSON.stringify(report))
	quit(0)
