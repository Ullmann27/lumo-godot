# Lumo Kart – gerendertes 3D-UI-Kit

Platten, Knöpfe, Rahmen, Balken, Icons, Lichtschichten und Platz-Abzeichen im Stil der
Zielbilder vom 17.11.2026 (`docs/design_targets/2026-11-17/`): Neon-Glas, plastische Kanten,
glänzende 3D-Icons. Das Kart-Hauptmenü (`scripts/games/kart_neon_*.gd`) zeichnet alle
Kacheln, Tafeln, Knöpfe und Icons aus diesem Kit.

## Herkunft

Alles in diesem Ordner ist selbst gemacht: `tools/art/render_ui_kit.py` baut jedes Teil
prozedural in Blender und rendert es mit Cycles auf transparentem Grund. Keine fremden
Meshes, Texturen, Logos oder Downloads. Ausnahme von „gerendert“: die beiden Lichtschichten
`overlay_*` sind reine Helligkeitsmuster und werden im selben Skript mit numpy berechnet.

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

Im Spiel läuft alles über einen Helfer, `scripts/games/kart_ui3d.gd`. Er liest das Manifest
einmal, hält Texturen (mit Mipmaps), 9-Slice-Ränder und StyleBoxen im Speicher und zeichnet
im richtigen Maßstab:

```gdscript
const KIT = preload("res://scripts/games/kart_ui3d.gd")

func _draw() -> void:  # k = dp-Maßstab des Menüs (Pixel je dp)
	if not KIT.draw_plate(self, "plate_hero_amber", Rect2(Vector2.ZERO, size), k):
		_draw_flat()                       # Textur fehlt: eigener Vektor-Ersatz
	KIT.draw_icon(self, "icon_flag", Vector2(40, 40) * k, 56 * k)
	KIT.draw_bar(self, "bar_fill_gold", bar_rect, 0.65, k)

button.add_theme_stylebox_override("normal", KIT.themed("button_primary_gold", k))
```

- `draw_plate()` legt den festen Körper der Platte genau auf das Rechteck; der Leuchtrand
  liegt außerhalb. Nachbarn dürfen sich im Leuchtrand überlappen.
- `themed()` gibt eine StyleBox für gewöhnliche Buttons und Panels (eine Instanz je Platte
  und Maßstab).
- `face_outline()` liefert den Umriss des Glasfelds (aus `corners`, `rim`, `lip`), mit
  `overlay_uvs()` und `draw_overlay()` wird eine Lichtschicht unverzerrt darübergelegt und
  exakt auf die abgeschrägte Kachel beschnitten. Derselbe Umriss ist der Fokusring.
- Jede Funktion meldet eine fehlende Textur (`false` bzw. `null`); das Menü zeichnet dann
  seinen flachen Vektor-Ersatz.

`ui_kit.json` nennt je Datei Größe, 9-Slice-Ränder `[links, oben, rechts, unten]`
(bei Icons, Lichtschichten und Abzeichen `null`), den durchsichtigen Leuchtrand `glow_pad`
und den Zweck. Platten nennen zusätzlich `corners` (unten links, unten rechts, oben rechts,
oben links; `r` rund, `c` abgeschrägt), `rim` (Randbreite) und `lip` (sichtbare Kante unter
dem Glasfeld). Lichtschichten nennen ihren Anker (`top_right` oder `bottom_right`).

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
  Verlauf. Die großen Kacheln `plate_hero_*` haben ein kräftiges Außenleuchten; ihr
  Schachmuster und die Lichtbahnen kommen als Lichtschicht darüber.
- `button_*_pressed`: gleiche Größe und Ränder wie der Knopf, Kappe tiefer, Kante schmal.
- `frame_neon_cyan`, `frame_neon_amber`: Neonrahmen mit durchsichtiger Mitte für
  Streckenbilder (Bernstein = gewählt), 9-Slice.
- `bar_track`, `bar_fill_gold`, `bar_fill_cyan`: Rinne und Füllung eines Fortschrittsbalkens,
  9-Slice; über `draw_bar()` wächst die Kappe mit der Balkenhöhe, die Enden bleiben rund.
- `overlay_hero_streak` (schräge Lichtbahnen, großes Schachmuster) und `overlay_glass_grid`
  (Holo-Bodenraster mit Lichtfleck): 384×256, **nicht dehnen**, nur über `draw_overlay()`.
- `icon_*`: 256×256, auf 48 px lesbar. Neu für das Menü: `icon_back`, `icon_play`,
  `icon_rotate` (für links gespiegelt zeichnen), `icon_chevrons`, `icon_alert`.
- `badge_place_1..3`: 512×512, Ziffer mit Lorbeer. `badge_place_other`: Lorbeer mit
  Glasscheibe, die Platzzahl kommt als Text darüber.
