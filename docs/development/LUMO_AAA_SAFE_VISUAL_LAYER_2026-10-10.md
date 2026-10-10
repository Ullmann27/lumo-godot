# Lumo Kart: additive next-generation rendering, without loss of the existing product

**Base:** Godot commit `81a1306` (reference menu / 1921 candidate). The verified Android 1920 core is preserved. Original photographs/screenshots and fixed user-facing design are indexed in the companion Flutter repository:
`docs/design/2026-10-10-lumo-games/REFERENZEN.md` and `DESIGN_BESTANDSSCHUTZ.md`.

## Actual code locations and responsibilities

| File | Task | Integration and fallback |
|---|---|---|
| `assets/shaders/kart_frosted_glass.gdshader` | Rounded sapphire glass, screen-space mip blur, neon cyan rim | Optional `ColorRect` layer **behind** interactive controls, no input interception |
| `assets/shaders/kart_glass_lite.gdshader` | Similar appearance, no screen-texture sampling | Selected for `gl_compatibility` / low detail |
| `scripts/games/visual/kart_premium_glass.gd` | Creates `Control.MOUSE_FILTER_IGNORE` decorative overlay | Never replaces navigation, save, or actual controls |
| `scripts/games/visual/kart_environment_polish.gd` | Quality-gated HDR glow / Forward+ SSAO | Composed into **existing** `kart_world.gd::_lighting()`; SSR and SDFGI remain disabled |
| `scripts/games/visual/kart_neon_gates.gd` | Non-colliding holographic arches in one `MultiMeshInstance3D` | Called after world geometry / only not low_detail and not geometry_only |
| `scripts/games/visual/kart_neon_gate_pulse.gd` | Animated decorative light along `Path3D` | Never changes player or rival positions |
| `scripts/games/visual/kart_tail_spring_adapter.gd` | Visual spring candidate for actual `TailJoint` | **Not yet connected**, because existing procedural tail animation already owns rotation |
| `scripts/games/kart_world.gd` | Single additive integration boundary | No race state, checkpoint, lap, save or kart physics changes |
| `scripts/tests/kart_aaa_visual_regression.gd` | Engine import and standalone smoke checks | Quality fallback, draw batching, no colliders |

## Renderer reality

- **Desktop Forward+:** HDR emissive glow + optional SSAO. Actual SSR is expensive; keep disabled until matched GPU recordings and frame-time budget. SDFGI is not suitable as an automatic mobile toggle.
- **Android Mobile:** existing ambient lighting + shadows + restrained glow. Bake important GI into optimised lightmaps once .glb production assets exist. Avoid per-frame reflections and expensive shadows from decorative arches.
- **GL Compatibility:** no forced SSAO/SSR/SDFGI; apply lightweight glass shader. No screen mipmaps required in the fallback.
- **Reduce motion:** UI animation, animated light pulses and tail spring must be turned off from settings when activated in screens. Currently the demo spring remains disconnected, and pulse animation must be separately wired to the app's existing reduce-motion flag before release.

## Asset production (not yet claimed as completed)

Use Blender for quad-topology authoring, glTF/GLB output; target **15–25k triangles for Lumo** and **up to 30k for a hero Kart** as upper review targets, with significantly lower LOD variants for Android. Bake normal/AO/roughness; use realistic PBR for clear-coat paint and stylized skin/fur. Blender tools, ArmorPaint, ComfyUI (texture references), Meshy/Tripo (rapid prototyping only) are optional sources, not required proprietary runtime components. Imported generated meshes must pass licensing and identity review. Do not copy third-party characters or race tracks.

**No new forced flight paths:** Existing airborne movement in `kart_island.gd::_move_vertically` is based on gravity and steering; remain in control. New tail spring and visual air-lean systems may affect only presentation, never collision, checkpoint logic or jump path. Mark any future change to lateral or air control with deterministic real-game physics regression tests.

## Approval gates

1. Godot editor import / shader compilation; standalone AAA smoke (the present PR).
2. Regression suite: pre-existing menu, Fold resize, jump, all race modes, Android input.
3. Runtime screenshots showing all five Kart menu modes, matching original Lumo character; original app screens unchanged.
4. GPU profiler comparison: 30 FPS minimum on the device profiles targeted, no crashes, no frame spikes / excessive memory; dynamically disable optional visual upgrades if needed.
5. Android APK update, offline/race save, profile and migration checks in the Flutter host.

A green isolated smoke test is NOT a release approval or evidence of equivalent AAA visuals.
