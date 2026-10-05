# Lumo 3D/Game Specs Handoff — 2026-10-05

Canonical visual/technical references are merged in **Ullmann27/lumo-lernen** at commit:

`89bebcb09995a6eed64038c5445c33a08f8eca5c`

Folder:
`docs/lumo_game_specs/2026-10-05/`

It contains:
- master Lumo character/animation board,
- Spielwelt technical board + key art,
- Memory board + key art,
- Cards board + key art,
- Puzzle board + key art,
- Jump & Run board + key art,
- Rhythm Party board + key art,
- Schatzsuche board + key art,
- Bauwelt board + key art,
- master implementation prompt,
- per-game prompts,
- manifest and SHA256 sums.

These are binding production references, not poster backgrounds. Runtime implementation must use real 3D geometry/collision/animation where required. If the cloud agent cannot access the cross-repo bytes, it must stop with `BLOCKED_REFERENCE_ACCESS` rather than improvising.

Existing Kart PR #4 remains separate. Do not overwrite an active Kart Opus claim.
