// LUMO Dorfwelt · Geländeschicht (Eigenbau).
// Gras, Erde/Wege, Fels, Sand und Schnee werden nach Höhe, Neigung und einer
// zur Laufzeit gemalten Wegekarte gemischt. Läuft im Mobile- und im
// gl_compatibility-Renderer: keine Bildschirm- oder Tiefentextur.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D grass_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D noise_map : filter_linear_mipmap, repeat_enable;
// R = Weg/Erde, G = Feld/Bauplatz; deckt beide Ortsteile ab.
uniform sampler2D paint_map : filter_linear, repeat_disable;
uniform vec4 paint_rect = vec4(-192.0, -96.0, 384.0, 192.0);
uniform float water_level = -1.1;
uniform float snow_height = 44.0;
uniform float cloud_shadow : hint_range(0.0, 1.0) = 0.32;
uniform vec2 cloud_wind = vec2(0.0045, 0.0018);
uniform float detail_strength : hint_range(0.0, 2.0) = 1.0;
uniform vec4 grass_tint : source_color = vec4(0.84, 0.92, 0.74, 1.0);

varying vec3 world_pos;
varying vec3 world_nrm;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec3 triplanar_rock(vec3 p, vec3 n) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	vec3 x = texture(rock_albedo, p.zy * 0.11).rgb;
	vec3 y = texture(rock_albedo, p.xz * 0.11).rgb;
	vec3 z = texture(rock_albedo, p.xy * 0.11).rgb;
	return x * w.x + y * w.y + z * w.z;
}

void fragment() {
	vec2 p = world_pos.xz;
	vec3 noise_far = texture(noise_map, p * 0.0021).rgb;
	vec3 noise_near = texture(noise_map, p * 0.019).rgb;
	float macro = noise_far.g;
	float breakup = noise_near.b - 0.5;

	vec3 g1 = texture(grass_albedo, p * 0.23).rgb;
	vec3 g2 = texture(grass_albedo, p * 0.057 + vec2(0.37, 0.71)).rgb;
	vec3 grass = mix(g1, g2, 0.4);
	grass *= mix(vec3(0.72, 0.88, 0.64), vec3(1.12, 1.06, 0.80), smoothstep(0.2, 0.8, macro));
	grass *= mix(1.0, 0.9, smoothstep(0.55, 0.85, noise_near.g));
	grass *= grass_tint.rgb;
	vec3 dirt = texture(dirt_albedo, p * 0.21).rgb;
	vec3 sand = texture(sand_albedo, p * 0.17).rgb;
	vec3 rock = triplanar_rock(world_pos, world_nrm);
	rock *= mix(vec3(0.92, 0.9, 0.86), vec3(1.06, 1.02, 0.95), macro);

	float slope = 1.0 - world_nrm.y;
	float h = world_pos.y;
	float rock_w = smoothstep(0.16, 0.30, slope + breakup * 0.10);
	rock_w = max(rock_w, smoothstep(30.0, 52.0, h + breakup * 12.0) * 0.6);
	float sand_w = 1.0 - smoothstep(water_level + 0.55, water_level + 1.5, h + breakup * 0.9);
	float snow_w = smoothstep(snow_height - 5.0, snow_height + 5.0, h + breakup * 16.0 + macro * 8.0)
		* (1.0 - smoothstep(0.42, 0.66, slope));

	vec2 puv = (p - paint_rect.xy) / paint_rect.zw;
	vec4 paint = vec4(0.0);
	if (puv.x > 0.0 && puv.y > 0.0 && puv.x < 1.0 && puv.y < 1.0) {
		paint = texture(paint_map, puv);
	}
	float path_w = smoothstep(0.18, 0.6, paint.r + breakup * 0.35);
	float yard_w = smoothstep(0.2, 0.7, paint.g + breakup * 0.3) * 0.55;

	vec3 col = grass;
	col = mix(col, mix(grass, dirt, 0.65), yard_w);
	vec3 path = mix(dirt, vec3(dot(dirt, vec3(0.33))) * vec3(1.05, 0.98, 0.88), 0.45);
	col = mix(col, path, path_w * 0.92);
	col = mix(col, sand, sand_w);
	col = mix(col, rock, rock_w);
	col = mix(col, vec3(0.93, 0.95, 0.98) * (0.92 + noise_near.r * 0.1), snow_w);
	// Wet, darker ground under the waterline: the river bed reads as depth.
	float under = smoothstep(water_level + 0.05, water_level - 2.2, h);
	col = mix(col, col * vec3(0.42, 0.55, 0.58), under);

	float clouds = texture(noise_map, p * 0.0042 + TIME * cloud_wind).r;
	float shade = 1.0 - cloud_shadow * smoothstep(0.52, 0.7, clouds);

	vec3 n_grass = texture(grass_normal, p * 0.23).rgb;
	vec3 n_rock = texture(rock_normal, p * 0.11 + vec2(world_pos.y * 0.07, 0.0)).rgb;
	vec3 n = mix(n_grass, n_rock, max(rock_w, snow_w * 0.4));
	n = mix(n, vec3(0.5, 0.5, 1.0), path_w * 0.4 + snow_w * 0.5);

	ALBEDO = col * COLOR.rgb * shade;
	NORMAL_MAP = n;
	NORMAL_MAP_DEPTH = detail_strength * mix(0.9, 1.6, rock_w);
	ROUGHNESS = mix(mix(0.93, 0.86, rock_w), 0.62, snow_w);
	SPECULAR = mix(0.25, 0.45, snow_w);
}
