# Original Lumo racers and shared companion, 2026-10-03

## Authorship and source

The vehicle and character geometry in `scripts/games/kart_vehicle.gd` is newly authored procedural 3D geometry for Lumo. It is generated directly from explicitly specified cross-section profiles, Catmull–Rom interpolation, shared smooth vertex normals, tubes, wheel profiles and small detail meshes. No Nintendo meshes, textures, names, sounds or animations are included. No external model pack is required to build these vehicles.

The existing Lumo reference sheet in `assets/characters/lumo/reference/01_master_character_sheet.png` informed the fox's identity: orange fur, cream cheek mask, large readable eyes, pointed ears and a cream-tipped tail. The new navy/white/cyan racing clothing and vehicle bodywork are original project work. The source file is the reproducible asset generator; its generated meshes are actual Godot `ArrayMesh` resources used by the game. There is no claim that a separate studio-quality imported or fully skinned character asset was produced.

## Visible changes

- Smooth shaped chassis, long bonnet, sculpted side pods, aerofoil spoiler, recessed front light blades and illuminated trim.
- Rounded tyre shoulders, five-spoke wheels, separate brake/rim/hub details, tread cuts, suspension links and coils.
- Curved exhaust nozzles and separate animated boost/flame and drift meshes.
- Custom head, muzzle, cheek volumes, ears, inner ear tufts and swept tail; mouth cavity, polished nose, eye layers and highlights.
- Navy race suit with white panels, cyan piping, collar, gloves and footwear; consistent clothing on the standing companion.
- Distinct `fox`/Lumo, `rabbit`/Nova and `otter`/Milo silhouettes, plus compatible badger and cat variants.
- Three vehicle styles: `comet` balanced body, `glider` narrower body and wider/taller wing, `turbo` wider stance and protective white side bodywork.

`configure(kind, color)` remains compatible with existing callers. The optional third argument selects `comet`, `glider` or `turbo`. Aliases `lumo`, `nova` and `milo` resolve to `fox`, `rabbit` and `otter`.

`set_motion(speed, steer, boost, drift)` animates wheel rotation, front steering, suspension travel, driver lean, head turn, tail, steering wheel, blinking and effects. `update_motion(speed, steer, drift, boost)` is an explicit compatibility alias; its final arguments have the order shown here.

`set_graphics_quality(profile)` sets the LOD distance to 14 m for light/low, 22 m for medium and 32 m for high, with 4 m hysteresis. Distant racers use one baked colour surface, fewer radial segments and no character joint animation. The nearby player keeps the more detailed geometry.

## Shared standing companion

```gdscript
const Racer = preload("res://scripts/games/kart_vehicle.gd")
var companion = Racer.new()
companion.configure_companion("fox")
add_child(companion)
companion.set_process(false)
companion.set_companion_pose(time_seconds, "help", voice_open)
```

The character faces local `-Z`, has its feet around `Y=0`, head centre around `Y=1.68`, and fox ear tips around `Y=2.32`. Available poses are `idle`, `speaking`, `cheer`, `think`, `help` and `walk`. Idle has a four-second cycle; the other poses use one-second cycles. The animation has separate shoulder, elbow, hip, head, ear, eye, jaw and tail joints. It uses a hierarchical node rig rather than a `Skeleton3D` skin.

`voice_open` only drives visible jaw opening. Actual playback state and speech synchronization are supplied by the host; the model does not generate audio or imply that the online speech service is working. The Flutter atlas export uses these same meshes and deterministic poses with a transparent viewport.

## Real-engine evidence

`tools/art/render_kart_portrait.gd` produces actual Godot screenshots under the same camera and studio lighting for old and current karts. It uses a neutral key of 0.95, fill of 0.35, subtle blue rim of 0.18 and ambient strength 0.40 so that the fox stays orange and the white surfaces retain shape.

The baseline is the previous `kart_vehicle.gd` at commit `77269301e63b340d2ad85b23b346b4973157d17b`; prepare it with:

```sh
git show 77269301e63b340d2ad85b23b346b4973157d17b:scripts/games/kart_vehicle.gd > /tmp/lumo-kart-vehicle-before.gd
godot --path . --rendering-method gl_compatibility --script tools/art/render_kart_portrait.gd -- --before
godot --path . --rendering-method gl_compatibility --script tools/art/render_kart_portrait.gd
```

Additional switches: `--front`, `--rear`, `--companion`, `--rabbit`, `--otter`. The outputs under `/tmp/lumo-*-current.png` are copied to `docs/screenshots/holographic/` for review. These are engine captures, not image-generation concepts. The character/vehicle portraits establish geometry and material changes; Android gameplay and device performance require separate verification of the final APK.

## Verification and budgets

`godot --headless --path . --script tools/art/verify_kart_geometry.gd` passes: all five driver variants construct, all three kart styles rebuild, wheel and steering joints animate, boost/drift effects switch, distance meshes replace nearby meshes, and all six companion poses produce finite joint transforms. Deterministic blink and jaw movement are checked.

Measured source mesh budgets after detail batching:

| Driver | Nearby triangles | Distant triangles | Nearby material surfaces | Distant surfaces |
| --- | ---: | ---: | ---: | ---: |
| Fox | 77,008 | 17,096 | 60 | 1 |
| Rabbit | 73,760 | 16,088 | 60 | 1 |
| Otter | 73,856 | 16,136 | 60 | 1 |
| Badger | 74,368 | 16,200 | 60 | 1 |
| Cat | 77,008 | 17,096 | 60 | 1 |

The real-engine portraits were rendered with Godot 4.6.3, OpenGL Compatibility and Mesa llvmpipe. They are visual verification, not a claim of phone-frame-rate performance. The renderer reports that screen-space antialiasing and volumetric fog are unsupported in Compatibility; neither is required for these character meshes. Further production work could add authored fur textures, richer facial deformation and additional animations, followed by device-specific performance tuning.
