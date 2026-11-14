# Independent review of the actual Native artifact from Host run 43596913210

## Outcome and scope

The completed Native desktop evidence passes the independent original-file, source, log, image and report checks described below. This is **not Android acceptance or release approval**. The coordinator reported failures in the subsequent API35 Android jobs; their original diagnosis is separate. No source changes, renderer captures, Godot runs, Android runs or unit-test executions were made for this review.

| Binding | Exact original |
| --- | --- |
| Host | `1e22d2455937e2640d1e44e153d290746f3afe49` |
| Native | `e9a9f60f20403ffa6b2b26d1437f958b2704d2aa` |
| Native tree | `1c2b5da7a4485cb8b911adcac2b567481cf902b5` |
| Run / attempt | `43596913210` / `1` |
| Native-producing job | `132454178537` |
| Artifact | `14118079396`, `lumo-candidate-pinned-native-gameplay` |
| Original ZIP bytes | `226400623` |
| Original ZIP SHA256 | `ff250719d53ed02c3e13900c4771975bbf8661e74059b9757133891f96804457` |

The artifact was downloaded once. Its size and digest match the actual API catalog. All ZIP CRCs passed, all member paths were safe and unique, and its 6074 original files total 588336682 uncompressed bytes. Every file was hashed again after the readers ran: the file set and all original bytes remained unchanged. All 188 original PNGs passed a PNG format/dimension check, Pillow verification and full pixel decode. This does not claim that unrelated diagnostic images are nonuniform; the unchanged required readers perform their own stronger image checks where specified.

## Original Native contracts

| Contract | Independent confirmation |
| --- | --- |
| Nextgen | All **52** probe/mode/order entries exactly match the pinned original runner and `results.tsv`; **32 headless and 20 rendered** modes. Their actual required markers are present and no engine or leak error marker was found. |
| Studio 2020 extension | Original unchanged reader reproduces **17 PNGs, 3 original sidecars and 1 facial movie** and exactly matches `studio-2020-images.json`. |
| Existing raster readers | All four original readers also replay successfully on separate copies: **24 Studio, 4 Village, 6 Puzzle-menu and 7 Safe-Area PNGs**. Their six generated manifest documents equal the six original documents exactly. |
| Standalone C4 return regression | Exactly one original `CONNECT_FOUR_RETURN_PASS checks=21` status line in `connect-four-return.log`. This is the native regression, not a claim about an actual Android Activity return. |
| Dream | Original unchanged reader confirms **5 probes, 7 PNGs and 2 reports**, including actual changing frame pairs and the complete before/after source inventories. |
| Live | All **9** original probe markers pass; the exact original Python heredoc, run on a separate copy of the capture files, reproduces the **7-PNG** manifest exactly. |
| Discovery | All **10** original probe markers pass; unchanged `verify_discovery_rasters.verify` confirms **38 PNGs**, the actual Hub GLB/rig identity, all 11 Wonder captures and their 136 geometry checks, and the original task-linked image changes. |

The complete log review covers 119 relevant original log files and finds zero `SCRIPT ERROR`, `Parse Error`, `ERROR:`, assertion-failure, leak, remaining-resource, probe-failure or probe-timeout matches. The current `project.log` still reports **117 PASS / 7 WARN / 0 FAIL**. It is not warning-free. The separate warning/callgraph review is preserved in Native commit `bca73b31e277be2a4797594b495ce8130b914f65`; the same seven actual warning lines are retained here in the new original Project log.

## Original Lumo: what was actually proved

The current headless Jump log ends with:

```
[JumpOriginalLumo] PASS: original 65-bone GLB visible, grounded, moving, paused and resumed
```

It is line 16 of the original per-probe file and line 9336 of the single archived full job log. The pinned test checks that the actual imported rig is usable, contains 65 bones, reports `imported_packed_scene`, is visible, and that the old procedural visual is hidden; it also checks movement, pause and resume. This proves the current tested normal path. It does not remove the source's conditional primitive fallback when the rig cannot load or fit, and it does not establish the same result on an Android device.

One additional existing Jump PNG was opened without modification: `nextgen/captures/jump_nextgen_capture/jump_1280x720_ready.png`. The player is visible from behind on the first island with orange ears/tail, a white tail tip and dark blue clothing. Movement, jump, pause and Spiele-return controls are visible and separated. The face and goggles are not judged from this rear view; rig identity comes from the source-bound test, not appearance alone.

