# Learning wonder details — execution record

## Accepted direction
Continue Heinz's original LUMO in the actual native learning route, not an independent HTML or concept image. Preserve original fox, learning controls, answers, profiles, handwriting, journal and saved rewards. Base is the existing ambience work at 9d7d1e3c1696fa7485e2079f3d14c5e7acf3ef35, not a competing particle system.

## Implementation
A small `learning_wonder_world.gd` extends the original learning class, attaches the reactive garden to the existing atelier after its normal initialization, and provides landscape camera headroom. The production `learning_world.tscn` route points to that extension. **Original learning_world.gd, learning_atelier.gd, learning_activity.gd and the original fox are unchanged.**

The new garden observes actual activity state. Seven bounded MultiMesh geometry batches form copper planters, leaves and 35 hinged petals. The existing two-batch LumoDreamAmbience supplies the decorative particles/butterflies. Numbers, syllables and plant discovery have separate palettes. Decorative progress does not write answers, mastery, profile data, speech or rewards. An invalid activity does not allocate decorative geometry. Reduced motion retains static task feedback; suspension and SceneTree pause stop the local shader clock.

## Test-first evidence and rulings
- Original missing-route assertion failed before implementation in local exact-capsule source and GitHub run43574150201. Its unchanged existing learning-image job succeeded, preserving the baseline.
- Actual renderer inspection found flowers behind the landscape header. A projected-bounds assertion reproduced that failure; landscape framing was corrected rather than hiding flowers.
- Portrait hundred flowers originally fell behind the footer. Exact-geometry projection reproduced this with 10 failures; those flowers moved to the side border, leaving original hundred-stock and source labels intact.
- Ruling: use a short scene extension, not a rewrite of the large learning class or the concurrent team's atelier. This keeps integration additive and preserves every base learning method.
- Ruling: validate flower projection using actual mesh vertices plus the petal shader's linear hinge transform. A cube combining mutually impossible extreme deflections caused false positives; actual-geometry checks remain strict.
- Baseline invalid-scene disposal emits two material-null errors under Godot's dummy headless renderer. The exact baseline was reproduced independently. The invalid production route is therefore tested in the mandatory real-renderer regression, where those errors do not occur; they are not filtered from logs or silently relabelled as fixed.

## Verification contract
Run original learning, sharing, Studio and ambience regressions; new state/accessibility tests headless and with the real renderer; all 25 unmodified real-touch learning captures; and 11 new renderer captures with per-vertex bounds, dimensions, state metadata and hashes. Require zero SCRIPT ERROR, Parse Error or ERROR lines in these gates. Preserve ordinary renderer-compatibility warnings as evidence.

## Scope limits
No Flutter pin update, production APK/AAB, Play publication, physical Fold7/FPS/thermal claim, all-grade content review or full application visual approval. General Kart/full-project tests remain separate from the learning change; a local full-suite attempt reached the existing Kart pause-layout test but hit its time limit on software rendering. Do not present that attempt as a full-suite PASS. The final native SHA must pass integration/Android acceptance before any APK includes it.
