# Live / Dream / minimap reconciliation

This checkpoint combines Native `71a4c1e2304b52005950b12490d070c286c45438` and `e2d15dbc5f3709306decb139eeb70a1cf30c0b73` with two real Git parents. Their common ancestor and the directly read Native base ref are `f052c2795b765265dbb6f5c27b9e92b557d39a39`. Host `aab09275ec6b5808de9be539ca4e1a7e70921249` consumes the second parent. PR base caches were not used to infer source state.

## Exact source preservation

All three recursive trees were complete. Of 76 upstream changed paths, 13 Dream asset/runtime/test paths are already byte-identical in both integrations. The remaining 63 entries are imported by their existing Gitblob and mode: 57 original producer evidence files and six code/test/gate paths. There are no conflicting paths or removals.

The exact source union before these two provenance files is tree `a247759c62dceeecf840b35ebb2b37c118d5b396`. Its complete 3,710 non-tree entries match the calculated union, with zero differences. All 81 changes made by our first parent since the common ancestor remain intact. Of its 3,649 existing entries, 3,647 remain byte/mode-identical; only Kart layout and its SafeArea regression are updated. The remaining 61 upstream files are additions.

`source-preservation.json` contains every imported path/blob/mode, all 13 identical paths, the full-tree equality digest, exact protected-source identities and original evidence references. The eight Hub/Village/Discovery correction files are preserved exactly, along with C4/Wisp, all current runners and the existing raster readers.

## Six reviewed code and gate paths

| Path | Exact upstream blob |
| --- | --- |
| scripts/games/kart_island.gd | 83b3b6b548cffa2790c582e061a74e37bbfcf356 |
| scripts/tests/mobile_safe_area_regression.gd | 6c58c08b8c47a7bf7c957c448b88474a984b9509 |
| .github/workflows/lumo-dream-connections.yml | 321aeff8018435789cc57df3af3e3b5fecc4c910 |
| tools/tests/test_dream_rasters.py | 0af63932d9f71fd3f1c1657f6aaaba46a019a2c0 |
| tools/validate_dream_connections.sh | 834ea912003f5e27a271139646a857601baea905 |
| tools/verify_dream_rasters.py | da8eed7d6383fcbc82a03596518a5fcc3b9a00c5 |

The Kart change fits the minimap to settled safe-area/HUD geometry and excludes controls, action artwork, instructions and the live jump hint. Its additive existing test observes seven layouts and two real hint transitions. The 52-mode runner and seven-SafeArea-raster reader remain unchanged; the original 15 controls and four Mobile images are still required. Optional new Kart images have a separate destination.

Dream adds a separate five-probe/seven-PNG gate. Its exact final marker is `[LumoDreamConnections] PASS 5 original probes and 7 verified renderer PNGs`. The unchanged reader has independently recomputed UTF-8 SHA256 `f7296a802d15c382dbcc77640373a0f53e30306fcaab3de869549ff1656de89d` and 20,254 bytes. This preserves the Host workflow and delivery reader's hard binding. Dream output is separate from Live9/7 and Discovery10/38.

## Original evidence actually inspected

The combined producer SafeArea record `docs/evidence/native-dream-minimap-merge-20261114/integration/run.json`, original log and original report were read. The latter two hashes were independently recomputed and match the run record. Godot 4.6.3 completed 380 checks, zero failures, 15 original controls, seven added layouts and two hint transitions in 14.646 seconds, exit 0. The source inventory covers 1,454 materialized files and is unchanged before/after. This was a headless run with zero images; its two nonfatal compatibility-renderer warnings remain in the original log.

The original minimap records report the same 380-check test failing 26 checks on the old layout and passing on the reviewed candidate. The Dream local summary records 12 synthetic reader test methods and the 170/544-check headless probes, with no renderer run. These producer records are imported unchanged. They are not presented as a new execution of this merge.

Our actual prior Host run `43586101225` on Native71a completed all 52 modes/17 Studio rasters and Live9/7. Discovery completed eight probes and the two original Hub captures; its Learning capture was cancelled at 10/25 before final Discovery acceptance. Its independent original-log analysis is saved in Host evidence commit `a6216484bd48bc2db8615d73d1397c0b5b35feb4`. The original full log is blob `c246b7ddce9d1b66db659a93b0af8abec539ee0d` in the Host repository.

## Current validation boundary

The executor is unavailable. This reconciliation performs GitData source construction, full-tree/ancestry verification, source review and immutable-original evidence checks only. No new local shell, parser, lint, Godot, Python, renderer or Android test is claimed.

The final Host pipeline must execute Native52/17, Live9/7, Discovery10/38 and separate Dream5/7 on this exact merged commit. The original Lumo rig/framing, eight Hub routes, profile/Back/reduced-motion behavior, guarded Village save and direct visible host return remain unchanged. No failure guard, capture roster or individual probe deadline is weakened. Only the new isolated checkpoint branch is created; central Native/Host refs remain under the integration coordinator.
