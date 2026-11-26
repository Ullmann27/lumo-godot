shader_type spatial;
// Signatur-Strecken (Vulkanexpress, Wolkensturm, Kristallflut): eine Fahrbahn, neun Beläge.
// UV = (Querlage m, Strecke m), UV2 = (halbe Breite m, Belag). Rein prozedural, keine
// Texturen. Jede Fahrbahn hat helle Randsteine und eine Mittellinie: immer lesbar.
// 0 Basalt-Asphalt  1 Steinbrücke  2 Holzplanken  3 Kristall-Obsidian  4 Holo-Glas
// 5 Skyway-Metall  6 Küstenstein  7 Glastunnel-Boden  8 Wolkenstraße
render_mode cull_disabled;

uniform vec3 asphalt : source_color = vec3(0.18, 0.17, 0.19);
uniform vec3 kerb_a : source_color = vec3(0.95, 0.30, 0.18);
uniform vec3 kerb_b : source_color = vec3(0.96, 0.94, 0.88);
uniform vec3 accent : source_color = vec3(1.0, 0.62, 0.22);
uniform float accent_glow = 1.4;

float hash_value(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float seam(float value, float period, float width) {
	float m = mod(value, period);
	float w = max(fwidth(value) * 1.2, width);
	return 1.0 - smoothstep(0.0, w, min(m, period - m));
}

float soft_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash_value(i);
	float b = hash_value(i + vec2(1.0, 0.0));
	float c = hash_value(i + vec2(0.0, 1.0));
	float d = hash_value(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	int surface = int(UV2.y + 0.5);
	float half_width = max(UV2.x, 1.0);
	float lat = UV.x;
	float along = UV.y;
	float footprint = max(fwidth(lat), fwidth(along));
	float fine = 1.0 - smoothstep(0.02, 0.09, footprint);
	float grain = (soft_noise(vec2(lat * 2.6, along * 0.7)) - 0.5) * fine;
	vec3 colour = asphalt * (0.94 + grain * 0.18);
	float rough = 0.78;
	float metal = 0.0;
	vec3 glow = vec3(0.0);
	if (surface == 1) {
		float row = floor(along / 0.9);
		vec2 stone = vec2(floor((lat + half_width + mod(row, 2.0) * 0.45) / 0.9), row);
		float joint = max(seam(lat + half_width + mod(row, 2.0) * 0.45, 0.9, 0.04), seam(along, 0.9, 0.04));
		colour = vec3(0.42, 0.38, 0.36) * (0.86 + hash_value(stone) * 0.22 + grain * 0.1);
		colour = mix(colour, vec3(0.16, 0.14, 0.14), joint * 0.8);
		rough = 0.86;
	} else if (surface == 2) {
		float plank = floor(along / 0.62);
		float tint = hash_value(vec2(plank, 3.0)) * 0.16;
		float gap = seam(along, 0.62, 0.025);
		colour = vec3(0.58, 0.38, 0.22) * (0.88 + tint + grain * 0.12);
		colour = mix(colour, vec3(0.12, 0.08, 0.06), gap * 0.9);
		rough = 0.7;
	} else if (surface == 3) {
		float vein = smoothstep(0.80, 0.97, soft_noise(vec2(lat * 0.55 + along * 0.08, along * 0.21)));
		colour = vec3(0.17, 0.13, 0.13) * (0.9 + grain * 0.2);
		glow += accent * vein * 0.85 * (0.75 + 0.25 * sin(TIME * 1.7 + along * 0.11));
		rough = 0.36;
		metal = 0.15;
	} else if (surface == 4) {
		float grid = max(seam(lat + half_width, 2.0, 0.03), seam(along - TIME * 6.0, 4.0, 0.04));
		colour = vec3(0.07, 0.12, 0.24) * (0.95 + grain * 0.1);
		glow += accent * grid * 0.75 * fine;
		rough = 0.12;
		metal = 0.35;
	} else if (surface == 5) {
		float panel = max(seam(lat + half_width, 3.2, 0.04), seam(along, 5.0, 0.04));
		colour = vec3(0.58, 0.62, 0.68) * (0.93 + grain * 0.06) - panel * 0.16;
		rough = 0.42;
		metal = 0.55;
	} else if (surface == 6) {
		float slab = hash_value(floor(vec2(lat + half_width, along) / vec2(1.6, 1.2)));
		float joint = max(seam(lat + half_width, 1.6, 0.04), seam(along, 1.2, 0.04));
		colour = vec3(0.66, 0.60, 0.50) * (0.88 + slab * 0.14 + grain * 0.1) - joint * 0.18;
		rough = 0.72;
	} else if (surface == 7) {
		float caustic = abs(sin(along * 0.55 + lat * 1.1 + TIME * 1.3) * sin(along * 0.37 - lat * 0.8 - TIME * 0.9));
		colour = vec3(0.13, 0.30, 0.36) * (0.92 + grain * 0.1);
		glow += vec3(0.30, 0.75, 0.85) * pow(caustic, 3.0) * 0.55 * fine;
		rough = 0.18;
		metal = 0.2;
	} else if (surface == 8) {
		float swirl = soft_noise(vec2(lat * 0.35, along * 0.12 - TIME * 0.4));
		colour = mix(vec3(0.78, 0.84, 0.95), vec3(0.95, 0.97, 1.0), swirl) * (0.95 + grain * 0.05);
		float grid = seam(along, 6.0, 0.05);
		glow += accent * grid * 0.35 * fine;
		rough = 0.65;
	}
	// Mittellinie (gestrichelt) und Randsteine: dieselbe Lesbarkeit auf jedem Belag.
	float dash = step(0.5, fract(along / 9.0)) * (1.0 - smoothstep(0.10, 0.18, abs(lat)));
	colour = mix(colour, vec3(0.97, 0.93, 0.80), dash * 0.82);
	float edge = smoothstep(half_width - 1.05, half_width - 0.9, abs(lat));
	float stripe = step(0.5, fract(along / 4.0));
	colour = mix(colour, mix(kerb_a, kerb_b, stripe), edge);
	float inner_line = (1.0 - smoothstep(0.06, 0.13, abs(abs(lat) - (half_width - 1.25))));
	glow += accent * inner_line * 0.6 * accent_glow;
	ALBEDO = colour;
	ROUGHNESS = rough;
	METALLIC = metal;
	EMISSION = glow;
}
