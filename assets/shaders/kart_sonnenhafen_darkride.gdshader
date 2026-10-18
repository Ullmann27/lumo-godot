shader_type spatial;
render_mode unshaded, cull_disabled;

uniform float animation_time = 0.0;
uniform float road_factor : hint_range(0.0, 1.0) = 0.0;
uniform vec4 rock_color : source_color = vec4(0.16, 0.19, 0.27, 1.0);
uniform vec4 road_color : source_color = vec4(0.11, 0.15, 0.21, 1.0);
uniform vec4 cold_light : source_color = vec4(0.11, 0.87, 0.96, 1.0);
uniform vec4 violet_light : source_color = vec4(0.62, 0.28, 0.94, 1.0);
uniform float light_intensity : hint_range(0.0, 2.0) = 1.10;
uniform float rock_detail_strength : hint_range(0.0, 1.0) = 1.0;
varying float inner_fade;
varying vec3 at_world;

float rock_hash(vec3 p) {
    p = fract(p * 0.1031);
    p += dot(p, p.yzx + 33.33);
    return fract((p.x + p.y) * p.z);
}
float stone_noise(vec3 p) {
    vec3 cell = floor(p);
    vec3 t = fract(p);
    t = t * t * (3.0 - 2.0 * t);
    return mix(mix(mix(rock_hash(cell), rock_hash(cell + vec3(1,0,0)), t.x),
                   mix(rock_hash(cell + vec3(0,1,0)), rock_hash(cell + vec3(1,1,0)), t.x), t.y),
               mix(mix(rock_hash(cell + vec3(0,0,1)), rock_hash(cell + vec3(1,0,1)), t.x),
                   mix(rock_hash(cell + vec3(0,1,1)), rock_hash(cell + vec3(1,1,1)), t.x), t.y), t.z);
}
void vertex() {
    inner_fade = COLOR.a;
    at_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
    float macro = stone_noise(at_world * 0.42);
    float grain = stone_noise(at_world * 4.2);
    float bedding = sin(at_world.y * 8.2 + macro * 7.0 + at_world.x * 0.38);
    float vein = 1.0 - smoothstep(0.035, 0.15, abs(bedding));
    vec3 face_normal = normalize(cross(dFdx(at_world), dFdy(at_world)));
    float relief = 0.48 + 0.52 * abs(dot(face_normal, normalize(vec3(0.4,0.75,0.25))));
    vec3 mineral = mix(rock_color.rgb * 0.48, vec3(0.25,0.31,0.41), macro);
    mineral *= relief * (0.65 + grain * 0.5);
    vec3 base_rock = mix(rock_color.rgb, mineral, rock_detail_strength);
    float wave = 0.5 + 0.5 * sin(animation_time * 0.7 + UV.y * 0.9);
    vec3 glow_rock = mix(violet_light.rgb, cold_light.rgb, wave)
        * vein * smoothstep(0.45,0.8, macro) * 0.23 * rock_detail_strength;
    float lane_edge = smoothstep(0.84, 0.94, abs(UV.x));
    float dash_phase = fract(UV.y * 1.6);
    float dash_aa = max(fwidth(UV.y * 1.6), 0.01);
    float dash = smoothstep(0.6 - dash_aa, 0.6 + dash_aa, dash_phase)
        * (1.0 - smoothstep(0.96 - dash_aa, 0.96, dash_phase));
    float road_dash = (1.0 - smoothstep(0.015, 0.035, abs(UV.x))) * dash;
    vec3 base_road = road_color.rgb * (0.70 + 0.15 * grain) + cold_light.rgb * lane_edge * 0.12;
    vec3 glow_road = cold_light.rgb * (lane_edge * 0.52 + road_dash * 0.20);
    float edge_fade = max(inner_fade, 0.12);
    ALBEDO = mix(base_rock, base_road, road_factor) * (0.72 + 0.28 * edge_fade);
    EMISSION = mix(glow_rock, glow_road, road_factor) * light_intensity * edge_fade;
    ROUGHNESS = mix(0.94, 0.72, road_factor);
}
