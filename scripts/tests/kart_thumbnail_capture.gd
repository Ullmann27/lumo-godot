extends SceneTree
## Echte Engine-Vorschaubilder aller Karts (Dreiviertelansicht von vorn, ohne Fahrer, transparenter
## Hintergrund, weicher Schatten) für die Auswahlkarten. Keine Bildbearbeitung außer Zuschneiden.
## Aufruf: godot --rendering-method gl_compatibility --script scripts/tests/kart_thumbnail_capture.gd -- <ordner> [id1,id2,...] [--with-driver]
const FLEET = preload("res://scripts/games/kart_fleet.gd")
const STAGE = preload("res://scripts/games/kart_stage.gd")
const CATALOG = preload("res://scripts/games/kart_catalog.gd")
const RENDER := Vector2i(1280, 960)
const OUTPUT := Vector2i(512, 384)

var viewport: SubViewport
var kart: Node3D
var camera: Camera3D
var ids: Array = []
var index: int = 0
var wait: int = 0
var out_dir: String = "res://exports/screenshots/fleet"
var with_driver: bool = false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var positional: Array = []
	for arg in args:
		if arg == "--with-driver":
			with_driver = true
		else:
			positional.append(arg)
	if positional.size() > 0:
		out_dir = positional[0]
	if positional.size() > 1:
		ids = Array(str(positional[1]).split(","))
	else:
		ids = FLEET.ids()
	viewport = SubViewport.new()
	viewport.size = RENDER
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var built: Dictionary = STAGE.build(world, Color("45d9ef"), false)
	(built.camera as Camera3D).queue_free()
	# Etwas heller und kontrastreicher als die Garage: Die kleinen Karten brauchen Kontur.
	var settings: Environment = (world.get_child(0) as WorldEnvironment).environment
	settings.adjustment_enabled = true
	settings.adjustment_brightness = 1.28
	settings.adjustment_contrast = 1.10
	settings.adjustment_saturation = 1.12
	# Weicher Schatten als dunkle Scheibe mit Farbverlauf nach außen.
	var shadow := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(4.2, 4.2)
	quad.orientation = PlaneMesh.FACE_Y
	shadow.mesh = quad
	shadow.position.y = 0.01
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0, 0.02, 0.06, 0.62))
	gradient.set_color(1, Color(0, 0.02, 0.06, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 128
	texture.height = 128
	var shadow_material := StandardMaterial3D.new()
	shadow_material.albedo_texture = texture
	shadow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow.material_override = shadow_material
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(shadow)
	camera = Camera3D.new()
	camera.fov = 30
	world.add_child(camera)
	camera.current = true
	kart = Node3D.new()
	kart.set_script(load("res://scripts/games/kart_vehicle.gd"))
	world.add_child(kart)
	DirAccess.make_dir_recursive_absolute(out_dir)
	_place()


func _place() -> void:
	var driver: Dictionary = CATALOG.entry(CATALOG.DRIVERS, "fox")
	kart.call("configure", "fox", driver.color, str(ids[index]))
	kart.call("set_motion", 0.0, 0.0, false, false)
	if not with_driver and kart.get("driver") != null:
		(kart.get("driver") as Node3D).hide()
	camera.look_at_from_position(Vector3(-3.6, 1.9, -4.7), Vector3(0, 0.55, 0.05))
	wait = 0


func _process(_delta: float) -> bool:
	wait += 1
	if wait < 22:
		return false
	var shot: Image = viewport.get_texture().get_image()
	shot.convert(Image.FORMAT_RGBA8)
	# Schatten zählt nicht zum Zuschnitt: nur deutlich deckende Pixel (Alpha > 0,35).
	var left: int = shot.get_width()
	var right: int = 0
	var top: int = shot.get_height()
	var bottom: int = 0
	for y in range(0, shot.get_height(), 2):
		for x in range(0, shot.get_width(), 2):
			if shot.get_pixel(x, y).a > 0.35:
				left = mini(left, x)
				right = maxi(right, x)
				top = mini(top, y)
				bottom = maxi(bottom, y)
	var bounds := Rect2i(left, top, maxi(20, right - left), maxi(20, bottom - top))
	# Auf 4:3 mit etwas Rand zuschneiden, Schwerpunkt mittig.
	var margin: int = 26
	var width: int = bounds.size.x + margin * 2
	var height: int = bounds.size.y + margin * 2
	if float(width) / float(height) > float(OUTPUT.x) / float(OUTPUT.y):
		height = roundi(float(width) * float(OUTPUT.y) / float(OUTPUT.x))
	else:
		width = roundi(float(height) * float(OUTPUT.x) / float(OUTPUT.y))
	var center: Vector2i = bounds.position + bounds.size / 2
	var crop := Rect2i(center.x - width / 2, center.y - height / 2, width, height)
	var canvas := Image.create(width, height, false, Image.FORMAT_RGBA8)
	canvas.blit_rect(shot, Rect2i(Vector2i.ZERO, shot.get_size()), Vector2i(-crop.position.x, -crop.position.y))
	canvas.resize(OUTPUT.x, OUTPUT.y, Image.INTERPOLATE_LANCZOS)
	var path: String = "%s/%s.png" % [out_dir, ids[index]]
	assert(canvas.save_png(path) == OK)
	index += 1
	if index >= ids.size():
		print("[KartThumbnails] PASS: ", out_dir, " ", ids)
		quit(0)
		return true
	_place()
	return false
