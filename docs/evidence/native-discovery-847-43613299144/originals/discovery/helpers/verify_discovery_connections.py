#!/usr/bin/env python3
"""Read-only verification of the separate Discovery 10/38/2 original evidence."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import stat
import sys
import types

ENGINE = "4.6.3.stable.official.7d41c59c4"
HELPERS = {
    "verify_discovery_rasters.py": (
        "55591b4478d2074135ea4950fb00200d68a3f9bede286b39642d7fc17aa586da",
        "219e691fc8aa119cc80221b3db6c77e63caf8bfe"),
    "verify_dream_rasters.py": (
        "f7296a802d15c382dbcc77640373a0f53e30306fcaab3de869549ff1656de89d",
        "da8eed7d6383fcbc82a03596518a5fcc3b9a00c5"),
    "run_godot_probe.py": (
        "e1836029a196e4dcd4a4f47fd8c2010c5b460ec5bf4c0578e90e75d3a5d2ea13",
        "c23859ece2d62101d000d7a89556fda5d3fe4105"),
}
PROBES = (
    ("learning_world_regression", "headless", 420, "[LearningWorld] PASS checks=5347"),
    ("learning_sharing_regression", "headless", 420, "[LearningSharing] PASS checks=1811"),
    ("learning_studio_regression", "headless", 420,
     "[LearningStudio] PASS checks=183; runtime asset, materials, reduced motion and preserved learning"),
    ("game_hub_magic_regression", "headless", 150,
     "[LumoHub] PASS 8 visible native game entrances, active village route, preserved child settings and 3D reduced-motion portal"),
    ("village_host_launch_regression", "headless", 150,
     "[VillageHost] PASS Flutter village request, native boot scene and child context"),
    ("learning_wonder_details_regression", "headless", 150,
     "[LearningWonder] checks=100 failures=0 renderer=headless invalid_scene_checked=false"),
    ("learning_wonder_details_regression", "rendered", 420,
     "[LearningWonder] checks=108 failures=0 renderer=X11 invalid_scene_checked=true"),
    ("game_hub_magic_capture", "rendered", 180,
     "[LumoHubCapture] PASS 2 original current-source rendered PNGs"),
    ("learning_world_capture", "rendered", 900, "[LearningCapture] PASS captures=25"),
    ("learning_wonder_details_capture", "rendered", 420,
     "[WonderCapture] checks=136 failures=0 captures=11"),
)
REPORTS = ("captures/hub/hub-original-identity.json", "captures/wonder/captures.json")
ERRORS = re.compile(
    r"SCRIPT ERROR|Parse Error|ERROR:|Assertion failed|ObjectDB instances leaked|"
    r"resources still in use at exit|\[ProbeRunner\] (?:FAIL|timeout)|"
    r"Traceback \(most recent call last\)|Segmentation fault|core dumped", re.IGNORECASE)
MANIFEST = "discovery-acceptance.json"
PASS = "[DiscoveryOriginals] PASS 10 exact probes, 38 decoded PNGs and 2 original reports"
SHA1 = re.compile(r"[0-9a-f]{40}")
SHA256 = re.compile(r"[0-9a-f]{64}")


def require(condition, message):
    if not condition:
        raise ValueError(str(message))


def object_id(kind, data):
    return hashlib.sha1(kind.encode() + b" " + str(len(data)).encode() + b"\0" + data).hexdigest()


def identity(data):
    return {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest(),
            "git_blob": object_id("blob", data)}


def relative_name(value):
    require(type(value) is str and value and "\\" not in value and
            all(ord(c) >= 32 and ord(c) != 127 for c in value), "Invalid original path")
    name = PurePosixPath(value)
    require(not name.is_absolute() and ".." not in name.parts and
            str(name) == value and value != ".", "Unsafe original path: " + value)
    return name


def absolute_name(value):
    require(type(value) is str and value.startswith("/") and
            all(ord(c) >= 32 and ord(c) != 127 for c in value) and
            ".." not in PurePosixPath(value).parts and str(PurePosixPath(value)) == value,
            "Invalid absolute original path")
    return value


def no_symlink_path(path):
    for item in (path, *path.parents):
        require(not item.is_symlink(), "Symlink original path: " + str(item))


def read(root, relative):
    name = relative_name(relative)
    path = root.joinpath(*name.parts)
    no_symlink_path(path)
    require(path.is_file(), "Missing original file: " + relative)
    size = path.stat().st_size
    require(0 <= size <= 67108864, "Original file exceeds the bounded reader: " + relative)
    data = path.read_bytes()
    require(len(data) == size, "Original changed while reading: " + relative)
    return data


def record(root, relative):
    return {"path": relative, **identity(read(root, relative))}


def parse_json(data):
    def pairs(items):
        result = {}
        for key, value in items:
            require(key not in result, "Duplicate JSON key: " + key)
            result[key] = value
        return result

    def constant(value):
        raise ValueError("Nonfinite JSON value: " + value)

    result = json.loads(data.decode("utf-8"), object_pairs_hook=pairs, parse_constant=constant)
    require(type(result) is dict, "Expected a JSON object")
    return result


def json_original(root, relative):
    return parse_json(read(root, relative))


def bound_module(root, name):
    """Import only the exact published helper; never trust an artifact's filename."""
    require(name in HELPERS, "Unknown helper")
    data = read(root, "helpers/" + name)
    actual = identity(data)
    wanted_sha, wanted_blob = HELPERS[name]
    require(actual["sha256"] == wanted_sha and actual["git_blob"] == wanted_blob,
            "Published helper identity mismatch before import: " + name)
    module = types.ModuleType("_discovery_bound_" + name.removesuffix(".py"))
    module.__file__ = str(root / "helpers" / name)
    exec(compile(data, module.__file__, "exec"), module.__dict__)
    return module


