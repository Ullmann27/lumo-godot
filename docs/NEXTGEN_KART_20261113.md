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
| `kart_nextgen_garage_regression.gd` | PASS, 93 Prüfungen | Produktive Szeneninstanz, tatsächliche Touchauswahl, Originalfigur/Geste, Radbewegung, Pinch, frische Drehgeste, Fokuswechsel, reduzierte Animationen, sichtbare Ziele bei 1280×720, 412×915, 2400×1080; zusätzlich vollständige Rad-Einpassung, getrennte projizierte Kopf-/Rad-Silhouetten anhand des echten GLB-Head-Knochens und vollständig sichtbare erste Weltkarte nach Abschnittswechsel |
| `kart_player_full_route_regression.gd` | PASS | Zwei vollständige Sonnenhafen-Runden durch echte Touch-Stick-/Gas-/Bremseingaben; keine Positions- oder Fortschrittsinjektion |
| `kart_modes_regression.gd` | PASS | Bestehende Übergänge aller zwölf Cup-Runden, tatsächlicher 90-Sekunden-Arena-Lauf mit aktiver KI, Training, Torreihenfolge, Geister, Freischaltungen |
| `kart_spatial_menu_regression.gd` | PASS, 554 Prüfungen, 5/5 Formate | Bestehende Menü-, Auswahl-, Framing- und Touch-Verträge bleiben erfüllt |
| `kart_race_continuity_regression.gd` | PASS; enthaltene Handoff-Prüfung 10/10 | Nach der Besitzerkorrektur: Grafikwechsel, Speichern/Wiederöffnen, nächste Runde, Rivalenzustände, Altstände, Flugreset und bestehende Host-Ergebnisbestätigung |
| `kart_garage_presentation_regression.gd` | PASS, 66 Prüfungen | Bereits nach der Werkstatterweiterung geprüft; spätere Streckenpass-Anbindung wird durch die oben genannten neuen und vorhandenen Menütests geprüft |
| `kart_lasso_production_regression.gd` | PASS, 26 Prüfungen | Alle 24 bisherigen echten Bewegungs-/Lasso-Aussagen plus beobachtete tatsächliche Audio-Playbacks und bestätigte Freigabe sämtlicher WeakRefs vor Prozessende |
| `kart_audio_regression.gd` | PASS | Bestehende Lautstärke-/Speichertests plus tatsächlicher Track/Crossfade/Effekt, vollständige Streamfreigabe beim Szenenaustritt und erneutes Abspielen desselben Tracks nach Wiedereintritt |
| Baseline-Capture-Skript `--check-only` | Exit 0 | Syntax geprüft; keine Pixelaufnahme behauptet |

Die echte Zwei-Runden-Fahrt erreichte 16 geordnete Tore, acht Schanzen und acht Landungen, zwei Loopings, null Zurücksetzungen sowie einen Lasso-Fang und drei Ausweichvorgänge. Simulierte Rennzeit: 98,5167 Sekunden. Größter Positionsschritt: 0,714346 Meter bei 60-Hz-Physik. Platz sechs erhielt das passende erste Ziel; dieses wurde wirklich neu aus der Datei geladen. Ein anderes Testkind blieb bei null. Diese Simulationsrate ist **keine gemessene Bildrate auf einem Fold7**.

Logs, vollständige Fahrtelemetrie und Quellcode-Hashes stehen in `docs/evidence/nextgen-kart-20261113/`.

## Echte Grafikaufnahmen und verbleibende Abnahme

`kart_nextgen_garage_baseline_capture.gd` ist mit dem unveränderten PR-156-Code lauffähig und erzeugt sechs echte Vorher-PNGs: Garage und Fahrzeugauswahl in drei Formaten. `kart_nextgen_garage_regression.gd --capture` erzeugt zwölf Nachher-PNGs: Garage, Auswahlgeste, Zwei-Finger-Zoom und Streckenziele in denselben Formaten, ergänzt durch `capture.json` mit tatsächlichem Renderer und Draw-Calls. Beide Skripte verweigern Bildaufnahmen mit dem Headless-Displayserver. `LUMO_CAPTURE_DIR` überschreibt das Ausgabeziel.

Die echten Vorherbilder aus CI-Artefakt `14002364129` wurden in allen drei Formaten visuell geprüft. Sie bestätigen die bestehende räumliche Garage und den sitzenden Originalfuchs. Im Porträt liegt die Auswahl unter dem Kart, im Querformat links; der zentrale Raum bleibt sichtbar. Die Bilder liegen im QA-Artefakt unter `baseline-2017/garage/`.

