# LUMO Kart: Werkstatt und dauerhafte Streckenziele

Geprüfter Ausgangsstand: PR #156, `1d5c5cb45a323228f627ec529e6ff1ddd86f1c57`.
Arbeitszweig: `chatgpt/lumo-nextgen-20261113`. Der produktive Main-Branch wird nicht verändert.

## Tatsächlicher Bestand

Kart besitzt bereits fünf erreichbare Modi: Einzelrennen mit zwei Runden und fünf Rivalen, Sternen-Cup über zwölf Strecken, Zeitfahren mit gespeichertem Geist, freies Training und die 90-Sekunden-Kristall-Arena. Alte `learn_cup`-Setups werden zum Sternen-Cup normalisiert. Es werden keine zusätzlichen fiktiven Modi behauptet.

| Strecken-ID | Vorhandene Produktionsumgebung | Geprüfte gemeinsame Anschlussstelle |
|---|---|---|
| `sonnenhafen` | Hafen, Brücken, Schanzen, Looping, Leuchtturm, Lasso-Ereignisse | `kart_world.gd`, Sonnenhafen-Module |
| `zauberwald` | Baumbibliothek, Pilzgärten, Samenlaternen | `nature_track_details.gd` |
| `bergwelt` | Himmelsinseln, Terrassen, Leuchtfeuer | `sky_fantasy_track_details.gd` |
| `holo_city` | Neon-Architektur, Stadtmarken, Gärten | `technology_track_details.gd` |
| `crystal_canyon` | Observatorium, Vermessungsbaken, Kristallformationen | `sky_fantasy_track_details.gd` |
| `jungle_temple` | Wissensruinen, Tempelbaken, bewachsene Torstürze | `nature_track_details.gd` |
| `candy_cloud` | Konditorei, Donut-Bauten, Wolkengärten | `sky_fantasy_track_details.gd` |
| `volcano_night` | Vulkanarchitektur und Gesteinsformationen | `technology_track_details.gd` |
| `winter_sprint` | Chalets, Laternen, verschneite Tannen | `sky_fantasy_track_details.gd` |
| `galaxy_ringway` | Raumfahrt-Bauten und räumliche Streckenmarken | `technology_track_details.gd` |
| `desert_drift` | Oasenpavillons, Sonnenbanner, Palmenbecken | `nature_track_details.gd` |
| `learning_lab` | Labor-Bauten, Streckenmarken und technische Gärten | `technology_track_details.gd` |

Diese Umgebungen waren bereits vorhanden. Dieser Patch behauptet keine Neugestaltung aller zwölf Strecken. Die Prüfung ergab eine wichtigere gemeinsame Spielmechanik-Lücke: Cup-Runden und Bestzeiten waren vorhanden, aber kein unabhängiger dauerhafter Zielpass pro Strecke und Kind. Die vorhandene Garage war bereits räumlich; Lumo blieb dort im Kart sitzen und die Vorschau unterstützte nur einen Finger.

## Neue produktiv angeschlossene Funktionen

