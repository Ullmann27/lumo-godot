#!/usr/bin/env python3
"""Bind the seven actual Safe-Area rasters, settled Cards layouts and reports."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

from verify_village_rasters import verify_fixed_rasters


CARDS_DIRECTORY = 'captures/cards_safe_area_regression'
MOBILE_DIRECTORY = 'captures/mobile_safe_area_regression'
CARDS_PNGS = {
    CARDS_DIRECTORY + '/android35_portrait-playing.png': (1080, 2400),
    CARDS_DIRECTORY + '/android35_portrait-paused.png': (1080, 2400),
    CARDS_DIRECTORY + '/landscape_cutout_fixture-playing.png': (2400, 1080),
}
MOBILE_PNGS = {
    MOBILE_DIRECTORY + '/' + module + '-landscape-cutout.png': (2400, 1080)
    for module in ('jump', 'build', 'puzzle', 'treasure')
}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def file_record(root: Path, path: Path) -> dict:
    require(path.is_file() and not path.is_symlink() and not path.parent.is_symlink(),
            'Safe-Area evidence must be an original regular file: ' + str(path))
    data = path.read_bytes()
    return {'path': path.relative_to(root).as_posix(), 'bytes': len(data),
            'sha256': hashlib.sha256(data).hexdigest()}


def read_json(root: Path, relative: str) -> tuple[dict, dict]:
    path = root / relative
    record = file_record(root, path)

    def invalid_number(value: str):
        raise ValueError('Nonfinite JSON value: ' + value)

    document = json.loads(path.read_bytes(), parse_constant=invalid_number)
    require(isinstance(document, dict), 'Expected a Safe-Area JSON object: ' + relative)
    return document, record


def finite_vector(value, count: int) -> bool:
    return (isinstance(value, list) and len(value) == count
            and all(type(number) in (int, float) and math.isfinite(number) for number in value))


def quad(value) -> bool:
    return isinstance(value, list) and len(value) == 4 and all(finite_vector(point, 2) for point in value)


def successful_report(report: dict, relative: str) -> None:
    require(type(report.get('checks')) is int and report['checks'] > 0
            and report.get('failures') == [], 'Incomplete or failed Safe-Area report: ' + relative)


def verify(root: Path) -> dict:
    cards_path = CARDS_DIRECTORY + '/cards-safe-area.json'
    mobile_path = MOBILE_DIRECTORY + '/mobile-safe-area.json'
    cards, cards_record = read_json(root, cards_path)
    mobile, mobile_record = read_json(root, mobile_path)
    successful_report(cards, cards_path)
    successful_report(mobile, mobile_path)
    require(cards.get('android_device_measurement') is False
            and isinstance(cards.get('renderer'), str)
            and cards['renderer'].lower() not in ('', 'headless'),
            'Cards report must identify the actual fixture renderer')

    card_images = cards.get('images')
    require(isinstance(card_images, list) and len(card_images) == 3
            and all(isinstance(row, dict) and isinstance(row.get('path'), str) for row in card_images),
            'Cards report must contain exactly three original captures')
    reported_cards = {Path(row['path']).name: row for row in card_images}
    require(set(reported_cards) == {Path(path).name for path in CARDS_PNGS},
            'Cards report refers to a different capture roster')
    layouts = {}
    for relative, dimensions in CARDS_PNGS.items():
        name = Path(relative).name
        require(reported_cards[name].get('size') == list(dimensions),
                'Cards report has different physical dimensions: ' + relative)
        layout_path = str(Path(relative).with_suffix('.layout.json'))
        layout, record = read_json(root, layout_path)
        require(type(layout.get('schema')) is int and layout['schema'] == 1,
                'Unsupported native Cards layout: ' + layout_path)
        require(type(layout.get('layout_sequence')) is int and layout['layout_sequence'] > 0,
                'Cards layout lacks its original integer sequence: ' + layout_path)
        require(layout.get('settled') is True and layout.get('ui_visible') is True
                and type(layout.get('pending')) is int and layout['pending'] == 0,
                'Cards layout is not a settled visible observation: ' + layout_path)
        require(layout.get('observation_source') == 'fixture'
                and layout.get('window_px') == list(dimensions),
                'Cards layout is not bound to the current fixture viewport: ' + layout_path)
        require(layout.get('paused') is name.endswith('-paused.png'),
                'Cards layout phase does not match its capture: ' + layout_path)
        hand = layout.get('hand')
        discard = layout.get('discard')
        require(isinstance(hand, list) and bool(hand)
                and all(isinstance(row, dict) and isinstance(row.get('id'), str)
                        and bool(row['id'].strip()) and quad(row.get('quad')) for row in hand)
                and isinstance(discard, dict) and isinstance(discard.get('id'), str)
                and bool(discard['id'].strip()) and quad(discard.get('quad')),
                'Cards layout lacks the actual hand/discard projection: ' + layout_path)
        layouts[relative] = record

    targets = mobile.get('targets')
    require(isinstance(targets, list) and len(targets) == 15
            and all(isinstance(row, dict) and row.get('fully_inside_true_safe_area') is True
                    and finite_vector(row.get('exposed_dp'), 2)
                    and min(row['exposed_dp']) >= 47.95 for row in targets),
            'The 15 shared controls must remain fully inside the observed fixture safe area at 48 dp')
    mobile_images = mobile.get('images')
    require(isinstance(mobile_images, list) and len(mobile_images) == 4
            and all(isinstance(row, dict) and isinstance(row.get('path'), str) for row in mobile_images),
            'Shared Safe-Area report must contain exactly four original captures')
    reported_mobile = {row['path']: row for row in mobile_images}
    require(set(reported_mobile) == {Path(path).name for path in MOBILE_PNGS},
            'Shared Safe-Area report refers to a different capture roster')
    for relative, dimensions in MOBILE_PNGS.items():
        reported = reported_mobile[Path(relative).name]
        record = file_record(root, root / relative)
        require(reported.get('sha256') == record['sha256']
                and (reported.get('width'), reported.get('height')) == dimensions,
                'Shared Safe-Area original PNG bytes/dimensions disagree with the report: ' + relative)

    # Reuse the existing complete decoder and visible-pixel checks. Successful
    # component manifests are partial evidence until this combined manifest exists.
    cards_checked = verify_fixed_rasters(
        root, directory=CARDS_DIRECTORY, expected=CARDS_PNGS,
        label='Cards safe area', manifest='cards-safe-area-images.json')
    mobile_checked = verify_fixed_rasters(
        root, directory=MOBILE_DIRECTORY, expected=MOBILE_PNGS,
        label='Shared safe area', manifest='mobile-safe-area-images.json')
    for image in cards_checked:
        image['native_layout'] = layouts[image['path']]
    result = {'schema': 1, 'images': cards_checked + mobile_checked,
              'reports': [cards_record, mobile_record]}
    temporary = root / '.safe-area-images.json.tmp'
    temporary.write_text(json.dumps(result, indent=2) + '\n')
    temporary.replace(root / 'safe-area-images.json')
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('log_dir', type=Path)
    args = parser.parse_args()
    try:
        result = verify(args.log_dir)
    except (OSError, ValueError, TypeError, KeyError) as error:
        print(f'[SafeAreaRasterRoster] FAIL: {error}', file=sys.stderr)
        return 1
    print(f'[SafeAreaRasterRoster] PASS {len(result["images"])} actual PNG files and 3 settled layout sidecars')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
