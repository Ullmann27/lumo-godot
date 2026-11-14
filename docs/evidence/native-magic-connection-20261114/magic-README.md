# Native Magic integration: PR172 + PR174 on f0c19

## Frozen source decision

This pack connects seven already published source files to **f0c19f9eb69ea330ac5d2b8f9948cb029ca218aa**, tree **40e7a8d073de320865613152f8a027abbe025d51**. Four modified files were assembled by applying the narrow published context hunks at unique matching positions in the immutable base. Every result equals the complete published PR174 blob. Three additional paths are absent in the complete base tree and are added byte-for-byte. No custom product correction was required.

The only files proposed for the repository are under `final-source/`. `source-freeze.json` binds all seven sizes, SHA256 hashes, Git blobs, original base blobs and direct resource dependencies. `integration.patch` is the exact minimal patch. All four modified files contain additions only: every existing line remains in order.

| Native path | Published final Git blob | Bytes |
|---|---|---:|
| `scripts/creative/treasure_world.gd` | `703873a3b0fbe7e589c81bf9695fac5ecf43cd63` | 27404 |
| `scripts/tests/treasure_exploration_regression.gd` | `a2fe8fd1e0a18403c396fb0ff73ec339a34e1a29` | 7475 |
| `scripts/learning/learning_world.gd` | `c3b1bc8c73cd764724464d8d2fe0413bdba62a96` | 45953 |
| `scripts/tests/learning_world_regression.gd` | `8e534e78509283679889335255f39a4f7d49bb64` | 23091 |
| `assets/creative/shaders/treasure_wisp.gdshader` | `63fd420156242d2bea3a5a9d3ec04eac9da4974b` | 867 |
| `scripts/creative/treasure_wisps.gd` | `2d854c19869a1959f9bbc76b9aa21c1ca8947a80` | 6446 |
| `scripts/tests/treasure_wisp_regression.gd` | `7f256c202defeeba47c8c96a577065ee2eda16c1` | 3061 |