- `kart_garage_service_station.gd`: Werkstatt mit räumlicher Auswuchtmaschine, Rad, Achse, Felge, sechs instanzierten Speichen und instanziertem Werkzeug. Die vorhandenen Materialfamilien werden wiederverwendet. Es gibt keine zusätzlichen Spielkollisionen.
- Der vorhandene Original-Lumo mit 65 Knochen steht in der Werkstatt neben seinem Kart. Seine vorhandenen Clips begrüßen das Kind und reagieren mit einer Zeigegeste auf die tatsächliche Fahrzeugauswahl. Der Darsteller bleibt bei Kartwechseln erhalten. Der sitzende Darsteller wird nur in dieser Werkstattansicht verborgen; die Fahrerinspektion und das Rennen behalten ihn.
- `kart_stage_pinch.gd` und `kart_spatial_menu.gd`: Zwei echte Touchkontakte verändern die Kameradistanz. Die gesamte Geste bleibt bis zum letzten Loslassen eingefangen; ein verbleibender Finger löst keinen Klick oder unbeabsichtigte Drehung aus. Ein neuer einzelner Finger dreht weiterhin das Kart. Abschnittswechsel setzen die Kamera auf vollständige Ansicht zurück. Fokusverlust löscht Eingaben und pausiert den Darsteller; reduzierte Animationen werden beachtet.
- `kart_track_pass.gd`: je Strecke und gewählter Schwierigkeit die Ziele **zwei Runden ins Ziel**, **Podiumsplatz**, **Sieg ohne Zurücksetzen**. Ein starker erster Lauf darf alle passenden Ziele erfüllen. Spätere schlechtere Läufe nehmen nichts weg. Alle drei Schwierigkeiten besitzen dieselben Ziele; eine Erhöhung des Schwierigkeitsgrads ist nicht erforderlich.
- `kart_island.gd`: echte abgeschlossene Einzelrennen und Cup-Rennen übergeben Distanz und 16 geordnete Tore an den Pass. Training, Arena, Zeitfahren, Abbruch, ungültige Zahlen und unvollständige Rennen zählen nicht. Ergebnisansicht und tatsächliche Weltwahl zeigen den Stand und das nächste Ziel. Kompakte Karten blenden diese notwendigen Informationen ausdrücklich ein.
- Pro Kind wird ausschließlich `user://kart_track_pass_<SHA256(childKey)>.cfg` atomar gespeichert. Die Kindidentität wird beim Eintritt festgehalten. Bestehende Sterne, Freischaltungen, Geister und Spielstände werden nicht migriert. Der Pass erzeugt keine Währung. Wiederholte Ergebnis-IDs zählen nicht erneut. Schreibfehler werden angezeigt; Speicherformate neuerer Versionen und Dateien mit falschem Besitzer werden nicht überschrieben.
- Das abschließende Resume-Audit zeigte, dass die vorhandene zentrale Rennsession keinen Kindbesitzer enthielt. Neue Sessions erhalten deshalb das zusätzliche Feld `track_pass_owner`; Versionsnummer und vorhandene Felder bleiben kompatibel. Das Fortsetzen bewahrt den ursprünglichen Besitzer. Ein fremdes Kind erhält keine Ziele aus dieser Session. Alte Sessions ohne Besitzer bleiben spielbar und erzeugen keine rückwirkend zugeordneten Passziele. Das nächste neu gestartete Rennen ist wieder regulär zugeordnet. Dies ändert nicht die vorhandene Renn- oder Sterneabrechnung.

## Tatsächlich ausgeführte Prüfungen

Godot `4.6.3.stable.official.7d41c59c4`, Linux, getrennte Test-Datenverzeichnisse. Die Tests unten liefen mit `--headless`; das ist ein Funktionsnachweis, kein Grafik- oder Android-Leistungsnachweis.

| Prüfung | Ergebnis | Aussage |
|---|---|---|
| `kart_track_pass_regression.gd` | PASS, 104 Prüfungen | Ziele aller 12×3 Kombinationen, echte Dateiablage/Neuladen, Profiltrennung, Idempotenz, ungültige Ergebnisse, Schreibfehler/Retry, Zukunftsformat, Originaldateien unverändert, tatsächliche Menüverbindung; zusätzliche produktive Save/Resume-Fixtures für gleiches Kind, fremdes Kind und Besitzer unbekannter Altstände |
| `kart_nextgen_garage_regression.gd` | PASS, 81 Prüfungen | Produktive Szeneninstanz, tatsächliche Touchauswahl, Originalfigur/Geste, Radbewegung, Pinch, frische Drehgeste, Fokuswechsel, reduzierte Animationen, sichtbare Ziele bei 1280×720, 412×915, 2400×1080 |
| `kart_player_full_route_regression.gd` | PASS | Zwei vollständige Sonnenhafen-Runden durch echte Touch-Stick-/Gas-/Bremseingaben; keine Positions- oder Fortschrittsinjektion |
| `kart_modes_regression.gd` | PASS | Bestehende Übergänge aller zwölf Cup-Runden, tatsächlicher 90-Sekunden-Arena-Lauf mit aktiver KI, Training, Torreihenfolge, Geister, Freischaltungen |
| `kart_spatial_menu_regression.gd` | PASS, 554 Prüfungen, 5/5 Formate | Bestehende Menü-, Auswahl-, Framing- und Touch-Verträge bleiben erfüllt |
| `kart_race_continuity_regression.gd` | PASS; enthaltene Handoff-Prüfung 10/10 | Nach der Besitzerkorrektur: Grafikwechsel, Speichern/Wiederöffnen, nächste Runde, Rivalenzustände, Altstände, Flugreset und bestehende Host-Ergebnisbestätigung |
| `kart_garage_presentation_regression.gd` | PASS, 66 Prüfungen | Bereits nach der Werkstatterweiterung geprüft; spätere Streckenpass-Anbindung wird durch die oben genannten neuen und vorhandenen Menütests geprüft |
| Baseline-Capture-Skript `--check-only` | Exit 0 | Syntax geprüft; keine Pixelaufnahme behauptet |

