# Native CI hang diagnosis and checked correction

**Tested production commit:** `5498a651b5ee0b67fb1536580f51b07123aac55e`, on the two-test checkpoint `a6a0881b924a76d7a7fa844548cd5cdb77509377`. Both descend directly from the original Android native pin `332307fafa2f68a1aa3667d81b7c90d3683c5c45`.

All eleven native workflow scripts now exit successfully under an individual 90-second OS timeout. The final run has **55,509 checks**, no `SCRIPT ERROR`, no timeout, and no failing assertion. The full English gate retains its **7,239 checks** across all fourteen original profiles. The renderer replays below supplement this gate; they do not replace it.

## Original reproduced blockers

The unmodified original pin was imported with Godot 4.6.3 in 36.09 seconds, exit 0. It used the real complete asset set; the authoring sources did not produce a parser or import error. The local result cannot identify which phase the remote CI process was executing while its live logs were unavailable.

Two exact workflow tests then raised runtime errors before reaching `quit()` and remained alive until their 90-second OS timeouts:

- `learning_world_regression.gd` read the removed `teacher_enabled` / `teacher_pose` internals of the actual `LearningLumoActor`.
- `learning_generation_regression.gd` called the removed actor `_process()` method. Continuing after that correction exposed another obsolete model property, `pattern_choice`.

The same generation test also mutated the unused `patternChoices` alias while its canonical `choices` field remained valid, and supplied a `point` conversation reply without including `point` in that fixture's allowed actions. The fixes use the canonical fields and explicitly permit the behavior that fixture exercises. Production authorization checks were not relaxed.

Original import, all eleven original logs, original English failure report and commands are in [original/](original/). Intermediate logs retain the distinction between the first corrected API run, the first successful 47-check generation run and the layout correction.

## Corrected assertions

The two test files now inspect the actual director's greeting, explaining, listening and paused states; exact gaze and pointing target identities; audible/preparing status; and actual rendered mesh mouth/eye blend-shape weights. The teaching assertion additionally binds the real next receiving slot. Stop, stale playback, resume and model-selection assertions remain active.

The ten-frame row assertion projects the actual imported mesh vertices and still requires **more than one pixel of clear vertical separation**. It no longer approximates an older box mesh. The measured original overlap was 1.67 px at 412×915, 1.42 px at 690×829 and 3.38 px at 2400×1080. The original actor-height approximation was also replaced with the real mesh silhouette.

No test assertions were removed or disabled. The scoped lint naming exception only preserves the exact camelCase names of JNI fixture methods, matching the production host API.

## Narrow production changes

- On short English landscape surfaces, the eight buttons occupy one row. Their 52 dp minimum dimensions and font size remain unchanged. Horizontal padding and spacing are reduced; the question button is labelled “Fragen” with an explanatory tooltip. The return button remains “Zur Aufgabe”.
- English object groups, their colliders and numbered plinths scale together to 1.5 on those same surfaces and receive appropriate horizontal spacing. Actual geometry, the complete fox and the existing camera fit remain the layout inputs. Asset geometry and task rules are unchanged.
- Only `bridge_ten`, `addition`, `bridge_hundred` and `subtract_ten` use a camera height of 11.5 instead of 9.5, preserving the same look target and distance along Z. This resolves the real row overlap while retaining the complete fox. Other task kinds retain their previous camera.

The production change is limited to `learning_world.gd` and `learning_world_next.gd`. Actor, Blender, GLB, Kart and Jungle files are unchanged.

## Final exact workflow run

| Script | Checks | Result |
|---|---:|---|
| learning_pattern_regression | 33,077 | Exit 0 |
| learning_world_regression | 5,351 | Exit 0 |
| learning_sharing_regression | 1,811 | Exit 0 |
| learning_host_payload_regression | 135 | Exit 0 |
| learning_generation_regression | 47 | Exit 0 |
| learning_companion_scope_regression | 56 | Exit 0 |
| learning_wonder_details_regression | 100 | Exit 0 |
| nextgen_avatar_contract_review | 300 | Exit 0 |
| nextgen_learning_route_review | 7,324 | Exit 0 |
| nextgen_learning_base_audio_regression | 69 | Exit 0 |
| learning_english_regression | 7,239 | Exit 0 |

