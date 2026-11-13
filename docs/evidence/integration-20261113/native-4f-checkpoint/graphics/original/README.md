# PR160: Grafiknachweis für 4f34492

Der Grafiklauf 43466005184 ist am 13.11.2026 um 17:03:51 UTC mit **SUCCESS**
abgeschlossen. Alle drei Jobs sind erfolgreich. Die unveränderten Original-
metadaten binden diesen Lauf an Head
`4f3449253fd59023a2544432a178eb9efcafe4f9` und Tree
`189b7a66c731067559469e2503e3a190b337031d`.

## Neue Originale und Prüfung

| Bereich | Originalartefakt | Aktuelle PNG | Baseline-PNG | Geprüfte Logs |
|---|---:|---:|---:|---:|
| Home | 14059154186 | 24 | 20 | 19 |
| Worlds | 14059251203 | 6 | 6 | 15 |
| Feedback | 14058227051 | 6 | 0 | 6 |

Alle drei ZIPs stammen aus diesem Lauf. SHA256-Werte, Originalgrößen und Pfade
stehen vollständig in `handoff.json`. ZIP-Digests wurden gegen die originalen
GitHub-REST-Metadaten geprüft, außerdem CRC, reguläre sichere Archivpfade,
alle Bildmanifest-Einträge und alle 62 PNG. Pillow 13.0.0 hat jede aktuelle und
historische Datei mit `Image.verify()` und vollständigem `Image.load()`
geprüft. Alle 40 ursprünglichen Artefaktlogs sind frei von den geprüften
Engine-, Script-, Parse-, Ressourcen- und Leakfehlern. Die unveränderten
Projektvalidator-Warnungen stehen weiterhin in den Originalprotokollen.

Aktuelle Stempel sind exakt 4f34492/189b7a66 bei leerem Nachweis geänderter
getrackter Quellen. Der separat neu ausgeführte historische Vergleich verwendet
`ada5ed81ad62339f15289da62670c0a4f9f7f2b9`, Tree
`2e93cc5587b477ceee2d159c8aa981ff5188171b`. Aktuelle und historische Imports
sowie Rendereraufnahmen sind erfolgreich. Die Hashes des gemeinsamen Home-/
Worlds-Aufnahmeprogramms stimmen mit den unveränderlichen Dateien dieses
aktuellen Commits überein. `immutable-source/` bewahrt auch die gemeinsame
Home-Regressionsbasis.

## Fünf aktuelle Originalbilder für Root

`required-current-image-paths.json` enthält die beiden Home-Orientierungen
1280×720 und 412×915, Winter/Crystal Landmark 02 sowie Feedback Drift 03.
Jeder Eintrag nennt Originalarchiv, Artefakt-ID, Run, Head, Tree, Dateipfad,
Bilddigest und Maße. Dies ist ein Herkunftskatalog und keine Bildfreigabe.
Auch bei bytegleichen Bildern wird ausschließlich ihre neue Archiv- und
Quellbindung verwendet. Root hat alle fünf frischen Originale tatsächlich
geöffnet. Seine unveränderten, an Head/Tree/Run/Artefakt und PNG-Hashes gebundenen
Beobachtungen und die Auswahl liegen unter `root-review/`. Der Sichtungsbeleg
hat SHA256 `c87800000a35f7169eefc7a682b30055c6ad9381875358da49a4761c6874c927`.
Dies bleibt ein eigener Zwischenstand für 4f; wegen der folgenden separaten
Loop-/Village-Lieferung wurde kein Receipt ausgestellt.

## Vollständige Original-Proofs

`proofs/run.json`, `proofs/jobs.json` und `proofs/artifacts.json` sind die
unveränderten endgültigen GitHub-REST-Antworten. Einzelne Artefakt-Proofs sind
vollständige unveränderte Objekt-Byteausschnitte der Originalsammlung.
`artifact-metadata-provenance.json` hält Quelle, Bytepositionen und Hashes fest;
alle drei Objektinhalte wurden mit der endgültigen Sammlung verglichen.
Die drei vollständigen Joblogs sind als unveränderte, vom Connector dekodierte
UTF-8-Ausgaben gespeichert. Die Rohlogs innerhalb der ZIPs bleiben ebenfalls
unverändert erhalten.

Der bestehende Recorder hat über seine reinen Eingabeleser das vollständige
Eingabeset geprüft (`recorder-inputs-ready.json`). Es wurde kein Receipt
erstellt. Die Prüfhelfer wurden lediglich an die neue Quellidentität gebunden;
kein älteres Ergebnis, Archiv oder Bild wurde als aktueller Nachweis kopiert.

## Prüfgrenzen

Dies ist ausschließlich der Grafiklauf für 4f34492. Separate Nextgen-, Android-
oder spätere Quellstände werden damit nicht abgenommen. Der parallel separat
geprüfte, noch nicht veröffentlichte Loop-/Village-Folgestand ist nicht Quelle
dieser Bilder. X11/Mesa-Aufnahmen belegen keine physische Android-Abnahme und
keine gemessene 60-FPS-Leistung. Weltenbilder zeigen stationäre Produktionsszenen
mit gesetzten Kameras; die Landmark-Ansicht verwendet eine Kontextkamera.

Es gab keinen Rerun, keine Quellen-/Ref-Änderung und keinen Pin-/Receipt-Eingriff
im Rahmen dieser Sammlung. `SHA256SUMS` bindet Originalarchive, Metadaten,
Rohlogs, Stempel, sämtliche manifestierten PNG und diese Übergabedateien.
