# Actual Discovery, Village Scaling and Minimap acceptance on 84789d

**The new Native push acceptance completed successfully and its original archive was independently replayed.** Source is exactly **84789d0c2c6fb4b6ecd2897ce1951b89f958b604**, tree **91cc8fc1c6f8a36336b7ac9a12585284a983a6f6**. No source change, new Godot invocation, Android run or new image capture was performed during this review.

## Actual run and original archive

| Binding | Observed value |
| --- | --- |
| Repository / workflow | `Ullmann27/lumo-godot`, `.github/workflows/lumo-discovery-connections.yml` |
| Trigger | Actual `push` to `integration/lumo-live-connections-20261114` |
| Run / attempt | **43613299144 / 1** |
| Job | **132502826135**, `discovery-native-acceptance` |
| Job time | **16:01:24–16:20:33 UTC**, 14 November 2026; **1,149 s / 19:09** |
| Result | SUCCESS; all 17 actual job step results SUCCESS |
| Original artifact | **14122180486**, `lumo-discovery-connections-native-evidence-43613299144-1` |
| ZIP bytes | **66,954,397**, exactly the API size |
| ZIP SHA-256 | **af8a7b6f08d59f52dd25c2b061b4119b369f3793845132bb39ef9fca6b0446f0**, exactly the API digest |
| Extraction | All ZIP CRCs valid; safe distinct paths, no symlink entries |
| Original contents | **1,516 files**, **140,521,177 uncompressed bytes**, **60 PNGs** |
| Complete original job log | **381,418 bytes**, Git blob **fea946da938bc4bc14bd37359a76df5acc5d867b** |
| Job-log SHA-256 | **c8e3f3982d052cb6de3828ccbc9d11333b4fc5e3540a99e3c972252fb1bdb7d2** |

The artifact and terminal job log were fetched once. No earlier run's logs or screenshots were substituted. The full 1,516-file hash/size/CRC index is retained. The permanent Git evidence preserves all 60 original PNGs, original acceptance reports, source inventories, helper copies, actual per-probe logs, test output and CI metadata individually. Generated user-state/shader-cache directories are represented by the complete original hash index rather than duplicated as source evidence. The ZIP is not embedded as a large base64 monolith.

## Actual test groups and markers

The source-bound workflow ran **23 production probes**: 14 headless and nine rendered. Every primary probe log contains exactly one real Godot 4.6.3 engine banner. The independent scan found no runtime, parse, assertion, timeout or engine-leak failure in those 23 original primary logs.

| Group | Actual original result | Original images / reports | CI step duration |
| --- | --- | --- | ---: |
| Four preserved headless gates | Return **21**; Treasure Wisp **14**; Treasure Exploration **92**; Learning World **5,347** | Headless scope | 23 s |
| Dream | **5 probes**; exact original Dream end markers | **7 PNGs / 2 reports** | 49 s |
| Strict Discovery | **10 probes**; `[DiscoveryOriginals] PASS 10 exact probes, 38 decoded PNGs and 2 original reports` | **38 PNGs / 2 reports** | **761 s / 12:41** |
| Village schema and scaling | Economy **339**; scaling headless **42**; actual scaling renderer **46** | **2 PNGs** | 11 s |
| MobileSafeArea and Minimap | `MOBILE_SAFE_AREA_PASS checks=428 failures=0 controls=15 images=4 scope=platform_boundary_fixture` | **4 SafeArea PNGs + 9 Minimap PNGs**, original report | **236 s / 3:56** |

The original helper suites also ran successfully: **12** Dream raster tests, **24** strict Discovery tests and **11** original producer-reader tests, **47 total**. This is a separate, actual CI count; it is not the earlier local 59-test preflight or an invented 47-test Studio count.

The ten Discovery probe names and modes are preserved in the original `results.tsv`: six headless probes (Learning World, Sharing, Studio, Magic Hub, direct Village Host launch, Wonder Details) and four rendered probes (Wonder Details, Magic Hub capture, Learning World capture, Wonder Details capture). The earlier four headless gates remain a distinct unchanged workflow group. No second Discovery collector was introduced.

The 14-check Wisp result is the headless mode. This archive does not claim the separate rendered 18-check Wisp acceptance, complete Native52/17, Live9/7, the later combined Host acceptance, or Android performance.

## Strict source and index evidence

The final workflow's original source files report exact head **84789d** and tree **91cc8fc1** both before and after execution, empty tracked status, and equal before/after stage listings. Its recorded raw Git-index SHA-256 is identical throughout:

`84726d73c7e80898ca32f2f38ec1037cc6d322960a527cfea9af28b855432772`

