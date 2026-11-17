"""Index final native Blender renders and verify their source hashes and sizes."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import struct


ROOT = Path(__file__).resolve().parents[3]
EVIDENCE = ROOT / 'evidence/lumo_kart_art/drivers'


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def image_record(path: Path, resolution: list[int], inputs: list[dict]) -> dict:
    with path.open('rb') as handle:
        header = handle.read(24)
    assert header[:8] == b'\x89PNG\r\n\x1a\n', path
    dimensions = list(struct.unpack('>II', header[16:24]))
    assert dimensions == resolution, (path, dimensions, resolution)
    for source in inputs:
        source_path = ROOT / source['file']
        assert digest(source_path) == source['sha256'], source_path
        assert path.stat().st_mtime_ns >= source_path.stat().st_mtime_ns, path
    return {
        'file': str(path.relative_to(ROOT)),
        'sha256': digest(path),
        'bytes': path.stat().st_size,
        'resolution': dimensions,
        'inputs': inputs,
    }


def main() -> None:
    package = json.loads((ROOT / 'assets/kart/production/drivers/manifest.json').read_text())
    expected = {entry['id']: entry['blender_source'] for entry in package['drivers']}
    images = []
    for prefix in ['roster_', 'roster_kart_']:
        report = json.loads((EVIDENCE / (prefix + 'render.json')).read_text())
        inputs = []
        for model in report['inputs']:
            source = expected[model['species']]
            assert model['blend'] == source['file'] and model['sha256'] == source['sha256'], model
            inputs.append({'file': source['file'], 'sha256': source['sha256']})
        if 'kart' in report:
            inputs.append(report['kart'])
        for angle in report['angles_degrees']:
            entry = image_record(EVIDENCE / (prefix + angle + '.png'), report['resolution'], inputs)
            entry.update({'view': angle, 'renderer': report['engine'], 'samples_max': report['samples_max']})
            images.append(entry)

    comparison = json.loads((EVIDENCE / 'rabbit/comparison_measurement.json').read_text())
    rabbit = expected['rabbit']
    assert comparison['driver_source_sha256'] == rabbit['sha256']
    assert abs(comparison['post_transform_floor_m']) < .0001
    assert abs(comparison['post_transform_body_height_m'] - comparison['target_body_height_m']) < .001
    inputs = [
        {'file': comparison['driver_source'], 'sha256': comparison['driver_source_sha256']},
        {'file': comparison['source'], 'sha256': comparison['source_sha256']},
    ]
    for angle in ['front', 'three_quarter']:
        path = EVIDENCE / 'rabbit' / ('rabbit_and_original_lumo_' + angle + '.png')
        entry = image_record(path, comparison['resolution'], inputs)
        entry.update({'view': angle, 'renderer': 'Blender Cycles CPU', 'samples_max': comparison['samples_max']})
        images.append(entry)
    assert len(images) == 8
    result = {
        'schema_version': 1,
        'status': 'PASS',
        'scope': 'Final PNG existence, dimensions, source hashes and render/source freshness. This does not automate visual art judgement.',
        'images': images,
        'comparison': comparison,
    }
    (EVIDENCE / 'final_render_manifest.json').write_text(json.dumps(result, indent=2) + '\n')

    lines = [
        '# Finale Blender-Ansichten', '',
        'Die folgenden acht Bilder wurden aus den eingefrorenen bearbeitbaren Blender-Szenen gerendert. '
        'Die Hashes der Eingaben entsprechen dem Fahrer-Manifest; alle Bilder wurden nach den zugehörigen Quelldateien erzeugt. '
        'Der vollständige Bildnachweis steht in `evidence/lumo_kart_art/drivers/final_render_manifest.json`.', '',
        '| Ansicht | Auflösung | Datei ab Repository-Wurzel |',
        '|---|---|---|',
    ]
    for item in images:
        dimensions = ' × '.join(str(value) for value in item['resolution'])
        lines.append(f"| {item['view']} | {dimensions} | `{item['file']}` |")
    lines += [
        '',
        'Die Charakterübersichten zeigen alle fünf Fahrer mit identischer Kamera und Beleuchtung. '
        'Die Kartbilder behalten die unveränderte Comet-Geometrie und die tatsächlichen relativen Fahrer-/Kartursprünge bei. '
        'Nur die gemeinsame Präsentationsgruppe wird für die Rückansichten gedreht.', '',
        'In der freien Eulen-Rückansicht verdeckt der Anzug einen Teil der flach anliegenden Federn; '
        'sichtbar bleibt eine Kontur aus Federspitzen. Die Kart-Rückansichten zeigen den tatsächlich sichtbaren Bereich über der Lehne. '
        'Dieser gestalterische Befund gehört zum dokumentierten eingefrorenen Modellstand.', '',
        f"Im Originalvergleich beträgt die gemessene gemeinsame Körperhöhe {comparison['target_body_height_m']:.6f} m. "
        'Gemessen wird von der Sohle bis zur zentralen Schädelkrone, ohne die langen Hasenohren. '
        'Nur der unveränderte Original-Fuchs erhält eine gleichmäßige Vergleichsskalierung; es gibt keine nicht proportionale Skalierung.', '',
        'Der Original-Fuchs bleibt der vorhandene LUMO-Charakter. Die zugehörigen Herkunfts- und Lizenzangaben in '
        '`assets/characters/lumo_animated/ATTRIBUTION.md` gelten auch für seine Darstellung in diesen Vergleichsbildern.', '',
        'Frühere Dateien mit `_preview` im Namen sind Arbeitsansichten. Für den finalen Modellstand sind die acht oben aufgeführten Dateien maßgeblich.',
    ]
    (ROOT / 'docs/art/lumo_kart/drivers/FINAL_RENDERS.md').write_text('\n'.join(lines) + '\n')
    print('DRIVER_RENDER_EVIDENCE_PASS', len(images))


if __name__ == '__main__':
    main()
