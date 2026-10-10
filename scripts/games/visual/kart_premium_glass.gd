extends RefCounted
## Additive glass UI adapter. Never replaces the original interactive Controls.
const GLASS = preload("res://assets/shaders/kart_frosted_glass.gdshader")
const LITE = preload("res://assets/shaders/kart_glass_lite.gdshader")


static func create_overlay(size: Vector2, low_detail: bool = false) -> ColorRect:
    var overlay := ColorRect.new()
    overlay.name = "DecorativeGlass"
    overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
    overlay.focus_mode = Control.FOCUS_NONE
    overlay.custom_minimum_size = size
    overlay.color = Color.WHITE
    var rd_available: bool = RenderingServer.get_rendering_device() != null
    var shader := ShaderMaterial.new()
    shader.shader = LITE if low_detail or not rd_available else GLASS
    overlay.material = shader
    overlay.set_meta("decorative_only", true)
    return overlay
