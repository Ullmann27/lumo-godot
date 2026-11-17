# Lumo Kart – gerendertes 3D-UI-Kit

Platten, Knöpfe, Icons und Platz-Abzeichen im Stil der Zielbilder vom 17.11.2026
(`docs/design_targets/2026-11-17/`): Neon-Glas, plastische Kanten, glänzende 3D-Icons.

## Herkunft

Alles in diesem Ordner ist selbst gemacht: `tools/art/render_ui_kit.py` baut jedes Teil
prozedural in Blender und rendert es mit Cycles auf transparentem Grund. Keine fremden
Meshes, Texturen, Logos oder Downloads.

Einzige Fremddatei ist die Projektschrift für die Ziffern der Platz-Abzeichen:
`assets/fonts/Nunito-Black.ttf` (dieselbe wie `HEADING` in `scripts/games/kart_ui_theme.gd`),
SIL Open Font License 1.1, Lizenztext in `assets/fonts/Nunito-LICENSE.txt`.

## Neu erzeugen

```bash
/home/user/tools/bpyenv/bin/python tools/art/render_ui_kit.py              # alles (ca. 3–4 Minuten, CPU)
/home/user/tools/bpyenv/bin/python tools/art/render_ui_kit.py --only icon_flag,plate_nav
/home/user/tools/bpyenv/bin/python tools/art/render_ui_kit.py --only 'badge_*'
/home/user/tools/bpyenv/bin/python tools/art/render_ui_kit.py --list
```

Braucht Blender als Python-Modul (`bpy`), dazu Pillow und numpy. Das Skript schreibt die
WebP-Dateien und `ui_kit.json` neu. Gleiche Maschine, gleiche Eingaben: gleiche Dateien.
Mit `--contact-sheet <png>` und `--stretch-test <png>` entstehen Prüfbilder (nicht ins Repo).

Prüfung in Godot:

```bash
/home/user/tools/godot --headless --script scripts/tests/kart_ui3d_kit_regression.gd
```

## Benutzen

`ui_kit.json` nennt je Datei Größe, 9-Slice-Ränder `[links, oben, rechts, unten]`
(bei Icons und Abzeichen `null`), den durchsichtigen Leuchtrand `glow_pad` und den Zweck.

Die Texturen sind für die 720×1280-Grundfläche in **doppelter Auflösung** gebaut
(`design_scale` 2), damit sie auf Tablet und Fold scharf bleiben. Die 9-Slice-Ränder gelten
in Texturpixeln. Eine Platte wird deshalb mit Faktor 0,5 gezeichnet, zum Beispiel so:

```gdscript
func _draw() -> void:  # box: StyleBoxTexture mit texture_margin_* aus nine_slice
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(0.5, 0.5))
	draw_style_box(box, Rect2(Vector2.ZERO, size * 2.0))
```

Ohne den Faktor (StyleBoxTexture direkt) sind Ecken und Rand doppelt so groß und die
Platte braucht mindestens die Summe ihrer Ränder als Fläche.

Der Leuchtrand gehört zur Textur: Die sichtbare Platte ist ringsum um `glow_pad` (halbiert
bei Faktor 0,5) kleiner als das gezeichnete Rechteck. Nachbarn dürfen sich im Leuchtrand
überlappen.

- `plate_*`, `panel_glass_navy`, `row_stat`, `button_*`: 9-Slice. Die Mitte ist ein reiner
  Verlauf, das Schachmuster der großen Kacheln sitzt nur in der Ecke oben rechts.
- `button_*_pressed`: gleiche Größe und Ränder wie der Knopf, Kappe tiefer, Kante schmal.
- `icon_*`: 256×256, auf 48 px lesbar.
- `badge_place_1..3`: 512×512, Ziffer mit Lorbeer. `badge_place_other`: Lorbeer mit
  Glasscheibe, die Platzzahl kommt als Text darüber.
