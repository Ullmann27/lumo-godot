# Lossless transport of the original Graphics checkpoint

`original-evidence.tar.gz` preserves all 136 original pack files without
changing their bytes, names or internal evidence scopes. Its size is
632,267 bytes and SHA256 is `7bebf69e5d9ad0dd21c92efdf45fcd1556ff8077b7c0268b0e60f156360893e4`.
Every member was byte-compared after reading the completed archive.
`archive-manifest.json` records all original names, sizes and hashes.

The original README, manifest and SHA256SUMS remain separately versioned.
Their relative file references become available after extracting the archive
into an empty directory with `tar -xzf original-evidence.tar.gz -C <directory>`.
Stored gzip files retain the original pack's recorded uncompressed hashes.

The outer container includes complete original logs and indices. It does not
add ZIP/PNG payloads excluded by the original pack. Those payload identities
and their exact original source artifacts remain separately documented in the
unchanged README and manifest. No earlier source or image review is relabelled.
