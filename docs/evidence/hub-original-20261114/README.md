# Actual Original-Lumo Hub evidence

Source: `71a4c1e2304b52005950b12490d070c286c45438`.
Runtime tree: `8633c0ac611f2ba9f261cc247a60997634d43dd9`.

The archive contains the two unedited PNGs produced by the actual production Hub scene, the actual imported-GLB/65-bone/skin/framing JSON, original Godot logs, renderer invocation metadata, exact changed-source blob hashes, original regression logs and the separate 38-image compatibility replay receipt.

| File | Original size | SHA256 |
| --- | ---: | --- |
| hub_fold_landscape.png | 1878803 bytes | `aa22c4818959435cbb4ed24c9470a76be55581e3fd65cd560eb52c0c145f34a9` |
| hub_portrait.png | 1822764 bytes | `c479d48648cf933e9ce53f65d8d324ae4cc0dce6de18eaa67dd812848a157b46` |

Archive: `hub-original-rendered-evidence.tar.gz`, 3711954 bytes.
SHA256: `db025f01068d0db82379a774246df20fb6cbdd60c58dd5f4a0e0325e7271921b`.
Git blob: `82f072c45823c31f88247b432e80c67864adfcf4`.

The archive was extracted to a new directory and both PNG hashes, dimensions and actual Hub identity were verified again. Portrait is 1080×1920; landscape is 2400×1080. The final source renderer exited 0 in 15.176 seconds on Godot 4.6.3 Compatibility / Mesa llvmpipe. This is actual software rendering, not a physical Android FPS measurement.

Both views show the original fox with its blue goggles and dark clothing, full ears, hands, feet and white tail tip. Back and profile controls are unobstructed. All eight landscape cards are fully visible; portrait preserves its existing scroll area with six complete cards and the final two continuing below. Root and Android QA independently reviewed the preceding capture pair from the identical production Hub blob; the final pair adds stricter actual identity metadata and was also visually opened by the Native agent.

The 38-image replay includes these two new originals plus the 36 unchanged earlier Learning/Wonder originals. It does not claim 38 newly rendered frames. Full source-bound CI and the actual Android Village roundtrip are separately required after the final host pin update.

This is an evidence-only branch. The runtime pin is the source commit above, not this archive commit.
