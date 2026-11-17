# Android Garage QA: blocked before emulator startup

Final authorized retry: run 43034616066, attempt 2, job 130572125063, completed/failure at 2026-11-11T14:07:14Z.

QA source a1d581f0b0b392e0bc4ad7d90fd38d14f8d74095 (local 609549fe9293a11128d8e648bbbacf4b743fce6d), identical tree 879f7d169b80e19d31d02f29d1cb78dd94b28a51; draft PR 456.

The existing immutable APK remains source 2718f405e69c193d0121c6f6447fe53769d7c803, Godot b357b2f8decb4b11b0cc45e9fde2b8df5ec9cbe1, x86_64 SHA-256 b863bc25bc07a7ca3fb78ad4fd56a6f816d091f821c5b9af27bfb0a7aecbcb4e.

17 guard tests, build/artifact identity, exact APK bytes and SDK setup passed. The OCR/input dependency step exited 2 after both official Ubuntu DNS preflights returned no addresses. Both original DNS output files are zero bytes; no APT fallback script or emulator stage executed. The original artifact contains no runtime/garage-result.json. No complete Android Garage PASS exists.

- qa-run.json and qa-jobs.json: unmodified API payloads for the actual QA run/attempt.
- original-failure-artifact.zip: original GitHub artifact 13861309860; its SHA-256 is 8a59b7d5538b490ec42bb565866df056b0c15e12633d6d660b0df998ea116514, verified after download.
- setup-failure.log: unchanged final setup/job tail from job 130572125063.
- guard-tests.txt and the DNS/source-identity files: extracted original artifact bytes.
- result-summary.json: clearly labeled summary, not an invented runtime result.

A previous superseded partial run 43031790627 genuinely verified APK identity, created the fictional profile and opened the native Garage. Its original 2400x1080 screenshot is in sibling android-garage-partial-43031790627/garage-title-1.png. That is a renderer proof, not proof of completed selection/confirmation/continue or Fold flows.

Exactly one retry was authorized and executed. No further run, DNS bypass, app source edit, APK build, merge or release was performed after this result.
