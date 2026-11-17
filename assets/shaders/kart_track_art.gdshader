shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Family: 0 painted plaster, 1 timber, 2 manufactured metal, 3 mineral,
// 4 roof tiles, 5 foliage, 6 crystal. No scene lights or colour palette replaced.
uniform vec4 base_tint : source_color = vec4(1.0);
uniform int family = 0;
uniform bool detailed = true;
uniform bool technical = false;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.72;
uniform float metallic_value : hint_range(0.0, 1.0) = 0.04;
uniform float grain_strength : hint_range(0.0, 0.25) = 0.13;
varying vec3 world_point;
varying vec3 world_n;
varying vec3 object_size;

float hash2(vec2 p) {
    p = fract(p * vec2(0.1031, 0.11369));
    p += dot(p, p.yx + 19.19);
    return fract(p.x * p.y);
}
float noise2(vec2 p) {
    vec2 cell = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash2(cell), hash2(cell + vec2(1.0, 0.0)), f.x),
               mix(hash2(cell + vec2(0.0, 1.0)), hash2(cell + vec2(1.0)), f.x), f.y);
}
float joint(float p, float width) {
    float d = abs(fract(p + 0.5) - 0.5);
    float aa = max(fwidth(p), 0.001);
    return 1.0 - smoothstep(width, width + aa, d);
}
void vertex() {
    world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_n = normalize(MODEL_NORMAL_MATRIX * NORMAL);
    object_size = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
}
void fragment() {
    vec3 n = normalize(world_n);
    vec3 an = abs(n);
    vec2 p = an.y > max(an.x, an.z) ? world_point.xz :
        (an.x > an.z ? world_point.zy : world_point.xy);
    vec3 pigment = COLOR.rgb;
    if (!OUTPUT_IS_SRGB) {
        pigment = mix(pigment / 12.92, pow((pigment + 0.055) / 1.055, vec3(2.4)),
                      step(vec3(0.04045), pigment));
    }
    pigment *= base_tint.rgb;
    float distance_fade = 1.0 - smoothstep(24.0, 120.0, length(VERTEX));
    float pixel_fade = 1.0 - smoothstep(0.035, 0.20, length(fwidth(p)));
    float detail = distance_fade * pixel_fade;
    float coarse = noise2(p * 0.72);
    float fine = detailed ? noise2(p * 15.0) : 0.5;
    float relief = (coarse - 0.5) * grain_strength + (fine - 0.5) * grain_strength * detail;
    float seams = 0.0;
    float rough = roughness_value;
    float metal = metallic_value;
    // Small manufactured pieces remain clean; only genuinely large panels tile.
    if (family == 0 && object_size.y > 1.0 && max(object_size.x, object_size.z) > 1.1) {
        float row = floor(p.y / 0.60);
        float vertical = joint(p.x / (technical ? 2.2 : 1.6) + mod(row, 2.0) * 0.5, 0.008);
        float horizontal = joint(p.y / 0.60, 0.013);
        seams = max(horizontal, vertical) * detail * (technical ? 0.15 : 0.11);
    }
    if (family == 1) {
        float timber = sin(p.x * 28.0 + coarse * 3.0) * 0.5 + 0.5;
        relief += (timber - 0.5) * 0.075 * detail;
    }
    if (family == 2) {
        // Existing cylinder batches mix supports and brown tree trunks.
        bool timber = COLOR.r > COLOR.g * 1.22 && COLOR.g > COLOR.b * 1.10 && COLOR.r < 0.72;
        if (timber) { metal = 0.0; rough = 0.86; }
        relief *= timber ? 1.0 : 0.34;
    }
    if (family == 3) {
        relief += sin(world_point.y * 3.8 + coarse * 2.0) * 0.035;
        rough = clamp(rough + (coarse - 0.5) * 0.14, 0.60, 0.98);
    }
    if (family == 4) {
        float row = floor(p.y * 2.0);
        seams = max(joint(p.y * 2.0, 0.028), joint(p.x * 1.7 + mod(row, 2.0) * 0.5, 0.015)) * detail * 0.23;
    }
    if (family == 5) {
        relief = (coarse - 0.5) * 0.12 + n.y * 0.035;
        rough = 0.88;
        metal = 0.0;
    }
    if (family == 6) {
        relief *= 0.12;
        rough = 0.18;
    }
    ALBEDO = clamp(pigment * (1.0 + relief - seams), vec3(0.0), vec3(1.0));
    ROUGHNESS = clamp(rough + (fine - 0.5) * 0.055 * detail, 0.12, 0.98);
    METALLIC = metal;
    SPECULAR = family == 5 ? 0.22 : 0.45;
    AO = 1.0 - seams * 0.45;
    AO_LIGHT_AFFECT = 0.2;
}
