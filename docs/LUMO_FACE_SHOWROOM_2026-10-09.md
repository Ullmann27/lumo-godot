# Lumo Kart – echte Gesichtsvorschau und reproduzierbare Renderbeweise (09.10.2026)

## Source and limitation

- Baseline: `f9d2b90608130014d6b5a9f665e6ae8095d8db12`, Godot PR #37 (released from Claude's earlier `240bf6a`).
- Heinz' 14:44 screenshots show an **uncommitted Claude worktree** changing face geometry, the flight goggles and the navy suit.
- Those edits are **not** in this GitHub baseline. Do not claim they are included, and do not overwrite or reimplement them blindly.
- This PR deliberately changes the **shared garage preview**, not the user's unpublished 3D face meshes.
- The same selectable 3D model remains used for the garage and in-game race.

## Real graphics changes

1. Bounded, neutral-colour `LumoFaceFill` in `scripts/games/kart_stage.gd`: restores iris, brow, muzzle and goggles readability; no additional shadow map, limited to the dedicated menu studio.
2. Subtle saturation/contrast and unchanged key shadow; no new sky/reflection texture allocation.
3. Extra **Lumos Gesicht** close-up in the existing inspection selector, preserving the six previous viewpoints, five-step garage, 14 karts, all saves and race controls.
4. Real 3D preview antialiasing 4x for HIGH, 2x for MEDIUM, disabled for LOW, isolated from gameplay.
5. New `kart_stage_visual_regression.gd` and `kart_garage_face_capture.gd` for engine-grounded QA, plus existing `kart_driver_portrait.gd` four-view captures.

## Actual screenshot evidence – produced by the workflow

When the PR CI completes, download the `kart-stage2-regression-<run-id>` Actions artifact. Required *real* Godot captures:

- `exports/face-showroom/lumo-face-1280x720.png`
- `exports/face-showroom/lumo-face-800x480.png`
- `exports/face-showroom/lumo-face-412x915.png`
- `exports/face-showroom/lumo-driver-4views.png`

Screenshots are engine renders, not the AI concept drawings. Missing, empty or failed captures fail the CI job. Review them against the **seven October 8 reference sheets**, especially face width, brown eyes, pupils, flying goggles and cheek fur.

## Later integration of Claude's uncommitted model

First commit and push Claude's visual worktree to its **own branch**. Inspect its SHA and compare it to PR #37. Then integrate selected changes into a new candidate branch with this studio/QA PR. Keep the original `kart_vehicle.gd` and 14-kart physics code safe during integration. Re-run model, arm contact, steering grips, render and APK/Android checks. An APK containing Claude's unpublished face must not be claimed until that model SHA exists in the pinned Godot commit.

**Acceptance state:** source change implemented; **visual screenshots, CI and physical Fold performance must be independently checked**. The face itself is not declared visually accepted by this limited UI/lighting pass.
