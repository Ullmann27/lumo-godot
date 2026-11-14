# PR167-Folgeanschluss: Import, Modellidentität und MovieMaker-Maße

## Feste Quellen und Umfang

Dieses Paket ergänzt ausschließlich vier Dateien gegenüber unserem veröffentlichten Native-Stand `7e03f1113073e2f941b052028a649aa144eefe64`, Tree `a79d41272a55b1bf1ffb82e656ea34556b3a0a83`.

Die ersten drei Dateien sind exakt veröffentlichte Quellen aus Producer-Commit `acf51d3bd2997c4b731e9a48e1791e05e756a132`, Tree `625d501c8517fa88787a0a415cd5d5b2e75ac845`, unmittelbarer Parent `8be3a95d5d948d457c4c39bc6694138d60b70027`. Der vollständige originale GitHub-Compare liegt unverändert unter `originals/producer-compare.json`. Seine vollständigen Hunks ließen sich auf unsere exakten 7e03-Blobs ohne Offset oder Fuzz anwenden. Die Ergebnisse stimmen mit den drei veröffentlichten Git-Blobidentitäten überein. Das vollständig enthaltene neue Producer-Dokument wurde aus seinem Additionspatch bytegenau materialisiert und gegen seinen veröffentlichten Blob geprüft.

| Zielpfad | Enger Anschluss |
|---|---|
| `assets/characters/lumo_facial/Lumo-Facial-Mobile.glb.import` | Nur veröffentlichte kanonische Defaultfelder im bestehenden Eyelids-Unterobjekt; GLB und explizite Lid-LOD-Einstellung bleiben unverändert. |
| `scripts/tests/lumo_attention_landing_regression.gd` | Ursprüngliches Modell bleibt separat an Originalpfad und Originalhash gebunden; das aktiv gewählte Facialmodell erhält zusätzlich seinen eigenen Pfad- und Hashcheck. |
| `scripts/tests/lumo_facial_capture.gd` | Nur früher Capture-`_init()` setzt beide MovieMaker-Fenstermaße auf 640. Produktives `project.godot` bleibt unverändert. |
| `tools/tests/test_studio_2020_rasters.py` | Ein neuer negativer Fall für das veröffentlichte fehlerhafte Format 720×1280, mit frisch gebundenen Transporthashes; sämtliche bisherigen Testfunktionen bleiben AST-identisch. |

Der Producer-Runner wurde nicht übernommen. Unser bereits eingefrorener 52er-Runner sowie sein Raster-/Movie-Nachrechner bleiben bytegleich. Die tatsächliche Laufzeitprüfung verlangt bereits strikt 640×640. Das hinzugefügte Gegenbeispiel schließt die konkrete fehlende Testabdeckung; es ist keine Lockerung und keine Korrektur der Größenbedingung.

## Modell- und Verbraucherbindung

Die beiden Modellbytes wurden direkt aus dem tatsächlichen 7e03-Gitobjekt gehasht: ursprüngliches GLB `3559f700784bc1006905ee3aae01e8bcfbffb95b4f621f7430ce771ba0e3efd5`, Facialableitung `e14aea79eb9918f5184c8ded64e8c1343bf71f553772a4f59298ada6862d9524`. Der aktuelle Actor definiert beide Pfade getrennt. Kein Modell wird in diesem Folgepack verändert.

Der aktive Technical-Art-Runner ruft die Attention-Probe auf und verlangt weiterhin `"failures":0`. Die quellengebundene Suche über alle verfolgten `tools/`, `.github/` und `scripts/` fand keinen zusätzlichen Verbraucher des ersetzten `model_unchanged`-Reportfelds. Suchbefehl, vollständiger Ausgang und betreffende Abhängigkeitsblobs sind unter `active-consumer-check.*` erhalten. Aussagen über externe Verbraucher werden daraus nicht abgeleitet.

## Tatsächliche lokale Prüfung

Drei gezielte Python-Verträge bestanden in 1,182 Sekunden, ohne Fehler oder Skips:

1. Ein Movie-Report mit 720×1280 wird trotz aktualisierter Report-/Proofhashes verworfen; nach Wiederherstellung von 640×640 ist derselbe vollständige synthetische Nachweis gültig.
2. Die unveränderten Originalreportstrukturen binden weiterhin alle 16 vollständig dekodierten synthetischen Bilder.
3. Der reine Replay erhält sämtliche Originaldateien und Manifeste unverändert.

Die vollständigen ungekürzten Logs liegen unter `local-tests/`; `focused-validation.json` bindet die tatsächlichen Befunde. Alle vier Kandidatquellen und der veröffentlichte 7e03-Arbeitsbaum blieben währenddessen unverändert. Der frühere 41/41-Abschluss auf 7e03 bleibt als eigener, unveränderter historischer Pack erhalten.

## Nachweisgrenzen

Hier wurden keine Godot-Imports, Engine-Probes, echten Filme, Rendererbilder oder Androidläufe ausgeführt. Die dokumentierten Producer-Red-/Green- und MovieMaker-Ergebnisse bleiben dessen eigener historischer Nachweis; dessen Originaldokument wird unverändert mitgeführt. Sie werden nicht als erfolgreicher kombinierter Lauf unseres neuen 52er-Standes bezeichnet. Ein frischer gemeinsamer Lauf, seine Originalbilder und der tatsächlich erzeugte 640×640-Film bleiben erforderlich.

Dieses Paket ändert weder einen Worktree noch Git-Index, Commit, Ref, Pin oder Workflow. Root übernimmt ausschließlich die vier ausdrücklich eingefrorenen Zielpfade.
