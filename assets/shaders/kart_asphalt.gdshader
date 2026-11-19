shader_type spatial;
render_mode cull_disabled;

uniform vec4 road_tint : source_color = vec4(0.16, 0.20, 0.25, 1.0);
uniform vec4 edge_glow_color : source_color = vec4(0.35, 0.9, 1.0, 1.0);
uniform float night_course = 0.0;
uniform float sky_island_detail = 0.0;
uniform float cinematic_grade : hint_range(0.0, 1.0) = 0.95;
uniform float road_gloss : hint_range(0.0, 1.0) = 0.90;
uniform float edge_energy : hint_range(0.0, 1.0) = 0.50;
// Zero on low-detail devices; adds a mobile-friendly aggregate and worn tread.
uniform float surface_grit : hint_range(0.0, 1.0) = 0.0;
// Course identity: 0 asphalt, 1 forest path, 2 stone slabs, 3 sand, 4 snow and
// ice, 5 basalt with lava cracks, 6 star glass, 7 laboratory tiles.
uniform int surface_style = 0;
uniform vec4 detail_tint : source_color = vec4(0.5, 0.5, 0.5, 1.0);
// 1 keeps the surface colour readable instead of mirroring the sky.
uniform float surface_matte : hint_range(0.0, 1.0) = 0.0;
// Kulissen-Paket: plastische Feinstruktur (Normalen), Risse/Fugen, Gullys,
// Reifenabrieb auf der Ideallinie und Pfuetzen mit Himmelsspiegelung.
// 0 auf LOW (kostet dort nichts ausser einer Verzweigung).
uniform float road_detail : hint_range(0.0, 1.0) = 0.0;
uniform float wetness : hint_range(0.0, 1.0) = 0.0;
uniform float gully_spacing = 24.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(cell), hash21(cell + vec2(1.0, 0.0)), f.x),
		mix(hash21(cell + vec2(0.0, 1.0)), hash21(cell + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	// UV.x spans the road in metres; UV.y follows its centre line.
	float grain_visibility = 1.0 - smoothstep(0.012, 0.035, max(fwidth(UV.x), fwidth(UV.y)));
	float aggregate = mix(0.5, hash21(floor(UV * 26.0)), grain_visibility);
	float coarse = hash21(floor(UV * 1.8));
	float rubber = exp(-pow((abs(UV.x) - 2.4) * 1.1, 2.0));
	// Two world-scale procedural aggregates: broad repairs and fine gravel.
	// The high-frequency layer fades with pixel footprint to avoid shimmer.
	float pebble_footprint = max(fwidth(UV.x), fwidth(UV.y)) * 14.0;
	float pebble_lod = 1.0 - smoothstep(0.28, 0.62, pebble_footprint);
	float pebbles = hash21(floor(UV * 14.0 + vec2(3.7, 9.1))) - 0.5;
	float repairs = hash21(floor(UV * 0.92 + vec2(13.0, 2.1))) - 0.5;
	float driven_lane = rubber * (0.86 + 0.14 * sin(UV.y * 0.17));
	float lane_wear = 0.96 - rubber * mix(0.085, 0.115, sky_island_detail);
	float joint_phase = fract(UV.y / 13.0);
	float joint = 1.0 - smoothstep(0.0, max(fwidth(joint_phase) * 1.5, 0.006), min(joint_phase, 1.0 - joint_phase));
	float surface_joint = joint * sky_island_detail * 0.055;
	float edge_distance = abs(abs(UV.x) - 5.08);
	float edge_band = 1.0 - smoothstep(0.05, 0.24, edge_distance);
	float wet_band = 0.5 + 0.5 * sin(UV.y * 0.11 + UV.x * 0.55);
	vec3 base = road_tint.rgb * (0.91 + aggregate * 0.13 + coarse * 0.04 - surface_joint) * lane_wear;
	base = mix(base, base * (0.92 + wet_band * 0.12), cinematic_grade * road_gloss * 0.45);
	// Keep the original color identity; make coarse aggregate and wheel polish
	// legible on the chase camera without increasing vertex or draw-call count.
	float grit_color = pebbles * pebble_lod * 0.21 + repairs * 0.18 - driven_lane * 0.045;
	base *= 1.0 + surface_grit * grit_color;
	float original_roughness = mix(mix(0.90, 0.43, night_course), 0.22, cinematic_grade * road_gloss * 0.76);
	float roughness = clamp(original_roughness + surface_grit * (pebbles * pebble_lod * 0.11 + repairs * 0.09 - driven_lane * 0.035), 0.18, 0.94);
	float metallic = mix(night_course * 0.18, 0.26, cinematic_grade * road_gloss * 0.30);
	float specular = mix(0.42, 0.82, cinematic_grade * road_gloss);
	vec3 emission = edge_glow_color.rgb * edge_band * edge_energy * cinematic_grade;
	if (surface_style != 0) {
		// Themed surfaces own their colour; fine sparkle and specks follow the
		// same pixel-footprint fade as the asphalt grain.
		float fine_detail = grain_visibility * step(0.001, surface_grit);
		float broad = value_noise(UV * 0.5);
		float rut = rubber;
		vec3 themed = road_tint.rgb;
		float themed_roughness = 0.9;
		float themed_metallic = 0.0;
		vec3 themed_emission = vec3(0.0);
		if (surface_style == 1) {
			// Packed earth with two wheel ruts, mossy verges and fallen leaves.
			float crumbs = value_noise(UV * 3.1);
			themed = road_tint.rgb * (0.80 + broad * 0.32 + crumbs * 0.10) * (1.0 - rut * 0.17);
			float moss = smoothstep(3.2, 5.0, abs(UV.x) + (broad - 0.5) * 1.7);
			themed = mix(themed, detail_tint.rgb * (0.72 + crumbs * 0.42), moss * 0.82);
			vec2 leaf_grid = UV * 5.0;
			vec2 leaf_cell = floor(leaf_grid);
			float leaf_shape = 1.0 - smoothstep(0.16, 0.30, length(fract(leaf_grid) - 0.5));
			float leaf = step(0.955, hash21(leaf_cell)) * leaf_shape * fine_detail;
			vec3 leaf_colour = mix(vec3(0.86, 0.52, 0.16), vec3(0.93, 0.78, 0.26), hash21(leaf_cell + 5.0));
			themed = mix(themed, leaf_colour, leaf * 0.75);
			themed_roughness = 0.93;
		} else if (surface_style == 2) {
			// Large pavers in offset rows; a few slabs carry the course accent.
			vec2 grid = vec2(UV.x / 1.35, UV.y / 1.9);
			grid.x += 0.5 * mod(floor(grid.y), 2.0);
			vec2 slab = floor(grid);
			vec2 inside = fract(grid);
			float tone = hash21(slab);
			float to_joint = min(min(inside.x, 1.0 - inside.x) * 1.35, min(inside.y, 1.0 - inside.y) * 1.9);
			float joint_width = 0.05 + max(fwidth(UV.x), fwidth(UV.y)) * 1.5;
			float slab_joint = 1.0 - smoothstep(0.015, joint_width, to_joint);
			themed = road_tint.rgb * (0.82 + tone * 0.26 + value_noise(UV * 2.0) * 0.08);
			themed = mix(themed, detail_tint.rgb, smoothstep(0.90, 1.0, tone) * 0.40);
			themed = mix(themed, road_tint.rgb * 0.40, slab_joint * 0.85) * (1.0 - rut * 0.07);
			themed_roughness = 0.80;
		} else if (surface_style == 3) {
			// Wind-rippled packed sand with darker tyre tracks.
			float ripple = 0.5 + 0.5 * sin(UV.y * 2.2 + UV.x * 0.6 + value_noise(UV * 0.35) * 4.0);
			themed = road_tint.rgb * (0.86 + broad * 0.18 + ripple * 0.08 + (aggregate - 0.5) * 0.07);
			themed = mix(themed, detail_tint.rgb, rut * 0.36);
			themed_roughness = 0.95;
		} else if (surface_style == 4) {
			// Packed snow, tyre grooves and glossy blue ice sheets.
			float ice = smoothstep(0.56, 0.74, value_noise(UV * 0.28 + vec2(7.3, 1.9)));
			float groove = rut * (0.6 + 0.4 * sin(UV.x * 18.0));
			themed = road_tint.rgb * (0.90 + broad * 0.12) * (1.0 - groove * 0.11);
			themed = mix(themed, detail_tint.rgb, ice * 0.58);
			float sparkle = step(0.992, hash21(floor(UV * 22.0))) * fine_detail;
			themed_emission = vec3(0.55, 0.62, 0.70) * sparkle;
			themed_roughness = mix(0.86, 0.16, ice);
		} else if (surface_style == 5) {
			// Basalt plates; the cracks between them glow and breathe slowly.
			float vein = abs(value_noise(UV * 0.55) - 0.5);
			float crack = 1.0 - smoothstep(0.0, 0.034, vein);
			float halo = 1.0 - smoothstep(0.0, 0.13, vein);
			themed = road_tint.rgb * (0.84 + value_noise(UV * 2.2) * 0.26);
			themed = mix(themed, themed * 0.55, halo * 0.5);
			float breathe = 0.72 + 0.28 * sin(TIME * 1.3 + UV.y * 0.21);
			themed_emission = detail_tint.rgb * (crack * 1.5 + halo * 0.22) * breathe;
			themed_roughness = 0.72;
		} else if (surface_style == 6) {
			// Dark glass over a drifting nebula with twinkling stars.
			float nebula = value_noise(UV * 0.22 + vec2(0.0, TIME * 0.02));
			float clouds = value_noise(UV * 0.6 + vec2(4.1, -TIME * 0.03));
			themed = mix(road_tint.rgb * 0.55, road_tint.rgb * 1.9 + vec3(0.16, 0.02, 0.26), nebula * clouds * 1.5);
			vec2 star_grid = UV * 3.2;
			vec2 star_cell = floor(star_grid);
			float star_shape = 1.0 - smoothstep(0.03, 0.14, length(fract(star_grid) - 0.5));
			float star = step(0.90, hash21(star_cell)) * star_shape * fine_detail;
			float twinkle = 0.55 + 0.45 * sin(TIME * 3.0 + hash21(star_cell + 3.0) * 40.0);
			float runway = 1.0 - smoothstep(0.03, 0.09, abs(fract(UV.y / 9.0 - TIME * 0.2) - 0.5));
			themed_emission = detail_tint.rgb * (star * twinkle * 1.6 + runway * 0.30 * step(abs(UV.x), 4.9));
			themed_roughness = 0.26;
			themed_metallic = 0.30;
		} else {
			// Clean laboratory tiles with one coloured guide lane per side.
			vec2 grid = UV / 1.35;
			vec2 inside = fract(grid);
			float tone = hash21(floor(grid));
			float to_joint = min(min(inside.x, 1.0 - inside.x), min(inside.y, 1.0 - inside.y)) * 1.35;
			float joint_width = 0.03 + max(fwidth(UV.x), fwidth(UV.y)) * 1.5;
			float tile_joint = 1.0 - smoothstep(0.008, joint_width, to_joint);
			themed = road_tint.rgb * (0.93 + tone * 0.08);
			themed = mix(themed, detail_tint.rgb, smoothstep(0.93, 1.0, tone) * 0.45);
			float guide = 1.0 - smoothstep(0.20, 0.27, abs(abs(UV.x) - 4.15));
			themed = mix(themed, detail_tint.rgb, guide * 0.85);
			themed = mix(themed, road_tint.rgb * 0.55, tile_joint * 0.7) * (1.0 - rut * 0.05);
			themed_roughness = 0.50;
		}
		base = themed;
		roughness = themed_roughness;
		metallic = themed_metallic;
		specular = 0.45;
		emission += themed_emission;
	}
	float final_roughness = mix(roughness, max(roughness, 0.82), surface_matte * float(surface_style == 0));
	float final_metallic = metallic * (1.0 - surface_matte * float(surface_style == 0));
	if (road_detail > 0.0) {
		float footprint = max(fwidth(UV.x), fwidth(UV.y));
		float near_fade = 1.0 - smoothstep(0.02, 0.07, footprint);
		// Feinstruktur: Hoehenfeld aus zwei Rauschlagen, Normalen aus Differenzen.
		vec2 p = UV * vec2(4.5, 4.5);
		float e = 0.06;
		float h0 = value_noise(p) * 0.6 + value_noise(p * 2.3) * 0.4;
		float hx = value_noise(p + vec2(e, 0.0)) * 0.6 + value_noise((p + vec2(e, 0.0)) * 2.3) * 0.4;
		float hy = value_noise(p + vec2(0.0, e)) * 0.6 + value_noise((p + vec2(0.0, e)) * 2.3) * 0.4;
		float relief = (surface_style == 0 ? 1.0 : 0.7) * road_detail * near_fade;
		vec3 bump = normalize(vec3((h0 - hx) * 2.2 * relief, (h0 - hy) * 2.2 * relief, 1.0));
		// Risse mit dunklem Bitumen-Verguss (nur Asphalt und Steinplatten)
		float crack_field = abs(value_noise(UV * vec2(0.55, 0.35) + vec2(11.0, 3.0)) - 0.5);
		float crack = (1.0 - smoothstep(0.004, 0.016 + footprint * 0.6, crack_field))
			* smoothstep(0.45, 0.62, value_noise(UV * 0.09 + 2.0)) * float(surface_style == 0 || surface_style == 2);
		base = mix(base, base * 0.45, crack * 0.8 * road_detail);
		final_roughness = mix(final_roughness, 0.35, crack * 0.6 * road_detail);
		// Reifenabrieb: dunkle Laengsstreifen auf der Ideallinie (beide Spuren)
		float streak = value_noise(vec2(UV.x * 7.0, UV.y * 0.04)) * value_noise(vec2(UV.x * 2.3 + 5.0, UV.y * 0.11));
		float line = exp(-pow((abs(UV.x + sin(UV.y * 0.013) * 1.2) - 1.4) * 0.9, 2.0));
		float rubber_line = line * smoothstep(0.15, 0.55, streak) * road_detail;
		base *= 1.0 - rubber_line * (surface_style == 0 ? 0.22 : 0.10);
		final_roughness = mix(final_roughness, final_roughness * 0.82, rubber_line);
		// Gullys mit Gitterrost am Fahrbahnrand (nur Asphalt)
		float along = mod(UV.y, gully_spacing);
		float lateral = abs(UV.x) - 4.55;
		float in_gully = step(0.0, lateral) * step(lateral, 0.42) * step(along, 0.75) * float(surface_style == 0);
		if (in_gully > 0.5) {
			float slot = step(0.45, fract(along * 10.0));
			float frame_edge = step(0.06, min(along, 0.75 - along)) * step(0.05, min(lateral, 0.42 - lateral));
			base = mix(vec3(0.08, 0.085, 0.09), vec3(0.015), slot * frame_edge);
			final_metallic = 0.55;
			final_roughness = 0.42;
			bump = vec3(0.0, 0.0, 1.0);
		}
		// Pfuetzen: spiegeln den Himmel, nicht auf der befahrenen Linie
		float puddle_noise = value_noise(UV * vec2(0.22, 0.12) + vec2(4.7, 1.3)) * 0.75 + value_noise(UV * 0.9) * 0.25;
		float puddle = smoothstep(0.66, 0.70, puddle_noise + wetness * 0.12) * wetness * (1.0 - line * 0.55);
		float damp = smoothstep(0.52, 0.66, puddle_noise + wetness * 0.12) * wetness;
		base = mix(base, base * 0.62, damp * 0.6);
		base = mix(base, base * 0.38, puddle);
		final_roughness = mix(final_roughness, final_roughness * 0.55, damp);
		final_roughness = mix(final_roughness, 0.04, puddle);
		final_metallic = mix(final_metallic, 0.0, puddle);
		bump = normalize(mix(bump, vec3(0.0, 0.0, 1.0), puddle));
		NORMAL_MAP = bump * 0.5 + 0.5;
		NORMAL_MAP_DEPTH = 1.0;
		specular = mix(specular, 0.7, puddle);
	}
	ALBEDO = base;
	ROUGHNESS = final_roughness;
	METALLIC = final_metallic;
	SPECULAR = specular;
	EMISSION = emission;
}