Die echte Zwei-Runden-Fahrt erreichte 16 geordnete Tore, acht Schanzen und acht Landungen, zwei Loopings, null Zurücksetzungen sowie einen Lasso-Fang und drei Ausweichvorgänge. Simulierte Rennzeit: 98,5167 Sekunden. Größter Positionsschritt: 0,714346 Meter bei 60-Hz-Physik. Platz sechs erhielt das passende erste Ziel; dieses wurde wirklich neu aus der Datei geladen. Ein anderes Testkind blieb bei null. Diese Simulationsrate ist **keine gemessene Bildrate auf einem Fold7**.

Logs, vollständige Fahrtelemetrie und Quellcode-Hashes stehen in `docs/evidence/nextgen-kart-20261113/`.

## Echte Grafikaufnahmen und verbleibende Abnahme

`kart_nextgen_garage_baseline_capture.gd` ist mit dem unveränderten PR-156-Code lauffähig und erzeugt sechs echte Vorher-PNGs: Garage und Fahrzeugauswahl in drei Formaten. `kart_nextgen_garage_regression.gd --capture` erzeugt zwölf Nachher-PNGs: Garage, Auswahlgeste, Zwei-Finger-Zoom und Streckenziele in denselben Formaten, ergänzt durch `capture.json` mit tatsächlichem Renderer und Draw-Calls. Beide Skripte verweigern Bildaufnahmen mit dem Headless-Displayserver. `LUMO_CAPTURE_DIR` überschreibt das Ausgabeziel.

Die echten Vorherbilder aus CI-Artefakt `14002364129` wurden in allen drei Formaten visuell geprüft. Sie bestätigen die bestehende räumliche Garage und den sitzenden Originalfuchs. Im Porträt liegt die Auswahl unter dem Kart, im Querformat links; der zentrale Raum bleibt sichtbar. Die Bilder liegen im QA-Artefakt unter `baseline-2017/garage/`.

Die lokale Umgebung verweigerte den X11-Socket. Deshalb sind neue Rendereraufnahmen über den nativen CI-X11-Lauf vorgesehen. Der erste integrierte Lauf stoppte vor diesem Capture an einer unabhängigen Jump-Prüfung. Zum Stand dieses lokalen Berichts sind noch keine neuen Rendererbilder visuell freigegeben. Es wird keine Gleichwertigkeit mit den hochauflösenden Referenzillustrationen behauptet. Android-APK, Fold7-Touchgefühl, CPU/GPU-Framezeiten, Temperatur, Speicher und 60 FPS müssen von der Integrations-/Geräteprüfung belegt werden. Der Patch bleibt bis dahin ein überprüfter Funktionskandidat.

Reproduktion, jeweils aus dem Godot-Projekt:

```sh
godot --headless --path . --script res://scripts/tests/kart_track_pass_regression.gd
godot --headless --path . --script res://scripts/tests/kart_nextgen_garage_regression.gd
godot --headless --path . --script res://scripts/tests/kart_player_full_route_regression.gd
godot --headless --path . --script res://scripts/tests/kart_modes_regression.gd
godot --headless --path . --script res://scripts/tests/kart_spatial_menu_regression.gd
godot --headless --path . --script res://scripts/tests/kart_race_continuity_regression.gd
xvfb-run -a godot --path . --rendering-method gl_compatibility --fixed-fps 60 --script res://scripts/tests/kart_nextgen_garage_regression.gd -- --capture
```

`--fixed-fps 60` fixiert ausschließlich die Simulationszeit der kurzen Animations-Capture-Probe, sodass ein langsamer Software-Renderer eine Geste nicht zwischen wenigen Prüfframes überspringt. Die Option ist kein gemessener Leistungswert.
