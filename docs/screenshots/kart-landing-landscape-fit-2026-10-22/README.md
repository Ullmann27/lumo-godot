# Kart-Startmenü im Querformat – Vorher/Nachher (22.10.2026)

Echte Godot-4.6.3-Renderings (gl_compatibility unter xvfb) von
`scripts/games/kart_reference_landing.gd`, erzeugt mit
`LUMO_CAPTURE_DIR=<ordner> scripts/tests/kart_reference_landing_fit_regression.gd`.
Fenstergröße in Pixeln und Android-Dichte über `HostBridge` wie auf dem Gerät:

| Datei | Pixel | Dichte | entspricht |
|---|---|---|---|
| `vorher_nachher_emulator_landscape.jpg` | 2400×1080 | 2,625 | Pixel-5-Emulator der Android-Tour |
| `vorher_nachher_phone_720p_landscape.jpg` | 1600×720 | 2,0 | kleines 720p-Handy |
| `vorher_nachher_fold_cover_landscape.jpg` | 2316×904 | 2,625 | Fold außen, quer |
| `vorher_nachher_fold_open.jpg` | 2176×1812 | 2,625 | Fold innen |

Vorher: `700baf49`. Die untere Kachelreihe (Sonnenhafen, Garage, Einstellungen)
lag samt Beschriftung unter dem START-Balken; derselbe Befund ist im echten
Android-Emulatorbild von Lumo-Unified-Lauf 39723572595 sichtbar.
Nachher: alle fünf Kacheln lesbar über START, ohne Scrollen.

Nicht geprüft: echtes Samsung-Gerät; Kart erzwingt auf Android Querformat, daher
kein Hochformat-Profil.