def tree_entries(data):
    entries = []
    for row in data.split(b"\0"):
        if not row:
            continue
        metadata, raw_name = row.split(b"\t", 1)
        mode, kind, blob = metadata.decode("ascii").split()
        name = raw_name.decode("utf-8")
        relative_name(name)
        require(mode in ("100644", "100755", "120000") and kind == "blob" and
                SHA1.fullmatch(blob), "Unsupported Git tree entry")
        entries.append({"path": name, "mode": mode, "git_blob": blob})
    require(entries and len({e["path"] for e in entries}) == len(entries),
            "Missing or duplicate complete Git tree entries")
    return sorted(entries, key=lambda item: item["path"])


def tree_id(entries):
    """Reconstruct Git's directory objects, so an omitted source cannot pass."""
    root = {}
    for entry in entries:
        parts = relative_name(entry["path"]).parts
        node = root
        for part in parts[:-1]:
            node = node.setdefault(part, {})
            require(type(node) is dict, "Git tree file/directory collision")
        require(parts[-1] not in node, "Duplicate Git tree path")
        require(entry["mode"] in ("100644", "100755", "120000") and
                SHA1.fullmatch(entry["git_blob"]), "Invalid Git tree object")
        node[parts[-1]] = (entry["mode"], entry["git_blob"])

    def digest(node):
        data = bytearray()
        for name in sorted(node, key=lambda n: n.encode("utf-8") +
                           (b"/" if type(node[n]) is dict else b"")):
            value = node[name]
            mode, blob = ("40000", digest(value)) if type(value) is dict else value
            data.extend(mode.encode() + b" " + name.encode("utf-8") + b"\0" + bytes.fromhex(blob))
        return object_id("tree", bytes(data))
    return digest(root)


