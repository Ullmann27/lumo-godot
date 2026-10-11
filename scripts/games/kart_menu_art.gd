extends RefCounted
## Sampling boundary for the existing original illustration, not a replacement asset.
## The source WebP has a baked white strip at x >= 1069 and y >= 1907.
## Leave its bytes untouched and exclude the antialiased transition as well.
const WORLD := preload("res://assets/kart/menu/lumo-world.webp")
const WORLD_CONTENT := Rect2(0, 0, 1066, 1904)
static var _world_content: AtlasTexture


static func world_texture() -> Texture2D:
	if _world_content == null:
		_world_content = AtlasTexture.new()
		_world_content.atlas = WORLD
		_world_content.region = WORLD_CONTENT
		_world_content.filter_clip = true
	return _world_content
