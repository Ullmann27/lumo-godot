# Combined native integration, 14 November 2026

This candidate joins the checked integration tree `d1191322989a7f20db66d4da9ba641bf6e8702ac`
with the C4/Wisp checkpoint `8db41cd0b8a05c20b1861ff279ff603e81c1b8ea`, the six ambience
files from `9d7d1e3c1696fa7485e2079f3d14c5e7acf3ef35`, and the actual Blender garden
assets and production-scene connection from `81ea4b830a03e942a97c08dd1818d5cb736adaec`.
It is an integration candidate on a separate branch. Main and previous release
identities are preserved.

## Connected behavior

- The existing learning atelier instantiates the exported storybook and blossom
  meshes. They stay outside the manipulatives and original teacher. The shared
  ambience now reaches this production route as well as the creative worlds.
- Decoration has bounded geometry, no collision or input nodes, and stops for
  reduced motion or the applicable lifecycle state. Existing task, reward,
  save and answer logic stays authoritative.
- C4 retries a refused Android return without losing its session. Its regression
  demonstrates the original three failures before the correction and 21 checks
  after it.
- Treasure uses actual available quest destinations for its two colored routes.
  Both renderer-independent coordinates and direct MultiMesh readback are
  checked: 14 headless assertions and 18 with an actual renderer.
- The earlier Treasure title/cutout fix, village economy, Kart work, 52 original
  probe/mode combinations and the verified 17-image roster remain in place.

## Small integration adjustments

The atelier source differs from the producer only by removal of a trailing blank
line. The ambience capture supplies a real `bridge_ten` task (`8 + 5`) when opening
the learning route, so a screenshot of an invalid lesson cannot serve as its
learning evidence. Production task generation is unchanged by this capture fix.

`tools/validate_live_connections.sh` adds nine mandatory original probes beside
the existing acceptance runner. It requires complete success lines, rejects
engine errors and resource leaks, and independently opens seven actual PNGs. It
checks all three garden dimensions, both two-frame scene pairs, advancing clocks,
nonuniform images and actual changed pixels. The host C4 pipeline requires this
additional step to succeed before building its APK; a skipped step is rejected.

## Evidence already obtained when assembling this candidate

- Exact Godot `4.6.3.stable.official.7d41c59c4` import: no engine/script errors.
- Shared ambience: 170 assertions, no failures.
- Garden: 544 assertions, no failures, including seven lesson kinds at three
  dimensions, original teacher visibility, projected clearances and lifecycle.
- Actual local Compatibility/llvmpipe garden render: three original PNGs at
  1280x720, 412x915 and 2400x1080; all three visually reviewed.
- Actual two-frame Treasure ambience capture: both original images saved, clock
  advanced, pixels changed.
- Existing roster helpers: 42 Python tests passed; the final whitespace-only
  cleanup retained a separate 19-test successful run.
- The C4/Wisp parent contains its actual 21/14/18/92/3341-check results and logs,
  including the explicitly unsuccessful local full-quest renderer attempts.

The full nine-probe combined run and final host/native APK acceptance are separate
gates after this source checkpoint. Local results and later CI artifacts must be
bound to their exact source and must not be relabeled as physical Android or
60-FPS performance evidence. A killed process or an interrupted Dart compiler is
not a passing test. The final host integration evidence records those outcomes.

The branch `chatgpt/lumo-learning-wonder-details-20261114` at
`587f8d6996b900f7bc2d13fca63666c2048be578` contained a proposed test/workflow and plan,
but no `learning_wonder_garden.gd` implementation when inspected. That incomplete
test is not installed as if its new progress-responsive feature existed. The
separately completed and tested garden above is connected to the real learning
scene.
