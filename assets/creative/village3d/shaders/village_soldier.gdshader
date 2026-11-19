// LUMO Dorfwelt · Soldaten (Menschen, Pferde) aus dem Dorf-Atlas mit Bewegung ohne Skelett.
// Wie village_building.gdshader: UV = Kachelkoordinate, UV2 = Kachelmitte, COLOR.rgb = Tönung.
// COLOR.a trägt das Körperteil ((id + 0.5) / 16, 1.0 = starr): 1 Kopf, 2/3 Arm links/rechts,
// 4/5 Bein links/rechts, 6/7 Pferdebeine (diagonale Paare), 8 Pferdekopf, 9 Schweif.
// Flächen in Stadtfarbe sind in UV2.x um 0.02 verschoben (team_color färbt sie um),
// Metallflächen in UV2.y (glänzen).
// INSTANCE_CUSTOM (MultiMesh): r = Zustand / 8 (0 stehen, 1 marschieren, 2 Abwehr,
// 3 jubeln, 4 zurückweichen, 5 Waffen senken), g = Phase, b = Tempo-Streuung.
// Läuft in Mobile und gl_compatibility.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D atlas_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D atlas_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float normal_strength = 1.0;
uniform vec3 hip = vec3(0.095, 0.93, 0.0);
uniform vec3 shoulder = vec3(0.2, 1.42, -0.01);
uniform vec3 neck = vec3(0.0, 1.52, 0.005);
uniform vec2 arm_swing = vec2(0.25, 0.25);
uniform float seated = 0.0;
uniform vec4 team_color : source_color = vec4(0.18, 0.38, 0.77, 0.0);
uniform float state_override = -1.0;

varying vec2 tile;
varying float team;
varying float metal;

mat3 rot_x(float a) {
	float c = cos(a);
	float s = sin(a);
	return mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, c, s), vec3(0.0, -s, c));
}

mat3 rot_y(float a) {
	float c = cos(a);
	float s = sin(a);
	return mat3(vec3(c, 0.0, -s), vec3(0.0, 1.0, 0.0), vec3(s, 0.0, c));
}

mat3 rot_z(float a) {
	float c = cos(a);
	float s = sin(a);
	return mat3(vec3(c, s, 0.0), vec3(-s, c, 0.0), vec3(0.0, 0.0, 1.0));
}

