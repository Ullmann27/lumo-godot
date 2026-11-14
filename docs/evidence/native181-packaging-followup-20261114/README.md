# Native181 packaging followup on baf — source checkpoint ready

Exactly three proposed leaves, based on Native baf148b03a7a32c6ad9f737d731f900eb9113ea1 / tree0c18a0ca5200ade267cfedb4c12d5c4b0a761a00:

| Path | Final Git blob | Mode |
|---|---|---|
| assets/manifests/assets.json | 0ea85bdd7f4492eda8aeb05dd3a86a5c3ecb35f0 |100644|
| export_presets.cfg |6df845e568e8a1573233ab3ad93b96b46c457ddd|100644|
| tools/build_web_bundle.sh |07b2b8d0e7341d57a9567996a7a446ff6536195e|100755|

The first two are exact published Producer3213 blobs with byte-identical baf preimages. The Web script keeps every byte; only its executable bit changes. No gameplay, engine, runner, pin, workflow or release settings are changed. The separately frozen original review remains untouched.

## Concrete packaging finding

The baf Android include filter is empty.759 exact active Native text sources contain no separate notice reference/export hook. Host0b7 has no matching notice asset or preparer copy; its existing exporter invokes the Native Android preset to build lumo_game.pck. The new filter explicitly adds the two existing Lumo attribution files and THIRD_PARTY_NOTICES.md. Their complete original bytes and exact distribution sentences are retained under packaging-reference/native and quoted in packaging-report.json. They are not rewritten or legally reinterpreted.

This is a source packaging finding. No current PCK/APK was opened and no new export was executed, so package member absence/presence is not claimed. After Root's exact source checkpoint, a narrowly scoped genuine Android PCK export plus exact-path/byte verification can resolve physical inclusion. Root chooses that qualification.

Godot4.6's primary export documentation explains the separate non-resource include filter and named export preset: https://docs.godotengine.org/en/4.6/tutorials/export/exporting_projects.html . This reference is distinct from any executed export result.

## Handoff

source-freeze.json and publication-source-plan.json contain exact reusable Git blob IDs/modes and local paths. integration.patch preserves the full three-leaf delta, including the mode-only edit. A metadata-only permission-bit assertion during initial pack construction and the absent local baf commit object are documented in preparation-observation.json; no source/test result was substituted. Immutable blob scans use the authentic complete baf tree and disable lazy fetching.

No test, importer, engine, renderer, export, Git index/commit/ref, active worktree or remote mutation was performed. Every final source and reference was read back and hashed. Root owns publication and subsequent qualification.
