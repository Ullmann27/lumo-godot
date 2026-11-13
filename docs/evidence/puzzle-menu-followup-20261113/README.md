# Puzzle-Menü: sichere Freigabe nach Button-Release

Dieser lokale Folgekandidat basiert exakt auf Native
`76980a941fa05d047574d8cc386d3249d93ffca3`. Er ist nicht in den eingefrorenen
Studio-/APK-Stand übernommen. Die aktive Godot-Arbeitskopie und der aktive
Flutter-Host wurden durch diese Untersuchung nicht geändert.

## Fehler und kleine Reparatur

Beim Tippen auf Teilezahl, Motiv oder Modus baut `_show_selection()` das Menü
neu auf. `_clear_menu()` entfernte den gerade auslösenden Button sofort mit
`menu_box.remove_child(child)`. Godot traversiert beim Abschluss des Releases
noch dessen Control-Eltern und meldet dann `!is_inside_tree()` in
`can_process()`. Dasselbe betrifft „Anderes Puzzle“ im Pausenmenü.

Die Reparatur ändert ausschließlich diese Freigabe: Alte Controls werden
sofort ausgeblendet und mit dem vorhandenen `queue_free()` nach der laufenden
Ereignisverarbeitung gelöscht. Auswahl, Spielregeln, Speicherschema und
Belohnungen bleiben unverändert. Keine Verzögerung oder Fehlerunterdrückung
wurde in den Eingabeweg eingebaut.

## Tatsächlicher Rot-/Grün-Nachweis

Die neue `scripts/tests/puzzle_menu_lifecycle_regression.gd` läuft in einer
echten Godot-4.6.3-X11-Sitzung mit dem lokalen Mesa-Software-Renderer. Sie
sendet Root-Viewport-`InputEventScreenTouch` und `InputEventScreenDrag`.
Getestet wurden 960 × 540 und 640 × 360, jeweils bei simulierter Dichte 1.

| Ergebnis | Original 76980 | Reparatur |
| --- | ---: | ---: |
| Verhaltensprüfungen erfolgreich | 732 | 732 |
| Native `can_process`-Fehler | 46 | 0 |
| Godot-Prozessstatus | 0 | 0 |
| Strikter Log-Gate | FAIL, Exit 1 | PASS, Exit 0 |
| Tatsächliche Rendererbilder | 6 | 6 |

Die Probe ist zwischen beiden Läufen bytegleich. Das vollständige
Eingabe-/Zustands-JSON ist ebenfalls bytegleich und deshalb einmal als
`identical-input-state-report.json` gespeichert. Die ursprünglichen Logs,
Laufberichte, Quellenbindungen und strikten Ergebnisse liegen unverändert
mit `before-` beziehungsweise `after-` im Dateinamen vor.

Die tatsächlichen Eingaben durchlaufen alle fünf Teilezahlen und Motive,
mehrfach rasch den Moduswechsel, Start und Vierteldrehung im Drehpuzzle,
Pause → Anderes Puzzle, anschließend den Klassikstart und eine echte
Teilplatzierung samt Speichern bei Pause und Wiederaufnahme. Es wurden keine
Spielzustände, Teilpositionen oder Fortschritte eingesetzt. Die 124
Touch-Ereignisse und 16 Drag-Ereignisse stehen im Zustandsbericht.

Unveränderte Bestandsprüfungen bestanden zusätzlich:

- `puzzle_expansion_regression.gd`: 1103 Prüfungen, keine nativen Fehler.
- `puzzle_rotation_regression.gd`: 4558 Prüfungen, keine nativen Fehler.

Die sechs beigefügten Nachher-PNGs wurden einzeln geöffnet. Menüauswahl,
Drehpuzzle und Klassikplatzierung sind sichtbar; alte Menüs bleiben nicht
über dem Spiel liegen. In 640 × 360 sind weiterhin Scrollausschnitte nötig.
Das ist keine neue Abnahme aller Menüeinträge ohne Scrollen.

## Reproduktion des reparierten Stands

Aus dem Projektverzeichnis, mit einem freien exklusiven Testdisplay und
neuem Ausgabeverzeichnis:

```sh
LUMO_PUZZLE_MENU_EVIDENCE_DIR=/tmp/lumo-puzzle-menu-check \
  python3 tools/run_local_renderer.py \
  --display 98 --output /tmp/lumo-puzzle-menu-check/renderer \
  --project . --timeout 300 -- \
  --resolution 960x540 --disable-vsync \
  --script res://scripts/tests/puzzle_menu_lifecycle_regression.gd -- --capture

python3 docs/evidence/puzzle-menu-followup-20261113/verify_renderer_result.py \
  /tmp/lumo-puzzle-menu-check
```

Der zweite Befehl ist erforderlich: Der ursprüngliche Fehler lässt Godot
trotz der nativen Fehlermeldungen mit Exit 0 enden. Der strikte Prüfer
akzeptiert weder solche Meldungen noch fehlende Bilder, Verhaltensfehler oder
Timeouts. Die beigelegten `before-*`/`after-*` sind historische Originalbelege;
der Prüfer arbeitet auf der vollständigen Verzeichnisstruktur eines frischen
Laufs.

## Grenzen und verworfene Probenvorstufe

Die erste eigene Probenfassung traf mit ihrer zu breiten Suche nach „Teile“
auch die Werkzeugleistenaktion „‹ Teile“. Diese Fassung wird nicht als
Rot-/Grün-Beleg verwendet. Vor dem akzeptierten Rotlauf wurde die Suche auf
Nachfahren des echten Menücontainers begrenzt; danach blieb die Probe bis
zum Grünlauf unverändert. Die Vorstufe bleibt getrennt unter dem in
`review.json` genannten Diagnosepfad erhalten.

Der Desktopzeiger wird vor dem ersten Touch in das X11-Fenster gesetzt,
damit dessen Eingabefokus tatsächlich aktiv ist. Ein begrenzter
`ensure_control_visible`-Helfer macht gegebenenfalls einen geclippten
Menüknopf sichtbar; ein neuer natürlicher Scrollgestentest wird damit nicht
behauptet. Dieser Nachweis ist weder ein Android-17-Test noch eine
Fold7- oder 60-FPS-Messung. Tastatur und Gamepad wurden hier nicht geprüft.
