# Completed cce Native and Graphics evidence

This checkpoint belongs only to Native `ccebbe24b489ba7971c605a2bc5187fcfea26f9e`
and tree `8409dc27958dc102d7fc84b413f28642782668aa`. All fifteen workflows passed.
Nextgen uses the frozen Host4098 contract: 41 Core pairs, 24 Studio images,
four Village images and six Touch pairs/32 Touch images. The later Puzzle 43
source needs its own acceptance.

## Exact original files

`original-checkpoints.tar.gz` contains the complete frozen `graphics/` and
`nextgen/` directories, including their original manifests, all original logs,
API metadata, source snapshots, hash indices and Root's actual image findings.
`archive-manifest.json` binds every member's original bytes, hash and size.
All 495 archive members were decompressed and compared byte-for-byte before
publication. Individual large CI ZIPs and PNG payloads are not duplicated here;
the original CI artifact/release identities remain in the evidence manifests.

The original README, manifest and checksum list for each directory are also
available directly in Git. Restore the remaining originals into an empty local
directory before running those original checksum lists:

```sh
mkdir -p restored-cce
tar -xzf original-checkpoints.tar.gz -C restored-cce
cd restored-cce/graphics
sha256sum -c SHA256SUMS
cd ../nextgen
sha256sum -c SHA256SUMS
```

The already published `auxiliary/` directory retains the separate thirteen
workflow/fourteen-job proof. This packaging change never relabels a source,
changes a log, records a new receipt or claims Android/device performance.
