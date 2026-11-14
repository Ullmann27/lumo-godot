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