The global, Dream, Discovery, Village and Mobile source-inventory pairs independently contain the same **3,770 materialized tracked records**, modes, blob identities and index digest. Discovery additionally retains the original commit object and complete tree/index representations verified by its unchanged strict reader. The global generated-import inventory changes from zero to 961 entries during the actual editor import; these outputs are explicitly separate from tracked source. Subsequent inventories retain 961 entries.

The exact final workflow blob is **02940ea1a3698d14b8fabaed4d5ee7af5b24907b**. The newly admitted integration ref actually ran the existing source/index gates; their successful CI result is not inferred from the local preliminary run. In particular, the earlier local Scaling raw-index mismatch remains a separately documented limitation and has not been rewritten or substituted with this CI result.

## Independent replay of unchanged originals

All five helper files were bound both to the archived originals and final Native Git blobs before execution:

| Helper | Exact Git blob |
| --- | --- |
| `verify_discovery_connections.py` | `c00ca9873106c974d66282cddfdcfaf5eb3bbebc` |
| `collect_discovery_connections.py` | `1ebdec66300dfb87bf9287d194525d3c374c8aee` |
| `verify_discovery_rasters.py` | `219e691fc8aa119cc80221b3db6c77e63caf8bfe` |
| `verify_dream_rasters.py` | `da8eed7d6383fcbc82a03596518a5fcc3b9a00c5` |
| `run_godot_probe.py` | `c23859ece2d62101d000d7a89556fda5d3fe4105` |

The original Dream reader passed read-only in **0.670 s**. The original strict Discovery reader passed read-only in **3.838 s**, including ten invocations, all 38 decoded PNGs, both original reports, helper identities and the complete source binding.

The two Python verification blocks were extracted without editing from the exact final workflow. They ran on independent copies of the Village/Mobile evidence. Because the unmodified Minimap block strictly checks absolute original report paths, only the unique original CI-run namespace was recreated for these copies. No original evidence file was removed or rewritten. The Village replay passed in **0.266 s** and the Minimap replay in **1.621 s**. Both newly computed acceptance reports are **byte-identical** to the actual CI originals.

All 1,516 original files and their names were rehashed after replay and remained unchanged. The helper replay used **CPython 3.12.14** and **Pillow 13.0.0**; the real CI used pinned **Pillow 12.3.0**. These are reported separately. The replay invoked **zero Godot processes**.

## Raster and geometry review

The original bound readers fully decoded all **60 PNGs**. Five were also opened individually for visual inspection: both CI Village Scaling frames, dense-left-cutout Minimap, expanded-with-hint Minimap, and the compact portrait fixture. Their exact file hashes and separate observations are in `visual-original-review.json`.

The Village frames show the existing 2,178-house stress fixture, a bounded detailed region, simplified farther houses, and the river/bridge separating the settlements. Header values and visible main controls are readable; horizontal action scrolling remains. These are not new-village screenshots.

In the dense and expanded examples, the Minimap sits apart from the displayed controls and live hint. A separate calculation over the unmodified report confirms that all seven visible layout/transition records place the map inside the reported safe rectangle, contain its content rectangle, and avoid the recorded control artwork/rectangles and notice rectangles. The compact portrait and short-landscape records intentionally hide the map. The two hint transition records retain seven-layout source identities and shift the map consistently with the observed notice bounds.

The compact portrait original also shows the kart sides clipped by the narrow frame. This review therefore makes **no universal complete-kart-framing claim**. Desktop keyboard instructions visible in these captures are part of the actual desktop platform-boundary fixture; the images are not presented as Android UI screenshots.

## Warnings and remaining acceptance boundary

Across the 23 primary original logs, each of three capability warnings appears nine times: V-Sync changes unsupported by the graphics driver, screen-space AA requiring Forward+/Mobile, and volumetric fog requiring Forward+. The aggregate job log contains only five sets because Discovery stores its per-probe stdout separately. No warning-free claim is made, and duplicated aggregate/runner output is not counted as independent probe evidence.

The eleven other PR workflows and twelve corresponding original job logs have their separate permanent archive on commit **2b8628c99620c095a9b06b7543d70f1921fa3b58**, under `docs/evidence/native-pr-847-20261114/`. Together with this actual push run, all **12 Native runs / 13 jobs** on this head are terminal SUCCESS. Exact metadata and original source-tree bindings are preserved.

The full combined Host release acceptance is a separate gate. Host93/43615133709 was withdrawn as a release candidate after a Flutter test-sequencing failure; its Native artifact is not silently treated as final acceptance. Root's replacement is Host **6b3047b7979dfb86d837e74a21b0fd890e4f9e66**, tree **8b0c31a26207068c28658e14c6535c39a51cf95b**, actual C4 run **43616038272 / 1**, created at 16:31:12 UTC and initially pending behind the existing concurrency group. That Host run has not been accepted by this archive. Native source remains **84789d**, and no additional Native product patch was made.
