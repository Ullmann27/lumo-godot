set -euo pipefail
export LUMO_VILLAGE_OUTPUT="$LUMO_DISCOVERY_EVIDENCE_DIR/village-scaling"
test ! -e "$LUMO_VILLAGE_OUTPUT"
test ! -L "$LUMO_VILLAGE_OUTPUT"
test "$(git rev-parse HEAD)" = "$LUMO_EXPECTED_NATIVE_SHA"
test "$(git rev-parse 'HEAD^{tree}')" = "$LUMO_EXPECTED_NATIVE_TREE"
printf '%s  %s\n' \
  f7296a802d15c382dbcc77640373a0f53e30306fcaab3de869549ff1656de89d tools/verify_dream_rasters.py \
  e1836029a196e4dcd4a4f47fd8c2010c5b460ec5bf4c0578e90e75d3a5d2ea13 tools/run_godot_probe.py \
  | sha256sum -c -
test "$(git hash-object tools/verify_dream_rasters.py)" = da8eed7d6383fcbc82a03596518a5fcc3b9a00c5
test "$(git hash-object tools/run_godot_probe.py)" = c23859ece2d62101d000d7a89556fda5d3fe4105
test "$(git hash-object scripts/tests/build_village_economy_regression.gd)" = 9dd8ff269e266dd73ad5207febd87aab367a4986
test "$(git hash-object scripts/tests/build_village_scaling_regression.gd)" = c6abdb5f9576c0b48db7bd59716da52ea5fac036
mkdir "$LUMO_VILLAGE_OUTPUT"
mkdir "$LUMO_VILLAGE_OUTPUT/logs" "$LUMO_VILLAGE_OUTPUT/captures" "$LUMO_VILLAGE_OUTPUT/source"
"$LUMO_DISCOVERY_PYTHON" tools/verify_dream_rasters.py "$LUMO_VILLAGE_OUTPUT/source" \
  --snapshot-source "$GITHUB_WORKSPACE" --snapshot-phase before
check_village() {
  local name="$1" script="$2" mode="$3" seconds="$4" marker="$5"
  local proof="$LUMO_VILLAGE_OUTPUT/logs/$name.log"
  local runner="$LUMO_VILLAGE_OUTPUT/logs/$name.runner.log"
  local state="$LUMO_DISCOVERY_ROOT/xdg/village-$name"
  mkdir "$state" || return 1
  mkdir "$state/data" "$state/config" "$state/cache" || return 1
  if [[ "$mode" == headless ]]; then
    XDG_DATA_HOME="$state/data" XDG_CONFIG_HOME="$state/config" XDG_CACHE_HOME="$state/cache" \
      "$LUMO_DISCOVERY_PYTHON" tools/run_godot_probe.py \
      --log "$proof" --timeout "$seconds" --required "$marker" -- \
      "$GODOT_BIN" --headless --audio-driver Dummy --path "$GITHUB_WORKSPACE" \
      --script "res://scripts/tests/$script.gd" 2>&1 | tee "$runner" || return $?
  elif [[ "$mode" == rendered ]]; then
    XDG_DATA_HOME="$state/data" XDG_CONFIG_HOME="$state/config" XDG_CACHE_HOME="$state/cache" \
      LUMO_CAPTURE_DIR="$LUMO_VILLAGE_OUTPUT/captures" \
      "$LUMO_DISCOVERY_PYTHON" tools/run_godot_probe.py \
      --log "$proof" --timeout "$seconds" --required "$marker" -- \
      xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT_BIN" \
      --audio-driver Dummy --path "$GITHUB_WORKSPACE" --rendering-method gl_compatibility \
      --resolution 1280x720 --script "res://scripts/tests/$script.gd" -- --capture \
      2>&1 | tee "$runner" || return $?
  else
    return 1
  fi
  cmp "$proof" "$runner" || return 1
  test "$(grep -Fxc -- "$marker" "$proof")" = 1 || return 1
  if grep -En 'SCRIPT ERROR|Parse Error|ERROR:|Assertion failed|ObjectDB instances leaked|resources still in use at exit|\[ProbeRunner\] (FAIL|timeout)' "$proof"; then
    return 1
  fi
}
{
  check_village 01-economy-headless build_village_economy_regression headless 420 \
    '[VillageEconomy] PASS 339 checks' || exit 1
  # New bounded-workload budgets: 2178 saved houses, five view states, two PNGs.
  # These 180s/300s bounds are not an asserted original Producer timeout.
  check_village 02-scaling-headless build_village_scaling_regression headless 180 \
    '[VillageScaling] PASS 42 checks: full 2178-house model, camera and explorer' || exit 1
  check_village 03-scaling-rendered build_village_scaling_regression rendered 300 \
    '[VillageScaling] PASS 46 checks: full 2178-house model, camera and explorer' || exit 1
} 2>&1 | tee "$LUMO_VILLAGE_OUTPUT/runner.log"
"$LUMO_DISCOVERY_PYTHON" tools/verify_dream_rasters.py "$LUMO_VILLAGE_OUTPUT/source" \
  --snapshot-source "$GITHUB_WORKSPACE" --snapshot-phase after
