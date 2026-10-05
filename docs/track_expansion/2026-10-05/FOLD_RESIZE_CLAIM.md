# Fold/resize and local track-direction claim

- Implementation PR: #17, continuing the existing `copilot/lumo-kart-upload-streckenpakete` branch.
- Base: neutral integration branch commit `7351f1756e1910389450e041185b846823a97e92`; current worktree starts at `49d145699fca8dc85b091dcf8b0d806955da4c37`.
- Fold files claimed: `scripts/games/kart_island.gd`, `scripts/games/kart_garage_menu.gd`, `scripts/tests/kart_pause_layout_regression.gd`.
- Arrow files claimed: `scripts/games/kart_world.gd`, `scripts/tests/kart_track_contract.gd`.
- Evidence: `docs/track_expansion/2026-10-05/TRACK_PROGRESS.md`, `docs/track_expansion/2026-10-05/TRACK_BUILD_ROADMAP.md`.
- Scope: responsive Godot window/viewport layout and local per-segment track-arrow direction; no portrait lock, no Flutter/Android host edits, no inferred hinge geometry, and no pixel-dependent physics.
- Required validation: Godot 4.6.3 import, existing pause/window regression, new dimension/layout/track-frame assertions, project validation. Physical Fold testing remains separate.
- Status: claim only; inspect actual Fold host matrix and runtime renderer path before implementation.
