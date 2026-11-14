"""Verify only the original PR160 4f34492 artifact bytes and exact source metadata."""
from __future__ import annotations

import argparse
import hashlib
from io import BytesIO
import json
from pathlib import Path, PurePosixPath
import re
import stat
import sys
import zipfile

from PIL import Image

ROOT = Path(__file__).resolve().parent
HEAD = "4f3449253fd59023a2544432a178eb9efcafe4f9"
TREE = "189b7a66c731067559469e2503e3a190b337031d"
RUN = 43466004918
BASELINE = "1d5c5cb45a323228f627ec529e6ff1ddd86f1c57"
NAMES = {
    "preview": "lumo-nextgen-2018-learning-preview",
    "legacy": "lumo-nextgen-2018-legacy-evidence",
    "native": "lumo-nextgen-2018-native-evidence",
}
JOBS = {"preview": "learning-preview", "legacy": "gameplay", "native": "bundle-evidence"}


def require(value: bool, message: str) -> None:
    if not value:
        raise ValueError(message)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("kind", choices=NAMES)
    parser.add_argument("artifact_id", type=int)
    args = parser.parse_args()
    run = json.loads((ROOT / "workflow-run.json").read_text())
    jobs = json.loads((ROOT / "workflow-jobs.json").read_text())
    artifacts = json.loads((ROOT / "workflow-artifacts.json").read_text())
    require(run["id"] == RUN and run["head_sha"] == HEAD, "Wrong original run/source")
    require(run["head_commit"]["tree_id"] == TREE and run["event"] == "pull_request", "Wrong run tree/event")
    matching = [item for item in artifacts["artifacts"] if item["id"] == args.artifact_id]
    require(len(matching) == 1, "Missing or duplicate original artifact ID")
    artifact = matching[0]
    require(artifact["name"] == NAMES[args.kind] and not artifact["expired"], "Wrong artifact name/expiry")
    require(artifact["workflow_run"]["id"] == RUN and artifact["workflow_run"]["head_sha"] == HEAD,
            "Artifact belongs to another run/source")
    finished = [item for item in jobs["jobs"] if item["name"] == JOBS[args.kind]]
    require(len(finished) == 1 and finished[0]["status"] == "completed" and
            finished[0]["conclusion"] == "success", "Producer job has not successfully completed")
    archive = ROOT / f"{args.kind}-{args.artifact_id}.zip"
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    require(artifact["digest"] == "sha256:" + digest, "Original ZIP digest differs")
    unpacked = ROOT / f"{args.kind}-{args.artifact_id}"
    unpacked.mkdir(exist_ok=True)
    sources, trees, dirty, images, logs, counts = {}, {}, {}, [], {}, {}
    additional = {}
    with zipfile.ZipFile(archive) as zipped:
        seen = set()
        for entry in zipped.infolist():
            name = entry.filename
            path = PurePosixPath(name)
            require(name not in seen and not path.is_absolute() and ".." not in path.parts and
                    "\\" not in name and not stat.S_ISLNK(entry.external_attr >> 16), "Unsafe/duplicate ZIP member: " + name)
            seen.add(name)
        require(zipped.testzip() is None, "ZIP CRC failure")
        zipped.extractall(unpacked)
        for name in zipped.namelist():
            if name.endswith("/"):
                continue
            data = zipped.read(name)
            require((unpacked / name).read_bytes() == data, "Extracted original bytes differ: " + name)
            if name.endswith("source-sha.txt"):
                source = data.decode().strip()
                require(source == (BASELINE if "baseline-2017/" in name else HEAD), "Wrong source stamp: " + name)
                sources[name] = source
            if name.endswith("source-tree.txt"):
                tree = data.decode().strip()
                if "baseline-2017/" not in name:
                    require(tree == TREE, "Wrong current tree stamp: " + name)
                trees[name] = tree
            if name.endswith(("source-dirty.txt", "source-dirty-after.txt")):
                dirty[name] = data.decode().strip()
                require(not dirty[name], "Tracked source changed: " + name)
            if name.endswith(".png"):
                with Image.open(BytesIO(data)) as picture:
                    dimensions = list(picture.size)
                    require(picture.format == "PNG", "Non-PNG image: " + name)
                    picture.verify()
                images.append({"path": name, "dimensions": dimensions, "bytes": len(data),
                               "sha256": hashlib.sha256(data).hexdigest(), "baseline": "baseline-2017/" in name})
                if "/captures/" in name:
                    group = name.split("/captures/", 1)[0] + "/captures/" + name.split("/captures/", 1)[1].split("/", 1)[0]
                    counts[group] = counts.get(group, 0) + 1
            if name.endswith(".log"):
                text = data.decode(errors="replace")
                errors = [line for line in text.splitlines() if re.search(r"SCRIPT ERROR|Parse Error|ERROR:|Leaked instance|ObjectDB instances leaked", line)]
                logs[name] = {"sha256": hashlib.sha256(data).hexdigest(), "error_lines": errors}
                require(not errors, "Original log contains an engine/script error: " + name + ": " + str(errors))
        require(bool(sources) and bool(images), "Missing actual source stamps/images")
        if args.kind == "native":
            sys.dont_write_bytecode = True
            host_scripts = ROOT / "validator-9e285e"
            validator_source = json.loads((ROOT / "validator-9e285e-source-manifest.json").read_text())
            require(validator_source["source_revision"] == "9e285e17a8cbd54f73cf5a14ccdad07c0ad29199",
                    "Wrong frozen host verifier revision")
            for module, original in validator_source["modules"].items():
                require(hashlib.sha256((host_scripts / (module + ".py")).read_bytes()).hexdigest() == original["sha256"],
                        "Frozen verifier dependency changed: " + module)
            sys.path.insert(0, str(host_scripts))
            import verify_studio_delivery as verifier
            verifier.verify_native_acceptance(HEAD, artifact, run, jobs, native_profile="nextgen-2019")
            verifier.verify_archive_sources(zipped, HEAD, native_profile="nextgen-2019")
            additional = verifier.verify_nextgen_archive(zipped, run)
            require(additional["native_probe_count"] == 37 and additional["native_studio_raster_count"] == 24,
                    "Missing complete core gates/Studio roster")
            require(additional["native_touch_probe_count"] == 6 and additional["native_touch_raster_count"] == 32,
                    "Missing complete touch modes/images")
            additional["validator_sha256"] = hashlib.sha256((host_scripts / "verify_studio_delivery.py").read_bytes()).hexdigest()
            additional["validator_revision"] = validator_source["source_revision"]
            additional["validator_blob"] = validator_source["modules"]["verify_studio_delivery"]["blob"]
    report = {"status": "ORIGINAL_ARTIFACT_VERIFIED", "scope": args.kind, "head_sha": HEAD,
              "tree": TREE, "run_id": RUN, "artifact_id": args.artifact_id, "artifact_name": artifact["name"],
              "zip_sha256": digest, "zip_bytes": archive.stat().st_size, "sources": sources, "trees": trees,
              "tracked_dirty": dirty, "images": images, "capture_counts": counts, "logs": logs,
              "no_visual_or_android_approval_claim": True, **additional}
    output = ROOT / f"{args.kind}-artifact-verification.json"
    output.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"report": str(output), "artifact_id": args.artifact_id, "zip_sha256": digest,
                      "images": len(images), "baseline_images": sum(item["baseline"] for item in images),
                      "capture_counts": counts, **additional}, indent=2))


if __name__ == "__main__":
    main()
