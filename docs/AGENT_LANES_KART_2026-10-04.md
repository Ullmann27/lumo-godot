# Lumo Kart agent lanes

Coordination is anchored in Ullmann27/lumo-lernen issue #170. This repository keeps Kart-specific model lanes separate from Flutter lanes.

| Agent | Model | Role | Tracked writes |
| --- | --- | --- | --- |
| Lumo Kart Opus | Claude Opus 5.5 | Godot tracks, physics, camera, performance implementation | Yes, exact claims |
| Lumo Kart Sol Review | GPT-5.6 Sol | deep physics/integration/provenance review | No |
| Lumo Kart Visual QA | MAI-Code-1.1-Flash | reference-vs-runtime visual acceptance | No |

Before any write, Kart Opus posts a CLAIM with base SHA, exact files and tests; rechecks active claims before push. Review agents never silently repair findings.

Handoff: Kart Opus -> Kart Sol Review -> (if visual evidence exists) Kart Visual QA -> Flutter Integration Sol/Luna receives the accepted Godot SHA/PCK provenance. The Flutter Godot pin is never changed by this repo's Kart write agent.

For faults: reproduce -> independent countercheck -> one writer fixes -> independent retest.

Product rule: learning progress unlocks Kart outside the game. Lumo Kart itself contains no learning questions, learning cups, answer timers or correct-answer turbo.

Required final evidence includes complete laps for all finished tracks, valid checkpoint ordering, reset/shortcut/reverse-finish tests, pause/resume/results, controller/touch behavior, real performance traces where claimed, and exact export SHA/provenance. Missing evidence is NOT EXECUTED.
