extends RefCounted
## Shaders of Wolkenhafen. All of them run on the phone's gl_compatibility
## renderer: no screen or depth textures, light computed in the shader where a
## soft, painted look is wanted (clouds), the engine's lights elsewhere.

const SKY := """
shader_type sky;
uniform vec3 zenith : source_color = vec3(0.16, 0.42, 0.90);
uniform vec3 horizon : source_color = vec3(1.0, 0.80, 0.64);
uniform vec3 below : source_color = vec3(0.98, 0.86, 0.78);
uniform vec3 sun_colour : source_color = vec3(1.0, 0.90, 0.68);
uniform vec3 sun_dir = vec3(0.55, 0.32, -0.77);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	float a = mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x);
	float b = mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x);
	return mix(a, b, u.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) { v += noise(p) * a; p = p * 2.07 + 3.1; a *= 0.5; }
	return v;
}

void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	vec3 colour = mix(horizon, zenith, pow(clamp(h, 0.0, 1.0), 0.55));
	colour = mix(colour, below, clamp(-h * 3.0, 0.0, 1.0));
	vec3 s = normalize(sun_dir);
	float sun = max(dot(d, s), 0.0);
	colour += sun_colour * (pow(sun, 600.0) * 6.0 + pow(sun, 18.0) * 0.35 + pow(sun, 3.0) * 0.12);
	// Soft cirrus streaks high in the sky.
	if (h > 0.02) {
		vec2 uv = d.xz / (h + 0.18) * 1.6 + vec2(TIME * 0.004, 0.0);
		float c = smoothstep(0.52, 0.86, fbm(uv * vec2(1.0, 3.2)));
		colour = mix(colour, vec3(1.0, 0.97, 0.94), c * 0.38 * smoothstep(0.02, 0.25, h));
	}
	COLOR = colour;
}
"""

const CLOUD_SEA := """
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
uniform vec3 shadow_colour : source_color = vec3(0.62, 0.66, 0.86);
uniform vec3 lit_colour : source_color = vec3(1.0, 0.97, 0.92);
uniform vec3 far_colour : source_color = vec3(1.0, 0.82, 0.70);
uniform vec3 sun_dir = vec3(0.55, 0.32, -0.77);
uniform float scale = 0.012;
varying vec3 world;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	float a = mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x);
	float b = mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x);
	return mix(a, b, u.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.55;
	for (int i = 0; i < 5; i++) { v += noise(p) * a; p = p * 2.03 + vec2(4.1, 1.7); a *= 0.5; }
	return v;
}

void vertex() { world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

void fragment() {
	vec2 p = world.xz * scale + vec2(TIME * 0.004, TIME * 0.002);
	float height = fbm(p);
	// Light from the sun side of each puff: compare with a sample towards the sun.
	float toward = fbm(p + normalize(sun_dir.xz) * 0.08);
	float lit = clamp(0.55 + (height - toward) * 5.0, 0.0, 1.0);
	float puff = smoothstep(0.25, 0.85, height);
	vec3 colour = mix(shadow_colour, lit_colour, clamp(puff * 0.6 + lit * 0.55, 0.0, 1.0));
	float far = smoothstep(220.0, 700.0, length(world.xz - CAMERA_POSITION_WORLD.xz));
	ALBEDO = mix(colour, far_colour, far);
}
"""

## Cumulus clouds: painted light from the sun direction plus a bright rim.
const CLOUD := """
shader_type spatial;
render_mode unshaded, fog_disabled;
uniform vec3 lit : source_color = vec3(1.0, 0.98, 0.95);
uniform vec3 shade : source_color = vec3(0.74, 0.76, 0.90);
uniform vec3 warm : source_color = vec3(1.0, 0.86, 0.72);
uniform vec3 sun_dir = vec3(0.55, 0.32, -0.77);
uniform float fade_near = 6.0;
varying vec3 world_normal;
varying vec3 world;

void vertex() {
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float wobble = sin(TIME * 0.35 + world.x * 0.07 + world.z * 0.05) * 0.25;
	VERTEX += NORMAL * wobble;
}

void fragment() {
	vec3 n = normalize(world_normal);
	float d = dot(n, normalize(sun_dir)) * 0.5 + 0.5;
	vec3 colour = mix(shade, lit, smoothstep(0.15, 0.85, d));
	vec3 view = normalize(CAMERA_POSITION_WORLD - world);
	float rim = pow(1.0 - clamp(dot(n, view), 0.0, 1.0), 2.5);
	colour = mix(colour, warm, rim * 0.45 * smoothstep(0.3, 1.0, d));
	colour *= 0.92 + 0.08 * clamp(n.y * 0.5 + 0.5, 0.0, 1.0);
	ALBEDO = colour;
	// Dissolve when the camera flies through.
	float near = length(CAMERA_POSITION_WORLD - world);
	ALPHA = 1.0;
	if (near < fade_near) {
		float h = fract(sin(dot(floor(FRAGCOORD.xy * 0.5), vec2(12.9898, 78.233))) * 43758.5453);
		if (h > near / fade_near) { discard; }
	}
}
"""

