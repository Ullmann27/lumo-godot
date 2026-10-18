// Lumo original Cinema-Rock – intentionally a *small* first art pass.
// On Sonnenhafen's close decorative rocks only. The Mobile/low detail
// setting continues to use the unchanged original fast material.
// Vertex COLOR is the MultiMesh instance's actual authored pigment;
// it is not curvature/AO (those channels are NOT baked in current GLBs).
shader_type spatial;
render_mode cull_back, diffuse_toon, specular_toon;

uniform vec4 cobalt_shadow : source_color = vec4(0.29, 0.25, 0.58, 1.0);
uniform vec4 warm_key : source_color = vec4(1.00, 0.85, 0.64, 1.0);
uniform vec4 rim_glow : source_color = vec4(0.92, 0.65, 0.31, 1.0);
uniform float tactility : hint_range(0.0, 0.25) = 0.095;
uniform float rim_strength : hint_range(0.0, 0.4) = 0.15;

varying vec3 world_position;
varying vec3 world_normal;

float stable_hash(vec3 p) {
    p = fract(p * vec3(0.1031, 0.11369, 0.13787));
    p += dot(p, p.yzx + 19.19);
    return fract((p.x + p.y) * p.z);
}

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
    vec3 n = normalize(world_normal);
    vec3 original_pigment = COLOR.rgb;
    float key = dot(n, normalize(vec3(-0.34, 0.84, 0.43)));
    float tier = smoothstep(-0.25, 0.52, key);
    vec3 film_light = mix(cobalt_shadow.rgb * 0.76, warm_key.rgb, tier);
    // Object-space-free procedural pigment: no texture upload, no stochastic
    // motion, and pixel-footprint suppression against mobile shimmer.
    vec3 cells = floor(world_position * 7.0);
    float footprint = fwidth(world_position.x) + fwidth(world_position.z);
    float small_detail = 1.0 - smoothstep(0.025, 0.10, footprint);
    float paint = (stable_hash(cells) - 0.5) * tactility * small_detail;
    ALBEDO = original_pigment * film_light * (1.0 + paint);
    ROUGHNESS = 0.77;
    METALLIC = 0.0;
    SPECULAR = 0.50;
    float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
    EMISSION = rim_glow.rgb * (rim_strength * rim);
}

void light() {
    // Warm/blue two-step contrast plus an intentionally restrained glint.
    float key = smoothstep(-0.10, 0.24, dot(NORMAL, LIGHT));
    DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * mix(0.24, 1.0, key);
    vec3 halfway = normalize(LIGHT + VIEW);
    float glint = smoothstep(0.95, 0.99, max(dot(NORMAL, halfway), 0.0));
    SPECULAR_LIGHT += LIGHT_COLOR * glint * ATTENUATION * 0.16;
}
