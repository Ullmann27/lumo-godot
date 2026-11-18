// Lumo-Kart-Kulisse: Blaetter, Rinde und Felsen in EINEM Material (ein Zeichenaufruf
// je MultiMesh). Wind, Durchlicht, Farbvariation je Instanz. Mobile- und
// gl_compatibility-tauglich: keine Bildschirm-/Tiefentextur, nur 2 Texturzugriffe
// je Pixel (Blatt: Farbe+Normal, Rinde: Farbe+Normal, Fels: triplanar Farbe).
// Kodierung siehe tools/lumo_kart_art/scenery/build_scenery_models.py.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform sampler2D foliage_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D foliage_normal : hint_normal, filter_linear_mipmap, repeat_disable;
uniform sampler2D bark_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D bark_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap, repeat_enable;

uniform vec3 wind_direction = vec3(1.0, 0.0, 0.35);
uniform float wind_strength : hint_range(0.0, 2.0) = 0.55;
uniform float wind_speed : hint_range(0.0, 4.0) = 1.0;
// Richtung, in die das Sonnenlicht faellt (Weltraum) und seine Farbe.
uniform vec3 sun_direction = vec3(-0.5, -0.6, -0.6);
uniform vec4 sun_color : source_color = vec4(1.0, 0.95, 0.85, 1.0);
uniform float translucency : hint_range(0.0, 2.0) = 0.65;
uniform float leaf_saturation : hint_range(0.0, 2.0) = 1.0;
uniform vec4 leaf_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 bark_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float snow_cover : hint_range(0.0, 1.0) = 0.0;
uniform float leaf_glow : hint_range(0.0, 2.0) = 0.0;
uniform vec4 leaf_glow_color : source_color = vec4(0.4, 1.0, 0.85, 1.0);
// 0 auf LOW: keine Normalen-Texturen, kein Flattern.
uniform float detail : hint_range(0.0, 1.0) = 1.0;
// Himmelslicht-Aufhellung im Schatten (Blaetter sind sonst zu dunkel).
uniform vec4 fill_color : source_color = vec4(0.75, 0.85, 0.95, 1.0);
uniform float fill : hint_range(0.0, 1.0) = 0.16;
uniform float alpha_cut : hint_range(0.05, 0.95) = 0.42;

varying float v_mode;
varying vec3 v_local;
varying vec3 v_local_normal;
varying vec4 v_tint;
varying float v_ao;
varying float v_height;

void vertex() {
	// UV2.y: 0 Blatt, 1 Rinde, 2 Fels
	v_mode = UV2.y;
	v_tint = INSTANCE_CUSTOM;
	v_ao = COLOR.b;
	v_local = VERTEX;
	v_local_normal = NORMAL;
	vec3 origin = MODEL_MATRIX[3].xyz;
	float phase = dot(origin.xz, vec2(0.071, 0.113)) + INSTANCE_CUSTOM.a * 6.2831;
	float t = TIME * wind_speed;
	float gust = 0.55 + 0.45 * sin(t * 0.37 + origin.x * 0.013 + origin.z * 0.009);
	float sway = (sin(t * 1.1 + phase) * 0.65 + sin(t * 2.3 + phase * 1.7) * 0.25) * gust;
	float bend = COLOR.r * COLOR.r * wind_strength;
	// Schwanken der ganzen Krone (lokal, damit Stamm und Blaetter zusammenpassen)
	vec3 wind_local = normalize(normalize(wind_direction) * mat3(MODEL_MATRIX));
	VERTEX += wind_local * sway * bend * 0.28 * (0.6 + 0.4 * VERTEX.y / max(1.0, VERTEX.y + 2.0));
	// Blattflattern: kleine, schnelle Bewegung je Buendel
	if (v_mode < 0.5) {
		float flutter = sin(t * 7.3 + COLOR.g * 40.0 + VERTEX.y * 2.0) * COLOR.r * 0.035 * detail;
		VERTEX += NORMAL * flutter * (0.5 + gust);
	}
	v_height = VERTEX.y;
}

vec3 triplanar(sampler2D tex, vec3 p, vec3 n) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	return texture(tex, p.zy * 0.45).rgb * w.x + texture(tex, p.xz * 0.45).rgb * w.y
		+ texture(tex, p.xy * 0.45).rgb * w.z;
}

