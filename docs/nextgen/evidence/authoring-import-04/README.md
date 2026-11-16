# Warm authoring/import compatibility check — 2026-11-15

Checked source: `3ea2e3777aa97e8a44ae2aacba7ff9d60ab360f8`, the local cherry-pick of Root's authoring-only commit `5a289a1` on top of final layout/runtime commit `837d7096971d0576f46da64a8ae7aff36f93d70b`. The authoring cherry-pick is already present at Root and must not be transferred again. This evidence commit changes no production file.

Both actual Blender files, all accompanying authoring files, and `art/lumo_next/.gdignore` were materialized in the existing imported worktree for the final run. No SDK, alternate engine, fresh project cache, or new asset production was used.

| Actual check | Result |
| --- | --- |
| Godot 4.6.3 `--headless --editor --import --quit` | Exit 0 in 4.02 s; no parse, script, or import errors |
| Direct Godot `--check-only` on new `tools/lumo_next/capture_learning_scene.gd` | Exit 0; no errors or warnings |
| Current routed scene: 8+5, Banane, task card | 1,774 checks, zero failures |
| Canonical companion scope | 56 checks, zero failures |
| Fourteen authoring receipt files | All byte hashes match |
| Three new Python authoring helpers | Compile-only syntax check passes; Blender generators were not executed |
| Fifteen runtime learning GLBs and the actual character GLB | All manifest hashes match |
| Ignored authoring directory | No import sidecars created |
| Web, Android, Linux presets | Existing filters exclude `art/*`, `tools/*`, and `docs/*` |

The final editor import observed approximately 690 MB peak process RSS and 4 KB maximum filesystem growth while running. It started with 702 MB free disk. The run was guarded against growth above 200 MiB, free disk below 350 MiB, and a 180-second timeout; no guard triggered. These are sampled process/filesystem observations, not renderer performance measurements.

The sole editor warning was the pre-existing nested project at `tools/lumo_kart_art/review`, which Godot ignored. The new tools and art generated no parser errors. The character GLB remains `cc210fb03bd831f21f0ba99aa12c7b7ef60f2fb5a38e0ca30a8b059d51f08163`; the editable character Blender source remains `7ce9c6a6b6f7e92747cf9d97eca62ab0a6917d3a85ce16c4fe1a58e731618a9d`.

Raw logs and commands are recorded alongside `runs.json`; the two-line parser log is losslessly gzip-compressed to preserve its trailing blank line. `runtime-assets-and-export-scope.json` records asset hashes and preset exclusions. `manifest.json` binds these files and the checked scripts.

No full APK/PCK was built in this low-disk workspace. The checks establish actual warm-import, parser, routed-scene, and scope compatibility of the integrated source; the pinned CI export and subsequent Android run remain separate build evidence. No physical Android audio or FPS claim follows from this check.
