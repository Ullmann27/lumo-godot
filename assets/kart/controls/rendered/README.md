# Lumo Kart – gerenderte Bedienknöpfe

Gas (grün-türkis, Doppelpfeil), Bremse (rot-orange, Bremsscheibe), Drift (blau, Reifen mit
Funken), Turbo (gold, Rakete), Item (violett, Überraschungs-Kiste; scharf = rot-gold,
Schild = cyan) und der Lenk-Stick (Basis + Knauf). Je Knopf `_normal`, `_pressed`,
`_disabled`, bei Turbo/Item zusätzlich `_ready`, beim Item `_armed`, `_armed_pressed`, `_shield`.

Herkunft: alles selbst gebaut. `tools/art/render_kart_controls.py` modelliert jedes Teil in
Blender (bpy 5.3, Cycles CPU, transparenter Hintergrund, 512 px) mit den Bausteinen aus
`tools/art/render_ui_kit.py` und legt es auf 384 px verkleinert als WebP ab. Keine fremden
Meshes, Texturen, Icons oder Downloads; einzige Fremddatei ist die Projektschrift
`assets/fonts/Nunito-Black.ttf` (SIL OFL 1.1) für das Fragezeichen der Item-Kiste.

```bash
/home/user/tools/bpyenv/bin/python tools/art/render_kart_controls.py            # alles
/home/user/tools/bpyenv/bin/python tools/art/render_kart_controls.py --only brake,stick_knob
```

Benutzt von `scripts/games/kart_touch_action.gd` und `scripts/games/kart_joystick.gd`
(Skin `"kart3d"`), eingeschaltet in `scripts/games/kart_hud/kart_race_hud.gd`.
