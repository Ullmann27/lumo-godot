# Native Lernwerkstatt – überprüfter Entwicklungsstand

Diese Arbeit erweitert die vorhandenen Flutter-Lektionen um eine tatsächlich
angeschlossene Godot-Szene. Sie ersetzt weder Lernprofil noch Bewertung,
Schreibtrainer, Journal oder Lesetrainer. Dieser Bericht ist keine visuelle,
Android- oder 60-FPS-Freigabe.

## Ausgangszustand und Anschluss

Die geprüfte Basis enthielt sieben geführte Konzepte im Flutter-Katalog mit
lokalen Illustrationen, Sprachbegleitung und begleiteter/selbstständiger
Aufgabenbewertung. Ein typisierter Start der jeweiligen konkreten Lektion in
einer interaktiven Godot-Lernszene war noch nicht angeschlossen.

`NativeLearningActivity` in `lumo-lernen` übersetzt jetzt die tatsächlichen
Operanden, Silben und Pflanzenteile des aktuellen Schritts. Derselbe Vertrag
öffnet unterstützte aktuelle Aufgaben aus `LearningContent`: Addition bis 20,
Subtraktion bis 20 und bekannte Silbenwörter. Unbekannte oder nicht begrenzte
Aufgaben behalten ihre vorhandene Darstellung; keine Ersatzaufgabe wird
erfunden. Die Addition unterstützt im jetzigen Modell Anfangsmengen bis zehn.

Die sichtbare Aktion heißt **Mit Lumo in 3D ausprobieren**. Bei geführten
Lektionen erscheint sie nur für einen gültigen konkreten Schritt. Im adaptiven
Lernen bleibt sie in Tests und Schularbeiten gesperrt. Der bestehende native
Start erfasst Kindidentität und Profilgeneration; ein veralteter Rücklauf wird
verworfen. Die Tagesmission sperrt weiterhin Spiele, nicht diese Lernhilfe.

## Tatsächliche Implementierung

| Lernmodell | Reale Darstellung und Interaktion |
| --- | --- |
| Zehnerübergang / Addition | Zwei räumliche Zehnerfelder; blaue Ausgangsmenge und goldene verschiebbare Würfel. Antippen oder Ziehen füllt zuerst zehn und anschließend das zweite Feld. |
| Subtraktion | Ausgangswürfel verlassen das Feld und sammeln sich auf einer getrennten Ablage. Beim Zehnerübergang werden zuerst die Würfel oberhalb zehn entfernt. Kein Objekt verschwindet als bloßer Zählerwechsel. |
| Gleiche Gruppen | Tatsächliche runde Ablagen und einzelne Würfel; jede Gruppe erhält dieselbe Anzahl. Bis zu sechs Gruppen mit je sechs Objekten. |
| Hunderterübergang | Jeder bewegliche, mit 10 beschriftete Block zählt einen Zehner. Vorhandene Hunderter bleiben als Stapel erhalten. Die aktuelle Menge wird aus bewegten Zehnern berechnet. |
| Bruchteile | Ein Ganzes mit zwei bis zwölf gleich großen räumlichen Segmenten. Markierte Teile und zusätzliche Teile bleiben bei unverändertem Nenner sichtbar. |
| Silben | Farbige Körper mit extrudierter TextMesh-Beschriftung. Das Kind setzt die tatsächlichen Silben des aktuellen Worts in ihrer Reihenfolge zusammen; falsche Zuordnung wird nicht akzeptiert. |
| Pflanzenteile | Eigenständige Meshes für Wurzeln, Stängel, Blätter und Blüte. Wasser und Licht verändern das sichtbare Wachstumsmodell; jeder Teil hat eine konkrete Erklärung. Dies ist ein vereinfachtes Lernexperiment, keine botanische Simulation. |

Produktive Dateien:

- `scenes/learning/learning_world.tscn`
- `scripts/learning/learning_world.gd`
- `scripts/learning/learning_activity.gd`
- Einträge in `scripts/app/scene_router.gd`, `scripts/app/app_boot.gd` und
  `scripts/systems/host_bridge.gd`

Alle Lernobjekte werden zur Laufzeit als echte 3D-Meshes erstellt. Gemeinsame
Materialinstanzen, begrenzte Geometrie, statische Beleuchtung und eine
orthografische Kamera halten den Aufwand überschaubar. Ein gemessenes
Framebudget ist damit noch nicht belegt. Die HUD-Aktionen sind mindestens
52 logische Pixel hoch. Das Layout berücksichtigt Android-Dichte und Insets,
Hoch-/Querformat sowie reduzierte Bewegung. Ein eigener Finger besitzt seinen
Drag; zweiter Finger, emulierte Maus und Loslassen über dem HUD können ihn
nicht falsch übernehmen oder hängen lassen.

## Original-Lumo und Stimme

Die Szene instanziert den vorhandenen `lumo_rigged_actor.gd` mit dem originalen
65-Knochen-Fuchs. Dessen neue Teacher-API folgt dem Lernobjekt und verbindet
Originalclips mit Begrüßung, Erklärung, Ermutigung, bestätigendem Nicken und
Jubel. Das Ziel wird beim Ziehen aktualisiert. Es gibt keine Behauptung über
neue Lippen-, Kiefer- oder Blinzelanimationen: Der Originalrig bietet dafür
keine belegten Morphs.

