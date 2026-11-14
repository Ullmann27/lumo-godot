set -euo pipefail
export LUMO_MINIMAP_OUTPUT="$LUMO_DISCOVERY_EVIDENCE_DIR/mobile-minimap"
test ! -e "$LUMO_MINIMAP_OUTPUT"
test ! -L "$LUMO_MINIMAP_OUTPUT"
test "$(git rev-parse HEAD)" = "$LUMO_EXPECTED_NATIVE_SHA"
test "$(git rev-parse 'HEAD^{tree}')" = "$LUMO_EXPECTED_NATIVE_TREE"
printf '%s  %s\n' \
  f7296a802d15c382dbcc77640373a0f53e30306fcaab3de869549ff1656de89d tools/verify_dream_rasters.py \
  e1836029a196e4dcd4a4f47fd8c2010c5b460ec5bf4c0578e90e75d3a5d2ea13 tools/run_godot_probe.py \
  | sha256sum -c -
test "$(git hash-object tools/verify_dream_rasters.py)" = da8eed7d6383fcbc82a03596518a5fcc3b9a00c5
test "$(git hash-object tools/run_godot_probe.py)" = c23859ece2d62101d000d7a89556fda5d3fe4105
test "$(git hash-object scripts/games/kart_island.gd)" = 83b3b6b548cffa2790c582e061a74e37bbfcf356
test "$(git hash-object scripts/tests/mobile_safe_area_regression.gd)" = 6c58c08b8c47a7bf7c957c448b88474a984b9509
mkdir "$LUMO_MINIMAP_OUTPUT"
mkdir -p "$LUMO_MINIMAP_OUTPUT/logs" "$LUMO_MINIMAP_OUTPUT/source" \
  "$LUMO_MINIMAP_OUTPUT/captures/mobile" "$LUMO_MINIMAP_OUTPUT/captures/minimap"
"$LUMO_DISCOVERY_PYTHON" tools/verify_dream_rasters.py "$LUMO_MINIMAP_OUTPUT/source" \
  --snapshot-source "$GITHUB_WORKSPACE" --snapshot-phase before
state="$LUMO_DISCOVERY_ROOT/xdg/mobile-minimap"
mkdir "$state"
mkdir "$state/data" "$state/config" "$state/cache"
# Preserve the existing Native52 rendered MobileSafeArea limit of 420s.
XDG_DATA_HOME="$state/data" XDG_CONFIG_HOME="$state/config" XDG_CACHE_HOME="$state/cache" \
  LUMO_CAPTURE_DIR="$LUMO_MINIMAP_OUTPUT/captures/mobile" \
  LUMO_KART_MINIMAP_CAPTURE_DIR="$LUMO_MINIMAP_OUTPUT/captures/minimap" \
  "$LUMO_DISCOVERY_PYTHON" tools/run_godot_probe.py \
  --log "$LUMO_MINIMAP_OUTPUT/logs/mobile-safe-area-rendered.log" --timeout 420 \
  --required MOBILE_SAFE_AREA_PASS -- \
  xvfb-run -a -s "-screen 0 2400x1080x24" "$GODOT_BIN" \
  --audio-driver Dummy --path "$GITHUB_WORKSPACE" --rendering-method gl_compatibility \
  --resolution 2400x1080 --script res://scripts/tests/mobile_safe_area_regression.gd -- --capture \
  2>&1 | tee "$LUMO_MINIMAP_OUTPUT/logs/mobile-safe-area-rendered.runner.log"
"$LUMO_DISCOVERY_PYTHON" tools/verify_dream_rasters.py "$LUMO_MINIMAP_OUTPUT/source" \
  --snapshot-source "$GITHUB_WORKSPACE" --snapshot-phase after
