extends RefCounted
## Small vector glyphs for the Bauwelt HUD, rasterised once into cached
## textures (2x2 supersampled). No emoji-font dependency, identical on every
## Android device, and one batched draw per chip instead of many primitives.

const SIZE := 40
const SAMPLES := 2
static var _cache: Dictionary = {}


static func texture(kind: String, tint: Color) -> ImageTexture:
	var key := "%s_%s" % [kind, tint.to_html()]
	if _cache.has(key):
		return _cache[key]
	var shapes := _shapes(kind, tint)
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in range(SIZE):
		for x in range(SIZE):
			var color := Color(0, 0, 0, 0)
			for sy in range(SAMPLES):
				for sx in range(SAMPLES):
					var p := Vector2(x + (sx + 0.5) / SAMPLES, y + (sy + 0.5) / SAMPLES) / SIZE
					var sample := Color(0, 0, 0, 0)
					for shape in shapes:
						if _inside(shape, p):
							sample = shape.color
					color += sample
			color /= float(SAMPLES * SAMPLES)
			if color.a > 0.0:
				color.r /= color.a
				color.g /= color.a
				color.b /= color.a
			image.set_pixel(x, y, color)
	var result := ImageTexture.create_from_image(image)
	_cache[key] = result
	return result


static func _inside(shape: Dictionary, p: Vector2) -> bool:
	match shape.type:
		"circle":
			return p.distance_to(shape.c) <= shape.r
		"rect":
			return shape.rect.has_point(p)
		"poly":
			return Geometry2D.is_point_in_polygon(p, shape.points)
		"line":
			var closest := Geometry2D.get_closest_point_to_segment(p, shape.a, shape.b)
			return p.distance_to(closest) <= shape.w * 0.5
		"ring":
			var d := p.distance_to(shape.c)
			return d <= shape.r and d >= shape.r - shape.w
	return false


static func _circle(c: Vector2, r: float, color: Color) -> Dictionary:
	return {"type": "circle", "c": c, "r": r, "color": color}


static func _rect(position: Vector2, size: Vector2, color: Color) -> Dictionary:
	return {"type": "rect", "rect": Rect2(position, size), "color": color}


static func _poly(points: Array, color: Color) -> Dictionary:
	return {"type": "poly", "points": PackedVector2Array(points), "color": color}


static func _line(a: Vector2, b: Vector2, w: float, color: Color) -> Dictionary:
	return {"type": "line", "a": a, "b": b, "w": w, "color": color}


## Shapes in unit space (0..1); later shapes paint over earlier ones.
static func _shapes(kind: String, tint: Color) -> Array:
	var c := Vector2(0.5, 0.5)
	var light := Color(1, 1, 1, 0.95)
	var ink := tint.darkened(0.62)
	var shapes: Array = [_circle(c, 0.5, tint.darkened(0.35)), _circle(c - Vector2(0, 0.02), 0.45, tint)]
	match kind:
		"block":
			shapes.append(_rect(Vector2(0.26, 0.29), Vector2(0.48, 0.42), light))
			shapes.append(_line(Vector2(0.26, 0.5), Vector2(0.74, 0.5), 0.05, ink))
			shapes.append(_line(Vector2(0.5, 0.29), Vector2(0.5, 0.5), 0.05, ink))
		"layer":
			for i in range(3):
				var y := 0.68 - i * 0.17
				shapes.append(_line(Vector2(0.27, y), Vector2(0.73, y), 0.09, light))
		"star", "badge":
			var points: Array = []
			for i in range(10):
				var radius := 0.31 if i % 2 == 0 else 0.135
				var angle := -PI * 0.5 + i * PI / 5.0
				points.append(c + Vector2(cos(angle), sin(angle)) * radius)
			shapes.append(_poly(points, light))
		"world", "map":
			shapes.append(_circle(c, 0.28, Color("4fb7e8")))
			shapes.append(_circle(c + Vector2(-0.07, -0.05), 0.12, Color("7ed957")))
			shapes.append(_circle(c + Vector2(0.11, 0.1), 0.08, Color("7ed957")))
		"wood":
			shapes.append(_rect(Vector2(0.2, 0.39), Vector2(0.5, 0.22), Color("a0663a")))
			shapes.append(_circle(Vector2(0.7, 0.5), 0.11, Color("e6b27a")))
		"stone":
			shapes.append(_poly([Vector2(0.22, 0.65), Vector2(0.35, 0.32), Vector2(0.62, 0.29),
				Vector2(0.79, 0.56), Vector2(0.65, 0.71)], Color("dfe5ea")))
		"food":
			shapes.append(_circle(Vector2(0.5, 0.54), 0.21, Color("ff6b5a")))
			shapes.append(_line(Vector2(0.5, 0.35), Vector2(0.56, 0.2), 0.06, Color("4f8a2a")))
		"coin":
			shapes.append(_circle(c, 0.25, Color("ffe08a")))
			shapes.append({"type": "ring", "c": c, "r": 0.19, "w": 0.04, "color": Color("c8861d")})
		"people":
			shapes.append(_circle(Vector2(0.5, 0.39), 0.11, light))
			shapes.append(_poly([Vector2(0.3, 0.74), Vector2(0.35, 0.56), Vector2(0.65, 0.56),
				Vector2(0.7, 0.74)], light))
		"water":
			shapes.append(_poly([Vector2(0.5, 0.2), Vector2(0.69, 0.56), Vector2(0.5, 0.75),
				Vector2(0.31, 0.56)], Color("dff6ff")))
		"heart":
			shapes.append(_circle(Vector2(0.4, 0.46), 0.12, light))
			shapes.append(_circle(Vector2(0.6, 0.46), 0.12, light))
			shapes.append(_poly([Vector2(0.29, 0.5), Vector2(0.71, 0.5), Vector2(0.5, 0.75)], light))
		"day":
			shapes.append(_circle(c, 0.15, light))
			for i in range(8):
				var dir := Vector2.from_angle(i * TAU / 8.0)
				shapes.append(_line(c + dir * 0.21, c + dir * 0.31, 0.05, light))
		"treasury":
			shapes.append(_rect(Vector2(0.25, 0.41), Vector2(0.5, 0.3), Color("8a5a2b")))
			shapes.append(_rect(Vector2(0.25, 0.29), Vector2(0.5, 0.13), Color("b57a3c")))
			shapes.append(_rect(Vector2(0.45, 0.4), Vector2(0.1, 0.11), Color("ffe08a")))
		"shield":
			shapes.append(_poly([Vector2(0.28, 0.28), Vector2(0.72, 0.28), Vector2(0.7, 0.55),
				Vector2(0.5, 0.79), Vector2(0.3, 0.55)], light))
		_:
			shapes.append(_circle(c, 0.15, light))
	return shapes


## Ready-to-place TextureRect for HUD rows.
static func rect(kind: String, tint: Color, side: float = 30.0) -> TextureRect:
	var control := TextureRect.new()
	control.texture = texture(kind, tint)
	control.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	control.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	control.custom_minimum_size = Vector2.ONE * side
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return control
