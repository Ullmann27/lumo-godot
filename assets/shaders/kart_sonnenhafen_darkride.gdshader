shader_type spatial;
render_mode unshaded, cull_disabled;

// Baked cave art lighting is intentional: no point lights, screen derivatives,
// triplanar projection or per-pixel 3D noise. Relief comes from real normals.
uniform float animation_time = 0.0;
uniform float road_factor : hint_range(0.0, 1.0) = 0.0;
uniform vec4 rock_color : source_color = vec4(0.31, 0.38, 0.48, 1.0);
uniform vec4 road_color : source_color = vec4(0.11, 0.15, 0.21, 1.0);
uniform vec4 cold_light : source_color = vec4(0.11, 0.87, 0.96, 1.0);
uniform vec4 violet_light : source_color = vec4(0.62, 0.28, 0.94, 1.0);
uniform float light_intensity : hint_range(0.0, 2.0) = 1.10;
uniform float rock_detail_strength : hint_range(0.0, 1.0) = 1.0;
uniform bool mobile_detail = false;
varying float inner_fade;
varying vec3 rock_normal;
varying vec3 material_tag;

float mineral_hash(vec2 p) {
    vec3 q = fract(vec3(p.xyx) * 0.1031);
    q += dot(q, q.yzx + 33.33);
    return fract((q.x + q.y) * q.z);
}
float mineral_noise(vec2 p) {
    vec2 cell = floor(p);
    vec2 t = fract(p);
    t = t * t * (3.0 - 2.0 * t);
    return mix(mix(mineral_hash(cell), mineral_hash(cell + vec2(1.0, 0.0)), t.x),
        mix(mineral_hash(cell + vec2(0.0, 1.0)), mineral_hash(cell + vec2(1.0)), t.x), t.y);
}
void vertex() {
    inner_fade = COLOR.a;
    material_tag = COLOR.rgb;
    rock_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
    float macro = mineral_noise(UV * vec2(18.0, 2.6));
    float strata = sin(UV.x * 49.0 + UV.y * 2.7 + macro * 2.5);
    float terrace = smoothstep(-0.65, -0.05, strata) * (1.0 - smoothstep(0.58, 0.9, strata));
    float vein = 1.0 - smoothstep(0.025, 0.11, abs(strata - 0.45));
    float close_detail = 1.0 - smoothstep(8.0, 42.0, length(VERTEX));
    float grain = 0.5;
    if (!mobile_detail) {
        grain = 0.5 + 0.5 * sin(UV.x * 210.0 + macro * 4.0) * sin(UV.y * 30.0);
    }
    vec3 normal = normalize(rock_normal);
    float key = smoothstep(-0.35, 0.7, dot(normal, normalize(vec3(-0.55, 0.65, 0.4))));
    float cool = smoothstep(-0.1, 0.85, dot(normal, normalize(vec3(0.6, 0.25, -0.4))));
    float warm_zone = smoothstep(0.48, 0.95, sin(UV.y * 1.75 + 1.2));
    vec3 shadow = vec3(0.055, 0.075, 0.15);
    vec3 mineral = mix(shadow, vec3(0.24, 0.31, 0.42), 0.38 + key * 0.44 + cool * 0.18);
    mineral = mix(mineral, vec3(0.36, 0.26, 0.18), warm_zone * key * 0.55);
    mineral *= 0.76 + macro * 0.30 + terrace * 0.14;
    mineral *= 1.0 + (grain - 0.5) * close_detail * 0.085;
    vec3 base_rock = mix(rock_color.rgb, mineral, rock_detail_strength);
    // Compatibility flips NORMAL on back faces of a double-sided material.
    // Use the authored inward normal consistently for camera-facing cave rims.
    vec3 view_normal = normalize((VIEW_MATRIX * vec4(normal, 0.0)).xyz);
    float glancing = 1.0 - clamp(dot(view_normal, normalize(VIEW)), 0.0, 1.0);
    float rim = glancing * glancing * glancing;
    vec3 zone_color = mix(cold_light.rgb, vec3(0.9, 0.46, 0.12), warm_zone);
    vec3 glow_rock = zone_color * (vein * 0.032 + rim * terrace * 0.025)
        * rock_detail_strength;
    float lane_edge = smoothstep(0.84, 0.94, abs(UV.x));
    float dash_phase = fract(UV.y * 1.6);
    float dash_aa = mix(0.01, 0.09, smoothstep(6.0, 60.0, length(VERTEX)));
    float dash = smoothstep(0.6 - dash_aa, 0.6 + dash_aa, dash_phase)
        * (1.0 - smoothstep(0.96 - dash_aa, 0.96, dash_phase));
    float road_dash = (1.0 - smoothstep(0.015, 0.035, abs(UV.x))) * dash;
    vec3 base_road = road_color.rgb * (0.86 + grain * 0.04) + cold_light.rgb * lane_edge * 0.045;
    vec3 glow_road = cold_light.rgb * (lane_edge * 0.36 + road_dash * 0.17);
    float edge_fade = max(inner_fade, 0.12);
    ALBEDO = mix(base_rock, base_road, road_factor) * (0.80 + 0.20 * edge_fade);
    EMISSION = mix(glow_rock, glow_road, road_factor) * light_intensity * edge_fade;
    ROUGHNESS = mix(0.89, 0.72, road_factor);

    // Batched water/lava ribbon geometry marks its material in vertex RGB.
    // Legacy tunnel and roadway stay white (1,1,1), so their look is unchanged.
    // The controlled director clock respects pause and reduced-motion mode.
    float water = clamp(1.0 - material_tag.r, 0.0, 1.0) * road_factor;
    float lava = clamp(1.0 - material_tag.b, 0.0, 1.0) * road_factor;
    float stream_mask = max(water, lava);
    float ripple = 0.74 + 0.26 * sin(UV.y * 2.8 + UV.x * 7.0 +
        animation_time * (mobile_detail ? 0.9 : 2.1));
    vec3 stream_color = mix(vec3(0.035, 0.27, 0.39),
        vec3(0.85, 0.26, 0.045), lava);
    vec3 stream_glow = mix(vec3(0.04, 0.48, 0.72),
        vec3(1.0, 0.27, 0.045), lava);
    ALBEDO = mix(ALBEDO, stream_color * (0.83 + ripple * 0.24), stream_mask);
    EMISSION = mix(EMISSION, stream_glow * ripple * light_intensity * edge_fade * 0.7,
        stream_mask);
    ROUGHNESS = mix(ROUGHNESS, 0.26, stream_mask);
}
