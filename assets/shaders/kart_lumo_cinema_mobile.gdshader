shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_schlick_ggx;

// Economical ES3/Compatibility variant: no fragment noise or dynamic flow,
// one interpolated mineral band, one broad glint, same authored material colors.
uniform vec4 base_color : source_color = vec4(1.0);
uniform bool instance_colors = false;
uniform bool correct_instance_normals = false;
uniform float surface_roughness = 0.84;
uniform float surface_metallic = 0.0;
uniform float specular_strength = 0.18;
uniform float rim_strength = 0.055;
uniform float micro_strength = 0.08;
uniform float crystal_amount = 0.0;
uniform float water_amount = 0.0;
uniform float animation_time = 0.0;
uniform float light_intensity = 1.1;
varying float mineral_band;

void vertex() {
    if (correct_instance_normals && OUTPUT_IS_SRGB) {
        vec3 scale_squared = vec3(dot(MODEL_MATRIX[0].xyz, MODEL_MATRIX[0].xyz),
            dot(MODEL_MATRIX[1].xyz, MODEL_MATRIX[1].xyz),
            dot(MODEL_MATRIX[2].xyz, MODEL_MATRIX[2].xyz));
        NORMAL /= max(scale_squared, vec3(0.000001));
    }
    vec3 point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    mineral_band = 0.5 + 0.5 * sin(point.y * 3.4 + point.x * 0.37 + point.z * 0.19);
}

void fragment() {
    vec3 pigment = base_color.rgb * (instance_colors ? COLOR.rgb : vec3(1.0));
    ALBEDO = pigment * (1.0 + (mineral_band - 0.5) * micro_strength);
    ROUGHNESS = surface_roughness;
    METALLIC = surface_metallic;
    SPECULAR = specular_strength;
    float edge = 1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
    float rim = edge * edge * edge;
    EMISSION = (pigment * vec3(0.055, 0.065, 0.12)
        + vec3(0.35, 0.40, 0.55) * rim * rim_strength
        + pigment * crystal_amount * (0.16 + rim * 0.30)
        + vec3(0.015, 0.34, 0.42) * water_amount * 0.34) * light_intensity;
}

void light() {
    float band = smoothstep(-0.24, 0.64, dot(NORMAL, LIGHT));
    DIFFUSE_LIGHT += mix(vec3(0.29, 0.34, 0.66), vec3(1.0, 0.84, 0.63), band)
        * LIGHT_COLOR * ATTENUATION * (0.24 + 0.76 * band) * 0.318309886;
    float glint = smoothstep(0.92, 0.995, dot(NORMAL, normalize(LIGHT + VIEW)));
    SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * glint * specular_strength * 0.25 * 0.318309886;
}