const GRASS := """
shader_type spatial;
render_mode cull_back;
uniform float detail = 1.0;
varying vec3 world;
varying vec3 local_normal;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	float a = mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x);
	float b = mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x);
	return mix(a, b, u.y);
}

void vertex() { world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; local_normal = NORMAL; }

void fragment() {
	float n = noise(world.xz * 0.35) * 0.6 + noise(world.xz * 1.7) * 0.4 * detail;
	vec3 base = COLOR.rgb;
	base *= 0.86 + 0.24 * n;
	// Tiny flower dots on the meadow.
	float dots = step(0.985, hash(floor(world.xz * 2.2))) * detail;
	vec3 flower = mix(vec3(1.0, 0.92, 0.5), vec3(1.0, 0.55, 0.72), hash(floor(world.xz * 2.2) + 7.0));
	ALBEDO = mix(base, flower, dots * 0.85);
	ROUGHNESS = 0.92;
	SPECULAR = 0.2;
}
"""

const ROCK := """
shader_type spatial;
uniform float detail = 1.0;
varying vec3 world;

float hash(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float noise(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p); vec3 u = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(hash(i), hash(i + vec3(1, 0, 0)), u.x),
		mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), u.x), u.y);
	float b = mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), u.x),
		mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), u.x), u.y);
	return mix(a, b, u.z);
}

void vertex() { world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

void fragment() {
	float n = noise(world * vec3(0.45, 1.6, 0.45)) * 0.6 + noise(world * 1.9) * 0.4 * detail;
	vec3 base = COLOR.rgb * (0.8 + 0.3 * n);
	// Thin bright seams between the strata.
	float seam = smoothstep(0.92, 1.0, abs(sin(world.y * 2.2 + n * 1.4)));
	ALBEDO = base + seam * 0.06 * detail;
	ROUGHNESS = 0.95;
	SPECULAR = 0.15;
}
"""

## Rising updraft: a glassy spiral column, additive, brighter towards the edge.
const UPDRAFT := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;
uniform vec4 tint : source_color = vec4(0.55, 0.92, 1.0, 1.0);
uniform float strength = 1.0;
varying vec3 local;

void vertex() { local = VERTEX; }

void fragment() {
	float angle = atan(local.x, local.z);
	float spiral = sin(angle * 3.0 + local.y * 0.35 - TIME * 4.0);
	float bands = smoothstep(0.75, 1.0, spiral);
	float edge = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.2);
	float fade = smoothstep(0.0, 0.25, UV.y) * smoothstep(1.0, 0.7, UV.y);
	ALBEDO = tint.rgb * (0.05 + bands * 0.45 + edge * 0.5) * fade * strength;
}
"""

## Ring gates: a glowing tube whose colour runs around the ring.
const RING := """
shader_type spatial;
render_mode unshaded, fog_disabled;
uniform vec4 colour_a : source_color = vec4(1.0, 0.85, 0.3, 1.0);
uniform vec4 colour_b : source_color = vec4(1.0, 0.98, 0.8, 1.0);
uniform float energy = 1.0;
uniform float pulse = 0.0;
varying vec3 local;

void vertex() { local = VERTEX; }

void fragment() {
	float a = atan(local.y, local.x);
	float run = 0.5 + 0.5 * sin(a * 6.0 - TIME * 5.0);
	vec3 c = mix(colour_a.rgb, colour_b.rgb, run * 0.6);
	float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 1.5);
	ALBEDO = c * (0.9 + rim * 0.6 + pulse) * energy;
}
"""

## Sparks (instanced): a star drawn in the fragment shader, facing the camera.
const SPARK := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
uniform vec4 tint : source_color = vec4(1.0, 0.86, 0.32, 1.0);
varying float phase;
varying float alive;

void vertex() {
	phase = INSTANCE_CUSTOM.x;
	alive = INSTANCE_CUSTOM.y;
	float bob = sin(TIME * 2.4 + phase * 6.28) * 0.18;
	vec3 centre = (MODEL_MATRIX * vec4(0.0, bob, 0.0, 1.0)).xyz;
	vec3 right = normalize(INV_VIEW_MATRIX[0].xyz);
	vec3 up = normalize(INV_VIEW_MATRIX[1].xyz);
	float size = length(MODEL_MATRIX[0].xyz) * alive * (1.0 + 0.12 * sin(TIME * 5.0 + phase * 9.0));
	vec3 world_pos = centre + (right * VERTEX.x + up * VERTEX.y) * size;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world_pos, 1.0);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x) + TIME * 0.6 + phase;
	float star = 0.42 + 0.22 * cos(a * 5.0);
	float body = smoothstep(star + 0.05, star - 0.05, r);
	float glow = exp(-r * 3.2) * 0.9;
	vec3 colour = mix(tint.rgb, vec3(1.0, 1.0, 0.92), body * 0.6);
	ALBEDO = colour * (body * 1.4 + glow);
	if (alive < 0.01) { discard; }
}
"""

