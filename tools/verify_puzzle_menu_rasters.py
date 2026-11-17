#!/usr/bin/env python3
"""Require all six actual frames from the production Puzzle menu lifecycle."""
import argparse
from pathlib import Path
import sys

from verify_village_rasters import verify_fixed_rasters


CAPTURE_DIRECTORY = 'captures/puzzle_menu_lifecycle_regression'
EXPECTED_PNGS = {
    f'{CAPTURE_DIRECTORY}/{width}x{height}-{stage}.png': (width, height)
    for width, height in ((960, 540), (640, 360))
    for stage in ('rotation-menu', 'rotation-play', 'classic-play')
}


def verify(root: Path) -> list[dict]:
    return verify_fixed_rasters(root, directory=CAPTURE_DIRECTORY, expected=EXPECTED_PNGS,
                                label='Puzzle menu', manifest='puzzle-menu-images.json')


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('log_dir', type=Path)
    args = parser.parse_args()
    try:
        images = verify(args.log_dir)
    except (OSError, ValueError) as error:
        print(f'[PuzzleMenuRasterRoster] FAIL: {error}', file=sys.stderr)
        return 1
    print(f'[PuzzleMenuRasterRoster] PASS {len(images)} actual PNG files')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
