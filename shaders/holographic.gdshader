// ════════════════════════════════════════════════════════════════════════
// HOLOGRAPHIC GRID SHADER — Cyberpunk-Glow fuer 3D-Objekte
// ════════════════════════════════════════════════════════════════════════
// Spatial-Shader (laeuft auf 3D-Geometrie). Erzeugt:
//   - Animierter UV-Grid (Linien in U + V)
//   - Fresnel-Edge-Glow (Raender leuchten)
//   - Scanline-Pulse (vertikale Banded Lines wandern)
//   - Emission > 1 fuer Bloom-Reaktion
// Wirkt zusammen mit aktivem Bloom + Volumetric Fog wie HUD-Hologramm.
// ════════════════════════════════════════════════════════════════════════
shader_type spatial;
render_mode unshaded, cull_back, blend_add, depth_draw_opaque;

uniform vec3 base_color : source_color = vec3(0.30, 0.85, 1.00);
uniform vec3 edge_color : source_color = vec3(1.00, 0.55, 0.20);
uniform float grid_density : hint_range(2.0, 64.0) = 18.0;
uniform float grid_line_width : hint_range(0.0, 0.2) = 0.04;
uniform float scan_speed : hint_range(0.0, 4.0) = 1.2;
uniform float fresnel_power : hint_range(0.5, 8.0) = 2.5;
uniform float pulse_speed : hint_range(0.0, 4.0) = 1.6;
uniform float emission_strength : hint_range(0.0, 5.0) = 2.2;

void fragment() {
    // ─── Animated UV-Grid ───
    vec2 g = abs(fract(UV * grid_density) - 0.5);
    float grid_u = step(0.5 - grid_line_width, g.x);
    float grid_v = step(0.5 - grid_line_width, g.y);
    float grid = clamp(grid_u + grid_v, 0.0, 1.0);

    // ─── Vertikale Scanline (wandert mit Zeit nach oben) ───
    float scan = sin((UV.y - TIME * scan_speed) * 22.0) * 0.5 + 0.5;
    scan = pow(scan, 6.0); // schmale, helle Linien

    // ─── Fresnel-Edge-Glow ───
    vec3 view_dir = normalize(VIEW);
    float fresnel = pow(1.0 - clamp(dot(NORMAL, view_dir), 0.0, 1.0),
                        fresnel_power);

    // ─── Pulsierender Master-Multi (atmet 0.7 -> 1.0) ───
    float pulse = 0.85 + 0.15 * sin(TIME * pulse_speed);

    // ─── Mixen: Grid + Scan in base_color, Edge in edge_color ───
    vec3 col = base_color * (0.18 + 0.55 * grid + 0.30 * scan);
    col += edge_color * fresnel * 0.9;
    col *= pulse * emission_strength;

    ALBEDO = vec3(0.0);                  // unshaded - kein Albedo-Mix
    EMISSION = col;
    ALPHA = clamp(0.25 + grid * 0.45 + scan * 0.35 + fresnel * 0.55,
                  0.0, 1.0);
}