def check_sources(root, expected_sha, expected_tree):
    require(SHA1.fullmatch(expected_sha) and SHA1.fullmatch(expected_tree),
            "Exact expected Native HEAD and tree are required")
    commit = read(root, "source-commit.raw")
    require(object_id("commit", commit) == expected_sha and
            commit.splitlines()[0] == ("tree " + expected_tree).encode(),
            "Original Git commit does not bind the expected Native tree")
    inventories = []
    files = ["source-commit.raw"]
    for phase, suffix in (("before", ""), ("after", "-after")):
        for kind, wanted in (("sha", expected_sha), ("tree", expected_tree)):
            name = "source-" + kind + suffix + ".txt"
            require(read(root, name) == (wanted + "\n").encode(), "Foreign Native stamp: " + name)
            files.append(name)
        dirty = "source-dirty" + suffix + ".txt"
        require(read(root, dirty) == b"", "Tracked Native source/index is dirty")
        files.append(dirty)
        listing_name = "source-tree-" + phase + ".bin"
        entries = tree_entries(read(root, listing_name))
        require(tree_id(entries) == expected_tree, "Incomplete or changed original Git tree")
        inventory_name = "source-inventory-" + phase + ".json"
        inventory = json_original(root, inventory_name)
        require(type(inventory.get("schema")) is int and inventory["schema"] == 1 and inventory.get("head") == expected_sha and
                inventory.get("tree") == expected_tree, "Source snapshot identity mismatch")
        tracked = inventory.get("tracked")
        require(type(tracked) is list and len(tracked) == len(entries),
                "All tracked sources must be inventoried")
        bound = []
        for entry in tracked:
            require(type(entry) is dict and type(entry.get("path")) is str, "Malformed tracked source")
            relative_name(entry["path"])
            require(type(entry.get("skip_worktree")) is bool and entry.get("materialized") is True,
                    "This full-checkout CI requires every tracked source byte")
            require(type(entry.get("bytes")) is int and entry["bytes"] >= 0 and
                    SHA256.fullmatch(entry.get("sha256", "")) and
                    entry.get("actual_blob") == entry.get("git_blob"),
                    "Tracked bytes do not match the original index")
            bound.append({key: entry.get(key) for key in ("path", "mode", "git_blob")})
        require(bound == entries, "Git index/source inventory differs from the complete HEAD tree")
        index_name = "source-index-" + phase + ".bin"
        require(hashlib.sha256(read(root, index_name)).hexdigest() == inventory.get("index_sha256"),
                "Original Git index hash mismatch")
        generated = inventory.get("untracked_import_inventory")
        require(type(generated) is list, "Missing generated-import inventory")
        names = set()
        tracked_names = {entry["path"] for entry in tracked}
        for item in generated:
            require(type(item) is dict, "Invalid generated/import entry")
            name = str(relative_name(item.get("path")))
            require(name not in names and name not in tracked_names, "Duplicate or tracked import path")
            names.add(name)
            require(type(item.get("bytes")) is int and item["bytes"] >= 0 and
                    SHA256.fullmatch(item.get("sha256", "")) and SHA1.fullmatch(item.get("actual_blob", "")) and
                    item.get("mode") in ("100644", "100755", "120000"), "Invalid import byte identity")
            category = item.get("category")
            require(category in ("generated_uid", "generated_import_metadata", "other_untracked"),
                    "Unknown import classification")
            if category != "other_untracked":
                suffix2 = ".uid" if category == "generated_uid" else ".import"
                require(item.get("tracked_owner") in tracked_names and
                        name == item["tracked_owner"] + suffix2, "Unbound generated import owner")
        inventories.append(inventory)
        files.extend((listing_name, inventory_name, index_name))
    require(inventories[0]["tracked"] == inventories[1]["tracked"] and
            read(root, "source-index-before.bin") == read(root, "source-index-after.bin") and
            read(root, "source-tree-before.bin") == read(root, "source-tree-after.bin"),
            "Tracked source/index changed during Discovery collection")
    return inventories[0], files


def log_names(number, probe, mode):
    stem = f"logs/{number:02d}-{probe}-{mode}"
    return stem + ".log", stem + ".runner.log"


def invocation_plan(context):
    project, output = context["project"], context["output"]
    plan = []
    for number, (probe, mode, seconds, marker) in enumerate(PROBES, 1):
        log, runner_log = log_names(number, probe, mode)
        engine = [context["godot"], "--headless"] if mode == "headless" else (
            context["renderer_prefix"] + [context["godot"], "--rendering-method", "gl_compatibility"])
        engine += ["--audio-driver", "Dummy", "--path", project, "--script", "res://scripts/tests/" + probe + ".gd"]
        env = {"XDG_" + kind + "_HOME": f"{output}/state/{number:02d}/{folder}"
               for kind, folder in (("DATA", "data"), ("CONFIG", "config"), ("CACHE", "cache"))}
        env.update(GODOT_SILENCE_ROOT_WARNING="1", LP_NUM_THREADS="2")
        if mode == "rendered" and not context["renderer_prefix"]:
            env["DISPLAY"] = context["display"]
        if probe == "game_hub_magic_capture":
            env["LUMO_HUB_CAPTURE_DIR"] = output + "/captures/hub"
        if probe in ("learning_world_capture", "learning_wonder_details_capture"):
            group = "learning" if probe == "learning_world_capture" else "wonder"
            engine += ["--", "--output=" + output + "/captures/" + group]
        command = [context["python"], project + "/tools/run_godot_probe.py",
                   "--log", output + "/" + log, "--timeout", str(seconds), "--required", marker, "--", *engine]
        plan.append({"ordinal": number, "probe": probe, "mode": mode, "timeout_seconds": seconds,
                     "marker": marker, "log": log, "runner_log": runner_log,
                     "command": command, "engine_command": engine, "environment": env})
    return plan


