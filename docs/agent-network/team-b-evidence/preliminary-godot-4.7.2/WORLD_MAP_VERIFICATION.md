# World-Karte – Prüfung vom 23. November 2026

## Ergebnis

Godot 4.7.2, echte Xorg/Mesa-Softwaredarstellung: **136 Prüfungen bestanden**, Exitcode 0. Der vorliegende PNG-Capture wurde visuell geprüft. Ein im ersten Lauf entdeckter Umbruchfehler in der Legende und eine Überlagerung mit der Nordanzeige wurden vor diesem Ergebnis korrigiert.

## Umfang

- Fünf tatsächliche Control-Layouts: 280×640, 360×800, 640×360, 720×840 und 1280×720.
- Echte Klicks durch die Viewport-Eingabe auf Standort-, Ziel-, Welt- und gescrollte Ortswahl.
- Bedienelemente mindestens 48 logische Pixel, keine horizontale Abschneidung, lesbare einzeilige Legendentexte.
- Gleicher Maßstab für beide Weltachsen, lokale Ansicht am äußeren Dorfrand, vollständige Weltansicht.
- Abgeschlossener Hauptauftrag ohne aktiven Zielknopf; Quellzustände bleiben durch Kartennutzung unverändert.
- Grenzen-Clipping für Wege; Eingabedaten werden tief kopiert.

## Reproduktion und Grenzen

Das unveränderte Karten- und Testskript lief in einem minimalen Godot-Projekt ohne Autoloads oder 3D-Assets. Der dokumentierte Rendereraufruf und die Engine-Ausgabe stehen in `world-map-renderer-run.json` und `world-map-renderer.log`. Das Quellskript des Tests enthält den optionalen Capturepfad über `LUMO_WORLD_MAP_CAPTURE`.

Dieser Beleg gilt für die Kartenkomponente. Kein vollständiger World-Szenenstart, kein Android-Gerät, keine APK und keine Bildratenmessung werden damit bestätigt. Der Renderer meldet eine fehlende V-Sync-Umschaltung; die Tests und Bildausgabe wurden mit Mesa llvmpipe durchgeführt.

## SHA-256

| Datei | SHA-256 |
|---|---|
| `scripts/creative/lumo_world_map.gd` | `267f3410246ad7c923b3d0b65e11e9a3848e1bb4897df07c704fbb144ed88fe7` |
| `scripts/tests/lumo_world_map_regression.gd` | `4b129e3e77f2f6e1ed4eab94dedb1e8a61a2fe3fa1045c62d9db7406bb56d034` |
| `docs/agent-network/team-b-evidence/world-map.png` | `0c77ed4d674f7a45ffe02d32a273e93582c67e318b7522102cab657d806eccf3` |
