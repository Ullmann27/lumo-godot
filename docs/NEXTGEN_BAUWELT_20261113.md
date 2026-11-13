# Bauwelt und native Kreativspiele – geprüfter Entwicklungsschnitt

Stand: 13. November 2026. Ausgangspunkt Godot PR #156, Commit `1d5c5cb45a323228f627ec529e6ff1ddd86f1c57`. Der gemeinsame Entwicklungsbranch wird vom Integrationsverantwortlichen gesichert; dieser Bericht behauptet keine Veröffentlichung auf Main.

## Tatsächlicher Ausgangspunkt

| Modul | Bereits vorhanden | Qualitätslücke dieses Schnitts |
| --- | --- | --- |
| Bauwelt | 41 echte 3D-Bauteile, 49×49 Rasterzellen, maximal 1536 Teile, sechs Projekte je Kind, Haus/Turm/Burg/Dorf/Brücken-Aufträge, Grundstützprüfung, Undo/Redo, Füllen/Kopieren/Spiegeln | Bestehende Teile waren nicht als einzelne Objekte versetzbar/drehbar; die eigene Konstruktion war nicht mit dem Original-Lumo begehbar. Keine Ressourcenwirtschaft oder fairer KI-Wettbau. |
| Puzzle | Fünf Originalmotive; 6/12/24/48/96 Teile; geometrische Puzzleformen, Drag/Snap, gespeicherter Spielstand | Bestehende Schwierigkeit und Ziele bleiben erhalten; kein neuer Kampagnenpfad in diesem Schnitt. |
| Rhythm Party | Vier Originallieder, drei Timingfenster, Tap/Hold/Slide/Star, Combo-Boni, 3D-Bühne und Bestwerte | Lieder teilen das grundlegende 40-Noten-Muster; keine neue Tour/Kampagne in diesem Schnitt. |
| Schatzsuche | Begehbare Insel, sieben ortsgebundene Hinweise, Inventar- und Torregeln, drei Nebenentdeckungen, gespeicherte Kapitel | Eine Insel/Kampagne; keine zusätzlichen Welten in diesem Schnitt. |

Puzzle, Rhythm Party und Schatzsuche wurden inventarisiert und ihre bestehenden Regressionen erneut ausgeführt. Sie erhalten durch diesen Bauwelt-Schnitt keine behauptete neue Grafik oder Mechanik.

## Neue produktive Funktionen

### Freies Bauen

- `scripts/creative/build_state.gd`: bestehendes Teil über unveränderte UID atomar versetzen/drehen. Volumenprüfung und Boden-erreichbarer Stützgraph verhindern Überlappung, schwebende neue Bauteile und abgetrennte Aufbauten. Ein erfolgreicher Vorgang ist genau ein Undo-Schritt; abgelehnte/identische Vorgänge verändern weder IDs noch Historie. Bereits gespeicherte, ungestützte Altteile werden nicht nachträglich entfernt.
- `scripts/creative/build_world.gd`: native Aktion **Verschieben**, echte Raycast-Auswahl, geometrische Vorschau, Raster und Drehung. Antippen oder Ziehen setzt das Originalteil um. Abgebrochene Fingerereignisse bauen nichts; Maus-Emulation kann den echten Touch nicht überschreiben.
- `scripts/creative/build_explorer.gd`: **Mit Lumo laufen** verwendet das vorhandene Originalmodell mit 65 Knochen, seine Animationen und das gemeinsame Bewegungssignal aus Team B. Beschleunigung, Bremsung, Bodenkontakt, echte Kollisionen, variable Sprunghöhe, Puffer, Kanten-Toleranz, sichere Rückkehr sowie eine kollisionsgeprüfte Folgekamera sind in der tatsächlichen Bauwelt angeschlossen.
- Unabhängiger linker Stick und rechter Sprungknopf erlauben zwei Finger gleichzeitig. Pause löscht gehaltene Eingaben. Die Rückkehr zum Bauen bewahrt Kamera und Konstruktion.
- Bestehende freie JSON-Spielstände bleiben Version 1. Siedlungsbesuche kehren zum gewählten Projekt-Slot zurück.

### Siedlung und Wettbau

Erreichbar über **Bauwelt → Siedlung** beziehungsweise **Bauwelt → Wettbau**, mit eigener Godot-Szene `scenes/creative/build_settlement_world.tscn`. Es sind begrenzte, spielbare Aufbauvarianten; kein vollständiger Minecraft-Ersatz.

