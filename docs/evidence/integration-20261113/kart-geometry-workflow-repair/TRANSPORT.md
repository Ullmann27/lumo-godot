# Exact original repair evidence

`original-evidence.tar.gz` contains all 37 original repair-pack files,
including its unchanged manifest and README. Every member was byte-compared
after reading the finished archive. Size: 246,061 bytes.
SHA256: `4f4f4f500960ca9a822ef045ba8d852eca0054c5836b7c66cee054aef1ea0cb5`.

The separately versioned original README and manifest describe paths available
after `tar -xzf original-evidence.tar.gz -C <empty-directory>`.
`archive-manifest.json` binds every original member. Inner gzip files preserve
the raw log and source bytes recorded in the original manifest. Neither the
real false-success baseline nor the genuinely clean repair run was normalized
or rerun while packaging. The later trigger-filter change retains its explicit
byte-identical execution-block proof and separate final focused checks.
