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
5. **Speaking lower lip.** A real four-view speech capture showed the moving lower lip separating from the chin. Its revised closed loft has a hidden upper root inside the chin throughout the tested motion. Teeth and tongue remain head-mounted; this is a bounded geometry correction rather than a complete new facial rig.
6. **Other drivers.** Non-fox pupil/highlight values inadvertently changed by PR41 were restored to the de91 values. Non-fox chin tessellation remains 28/3; only the fox uses the revised chin.

The result is a measurable improvement toward the references. It is not a claim of pixel identity with illustrative artwork, finished AAA character production, a new skeletal rig, or complete facial blendshapes. Existing procedural joints remain the compatible animation pipeline. Speech poses still require visual review in addition to joint tests.

## Playable welcome screen

The existing five-step menu gains a direct **Spielen** action using the current selected setup. Its start signal is the existing race entry, so it enters the real countdown/race flow. Driver, kart, course, tempo and workshop selection remain available through the existing setup.

Portrait screens place the actual live 3D kart above the independently scrollable modes. The camera now keeps the fox facing the child through a small idle arc; reduced motion holds it still. Garage dragging and inspection views remain available. Camera framing was corrected after actual screenshots showed the former angle turning Lumo sideways.

The start regression uses real input events at 1280×720, 800×480, 412×915, 320×568 and 900×1360. It checks usable preview/navigation bounds, at least 44 px play targets, exactly one start per touch, the emitted setup and bounded/still camera behavior. An additional saved-race case exposed a zero-height mode scroller at 320×568. The compact arrangement now reserves a usable mode row. Reapplying the margin size after deferred minimum-size changes prevents a stale 388 px-wide layout in a 320 px window while retaining the parent safe area. The test also touches mode cards, preserves training/cup setup, and emits exactly one resume event. Rendered runs save four unretouched viewport PNGs, including the saved-race case.

No unimplemented online mode is exposed as playable. The existing menu still lists only the actual modes.

### Android safe-area correction found by full app CI

The first app candidate `f3677fff127d0348418f27c785bb774bacdc066f` failed in [full run 37972626153](https://github.com/Ullmann27/lumo-lernen/actions/runs/37972626153), before APK build. Its Flutter tests and exact profile RED/GREEN passed, and the separate Godot Stage2 passed, but the existing five-step menu probe found a real layout regression. On a 1280×720 window with 80 px of vertical system insets the new welcome required 685 px inside a 640 px safe area; the Next button extended 23 px beyond that area. This failure was reproduced locally without changing the assertion.

The welcome now hides its extra mode-description paragraph when the actual available height is below 700 physical pixels, preserving the large character, selected mode card and both start paths. At very short landscape sizes the direct Play action moves into the existing header row so it does not consume a second vertical row. The existing three-size five-step touch probe passes again. It also now exercises direct selected-Cup start inside the 640×320 safe area and emits precise bounds on a future failure. Stage2 runs this same test before accepting its character evidence. The full app workflow remains unchanged and must rerun on the updated exact pin; no failed native gate was removed.

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
| Start hero | 66 checks headless; 69 checks with real GL and 4 PNGs; 0 failures |
| Aquarium clearance | Headless and real GL PASS; 292 LOW / 324 HIGH batched props, 12 / 40 fish, complete school-motion clearance envelope |
| Aquarium driven capture | Six actual 1280×720 chase-camera views; LOW/HIGH entry, middle and exit after 6.24–6.25 m of physics-driven travel per fixture |
| Existing track contracts | All 12 tracks PASS; Sonnenhafen remains 544.8 m with 25.4 m minimum curve radius |
| Existing action workshop | Real GL PASS after the aquarium change |

The initial static project audit returned 117 PASS / 7 WARN / 0 FAIL. Its warnings concerned legacy GLB manifest entries and a non-executable web helper; they are not silently relabeled as passes.

Final source-bound capture manifests and CI runs are required before an APK is accepted. Do not infer that CI or Android passed from this pre-CI document. The app workflow preserves the existing full native gates and Android matrix, then packages the exact APK only after required jobs succeed.

## Integration and remaining work

The main app candidate also captures attempt-log ownership before delayed learning-profile load/save. That is a narrow attribution correction, not complete multi-child isolation. Issue [233](https://github.com/Ullmann27/lumo-lernen/issues/233) remains open. Global learning/Cosmos state, immutable profile scopes, safe legacy ownership migration, quick switching, restart/write-failure scenarios and physical multiprofile acceptance remain to be completed.

The local Flutter bootstrap was stopped following automatic review rejection of an unexpected cloud-metadata access attempt. It was not retried or bypassed. The safe verification route is the existing GitHub-hosted workflow, which requires the identical profile test to fail for the expected reason on the immutable original file and pass on the candidate, followed by the unchanged broader suite.

Sonnenhafen is improved in its existing approximately 30 m aquarium passage by a separate bounded change. Three LOW/four HIGH reef clusters, twelve/forty shared-mesh fish, animated schools, entrance portals and a UV-driven water/caustic shader make the passage readable and lively. The clearance test covers the entire school-animation envelope, actual GPU instance transforms, road, eight gates, cones and ramp gap. Track centerline, collision contracts, physics, checkpoints and rewards are unchanged. The short driven capture fixtures prove the passage presentation; they do not by themselves prove a complete lap. It remains the existing reference race, not a newly invented shortcut system. A genuine shortcut requires route-aware projection, gates, minimap, rivals, ghosts and respawn treatment; drawing an extra road strip would not meet that contract.

No paid backend, public deployment, main-branch merge, child-data migration or online multiplayer activation is part of this development candidate. Physical Fold7 installation, prolonged thermal/frame-time measurements, two-client network tests and the remaining full production roadmap are still outstanding.