def check_runs(root, expected_sha, expected_tree):
    context = json_original(root, "collection-context.json")
    require(type(context.get("schema")) is int and context["schema"] == 1 and context.get("native_source") == expected_sha and
            context.get("native_tree") == expected_tree and context.get("output_was_absent") is True,
            "Foreign or reused collection context")
    for key in ("project", "output", "godot", "python"):
        absolute_name(context.get(key))
    require(context["project"] != context["output"] and
            not context["output"].startswith(context["project"] + "/"), "Output must be outside Native sources")
    prefix = context.get("renderer_prefix")
    require(prefix == [] or (type(prefix) is list and len(prefix) == 4 and
                            prefix[1:] == ["-a", "-s", "-screen 0 2560x2560x24"] and
                            PurePosixPath(absolute_name(prefix[0])).name == "xvfb-run"),
            "Unknown rendered execution prefix")
    require(type(context.get("display")) is str and
            ((prefix == [] and re.fullmatch(r":[0-9]+(?:\.[0-9]+)?", context["display"])) or
             (prefix != [] and context["display"] == "")), "Missing original render display")
    require(read(root, "engine.txt") == (ENGINE + "\n").encode(), "Wrong Godot version")
    binary = json_original(root, "engine-binary.json")
    require(binary.get("path") == context["godot"] and type(binary.get("bytes")) is int and
            binary["bytes"] > 0 and SHA256.fullmatch(binary.get("sha256", "")),
            "Missing original engine binary identity")
    result = json_original(root, "invocations.json")
    require(type(result.get("schema")) is int and result["schema"] == 1 and result.get("completed") is True,
            "Incomplete Discovery invocation recording")
    actual = result.get("calls")
    plan = invocation_plan(context)
    require(type(actual) is list and len(actual) == 10, "Ten engine calls required exactly once")
    expected_tsv = "probe\tmode\tresult\n" + "".join(f"{p}\t{m}\tPASS\n" for p, m, _, _ in PROBES)
    require(read(root, "results.tsv").decode() == expected_tsv, "Wrong probe order or missing result")
    logs, previous = [], context.get("started_monotonic_ns")
    require(type(previous) is int and previous > 0, "Missing collection start time")
    for want, got in zip(plan, actual):
        require(type(got) is dict and type(got.get("ordinal")) is int and
                type(got.get("timeout_seconds")) is int and {key: got.get(key) for key in want} == want,
                "Engine argv, mode, order, output or deadline changed")
        start, finish = got.get("started_monotonic_ns"), got.get("finished_monotonic_ns")
        require(type(start) is int and type(finish) is int and previous <= start < finish,
                "Incomplete, overlapping or out-of-order engine calls")
        require(type(got.get("returncode")) is int and got["returncode"] == 0 and
                got.get("outer_timeout") is False and
                finish - start <= (want["timeout_seconds"] + 10) * 1_000_000_000,
                "Original engine failed, timed out or exceeded its deadline/grace")
        previous = finish
        data, runner = read(root, want["log"]), read(root, want["runner_log"])
        require(data == runner, "Original engine and successful runner transcript differ")
        text = data.decode("utf-8")
        lines = text.splitlines()
        banners = [line for line in lines if line.startswith("Godot Engine v")]
        require(len(banners) == 1 and banners[0].startswith("Godot Engine v" + ENGINE + " - "),
                "Exactly one real invocation of the expected engine required")
        require(lines.count(want["marker"]) == 1, "Missing, partial or duplicate probe marker")
        require(all(other == want["marker"] or other not in lines for _, _, _, other in PROBES),
                "Another probe's result appears in this engine transcript")
        require(ERRORS.search(text) is None, "Original probe contains an error, timeout or resource leak")
        logs.append({**record(root, want["log"]), "runner": record(root, want["runner_log"]),
                     "probe": want["probe"], "mode": want["mode"],
                     "timeout_seconds": want["timeout_seconds"],
                     "elapsed_seconds": (finish - start) / 1e9, "marker": want["marker"]})
    require(type(result.get("finished_monotonic_ns")) is int and result["finished_monotonic_ns"] >= previous,
            "Missing final collection boundary")
    expected_logs = {value for row in plan for value in (row["log"], row["runner_log"])}
    require(file_names(root / "logs", root) == expected_logs, "Missing or unexpected probe transcript")
    return context, logs


