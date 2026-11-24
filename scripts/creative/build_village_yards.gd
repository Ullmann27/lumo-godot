extends Node3D
## A drawn yard owns its outline, including a permanently open south entrance.
const REGION = preload("res://scripts/creative/build_settlement_region.gd")
const TERRAIN = preload("res://scripts/creative/build_village_terrain.gd")
const FIELDS = preload("res://scripts/creative/build_village_fields.gd")
const MAX_YARDS := 24
const MAX_SIDE := 6
const GATE_WIDTH := 2.1
const BUILD_HALF := 2.1
var _signature: Array = []
var _timber: BoxMesh


static func bounds(yard: Dictionary) -> Rect2:
	var box := FIELDS.rect(int(yard.a), int(yard.b))
	var low := Vector2(-REGION.TOWN_CENTER, 0) + (Vector2(box.position) - Vector2.ONE * 0.5) * REGION.SPACING
	return Rect2(low, Vector2(box.size) * REGION.SPACING)


static func gate(yard: Dictionary) -> Vector2:
	var box := bounds(yard)
	var cells := roundi(box.size.x / REGION.SPACING)
	var offset := float(cells / 2) * REGION.SPACING if cells > 1 else REGION.SPACING * 0.5
	return Vector2(box.position.x + offset, box.end.y)


static func blocks_building(yard: Dictionary, center: Vector2) -> bool:
	var box := bounds(yard)
	var footprint := Rect2(center - Vector2.ONE * BUILD_HALF, Vector2.ONE * BUILD_HALF * 2.0)
	if box.grow(0.13).intersects(footprint) and not box.grow(-0.13).encloses(footprint):
		return true
	# Keep the actual walking approach clear on both sides of the opening.
	var opening := gate(yard)
	return footprint.intersects(Rect2(opening - Vector2(0.52, 1.15), Vector2(1.04, 2.3)))


static func building_at(building: Dictionary, opponent := false) -> Vector3:
	var at := REGION.plot_position(int(building.plot), opponent)
	if building.has("site_x_cm"):
		at.x += float(building.site_x_cm) * 0.01
		at.z += float(building.site_z_cm) * 0.01
		at.y = TERRAIN.height(at.x, at.z) + 0.03
	return at


static func error(model, a: int, b: int) -> String:
	if a < 0 or b < 0 or a >= int(model._player.plots) or b >= int(model._player.plots):
		return "Zieh auf deiner erschlossenen Wiese."
	var yard := {"a": a, "b": b}
	var box := FIELDS.rect(a, b)
	if box.size.x > MAX_SIDE or box.size.y > MAX_SIDE:
		return "Zieh ein kleineres Gehege (höchstens sechs Felder je Seite)."
	var yards: Array = model._player.get("yards", [])
	if yards.size() >= MAX_YARDS:
		return "Dein Dorf hat schon 24 Gehege."
	for other in yards:
		if bounds(yard).grow(0.15).intersects(bounds(other)):
			return "Lass zwischen zwei Gehegen einen Weg frei."
	for z in range(box.position.y, box.end.y):
		for x in range(box.position.x, box.end.x):
			var index := REGION.plot_index_at(Vector2i(x, z))
			if index < 0 or index >= int(model._player.plots) or not model.plot_buildable(index):
				return "Der ganze Zaun braucht ebene, erschlossene Wiese."
	for building in model._player.buildings:
		var at := building_at(building)
		if blocks_building(yard, Vector2(at.x, at.z)):
			return "Hier braucht ein Haus mehr Platz. Lass den Durchgang frei."
	return ""


func sync(yards: Array) -> void:
	if yards == _signature:
		return
	_signature = yards.duplicate(true)
	for child in get_children():
		remove_child(child)
		child.queue_free()
	for yard in yards:
		_make_yard(yard, true)


func preview(yard: Dictionary) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	if not yard.is_empty():
		_make_yard(yard, false)


func _make_yard(yard: Dictionary, solid: bool) -> void:
	if _timber == null:
		_timber = BoxMesh.new()
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		_timber.material = mat
	var body := StaticBody3D.new()
	body.name = "Gartenzaun"
	add_child(body)
	var box := bounds(yard)
	var opening := gate(yard)
	var left := opening - Vector2(GATE_WIDTH * 0.5, 0)
	var right := opening + Vector2(GATE_WIDTH * 0.5, 0)
	var parts: Array = []
	var north_east := Vector2(box.end.x, box.position.y)
	var south_west := Vector2(box.position.x, box.end.y)
	for span in [[box.position, north_east], [north_east, box.end], [box.end, right],
			[left, south_west], [south_west, box.position]]:
		_span(body, parts, span[0], span[1], solid)
	# Two contrasting gateposts with warm caps, plus leaves folded back along the rails.
	for edge: Vector2 in [left, right]:
		var p := _ground(edge)
		_piece(parts, p + Vector3.UP * 0.84, Vector3(.25, 1.68, .25), 0, Color("316f73"))
		_piece(parts, p + Vector3.UP * 1.69, Vector3(.33, .13, .33), 0, Color("efbb64"))
		var wing := -1.0 if edge == left else 1.0
		for i in range(4):
			_piece(parts, p + Vector3(wing * (.15 + i * .17), .66, .12),
				Vector3(.15, .84 - i * .05, .09), 0, Color("4c9490"))
	var batched := MultiMesh.new()
	batched.transform_format = MultiMesh.TRANSFORM_3D
	batched.use_colors = true
	batched.mesh = _timber
	batched.instance_count = parts.size()
	for i in range(parts.size()):
		batched.set_instance_transform(i, parts[i][0])
		batched.set_instance_color(i, parts[i][1])
	var mesh := MultiMeshInstance3D.new()
	mesh.multimesh = batched
	mesh.visibility_range_end = 100
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(mesh)


func _ground(p: Vector2) -> Vector3:
	return Vector3(p.x, TERRAIN.height(p.x,p.y), p.y)


func _piece(parts: Array, at: Vector3, size: Vector3, yaw: float, color: Color) -> void:
	parts.append([Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(size), at), color])


func _span(body: StaticBody3D, parts: Array, a: Vector2, b: Vector2, solid: bool) -> void:
	var count := maxi(1, ceili(a.distance_to(b) / 1.85))
	var yaw := -atan2(b.y - a.y, b.x - a.x)
	for i in range(count + 1):
		var p := _ground(a.lerp(b, float(i) / count))
		_piece(parts, p + Vector3.UP * .53, Vector3(.15, 1.06, .15), yaw, Color("9a6341"))
		if i == count:
			break
		var q := _ground(a.lerp(b, float(i + 1) / count))
		for h in [.37, .78]:
			var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, atan2(q.y - p.y, Vector2(q.x-p.x, q.z-p.z).length()))
			parts.append([Transform3D(basis * Basis.from_scale(Vector3(p.distance_to(q), .105, .085)),
				(p+q)*.5 + Vector3.UP * h), Color("bf905a")])
		if solid:
			var collider := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = Vector3(a.distance_to(b) / count + .02, 1.03 + absf(q.y - p.y), .18)
			collider.shape = shape
			collider.position = (p + q) * .5 + Vector3.UP * .5
			collider.rotation.y = yaw
			body.add_child(collider)
