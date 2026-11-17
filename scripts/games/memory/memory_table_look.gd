extends RefCounted
## Original LUMO look for the 3D Memory table: card back, felt mat, wooden
## rim, room backdrop, soft contact shadows and pair sparkles. Presentation
## only. Nothing here reads or changes the authoritative Dart round.

const CARD_BACK := """
shader_type spatial;
render_mode unshaded, cull_back;
uniform vec4 top_color : source_color = vec4(0.16, 0.62, 0.74, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.11, 0.24, 0.52, 1.0);
uniform vec4 gold : source_color = vec4(1.0, 0.80, 0.34, 1.0);
uniform float aspect = 0.76;
uniform float shine = 1.0;

float sd_round_rect(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

float sd_star(vec2 p, float r, float rf) {
	const vec2 k1 = vec2(0.809016994375, -0.587785252292);
	const vec2 k2 = vec2(-0.809016994375, -0.587785252292);
	p.x = abs(p.x);
	p -= 2.0 * max(dot(k1, p), 0.0) * k1;
	p -= 2.0 * max(dot(k2, p), 0.0) * k2;
	p.x = abs(p.x);
	p.y -= r;
	vec2 ba = rf * vec2(-k1.y, k1.x) - vec2(0.0, 1.0);
	float h = clamp(dot(p, ba) / dot(ba, ba), 0.0, r);
	return length(p - ba * h) * sign(p.y * ba.x - p.x * ba.y);
}

void fragment() {
	vec2 p = (UV - 0.5) * vec2(aspect, 1.0);
	vec2 extent = vec2(aspect, 1.0) * 0.5;
	vec3 col = mix(top_color.rgb, bottom_color.rgb, smoothstep(0.0, 1.0, UV.y));
	vec2 d = p * 15.0;
	float diamond = abs(fract(d.x + d.y) - 0.5) + abs(fract(d.x - d.y) - 0.5);
	col += vec3(0.05, 0.07, 0.09) * (1.0 - smoothstep(0.08, 0.14, diamond));
	float rc = length(p);
	col += gold.rgb * 0.28 * exp(-rc * rc * 16.0);
	float frame = sd_round_rect(p, extent - vec2(0.05), 0.07);
	col = mix(col, gold.rgb, 1.0 - smoothstep(0.004, 0.014, abs(frame + 0.012)));
	col = mix(col, gold.rgb * 0.75, 1.0 - smoothstep(0.002, 0.008, abs(frame + 0.042)));
	vec2 sp = vec2(p.x, -p.y + 0.01);
	float s = sd_star(sp, 0.19, 0.46);
	float outline = 1.0 - smoothstep(0.012, 0.022, s);
	col = mix(col, vec3(0.42, 0.22, 0.05), outline);
	float fill = 1.0 - smoothstep(-0.003, 0.004, s);
	vec3 star = mix(gold.rgb, vec3(1.0, 0.97, 0.82), clamp(0.55 * sp.y / 0.19 + 0.35, 0.0, 1.0));
	star = mix(star, gold.rgb * 0.8, step(0.0, sp.x) * 0.25);
	col = mix(col, star, fill);
	for (int i = 0; i < 4; i++) {
		float a = float(i) * 1.5707963 + 0.7853981;
		vec2 c = vec2(cos(a) * extent.x * 0.62, sin(a) * 0.36);
		col = mix(col, vec3(1.0, 0.93, 0.7), 1.0 - smoothstep(0.012, 0.02, length(p - c)));
	}
	float t = fract(TIME * 0.12 + NODE_POSITION_WORLD.x * 0.09 + NODE_POSITION_WORLD.y * 0.05);
	float band = (p.x + p.y * 0.55) - (t * 3.2 - 1.6);
	col += shine * vec3(1.0, 0.97, 0.88) * 0.22 * exp(-band * band * 70.0) * step(frame, 0.0);
	ALBEDO = col;
}
"""

const BACKDROP := """
shader_type spatial;
render_mode unshaded;
uniform vec4 center_color : source_color = vec4(0.17, 0.39, 0.42, 1.0);
uniform vec4 edge_color : source_color = vec4(0.04, 0.09, 0.17, 1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 0.76, 0.42, 1.0);
uniform float bokeh = 1.0;
varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 p = world.xy;
	float r = length(p * vec2(0.10, 0.13));
	vec3 col = mix(center_color.rgb, edge_color.rgb, smoothstep(0.05, 1.05, r));
	col += glow_color.rgb * 0.12 * exp(-r * r * 4.0);
	for (int layer = 0; layer < 2; layer++) {
		float scale = layer == 0 ? 0.7 : 1.3;
		vec2 g = p * scale + float(layer) * 11.3;
		vec2 id = floor(g);
		vec2 f = fract(g) - 0.5;
		float h = hash(id + float(layer) * 5.0);
		vec2 o = vec2(hash(id + 3.1), hash(id + 7.7)) - 0.5;
		float size = 0.10 + 0.16 * h;
		float dist = length(f - o * 0.5);
		float on = step(0.70, h);
		vec3 tint = mix(glow_color.rgb, vec3(0.55, 0.85, 1.0), hash(id + 1.7));
		col += tint * on * (1.0 - smoothstep(size * 0.35, size, dist)) * 0.09 * bokeh * (layer == 0 ? 1.0 : 0.6);
	}
	ALBEDO = col;
}
"""

