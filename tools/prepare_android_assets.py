#!/usr/bin/env python3
"""Install an exported PCK and Godot 4.6's binary Android startup file."""

import argparse
from pathlib import Path
import shutil
import struct


PACK_NAME = "lumo3d.pck"
COMMAND_LINE = ("--main-pack", "res://" + PACK_NAME, "--rendering-method", "gl_compatibility")


def encode_command_line(arguments: tuple[str, ...]) -> bytes:
    result = bytearray(struct.pack("<I", len(arguments)))
    for argument in arguments:
        data = argument.encode("utf-8")
        if not data or len(data) > 65535:
            raise ValueError("Invalid Android command-line argument length")
        result.extend(struct.pack("<I", len(data)))
        result.extend(data)
    return bytes(result)


def decode_command_line(data: bytes) -> tuple[str, ...]:
    if len(data) < 4:
        raise ValueError("Missing Android command-line header")
    count = struct.unpack_from("<I", data)[0]
    offset = 4
    arguments = []
    for _ in range(count):
        if offset + 4 > len(data):
            raise ValueError("Truncated Android command-line length")
        length = struct.unpack_from("<I", data, offset)[0]
        offset += 4
        if not 0 < length <= 65535 or offset + length > len(data):
            raise ValueError("Truncated Android command-line argument")
        arguments.append(data[offset:offset + length].decode("utf-8"))
        offset += length
    if offset != len(data):
        raise ValueError("Unexpected Android command-line trailing bytes")
    return tuple(arguments)


def check_pack_header(data: bytes) -> None:
    if len(data) < 20 or data[:4] != b"GDPC":
        raise ValueError("Missing or invalid Godot PCK header")
    version, major, minor, patch = struct.unpack_from("<4I", data, 4)
    if (version, major, minor, patch) != (3, 4, 6, 3):
        raise ValueError("PCK must be exported by the matching Godot 4.6.3 engine")


def prepare_assets(pack: Path, assets: Path) -> None:
    pack, assets = Path(pack), Path(assets)
    with pack.open("rb") as source:
        check_pack_header(source.read(20))
    assets.mkdir(parents=True, exist_ok=True)
    command_file = assets / "_cl_"
    if command_file.is_dir():
        # Remove only the known broken layout; retain unexpected files for review.
        legacy_pack = command_file / PACK_NAME
        if set(command_file.iterdir()) - {legacy_pack}:
            raise ValueError("Unexpected files in legacy _cl_ directory")
        legacy_pack.unlink(missing_ok=True)
        command_file.rmdir()
    destination = assets / PACK_NAME
    if not destination.exists() or not pack.samefile(destination):
        shutil.copyfile(pack, destination)
    command_file.write_bytes(encode_command_line(COMMAND_LINE))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("pack", type=Path)
    parser.add_argument("assets", type=Path)
    args = parser.parse_args()
    prepare_assets(args.pack, args.assets)
    print(f"Android assets prepared: {PACK_NAME} and binary _cl_ startup file")


if __name__ == "__main__":
    main()
