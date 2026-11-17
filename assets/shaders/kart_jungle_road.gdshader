shader_type spatial;
render_mode cull_disabled;
uniform int surface_type = 0;

float hash_value(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	float footprint = max(fwidth(UV.x), fwidth(UV.y));
	float fine_lod = 1.0 - smoothstep(0.015, 0.065, footprint);
	float grit = (hash_value(floor(UV * 24.0)) - 0.5) * fine_lod;
	float coarse = hash_value(floor(UV * 1.7)) - 0.5;
	vec3 dry = vec3(0.30, 0.31, 0.26) * (1.0 + grit * 0.19 + coarse * 0.08);
	float rough = 0.82 + grit * 0.08;
	if (surface_type == 1) {
		float plank = floor(UV.y / 0.34);
		float seam_width = max(fwidth(UV.y) * 1.3, 0.015);
		float seam = 1.0 - smoothstep(0.0, seam_width, min(mod(UV.y, 0.34), 0.34 - mod(UV.y, 0.34)));
		float grain = sin(UV.x * 12.0 + sin(UV.x * 1.5 + plank * 0.31) * 2.0) * 0.04 * fine_lod;
		float plank_tint = hash_value(vec2(plank, floor(UV.x / 2.5))) * 0.15;
		dry = vec3(0.34, 0.20, 0.095) * (0.94 + grain + plank_tint - seam * 0.24);
		rough = 0.70;
	} else if (surface_type == 2) {
		float wetness = smoothstep(0.1, 0.7, sin(UV.y * 0.067 + sin(UV.x)) * 0.5 + 0.5);
		dry *= 0.89 + 0.08 * wetness;
		rough = mix(0.64, 0.32, wetness);
	}
	ALBEDO = dry;
	ROUGHNESS = clamp(rough, 0.30, 0.94);
	METALLIC = 0.0;
	SPECULAR = 0.35;
}

