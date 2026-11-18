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
	EMISSION = base * 0.16;
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
	// A small floor keeps shaded stone and wood readable in the deep jungle.
	EMISSION = base * (glow + 0.10);
}
"""

## Path decks and terrain: one shader, the pattern picks earth (0), planks (1),
## flagstones (2) or cave rock (3). Textures are the generated jungle maps
## (forest floor, moss, wood, sandstone, stone), mapped in world space so the
## long ribbons never stretch them. Vertex colour says how grassy a spot is.
const GROUND: String = """
shader_type spatial;
render_mode specular_schlick_ggx;
uniform int pattern = 0;
uniform vec3 tint : source_color = vec3(1.0);
uniform sampler2D ground_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ground_nrm : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D moss_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D moss_nrm : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D detail_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D detail_nrm : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float flecks = 0.15;
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
	float green = clamp((COLOR.g - COLOR.r) * 5.0 + 0.1, 0.0, 1.0);
	vec3 albedo;
	vec3 nrm;
	float rough = 0.95;
	if (pattern == 1) {
		// Planks across the path: wood grain across, dark seams, each plank its own shade.
		float along = UV.y * 2.6;
		float id = floor(along);
		float plank = fract(along);
		float seam = smoothstep(0.0, 0.07, plank) * smoothstep(1.0, 0.93, plank);
		vec2 wuv = vec2(plank * 0.38 + hash(vec2(id, 4.0)), UV.x * 0.55 + hash(vec2(id, 9.0)));
		vec3 wood = texture(detail_tex, wuv).rgb;
		albedo = wood * (0.75 + 0.45 * hash(vec2(id, 1.0))) * (0.45 + 0.55 * seam) * mix(vec3(1.0), base * 2.2, 0.25);
		nrm = texture(detail_nrm, wuv).rgb;
		rough = 0.82;
	} else if (pattern == 2) {
		// Old flagstones with moss in the joints.
		vec2 cell = vec2(UV.x * 2.2, UV.y * 0.9);
		cell.x += 0.5 * floor(cell.y);
		vec2 f = fract(cell);
		float joint = smoothstep(0.0, 0.08, f.x) * smoothstep(1.0, 0.92, f.x) * smoothstep(0.0, 0.08, f.y) * smoothstep(1.0, 0.92, f.y);
		vec2 suv = cell * 0.45 + vec2(hash(floor(cell)), hash(floor(cell) + 3.0));
		vec3 stone = texture(detail_tex, suv).rgb * (0.85 + 0.25 * hash(floor(cell) + 7.0));
		vec3 moss = texture(moss_tex, world.xz * 0.6).rgb;
		float mossy = clamp(1.0 - joint + green * 0.35 * noise(world.xz * 0.7), 0.0, 1.0);
		albedo = mix(stone, moss, mossy);
		nrm = mix(texture(detail_nrm, suv).rgb, texture(moss_nrm, world.xz * 0.6).rgb, mossy);
		rough = 0.8;
	} else if (pattern == 3) {
		vec2 cuv = world.xz * 0.28;
		albedo = texture(detail_tex, cuv).rgb * mix(vec3(1.0), base * 2.5, 0.35);
		vec3 moss = texture(moss_tex, world.xz * 0.5).rgb * vec3(0.6, 0.85, 0.8);
		albedo = mix(albedo, moss, green * 0.6);
		nrm = texture(detail_nrm, cuv).rgb;
		rough = 0.7;
	} else {
		vec2 guv = world.xz * 0.3;
		vec3 earth = texture(ground_tex, guv).rgb;
		vec3 moss = texture(moss_tex, world.xz * 0.45).rgb * vec3(0.6, 0.72, 0.5);
		float patchy = clamp(green * 0.5 + (noise(world.xz * 0.35) - 0.5) * 1.1 + (noise(world.xz * 0.07) - 0.5) * 0.6, 0.0, 1.0);
		albedo = mix(earth, moss, patchy);
		albedo = mix(albedo, base * 0.8, 0.12);
		nrm = mix(texture(ground_nrm, guv).rgb, texture(moss_nrm, world.xz * 0.45).rgb, patchy);
	}
	// Sun flecks drifting over the floor: light falling through the canopy.
	float fleck = smoothstep(0.62, 0.82, noise(world.xz * 0.21 + vec2(TIME * 0.035, TIME * 0.02)) * 0.7 + noise(world.xz * 0.9) * 0.3);
	albedo *= 1.0 + fleck * flecks;
	ALBEDO = albedo;
	NORMAL_MAP = nrm;
	NORMAL_MAP_DEPTH = 0.9;
	ROUGHNESS = rough;
	SPECULAR = pattern == 2 ? 0.25 : 0.12;
	EMISSION = albedo * fleck * flecks * 0.25;
}
"""

const WATER: String = """
shader_type spatial;
render_mode cull_disabled, depth_draw_never, blend_mix, specular_schlick_ggx;
uniform vec4 deep : source_color = vec4(0.04, 0.32, 0.36, 0.86);
uniform vec4 foam : source_color = vec4(0.85, 0.98, 1.0, 0.95);
uniform float flow = 0.6;
uniform float stretch = 1.0;
uniform float lit = 1.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float waves(vec2 p, float t) {
	return noise(p * 1.7 + vec2(0.0, -t * 1.3)) * 0.6 + noise(p * 4.1 + vec2(t * 0.7, -t * 2.1)) * 0.4;
}
void fragment() {
	vec2 uv = UV * vec2(5.0, 3.0 * stretch);
	float t = TIME * flow * stretch;
	vec2 moving = uv - vec2(0.0, t * 2.0);
	float streak = hash(vec2(floor(moving.x * 2.0), floor(moving.y * 0.7)));
	float band = smoothstep(0.62, 0.95, streak) * (0.6 + 0.4 * sin(moving.y * 3.0 + moving.x));
	float h0 = waves(uv, t);
	float hx = waves(uv + vec2(0.05, 0.0), t);
	float hy = waves(uv + vec2(0.0, 0.05), t);
	NORMAL_MAP = normalize(vec3((h0 - hx) * 6.0, (h0 - hy) * 6.0, 1.0)) * 0.5 + 0.5;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec4 colour = mix(deep, foam, clamp(band * 0.8 + smoothstep(0.75, 1.0, UV.y) * 0.8, 0.0, 1.0));
	ALBEDO = colour.rgb * mix(1.0, 0.6, lit);
	ROUGHNESS = mix(0.05, 0.35, band);
	METALLIC = 0.0;
	SPECULAR = 0.9;
	EMISSION = colour.rgb * (1.0 - lit) + colour.rgb * 0.25 * lit + vec3(0.55, 0.75, 0.8) * rim * 0.35;
	ALPHA = clamp(colour.a + rim * 0.2, 0.0, 1.0) * smoothstep(0.0, 0.08, UV.x) * smoothstep(1.0, 0.92, UV.x);
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
	// 4: ember (w = 1.0)
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
	} else if (kind == 4) {
		// Embers rising from a torch, fading as they climb.
		float rise = mod(t * 0.9, 1.0);
		offset = vec3(sin(t * 3.1 + phase) * 0.12 * rise, rise * 1.4, cos(t * 2.3 + phase) * 0.12 * rise);
		blink = (1.0 - rise) * (0.6 + 0.4 * sin(TIME * 20.0 + phase * 9.0)) * 3.0;
		v *= 1.0 - rise * 0.6;
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


## Leaf cards of the GLB plants (alpha-cut atlas). Wind: UV2.x is how much a
## corner sways (0 at the trunk, 1 at a leaf tip), UV2.y a phase. The crown
## normals face out on both sides of a card; light shines through (BACKLIGHT)
## and the rim catches the sun.
const LEAF: String = """
shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_disable;
uniform float alpha_cut = 0.42;
uniform float sway = 1.0;
uniform float translucency = 0.55;
uniform float variation = 0.35;
uniform float brightness = 1.0;
uniform float flutter = 1.0;
// Lumo's chest in world space (set every frame): leaves between the camera and
// Lumo, and leaves right in front of the lens, are cut away so the child always
// sees Lumo and the path.
global uniform vec3 jungle_focus;
varying float leaf_rand;
varying vec3 leaf_world;
void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float w = UV2.x * sway;
	float t = TIME * 1.15 + origin.x * 0.21 + origin.z * 0.17;
	vec3 gust = vec3(sin(t) + 0.35 * sin(t * 2.7), 0.0, cos(t * 0.83) + 0.3 * sin(t * 2.1)) * 0.07 * w;
	float f = TIME * 4.7 + UV2.y * 37.0 + origin.x * 1.3;
	VERTEX += gust + NORMAL * sin(f) * 0.035 * w * flutter;
	leaf_rand = fract(UV2.y * 7.13 + origin.x * 0.37 + origin.z * 0.91);
	leaf_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec4 tex = texture(albedo_tex, UV);
	vec3 eye = INV_VIEW_MATRIX[3].xyz;
	vec3 ray = jungle_focus - eye;
	float along = clamp(dot(leaf_world - eye, ray) / max(dot(ray, ray), 0.01), 0.0, 1.0);
	float off = length(leaf_world - (eye + ray * along));
	float clear = along < 0.97 ? smoothstep(0.7 + along * 0.6, 1.5 + along * 0.9, off) : 1.0;
	clear *= smoothstep(1.2, 3.2, length(VERTEX));
	ALPHA = tex.a * clear;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	vec3 col = tex.rgb;
	// Each card a little different: fresh yellow-green, deep blue-green or sun-dried.
	vec3 fresh = vec3(1.18, 1.12, 0.62);
	vec3 deep = vec3(0.78, 0.92, 0.95);
	col *= mix(mix(deep, vec3(1.0), smoothstep(0.0, 0.5, leaf_rand)), fresh, smoothstep(0.6, 1.0, leaf_rand) * variation * 2.0);
	col *= COLOR.rgb * brightness;
	ALBEDO = col;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = 0.6;
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	ROUGHNESS = 0.55;
	SPECULAR = 0.35;
	BACKLIGHT = col * translucency * vec3(1.1, 1.25, 0.7);
	RIM = 0.25;
	RIM_TINT = 0.6;
}
"""

## Everything solid from the GLBs: bark, wood, stone, sandstone, iron, paint.
## Textured or plain, optional moss on upward faces, optional world-space
## mapping for parts that are stretched per instance (posts, beams, blocks),
## optional wind (UV2) for trunks and stems.
const SURFACE: String = """
shader_type spatial;
render_mode specular_schlick_ggx;
uniform vec4 base_color : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D moss_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_tex = false;
uniform bool world_mapping = false;
uniform float world_scale = 0.5;
uniform float normal_depth = 1.0;
uniform float roughness_value = 0.85;
uniform float metallic_value = 0.0;
uniform float moss_amount = 0.0;
uniform float sway = 0.0;
uniform float floor_light = 0.05;
uniform float vertex_tint = 1.0;
uniform vec3 emission_color : source_color = vec3(0.0);
uniform float emission_energy = 0.0;
varying vec3 world_pos;
varying vec3 world_nrm;
void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	if (sway > 0.0) {
		vec3 origin = MODEL_MATRIX[3].xyz;
		float t = TIME * 1.15 + origin.x * 0.21 + origin.z * 0.17;
		VERTEX += vec3(sin(t) + 0.35 * sin(t * 2.7), 0.0, cos(t * 0.83)) * 0.07 * UV2.x * sway;
	}
}
void fragment() {
	vec3 albedo = base_color.rgb;
	if (use_tex) {
		vec2 uv = UV;
		if (world_mapping) {
			vec3 n = abs(world_nrm);
			uv = n.y > max(n.x, n.z) ? world_pos.xz : (n.x > n.z ? world_pos.zy : world_pos.xy);
			uv *= world_scale;
		}
		albedo *= texture(albedo_tex, uv).rgb;
		NORMAL_MAP = texture(normal_tex, uv).rgb;
		NORMAL_MAP_DEPTH = normal_depth;
	}
	albedo *= mix(vec3(1.0), COLOR.rgb, vertex_tint);
	float rough = roughness_value;
	if (moss_amount > 0.0) {
		vec3 moss = texture(moss_tex, world_pos.xz * 0.6 + world_pos.y * 0.3).rgb;
		float lumps = dot(moss, vec3(0.3, 0.6, 0.1));
		float mask = smoothstep(0.42, 0.78, world_nrm.y + (lumps - 0.35) * 0.9) * moss_amount;
		albedo = mix(albedo, moss, mask);
		rough = mix(rough, 1.0, mask);
	}
	ALBEDO = albedo;
	ROUGHNESS = rough;
	METALLIC = metallic_value;
	SPECULAR = 0.35;
	// A small floor keeps shaded stone and wood readable in the deep jungle.
	EMISSION = albedo * floor_light + emission_color * emission_energy;
}
"""

## Crystals and lantern glass: lit, glossy, glowing from inside with a slow pulse.
const CRYSTAL: String = """
shader_type spatial;
render_mode specular_schlick_ggx, shadows_disabled;
uniform vec4 base_color : source_color = vec4(0.6, 0.95, 1.0, 1.0);
uniform vec3 emission_color : source_color = vec3(0.4, 0.9, 1.0);
uniform float strength = 1.4;
uniform float pulse = 0.35;
void fragment() {
	float wave = 1.0 - pulse + pulse * (0.5 + 0.5 * sin(TIME * 2.3 + NODE_POSITION_WORLD.x * 0.7 + NODE_POSITION_WORLD.z * 0.3));
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	vec3 tint = COLOR.rgb;
	ALBEDO = base_color.rgb * tint * 0.5;
	ROUGHNESS = 0.08;
	METALLIC = 0.1;
	SPECULAR = 0.8;
	EMISSION = emission_color * tint * strength * wave * (0.55 + rim * 1.2);
}
"""

## Flower petals: the blossom colour comes per instance in INSTANCE_CUSTOM.
const PETAL: String = """
shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;
uniform float sway = 1.0;
varying vec3 blossom;
void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float t = TIME * 1.15 + origin.x * 0.21 + origin.z * 0.17;
	VERTEX += vec3(sin(t), 0.0, cos(t * 0.83)) * 0.05 * UV2.x * sway;
	blossom = INSTANCE_CUSTOM.a > 0.0 ? INSTANCE_CUSTOM.rgb : vec3(1.0, 0.45, 0.6);
}
void fragment() {
	vec3 col = pow(blossom, vec3(2.2)) * COLOR.rgb;
	ALBEDO = col;
	ROUGHNESS = 0.45;
	BACKLIGHT = col * 0.6;
	EMISSION = col * 0.12;
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
