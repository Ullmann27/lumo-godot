# Shared safe-area connection on the accepted Native base

This isolated connection combines published Studio source `20fd2880494c10f8f7d3a266956995e97f9011df`
with the existing accepted Native source `993c145304c3e5f8aa947e1c7a949a8ef8685415`.
The subsequent published `803e7a626ea6ef0aeeda9c37010e844033d3a8e3` changes a differently structured
producer test fixture and its evidence only. Its exact delta and original failure status are
preserved in the incremental review; no later product code was omitted.

## Behavior and the concrete integration repair

The shared asynchronous Android View observation refreshes layouts when usable bounds arrive,
change on rotation, or change without a window-size event. The Cards UI uses those measured
bounds and records its settled native layout separately from gameplay saves. Existing callbacks
and later Build, Settlement, Kart and Puzzle work remain connected.

The existing base also moved the Cards header around system edges. A direct textual combination
applied the same inset twice. The original new regression failed before repair; the integrated
header now subtracts the inset already covered by its parent before applying its remaining
edge and established density margin. The original failure and subsequent actual headless results
are preserved without rewriting their bytes.

## Completed local evidence

- Actual headless Cards safe-area checks: 682 passed across five profiles.
- Actual Android-boundary fixture checks: 20 passed; this is not Android execution.
- Actual headless shared-layout checks: 112 passed, retaining all fifteen controls.
- Unchanged existing Cards runtime regression: 295 checks passed.
- Four raster-roster and twenty runner/existing-roster Python contracts passed.
- The 1,231 recorded runtime source files remained unchanged throughout execution and freeze.
- The actual Native manifest generator and actual Host parser interoperated with explicitly
  synthetic files. That check proves their format connection, not rendered art or device behavior.

## Required fresh acceptance

The combined Nextgen runner retains all 43 previous probe/mode pairs and adds five, for 48.
Its original 24 Studio, four Village and six Puzzle-menu images remain mandatory, alongside all
six independent touch probe/mode pairs and 32 touch images. The additional manifest binds seven
safe-area PNGs, three original Cards layout sidecars and two original fixture reports.

No current renderer capture or visual approval is claimed here. A fresh exact-source Native CI
run and direct inspection of its original pictures are required. Actual Android JNI/window-inset,
API35/API37, complete upgrade and frame-rate/device acceptance remain separate. No APK is
published by this source connection. The running Host848 source and its Native993c pin remain
unchanged while this branch is tested.

`archive-index.json` indexes every original byte in `local-connection-evidence.tar.gz`.
`connection.json` records source identity, completed local scope and pending gates.
Generated import caches and `.uid` files are excluded from the commit.