void vertex() {
	tile = floor(UV2 * 4.0);
	team = step(0.04, abs(fract(UV2.x * 4.0) - 0.5));
	metal = step(0.04, abs(fract(UV2.y * 4.0) - 0.5));
	float part = floor(COLOR.a * 16.0);
	float state = floor(INSTANCE_CUSTOM.r * 8.0 + 0.5);
	if (state_override >= 0.0) {
		state = state_override;
	}
	float phase = INSTANCE_CUSTOM.g * 6.2831853;
	float tempo = 1.0 + (INSTANCE_CUSTOM.b - 0.5) * 0.16;
	float t = TIME * tempo + phase;
	float w = t * 5.4;
	float leg_l = 0.0;
	float leg_r = 0.0;
	float arm_l = sin(t * 1.1) * 0.025;
	float arm_r = -sin(t * 1.1) * 0.025;
	float arm_rz = 0.0;
	float head_yaw = sin(t * 0.37) * 0.28 * smoothstep(0.2, 0.8, sin(t * 0.13 + 1.0) * 0.5 + 0.5);
	float head_pitch = 0.0;
	float horse = 0.0;
	float bob = 0.0;
	float lean = 0.0;
	float breathe = sin(t * 1.7) * 0.007;
	if (state > 0.5 && state < 1.5) {
		leg_l = sin(w) * 0.42;
		leg_r = -sin(w) * 0.42;
		arm_l = -sin(w) * arm_swing.x;
		arm_r = sin(w) * arm_swing.y;
		horse = sin(w) * 0.42;
		bob = abs(cos(w)) * 0.035;
		head_yaw *= 0.3;
	} else if (state > 1.5 && state < 2.5) {
		arm_l = -0.55 + sin(t * 2.0) * 0.03;
		arm_r = -0.3 + sin(t * 3.1) * 0.05;
		leg_l = -0.16;
		leg_r = 0.2;
		lean = 0.09;
		head_yaw *= 0.2;
		horse = sin(t * 2.0) * 0.06;
	} else if (state > 2.5 && state < 3.5) {
		float hop = max(0.0, sin(t * 4.2));
		arm_r = -2.45 + sin(t * 4.2) * 0.22;
		arm_rz = -0.25;
		arm_l = -0.35;
		bob = hop * 0.14 * (1.0 - seated);
		head_pitch = -0.18;
		horse = sin(t * 4.2) * 0.12;
	} else if (state > 3.5 && state < 4.5) {
		float back = t * 3.4;
		leg_l = -sin(back) * 0.26;
		leg_r = sin(back) * 0.26;
		arm_l = 0.12;
		arm_r = 0.22;
		horse = -sin(back) * 0.3;
		bob = abs(cos(back)) * 0.02;
		head_pitch = 0.28;
		head_yaw *= 0.2;
	} else if (state > 4.5) {
		arm_l = -0.25;
		arm_r = -0.45;
		head_pitch = 0.42;
		lean = 0.12;
		head_yaw = 0.0;
	}
	vec3 v = VERTEX;
	mat3 r = mat3(1.0);
	vec3 pivot = vec3(0.0);
	bool moved = true;
	if (part == 1.0) {
		pivot = neck;
		r = rot_y(head_yaw) * rot_x(head_pitch);
	} else if (part == 2.0) {
		pivot = vec3(shoulder.x, shoulder.y, shoulder.z);
		r = rot_x(arm_l);
	} else if (part == 3.0) {
		pivot = vec3(-shoulder.x, shoulder.y, shoulder.z);
		r = rot_z(arm_rz) * rot_x(arm_r);
	} else if (part == 4.0 && seated < 0.5) {
		pivot = vec3(hip.x, hip.y, hip.z);
		r = rot_x(leg_l);
	} else if (part == 5.0 && seated < 0.5) {
		pivot = vec3(-hip.x, hip.y, hip.z);
		r = rot_x(leg_r);
	} else if (part == 6.0 || part == 7.0) {
		pivot = v.z > 0.0 ? vec3(0.0, 1.12, 0.48) : vec3(0.0, 1.16, -0.62);
		float swing = part == 6.0 ? horse : -horse;
		r = rot_x(swing);
	} else if (part == 8.0) {
		pivot = vec3(0.0, 1.45, 0.55);
		r = rot_x(sin(t * 1.3) * 0.05 + horse * 0.15) * rot_y(head_yaw * 0.5);
	} else if (part == 9.0) {
		pivot = vec3(0.0, 1.3, -0.75);
		r = rot_z(sin(t * 1.9) * 0.18);
	} else {
		moved = false;
	}
	if (moved) {
		v = pivot + r * (v - pivot);
		NORMAL = r * NORMAL;
		TANGENT = r * TANGENT;
		BINORMAL = r * BINORMAL;
	}
	// Atmen: der Oberkörper hebt sich leicht; Ganzkörper wippt und neigt sich.
	if (seated < 0.5 || part < 6.0 || part > 9.5) {
		float upper = smoothstep(hip.y, neck.y, v.y);
		v.y += upper * breathe * 0.6;
		v.x *= 1.0 + upper * breathe * 0.4;
	}
	mat3 l = rot_x(lean);
	v = l * v;
	NORMAL = l * NORMAL;
	v.y += bob;
	VERTEX = v;
}

void fragment() {
	vec2 local = fract(UV);
	vec2 auv = (tile + 0.012 + local * 0.976) * 0.25;
	vec2 gx = dFdx(UV) * 0.25 * 0.976;
	vec2 gy = dFdy(UV) * 0.25 * 0.976;
	vec4 albedo = textureGrad(atlas_albedo, auv, gx, gy);
	vec3 nrm = textureGrad(atlas_normal, auv, gx, gy).rgb;
	vec3 col = albedo.rgb * COLOR.rgb * 2.0;
	if (team > 0.5 && team_color.a > 0.0) {
		float lum = dot(col, vec3(0.299, 0.587, 0.114));
		col = mix(col, team_color.rgb * lum * 3.2, team_color.a);
	}
	ALBEDO = col;
	NORMAL_MAP = nrm;
	NORMAL_MAP_DEPTH = normal_strength;
	ROUGHNESS = mix(0.84, 0.32, metal);
	SPECULAR = mix(0.3, 0.65, metal);
	RIM = metal * 0.15;
	RIM_TINT = 0.5;
}
