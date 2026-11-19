extends Control
## Tappable top-down mini overview for the Bauwelt HUD. The owner supplies
## world-space bounds, terrain bands and markers; a tap reports the matching
## world XZ position through `picked`, so the camera can jump there.

signal picked(world_xz: Vector2)

var world_rect := Rect2(-32, -32, 64, 64)
var bands: Array = []
var markers: Array = []
var view_center := Vector2.ZERO
var view_extent := 8.0
var _baked: ImageTexture
const BAKE := 128


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "Übersicht: tippe, um dorthin zu schauen."


## bands: [[Rect2 world, Color], ...]; markers: [[Vector2 world, Color, radius_px], ...]
func set_content(new_bands: Array, new_markers: Array) -> void:
	bands = new_bands
	markers = new_markers
	_bake()
	queue_redraw()


## Terrain and markers go into one texture so the overview costs a single
## batched draw regardless of how many parts the child has placed.
func _bake() -> void:
	var image := Image.create(BAKE, BAKE, false, Image.FORMAT_RGBA8)
	image.fill(Color("6fbf5a"))
	var scale := Vector2(BAKE, BAKE) / world_rect.size
	for band in bands:
		var rect: Rect2 = band[0]
		var pixels := Rect2i(
			Vector2i((rect.position - world_rect.position) * scale), Vector2i((rect.size * scale).ceil())
		)
		image.fill_rect(pixels.intersection(Rect2i(0, 0, BAKE, BAKE)), band[1])
	for marker in markers:
		var at := Vector2i((Vector2(marker[0]) - world_rect.position) * scale)
		var half := maxi(1, int(round(float(marker[2]) * 0.6)))
		var dot := Rect2i(at - Vector2i(half, half), Vector2i(half * 2, half * 2))
		image.fill_rect(dot.intersection(Rect2i(0, 0, BAKE, BAKE)), marker[1])
	if _baked == null:
		_baked = ImageTexture.create_from_image(image)
	else:
		_baked.update(image)


func set_view(center: Vector2, extent: float) -> void:
	if center.is_equal_approx(view_center) and is_equal_approx(extent, view_extent):
		return
	view_center = center
	view_extent = extent
	queue_redraw()


func _map_rect() -> Rect2:
	return Rect2(Vector2(6, 6), size - Vector2(12, 12))


func to_local_point(world: Vector2) -> Vector2:
	var area := _map_rect()
	var t := (world - world_rect.position) / world_rect.size
	return area.position + t * area.size


func to_world_point(local: Vector2) -> Vector2:
	var area := _map_rect()
	var t := ((local - area.position) / area.size).clamp(Vector2.ZERO, Vector2.ONE)
	return world_rect.position + t * world_rect.size


func _draw() -> void:
	if size.x < 24.0 or size.y < 24.0:
		return
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0.02, 0.09, 0.14, 0.82)
	frame.border_color = Color("64d7c8")
	frame.set_border_width_all(2)
	frame.set_corner_radius_all(16)
	draw_style_box(frame, Rect2(Vector2.ZERO, size))
	var area := _map_rect()
	if _baked != null:
		draw_texture_rect(_baked, area, false)
	var half := Vector2.ONE * view_extent
	var va := to_local_point(view_center - half)
	var vb := to_local_point(view_center + half)
	draw_rect(Rect2(va, vb - va).intersection(area.grow(2)), Color(1, 1, 1, 0.95), false, 2.0)


func _gui_input(event: InputEvent) -> void:
	var pressed := false
	var at := Vector2.ZERO
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pressed = true
		at = event.position
	elif event is InputEventScreenTouch and event.pressed:
		pressed = true
		at = event.position
	if pressed:
		picked.emit(to_world_point(at))
		accept_event()