## Speed lines around the camera; instance custom carries the phase.
const WIND := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
uniform float amount = 0.0;
varying float fade;

void vertex() {
	fade = INSTANCE_CUSTOM.x;
}

void fragment() {
	float across = 1.0 - abs(UV.x * 2.0 - 1.0);
	float along = smoothstep(0.0, 0.3, UV.y) * smoothstep(1.0, 0.55, UV.y);
	ALBEDO = vec3(1.0, 1.0, 1.0) * across * along * amount * fade * 0.55;
}
"""

## Ribbons (wing-tip trails, letter trail): vertex colour alpha.
const RIBBON := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
void fragment() {
	float across = 1.0 - abs(UV.y * 2.0 - 1.0);
	ALBEDO = COLOR.rgb * COLOR.a * across;
}
"""

## Ground marker (drop target / landing preview): pulsing ring on the ground.
const MARKER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
uniform vec4 tint : source_color = vec4(1.0, 0.85, 0.3, 1.0);
uniform float fill = 0.12;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float ring = smoothstep(0.80, 0.9, r) * smoothstep(1.0, 0.92, r);
	float wave = smoothstep(0.06, 0.0, abs(r - fract(TIME * 0.7))) * step(r, 1.0);
	float inner = step(r, 0.9) * fill;
	ALBEDO = tint.rgb * (ring * 1.4 + wave * 0.6 + inner);
}
"""

## Beacon: vertical light shaft above the delivery target.
const BEACON := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
uniform vec4 tint : source_color = vec4(1.0, 0.85, 0.3, 1.0);
void fragment() {
	float edge = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 0.8);
	float fall = smoothstep(1.0, 0.0, UV.y);
	float flow = 0.75 + 0.25 * sin(UV.y * 30.0 + TIME * 3.0);
	ALBEDO = tint.rgb * (1.0 - edge) * fall * flow * 0.7;
}
"""

## Rising motes inside an updraft (instanced quads moved by the shader).
const RISE := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
uniform float height = 60.0;
uniform float speed = 6.0;
uniform vec4 tint : source_color = vec4(0.8, 1.0, 1.0, 1.0);
varying float fade;

void vertex() {
	float seed = INSTANCE_CUSTOM.x;
	float y = mod(seed * height + TIME * speed * (0.7 + seed * 0.6), height);
	fade = smoothstep(0.0, 0.1, y / height) * smoothstep(1.0, 0.8, y / height);
	vec3 sway = vec3(sin(TIME + seed * 40.0) * 0.6, y, cos(TIME * 0.8 + seed * 31.0) * 0.6);
	vec3 centre = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz + sway;
	vec3 right = normalize(INV_VIEW_MATRIX[0].xyz);
	vec3 up = normalize(INV_VIEW_MATRIX[1].xyz);
	float size = length(MODEL_MATRIX[0].xyz);
	vec3 corner = centre + (right * VERTEX.x + up * VERTEX.y) * size;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(corner, 1.0);
}

void fragment() {
	float r = length(UV * 2.0 - 1.0);
	ALBEDO = tint.rgb * exp(-r * r * 5.0) * fade * 0.9;
}
"""

static var _cache: Dictionary = {}


static func shader(code_name: String) -> Shader:
	if not _cache.has(code_name):
		var made := Shader.new()
		made.code = str(get_script_constant(code_name))
		_cache[code_name] = made
	return _cache[code_name]


static func get_script_constant(code_name: String) -> String:
	match code_name:
		"SKY":
			return SKY
		"CLOUD_SEA":
			return CLOUD_SEA
		"CLOUD":
			return CLOUD
		"GRASS":
			return GRASS
		"ROCK":
			return ROCK
		"UPDRAFT":
			return UPDRAFT
		"RING":
			return RING
		"SPARK":
			return SPARK
		"WIND":
			return WIND
		"RIBBON":
			return RIBBON
		"MARKER":
			return MARKER
		"BEACON":
			return BEACON
		"RISE":
			return RISE
	return ""


static func material(code_name: String, params: Dictionary = {}) -> ShaderMaterial:
	var made := ShaderMaterial.new()
	made.shader = shader(code_name)
	for key in params:
		made.set_shader_parameter(key, params[key])
	return made
