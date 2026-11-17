# Zauberwald: first bounded reference pass

Baseline: `47bef06db45d61d50ecd06d0b0cd0a69b9a25917` (APK2013 Godot pin).
Reference: original `Lumo_Referenzmappe_2026-11-03.pdf`, page18, visually inspected.
No replacement image design was generated. This is a roadside library, not a
drive-through library, root loop or completed world reconstruction.

| Reference feature | Previous runtime | Implemented | Still open |
| --- | --- | --- | --- |
| Layered tree-library silhouette | Small shelf with two tiny crowns | 7.6m canopy, three/four overlapping crown layers and thicker branching trunk | Large authored library building/interior and differentiated bark/leaf materials |
| Root architecture | One short root | Six-segment arch around the existing books plus three buttress roots | Actual road-connected root bridge and traversable library |
| Warm lanterns and cyan flora | Two tiny shelf lamps, one dark mushroom | Two elevated warm hanging lamps; cyan mushroom accents | Reactive lanterns and gameplay connection |
| Readable library in forest | Random tree pierced and hid first library | Accepted placement is shared with forest reservation; intersecting random clusters omitted from actual batches | Road-facing library orientation and more varied attraction composition |

The reservation runs the original tree/flower generators into disposable batches
for omitted clusters. Their random draws are preserved, so the other forest
geometry stays exactly in place. Six LOW /13 HIGH clusters are omitted, while
84 LOW /133 HIGH clusters remain. No screenshot-only hiding is used.

The existing 4.3m footprint and 80-part assembly cap remain unchanged. Library
parts:38→56 LOW,46→72 HIGH. The full world has three accepted library locations;
total reference-theme parts343→421 HIGH. All other ten factories are unchanged.
Their original-reference gaps remain documented in `LUMO_2014_HARBOR_ART.md`.

| Fixed camera | Baseline draw calls | Changed draw calls |
| --- | ---: | ---: |
| Stationary road view |124|124|
| Roadside library |282|278|
| Library front |149|145|

These are real renderer counters, not device frame-rate or thermal measurements.

## Verification actually performed

- Godot4.6.3 GL Compatibility /Mesa llvmpipe,1280×720 HIGH, isolated user data.
  All three before/after camera transforms and FOVs are identical. Images reviewed.
- Existing eleven-track contract:264 assemblies,22 placement cases,15 guards,
  four legacy cases,11 distinct hero signatures; PASS.
- Existing actual-world runner:22 track/quality cases,3043 checks,
  1199 ground-support probes; PASS. Zauberwald uses sculpted terrain, which this
  existing oracle explicitly marks NOT_ASSESSED; no invented ground-contact proof.
- Existing ground-oracle calibration:12 cases,102 checks; PASS.
- New production-world regression:601 checks, LOW/HIGH; full RNG identity,
  unchanged remaining geometry, actual cluster removal, road clearance and
  retained-crown/library clearance; PASS.
- Existing48-view pack-definition validation: all four packs PASS. The complete
  48-image render sweep was not rerun for this bounded roadside change.
- gdtoolkit formatting/lint on new files and changed nature factory; engine
  parsing and runtime tests cover the narrowly changed shared world/detail code.

Evidence in the producing workspace:

- `artifacts/kart-art/zauberwald-fixed-before/` — original runtime with new harness.
- `artifacts/kart-art/zauberwald-final-after/` — final actual runtime.
- `artifacts/kart-art/zauberwald-final-world-checks/` — complete source-bound report.
- `artifacts/kart-art/zauberwald-contract-final.log`.
- `artifacts/kart-art/zauberwald-library-final-regression.log`.
- `artifacts/kart-art/zauberwald-ground-oracle.log`.

The intermediate `zauberwald-fixed-after` images intentionally retain the discovered
tree overlap and are superseded by `zauberwald-final-after`.

No Android emulator/device measurement, full race, APK, interactive attraction or
60FPS guarantee is supplied by this change. Large visual differences from the PDF
remain; the other ten tracks have no new visual implementation in this pass.