The new original `discovery/captures/hub/hub_fold_landscape.png` was also opened unchanged. The original fox with blue goggles and dark clothing is fully framed; all eight game cards, both profile controls and Back are visible and unoccluded. The mandatory original Hub identity JSON separately binds both actual capture sizes to the GLB, adapter, 65 bones, nine original clips and skinned mesh resources. These are desktop Compatibility captures. No Android-original-Lumo or physical 60-FPS conclusion is drawn.

## Source and environment

The original global/Nextgen/Dream source stamps identify the exact Native commit and tree above; their tracked-dirty stamps are empty. Both original Dream inventories contain **all 3712 committed files**, fully materialized with no skip-worktree rows. Every recorded actual blob and file mode was independently compared with the complete immutable Git tree. Both tracked inventories and the index hash are equal before/after. Each phase separately inventories **604 generated import-metadata files and 356 generated UID files**; these are not silently called tracked-source changes.

The copied original Dream reader is exactly Git blob `da8eed7d6383fcbc82a03596518a5fcc3b9a00c5`, SHA256 `f7296a802d15c382dbcc77640373a0f53e30306fcaab3de869549ff1656de89d`. The other reader blobs and all replay methods are recorded individually. Readers that write manifests were run only on separate copies; the originals remained unchanged.

Local evidence-reader environment:

- CPython **3.12.14**, build `main, Aug 25 2026, 14:00:49`, Clang **22.1.3**.
- Pillow **13.0.0**.
- The actual CI log explicitly reports Pillow **12.3.0** at line 2838; its installation is also recorded at lines 1571 and 11257. The source workflow pins that version. The full CI Python patch version was not explicitly printed by the observed Native gate, so none is inferred.
- Original Godot: **4.6.3.stable.official.7d41c59c4**. No local Godot was launched for the replay.

The exact equality of the original/recomputed manifests was checked despite the explicitly recorded Pillow version difference.

## Shared original full-job log and observed timing

QA downloaded the terminal full job log exactly once. This review read that same immutable Git blob; it did not download the Actions log again.

- Host evidence commit: `5f964e9b56a2505ef667cefacb14c95f279aab09`.
- Path: `docs/evidence/live-integration-20261114/final-1e22d245/terminal-verify-and-build/job-132454178537-original.log`.
- Blob: `511fdb28b35703da777e38f6eda83722c4ca9d17`.
- Bytes: **1937867**; SHA256: `03751f95954ae914925ba6247ebfb7c546bca9a382fa282a512bc7ab7aaa3ac5`.

The complete text of each artifact runner log was matched against a contiguous block of that timestamped original job log:

| Original runner | Full-job lines | Observed stdout timestamp span |
| --- | --- | --- |
| Nextgen52 | 8840–10311 | 13:37:37.5554664–14:23:11.4769670 UTC; **45:33.921** |
| Dream | 10382–10469 | 14:23:12.9328210–14:24:28.2833304 UTC; **75.351 s** |
| Live | 10493–10637 | 14:24:28.3463985–14:25:39.6781668 UTC; **71.332 s** |
| Discovery | 10638–11144 | 14:25:55.4653522–14:44:55.8903674 UTC; **19:00.425** |

These are original stdout timestamp spans calculated to milliseconds, not process timers or device frame rates. The overall Native stage was 13:19:58–14:23:11 UTC (**63:13**). The same 25-image Learning probe has identical textual output in its two actual invocations; parent-block containment distinguishes them: **621.213 s** in Nextgen, **775.197 s** in Discovery, within the unchanged 900-second collection budget. No limit was changed during this review.

## Permanent files and limits

The archive preserves relevant original logs, JSON reports, TSV results and source stamps individually, all PNGs required by the original raster manifests, the viewed Jump frame, and the original facial AVI and MP4. It also preserves the exact readers, replay transcripts/review scripts, environment, source proof and original metadata.

**290 selected original files, including 111 PNGs**, are copied byte-for-byte as Git blobs. Their total size is **77868957 bytes**. The full original artifact index covers all **6074 files and 188 PNGs**; the remaining 77 PNGs and generated caches are indexed without another Git copy. No 226-MB ZIP/base64 monolith is stored. Original bytes, dimensions, SHA256 and Gitblob identities are retained. The original Actions artifact has its own recorded retention expiry; its complete digest is not represented as a claim that every cache byte was separately archived.

The additional current-ref review confirms that `main` and PR173's actual base are older ancestors of the already integrated producer head. The PR test merge has the same complete Native tree as the accepted pin. That review caused no new source or ref change. This evidence commit adds documentation and originals only; it must not move the central Native branch, Host pin or release state.
