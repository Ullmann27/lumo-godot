extends SceneTree
## Fixed camera, lighting and authored pose for before/after inspection of the real driver.
## Each PNG is the untouched viewport image. The manifest binds it to the source file hashes.
const VEHICLE = preload("res://scripts/games/kart_vehicle.gd")
const STAGE = preload("res://scripts/games/kart_stage.gd")
const SIZE := Vector2i(960, 960)
const SOURCES := [
	"scripts/games/kart_vehicle.gd",
	"scripts/games/kart_character_finish.gd",
	"scripts/games/kart_fur_geometry.gd",
	"scripts/games/kart_stage.gd",
	"scripts/tests/kart_fox_cheek_capture.gd",
]

var out_dir: String = "res://exports/fox-cheek-review/captures"
var kart: LumoRaceKart
var camera: Camera3D
var captures: Array[Dictionary] = []


func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	if not arguments.is_empty():
		out_dir = arguments[0]
	call_deferred("_run")


func _frames(count: int) -> void:
	for frame in range(count):
		await process_frame
	await RenderingServer.frame_post_draw


func _capture(name: String, offset: Vector3, speech: float = 0.0) -> void:
	kart.set_speaking(speech)
	kart._process(0.0)
	var aim: Vector3 = kart.head.global_position + Vector3(0, 0.12, 0)
	camera.look_at_from_position(aim + offset, aim)
	await _frames(6)
	var shot: Image = root.get_texture().get_image()
	var path: String = out_dir.path_join(name + ".png")
	assert(shot.get_size() == SIZE, "actual viewport must match the fixed capture size")
	assert(shot.save_png(path) == OK, "capture must save successfully")
	captures.append(
		{"file": name + ".png", "sha256": FileAccess.get_sha256(path), "speech": speech}
	)
	print("[FoxCheekCapture] ", name, " ", shot.get_size())


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Fox cheek capture needs a real display and GL renderer")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = SIZE
	root.content_scale_size = Vector2i.ZERO
	root.msaa_3d = Viewport.MSAA_4X
	var world := Node3D.new()
	root.add_child(world)
	var built: Dictionary = STAGE.build(world, Color("45d9ef"), false)
	# A hidden podium is not allocated; the shared stage owns only visible props.
	assert(built.podium == null)
	camera = built.camera
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.30
	camera.current = true
	# Use the existing production studio, with a solid background for reproducible PNGs.
	for child in world.get_children():
		if child is WorldEnvironment:
			child.environment.background_mode = Environment.BG_COLOR
			child.environment.background_color = Color("0b1f45")
	kart = VEHICLE.new()
	world.add_child(kart)
	kart.configure("fox", Color("1d4fa0"), "comet")
	kart.reduced_motion = true
	kart.set_motion(0.0, 0.0, false, false)
	kart.set_process(false)
	await _frames(12)
	await _capture("01-face-front", Vector3(0, 0, -4))
	await _capture("02-face-three-quarter", Vector3(-3, 0.15, -3))
	await _capture("03-face-side", Vector3(-4, 0, 0))
	await _capture("04-face-rear", Vector3(0, 0, 4))
	await _capture("05-speaking-front", Vector3(0, 0, -4), 0.75)
	await _capture("06-speaking-three-quarter", Vector3(-3, 0.15, -3), 0.75)
	var hashes: Dictionary = {}
	for path in SOURCES:
		hashes[path] = FileAccess.get_sha256("res://" + path)
	var evidence := FileAccess.open(out_dir.path_join("capture-manifest.json"), FileAccess.WRITE)
	(
		evidence
		. store_string(
			(
				JSON
				. stringify(
					{
						"engine": Engine.get_version_info().string,
						"display": DisplayServer.get_name(),
						"scope":
						"Actual fixed-pose desktop GL viewport captures, not device or frame-rate evidence",
						"size": [SIZE.x, SIZE.y],
						"sources": hashes,
						"captures": captures,
					},
					"  "
				)
			)
		)
	)
	evidence.close()
	world.queue_free()
	await _frames(2)
	print("[FoxCheekCapture] PASS: six fixed-pose native face views")
	quit(0)
