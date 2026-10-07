# Lumo Spielewelt: zusammenhängende Umsetzung

Flutter basis: b6a0afa421e5e854345bfac5cc2be1813a7c3e50 (PR207, exact actual SHA recorded by git).
Godot basis: 06d27c33f2273ecd3d32bb863c62303c7e51ad44 (PR22; includes PR21 rival warning).
Own branches: chatgpt/lumo-complete-games-2026-10-07 in both repositories.

Reviewed current main, open PRs and #170 claims. Existing puzzle namespace and parent polish are separate active work; no writes to their branches. New implementation uses scripts/creative/build_*, scripts/creative/rhythm_*, scripts/creative/treasure_* and scripts/games/kart_expansion_* / assets/shaders/kart_*_20261007.gdshader. Integrate immutable snapshots only after review. Existing Opus vehicle, track geometry and visual grade remain the baseline.

References: docs/lumo_game_specs/2026-10-05 (all boards/prompts), docs/design_targets/2026-10-04 and actual 10-second videos gemini_generated_video_2756fa61 (Candy Cloud Circuit), gemini_generated_video_90699f78 (Volcano Night Run). Screen captures MUST be engine-rendered. Generated raster assets are identified separately.

Implementation target: meaningful 3D build challenges, 24+ reusable pieces, support/collision validation, orbit/zoom/pan, save/load/undo, rhythm tap/hold/slide, treasure exploration/inventory/riddles, actual puzzle integration, ten distinct kart worlds and physical ramps. Learning stays in Flutter; racing never asks learning questions. Release/main merge remain subject to Heinz's approval. 60 FPS on physical Fold is not claimed without measurement.

Asset status: current Lumo is a procedural animated model; no verified fully skinned production GLB. Preserve existing Lumo and document VISUAL_GAP. No primitive model presented as final visual approval.
