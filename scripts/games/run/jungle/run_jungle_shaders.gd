extends RefCounted
## Shader sources of the Dschungelherz scenery. All of them run on the mobile and
## compatibility renderers: no screen or depth textures, motion only from TIME
## and per-instance data, so swaying leaves and flying animals cost no CPU.
## Vertex colours are authored in sRGB and converted here.

const FOLIAGE: String = """
shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;
uniform float sway = 1.0;
uniform float brightness = 1.0;
varying float lift;
void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float w = COLOR.a * sway;
	float t = TIME * 1.4 + world.x * 0.23 + world.z * 0.19;
	VERTEX += vec3(sin(t) * 0.08, sin(t * 1.9) * 0.035, cos(t * 0.8) * 0.08) * w;
	lift = COLOR.a;
}
void fragment() {
	vec3 base = pow(COLOR.rgb, vec3(2.2)) * brightness;
	ALBEDO = base * (0.82 + 0.3 * lift);
	ROUGHNESS = 0.75;
	SPECULAR = 0.18;
	// Light through the leaves: a little glow on the far side of the sun.
	EMISSION = base * 0.07;
}
"""

const SOLID: String = """
shader_type spatial;
render_mode specular_schlick_ggx;
uniform float brightness = 1.0;
uniform float glow = 0.0;
void fragment() {
	vec3 base = pow(COLOR.rgb, vec3(2.2)) * brightness;
	ALBEDO = base;
	ROUGHNESS = 0.9;
	SPECULAR = 0.1;
	EMISSION = base * glow;
}
"""

## Path decks and terrain: one shader, the pattern picks earth, planks or flagstones.
const GROUND: String = """
shader_type spatial;
render_mode specular_schlick_ggx;
uniform int pattern = 0;
uniform vec3 tint : source_color = vec3(1.0);
varying vec3 world;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	// Ground always faces up, whatever order its triangles were built in.
	vec3 world_normal = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	if (world_normal.y < -0.05) {
		NORMAL = -NORMAL;
	}
	vec3 base = pow(COLOR.rgb, vec3(2.2)) * tint;
	float n = noise(world.xz * 1.7) * 0.6 + noise(world.xz * 0.31) * 0.4;
	float shade = 0.78 + 0.36 * n;
	if (pattern == 1) {
		// Planks across the path, with dark seams and a little grain.
		float plank = fract(UV.y * 2.6);
		float seam = smoothstep(0.0, 0.06, plank) * smoothstep(1.0, 0.94, plank);
		float grain = 0.9 + 0.1 * sin(UV.x * 40.0 + hash(vec2(floor(UV.y * 2.6), 3.0)) * 20.0);
		shade = (0.55 + 0.45 * seam) * grain * (0.85 + 0.3 * hash(vec2(floor(UV.y * 2.6), 1.0)));
	} else if (pattern == 2) {
		// Old flagstones with mossy joints.
		vec2 cell = vec2(UV.x * 2.2, UV.y * 0.9);
		cell.x += 0.5 * floor(cell.y);
		vec2 f = fract(cell);
		float joint = smoothstep(0.0, 0.07, f.x) * smoothstep(1.0, 0.93, f.x) * smoothstep(0.0, 0.07, f.y) * smoothstep(1.0, 0.93, f.y);
		float stone = 0.8 + 0.3 * hash(floor(cell));
		base = mix(vec3(0.07, 0.16, 0.05), base * stone, joint);
	}
	ALBEDO = base * shade;
	ROUGHNESS = pattern == 2 ? 0.8 : 1.0;
	// No sky sheen on earth and wood: at the low camera angle it washed them out.
	SPECULAR = pattern == 2 ? 0.12 : 0.04;
}
"""

const WATER: String = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
uniform vec4 deep : source_color = vec4(0.05, 0.42, 0.45, 0.88);
uniform vec4 foam : source_color = vec4(0.85, 0.98, 1.0, 0.95);
uniform float flow = 0.6;
uniform float stretch = 1.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	vec2 uv = UV * vec2(5.0, 3.0 * stretch);
	uv.y -= TIME * flow * stretch * 2.0;
	float streak = hash(vec2(floor(uv.x * 2.0), floor(uv.y * 0.7)));
	float band = smoothstep(0.62, 0.95, streak) * (0.6 + 0.4 * sin(uv.y * 3.0 + uv.x));
	vec4 colour = mix(deep, foam, clamp(band + smoothstep(0.75, 1.0, UV.y) * 0.8, 0.0, 1.0));
	ALBEDO = colour.rgb;
	ALPHA = colour.a * smoothstep(0.0, 0.08, UV.x) * smoothstep(1.0, 0.92, UV.x);
}
"""

## Soft additive cards: sun shafts through the canopy and glow halos.
const SHAFT: String = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add, shadows_disabled;
uniform vec4 colour : source_color = vec4(1.0, 0.86, 0.55, 0.2);
void vertex() {
	// Turn round the card's own up axis to face the camera (a beam of light).
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(normalize(cross(MODEL_MATRIX[1].xyz, INV_VIEW_MATRIX[2].xyz)) * length(MODEL_MATRIX[0].xyz), 0.0),
		MODEL_MATRIX[1],
		vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, MODEL_MATRIX[1].xyz)), 0.0),
		MODEL_MATRIX[3]);
}
void fragment() {
	float across = sin(UV.x * 3.14159);
	float along = smoothstep(0.0, 0.25, UV.y) * smoothstep(1.0, 0.5, UV.y);
	float pulse = 0.85 + 0.15 * sin(TIME * 0.6 + NODE_POSITION_WORLD.x);
	ALBEDO = colour.rgb * colour.a * across * across * along * pulse;
}
"""

