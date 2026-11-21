shader_type spatial;
// Lumos Riesengarten – eine Fahrbahn, neun Beläge (UV2.y = Belag, UV2.x = halbe Breite).
// UV = (Querlage m, Strecke m). Rein prozedural, keine Texturen; Kanten hell und lesbar.
// 0 Holzbank-Planken  1 Gartenplatten  2 Zinkblech (Gießkanne)  3 Wasserrutsche
// 4 Riesen-Seerosenblätter  5 Schlauchwand (grün)  6 Terrakotta  7 Schwellen  8 Glashausfliesen
render_mode cull_disabled;

uniform float wet = 0.0;
// Nasse Stellen der zweiten Runde (Rasensprenger, Gewächshaus): x = von, y = bis (Meter
// auf der Strecke), z = Stärke 0..1. Nass heißt nur glänzender und dunkler – nie glatter.
uniform vec4 wet_zones[6];

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
	float grain = (soft_noise(vec2(lat * 3.0, along * 0.6)) - 0.5) * fine;
	vec3 colour = vec3(0.62, 0.46, 0.30);
	float rough = 0.78;
	float metal = 0.0;
	if (surface == 0) {
		float board = floor((lat + half_width) / 1.35);
		float tint = hash_value(vec2(board, floor(along / 9.0))) * 0.14;
		float lines = seam(lat + half_width, 1.35, 0.03) + seam(along + board * 3.1, 9.0, 0.03) * 0.8;
		float rings = sin(along * 2.3 + sin(lat * 2.1 + board) * 2.5) * 0.05 * fine;
		colour = vec3(0.70, 0.50, 0.31) * (0.92 + tint + rings + grain * 0.12 - lines * 0.30);
		rough = 0.66;
	} else if (surface == 1) {
		float row = floor(along / 2.1);
		float shift = mod(row, 2.0) * 0.9;
		vec2 slab = vec2(floor((lat + half_width + shift) / 1.8), row);
		float tint = hash_value(slab) * 0.16;
		float grout = max(seam(lat + half_width + shift, 1.8, 0.05), seam(along, 2.1, 0.05));
		colour = vec3(0.74, 0.69, 0.60) * (0.90 + tint + grain * 0.10);
		colour = mix(colour, vec3(0.36, 0.44, 0.26), grout * 0.85);
		rough = 0.80 - grout * 0.1;
	} else if (surface == 2) {
		float rib = seam(along, 3.2, 0.05);
		float brushed = sin(lat * 60.0 + soft_noise(vec2(lat * 2.0, along * 8.0)) * 4.0) * 0.03 * fine;
		colour = vec3(0.66, 0.71, 0.74) * (0.95 + brushed - rib * 0.25);
		rough = 0.34;
		metal = 0.75;
	} else if (surface == 3) {
		float flow = soft_noise(vec2(lat * 0.8, along * 0.35 - TIME * 2.6));
		float foam = smoothstep(0.62, 0.8, soft_noise(vec2(lat * 1.7, along * 0.9 - TIME * 4.0)));
		colour = mix(vec3(0.20, 0.55, 0.72), vec3(0.42, 0.78, 0.88), flow) + foam * 0.35;
		rough = 0.06;
		metal = 0.1;
	} else if (surface == 4) {
		// Kette aus Riesen-Seerosenblättern: Mittelpunkt alle 13 m, Adern strahlen nach außen.
		float pad = floor(along / 13.0 + 0.5);
		vec2 local = vec2(lat, along - pad * 13.0);
		float radius = length(local);
		float angle = atan(local.y, local.x);
		float veins = smoothstep(0.86, 1.0, abs(sin(angle * 9.0 + radius * 0.06))) * (0.4 + radius * 0.05);
		float ring = seam(radius, 4.2, 0.05) * 0.35;
		float join = 1.0 - smoothstep(0.0, 0.35, abs(abs(along - pad * 13.0) - 6.5));
		float tint = soft_noise(vec2(lat * 0.25, along * 0.25)) * 0.12;
		colour = vec3(0.30, 0.56, 0.20) * (0.95 + tint + grain * 0.08);
		colour = mix(colour, vec3(0.52, 0.72, 0.30), veins * fine * 0.8);
		colour = mix(colour, vec3(0.20, 0.36, 0.14), max(ring, join * 0.45));
		rough = 0.42;
	} else if (surface == 5) {
		float stripe = 1.0 - smoothstep(0.30, 0.45, abs(lat));
		float ripple = sin(along * 3.1) * 0.04 * fine;
		colour = vec3(0.24, 0.62, 0.30) * (0.95 + ripple + grain * 0.05);
		colour = mix(colour, vec3(0.98, 0.84, 0.22), stripe * 0.85);
		// Grünes Licht bricht durch die Schlauchwand: wandernde Lichtadern am Boden.
		float caustic = abs(sin(along * 0.7 + lat * 1.3 + TIME * 1.5) * sin(along * 0.45 - lat * 0.9 - TIME * 1.1));
		colour += pow(caustic, 3.0) * vec3(0.20, 0.36, 0.16) * fine;
		rough = 0.30;
	} else if (surface == 6) {
		float band = seam(along, 6.0, 0.05) * 0.5;
		float clay = soft_noise(vec2(lat * 1.5, along * 1.5));
		float specks = step(0.93, hash_value(floor(vec2(lat, along) * 7.0))) * fine;
		colour = vec3(0.78, 0.42, 0.24) * (0.88 + clay * 0.16 - band * 0.3) - specks * 0.12;
		rough = 0.86;
	} else if (surface == 7) {
		float sleeper = 1.0 - smoothstep(0.62, 0.70, abs(mod(along, 2.4) - 1.2) / 1.2);
		float gravel = hash_value(floor(vec2(lat, along) * 9.0)) * fine;
		vec3 bed = vec3(0.56, 0.53, 0.48) * (0.85 + gravel * 0.25);
		vec3 wood = vec3(0.46, 0.31, 0.19) * (0.9 + grain * 0.2);
		colour = mix(bed, wood, sleeper);
		rough = 0.85;
	} else if (surface == 8) {
		vec2 tile = floor(vec2(lat + half_width, along) / 1.25);
		float grout = max(seam(lat + half_width, 1.25, 0.03), seam(along, 1.25, 0.03));
		float tint = hash_value(tile) * 0.10;
		colour = vec3(0.80, 0.77, 0.70) * (0.92 + tint) - grout * 0.22;
		rough = 0.55;
	}
	float wetness = wet;
	for (int i = 0; i < 6; i++) {
		vec4 zone = wet_zones[i];
		float inside = smoothstep(zone.x - 6.0, zone.x, along) * (1.0 - smoothstep(zone.y, zone.y + 6.0, along));
		wetness = max(wetness, inside * zone.z);
	}
	float puddle = smoothstep(0.55, 0.75, soft_noise(vec2(lat * 0.35, along * 0.22))) * wetness;
	colour *= 1.0 - wetness * 0.22 - puddle * 0.12;
	rough = mix(rough, 0.08, max(wetness * 0.7, puddle));
	// Helle Ränder: die Fahrbahn bleibt auf jedem Belag und kleinem Bildschirm lesbar.
	float edge = abs(lat) - (half_width - 0.55);
	float band = 1.0 - smoothstep(0.0, 0.08 + footprint, abs(edge));
	float outer = smoothstep(0.25, 0.55, edge);
	colour = mix(colour, vec3(0.97, 0.93, 0.80), band * 0.85);
	colour *= 1.0 - outer * 0.25;
	ALBEDO = colour;
	ROUGHNESS = clamp(rough, 0.04, 0.95);
	METALLIC = metal;
	SPECULAR = 0.42;
}