`LumoLearningSpeech.kt` im Flutter-Repository verwendet denselben vorhandenen
lokalen F2-Synthesizer wie `LumoOfflineSpeechBridge.kt`. Es gibt keinen
System-TTS-Ersatz, neuen Cloud-Anbieter oder Mikrofonzugriff. Native Sprache
setzt die vorhandene lokale Lizenzfreigabe, aktivierte Stimme und gewählte
Lumo-Frei-Identität voraus. Ruhemodus deaktiviert automatisches Vorlesen;
explizites Anhören bleibt bei erlaubter Stimme möglich. Die bestehende
Geschwindigkeit wird übernommen.

Der Android-Player liest fertige WAV-Daten aus einem `MediaDataSource` im
Speicher. Ein Status mit aktueller Äußerungs-ID wird erst beim tatsächlichen
MediaPlayer-Start zu `playing`; nur dieser Status löst die Sprechgeste aus.
Abbruch, neue Handlung, Hintergrundwechsel und Szenenende stoppen alte Sprache.
Verspätete Statusmeldungen passen nicht mehr zur aktuellen ID. Bei Ausfall
bleibt die echte Erklärung lesbar. Diese Implementierung ist angeschlossen;
reale Synthese und Wiedergabe müssen zusätzlich auf Android geprüft werden.

## Bewertung und Bestandsschutz

Die Godot-Szene schreibt keine Kinderprofile, Aufgabenresultate, Sterne oder
Kompetenzwerte. Rückkehr sendet `status: illustrated`, niemals `completed`.
Die Flutter-Lektion markiert die angeforderte Darstellung als Hilfe, bevor sie
startet: Eine unterbrochene Rückkehr kann später keinen vermeintlich
selbstständigen Erfolg erzeugen. Die vorhandene Aufgabe, Antwortprüfung,
Fortschrittsspeicherung und Profileigentümerschaft bleiben zuständig.

## Ausgeführte Prüfungen

- `godot --headless --path . --script res://scripts/tests/learning_world_regression.gd`:
  **4123 Prüfungen bestanden**. Exhaustive begrenzte Subtraktion/Gruppen/Brüche,
  Mengeninvarianz, native JSON-Grenzen, Originalfuchs, echte Szenenknoten,
  Touch/Drag, mehrere Layoutgrößen, Lebenszyklus und Sprachstatus-Staleness.
- Flutter: **63 Tests bestanden** über neuen nativen Lernstart, vorhandenen
  Launcher-Lebenszyklus, geführte Lektionen, Deutsch/Natur sowie bestehende
  adaptive Aufgaben-/Belohnungs-/Prüfungsabläufe. Native MethodChannel-Antworten
  sind dabei Testdoubles, kein Nachweis einer gestarteten Android-Engine.
- Flutter-Analyse der sechs geänderten Lern-/Launcher-/Testdateien:
  **keine Befunde**.
- Android-Hostvorbereitung: **4 Tests bestanden**, einschließlich Kopieren der
  echten neuen Kotlin-Datei unter alternativen Paketnamen. Kein Ersatz für
  eine echte Android-Kompilierung.
- Tatsächlicher Android-Host-Compile von Snapshot
  `2d36496d5ed3684d52dab633b6e9a5d24cef0456`: CI-Lauf `43351542336`, Job
  `131643514999` erfolgreich; `compileDebugKotlin` und
  `compileDebugJavaWithJavac` mit realem Godot 4.6.3 und ONNX 1.23.1.
  Der finale Release-Build muss die späteren Lebenszyklus-/Sichtbarkeitskorrekturen
  erneut kompilieren. Dieser Debug-Compile beweist weder hörbare Wiedergabe noch
  eine veröffentlichte APK.

Reale Logs liegen in den jeweiligen Repositories unter
`docs/evidence/nextgen-learning-20261113/`.

## Noch zu belegende Abnahme

`scripts/tests/learning_world_capture.gd` fordert einen echten Renderer und
verweigert Headless-Erfolg. Es erzeugt 21 aktuelle Aufnahmen: Addition in drei
Displaygrößen sowie Silben, Pflanze, Subtraktion, Gruppen, Hunderter und Brüche
vor/nach echten Touch-Aktionen. Der vorhandene CI-Collector führt es aus.
Lokale X11-Sockets waren in dieser Umgebung blockiert; dieser Bericht enthält
deshalb keine erfundene visuelle Freigabe.

Zusätzlich erforderlich: integrierter Release-APK-Build mit genau dieser
Godot-PCK und aktuellem Host, native Touch-/Rückkehr-Tour,
hörbare Originalstimme mit erlaubten Einstellungen und Stopp bei Appwechsel.
Fold7-Messwerte für Framezeiten, Temperatur und Touch-Latenz sind offen.
Die endgültigen Commit-SHAs, PRs, Rendererartefakte und APK-Provenienz ergänzt
die übergeordnete Integration nach dem tatsächlichen Checkpoint und Build.
