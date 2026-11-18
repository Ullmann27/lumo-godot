// Notenbahn: dunkles Glas mit Taktlinien, die im Liedtempo zur Ziellinie laufen.
shader_type spatial;

uniform vec4 base_color : source_color = vec4(0.07, 0.05, 0.16, 1.0);
uniform vec4 line_color : source_color = vec4(0.55, 0.75, 1.0, 1.0);
uniform float song_time = 0.0;
uniform float beat_len = 0.6;
uniform float speed = 8.0;
uniform float hit_z = 3.0;

varying vec3 w_pos;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float t = song_time + (hit_z - w_pos.z) / speed;
	float beats = t / beat_len;
	float f = fract(beats);
	float line = smoothstep(0.06, 0.0, min(f, 1.0 - f));
	float bar = mod(floor(beats + 0.5), 4.0) < 0.5 ? 1.0 : 0.45;
	float fade = clamp((w_pos.z + 33.0) / 14.0, 0.0, 1.0);
	float near_hit = 1.0 - smoothstep(0.0, 6.0, abs(w_pos.z - hit_z));
	ALBEDO = base_color.rgb;
	EMISSION = line_color.rgb * line * bar * fade * 0.9 + line_color.rgb * near_hit * 0.08;
	ROUGHNESS = 0.18;
	METALLIC = 0.2;
	SPECULAR = 0.7;
}
