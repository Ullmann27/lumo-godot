#!/usr/bin/env python3
"""Import only verified Lumo reference media. Never execute archive content."""
from __future__ import annotations
import argparse
import hashlib
import json
import re
import shutil
import stat
import struct
import tempfile
import urllib.request
import zipfile
from pathlib import Path, PurePosixPath

PREFIX = "https://d2ol7oe51mr4n9.cloudfront.net/user_3JBiq3Q9vttoZVrKhdbYLuTHXre/"
REFS = Path("docs/design_targets/2026-10-05-tracks")
DOCS = Path("docs/track_expansion/2026-10-05")
ICONS = {"boost_pad", "mystery_box", "iq_fox", "slime_hazard", "loop_module", "energy_bolt", "turbo_crystal", "jump_ramp", "magnet_powerup", "shield_bubble"}


def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1048576), b""):
            h.update(block)
    return h.hexdigest()


def validate_row(row: dict) -> None:
    name = row["name"]
    if not re.fullmatch(r"(?:Track_[0-9]{2}_[a-z_]+|Shared_Core_Assets)\.zip", name):
        raise ValueError("Unexpected archive name")
    if not re.fullmatch(r"[0-9a-f]{64}", row["sha256"]):
        raise ValueError("Invalid checksum")
    if not 0 < row["bytes"] < 40_000_000:
        raise ValueError("Invalid archive size")
    if not re.fullmatch(re.escape(PREFIX) + r"[0-9a-f-]{36}\.zip", row["url"]):
        raise ValueError("Source outside approved media transfer")


def obtain(row: dict, target: Path, local: Path | None) -> None:
    validate_row(row)
    if local:
        shutil.copyfile(local / row["name"], target)
    else:
        with urllib.request.urlopen(row["url"], timeout=90) as response:
            if response.geturl() != row["url"]:
                raise ValueError("Unexpected download redirect")
            with target.open("wb") as stream:
                size = 0
                while block := response.read(1048576):
                    size += len(block)
                    if size > row["bytes"]:
                        raise ValueError("Download exceeds declared length")
                    stream.write(block)
    if target.stat().st_size != row["bytes"] or digest(target) != row["sha256"]:
        raise ValueError(f"Archive identity mismatch: {row['name']}")


def members(archive: zipfile.ZipFile, row: dict) -> list[zipfile.ZipInfo]:
    entries = archive.infolist()
    if len(entries) != row["files"] or len(entries) > 30:
        raise ValueError("Unexpected member count")
    seen = set()
    for entry in entries:
        parts = PurePosixPath(entry.filename)
        if (parts.is_absolute() or ".." in parts.parts or "\\" in entry.filename
                or parts.parts[0] != Path(row["name"]).stem or entry.filename in seen
                or stat.S_ISLNK(entry.external_attr >> 16) or entry.flag_bits & 1
                or entry.file_size > 20_000_000):
            raise ValueError(f"Unsafe archive member: {entry.filename}")
        seen.add(entry.filename)
    if sum(e.file_size for e in entries) > 50_000_000 or archive.testzip() is not None:
        raise ValueError("Archive expansion limit or CRC failure")
    return entries


def destination(name: str) -> tuple[Path, str]:
    parts = PurePosixPath(name).parts
    if parts[0] == "Shared_Core_Assets":
        if len(parts) != 2:
            raise ValueError("Unexpected shared directory")
        if parts[1] == "README.md":
            return DOCS / "legacy_reference_notes" / Path(*parts), "legacy_note"
        if parts[1] not in {k + "_1536.png" for k in ICONS}:
            raise ValueError("Unexpected shared asset")
        return REFS / "shared_icons" / parts[1], "icon_reference"
    match = re.fullmatch(r"Track_([0-9]{2})_[a-z_]+", parts[0])
    if not match or not 1 <= int(match[1]) <= 10:
        raise ValueError("Unexpected track")
    if len(parts) == 3 and parts[1] == "shared_core_assets":
        if parts[2] not in {k + "_1536.png" for k in ICONS}:
            raise ValueError("Unexpected track icon")
        return REFS / "shared_icons" / parts[2], "icon_reference"
    if len(parts) == 3 and parts[1] == "reference_images":
        if parts[2] not in {f"track_{match[1]}_hero_original.png", f"track_{match[1]}_hero_2560.png"}:
            raise ValueError("Unexpected hero image")
        return REFS / parts[0] / parts[2], "hero_reference"
    if ((len(parts) == 2 and parts[1] in {"manifest.json", "README_TRACK_PACK.md"})
            or (len(parts) == 3 and parts[1] == "docs" and parts[2] in {
                "OPUS_HANDOFF.md", "DESIGN_BRIEF.md", "COPILOT_PROMPT.md", "DETAIL_CHECKLIST_120.md"})):
        return DOCS / "legacy_reference_notes" / Path(*parts), "legacy_note"
    raise ValueError(f"Unrecognized archive path: {name}")