"$LUMO_DISCOVERY_PYTHON" - <<'PY'
import hashlib, importlib.util, json, math, os, pathlib, re
root = pathlib.Path(os.environ["LUMO_MINIMAP_OUTPUT"])
helper = pathlib.Path(os.environ["GITHUB_WORKSPACE"]) / "tools/verify_dream_rasters.py"
raw = helper.read_bytes()
if hashlib.sha256(raw).hexdigest() != "f7296a802d15c382dbcc77640373a0f53e30306fcaab3de869549ff1656de89d":
    raise SystemExit("Mobile evidence reader SHA256 changed")
if hashlib.sha1(b"blob " + str(len(raw)).encode() + bytes([0]) + raw).hexdigest() != "da8eed7d6383fcbc82a03596518a5fcc3b9a00c5":
    raise SystemExit("Mobile evidence reader Git blob changed")
spec = importlib.util.spec_from_file_location("mobile_original_reader", helper)
reader = importlib.util.module_from_spec(spec)
spec.loader.exec_module(reader)
before, before_record = reader.original_json(root, "source/source-inventory-before.json")
after, after_record = reader.original_json(root, "source/source-inventory-after.json")
expected_source = (os.environ["LUMO_EXPECTED_NATIVE_SHA"], os.environ["LUMO_EXPECTED_NATIVE_TREE"])
for value in (before, after):
    reader.require((value["head"], value["tree"]) == expected_source, "Foreign Mobile source")
    reader.require(all(row["materialized"] is True for row in value["tracked"]), "Incomplete Mobile source")
for key in ("head", "tree", "index_sha256", "tracked"):
    reader.require(before[key] == after[key], "Mobile tracked source/index changed: " + key)
log, log_record = reader.original_text(root, "logs/mobile-safe-area-rendered.log")
runner, runner_record = reader.original_text(root, "logs/mobile-safe-area-rendered.runner.log")
reader.require(log == runner, "Mobile original/runner bytes differ")
reader.require(log.splitlines().count("Godot Engine v" + reader.ENGINE + " - https://godotengine.org") == 1,
               "Mobile requires one real engine invocation")
reader.require(reader.ERRORS.search(log) is None, "Mobile original contains runtime failure")
report, report_record = reader.original_json(root, "captures/mobile/mobile-safe-area.json")
reader.require(type(report.get("checks")) is int and report["checks"] > 0 and report.get("failures") == [],
               "Mobile original report is incomplete or failed")
marker = re.compile(r"^MOBILE_SAFE_AREA_PASS checks=(\d+) failures=0 controls=15 images=4 scope=platform_boundary_fixture$")
matches = [marker.fullmatch(line) for line in log.splitlines() if marker.fullmatch(line)]
reader.require(len(matches) == 1 and int(matches[0].group(1)) == report["checks"],
               "Mobile complete PASS marker does not match the original report")
targets = report.get("targets")
reader.require(isinstance(targets, list) and len(targets) == 15 and all(
    isinstance(row, dict) and row.get("fully_inside_true_safe_area") is True
    and isinstance(row.get("exposed_dp"), list) and len(row["exposed_dp"]) == 2
    and all(type(n) in (int, float) and math.isfinite(n) and n >= 47.95 for n in row["exposed_dp"])
    for row in targets), "The original 15 targets must retain their SafeArea/48dp checks")
profiles = {
    "dense-left-cutout": ([2400, 1080], 2.625, True),
    "dense-right-cutout": ([2400, 1080], 2.625, True),
    "same-pixels-density-one": ([2400, 1080], 1.0, True),
    "expanded-inner-display": ([2176, 1812], 2.0, True),
    "compact-portrait": ([360, 800], 1.0, False),
    "short-landscape": ([1280, 640], 2.0, False),
    "dense-restored": ([2400, 1080], 2.625, True),
}
transitions = {
    "expanded-hint-visible": ([2176, 1812], 2.0, True),
    "expanded-hint-hidden": ([2176, 1812], 2.0, True),
}
for field, expected in (("kart_minimap_layouts", profiles), ("kart_minimap_transitions", transitions)):
    rows = report.get(field)
    reader.require(isinstance(rows, list) and len(rows) == len(expected)
                   and all(isinstance(row, dict) for row in rows)
                   and [row.get("label") for row in rows] == list(expected), "Missing/duplicate/out-of-order " + field)
    for row in rows:
        size, density, visible = expected[row["label"]]
        reader.require(row.get("surface") == size and type(row.get("density")) in (int, float)
                       and math.isfinite(row["density"]) and row["density"] == density
                       and row.get("visible") is visible, "Different observed profile: " + row["label"])