const MIST: String = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;
uniform vec4 colour : source_color = vec4(0.82, 0.93, 0.9, 0.35);
void fragment() {
	vec2 c = UV - vec2(0.5);
	float soft = smoothstep(0.5, 0.05, length(c * vec2(1.0, 1.6)));
	float drift = 0.8 + 0.2 * sin(TIME * 0.4 + UV.x * 3.0);
	ALBEDO = colour.rgb;
	ALPHA = colour.a * soft * drift;
}
"""

const FLAME: String = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add, shadows_disabled;
void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float flicker = 0.85 + 0.15 * sin(TIME * 13.0 + world.x * 7.0) * sin(TIME * 7.3 + world.z);
	VERTEX.y *= flicker;
	VERTEX.xz *= 1.0 + 0.1 * sin(TIME * 9.0 + world.z * 3.0) * VERTEX.y;
}
void fragment() {
	ALBEDO = pow(COLOR.rgb, vec3(2.2)) * (0.6 + 1.6 * COLOR.a);
}
"""

## Unshaded glowing things (crystals, fireflies, sparks): colour plus a slow pulse.
const GLOW: String = """
shader_type spatial;
render_mode unshaded, shadows_disabled;
uniform float pulse = 0.0;
uniform float strength = 1.0;
void fragment() {
	float wave = 1.0 - pulse + pulse * (0.5 + 0.5 * sin(TIME * 2.3 + NODE_POSITION_WORLD.x * 0.7));
	ALBEDO = pow(COLOR.rgb, vec3(2.2)) * strength * wave;
}
"""

## Animals moved entirely on the GPU: INSTANCE_CUSTOM = (phase, radius, speed, kind).
## kind 0 butterfly (flutter around a bush), 1 bird (wide circles above the canopy),
## 2 firefly (slow wander, blinking), 3 leaf (drifting down and round again).
const FAUNA: String = """
shader_type spatial;
render_mode cull_disabled, shadows_disabled, unshaded;
varying float blink;
void vertex() {
	float phase = INSTANCE_CUSTOM.x * 6.2831;
	float radius = INSTANCE_CUSTOM.y * 20.0;
	float speed = INSTANCE_CUSTOM.z * 3.0;
	int kind = int(INSTANCE_CUSTOM.w * 4.0 + 0.5);
	float t = TIME * speed + phase;
	vec3 offset = vec3(0.0);
	vec3 v = VERTEX;
	blink = 1.0;
	if (kind == 0) {
		float flap = sin(TIME * 18.0 + phase) * 1.1 * COLOR.a;
		v.y += abs(v.x) * flap;
		v.x *= cos(flap);
		offset = vec3(sin(t) * radius, sin(t * 1.7) * 0.5 + 0.4 * sin(t * 3.1), cos(t * 0.8) * radius * 0.7);
		float heading = atan(cos(t) * radius, -sin(t * 0.8) * radius * 0.56);
		v = vec3(v.x * cos(heading) + v.z * sin(heading), v.y, -v.x * sin(heading) + v.z * cos(heading));
	} else if (kind == 1) {
		float flap = sin(TIME * 7.0 + phase) * 0.6 * COLOR.a;
		v.y += abs(v.x) * flap;
		offset = vec3(cos(t) * radius, sin(t * 0.5) * 2.0, sin(t) * radius);
		float heading = -t;
		v = vec3(v.x * cos(heading) + v.z * sin(heading), v.y, -v.x * sin(heading) + v.z * cos(heading));
	} else if (kind == 2) {
		offset = vec3(sin(t * 0.9) * radius, sin(t * 1.3) * 0.8, cos(t * 0.7) * radius);
		blink = 0.4 + 0.6 * smoothstep(0.2, 1.0, sin(TIME * 2.0 + phase * 3.0));
	} else {
		float fall = mod(t * 1.2, 12.0);
		offset = vec3(sin(t * 2.0) * 0.8, 6.0 - fall, cos(t * 1.4) * 0.8);
		float spin = t * 3.0;
		v = vec3(v.x * cos(spin) - v.y * sin(spin), v.x * sin(spin) + v.y * cos(spin), v.z);
	}
	VERTEX = v + offset;
}
void fragment() {
	vec3 base = pow(COLOR.rgb, vec3(2.2));
	ALBEDO = base * blink;
}
"""


static func material(code: String, params: Dictionary = {}) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = code
	var result := ShaderMaterial.new()
	result.shader = shader
	for key in params:
		result.set_shader_parameter(key, params[key])
	return result
