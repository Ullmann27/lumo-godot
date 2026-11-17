shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Tactile Cinema: opaque, real light/shadow response, authored vertex pigments.
// No derivatives, triplanar, screen textures, reflection cameras or extra passes.
uniform vec4 base_color : source_color = vec4(1.0);
uniform bool instance_colors = false;
uniform bool correct_instance_normals = false;
uniform float surface_roughness : hint_range(0.05, 1.0) = 0.84;
uniform float surface_metallic : hint_range(0.0, 1.0) = 0.0;
uniform float specular_strength = 0.18;
uniform float rim_strength = 0.055;
uniform float micro_strength = 0.08;
uniform float crystal_amount = 0.0;
uniform float water_amount = 0.0;
uniform float animation_time = 0.0;
uniform float light_intensity = 1.1;
varying vec3 world_point;
varying float mineral_band;

void vertex() {
    // GLES3 checks the unit MultiMesh node, not each instance's nonuniform
    // scale. Precompensate S^2 so its default R*S transform gives R/S normals.
    // This path is only for our orthonormal-root MultiMeshes, never coachwork.
    if (correct_instance_normals && OUTPUT_IS_SRGB) {
        vec3 scale_squared = vec3(dot(MODEL_MATRIX[0].xyz, MODEL_MATRIX[0].xyz),
            dot(MODEL_MATRIX[1].xyz, MODEL_MATRIX[1].xyz),
            dot(MODEL_MATRIX[2].xyz, MODEL_MATRIX[2].xyz));
        NORMAL /= max(scale_squared, vec3(0.000001));
    }
    world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    mineral_band = 0.5 + 0.5 * sin(world_point.y * 3.4 + world_point.x * 0.37 + world_point.z * 0.19);
}

void fragment() {
    vec3 pigment = base_color.rgb * (instance_colors ? COLOR.rgb : vec3(1.0));
    float close_detail = 1.0 - smoothstep(7.0, 28.0, length(VERTEX));
    float grain = sin(world_point.x * 15.7 + world_point.y * 11.3)
        * sin(world_point.z * 13.1 - world_point.y * 7.9);
    float stratum = smoothstep(0.34, 0.65, mineral_band);
    float texture_amount = micro_strength * (0.65 * stratum + 0.35 * grain * close_detail);
    ALBEDO = pigment * (1.0 - micro_strength * 0.5 + texture_amount);
    ROUGHNESS = clamp(surface_roughness + grain * close_detail * micro_strength * 0.3, 0.08, 1.0);
    METALLIC = surface_metallic;
    SPECULAR = specular_strength;
    float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
    float fresnel = (1.0 - facing) * (1.0 - facing) * (1.0 - facing);
    vec3 rim_color = mix(vec3(0.14, 0.28, 0.58), vec3(1.0, 0.62, 0.23),
        smoothstep(-0.2, 0.8, NORMAL.y));
    vec3 mineral_glow = pigment * crystal_amount * (0.16 + fresnel * 0.30);
    float flow = 0.5 + 0.5 * sin(world_point.z * 2.1 + world_point.x * 0.8 - animation_time * 0.9);
    vec3 water_glow = vec3(0.015, 0.34, 0.42) * water_amount * (0.28 + flow * 0.13);
    EMISSION = (pigment * vec3(0.055, 0.065, 0.12) + rim_color * fresnel * rim_strength
        + mineral_glow + water_glow) * light_intensity;
}

void light() {
    float wrap = dot(NORMAL, LIGHT);
    float soft_band = smoothstep(-0.24, 0.64, wrap);
    float lit_band = smoothstep(0.43, 0.78, wrap);
    vec3 color_split = mix(vec3(0.29, 0.34, 0.66), vec3(1.0, 0.84, 0.63), soft_band);
    // Godot applies ALBEDO to DIFFUSE_LIGHT after this function. Do not square it.
    // LIGHT_COLOR already contains PI in Godot. Normalize to avoid clipping
    // slate/paint pigments to white under the actual harbor sun.
    DIFFUSE_LIGHT += color_split * LIGHT_COLOR * ATTENUATION * (0.24 + 0.64 * soft_band + 0.12 * lit_band) * 0.318309886;
    vec3 half_vector = normalize(LIGHT + VIEW);
    float n_half = max(dot(NORMAL, half_vector), 0.0);
    float broad = smoothstep(mix(0.88, 0.56, surface_roughness), 0.995, n_half);
    float glint = smoothstep(0.985, 0.999, n_half) * (1.0 - surface_roughness);
    SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * (broad * 0.22 + glint * 0.36)
        * specular_strength * mix(vec3(1.0), ALBEDO, surface_metallic) * 0.318309886;
}
