# cce-Grafikcheckpoint: PR 160, Lauf 43474541178

Dieser unveränderlich zugeordnete Quellencheckpoint gehört ausschließlich zu Native ccebbe24b489ba7971c605a2bc5187fcfea26f9e / Tree 8409dc27958dc102d7fc84b413f28642782668aa. Der Pull-Request-Lauf, Versuch 1, endete erfolgreich; Home, Worlds und Feedback waren jeweils SUCCESS. Der spätere Puzzle-Folgehead wird damit nicht abgenommen.

## Inhalt und Herkunft

original enthält alle gesicherten originalen REST-Metadaten, die vollständigen drei Joblogs, den eingefrorenen Handoff, die unveränderten Analyseberichte und die tatsächlichen fünf Root-Bildbeobachtungen. Der frühere Dreier-Sichtungsbeleg bleibt als chronologische Teilbeobachtung unverändert erhalten. Die fünf späteren Beobachtungen sind maßgeblich. Originale JSON-Dateien wurden nicht neu serialisiert; komprimierte Dateien werden unverändert zurückgewonnen.

artifact-logs enthält alle 40 vollständigen .log-Dateien aus den drei Originalarchiven, einschließlich Import-, Baseline- und Engineprotokollen. Namen mit Unterverzeichnissen wurden für diesen Pack abgeflacht; das Manifest nennt zu jeder Datei den exakten Original-ZIP-Pfad. Die drei vollständigen Joblogs sind die unveränderten vom Connector gelieferten UTF-8-Logtexte, keine Behauptung originaler HTTP-Transportbytes. original-artifacts bewahrt Quellenstempel, Bildmanifeste, Harness-Bindungen und Captureberichte.

archive-index.json bindet die drei originalen ZIP-Dateien an GitHub-Artefakte, Run und Source. raster-index.json enthält alle 62 originalen PNG-Identitäten: 36 aktuelle und 26 historische Baselinebilder. zip-entry-hashes.json.gz indexiert sämtliche 2487 regulären ZIP-Einträge, einschließlich nicht kopierter Laufzeit-Caches. Die unveränderten ZIP- und PNG-Payloads bleiben im ursprünglichen Scratch-Verzeichnis; dieser Pack dupliziert keine Binärarchive, Bilder oder Cachebäume.

## Prüfumfang

Vor dem Packen wurden alle 191 Hashbindungen des eingefrorenen Originalpakets erneut verglichen. Alle drei ZIP-Digests und Bytezahlen entsprechen den originalen GitHub-Artefaktobjekten. Sämtliche ZIP-Mitglieder wurden vollständig gelesen und gehasht; gesicherte Logs, Raster und Metadaten entsprechen den Originalbytes. Der ursprüngliche Decoder-Nachweis umfasst PNG-Signatur/IHDR, Image.verify und vollständiges Image.load für alle aktuellen und Baselinebilder. Das Packen startete keine neuen Engine-, Renderer- oder Regressionstests.

Der aktuelle Feedbacknachweis ist der tatsächlich gerenderte PASS mit 75 Prüfungen einschließlich des veröffentlichten Loop-Fixes und der Freigabe dreier echter Audio-Playbacks. Ein älterer lokaler Headless-PASS 56 wird nicht zu diesem Lauf umetikettiert. Im getrennten cce-Nextgen-Gameplay wurde durch dessen zuständigen Agenten kein separater Feedback-Headless-Marker gefunden; dieser Pack behauptet keinen solchen Nachweis.

Die originale Projektvalidierung meldet je Job 117 PASS, 7 WARN und 0 FAIL; die sieben Warnungen bleiben vollständig im Handoff und in den Logs erhalten. Alle 40 gesicherten Engine-/Gatelogs sind nach dem ursprünglichen strengen Fehlercheck sauber.

## Grenzen

Root hat genau fünf aktuelle Originalbilder geöffnet: Home 1280×720, Home 412×915, Winter-Landmark, Crystal-Landmark und Drift-Release. Diese tatsächlichen Beobachtungen stehen unverändert in original/root-current-five-viewed.json. Weder die Prüfung übriger PNG-Bytes noch ein erfolgreicher Renderer ersetzt eine Bildsichtung.

Die Worlds-Bilder sind stationäre Produktionsszenen mit gestellten Spieler-/Kamerapositionen; Landmarkansichten benutzen Kontextkameras. Es gibt keine Aussage über physische Android-Geräte, APK/AAR-Abnahme, gemessene Bildraten, den Gesamt-Native-Workflow oder späteren Quellcode. Dieser Pack erzeugt kein freigebendes Receipt und verändert weder Pin noch Quelle/Index/Ref.

Alle gzip-Dateien verwenden einen leeren Originaldateinamen, mtime=0 und Kompressionsstufe 9. Manifestfelder nennen Original- und Speicherhash sowie Größe; der vollständige gzip-Roundtrip wurde bytegleich geprüft. SHA256SUMS bindet sämtliche gespeicherten Dateien einschließlich Manifest.
