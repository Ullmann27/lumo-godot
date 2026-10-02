#!/usr/bin/env python3
"""Prepare Lumo APKs without changing Android's required ZIP storage formats.

Run prepare, then zipalign and apksigner, then verify the final signed APK.
Signature authenticity is checked separately by apksigner.
"""

import argparse
import copy
from pathlib import Path
import struct
import sys
import tempfile
import zipfile


ABIS = ("arm64-v8a", "armeabi-v7a", "x86", "x86_64")
REQUIRED = (
    "AndroidManifest.xml",
    "classes.dex",
    "resources.arsc",
    "assets/_cl_/lumo3d.pck",
)


def _native_abi(name: str) -> str | None:
    parts = name.split("/")
    return parts[1] if len(parts) >= 3 and parts[0] == "lib" else None


def _jar_signature(name: str) -> bool:
    parts = name.upper().split("/")
    return (
        len(parts) == 2
        and parts[0] == "META-INF"
        and (
            parts[1] == "MANIFEST.MF"
            or parts[1].endswith((".SF", ".RSA", ".DSA", ".EC"))
        )
    )


def _check_archive(archive: zipfile.ZipFile, abi: str, allow_other_abis: bool) -> None:
    entries = archive.infolist()
    names = [entry.filename for entry in entries]
    if len(names) != len(set(names)):
        raise ValueError("APK contains duplicate ZIP paths")
    for name in REQUIRED:
        if name not in names or archive.getinfo(name).is_dir():
            raise ValueError(f"APK is missing required file: {name}")
    native = [entry for entry in entries if entry.filename.endswith(".so")]
    if not any(_native_abi(entry.filename) == abi for entry in native):
        raise ValueError(f"APK has no native library for {abi}")
    if not allow_other_abis:
        for entry in entries:
            entry_abi = _native_abi(entry.filename)
            if entry_abi is not None and entry_abi != abi:
                raise ValueError(f"APK contains unwanted native ABI: {entry_abi}")
    damaged = archive.testzip()
    if damaged is not None:
        raise ValueError(f"APK ZIP CRC failed: {damaged}")


def prepare_apk(source: Path, output: Path, abi: str = "arm64-v8a") -> None:
    source, output = Path(source), Path(output)
    if source.resolve() == output.resolve() or (
        output.exists() and source.samefile(output)
    ):
        raise ValueError("Input and output APK must be different files")
    with zipfile.ZipFile(source) as original:
        _check_archive(original, abi, allow_other_abis=True)
        output.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.NamedTemporaryFile(dir=output.parent, delete=False) as temporary:
            temporary_path = Path(temporary.name)
        try:
            with zipfile.ZipFile(temporary_path, "w") as prepared:
                prepared.comment = original.comment
                for entry in original.infolist():
                    entry_abi = _native_abi(entry.filename)
                    if entry_abi is not None and entry_abi != abi:
                        continue
                    if _jar_signature(entry.filename):
                        continue
                    retained = copy.copy(entry)
                    if entry.filename == "resources.arsc":
                        retained.compress_type = zipfile.ZIP_STORED
                    prepared.writestr(retained, original.read(entry))
            temporary_path.replace(output)
        finally:
            temporary_path.unlink(missing_ok=True)


def _data_offset(stream, entry: zipfile.ZipInfo) -> int:
    stream.seek(entry.header_offset)
    header = stream.read(30)
    if len(header) != 30 or header[:4] != b"PK\x03\x04":
        raise ValueError(f"Invalid ZIP local header: {entry.filename}")
    compression = struct.unpack_from("<H", header, 8)[0]
    if compression != entry.compress_type:
        raise ValueError(f"ZIP compression headers disagree: {entry.filename}")
    name_size, extra_size = struct.unpack_from("<HH", header, 26)
    return entry.header_offset + 30 + name_size + extra_size


def verify_apk(path: Path, abi: str = "arm64-v8a") -> None:
    with zipfile.ZipFile(path) as archive, Path(path).open("rb") as stream:
        _check_archive(archive, abi, allow_other_abis=False)
        resources = archive.getinfo("resources.arsc")
        if resources.compress_type != zipfile.ZIP_STORED:
            raise ValueError("resources.arsc must be uncompressed (ZIP_STORED)")
        if _data_offset(stream, resources) % 4:
            raise ValueError("resources.arsc must be aligned on a 4-byte boundary")
        for entry in archive.infolist():
            if entry.filename.endswith(".so") and entry.compress_type == zipfile.ZIP_STORED:
                if _data_offset(stream, entry) % 16384:
                    raise ValueError(f"Stored native library needs 16-KiB alignment: {entry.filename}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    prepare = commands.add_parser("prepare", help="prepare unsigned APK before zipalign/signing")
    prepare.add_argument("input", type=Path)
    prepare.add_argument("output", type=Path)
    verify = commands.add_parser("verify", help="verify final APK packaging, not its signature")
    verify.add_argument("apk", type=Path)
    for command in (prepare, verify):
        command.add_argument("--abi", choices=ABIS, default="arm64-v8a")
    args = parser.parse_args()
    try:
        if args.command == "prepare":
            prepare_apk(args.input, args.output, args.abi)
            print(f"Prepared {args.output}; run zipalign and apksigner before verification")
        else:
            verify_apk(args.apk, args.abi)
            print(f"APK packaging verified: {args.apk} ({args.abi})")
    except (OSError, ValueError, RuntimeError, zipfile.BadZipFile) as error:
        print(f"APK packaging failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
