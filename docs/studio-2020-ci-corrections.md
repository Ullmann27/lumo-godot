# Studio 2020: Korrekturen des ersten gemeinsamen Native-Laufs

Ausgangspunkt ist der veröffentlichte Commit `8be3a95d5d948d457c4c39bc6694138d60b70027`, Tree `9edd7afed143c83fec5d2dc89949ca9325e042ce`. Sein vollständiger Studio-Lauf [43561885899](https://github.com/Ullmann27/lumo-godot/actions/runs/43561885899) ist fehlgeschlagen. Learning Preview sowie Touch Treasure, Workshop und Build bestanden; Gameplay und Studio scheiterten. New Worlds, Bundle und Archivierung wurden deshalb übersprungen. Dieser fehlgeschlagene Lauf wird nicht nachträglich als bestanden bezeichnet.

## 1. Kanonische Importdatei

Der zusätzliche Stage-2-Lauf meldete nach dem Import einen veränderten Quellbaum. Ein tatsächlicher Godot-4.6.3-Import der Gesichtsdatei reproduzierte die Ergänzung fehlender Standardfelder im vorhandenen Eyelids-Unterobjekt. Eine unabhängige Prüfung aller 1.185 gebundenen Dateien des privaten Runtimebaums fand ausschließlich diese Importdatei als durch den Import veränderte Eingabe.

Die Korrektur übernimmt genau die von Godot erzeugten Felder in `assets/characters/lumo_facial/Lumo-Facial-Mobile.glb.import`. Das GLB, die Originalassets und die ausdrücklich gesetzte Lid-LOD-Einstellung bleiben unverändert. Ein zweiter tatsächlich erzwungener vollständiger Import ließ die kanonische Datei bytegleich.

## 2. Getrennte Identität von Original und Gesichtsableitung

`lumo_attention_landing_regression.gd` verglich bisher den Hash des aktiven Modells mit dem Hash des unveränderten ursprünglichen GLB. Seit der ausdrücklich ausgewählten Gesichtsableitung waren dies unterschiedliche Dateien. Der tatsächliche Fehler wurde lokal mit 1.843 Prüfungen und einem Fehler reproduziert.

Der Test prüft nun vier konkrete Bedingungen: den ursprünglichen Modellpfad, dessen unveränderten SHA-256, den ausdrücklich ausgewählten Pfad der Gesichtsableitung und deren eigenen SHA-256. Die übrigen 1.842 Prüfungen für Bewegung, Handkontakt, Kopfbewegung, Landung, Pause und Aufräumen bleiben erhalten. Der korrigierte gezielte Lauf bestand 1.846 Prüfungen ohne Fehler. Gemessener Handkontakt und Landespitze blieben in diesem Test identisch.

Dies ändert keine produktive Fahr- oder Charakterlogik. Der originale Modellschutz bleibt bestehen.

## 3. Tatsächliche Filmmaße vor dem Start von MovieMaker

Der originale CI-Film hatte H.264-Video, AAC-Ton und 148 Bilder, wurde jedoch mit den produktiven Projektmaßen von 720 × 1280 statt mit den vorgeschriebenen 640 × 640 Pixeln geschrieben. Die vorhandene CLI-Fensterauflösung änderte die von MovieMaker zuvor ausgewählte Zielgröße nicht.

Die Korrektur setzt ausschließlich im Capture-Skript `lumo_facial_capture.gd` beide MovieMaker-Fenstermaße früh in `_init()`. `project.godot`, produktive Szenen, Assets und `tools/validate_studio.sh` bleiben unverändert. Die Rosterprüfung verlangt weiterhin 640 × 640, die gleiche Aufnahmerate, vollständige Frame-/Audio-/Hashnachweise und die tatsächlichen Mimikzustände. Eine zusätzliche negative Testvariante weist das originale falsche Hochkantformat weiterhin zurück.

Ein neuer tatsächlicher Film unter den unveränderten produktiven Projektdefaults wurde mit H.264, 640 × 640 Pixeln, 148 vollständig decodierten Bildern und AAC erzeugt. Der unveränderte vollständige Film-/Gesichtsprüfer akzeptierte diese Originaldateien. Acht neue Standbilder und alle 148 decodierten Frames wurden über 13 indexierte Kontaktbögen betrachtet. Die 13 einschlägigen Pythonfälle bestanden ohne Skip. Ein zuvor fehlender unveränderter Workflow in der isolierten Testkopie verursachte einen Setupfehler; dessen Rohlog bleibt neben dem anschließenden vollständigen erfolgreichen Lauf erhalten.

Die 24 Bilder pro Sekunde sind das Aufnahmeformat. Sie belegen keine Geräte-FPS. Die dezente Kieferbewegung bleibt amplitudenbasiert; eine phonemgenaue Lippenanimation wird nicht behauptet.

## Neue gemeinsame Abnahme

Diese vier Quellkorrekturen und dieses Dokument werden gemeinsam veröffentlicht. Die gezielten lokalen Ergebnisse ersetzen keinen neuen vollständigen Native-Lauf. Erst ein erfolgreicher Lauf am tatsächlichen Folgecommit samt Sichtprüfung seiner Originalbilder darf den neuen Hostpin freigeben. Android, Update und APK-Veröffentlichung bleiben danach eigene verpflichtende Prüfungen. Main und der bisherige Studio-2019-Branch bleiben unverändert.
