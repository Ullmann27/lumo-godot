// LUMO Dorfwelt · Fluss, See und Küste (Eigenbau).
// Tiefe und Uferschaum kommen aus einer Tiefenkarte, die aus der Höhenkarte
// gebaut wird; keine Bildschirm-/Tiefentextur, daher Mobile/gl_compat-fähig.
// Spiegelung wird durch Himmelsfarbe nach Fresnel ersetzt (Reflex-Ersatz).
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D water_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D depth_map : filter_linear, repeat_disable;
uniform sampler2D noise_map : filter_linear_mipmap, repeat_enable;
uniform vec4 depth_rect = vec4(-320.0, -240.0, 640.0, 480.0);
uniform vec4 shallow_color : source_color = vec4(0.30, 0.66, 0.62, 1.0);
uniform vec4 deep_color : source_color = vec4(0.05, 0.25, 0.40, 1.0);
uniform vec4 sky_color : source_color = vec4(0.62, 0.78, 0.92, 1.0);
uniform vec4 foam_color : source_color = vec4(0.93, 0.97, 0.98, 1.0);
uniform float wave_strength : hint_range(0.0, 2.0) = 1.0;
uniform float reflection_strength : hint_range(0.0, 1.0) = 0.55;
uniform float river_x_amplitude = 2.4;
uniform float sea_swell : hint_range(0.0, 1.0) = 1.0;

varying vec3 world_pos;

float river_center(float z) {
	return 2.4 * sin(z * 0.021) + 1.5 * sin(z * 0.057 + 1.3);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// Gentle swell on the open sea only (the river surface stays level).
	float sea = smoothstep(110.0, 160.0, world_pos.z);
	float swell = sin(world_pos.x * 0.05 + TIME * 0.7) * cos(world_pos.z * 0.04 - TIME * 0.5);
	VERTEX.y += swell * 0.22 * sea * sea_swell;
	world_pos.y += swell * 0.22 * sea * sea_swell;
}

void fragment() {
	vec2 p = world_pos.xz;
	vec2 duv = (p - depth_rect.xy) / depth_rect.zw;
	float depth = 1.0;
	if (duv.x > 0.0 && duv.y > 0.0 && duv.x < 1.0 && duv.y < 1.0) {
		depth = texture(depth_map, duv).r;
	}
	// River flows south to the sea; lakes and sea drift slowly.
	float in_river = (1.0 - smoothstep(9.0, 14.0, abs(p.x - river_center(p.y))))
		* (1.0 - smoothstep(100.0, 130.0, p.y));
	vec2 flow = mix(vec2(0.012, 0.008), vec2(0.0, 0.11), in_river);
	vec3 n1 = texture(water_normal, p * 0.045 + TIME * flow).rgb;
	vec3 n2 = texture(water_normal, p * 0.11 - TIME * flow.yx * 0.7 + vec2(0.3, 0.6)).rgb;
	vec3 n = normalize(mix(n1, n2, 0.5) * 2.0 - 1.0);
	n.xy *= wave_strength;

	float d = clamp(depth, 0.0, 1.0);
	vec3 col = mix(shallow_color.rgb, deep_color.rgb, pow(d, 0.55));
	// Fake reflection: sky colour by Fresnel, sun glitter by specular.
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL + vec3(n.x, 0.0, n.y) * 0.3), VIEW), 0.0, 1.0), 4.0);
	col = mix(col, sky_color.rgb, fres * reflection_strength);

	float shore = 1.0 - smoothstep(0.0, 0.06, d);
	float foam_noise = texture(noise_map, p * 0.09 + vec2(TIME * 0.03, -TIME * 0.02)).b;
	float foam = shore * smoothstep(0.35, 0.7, foam_noise + shore * 0.45);
	// Little white water where the river meets stones and bridge piers.
	foam += in_river * smoothstep(0.78, 0.92, foam_noise) * 0.25;
	col = mix(col, foam_color.rgb, clamp(foam, 0.0, 0.85));

	float cloud = texture(noise_map, p * 0.0042 + TIME * vec2(0.0045, 0.0018)).r;
	col *= 1.0 - 0.25 * smoothstep(0.52, 0.7, cloud);

	ALBEDO = col;
	NORMAL_MAP = vec3(n.xy * 0.5 + 0.5, 1.0);
	NORMAL_MAP_DEPTH = 0.9;
	ROUGHNESS = mix(0.06, 0.4, clamp(foam, 0.0, 1.0));
	METALLIC = 0.0;
	SPECULAR = 0.75;
}