def file_names(folder, root):
    require(folder.is_dir(), "Missing original directory: " + str(folder))
    no_symlink_path(folder)
    found = set()
    for directory, names, files in os.walk(folder, followlinks=False):
        for name in names + files:
            path = Path(directory) / name
            require(not path.is_symlink(), "Symlink inside original evidence")
            require(path.is_dir() or stat.S_ISREG(path.stat().st_mode), "Nonregular original evidence")
        for name in files:
            found.add((Path(directory) / name).relative_to(root).as_posix())
    return found


def verify(root: Path, *, expected_native_sha: str, expected_native_tree: str, write: bool = False) -> dict:
    """Recompute from originals only. This verifier never writes any output."""
    require(write is False, "Discovery replay is strictly read-only")
    root = Path(root).absolute()
    no_symlink_path(root)
    require(root.is_dir(), "Original Discovery directory required")
    inventory, source_files = check_sources(root, expected_native_sha, expected_native_tree)
    context, logs = check_runs(root, expected_native_sha, expected_native_tree)
    tracked = {entry["path"]: entry for entry in inventory["tracked"]}
    helpers = []
    for name, (sha, blob) in HELPERS.items():
        original = record(root, "helpers/" + name)
        require(original["sha256"] == sha and original["git_blob"] == blob and
                tracked.get("tools/" + name, {}).get("git_blob") == blob,
                "Published helper must also belong to the exact Native source")
        helpers.append(original)
    for name in ("collect_discovery_connections.py", "verify_discovery_connections.py"):
        original = record(root, "helpers/" + name)
        require(tracked.get("tools/" + name, {}).get("git_blob") == original["git_blob"],
                "Collector/replay source not bound to Native HEAD")
        helpers.append(original)
    replay_bytes = Path(__file__).read_bytes()
    require(identity(replay_bytes)["git_blob"] == tracked.get("tools/verify_discovery_connections.py", {}).get("git_blob"),
            "Replay implementation differs from the original Native verifier")
    reader = bound_module(root, "verify_discovery_rasters.py")
    dream = bound_module(root, "verify_dream_rasters.py")
    wanted = {"captures/" + name for name in reader.raster_roster()} | set(REPORTS)
    require(file_names(root / "captures", root) == wanted, "Missing or unexpected original capture/report")
    files = sorted(set(source_files) | wanted | {h["path"] for h in helpers} |
                   {p for log in logs for p in (log["path"], log["runner"]["path"])} |
                   {"collection-context.json", "engine.txt", "engine-binary.json", "invocations.json", "results.tsv"})
    before = [record(root, name) for name in files]
    decoded = []
    for relative, dimensions in reader.raster_roster().items():
        rec, image = dream.png(root, "captures/" + relative, dimensions)
        image.close()
        decoded.append({**record(root, rec["path"]), "width": dimensions[0], "height": dimensions[1]})
    producer = reader.verify(root)
    require([(r["path"], r["width"], r["height"], r["sha256"]) for r in producer] ==
            [(r["path"], r["width"], r["height"], r["sha256"]) for r in decoded],
            "Independent full decoding disagrees with the original Producer reader")
    reports = [record(root, name) for name in REPORTS]
    require(before == [record(root, name) for name in files],
            "Original bytes changed during read-only verification")
    result = {"schema": 1, "contract": "discovery-originals-10-38-2",
              "native_source": expected_native_sha, "native_tree": expected_native_tree,
              "probe_count": 10, "png_count": 38, "report_count": 2,
              "source_scope": "Complete tracked HEAD tree/index/bytes unchanged; generated import files separately inventoried",
              "probes": logs, "original_pngs": decoded, "original_reports": reports,
              "bound_helpers": helpers, "originals": before,
              "physical_android_fps_measured": False, "complete_native52_acceptance": False,
              "scope": "Separate source-bound Discovery renderer evidence; no Android, device FPS or combined Host acceptance"}
    if (root / MANIFEST).exists() or (root / MANIFEST).is_symlink():
        require(json_original(root, MANIFEST) == result, "Stored acceptance differs from fresh original replay")
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", type=Path)
    parser.add_argument("--expected-native-sha", required=True)
    parser.add_argument("--expected-native-tree", required=True)
    args = parser.parse_args()
    read(args.root, MANIFEST)
    result = verify(args.root, expected_native_sha=args.expected_native_sha,
                    expected_native_tree=args.expected_native_tree, write=False)
    print(json.dumps(result, indent=2))
    print(PASS)


if __name__ == "__main__":
    main()
