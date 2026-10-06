# Lumo Kart Developer Pack - Sonnenhafen

Pack-ID: lumo.track.sonnenhafen.2026-10-06
Track-ID: sonnenhafen
Status: authoring_source

This is a reproducible 3D / level-design handoff for the existing Lumo Kart
codebase. It contains no third-party branded racing-game assets.

## Scope

- 130 individually verifiable build/gameplay/QA details
- 48 exact camera/debug views
- 17 authoritative route control points
- 10 signature setpieces
- 8 checkpoint/respawn anchors
- 10 AI racing-line anchors
- 5 Lumo Mystery Prism zones
- road width: 10.8 m
- geometry guides: road, ramp, bridge, tunnel, full_loop

## Directory

- pack.json: full structured authority
- tables/: CSV exports for DCC, level tools, sheets and QA
- guides/: geometry, shot, item, loop, implementation and QA handoff
- source_snapshots/: relevant Godot, shader and test sources from this build
- manifest.json: counts, provenance and safety state

## Hard rules

1. Road, visible rail and collision must stay spatially aligned.
2. Full loop stays authoring-only until 360-degree inversion physics passes for
   player, camera, AI, collision and respawn.
3. Mystery Prisms use only boost, shield and pulse.
4. No learning questions, answer timers or correct-answer turbo in Kart races.
5. Repeated props should remain MultiMesh/batch friendly with mobile LODs and
   simple collision meshes.
6. 60 FPS is a target budget; no physical-device PASS without measurement.

## Source snapshots

- scripts/games/kart_tracks.gd
- scripts/games/kart_world.gd
- scripts/games/kart_island.gd
- scripts/games/kart_sky_islands.gd
- assets/shaders/kart_asphalt.gdshader
- assets/shaders/kart_stylized_vertex_tint.gdshader
- tools/validate_track_packs.py
- docs/track_expansion/2026-10-06/TRACK_DEVELOPER_PACK_SPEC.md
- scripts/tests/kart_sonnenhafen_showcase.gd

Runtime files in the repository remain authoritative. Snapshots exist only to
make this exact handoff self-contained and auditable.