mobile_images = report.get("images")
modules = ("jump", "build", "puzzle", "treasure")
reader.require(isinstance(mobile_images, list) and len(mobile_images) == 4
               and all(isinstance(row, dict) for row in mobile_images)
               and {row.get("module") for row in mobile_images} == set(modules), "Original four SafeArea captures missing")
expected_mobile = {module + "-landscape-cutout.png" for module in modules}
reader.require({path.name for path in (root / "captures/mobile").iterdir()} == expected_mobile | {"mobile-safe-area.json"},
               "Unexpected/missing original SafeArea files")
checked_mobile = []
for row in mobile_images:
    name = row["module"] + "-landscape-cutout.png"
    reader.require(row.get("path") == name and (row.get("width"), row.get("height")) == (2400, 1080),
                   "Different original SafeArea report path/dimensions")
    record, pixels = reader.png(root, "captures/mobile/" + row["path"], (2400, 1080))
    reader.require(row.get("sha256") == record["sha256"], "Original SafeArea PNG/report hash differs")
    checked_mobile.append({**record, "decoded_rgb_sha256": hashlib.sha256(pixels.tobytes()).hexdigest()})
expected_views = {**profiles, **transitions}
minimap_images = report.get("kart_minimap_images")
reader.require(isinstance(minimap_images, list) and len(minimap_images) == 9
               and all(isinstance(row, dict) for row in minimap_images)
               and {row.get("label") for row in minimap_images} == set(expected_views),
               "Missing/duplicate nine original minimap captures")
reader.require({path.name for path in (root / "captures/minimap").iterdir()} ==
               {label + ".png" for label in expected_views}, "Unexpected/missing minimap original files")
checked_minimap = []
for row in minimap_images:
    label = row["label"]
    expected_path = root / "captures/minimap" / (label + ".png")
    dimensions = expected_views[label][0]
    reader.require(row.get("path") == expected_path.as_posix()
                   and [row.get("width"), row.get("height")] == dimensions,
                   "Minimap original report path/dimensions differ: " + label)
    relative = pathlib.Path(row["path"]).relative_to(root).as_posix()
    record, pixels = reader.png(root, relative, dimensions)
    reader.require(row.get("sha256") == record["sha256"], "Minimap original PNG/report hash differs: " + label)
    checked_minimap.append({**record, "label": label, "original_report_path": row["path"],
                            "decoded_rgb_sha256": hashlib.sha256(pixels.tobytes()).hexdigest()})
result = {"schema": 1, "status": "PASS", "native_sha": expected_source[0], "native_tree": expected_source[1],
          "source_inventories": [before_record, after_record], "log": log_record, "runner": runner_record,
          "report": report_record, "checks": report["checks"], "layouts": list(profiles),
          "hint_transitions": list(transitions), "safe_area_images": checked_mobile,
          "minimap_images": checked_minimap,
          "scope": "Actual desktop renderer with asynchronous Android boundary fixture; no Android/device/FPS claim"}
destination = root / "mobile-minimap-acceptance.json"
reader.require(not destination.exists() and not destination.is_symlink(), "Mobile acceptance output must be fresh")
with destination.open("x", encoding="utf-8") as stream:
    stream.write(json.dumps(result, indent=2) + "\n")
print("[MobileMinimapOriginals] PASS 1 exact rendered probe, 4 preserved SafeArea PNGs and 9 minimap PNGs")
PY
