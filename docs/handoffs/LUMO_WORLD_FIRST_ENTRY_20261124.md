# Lumo World: Kart beim Ersteintritt sehen, hinfinden und Figuren erkennen

24. November 2026. Branch `grok/lumo-world-kart-20261124`, abgezweigt vom Kopf
von PR #226 (`fix/world-kart-save-20261124`,
`6e25e43d4b1c6a035c8bb2c3a45982b0f9ce46ae`). Produktcode-Stand der Prüfung:
`daa771eebc61317b5fe948260ea7084d7f206e74`. Zielversion Godot 4.6.3.

## Befund am Ausgangsstand (gemessen, nicht geschätzt)

Ersteintritt über `SceneRouter.goto("world")` mit frischem Profil, Physik
läuft, keine Testkamera (Godot 4.6.3 headless, 720×1280, 1280×720, 884×920):

- Lumo startet bei `(0, 0, 6)`, das Kart bei `(77, 0.2, 18)`: 77,9 m Abstand.
- Das Kart liegt in allen drei Fenstergrößen außerhalb des Kamerabilds.
- Nelli (90 m), Bruno (152 m) und Tilda (223 m) liegen außerhalb des Bilds;
  Bruno und Tilda werden zusätzlich von Gebäuden verdeckt.
- Die Taste **Ins Kart** ist ab 5 m deaktiviert; es gibt keinen Weg-Hinweis.
- Die Weltkarte zeichnet das Kart nur, wenn es im gewählten Ausschnitt liegt.
- Die drei Figuren tragen nur ihren Namen; nichts kennzeichnet sie als
  computergesteuert. Behauptungen über Online-Mitspieler gibt es in der World
  nicht.
- PR #226 löst bereits: Kartpose speichern/laden, Version-1-Spielstände ohne
  Kart lesbar, Kartmarker und **Mein Kart zeigen** auf der Karte.

## Änderungen

| Datei | Zweck |
|---|---|
| `scripts/creative/lumo_world_state.gd` | `KART_START` / `KART_START_YAW`: neues Spiel stellt das Kart 4,2 m vor Lumo auf den Inselweg, Richtung Inselbrücke. Alte Spielstände ohne `kart` behalten `KART_SPAWN` (Sonnendorf-Parkplatz). Speicherformat unverändert (Version 1). |
| `scripts/creative/lumo_world.gd` | Schild **Dein Kart** über dem abgestellten Kart (beim Fahren ausgeblendet). Weit vom Kart wird die Kart-Taste zu **Kart suchen**: Lichterweg zum Kart, Statuszeile mit Entfernung und Ort, erneutes Tippen beendet die Führung, in Reichweite endet sie selbst. Die Führung ändert weder Aufträge, Fortschritt, Kartpose noch Spielstand. Nelli, Bruno, Tilda erhalten ein zweites Schild **Computerfigur**; die Kartenhilfe sagt ausdrücklich „keine Online-Mitspieler“. Beim Wiedereintritt mit Kart in Reichweite dreht die Gehkamera so, dass das Kart neben Lumo im Bild ist. |
| `scripts/creative/lumo_world_map.gd` | Marker und Legende **Computerfigur** für die drei Figuren; Kartmarker bleibt am Kartenrand mit Pfeil sichtbar, wenn das Kart außerhalb des Ausschnitts steht (`kart_marker_point`). `location_name` ist statisch und wird für die Statuszeile mitgenutzt. |
| `scripts/tests/lumo_world_first_entry_regression.gd` | Neu: echter Einstiegsweg über `SceneRouter`, Sicht auf Kart und Lumo bei vier Fenstergrößen, Boden und Kollision am Start, Fahrt mit echtem Stick bis zur Brücke, Bremse, Aussteigen, Speichern, Wiedereintritt, Führung ohne Daten-/Speicheränderung, Figurenschilder, Karte, alter Spielstand. Optional Renderer-Aufnahmen mit `--capture=<dir>`. |
| `scripts/tests/lumo_world_kart_persistence_regression.gd` | Nur Testaufbau: misst die Breitenprüfung ohne Projekt-Stretch, damit UI-Einheiten und Fensterpixel wie im ursprünglichen Kleinprojekt übereinstimmen. Unter 4.6.3 im vollständigen Projekt schlug genau diese Prüfung vorher fehl (3 von 63). Erwartungen unverändert; die echten 48-dp-Prüfungen (auch für **Mein Kart zeigen**) stehen in `lumo_world_map_regression.gd`. |
| `scripts/tests/lumo_world_regression.gd` | Die aufgezeichnete Kart-Kamerapose setzt jetzt ausdrücklich ihre damalige Nordausrichtung (`rotation.y = 0`), weil ein neues Spiel das Kart Richtung Brücke ausrichtet. Erwartung unverändert. |

## Benutzte Unterlagen

Referenzmappe „Lumo – Referenzmappe und vollständiger Astra-Auftrag“
(03.11.2026, 152 Seiten, als vier Teil-PDFs): Seite 34 (Spielewelt-Hub),
Seite 128 (benannte Kamerarückstellung, ruhiger Standardblick, Wege nicht
verdecken), Seiten 136–137 (Touchflächen ≥ 48 × 48 dp ohne Überlappung,
transparente Belohnungen, reduzierte Bewegung). Seiten 109–111 (Kart-Modus)
nur gelesen; keine Kart-Rennänderung. Codequellen: die oben genannten Dateien
sowie `treasure_wisps.gd`, `lumo_world_art.gd`, `treasure_island_art.gd`,
`scene_router.gd`, `export_presets.cfg`.

## Integration

- Zielstellen: nur die drei World-Skripte; keine Szene-, Asset- oder
  Exportänderung. Alle World-Ressourcen werden über `export_filter="all_resources"`
  exportiert; dynamisch geladene GLB/PNG/TRES sind Ressourcen.
- Spielstände: Format und Version unverändert. Neue Spiele beginnen mit dem
  Kart am Inselweg; vorhandene Spielstände mit `kart` behalten ihre Pose,
  ältere ohne `kart` den Sonnendorf-Parkplatz.
- Für den Android-Kandidaten muss `config/godot-source.json` in lumo-lernen
  auf einen geprüften Commit dieses Zweigs zeigen. Das ist hier nicht geändert.

## Nicht geprüft

Android-Gerät, APK, Vulkan/Mobile-Renderer, Touch auf echter Hardware,
FPS-Messung, Flutter-Host-Einbettung. Renderer-Bilder stammen aus
Xvfb + OpenGL 3 (gl_compatibility, Mesa llvmpipe) auf Linux-Desktop.