The producers are [PR172](https://github.com/Ullmann27/lumo-godot/pull/172), head `1b01b08abd4ff2580125d787a6150e10b2fe47b8`, and [PR174](https://github.com/Ullmann27/lumo-godot/pull/174), head `f2edd325142b92a534b06518f66eadad3551412b`. PR174 is stacked directly on PR172. The large divergent comparison from our integration base to PR172 is retained only as original context and was not used as an integration patch. Narrow PR deltas are retained separately.

## Resulting behavior and preserved boundaries

Treasure mounts the bounded guide effect at the actual player position and feeds it the existing available clue locations. It presents one or two paths according to the real quest state, removes solved paths, and celebrates actual discovery or an accepted answer. The existing quest rules, save format, rewards, safe area and HUD geometry are unchanged.

Learning reuses only the celebration batch: `celebration_only=true` prevents the two Treasure guide batches from being created. Accepted token moves and existing plant interactions trigger the effect. Reduced motion and application suspend/resume are connected to the existing lifecycle. The current teacher/PCM/speech and lesson authority remain in place.

`preservation.json` binds 62 unchanged protected base files and the unchanged functions inside the two modified production files. These include the current Village/grain work, original and facial Lumo assets, Safe Areas, C4 return behavior, Treasure title/visibility regression, raster helper and strict probe runner. No binary asset is copied. The known portrait title truncation is not claimed to be repaired.

The existing `tools/validate_nextgen.sh` remains blob `3255c2e6bd6cfd4b7bb6e50e6dc9b4aaf67e5946` with **52 calls and 17 Studio2020 PNGs**. Its complete call sequence is retained in the preservation record. The three existing Learning/Treasure modes receive the additive assertions through their source updates. The new standalone Wisp regression must be attached separately; this pack does not change the 52-mode numbering, deadlines, movie/sidecar requirements or any existing raster roster.

## Separate Magic gate handoff

`gate-contract.json` is the machine-readable command contract. It supplies all arguments, required markers, output paths, isolated save-directory templates and exact Producer job references. Set `GODOT_BIN` to the existing verified Godot 4.6.3 executable and `MAGIC_EVIDENCE_DIR` to an absolute dedicated directory. Run from the subsequently published combined native checkout and bind that actual commit/tree/clean state; the old base and Producer heads are not substitutes for the new integrated source.

The four delivered command forms, with only executable/output paths parameterized, are:

```bash
XDG_DATA_HOME="$MAGIC_EVIDENCE_DIR/user-data/magic-wisps-headless" \
  python3 tools/run_godot_probe.py --log "$MAGIC_EVIDENCE_DIR/wisps.log" \
  --timeout 180 --required '[TreasureWisp] PASS' -- \
  "$GODOT_BIN" --headless --path . --audio-driver Dummy \
  --script scripts/tests/treasure_wisp_regression.gd

XDG_DATA_HOME="$MAGIC_EVIDENCE_DIR/user-data/magic-treasure-headless" \
  python3 tools/run_godot_probe.py --log "$MAGIC_EVIDENCE_DIR/quest.log" \
  --timeout 180 --required '[TreasureExploration] PASS' -- \
  "$GODOT_BIN" --headless --path . --audio-driver Dummy \
  --script scripts/tests/treasure_exploration_regression.gd

XDG_DATA_HOME="$MAGIC_EVIDENCE_DIR/user-data/magic-learning-headless" \
  python3 tools/run_godot_probe.py --log "$MAGIC_EVIDENCE_DIR/learning-3d.log" \
  --timeout 240 --required '[LearningWorld] PASS' -- \
  "$GODOT_BIN" --headless --path . --audio-driver Dummy \
  --script scripts/tests/learning_world_regression.gd

XDG_DATA_HOME="$MAGIC_EVIDENCE_DIR/user-data/magic-treasure-rendered" \
  LIBGL_ALWAYS_SOFTWARE=1 \
  TREASURE_EXPLORATION_CAPTURE_DIR="$MAGIC_EVIDENCE_DIR/images" \
  python3 tools/run_godot_probe.py --log "$MAGIC_EVIDENCE_DIR/render.log" \
  --timeout 420 --required '[TreasureExploration] PASS' -- \
  xvfb-run -a -s '-screen 0 2560x2560x24' "$GODOT_BIN" --path . \
  --rendering-method gl_compatibility --audio-driver Dummy \
  --script scripts/tests/treasure_exploration_regression.gd
```

Create the referenced directories first, reuse the existing strict importer and preserve `tools/run_godot_probe.py` unchanged. The listed Producer deadlines apply to this separate section only. They do not replace the different established core budgets. Record `source-sha.txt`, `source-tree.txt`, `source-dirty.txt`, `source-dirty-after.txt` and `engine.txt` for the actual combined source.

The rendered exploration probe writes the three existing names `treasure_choose_route.png`, `treasure_garden_first.png`, and `treasure_route_complete.png` to the capture directory. Its source sets a 1280×720 root window. No local PNG was decoded for this pack, so that source dimension is not represented as an independently measured image result. The Producer's `images.json` contains the three basename keys with `bytes` and `sha256`. Its inline image check verifies signature, minimum bytes and hash; a new combined acceptance must preserve the existing stronger raster checks and actual visual review.

## Original Producer CI

The fixed-head API records contain **8 successful workflows and 10 successful jobs** across the two heads, with **91 successful steps and 4 complementary matrix skips**. `ci-evidence.json` lists every actual run/job identity. Full original logs are retained for the two directly relevant Magic jobs; no claim of full-log inspection is made for the other jobs.

| Head / run | Actual direct job | Original result |
|---|---|---|
| PR172 `1b01b08` / [43574914204](https://github.com/Ullmann27/lumo-godot/actions/runs/43574914204) | `132386964721`, native-render-qa | Wisp14; Treasure92 headless and95 rendered |
| PR174 `f2edd325` / [43575163668](https://github.com/Ullmann27/lumo-godot/actions/runs/43575163668) | `132387709703`, actual-learning-runtime | Learning5347 and Wisp14 headless |

The PR172 render log preserves three graphics warnings: unsupported VSync change, screen-space AA unsupported on the compatibility renderer, and volumetric fog unsupported on that renderer. They are retained in the raw log and separately identified in the derived summary. No runtime ERROR prefix was found in the two original logs; command-echo strings containing ERROR are not treated as runtime findings.

The rendered Treasure result uses the earlier PR172 shared-effect blob. The final PR174 shared-effect source adds Learning's celebration-only mode and has direct headless evidence. Neither result is relabeled as a combined f0c19/C4-return/Village acceptance. No fresh Learning animation pixel review is claimed.

Artifact metadata is retained for `14105782145` (3,850,317 bytes; advertised SHA256 `d75d200139dac7fc9f48084abe494202d8cd08a176164043d5de28ebeffd489c`) and `14105997353` (13,267 bytes; advertised SHA256 `afe07b6ab6cfab2898aa119a26c95d5f7c4293dd2001e29a14230701a9a7001b`). These artifact payloads were not downloaded. The advertised digest is not a local ZIP/PNG validation claim. Original API responses and both full logs are preserved losslessly with deterministic gzip and raw/stored hash bindings.

## Source performance review and limits

The new effect has bounded geometry: two 16-instance guide batches plus one reused 20-instance celebration batch in Treasure; only the 20-instance celebration batch in Learning. Shadows are disabled on these batches. The shader uses an analytic luminous star without textures, point lights, glow postprocessing or framebuffer reads. Periodic redraw uses an accumulated 1/24-second interval, with immediate redraws on relevant state changes. Reduced motion freezes effect positions; pause stops progression. `set_routes` still creates a small bounded array at each call. These are source observations, not measurements of frame time, fill rate or allocation cost on Android.

There is no 60 FPS, Android, physical-device, audible-speech, visual-receipt or release claim. This pack ran no local Godot/renderer/device tests and changed no worktree, Git index, branch, pin, CI run or Producer file. Root must checkpoint the exact sources before the new combined validation. The separately reported 21-check C4 return result belongs to Root's prior evidence and was not rerun here.

## Storage and verification

`manifest.json` records every pack member with stored SHA256; gzip originals additionally have decompressed sizes/hashes. `SHA256SUMS` includes the manifest. The final check verifies all hashes, all original gzip roundtrips against their retrieval bindings, all seven source Git blobs and the exact patch mapping. No temporary signed download URL or access credential is included. Only compact source/API/log material is retained; no APK, image, asset archive or test-generated cache is added.
