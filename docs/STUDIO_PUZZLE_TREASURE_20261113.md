# LUMO Studio – Puzzle und Schatzsuche, 13.11.2026

## Herkunft und Umfang

Diese Änderungen wurden auf dem tatsächlich ausgecheckten Godot-Stand `ada5ed81ad62339f15289da62670c0a4f9f7f2b9` entwickelt. Die GitHub-Sicherung und PR-Zuordnung übernimmt der Integrator; dieser Bericht behauptet keinen eigenen Push. `main` wurde durch diesen Arbeitsbereich nicht verändert.

Bearbeitet wurden ausschließlich die unten gehashten Puzzle-/Schatzsuche-Quellen und ihre neuen Prüfskripte. Bestehende Kart-Geschwindigkeit, Extrem-Rivalen, Lasso, Original-Fuchs, Flutter-Lernprofile, Elternfreigaben und Belohnungsformeln wurden dabei nicht ersetzt.

## Puzzle: Vorher und neue tatsächliche Funktion

**Vorher:** Das native Puzzle-Atelier besaß echte, dicke Puzzleteile und präzises Raypicking, Dragging und Einrasten. Alle Teile hatten jedoch stets die richtige Orientierung. Weder Zustand noch UI noch Einrastregel enthielten eine Drehmechanik.

**Jetzt:** Im vorhandenen Startmenü ist zusätzlich der Modus „Drehpuzzle“ auswählbar. Das normale Bilderpuzzle bleibt erhalten. Im Drehmodus beginnen die Originalteile in unterschiedlichen Vierteldrehungen. Antippen und Loslassen behält die Auswahl; der mindestens 48 dp hohe Drehknopf dreht das echte 3D-Teil. Tastatur R führt dieselbe Aktion aus. Die Drehbewegung verwendet Quaternion-Interpolation. Einrasten und passendes Hover-Feedback verlangen sowohl korrekte Lage als auch richtige Orientierung. Ein am richtigen Ort liegendes Teil rastet mit der passenden Drehung ohne zusätzlichen versteckten Klick ein.

Hilfen wählen ein sichtbares Teil aus, zeigen seinen Platz und nennen erforderliche Vierteldrehungen. Die fünf vorhandenen Teilmengen und fünf Originalmotive bleiben erhalten. Das längere Modusmenü scrollt in kleinen Viewports, ohne Buttons unter 48 dp zu verkleinern. Die bestehenden Kinddateien, Ergebnis-IDs und Belohnungen bleiben gleich.

**Speicherbestand:** Version 1 bleibt gültig. `rotation_enabled` und `turn` sind additive optionale Felder; fehlende Werte bedeuten exakt das bisherige, nicht gedrehte Puzzle. Gebrochene/ungültige Winkel, gedrehte gesperrte Teile und ungültige Moduswerte werden vor Änderung des offenen Puzzles abgewiesen. Geprüft wurde echtes JSON-Encoding/Decoding, kein ausschließliches Dictionary-Roundtrip.

## Schatzsuche: Vorher und neue tatsächliche Funktion

**Vorher:** Sieben feste Stationen mussten streng in Listenreihenfolge besucht werden. Auch nach der Brücke war der Mondgarten wirkungslos, solange der Kristallplatz nicht zuerst abgeschlossen war. Die Welt besaß einen zentralen Weg und einen einzelnen Zielstern.

**Jetzt:** Nach dem Lösen der Brückenstation können Kristallwächter und Mondgarten in frei gewählter Reihenfolge besucht werden. Zwei echte, per MultiMesh instanzierte räumliche Wege und Wegweiser zeigen die Abzweigungen. Beide freigegebenen Ziele erhalten einen sichtbaren 3D-Zielstern. Die tatsächliche Nähe zum besuchten Ort bestimmt die Frage; die normalen Antwortbuttons verarbeiten dessen Lösung. Sobald ein Ziel erledigt ist, bleibt das andere aktiv. Das Schloss verlangt weiterhin beide Funde; die Truhe weiterhin den Schatzschlüssel. Frühes Überspringen, wiederholtes Einsammeln und Zusatzbelohnungen wurden nicht eingeführt.

**Speicherbestand:** Das alte `chapter` bleibt der längste vollständig gelöste lineare Präfix. Nach Garten-vor-Kristallen steht deshalb weiterhin `chapter=3`; der Gartenfund wird zusätzlich in `solved_clues` gespeichert. Alte Version-1-Spielstände ohne dieses Feld werden unverändert rekonstruiert. Neue Spielstände prüfen Schlüsselabhängigkeiten, Reihenfolge, doppelte/ungültige IDs und Widersprüche zum alten Präfix, bevor der offene Zustand ersetzt wird. Die ursprüngliche Ergebnis-ID und XP-/Sterneformel bleiben bestehen.