Der native CI-X11-Lauf des exakten Commits `d66aaebf9185e8b86d9d09d8a66149860239c6e2` erzeugte zwölf echte Nachherbilder mit `gl_compatibility`; die Capture-Prüfung bestand dort 106 Prüfungen. Alle zwölf PNGs wurden visuell geprüft. Sie zeigen den stehenden Originalfuchs neben dem Kart, die Reaktion auf den Wechsel zu Gecko Velo, echte Kameravergrößerung und lesbare Streckenziele. Der Code dieses Capture-Laufs war laut `source-dirty.txt` unverändert.

| Tatsächliche Rendererprobe | 1280×720 | 412×915 | 2400×1080 |
|---|---:|---:|---:|
| Garage, Draw-Calls | 194 | 156 | 199 |
| Fahrzeugauswahl, Draw-Calls | 191 | 153 | 196 |
| Kamerazoom, Draw-Calls | 184 | 175 | 191 |
| Vorhandene ganze Streckenvorschau, Draw-Calls | 677 | 640 | 647 |

Diese Bilder deckten zwei konkrete Mängel auf: Die zusätzliche Radmaschine lag hinter der linken Auswahl, und bei der großen Pixeldichte wurde der erste Weltname durch die übernommene Scrollposition angeschnitten. Die Maschine steht deshalb jetzt auf der sichtbaren Werkstattseite und ihre acht Geometrieecken fließen in das Kamera-Framing ein. Abschnittswechsel setzen den Auswahl-Scroll zurück. Der nachfolgende CI-Commit `096c9d20a3a1b92605e0a4f648e1afd87f967b9a` bestand 112 gerenderte Prüfungen und lieferte zwölf neue PNGs. Sechs repräsentative Bilder in allen drei Formaten wurden erneut geprüft: Der erste Weltname ist vollständig sichtbar und die Radmaschine erscheint. Sie überlagerte perspektivisch noch Lumos Kopf. Deshalb wurden ausschließlich die vorhandenen Maschinen-Meshes weiter seitlich/vor den Schrank gesetzt. Die abschließende Fassung besteht 93 neue Headless-Prüfungen einschließlich getrennter projizierter Kopf-/Rad-Silhouetten; **frische Pixel für diese letzte Positionskorrektur stehen noch aus**. Ältere Bilder werden nicht als Nachweis dieser späteren Korrektur ausgegeben.

Die vollständigen PNGs liegen im QA-Artefakt unter `baseline-2017/garage/` und `nextgen/captures/kart_nextgen_garage_regression/`. `docs/evidence/nextgen-kart-20261113/renderer-d66aae.json` enthält ihren exakten Quellcommit, ihre SHA256-Hashes und die gemessenen Capture-Daten. Die folgende Fassung ist separat in `renderer-096c9d.json` belegt: 176–205 Draw-Calls in der Garage, unverändert 640–677 in der Streckenvorschau. Die lokale Umgebung verweigerte den X11-Socket; lokal entstanden keine Rendererbilder. Es wird keine Gleichwertigkeit mit den hochauflösenden Referenzillustrationen behauptet. Android-APK, Fold7-Touchgefühl, CPU/GPU-Framezeiten, Temperatur, Speicher und 60 FPS müssen von der Integrations-/Geräteprüfung belegt werden. Die relativ teure vorhandene Streckenvorschau bleibt ein konkreter Messpunkt für das Gerätebudget.

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

## Nachprüfung des Audio-Lebenszyklus

Der integrierte CI-Lauf `096c9d20` scheiterte nach seinen 24 Lasso-Spielprüfungen an einer ObjectDB-/Resource-Warnung. Drei lokale unveränderte Läufe mit `--verbose` reproduzierten diese Warnung nicht. Es wird daher keine lokal bewiesene Ursachenidentität behauptet.

Der produktive `kart_audio.gd` beendet beim Austritt nun den Crossfade, löst jede `Player.stream`-Referenz und leert Streamcache und aktuelle Trackkennung. Ein echter Wiedereintritt kann damit denselben Track wieder starten. Der neue Testnachweis prüft dies ausdrücklich. Der Lasso-Test beobachtet außerdem tatsächliche Audio-Playback-Instanzen mit WeakRefs; er beendet den Prozess erst nach ihrer Freigabe und schlägt nach einer festen 3-Sekunden-Deadline mit den konkreten verbleibenden Typen fehl. Das ersetzt die frühere pauschale 0,1-Sekunden-Wartezeit. Alle bisherigen Lasso-Aussagen und das strenge Resource-Loggate bleiben erhalten.

Der lokale Lauf bestand 26 Prüfungen ohne Leak-/Resource-Fehler. Ein neuer vollständiger nativer CI-Lauf ist weiterhin erforderlich. Godots [bestätigter Audio-Shutdown-Issue #76745](https://github.com/godotengine/godot/issues/76745) beschreibt asynchron zurückgehaltene Playbacks als eine mögliche Ursache dieser Warnklasse; der konkrete 096-Lauf nennt ohne Verbose jedoch keine geleakten Klassen.