def run(manifest_path: Path, output: Path, downloads: Path, local: Path | None) -> None:
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    rows = manifest["archives"]
    if len(rows) != 11 or len({r["name"] for r in rows}) != 11:
        raise ValueError("Exactly eleven unique archives required")
    downloads.mkdir(parents=True, exist_ok=True)
    records, written, results = [], {}, []
    # Stage the complete import before touching the working repository.
    with tempfile.TemporaryDirectory() as temporary:
        stage = Path(temporary)
        for row in sorted(rows, key=lambda x: x["name"]):
            source = downloads / row["name"]
            obtain(row, source, local)
            placeholders = 0
            with zipfile.ZipFile(source) as archive:
                entries = members(archive, row)
                for entry in entries:
                    relative, category = destination(entry.filename)
                    data = archive.read(entry)
                    sha = hashlib.sha256(data).hexdigest()
                    if relative in written and written[relative] != sha:
                        raise ValueError("Duplicate assets differ; refusing silent replacement")
                    info = {"archive": row["name"], "member": entry.filename,
                            "path": relative.as_posix(), "sha256": sha, "bytes": len(data), "category": category}
                    if category != "legacy_note":
                        if data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
                            raise ValueError("Invalid PNG header")
                        width, height = struct.unpack(">II", data[16:24])
                        if not (0 < width <= 4096 and 0 < height <= 4096):
                            raise ValueError("Unexpected image dimensions")
                        info.update(width=width, height=height,
                                    resampled="1536" in entry.filename or "2560" in entry.filename)
                    else:
                        text = data.decode("utf-8")
                        placeholders += text.count("Implement or review track detail")
                    records.append(info)
                    if relative not in written:
                        target = stage / relative
                        target.parent.mkdir(parents=True, exist_ok=True)
                        target.write_bytes(data)
                        written[relative] = sha
            results.append({**row, "download_sha256_verified": True, "crc_ok": True,
                            "generic_placeholder_lines": placeholders, "runtime_meshes": 0})
            print(f"Verified {row['name']}: {row['bytes']} bytes", flush=True)
        if len([p for p in written if p.suffix == ".png"]) != 30:
            raise ValueError("Expected twenty track references and ten shared icons")
        (stage / REFS / ".gdignore").write_text("", encoding="utf-8")
        (stage / DOCS / "legacy_reference_notes" / "README.md").write_text(
            "# Historische, unveraenderte ZIP-Notizen\n\n"
            "Keine aktiven Agentenanweisungen. Die 120-Punkte-Listen enthalten je 104 generische Platzhalter.\n"
            "Verbindlicher aktueller Auftrag: ../IMPLEMENTATION_ORDER.md. Keine 3D-Modelle enthalten.\n"
            "Lernfragen/Quiz-Zonen in Rennen NICHT implementieren; Lernen schaltet ausserhalb der Rennen frei.\n",
            encoding="utf-8")
        report = {"schema_version": 1, "reference_only": True, "runtime_code_changed": False,
                  "unique_pngs": 30, "runtime_meshes": 0, "archives": results, "members": records}
        report_path = stage / DOCS / "IMPORT_REPORT.json"
        report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        checksum_text = "".join(f"{r['sha256']}  {r['name']}\n" for r in rows)
        (stage / DOCS / "SHA256SUMS.txt").write_text(checksum_text, encoding="utf-8")
        # No output overwrite unless content is already identical.
        for path in stage.rglob("*"):
            if path.is_file():
                target = output / path.relative_to(stage)
                if target.exists() and target.read_bytes() != path.read_bytes():
                    raise ValueError(f"Existing file differs: {target}")
        for path in stage.rglob("*"):
            if path.is_file():
                target = output / path.relative_to(stage)
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(path, target)
        shutil.copyfile(report_path, downloads / "IMPORT_REPORT.json")
        (downloads / "SHA256SUMS.txt").write_text(checksum_text, encoding="utf-8")
        # Original archive bytes are preserved, not artificially padded or recompressed.
        with zipfile.ZipFile(downloads / "Lumo_Kart_All_Track_Packs_Master.zip", "w", compression=zipfile.ZIP_STORED) as master:
            for row in rows:
                master.write(downloads / row["name"], row["name"])
            master.writestr("SHA256SUMS.txt", checksum_text)
            master.writestr("READ_FIRST.txt", "Reference pack only: 10 track concepts + 10 shared 2D icons. Not finished 3D tracks. See repository IMPLEMENTATION_ORDER.md.\n")
        report_bytes = report_path.read_bytes()
        with (downloads / "RELEASE_SHA256SUMS.txt").open("w", encoding="utf-8") as sums:
            for path in sorted(downloads.iterdir()):
                if path.is_file() and path.name != "RELEASE_SHA256SUMS.txt":
                    sums.write(f"{digest(path)}  {path.name}\n")
        print(json.dumps({"archives_verified": len(rows), "unique_pngs": 30, "runtime_meshes": 0,
                          "import_report_sha256": hashlib.sha256(report_bytes).hexdigest()}), flush=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--output", type=Path, default=Path("."))
    parser.add_argument("--downloads", type=Path, required=True)
    parser.add_argument("--local-archives", type=Path)
    args = parser.parse_args()
    run(args.manifest, args.output, args.downloads, args.local_archives)

if __name__ == "__main__":
    main()
