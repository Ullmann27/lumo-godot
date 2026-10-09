# Lumo character, playable welcome and Sonnenhafen integration

## Source selection

This is a development candidate, not a production release or a physical-device approval.

The integration starts at **de91cc966f7a8b5d43b04e0dd9d67b0e28dbe09b**, the Godot revision embedded by Lumo Lernen **0.12.11+1918**, app source **ab21b2295ca5307bae5e07c0c8a01c3017ee91a3**. Live GitHub inspection confirmed APK run [37961627110](https://github.com/Ullmann27/lumo-lernen/actions/runs/37961627110) succeeded. The broader [37956116041](https://github.com/Ullmann27/lumo-lernen/actions/runs/37956116041) succeeded on a different app commit, **4b2f837a3475c14033806c13f25e1a77b89a307a**. Its Android evidence does not automatically prove this candidate.

Godot PRs [38](https://github.com/Ullmann27/lumo-godot/pull/38), [39](https://github.com/Ullmann27/lumo-godot/pull/39), [40](https://github.com/Ullmann27/lumo-godot/pull/40) and [41](https://github.com/Ullmann27/lumo-godot/pull/41) were inspected. Selected visual files came from PR41 **8348496b6f6db32febb0d919aad49b83bad04b5e**. Its actual eye geometry already contained the PR40 work, despite the branch ancestry. Importing that entire older tree would remove newer action/workshop, snapshot, lifecycle and profile-budget safeguards; this branch therefore retains the tested de91 tree and imports only character/studio/garage changes and their relevant probes.

README, CLAUDE, CODEX_START, OPUS_NEXT, handoffs, source, workflows and tests were reviewed in both repositories where present. Godot did not contain a root README.md at the inspected revision. The kart controller, world/track modules, catalog/fleet/workshop, input controls, bridges, storage and performance modules were inspected before choosing changes. No physics, checkpoint, reward or track projection rewrite is included.

## Actual identity references

The current learning app has both a purple-hoodie animated Lumo family and a goggles/navy-outfit avatar family. For this racing figure the active `lumo-lernen/assets/lumo_design/fox/fox_avatar.png`, `fox_arms_open.png`, the existing Godot character sheets and `docs/design_targets/2026-10-08-kart-fahrzeuge/03_lumo_detail_kopf_fahrer_kart_materialien.png` are the relevant references. They agree on broad cream cheeks, inset brown eyes, a small rounded triangular nose, swept triangular ears and a warm open smile. The racing suit and goggles preserve the established kart identity.

The supplied attachment ZIPs were inspected: they contain older code/documents rather than importable 3D models or the current reference images. No newly generated concept image replaces game geometry.

## Character changes and reproduced defects

1. **Authored pose lost during animation.** PR41 sculpted the fox jaw at a new position and ears at a wider angle, but race/companion updates restored old hard-coded values. A real engine replay failed 365 of the original 1,095 checks. The correction stores each newly built jaw position and ear angle, clears them on rebuild, and applies animation offsets relative to those values.
2. **Detached eye/mouth appearance.** Actual four-view desktop renders exposed shallow-but-still-protruding eyes and a mouth volume too far in front of the cream muzzle. The new bounded depth test initially failed 11/21 checks. Eyes now follow the local head slope; the mouth is a curved, closed, upward-cornered shell supported by a continuous cream chin.
3. **Iris floating above the eye.** Independent review calculated an approximately 10–16 mm gap between the former iris and white ellipsoid. A new vertex-contact check failed for both eyes. Iris and pupil now conform to the same ellipsoid with 1.5 mm and 3 mm surface allowances. Highlights were moved with them. This is real geometry, not a replacement sprite.
4. **Level of detail.** The mouth and conforming eye overlays provide lower-detail meshes through the existing `far_geometry` mechanism. Degenerate tapered-mouth triangles are omitted and surface normals are derived from the actual winding. Existing batching, hysteresis, wheel/hand attachments and driver selection remain.
5. **Other drivers.** Non-fox pupil/highlight values inadvertently changed by PR41 were restored to the de91 values. Non-fox chin tessellation remains 28/3; only the fox uses the revised chin.

The result is a measurable improvement toward the references. It is not a claim of pixel identity with illustrative artwork, finished AAA character production, a new skeletal rig, or complete facial blendshapes. Existing procedural joints remain the compatible animation pipeline. Speech poses still require visual review in addition to joint tests.

## Playable welcome screen

The existing five-step menu gains a direct **Spielen** action using the current selected setup. Its start signal is the existing race entry, so it enters the real countdown/race flow. Driver, kart, course, tempo and workshop selection remain available through the existing setup.

Portrait screens place the actual live 3D kart above the independently scrollable modes. The camera now keeps the fox facing the child through a small idle arc; reduced motion holds it still. Garage dragging and inspection views remain available. Camera framing was corrected after actual screenshots showed the former angle turning Lumo sideways.

The start regression uses real input events at 1280×720, 800×480, 412×915, 320×568 and 900×1360. It checks usable preview/navigation bounds, at least 44 px play targets, exactly one start per touch, the emitted setup and bounded/still camera behavior. Rendered runs also save three unretouched viewport PNGs.

No unimplemented online mode is exposed as playable. The existing menu still lists only the actual modes.

## Verification status before CI

Actual local engine: official Godot **4.6.3.stable.official.7d41c59c4**, with release archive SHA512 checked. Desktop captures use X11/OpenGL compatibility on Mesa llvmpipe. These are **Godot desktop runtime captures**, not Android screenshots or Fold7 performance measurements.

The following strict engine probes completed with clean exit and required markers:

| Probe | Actual result |
|---|---|
| Character pose | 2,325 checks, 0 failures; race, companion, speech, reduced-motion settings and same-instance rebuilds |
| Face depth/contact | 23 checks, 0 failures; real mesh depth envelope and all iris vertices |
| Original eye proportions | PASS |
| Face studio | PASS |
| Steering grip | PASS across 14 Lumo karts, 5 drivers, 2 detail levels and celebration return |
| Physical arm contact | 8,640 checks; PASS |
| Vehicle geometry/LOD | PASS |
| Vehicle details | PASS |
| Start hero | 43 checks headless; 46 checks with real GL and 3 PNGs; 0 failures |

The initial static project audit returned 117 PASS / 7 WARN / 0 FAIL. Its warnings concerned legacy GLB manifest entries and a non-executable web helper; they are not silently relabeled as passes.

Final source-bound capture manifests and CI runs are required before an APK is accepted. Do not infer that CI or Android passed from this pre-CI document. The app workflow preserves the existing full native gates and Android matrix, then packages the exact APK only after required jobs succeed.

## Integration and remaining work

The main app candidate also captures attempt-log ownership before delayed learning-profile load/save. That is a narrow attribution correction, not complete multi-child isolation. Issue [233](https://github.com/Ullmann27/lumo-lernen/issues/233) remains open. Global learning/Cosmos state, immutable profile scopes, safe legacy ownership migration, quick switching, restart/write-failure scenarios and physical multiprofile acceptance remain to be completed.

The local Flutter bootstrap was stopped following automatic review rejection of an unexpected cloud-metadata access attempt. It was not retried or bypassed. The safe verification route is the existing GitHub-hosted workflow, which requires the identical profile test to fail for the expected reason on the immutable original file and pass on the candidate, followed by the unchanged broader suite.

Sonnenhafen is improved in its existing aquarium passage by a separate bounded change. It remains the existing complete reference race, not a newly invented shortcut system. A genuine shortcut requires route-aware projection, gates, minimap, rivals, ghosts and respawn treatment; drawing an extra road strip would not meet that contract.

No paid backend, public deployment, main-branch merge, child-data migration or online multiplayer activation is part of this development candidate. Physical Fold7 installation, prolonged thermal/frame-time measurements, two-client network tests and the remaining full production roadmap are still outstanding.
