# LUMO 2014: Sonnenhafen living harbor

Baseline: `47bef06db45d61d50ecd06d0b0cd0a69b9a25917` (APK 2013 Godot pin).
The original reference book `Lumo_Referenzmappe_2026-11-03.pdf` was read and
pages 16–28 rendered for visual inspection. No generated replacement design.

## Reference / old state / implementation / remaining gap

| Area | Reference | Old actual state | This change | Remaining gap |
| --- | --- | --- | --- | --- |
| Sonnenhafen storefronts | pp. 16–17: striped blue/cream awnings, flowers, warm lamps | Plain rectangular ground-floor windows | First three villa pairs receive striped canopies, doors, geometric L shop signs, planters and lamps in existing instance batches | More varied arches, facade materials and promenade furniture throughout the course |
| Harbor landmark | Existing authored wheel and lighthouse preserved | Static spokes and cabins | Wheel revolves with upright cabins; a passing racer triggers one slow cyan welcome wave, rearmed after leaving | Additional reactive harbor attractions, detailed boats and spectators |
| Performance | Mobile quality tiers | Static generation budget <=1400 pieces | Static parts remain 662 LOW /1298 HIGH; wheel uses 2 MultiMeshes (56/84 moving instances), animation capped to 20/30 updates/s, distant wheel stops | Actual Android GPU/thermal measurement remains required |
| Motion/accessibility | Calm child-friendly visual feedback | No interactive attraction | Pause/reduced-motion gate freezes wheel; no collision/reward/gameplay changes | End-to-end race-controller hook must be integrated and tested in collector |

The race-controller call is:

```gdscript
if is_instance_valid(world):
    var attraction = world.get_node_or_null("SonnenhafenHarborAttraction")
    if attraction != null:
        attraction.advance(delta, player.position, racing and not paused and not finished, reduced_motion)
```

Place it in `_physics_process` before the gem-animation loop. This branch deliberately
leaves shared `kart_island.gd` to the integration owner.

## Eleven other tracks: reference-grounded next work

The existing `track_theme_registry.gd` covers all eleven IDs. Its three factories
build static roadside assemblies into existing MultiMesh batches. This is already
integrated baseline work, not a new implementation in this PR. The following table
is a code/reference audit, not a claim that every camera or complete race was tested.

| Track / reference page | Existing authored roadside system | Concrete next target from the reference |
| --- | --- | --- |
| Zauberwald /18 | Tree library, seed lantern, mushroom garden | Drive-through tree-library interior, layered crowns/root bridge, reacting lanterns |
| Himmelsinseln (`bergwelt`) /19 | Temple terrace, beacon, floating islet | Continuous waterfall bridge composition and skyline/flight view |
| Hologramm City /20 | Holo landmark, marker, roof garden | Glass-tunnel continuity and larger distinct orbital plaza |
| Kristall Canyon /21 | Canyon observatory, survey beacon, outcrop | Deep cliff layering and readable prism-cave transitions |
| Dschungel Tempel /22 | Knowledge ruin, temple beacon, overgrown lintel | Temple courtyard, flowing waterfall gate, canopy depth |
| Candy Cloud /23 | Patisserie, donut, cloud garden | Continuous candy-glass tunnel and distinct palace silhouette |
| Volcano Night /24 | Basalt landmark, marker, outcrop | Volcanic fortress depth and visible lava-bridge interaction |
| Winter Sprint /25 | Chalet, lantern, fir bank | Dense alpine village composition, glacier tunnel and aurora response |
| Galaxy Ringway /26 | Observatory landmark, marker, orbital garden | Drive-through station/glass tunnel and convincing planet parallax |
| Desert Dune Drift /27 | Oasis pavilion, sun banner, palm pool | Dune-height variation, connected oasis market and wind-palace interior |
| Funkel Labor (`learning_lab`) /28 | Lab landmark, marker, garden | Connected glass laboratory/foyer, reacting molecular exhibit |

Do not mistake a small roadside model for a completed world section or a decorative
ring for a functioning loop. Each next target requires real route/collision, full
race, screenshots and device verification before acceptance.

## Reproducible tests

- `scripts/tests/kart_sonnenhafen_generation_regression.gd`: headless LOW/HIGH,
  placement/road clearance, unchanged 1400 static-part cap and non-Sonnenhafen isolation.
- `scripts/tests/kart_harbor_attraction_regression.gd`: **real GL renderer required**.
  Reads actual MultiMesh transforms; proves 1.761m of upright cabin movement over 2 s,
  one trigger per approach, hysteresis rearm, pause, reduced motion and distance culling.
  Headless rendering cannot read these GPU-backed transforms and exits 2 explicitly.
- `scripts/tests/kart_harbor_living_capture.gd`: identical HIGH profile/cameras,
  race/storefront/wheel captures and real render counters; optional 72-frame / 6 s
  animation (`LUMO_CAPTURE_MOVIE=1`) uses deterministic 12 Hz scene time.
  This is an actual Godot rendered animation, not a real-time device performance test.
- gdtoolkit 4.5 formatting and lint on changed runtime and new test files.

No APK, Android-emulator result, physical Fold7 result or 60 FPS guarantee is supplied
by this art branch. Global regression and full controller integration remain
collector gates.

## Local final evidence, 10 November 2026

Actual renderer: Godot 4.6.3, GL Compatibility, Mesa llvmpipe. Identical HIGH
settings and 1280 x 720 cameras, isolated user data, no device claim.

| Fixed camera | Baseline draw calls | Changed draw calls |
| --- | ---: | ---: |
| Race view | 212 | 220 |
| Storefront | 188 | 194 |
| Harbor wheel | 224 | 230 |

The animation adds visible life with a small measured draw-call increase, not
proof of 60 FPS or an across-the-board AAA visual target. The wider scenery still
has substantial silhouette, materials and density differences from the PDF.

The controller integration test `kart_harbor_race_hook_regression.gd` invokes only
the real `_physics_process`, never the attraction helper directly. It fails on
this art branch without the shared-file hook (advance, player response and resume)
and passes in the collector containing the integration owner's hook commit
`30ede7b29fe0b17fc39e191dea1e180374a8a5c8`. It covers active racing, real player
position, pause, resume, reduced motion and race finish. It deliberately places the
kart at a test fixture on the road; it is not a complete lap or device-drive proof.

Evidence in the producing workspace:
`artifacts/kart-art/final-v2-before/`, `final-v2-after/`,
`sonnenhafen-wheel-godot-6s.mp4`, `generation-final.log`,
`attraction-final.log`, `hook-before.log`, `hook-after.log`.
Captures were visually inspected. The earlier `verified-*` storefront close-up
was obstructed by the existing start gantry and is superseded by `final-v2-*`.
