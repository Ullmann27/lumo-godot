extends RefCounted
## Shared, opaque finish families. Mobile has its own cheaper shader, not a
## runtime branch hidden inside every fragment. No screen/depth reads or lights.
const HIGH = preload("res://assets/shaders/kart_lumo_cinema_high.gdshader")
const MOBILE = preload("res://assets/shaders/kart_lumo_cinema_mobile.gdshader")
static var _cache: Dictionary = {}


static func material(pigment: Color, kind: String, low_detail: bool,
		instance_colors: bool = false, instanced_normals: bool = false) -> ShaderMaterial:
	var key := "%s:%s:%s:%s:%s" % [pigment.to_html(), kind, low_detail, instance_colors, instanced_normals]
	if _cache.has(key):
		return _cache[key]
	var result := ShaderMaterial.new()
	result.shader = MOBILE if low_detail else HIGH
	result.set_shader_parameter("base_color", pigment)
	result.set_shader_parameter("instance_colors", instance_colors)
	result.set_shader_parameter("correct_instance_normals", instanced_normals)
	var roughness := 0.84
	var metal := 0.0
	var specular := 0.18
	var rim := 0.055
	var micro := 0.08
	match kind:
		"crystal":
			roughness = 0.24
			specular = 0.52
			rim = 0.16
			micro = 0.025
			result.set_shader_parameter("crystal_amount", 1.0)
		"water":
			roughness = 0.25
			specular = 0.46
			rim = 0.11
			micro = 0.02
			result.set_shader_parameter("water_amount", 1.0)
		"paint":
			roughness = 0.3
			metal = 0.28
			specular = 0.46
			rim = 0.08
			micro = 0.025
		"metal":
			roughness = 0.4
			metal = 0.68
			specular = 0.5
			rim = 0.065
			micro = 0.045
		"rubber":
			roughness = 0.94
			specular = 0.08
			rim = 0.025
			micro = 0.045
	result.set_shader_parameter("surface_roughness", roughness)
	result.set_shader_parameter("surface_metallic", metal)
	result.set_shader_parameter("specular_strength", specular)
	result.set_shader_parameter("rim_strength", rim)
	result.set_shader_parameter("micro_strength", micro)
	result.set_meta("lumo_cinema_kind", kind)
	result.set_meta("lumo_cinema_mobile", low_detail)
	_cache[key] = result
	return result
