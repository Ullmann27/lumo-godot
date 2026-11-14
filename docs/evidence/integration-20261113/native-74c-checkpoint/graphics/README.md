# PR160: Grafiknachweis für 74c246d

Der Grafiklauf 43458897683 ist am 13.11.2026 um 16:22:01 UTC mit **SUCCESS**
abgeschlossen. Alle drei Jobs sind erfolgreich. Die unveränderten Original-
metadaten binden diesen Lauf an Head
`74c246d0b0af01c5d2d5438400ddd9ff3a3b0fef` und Tree
`05f547fd58ccdc1002d98ff1031d4208b992b0ee`.

## Originale und Prüfung

| Bereich | Originalartefakt | Aktuelle PNG | Baseline-PNG | Geprüfte Logs |
|---|---:|---:|---:|---:|
| Home |14056672152|24|20|19|
| Worlds |14055182823|6|6|15|
| Feedback |14054878169|6|0|6|

Die drei ZIPs stammen aus diesem Lauf. Ihre vollständigen SHA256-Werte,
Originalgrößen und Pfade stehen in `handoff.json`. ZIP-Digest gegenüber GitHub,
CRC, reguläre sichere Archivpfade, sämtliche Bildmanifest-Einträge und alle
62 PNG wurden geprüft. Pillow 13.0.0 hat jede Datei mit `Image.verify()` und
vollständigem `Image.load()` geprüft. Alle 40 ursprünglichen Artefaktlogs sind
frei von den geprüften Engine-, Script-, Parse-, Ressourcen- und Leakfehlern.
Die sieben vorhandenen Projektvalidator-Warnungen sind unverändert erhalten;
sie werden nicht als beseitigt ausgegeben.

Aktuelle Stempel sind exakt 74c246d/05f547fd bei leerem tracked-source-dirty-
Nachweis. Der frische historische Vergleich verwendet
`ada5ed81ad62339f15289da62670c0a4f9f7f2b9`, Tree
`2e93cc5587b477ceee2d159c8aa981ff5188171b`. Beide Imports und ihre
Rendereraufnahmen sind erfolgreich. Die Hashes des gemeinsamen Home-/Worlds-
Aufnahmeprogramms stimmen mit den Originaldateien des aktuellen Commits
überein. `immutable-source/` bewahrt diese über die Commit-Referenz geladenen
Dateien, einschließlich der gemeinsamen Home-Regressionsbasis.

`proofs/run.json`, `proofs/jobs.json` und `proofs/artifacts.json` sind die
unveränderten endgültigen GitHub-REST-Antworten. Die einzelnen Artefakt-Proofs
sind vollständige unveränderte Objekt-Byteausschnitte der Originalsammlung,
keine normalisierten Rekonstruktionen. Herkunft, Bytepositionen und Hashes
stehen in `artifact-metadata-provenance.json`; alle drei Objektinhalte wurden
mit der endgültigen Sammlung verglichen. Die drei vollständigen Joblogs sind
als unveränderte vom Connector dekodierte UTF-8-Ausgaben erhalten.

Der vorhandene Recorder hat über seine reinen Eingabeleser das vollständige
Eingabeset geprüft (`recorder-inputs-ready.json`). Es wurde kein Receipt
erstellt. Auch bei bytegleichen Bildern gilt ausschließlich ihre neue
Archiv-/Quellbindung. Root muss die frischen Originalbilder selbst öffnen und
seine tatsächlichen Befunde gesondert dokumentieren.

## Grenzen

Dies ist ausschließlich der Grafiklauf. Der parallel gemeldete Ressourcen-
fehler im Nextgen-Gameplay wird dadurch nicht freigegeben. X11/Mesa-Aufnahmen
sind keine Android-Geräteabnahme und keine gemessene 60-FPS-Bestätigung. Die
Weltenbilder zeigen stationäre Produktionsszenen mit gesetzten Kameras; die
Landmark-Aufnahme verwendet eine Kontextkamera.

Es gab keinen Rerun, keine Quellen-/Ref-Änderung durch diese Grafikprüfung und
keine Übernahme alter Archive, Bilder oder Prüfergebnisse als aktuellen
Nachweis. `SHA256SUMS` bindet die Originalarchive, Metadaten, Logs, Stempel,
manifestierten PNG und diese Übergabedateien.