void fragment() {
	vec3 world_normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 albedo;
	float alpha = 1.0;
	float rough = 0.85;
	float trans = 0.0;
	if (v_mode < 0.5) {
		vec4 leaf = texture(foliage_albedo, UV);
		alpha = leaf.a;
		// Farbvariation je Instanz (INSTANCE_CUSTOM.rgb) und je Buendel (Phase)
		vec3 tint = mix(vec3(1.0), v_tint.rgb * 2.0, 0.85);
		albedo = leaf.rgb * tint * leaf_tint.rgb;
		float gray = dot(albedo, vec3(0.299, 0.587, 0.114));
		albedo = mix(vec3(gray), albedo, leaf_saturation);
		if (detail > 0.5) {
			NORMAL_MAP = texture(foliage_normal, UV).rgb;
			NORMAL_MAP_DEPTH = 0.7;
		}
		rough = 0.62;
		trans = 1.0;
		if (FRONT_FACING == false) {
			// Rueckseite etwas heller/gelblicher, wie echte Blattunterseiten
			albedo *= vec3(1.06, 1.08, 0.92);
		}
	} else if (v_mode < 1.5) {
		// Rinde: Streifen UV2.x, horizontal per fract gekachelt (textureGrad gegen Naht-Mip)
		vec2 tiled = vec2(UV2.x + fract(UV.x) * 0.25, UV.y);
		vec2 gx = dFdx(vec2(UV.x * 0.25, UV.y));
		vec2 gy = dFdy(vec2(UV.x * 0.25, UV.y));
		albedo = textureGrad(bark_albedo, tiled, gx, gy).rgb * bark_tint.rgb;
		albedo *= mix(vec3(1.0), v_tint.rgb * 2.0, 0.35);
		if (detail > 0.5) {
			NORMAL_MAP = textureGrad(bark_normal, tiled, gx, gy).rgb;
			NORMAL_MAP_DEPTH = 1.4;
		}
		rough = 0.92;
	} else {
		albedo = triplanar(rock_albedo, v_local, normalize(v_local_normal)) * v_tint.rgb * 2.0;
		if (detail > 0.5) {
			vec3 w = pow(abs(normalize(v_local_normal)), vec3(4.0));
			w /= (w.x + w.y + w.z);
			NORMAL_MAP = texture(rock_normal, v_local.xz * 0.45).rgb * w.y
				+ texture(rock_normal, v_local.zy * 0.45).rgb * w.x
				+ texture(rock_normal, v_local.xy * 0.45).rgb * w.z;
			NORMAL_MAP_DEPTH = 1.1;
		}
		// Moos/Staub oben
		albedo = mix(albedo, albedo * vec3(0.78, 0.92, 0.62), smoothstep(0.55, 0.9, world_normal.y) * 0.45);
		rough = 0.88;
	}
	// Schnee auf nach oben zeigenden Flaechen
	float snow = snow_cover * smoothstep(0.25, 0.75, world_normal.y + (v_mode < 0.5 ? 0.15 : 0.0));
	albedo = mix(albedo, vec3(0.93, 0.96, 1.0), snow);
	float ao = mix(1.0, v_ao, 0.85);
	ALBEDO = albedo * (0.7 + 0.3 * ao);
	AO = ao;
	AO_LIGHT_AFFECT = 0.2;
	ROUGHNESS = mix(rough, 0.55, snow);
	SPECULAR = 0.32;
	ALPHA = alpha;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	// Durchlicht: Blick gegen die Sonne laesst Blaetter warm aufleuchten.
	vec3 view_world = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	float back = pow(clamp(dot(view_world, normalize(sun_direction)), 0.0, 1.0), 3.0);
	float wrap = clamp(dot(world_normal, -normalize(sun_direction)) * -0.5 + 0.5, 0.0, 1.0);
	EMISSION = trans * albedo * sun_color.rgb * translucency * (back * 0.9 + wrap * 0.12) * ao;
	EMISSION += albedo * fill_color.rgb * fill * (0.4 + 0.6 * ao);
	EMISSION += trans * leaf_glow * leaf_glow_color.rgb * smoothstep(0.55, 0.9, albedo.b - albedo.r + 0.35) * 0.6;
}
