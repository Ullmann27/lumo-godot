# Permanent Puzzle menu lifecycle gates

Base: `ab9237025e5e5a30a168c4d1fbbd0a24a82690b6`. The production Puzzle fix and its real-input GDScript probe are unchanged from this base. Only `tools/validate_studio.sh` and the existing `tools/tests/test_nextgen_runner.py` are modified.

The Studio gate now invokes the menu lifecycle probe in headless mode (180 seconds) and through a real renderer with `-- --capture` (600 seconds). Existing calls, marker requirements and budgets remain. Headless JSON and renderer captures use separate evidence locations. Six fixed views at 960x540 and 640x360 join the existing24 rasters; each new filename must match its actual dimensions.

The local run used the unchanged run_probe/check_probe functions and the exact added call lines, selected into the two archived shell scripts. The portable authenticated Xorg runner on exclusive display98 started the selected renderer gate through the archived local gateway; GODOT_BIN pointed to the actual `/usr/local/bin/godot`. The actual strict `run_godot_probe.py` enforced clean exit, required marker, timeout and absence of native errors. No global display configuration changed, and the temporary authentication file was deleted by the portable runner.

Actual results: 720 headless checks and732 renderer checks, zero native errors, six real PNGs. Each PNG was individually opened and reviewed. The two machine reports preserve identical menu-state samples. The local source stamps truthfully name base ab923 and the modified gate; no new clean-source commit is claimed here.

Run the complete integrated gate in CI with `bash tools/validate_studio.sh`. The three new counterchecks are included in the already existing native workflow command `python3 -m unittest discover -s tools/tests -p test_nextgen_runner.py -v`; that exact command passed all six methods locally. Synthetic fixture rasters exercise rejection rules and are not included in this evidence directory.

Full current-source native CI, Android integration and physical Fold7 performance remain separate acceptance steps.
