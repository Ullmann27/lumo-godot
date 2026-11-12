# Resume the 2026-11-12 LUMO integration

Use PR #156 and its current remote head on `chatgpt/lumo-action-stage-20261112`.
Its base is PR #155 at `b4ccf593d7833e8c259ff0f963494b00d245d03d`; older main is not the integration base.

1. Preserve any local changes and compare the full source tree with the remote development branch. GitData commits were used because CLI push lacked credentials. Local commit IDs can differ while tree IDs are identical. The local checkpoint watcher was stopped after its repeated unauthenticated rescue-branch attempts; verify actual remote persistence explicitly.
2. Inspect the existing actual-gameplay workflow for this exact head. It imports the real project, checks native touch/menu captures and roadside action, then runs all existing gameplay, complete route, opponent field and technical-art gates. Renderer failures must be resolved, not replaced with generated images or headless assertions.
3. The updated fixtures intentionally use direct native sections, eight action jumps over two laps, and the actual doubled powertrain. The continuous movement limits and complete-route requirements remain in force. Physics/action completion counts reject misleading PASS output after a failed helper assertion.
4. Pin the reviewed native head in the Flutter repository's new 2017 candidate. Preserve the immutable 2011–2016 pins. Use the existing unified build, original preview package and public test key; preserve installed learning data.
5. Run the actual Android tour and in-place update check. Publish a unique direct ARM64 test APK only after the identity, byte hash, certificate and required gates pass. Never substitute an earlier APK for this candidate.

The local environment has Godot 4.6.3 and the Android toolchain, but its desktop X socket was blocked. Use the permitted CI renderer/emulator path for actual image/device evidence. Local headless evidence does not establish Android performance.