## Tatsächlich ausgeführte Prüfungen

Godot-Version: `4.6.3.stable.official.7d41c59c4`. Lokale Läufe verwendeten den Headless-Displaytreiber mit echten SceneTree-/Physics-Instanzen; sie sind keine GPU- oder Geräteleistungsnachweise.

| Prüfung | Tatsächlich beobachtetes Ergebnis | Rohprotokoll |
| --- | --- | --- |
| Neue Puzzle-Drehmechanik | PASS 4037 Prüfungen: alle Motive/Teilmengen, falsche Orientierung, abgeschlossene Teile, echte Raypicks, verbundener Drehknopf, JSON-Saves, kleine Menüs | `docs/evidence/studio-puzzle-20261113/puzzle_rotation_regression-headless.log` |
| Bestehende Puzzle-Erweiterung | PASS 1103 Prüfungen: bisherige Motive/Teilmengen, Spielstände und zwei durch Raypicking gespielte Runden | `docs/evidence/studio-puzzle-20261113/puzzle_expansion_regression-headless.log` |
| Bestehendes Touch-Layout | PASS 300 Prüfungen: tatsächliche dp-Umrechnung, Portrait, Fold, Android-Dichte; Puzzle und Bauwelt | `docs/evidence/studio-puzzle-20261113/creative_touch_layout_regression-headless.log` |
| Neue Erkundungsreihenfolge | PASS 87 Prüfungen: beide vollständigen Wege, reale Ortsfragen und Antwortbuttons, Touch-Stick/CharacterBody-Bewegung, alte und neue Saves, ursprüngliche Belohnung | `docs/evidence/studio-treasure-20261113/treasure_exploration_regression-headless.log` |
| Bestehende Schatzsuche | PASS: Kamera, Entdeckungen, Serienbonus, Speicher-/Belohnungskompatibilität | `docs/evidence/studio-treasure-20261113/treasure_island_regression-headless.log` |

Der erste neue Bewegungstest setzte nur die sichtbare Stickachse; der Stick glättet aber zum tatsächlichen Touchziel zurück. Dieser Test wurde deshalb auf echte `InputEventScreenTouch`-Press/Release-Ereignisse am Produktionsstick korrigiert. Die endgültige Prüfung bewegt den realen CharacterBody über die vorhandene Physik.

## Renderer und Grenzen

Für den zentralen echten Renderlauf vorbereitet:

- `PUZZLE_ROTATION_CAPTURE_DIR` mit `scripts/tests/puzzle_rotation_regression.gd`: Tisch, Orientierungsfehler, eingerastetes Teil, 640×360/412×915/840×760 und kleines scrollbares Menü.
- `TREASURE_EXPLORATION_CAPTURE_DIR` mit `scripts/tests/treasure_exploration_regression.gd`: freie Routenwahl, Garten zuerst und vollständiger Abschluss.

Zum Zeitpunkt dieses Berichts war lokal kein Displayserver für einen echten Godot-Rasterlauf verfügbar. Deshalb wird hier kein neues gerendertes Bild als bereits geprüft behauptet. Renderbilder, Android-APK, physische Fold7-Messung und 60-FPS-Nachweis sind vom Integrator getrennt zu bestätigen. Die bestehenden Memory-/4-Gewinnt-/Quizshow-Ansichten waren in der Bestandsaufnahme Flutter-CustomPainter-Ansichten; dieser Patch ersetzt sie nicht durch Godot. Er ist keine Vollabnahme aller Spiele.

## Quellstände per SHA-256

| Datei | SHA-256 |
| --- | --- |
| `scripts/creative/puzzle_state.gd` | `f0104403990e7cd9de815a39c7a3a2697b61997e9c0b5366c5303bdec4437e21` |
| `scripts/creative/puzzle_world.gd` | `6495f46bba959bbfcec3a9bb093a71f54aa1afc970280ce56da4bf4ddc95989e` |
| `scripts/tests/puzzle_rotation_regression.gd` | `b6edbb0bba1ac7c43819bc7ed55d2417aa6360f603d3ce53b0cd8da5ebecbf58` |
| `scripts/creative/treasure_state.gd` | `8a11898f66d1db922158d3169dd9ddcd7985bb7e3639c64fbfc60e3980064288` |
| `scripts/creative/treasure_world.gd` | `2232ee9120975e2880b0986ea285a6799c5dee1a0ff37e232c545061503ac76b` |
| `scripts/tests/treasure_exploration_regression.gd` | `2fff6b5359237626dbb402e46482aac0e15697491f8790ef0e6fb89d0ac00384` |