const FELT := """
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
uniform vec4 felt_color : source_color = vec4(0.13, 0.42, 0.40, 1.0);
uniform vec4 edge_color : source_color = vec4(0.06, 0.22, 0.25, 1.0);
uniform vec4 star_color : source_color = vec4(0.36, 0.66, 0.58, 1.0);
uniform vec2 extent = vec2(4.0, 3.0);
varying vec2 local;

void vertex() {
	local = VERTEX.xy;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(41.3, 289.1))) * 15731.743);
}

void fragment() {
	vec2 q = local / max(extent, vec2(0.01));
	float v = clamp(length(q * vec2(0.92, 1.0)), 0.0, 1.4);
	vec3 col = mix(felt_color.rgb, edge_color.rgb, smoothstep(0.35, 1.25, v));
	float grain = hash(floor(local * 90.0));
	col *= 0.95 + 0.07 * grain;
	vec2 g = local * 2.2;
	vec2 f = fract(g) - 0.5;
	float dots = 1.0 - smoothstep(0.035, 0.06, length(f));
	col = mix(col, star_color.rgb, dots * 0.22);
	float stitch = abs(max(abs(q.x), abs(q.y) * 1.0) - 0.93);
	col = mix(col, vec3(0.93, 0.80, 0.52), (1.0 - smoothstep(0.0, 0.006, stitch)) * step(0.5, fract((q.x + q.y) * 40.0)) * 0.7);
	ALBEDO = col;
	ROUGHNESS = 0.95;
}
"""

const WOOD := """
shader_type spatial;
uniform vec4 light_wood : source_color = vec4(0.86, 0.53, 0.26, 1.0);
uniform vec4 dark_wood : source_color = vec4(0.45, 0.22, 0.09, 1.0);
varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float wave = world.y * 5.5 + sin(world.x * 1.7 + sin(world.y * 2.3) * 1.2) * 1.6;
	float ring = 0.5 + 0.5 * sin(wave);
	float fine = 0.5 + 0.5 * sin(world.y * 41.0 + world.x * 3.0);
	vec3 col = mix(dark_wood.rgb, light_wood.rgb, ring * 0.75 + fine * 0.25);
	ALBEDO = col;
	ROUGHNESS = 0.55;
	SPECULAR = 0.3;
}
"""

const SHADOW := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
uniform float softness = 0.32;

float sd_round_rect(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 p = UV - 0.5;
	float d = sd_round_rect(p, vec2(0.5 - softness * 0.5), 0.08);
	float a = 1.0 - smoothstep(-softness * 0.5, softness * 0.45, d);
	ALBEDO = vec3(0.01, 0.05, 0.06);
	ALPHA = a * COLOR.a;
}
"""

static var _shaders := {}


static func shader(code: String) -> Shader:
	if not _shaders.has(code):
		var made := Shader.new()
		made.code = code
		_shaders[code] = made
	return _shaders[code]


static func material(code: String, parameters: Dictionary = {}) -> ShaderMaterial:
	var made := ShaderMaterial.new()
	made.shader = shader(code)
	for key in parameters:
		made.set_shader_parameter(key, parameters[key])
	return made


## Gold card body: a warm metal frame around the motif or the LUMO back.
static func card_body() -> StandardMaterial3D:
	var made := StandardMaterial3D.new()
	made.albedo_color = Color("eec35a").srgb_to_linear()
	made.metallic = 0.25
	made.roughness = 0.34
	made.metallic_specular = 0.7
	made.rim_enabled = true
	made.rim = 0.35
	made.rim_tint = 0.6
	made.emission_enabled = true
	made.emission = Color("ffd76a").srgb_to_linear()
	made.emission_energy_multiplier = 0.0
	return made


static func sparkle_emitter(amount: int) -> CPUParticles3D:
	var emitter := CPUParticles3D.new()
	emitter.name = "PairSparkles"
	emitter.emitting = false
	emitter.one_shot = true
	emitter.amount = maxi(1, amount)
	emitter.lifetime = 0.9
	emitter.explosiveness = 0.92
	emitter.local_coords = false
	emitter.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	emitter.emission_sphere_radius = 0.18
	emitter.direction = Vector3(0, 0.4, 1)
	emitter.spread = 180.0
	emitter.initial_velocity_min = 0.9
	emitter.initial_velocity_max = 2.0
	emitter.gravity = Vector3(0, -1.6, 0)
	emitter.damping_min = 1.2
	emitter.damping_max = 2.0
	emitter.scale_amount_min = 0.6
	emitter.scale_amount_max = 1.3
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.2))
	curve.add_point(Vector2(0.18, 1.0))
	curve.add_point(Vector2(1, 0))
	emitter.scale_amount_curve = curve
	var ramp := Gradient.new()
	ramp.set_color(0, Color("fff6c8"))
	ramp.set_color(1, Color(1.0, 0.72, 0.25, 0.0))
	ramp.add_point(0.45, Color("ffd24d"))
	emitter.color_ramp = ramp
	var quad := QuadMesh.new()
	quad.size = Vector2(0.09, 0.09)
	var look := StandardMaterial3D.new()
	look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	look.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	look.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	look.vertex_color_use_as_albedo = true
	var dot := GradientTexture2D.new()
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(1.0, 0.5)
	dot.width = 64
	dot.height = 64
	var falloff := Gradient.new()
	falloff.set_color(0, Color(1, 1, 1, 1))
	falloff.set_color(1, Color(1, 1, 1, 0))
	falloff.add_point(0.25, Color(1, 1, 1, 0.85))
	dot.gradient = falloff
	look.albedo_texture = dot
	quad.material = look
	emitter.mesh = quad
	return emitter
