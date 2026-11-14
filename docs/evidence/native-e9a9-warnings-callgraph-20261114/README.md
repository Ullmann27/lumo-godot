# Seven project warnings and actual Lumo scene reachability

This is a source review and an interpretation of an already archived original CI log. It did not launch Godot, a renderer, an emulator or new tests, and it did not change either central source ref.

## Exact sources and original warning evidence

- Native commit: `e9a9f60f20403ffa6b2b26d1437f958b2704d2aa`.
- Native tree: `1c2b5da7a4485cb8b911adcac2b567481cf902b5`.
- Android host commit: `1e22d2455937e2640d1e44e153d290746f3afe49`.
- Original auxiliary run: `43595543000`, attempt 1, job `132449119326`; it checked out the Native commit above directly.
- Complete original log was already archived, unchanged, in commit `935a4d8f764d993d384e21a9e2937572415028db`, path `docs/evidence/native-e9a9-pr-workflows-20261114/logs/job-132449119326-original.log`, blob `22a2d48f0746dbb444c9f2492ef2ff04e0da779a`, SHA256 `693d0ce393aeebdf6bc5e9b81810f9ba86caca028958c53364900bd91f35942f`.
- The result is **117 PASS / 7 WARN / 0 FAIL**, not a warning-free result. The original warning lines and original line numbers are retained in `warning-lines.json`.

The six asset warnings are about `lumo_fox`, `hub_island`, `portal_learn`, `portal_games`, `portal_parent` and `star_collectible`. Their `assets/models/*.glb` targets are absent in the committed tree. `tools/validate_project.py` emits each warning by testing the corresponding manifest path. These are real missing manifest targets; they are not physical-device measurement gaps or graphics-driver warnings. The warning text says that AssetLoader uses a placeholder, but this static check does not establish that any running scene actually requested the missing model.

The seventh warning concerns `tools/build_web_bundle.sh`: its tracked mode is `100644`. Its two actual workflow callers (`build.yml` and `lumo-fleet-quality.yml`) invoke `bash tools/build_web_bundle.sh`, so they do not require its executable bit. Direct execution with `./tools/build_web_bundle.sh` would have that permission problem. This is a concrete tool metadata issue, not an engine failure.

## AssetLoader and current resource paths

`project.godot` registers `AssetLoader` as an autoload and starts `res://scenes/app/boot.tscn`. AssetLoader reads the manifest and registers its entries at startup. It creates its magenta labelled placeholder only if `get_model` is called for an absent or invalid model. The full committed text search found the `get_model` definition and documentation comments, but no executable callers. The six IDs have no executable model consumers in the reviewed source. The manifest's `character_scenes` section also has no runtime reader.

The search covered 731 tracked text files, including all `.gd`, `.tscn`, `.tres`, `.json`, `.godot`, `.sh`, `.py`, `.yml` and `.yaml` source files outside `docs`. Every file was read by its exact Git object ID, with Git SHA1 and SHA256 recorded. There are no tracked C/C++/C#/Lua/GDExtension runtime files outside docs in this tree. `exact-source-search.json` retains this inventory and all relevant matches. This is an exhaustive source/text audit of this committed tree, not a claim that arbitrary future dynamic code is impossible.

The current GameHub and LearningWorld load `scripts/characters/lumo/lumo_rigged_actor.gd` directly. That adapter uses the existing `assets/characters/lumo_facial/Lumo-Facial-Mobile.glb`, blob `4d18f240a34a5aa6320ecd61c0ab0fa719c0b0ad`, SHA256 `e14aea79eb9918f5184c8ded64e8c1343bf71f553772a4f59298ada6862d9524`. They do not request the missing `lumo_fox` catalog entry. The hub stage, old Home island, portals and decorative stars use their explicitly authored procedural meshes and materials, not the six missing catalog models. The procedural environmental geometry must not be confused with AssetLoader's magenta error box.

## The old primitive character is not limited to Home

`scenes/characters/lumo/lumo_character.tscn`, blob `6244b2a134e1f385bd77f8ec21c1b2d72557bb05`, consists of capsule/sphere/box geometry with the older clothing. Its controller does not replace that geometry with the original GLB. It is separate from the missing-model AssetLoader fallback.