"$LUMO_DISCOVERY_PYTHON" - <<'PY'
import hashlib, importlib.util, json, os, pathlib, subprocess
root = pathlib.Path(os.environ["LUMO_VILLAGE_OUTPUT"])
project = pathlib.Path(os.environ["GITHUB_WORKSPACE"])
helper = project / "tools/verify_dream_rasters.py"
raw = helper.read_bytes()
if hashlib.sha256(raw).hexdigest() != "f7296a802d15c382dbcc77640373a0f53e30306fcaab3de869549ff1656de89d":
    raise SystemExit("Village evidence reader SHA256 changed")
if hashlib.sha1(b"blob " + str(len(raw)).encode() + bytes([0]) + raw).hexdigest() != "da8eed7d6383fcbc82a03596518a5fcc3b9a00c5":
    raise SystemExit("Village evidence reader Git blob changed")
spec = importlib.util.spec_from_file_location("village_original_reader", helper)
reader = importlib.util.module_from_spec(spec)
spec.loader.exec_module(reader)
before, before_record = reader.original_json(root, "source/source-inventory-before.json")
after, after_record = reader.original_json(root, "source/source-inventory-after.json")
expected = (os.environ["LUMO_EXPECTED_NATIVE_SHA"], os.environ["LUMO_EXPECTED_NATIVE_TREE"])
for value in (before, after):
    reader.require((value["head"], value["tree"]) == expected, "Foreign Village source")
    reader.require(all(row["materialized"] is True for row in value["tracked"]), "Incomplete Village source checkout")
for key in ("head", "tree", "index_sha256", "tracked"):
    reader.require(before[key] == after[key], "Village tracked source/index changed: " + key)
probes = (
    ("01-economy-headless", "build_village_economy_regression", "headless", 420, "[VillageEconomy] PASS 339 checks"),
    ("02-scaling-headless", "build_village_scaling_regression", "headless", 180, "[VillageScaling] PASS 42 checks: full 2178-house model, camera and explorer"),
    ("03-scaling-rendered", "build_village_scaling_regression", "rendered", 300, "[VillageScaling] PASS 46 checks: full 2178-house model, camera and explorer"),
)
originals = []
banner = "Godot Engine v" + reader.ENGINE + " - https://godotengine.org"
for name, script, mode, timeout, marker in probes:
    text, log_record = reader.original_text(root, "logs/" + name + ".log")
    runner, runner_record = reader.original_text(root, "logs/" + name + ".runner.log")
    reader.require(text == runner, "Village original/runner bytes differ: " + name)
    reader.require(text.splitlines().count(banner) == 1, "Village requires one real engine invocation: " + name)
    reader.require(text.splitlines().count(marker) == 1, "Village exact original marker missing/duplicated: " + name)
    reader.require(reader.ERRORS.search(text) is None, "Village original contains a runtime failure: " + name)
    originals.append({"probe": script, "mode": mode, "timeout_seconds": timeout, "required_marker": marker, "log": log_record, "runner": runner_record})
names = ("01-home-region.png", "02-river-boundary.png")
reader.require(sorted(path.name for path in (root / "captures").iterdir()) == sorted(names), "Unexpected or missing Village renderer originals")
images = []
for name in names:
    record, pixels = reader.png(root, "captures/" + name, (1280, 720))
    images.append({**record, "decoded_rgb_sha256": hashlib.sha256(pixels.tobytes()).hexdigest()})
report = {"schema": 1, "status": "PASS", "native_sha": expected[0], "native_tree": expected[1],
          "source_inventories": [before_record, after_record], "probes": originals, "images": images,
          "scope": "Three additional Village probes and two actual renderer PNGs; no complete52/17, Android or device-FPS acceptance"}
destination = root / "village-scaling-acceptance.json"
reader.require(not destination.exists() and not destination.is_symlink(), "Village acceptance output must be fresh")
with destination.open("x", encoding="utf-8") as stream:
    stream.write(json.dumps(report, indent=2) + "\n")
print("[VillageScalingOriginals] PASS 3 exact probes and 2 decoded 1280x720 PNGs")
PY
