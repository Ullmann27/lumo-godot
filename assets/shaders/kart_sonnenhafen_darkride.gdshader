shader_type spatial;
render_mode unshaded, cull_disabled;

// The physical tunnel blocks the bright horizon. A deterministic local
// light palette keeps the cavern dark even in Godot's low-detail renderer.
// No light nodes or per-frame GPU allocations; PBR source assets unaffected.
uniform float road_factor : hint_range(0.0, 1.0) = 0.0;
uniform vec4 rock_color : source_color = vec4(0.075, 0.100, 0.155, 1.0);
uniform vec4 road_color : source_color = vec4(0.11, 0.15, 0.21, 1.0);
uniform vec4 cold_light : source_color = vec4(0.11, 0.87, 0.96, 1.0);
uniform vec4 violet_light : source_color = vec4(0.62, 0.28, 0.94, 1.0);
uniform float light_intensity : hint_range(0.0, 2.0) = 1.10;
uniform float rock_detail_strength : hint_range(0.0, 1.0) = 1.0;
uniform float wayfinding_strength : hint_range(0.0, 1.0) = 1.0;

varying float inner_fade;
varying vec3 at_world;

void vertex() {
    inner_fade = COLOR.a;
    at_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    float wave = sin(UV.y * 6.4 + TIME * 1.3);
    float bio = smoothstep(0.73, 0.94,
        sin(UV.x * 31.0 + sin(UV.y * 3.6) * 2.1) *
        sin(UV.y * 11.0 + UV.x * 13.0));
    float cave_bands = smoothstep(0.84, 0.98, sin(UV.y * 6.28318));
    float lane_edge = smoothstep(0.84, 0.94, abs(UV.x));
    float road_dash = (1.0 - smoothstep(0.02, 0.06, abs(UV.x)))
        * step(0.60, fract(UV.y * 1.6));
    vec3 glow_rock = mix(violet_light.rgb, cold_light.rgb,
        0.5 + 0.5 * wave) * (bio * 0.60 + cave_bands * 0.035);
    float guide_lateral = smoothstep(0.69, 0.77, abs(UV.x)) * (1.0 - smoothstep(0.90, 0.98, abs(UV.x)));
    float guide_phase = fract(UV.y * 4.2);
    float guide_segment = smoothstep(0.05, 0.13, guide_phase) * (1.0 - smoothstep(0.60, 0.68, guide_phase));
    vec3 guide_color = mix(cold_light.rgb, vec3(1.0, 0.66, 0.25), step(0.0, UV.x));
    vec3 guide_mark = guide_color * guide_lateral * guide_segment * wayfinding_strength;
    vec3 glow_road = cold_light.rgb * (lane_edge * 0.68 + road_dash * 0.21) + guide_mark * 1.25;
    float edge_fade = max(inner_fade, 0.12);
    // Soft luminous stone: visible indigo-blue surfaces behind the neon ribs,
    // not a black polygon silhouette. Analytical light, not new Light3D nodes.
    float rock_iridescence = 0.5 + 0.5 * sin(UV.x * 13.0 + UV.y * 4.1);
    float rock_strata = smoothstep(0.18, 0.82,
        0.5 + 0.5 * sin(UV.y * 3.4 + sin(UV.x * 9.0)));
    vec3 cave_bounce = mix(violet_light.rgb, cold_light.rgb,
        0.2 + 0.75 * rock_iridescence);
    vec3 base_rock = rock_color.rgb * (0.80 + 0.45 * rock_strata)
        + cave_bounce * (0.08 + 0.14 * rock_iridescence);
    float mineral_strata = 0.5 + 0.5 * sin(UV.y * 19.0 + UV.x * 29.0 + sin(UV.x * 19.0 + UV.y * 2.2));
    float mineral_seam = smoothstep(0.91, 0.99, sin(UV.y * 11.0 + UV.x * 32.0));
    base_rock *= mix(1.0, 0.70 + 0.60 * mineral_strata, rock_detail_strength);
    glow_rock += (cold_light.rgb * 0.17 + violet_light.rgb * 0.10) * mineral_seam * rock_detail_strength;
    vec3 base_road = road_color.rgb * (0.88 + 0.10 * sin(UV.y * 29.0))
        + cold_light.rgb * lane_edge * 0.12 + guide_mark * 0.15;
    vec3 base = mix(base_rock, base_road, road_factor);
    vec3 local_glow = mix(glow_rock, glow_road, road_factor);
    ALBEDO = base * (0.65 + 0.35 * edge_fade);
    EMISSION = local_glow * light_intensity * edge_fade;
    ROUGHNESS = 0.88;
    METALLIC = 0.0;
}
