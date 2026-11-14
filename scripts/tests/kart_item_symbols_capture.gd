extends SceneTree
## A staged Godot framebuffer capture of the exact game symbol builders.
## This is a geometry/material showcase, not evidence of earning an item.
## Usage: godot --rendering-method gl_compatibility --script
## scripts/tests/kart_item_symbols_capture.gd -- /absolute/output/directory

const SYMBOLS = preload("res://scripts/games/kart_item_symbols.gd")
const RESONANCE = preload("res://scripts/games/kart_resonance_system.gd")
var stage: Node3D
var out_dir: String = "res://exports/item-symbols"


func _initialize() -> void:
	call_deferred("_run")


func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material


func _capture(name: String) -> void:
	for _frame in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	var frame: Image = root.get_texture().get_image()
	assert(frame.get_size() == Vector2i(1280, 720))
	assert(frame.save_png(out_dir.path_join(name + ".png")) == OK)
	print("[KartItemSymbolsCapture] saved ", out_dir.path_join(name + ".png"))


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	root.msaa_3d = Viewport.MSAA_4X
	stage = Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("0c1d2c")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("b8d5e8")
	settings.ambient_light_energy = 0.65
	environment.environment = settings
	stage.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -25, 0)
	light.light_color = Color("ffeacb")
	light.light_energy = 1.3
	stage.add_child(light)
	var fill := OmniLight3D.new()
	fill.position = Vector3(5, 4, 3)
	fill.omni_range = 18.0
	fill.light_energy = 2.2
	fill.light_color = Color("a5d7ff")
	stage.add_child(fill)
	var floor_node := MeshInstance3D.new()
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(80, 80)
	floor_node.mesh = floor_mesh
	floor_node.material_override = _material(Color("122b3e"), 0.12, 0.6)
	stage.add_child(floor_node)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 4.3, 11.0)
	camera.fov = 43.0
	stage.add_child(camera)
	camera.look_at(Vector3(0, 1.8, 0))
	camera.current = true
	var display := Node3D.new()
	stage.add_child(display)
	var captions := CanvasLayer.new()
	stage.add_child(captions)
	for index in range(SYMBOLS.KINDS.size()):
		var kind: String = SYMBOLS.KINDS[index]
		var x: float = (float(index) - 1.0) * 3.35
		var pedestal := MeshInstance3D.new()
		var pedestal_mesh := CylinderMesh.new()
		pedestal_mesh.top_radius = 1.25
		pedestal_mesh.bottom_radius = 1.35
		pedestal_mesh.height = 0.3
		pedestal_mesh.radial_segments = 48
		pedestal.mesh = pedestal_mesh
		pedestal.position = Vector3(x, 0.16, 0)
		pedestal.material_override = _material(Color("24495d"), 0.4, 0.3)
		display.add_child(pedestal)
		var symbol: Node3D = SYMBOLS.build(kind)
		symbol.position = Vector3(x, 1.95, 0)
		symbol.scale = Vector3.ONE * 1.65
		display.add_child(symbol)
		SYMBOLS.advance(symbol, 0.9 + float(index) * 0.4)
		var title := Label.new()
		title.text = str(SYMBOLS.TITLES[kind])
		title.position = Vector2(210.0 + float(index) * 290.0, 540.0)
		title.size = Vector2(280.0, 40.0)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 28)
		title.add_theme_color_override("font_color", SYMBOLS.COLORS[kind])
		captions.add_child(title)
		var meaning := Label.new()
		meaning.text = str(SYMBOLS.MEANINGS[kind])
		meaning.position = title.position + Vector2(0.0, 45.0)
		meaning.size = Vector2(280.0, 70.0)
		meaning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		meaning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		meaning.add_theme_font_size_override("font_size", 20)
		meaning.add_theme_color_override("font_color", Color("e8f3ff"))
		captions.add_child(meaning)
	await _capture("01_solid_item_symbols")
	display.visible = false
	captions.hide()
	var gate: Node3D = RESONANCE.build_ring(stage, Transform3D(Basis.IDENTITY, Vector3(0, 1.95, 0)))
	RESONANCE.advance_ring(gate, 1.25)
	camera.position = Vector3(5.0, 4.5, 10.0)
	camera.look_at(Vector3(0.0, 2.0, 0.0))
	await _capture("02_universal_skill_gate")
	gate.visible = false
	# The same actual product driver and FX used by kart_island: the tall rabbit
	# is the clearance case, shown at the lowest point of the symbol's bob.
	var vehicle = load("res://scripts/games/kart_vehicle.gd").new()
	vehicle.configure("rabbit", Color("b5b3ff"), "glider")
	vehicle.reduced_motion = true
	stage.add_child(vehicle)
	vehicle.set_process(false)
	vehicle.set_motion(0.0, 0.0, false, false)
	var fx = load("res://scripts/games/kart_rival_item_fx.gd").new()
	vehicle.add_child(fx)
	fx.advance(PI * 0.75, false, false)
	var face_light := DirectionalLight3D.new()
	face_light.rotation_degrees = Vector3(-25, 155, 0)
	face_light.light_color = Color("d3e8ff")
	face_light.light_energy = 0.7
	stage.add_child(face_light)
	camera.position = Vector3(4.5, 3.6, -7.2)
	camera.fov = 38.0
	camera.look_at(Vector3(0.0, 1.8, 0.0))
	var attachment_title := Label.new()
	attachment_title.position = Vector2(240, 650)
	attachment_title.size = Vector2(800, 45)
	attachment_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	attachment_title.add_theme_font_size_override("font_size", 26)
	var attachment_ui := CanvasLayer.new()
	stage.add_child(attachment_ui)
	attachment_ui.add_child(attachment_title)
	for kind in SYMBOLS.KINDS:
		fx.set_item(kind)
		attachment_title.text = "Nova · " + str(SYMBOLS.TITLES[kind])
		attachment_title.add_theme_color_override("font_color", SYMBOLS.COLORS[kind])
		await _capture("03_rabbit_held_" + kind)
	stage.queue_free()
	for _frame in range(6):
		await process_frame
	await create_timer(0.3).timeout
	print("[KartItemSymbolsCapture] PASS: actual Godot symbols, universal gate and rabbit attachments at 1280x720")
	quit(0)
