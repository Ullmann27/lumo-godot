shader_type spatial;
render_mode unshaded, cull_disabled;

// The physical tunnel blocks the bright horizon. A deterministic local
// light palette keeps the cavern dark even in Godot's low-detail renderer.
// No light nodes or per-frame GPU allocations; PBR source assets unaffected.
uniform float road_factor : hint_range(0.0, 1.0) = 0.0;
uniform vec4 rock_color : source_color = vec4(0.018, 0.028, 0.065, 1.0);
uniform vec4 road_color : source_color = vec4(0.032, 0.061, 0.095, 1.0);
uniform vec4 cold_light : source_color = vec4(0.11, 0.87, 0.96, 1.0);
uniform vec4 violet_light : source_color = vec4(0.62, 0.28, 0.94, 1.0);
uniform float light_intensity : hint_range(0.0, 2.0) = 0.78;

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
    vec3 glow_road = cold_light.rgb * (lane_edge * 0.68 + road_dash * 0.21);
    float edge_fade = max(inner_fade, 0.12);
    vec3 base = mix(rock_color.rgb, road_color.rgb, road_factor);
    vec3 local_glow = mix(glow_rock, glow_road, road_factor);
    ALBEDO = base;
    EMISSION = local_glow * light_intensity * edge_fade;
    ROUGHNESS = 0.88;
    METALLIC = 0.0;
}
