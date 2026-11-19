extends StyleBox
## StyleBox, die eine Platte des gerenderten UI-Kits im dp-Maßstab zeichnet. Damit bekommen
## auch gewöhnliche Buttons und Panels die Kit-Optik (StyleBoxTexture kann seine Ränder nicht
## skalieren). Instanzen kommen aus kart_ui3d.gd::themed().
var kit: GDScript
var plate := ""
var ui_scale := 1.0
var tint := Color.WHITE
## Deckende Farbe unter dem Glasfeld (für Overlays über unruhigem Grund); durchsichtig = aus.
var backing := Color(0, 0, 0, 0)
var _backing_size := Vector2.ZERO
var _backing_points := PackedVector2Array()
var _backing_colors := PackedColorArray()


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	if kit == null:
		return
	if backing.a > 0.0:
		if rect.size != _backing_size:
			_backing_size = rect.size
			_backing_points = kit.face_outline(plate, Rect2(Vector2.ZERO, rect.size), ui_scale, -1.0)
			_backing_colors = PackedColorArray([backing])
		RenderingServer.canvas_item_add_set_transform(to_canvas_item, Transform2D(0.0, rect.position))
		RenderingServer.canvas_item_add_polygon(to_canvas_item, _backing_points, _backing_colors)
		RenderingServer.canvas_item_add_set_transform(to_canvas_item, Transform2D.IDENTITY)
	kit.draw_plate_rid(to_canvas_item, plate, rect, ui_scale, tint)


func _get_minimum_size() -> Vector2:
	return Vector2.ZERO
