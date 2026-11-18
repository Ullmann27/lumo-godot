extends Node3D
## Backdrop of the course selection: the Lumo world artwork with the live,
## greeting fox in front of it. Freed as soon as a course is built.

const RIG = preload("res://scripts/characters/lumo/lumo_rigged_actor.gd")
const MENU_ART = preload("res://scripts/games/kart_menu_art.gd")
const LUMO_HEIGHT: float = 2.2
const LUMO_WIDTH: float = 1.9

var lumo
var camera: Camera3D
var reduced_motion: bool = false
var _wave: float = 1.2


func setup(calm: bool) -> void:
	reduced_motion = calm
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CANVAS
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("9acbff")
	environment.ambient_light_energy = 0.8
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	var layer := CanvasLayer.new()
	layer.layer = -1
	add_child(layer)
	var art := TextureRect.new()
	art.name = "Backdrop"
	art.texture = MENU_ART.world_texture()
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(art)
	var veil := ColorRect.new()
	veil.color = Color(0.01, 0.06, 0.17, 0.6)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(veil)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -26, 0)
	sun.light_color = Color("fff1d8")
	sun.light_energy = 1.15
	add_child(sun)
	camera = Camera3D.new()
	camera.fov = 40.0
	camera.near = 0.05
	add_child(camera)
	camera.current = true
	lumo = RIG.new()
	lumo.name = "MenuLumo"
	add_child(lumo)
	if not lumo.is_usable():
		lumo.hide()
		return
	var skeleton: Skeleton3D = lumo.skeleton
	var lowest: float = INF
	var highest: float = -INF
	for bone in range(skeleton.get_bone_count()):
		var y: float = skeleton.get_bone_global_rest(bone).origin.y
		lowest = minf(lowest, y)
		highest = maxf(highest, y)
	var scaled: float = 1.75 / maxf(0.2, highest - lowest)
	lumo.scale = Vector3.ONE * scaled
	lumo.position.y = -lowest * scaled
	lumo.rotation.y = -0.25
	lumo.set_reduced_motion(calm)


## Pans and pulls the camera so Lumo stands inside `rect` (viewport units).
func frame(rect: Rect2) -> void:
	if not is_instance_valid(camera) or not is_inside_tree():
		return
	var view: Vector2 = get_viewport().get_visible_rect().size
	if rect.size.x < 8.0 or rect.size.y < 8.0 or view.y <= 0.0:
		if is_instance_valid(lumo):
			lumo.visible = false
		return
	if is_instance_valid(lumo):
		lumo.visible = lumo.is_usable()
	var half: float = tan(deg_to_rad(camera.fov) * 0.5)
	var by_height: float = LUMO_HEIGHT * view.y / (rect.size.y * 2.0 * half)
	var by_width: float = LUMO_WIDTH * view.x / (rect.size.x * 2.0 * half * (view.x / view.y))
	var distance: float = maxf(by_height, by_width)
	var per_unit: float = 2.0 * distance * half / view.y
	var shift: Vector2 = rect.get_center() - view * 0.5
	camera.position = Vector3(-shift.x * per_unit, LUMO_HEIGHT * 0.48 + shift.y * per_unit, distance)
	camera.rotation = Vector3.ZERO


func _process(delta: float) -> void:
	if reduced_motion or not is_instance_valid(lumo) or not lumo.is_usable():
		return
	_wave -= delta
	if _wave <= 0.0:
		_wave = 6.5
		lumo.play_behavior("greeting_wave")