[Final commands, elapsed times and observed disk minima](final/runs.json). [Source hashes and scope](manifest.json). `gdformat --check`, `gdlint`, `git diff --check` and project validation also pass; validation reports 118 PASS / 0 WARN / 0 FAIL. Raw output is in [final/](final/).

The wonder-details test explicitly reports `invalid_scene_checked=false` on headless. The actor/base-audio and conversation checks use controlled host callbacks, not actual Android audio. Native route coverage is twelve activity kinds and does not claim complete Flutter task-bank coverage.

## Real renderer comparison

The four existing English profiles were replayed through the original regression's `_exercise` method, adding an actual screenshot after the first hint. The capture harness is in [diagnostic/english_review_capture.gd](diagnostic/english_review_capture.gd). Full fourteen-profile headless CI remained separate and unchanged.

| First hint | Original | Corrected |
|---|---:|---:|
| Ruler 640×360: stage height | 67 px | 127 px |
| Ruler 640×360: full fox height | 62.98 dp | 115.59 dp |
| Ruler 640×360: object height | 19.11 dp | 49.73 dp |
| Rubber 640×360: object height | 20.44 dp | 53.38 dp |
| Chair 640×360: object height | 35.40 dp | 94.55 dp |
| Paper 2400×1080, density 2.625: object height | 46.61 dp | 64.17 dp |
| Paper profile: distractor rubber height | 47.26 dp | 65.05 dp |

All three direct 3D targets now expose actual 48×48 dp areas on the 640×360 profiles. The numbered action buttons retain 52 dp dimensions. The original/full regression checks complete object/fox separation, unobscured mesh bounds, real object triangles, safe-area containment, actual touch input, task isolation and audio/lifecycle behavior. The corrected renderer replay has zero failures.

Original and corrected PNGs are direct Godot framebuffer readbacks:

- [Ruler before](english-before/english-ruler-640x360-first-hint.png) · [Ruler after](english-after/english-ruler-640x360-first-hint.png)
- [Rubber before](english-before/english-rubber-640x360-first-hint.png) · [Rubber after](english-after/english-rubber-640x360-first-hint.png)
- [Chair before](english-before/english-chair-640x360-first-hint.png) · [Chair after](english-after/english-chair-640x360-first-hint.png)
- [Paper before](english-before/english-paper-2400x1080-first-hint.png) · [Paper after](english-after/english-paper-2400x1080-first-hint.png)
- [8+5 at 412×960: ten plus three](bridge-after-412x960/03_ten_and_three.png)
- [8+5 at 750×832: ten plus three](bridge-after-750x832/03_ten_and_three.png)

Both math captures execute the existing production capture helper, move exactly two tokens into the first frame, leave three gold tokens, finish thirteen and check neutralized stop state. Each produces five PNGs and an empty errors list. The full fox, clear row separation and eight-blue/two-gold/three-remaining composition were visually reviewed.

These are **Linux X11 / Godot Compatibility / llvmpipe** screenshots with explicit viewport/density fixtures. They do not prove physical Fold dimensions, Android frame rate, actual spoken audio quality or GPU performance. Incidental `LUMO_LEARNING_PERF` lines are retained as raw logs and are not used as performance evidence. No FPS claim is made.

## Disk and provenance

The original import was guarded at 450 MiB free with a required reserve of 350 MiB. Its observed minimum remained above that guard. Following authorization to reuse the cache, a temporary hardlink retention prevented an unconditional diagnostic cleanup from discarding imported resources. The same cache was restored and reused; the intermediate cleanup entry therefore describes path removal, not a full release of its file data. Final cleanup is performed only after the evidence is committed and is reported separately.

No source, original asset, Blender file or another worktree's cache was removed. File byte hashes are recorded in [file-sha256.json](file-sha256.json); runtime/test source hashes are in [manifest.json](manifest.json).
