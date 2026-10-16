"""Start a race by tapping only actual text bounds from Android screenshots."""
from pathlib import Path
import csv
import io
import json
import os
import re
import shutil
import subprocess
import sys
import time
import unicodedata

from PIL import Image

# OCR shares the software-rendered emulator host; bound its thread usage.
os.environ.setdefault('OMP_THREAD_LIMIT', '1')


def normalized(text):
    plain = unicodedata.normalize('NFKD', text).encode('ascii', 'ignore').decode()
    return re.sub('[^a-z0-9]', '', plain.lower())


def ocr_variants(image):
    """Readable black-on-white versions of one real screenshot.

    Light labels sit on dark glass panels; the primary footer action is dark
    navy text on a gold button. Small 320x640 emulator captures need the
    upscale before thresholding, otherwise the anti-aliased 10 px glyphs
    break apart and the visible button is not read.
    """
    yield 2, image.convert('L').point(lambda value: 0 if value >= 170 else 255).resize(
        (image.width*2, image.height*2))
    scale = 4 if image.width < 1200 else 2
    yield scale, image.resize((image.width*scale, image.height*scale), Image.LANCZOS) \
        .convert('L').point(lambda value: 0 if value < 140 else 255)


def footer_targets(image, label, read_tsv):
    """Exact label matches in the lower 40 percent, in screenshot pixels."""
    wanted = normalized(label)
    targets = []
    for scale, picture in ocr_variants(image):
        lines = {}
        rows = csv.DictReader(io.StringIO(read_tsv(picture)), delimiter='\t',
                              quoting=csv.QUOTE_NONE)
        for word in rows:
            if not (word.get('text') or '').strip() or float(word['conf']) < 15:
                continue
            key = tuple(word[k] for k in ('block_num', 'par_num', 'line_num'))
            lines.setdefault(key, []).append(word)
        for words in lines.values():
            words.sort(key=lambda w: int(w['left']))
            for start in range(len(words)):
                for end in range(start+1, min(len(words), start+8)+1):
                    span = words[start:end]
                    text = ' '.join(w['text'] for w in span)
                    if wanted != normalized(text):
                        continue
                    x0 = min(int(w['left']) for w in span)/scale
                    y0 = min(int(w['top']) for w in span)/scale
                    x1 = max(int(w['left'])+int(w['width']) for w in span)/scale
                    y1 = max(int(w['top'])+int(w['height']) for w in span)/scale
                    if y0 >= image.height*.6:
                        targets.append((len(text), text, [x0, y0, x1, y1]))
    return sorted(targets)


def tesseract_tsv(work):
    def read(picture):
        picture.save(work)
        return subprocess.run(['tesseract', str(work), 'stdout', '--psm', '11',
                               '-l', 'deu+eng', 'tsv'], check=True,
                              capture_output=True, text=True, timeout=30).stdout
    return read


def main():
    out = Path(sys.argv[1])
    adb = os.environ.get('ADB') or shutil.which('adb')
    if not adb:
        raise RuntimeError('adb missing')
    serial = os.environ.get('ADB_SERIAL') or os.environ.get('ANDROID_SERIAL')
    prefix = [adb] + (['-s', serial] if serial else [])
    evidence = []
    for step in range(5):
        label = 'Weiter' if step < 4 else 'Rennen starten'
        for attempt in range(12):
            png = subprocess.run(prefix + ['exec-out', 'screencap', '-p'],
                                 check=True, capture_output=True, timeout=15).stdout
            screenshot = out / f'kart-garage-step-{step+1}.png'
            screenshot.write_bytes(png)
            image = Image.open(io.BytesIO(png)).convert('RGB')
            targets = footer_targets(image, label, tesseract_tsv(out / 'garage-ocr-input.png'))
            if targets:
                _, text, bounds = targets[0]
                x0,y0,x1,y1 = bounds
                subprocess.run(prefix + ['shell','input','tap',str(round((x0+x1)/2)),
                                         str(round((y0+y1)/2))], check=True, timeout=15)
                evidence.append({'step':step+1,'label':text,'observed_bounds':bounds,
                                 'capture':screenshot.name})
                print('[AndroidGarage] actual screenshot touch:',step+1,text,flush=True)
                time.sleep(2)
                break
            time.sleep(1)
        else:
            raise RuntimeError(f'Visible footer control missing at step {step+1}: {label}')
    (out/'android-garage-touches.json').write_text(json.dumps(evidence,indent=2)+'\n')
    print('[AndroidGarage] PASS: five real screenshot-directed touches',flush=True)


if __name__ == '__main__':
    main()
