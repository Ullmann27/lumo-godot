# Legacy log policy repair

The cf039 Gameplay job completed with SUCCESS while its raw log contained
three post-PASS resource ERRORs. All three current shell runners explicitly
filtered those errors. Their actual Bash gate functions are now strict.

The unchanged regression fixture first reproduced three incorrect acceptances
against the original functions. After the filter removal, all four test groups
(12 combinations of gate and log) pass. The fixture executable only replays
logs and exits zero; it is not a substitute for engine, input or renderer proof.
The standard build and fleet workflows already discover tools/tests/.

Reproduce the focused policy check:

```sh
python3 tools/tests/test_legacy_log_policy.py
```

The complete source hashes, red/green logs and exact shell patch are preserved
here. The separate actual teardown repairs and fresh native CI remain required.
No old baseline revision or old receipt was rewritten.

`red.log.gz` preserves the original failing log bytes losslessly, including
its original formatting. The original and compressed digests are in the manifest.
