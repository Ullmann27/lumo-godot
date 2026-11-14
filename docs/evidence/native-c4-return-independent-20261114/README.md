# Independent Connect Four return regression

## Actual result

The same unchanged regression was executed twice with the existing Godot 4.6.3 engine in an isolated checkout. The Android host is a fixture; the native scene, action submission, state acknowledgement and polling paths are real production code.

| Run | Exact native source | Exit | Checks | Failed assertions |
|---|---|---:|---:|---:|
| Before | `0e26153f0e58cc05739e72923b4c563a4cf380b8` plus the new test | 1 | 20 | 3 |
| After | `f0c19f9eb69ea330ac5d2b8f9948cb029ca218aa` | 0 | 21 | 0 |

The before run failed because the unchanged acknowledged exit state did not retry a refused Android return, did not close the native session after the host became available, and still had only one observed return attempt where the final assertion expected two. The third failure does not demonstrate duplicated returns.

The differing check count is caused by the unchanged test checking each observed return request in a loop: one before, two after. No assertion or test input was changed between runs. Test SHA256: `2d21893a3581ede82120853b7f7444a2b888fdd82aab44cf005c9a9c4aab09d3`; Git blob: `1d7a4cbd0f3b0d5a21ddeaf218bf27eadfe1f0bb`.

## Source and execution binding

The candidate's sole parent is exactly the before source. Its four changed files consist of two functional files and two evidence documents. The production script blobs are `cdeb31fc6cfe30c18fc6c96afb2b1d749532c37f` before and `f2ae17e7edf8ac1b2d0d72a0d477d7e1459b1458` after. The isolated checkout was detached at each exact commit, and its tracked diff was empty before both runs and after the final run.

The existing engine reported `4.6.3.stable.official.7d41c59c4`. A copied, physically separate import cache and 456 sidecars from byte-matching source assets were used to avoid unnecessary imports. The required isolated import completed in 5.530 seconds with exit 0 and no error/warning diagnostic; seven asset imports appeared in its output. No toolchain installation and no modification of another working tree occurred.

Both executions used the same headless command shown in `provenance.json`, with separate empty user-data/config/cache directories. Before: 2026-11-14 10:02:29 UTC, 0.468 seconds. After: 10:02:57 UTC, 0.670 seconds. Complete unedited logs and SHA256 bindings are retained alongside this document.

## Limits

This is a narrow independent regression result. It is not a test on an Android device, a full 52-mode gate, a visual-renderer review, an APK or release build, or a performance measurement. Frozen Flutter host `803a4e960ffb804a46b6d09417731c031f00f680` and its native pin remain unchanged. Its new original screenshot artifact is a separate review.