| Direct consumer | Source behavior and reachability |
| --- | --- |
| `scripts/app/home_controller.gd` | Instantiates the primitive scene. Standalone GameHub Back reaches Home. |
| `scenes/games/reading_hub.tscn` | Instantiates it. Standalone Home's Learn portal falls back to this reading hub if launching the external learning app fails; standalone Kart/Jump/LearningWorld return-to-learning paths can also reach it. |
| `scenes/games/alphabet_carousel.tscn` | Actual reading-hub card reaches this scene and its primitive character. |
| `scenes/games/word_picture_match.tscn` | Actual reading-hub card reaches this scene and its primitive character. |
| `scenes/games/sound_letter_match.tscn` | Actual reading-hub card reaches this scene and its primitive character. |
| `scenes/games/word_build.tscn` | Actual reading-hub card reaches this scene and its primitive character. |
| `scenes/games/star_collect.tscn` | Current standalone GameHub has the real `stars` / STERNENJAGD card; it reaches this primitive character. It is not merely an unused scene. |
| `scenes/games/learn_card.tscn` | Registered as `learn_old`; no actual UI caller for that route was found in the committed source. |
| `scenes/characters/lumo/lumo_showcase.tscn` | Contains the primitive scene; not registered as a game route. No current runtime entry was found. |
| `scripts/games/jump_islands.gd` | Instantiates the old visual, then loads the original rig. If the rig is usable and fits its 65-bone skeleton, `visual.hide()` hides the primitive. If either condition fails, the primitive remains visible as a fallback. |

All direct references, including the manifest and source comments, are recorded in `primitive-reference-search.json` and `navigation-source-review.json`; the latter also records a separate search across the entire committed tree, including documentation. The above identifies genuine limitations in the standalone product. It is not correct to describe all older scenes as unused, or to claim original Lumo is used everywhere.

## Current embedded Android entry and return contract

The exact Host `tools/auto_install/MainActivity.kt` allows these ten direct native starts: `kart`, `jump`, `puzzle`, `build`, `settlement`, `rhythm`, `treasure`, `learning`, `cards`, `connect_four`. Unknown destinations become `kart`. It does not allow direct `home`, `games`, `learn`, `reading_hub`, `stars`, `learn_old` or the four old reading games. The settlement route additionally requires both actual village options.

`LumoGameActivity` takes `lumoLaunchOptions` from that Intent and its `LumoHostPlugin.getLaunchOptions` returns those same options. `app_boot.gd` merges the embedded host options, then uses the actual registered scene loader. Native `SceneRouter.goto` intercepts subsequent `home`, `games` and `learn` destinations when HostBridge is embedded and the current scene is no longer boot: it returns to Flutter before changing scenes. Kart/Jump and LearningWorld also explicitly take their embedded HostBridge return branches. The settlement's context-dependent return uses the same router. The unused reference Kart settings helper routes through `parent`, whose Back goes through the guarded `home` route.

Thus the reviewed regular embedded entry/navigation graph does not reach the old Home/ReadingHub/Stars characters. This conclusion is specific to this exact Host and Native source pair. It does not turn the standalone limitations into nonexistent issues. The actual Android return still has to pass the pending real Android acceptance; this source review is not that test.

Jump has a distinct reachable failure branch in the current embedded game: an unusable original rig or invalid skeleton fit leaves the primitive visible. Its existing mandatory `lumo_original_jump_visual_regression` checks the actual scene, an imported usable 65-bone original GLB, original visibility and `not procedural.visible`, then movement, pause and resume. The current Host run's original 52-probe artifact was not yet available when this source finding was written. No current pass or observed Android fallback is inferred from source or copied from a historical run. This branch must be reported if the current original probe fails; a device-specific fallback cannot be excluded by a desktop-only pass.

## Scope of this checkpoint

This checkpoint records the seven warnings, their actual consumers and the character/navigation limitation. It preserves existing source blobs and the exact Host bridge sources for review. It changes no runtime, model, renderer, tests, validation limits, central refs or Host pins. No new model or substitute image was produced.