- `scripts/creative/build_settlement_world.gd`: Grundstück per Raycast auswählen, Gebäude über seinen tatsächlichen Rohstoffpreis kaufen, Tageswechsel bewusst auslösen, Handel, Erweiterung, Undo/Redo, Ziele, Vorräte und Bewohner verfolgen. Kein Zeitablauf im Hintergrund und keine Offline-Produktion.
- Sechs nutzbare Gebäude: Wohnhaus, Bauernhof, Holzwerkstatt, Steinbruch, Marktplatz und Lernhaus. Das gemeinsame Regelmodell `build_settlement_state.gd` gehört zur Integration; Oberfläche und Nachbar benutzen genau dessen öffentliche Aktionen und Preise.
- Drei Regionen mit 9 → 16 → 25 Grundstücken und mehreren Versorgungs-/Bevölkerungs-/Bildungszielen. Die bestehende Anordnung bleibt beim Erweitern stabil.
- Wettbau zeigt die tatsächlich bezahlten Gebäude der KI-Nachbarin auf der anderen Flussseite. Ihre Kosten, Produktion, Nahrung und Erweiterungsbedingungen stammen aus denselben Regeln. Der Waschbär ist ein vorhandener Lumo-Begleiter.
- `scripts/creative/build_settlement_visual.gd` verwendet und kombiniert die Original-Bauwelt-Geometrie. Wiederholte Gebäude teilen nach Material zusammengefasste Meshes; sichtbare Bauten haben echte Kollisionen.
- Original-Lumo kann auch die beiden Siedlungsufer und die Brücke begehen.
- Eigene atomare Datei pro Kind, Slot und Variante: `lumo_settlement_<kind>_<slot>_<modus>.json`. Der Wrapper prüft Version, Kind, Slot und Modus sowie das vollständige Regelmodell. Beschädigte oder zu einem anderen Kontext gehörende Dateien werden nicht überschrieben; eine sichere Rückkehr zur Bauwelt bleibt möglich. Freie Bauwelt-Daten werden nicht migriert oder mit wirtschaftlichen Kosten belastet.

## Tatsächlich ausgeführte Prüfungen

Auf Godot **4.6.3** unter Linux. Alle unten als bestanden bezeichneten Läufe sind Headless-Prüfungen, keine Screenshots und kein Android-FPS-Nachweis. Logs: `docs/evidence/nextgen-bauwelt-20261113/`.

| Prüfung | Ergebnis / Aussage |
| --- | --- |
| `build_transform_regression.gd` | 38 Prüfungen bestanden: Identität, Drehung, atomare Ablehnung, Stützgraph, Undo/Redo und bisherige V1-Vorlagen. |
| `build_nextgen_play_regression.gd` | 62 Prüfungen bestanden: tatsächliche InputEvent-Berührung, Auswahl/Versetzen/Drehen/History/Disk-Save, Originalrig, reale Wandkollision, kurze/lange Sprungbahn, Landung, zwei Finger, Pause und drei Bildschirmformate. |
| `build_settlement_play_regression.gd` | Tatsächlicher Szenenwechsel, Touch-Grundstücke und Kaufbuttons, genaue Ressourcen, sichtbare KI-Bauten, Tageswechsel, getrennte Saves, beschädigte Dateien, Slot 3, Pause und drei Bildschirmformate. Letzter exakter Prüfungszähler steht im zugehörigen Log. |
| `build_nextgen_play_regression.gd -- --negative-control` | Erwarteter Exit 1: Deaktivieren des produktiven Verschieben-Knopfs wird erkannt. |
| `build_sandbox_ui_regression.gd` | Bestanden: bisherige Werkzeuge und atomarer Undo-Workflow. |
| `build_sandbox_tools_regression.gd` | Bestanden: bisheriges Füllen/Kopieren/Spiegeln und Speicherung. |
| `creative_touch_layout_regression.gd` | 300 Prüfungen bestanden: 48-dp-Ziele, Portrait, Fold und Density. |
| `puzzle_expansion_regression.gd` | 1103 bestehende Prüfungen bestanden: Motive/Teilzahlen/Saves/zwei gespielte Runden. Kein Beweis für eine neue Puzzle-Funktion. |
| `rhythm_party_regression.gd` | Bestehende Lieder/Combo-/Save-/Reward-Prüfungen bestanden. |
| `treasure_island_regression.gd` | Bestehende Entdeckungs-/Kamera-/Save-/Reward-Prüfungen bestanden. |

Die produktiven Tests haben echte Fehler entdeckt und deren Behebung überprüft: emulierte Mausereignisse überschrieben die Objekt-Touch-Auswahl; eine noch nicht vermessene automatisch umbrechende HUD-Zeile verschob Kaufbuttons außerhalb des Displays; JSON-IDs von Siedlungsgebäuden dürfen nicht numerisch zusammenfallen. Die Eingabeprüfung verlässt sich nicht allein auf direkte Modellaufrufe.

## Renderer-Evidenz und Grenzen

Die folgenden beiden Tests besitzen `--capture` und erfordern einen tatsächlichen Renderer sowie `LUMO_CAPTURE_DIR`. Sie verweigern die Screenshot-Ausgabe im Headless-Modus.

- Bauwelt: `01_build_selection.png`, `02_build_moved.png`, `03_build_walking.png`, `04_build_jump.png`.
- Siedlung: `01_settlement_start.png`, `02_settlement_purchases.png`, `03_settlement_rival_day.png`, `04_settlement_lumo.png`.

Der lokale X11-Zugriff ist in dieser Sitzung blockiert. Echte Bilder werden über die zentrale Renderer-CI erzeugt und müssen anschließend visuell geprüft werden. Bis dahin ist die visuelle Abnahme offen. Es liegt aus diesem Agenten kein Fold7-/Android17-Gerätetest, keine thermische Messung, keine GPU-Zeit und kein 60-FPS-Nachweis vor. APK, GitHub-Commit, PR und finaler CI-Befund werden zentral im Integrationsbericht ausgewiesen.
