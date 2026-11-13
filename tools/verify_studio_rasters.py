#!/usr/bin/env python3
"""Require the published Studio captures and record their original PNG hashes."""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import sys


REQUIRED = {
    'learning_sharing_capture': 6,
    'lumo_studio_motion_capture': 8,
    'puzzle_rotation_regression': 7,
    'treasure_exploration_regression': 3,
}


def verify(root: Path) -> list[dict]:
    images = []
    for probe, count in REQUIRED.items():
        found = sorted((root / 'captures' / probe).glob('*.png'))
        if len(found) != count:
            raise ValueError(f'{probe}: found {len(found)} PNGs, expected {count}')
        for path in found:
            data = path.read_bytes()
            if len(data) < 24 or data[:8] != b'\x89PNG\r\n\x1a\n':
                raise ValueError(f'Invalid PNG: {path}')
            width, height = struct.unpack('>II', data[16:24])
            if width < 360 or height < 360:
                raise ValueError(f'Undersized PNG: {path} ({width}x{height})')
            images.append({
                'path': path.relative_to(root).as_posix(),
                'width': width,
                'height': height,
                'bytes': len(data),
                'sha256': hashlib.sha256(data).hexdigest(),
            })
    (root / 'renderer-images.json').write_text(json.dumps({'images': images}, indent=2) + '\n')
    return images


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('log_dir', type=Path)
    args = parser.parse_args()
    try:
        images = verify(args.log_dir)
    except (OSError, ValueError) as error:
        print(f'[StudioRasterRoster] FAIL: {error}', file=sys.stderr)
        return 1
    print(f'[StudioRasterRoster] PASS {len(images)} actual PNG files')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
