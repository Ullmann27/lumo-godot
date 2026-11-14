# Learning wonder details implementation plan

## Goal and accepted direction
Continue Heinz's existing LUMO, not a separate HTML demo: make the actual native learning scene a magical child-friendly space. Preserve original fox, controls, task answers, learning records, input picking and existing accessibility. The work is scoped to the learning scene so concurrent Kart/Studio/integration work is preserved.

## Approach
Use the published `9d7d1e3c1696fa7485e2079f3d14c5e7acf3ef35` ambience as the base, not a second parallel particle system. `learning_world.gd` has its own `_build_stage`, so the shared environment hook currently does not reach it. Add a presentation-only `LearningWonderGarden` to the existing `learning_atelier.gd`. Observe the production activity; never write its state. Small flowers/lanterns react to actual manipulation, with a quiet, deterministic reduced-motion representation. Keep the existing 3D board and Lumo unobstructed.

## Planned files
- New `scripts/learning/learning_wonder_garden.gd`: bounded real 3D plants/lamps and actual-progress observation, reusing existing ambience.
- Existing `scripts/learning/learning_atelier.gd`: attach to the production route, no replacement renderer or task generator.
- Existing `scripts/systems/render/lumo_dream_ambience.gd` only for verified lifecycle/accessibility defects found in tests.
- New `scripts/tests/learning_wonder_details_regression.gd`: production entry, real manipulation, reset, profile/reduced motion, pause and object/UI protection.
- New `scripts/tests/learning_wonder_details_capture.gd`: original renderer captures of before/after, phone/wide, quiet and active modes.
- Own `.github/workflows/lumo-learning-wonder-details.yml`: pinned Godot, strict logs, immutable-source evidence, no APK publication.

## Steps
1. Run the new scene-entry assertion on unchanged source and retain the actual failure.
2. Import exact production sources with verified Godot 4.6.3; obtain a runtime archive for offline local rendering.
3. Implement additive garden and hook; rerun same test, then existing learning/ambience probes.
4. Render actual production scenes on phone and wide formats, inspect every selected original image and fix overlap/contrast.
5. Push final source, create a draft against the ambience source, and notify the integration PR with exact tested SHA. No main merge, release pin update or APK claim until current full Native/Android gates pass.

## Review focus
Invalid lesson must not look completed; plant discovery is not arithmetic; changing orientation must preserve task state; app pause and reduced motion must stop decorative motion without disabling input; decoration must never intercept touch or obscure counters or the original fox.
