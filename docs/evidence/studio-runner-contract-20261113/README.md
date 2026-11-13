# Studio-Runnervertrag: gezielte Testkorrektur nach Native 20fd

## Tatsächlicher Fehler

Der Native-Lauf **43520242403**, Quellcommit
`20fd2880494c10f8f7d3a266956995e97f9011df`, scheiterte im Job
`new-worlds` an zwei veralteten Python-Verträgen in
`tools/tests/test_nextgen_runner.py`:

- Die positive Raster-Fixture enthielt nur die bisherigen 30 PNGs. Der bereits
  erweiterte reale Harness verlangte zusätzlich drei Cards-Bilder samt
  Layoutdateien und vier Mobile-Bilder mit Messbericht.
- Die Probe-Liste erwartete nur elf Aufrufe. Die fünf zusätzlichen erforderlichen
  Android-Inset-/Cards-/Mobile-Aufrufe waren noch nicht im Test berücksichtigt.

Das Originaljoblog endet bei sechs Runner-Tests mit genau diesen zwei Fehlern.
Dies ist kein nachgewiesener neuer Grafik- oder Gameplayfehler. Der fehlgeschlagene
Gesamtlauf wird durch die lokale Korrektur nicht rückwirkend erfolgreich.

## Exakte Ausgangsquelle

Die lokale Testdatei war zunächst älter als die veröffentlichte Quelle. Vor dem
Rotlauf wurde ausschließlich diese ausdrücklich zugewiesene Datei durch die
exakten 20fd-Bytes ersetzt. Die ältere lokale Kopie bleibt im QA-Arbeitsverzeichnis
erhalten; sie ist weder die Reparaturbasis noch Teil des Uploads.

- Ausgangstest: Git-Blob `49164a4b7cde1605ee80cd5ac0140a6ac55aa98d`,
  SHA-256 `fe0426c3e895d10ecfb4b931d8883625baeac6d387f211f2d2eb700d6c33872e`.
- Unveränderter `tools/validate_studio.sh`: Git-Blob
  `97e25c3ebef6f88a65ccee615ba144fe4b64b86a`, SHA-256
  `78d1cd6df60968c9d4d767b0c27c9b240df9968a817e703cec8d77294057b587`.
- Der gesamte veröffentlichte `tools/tests`-Baum wurde über GitHub an 20fd gelesen:
  elf Python-Testdateien plus eine PNG-Fixture. Alle zwölf Dateien waren nach der
  gezielten Wiederherstellung byte-/Gitblobgleich. Es fehlte keine Testdatei.
  Die einzige zusätzliche lokale Datei war Godots generierte `.png.import`-
  Metadatei; sie ist kein ausführbarer Python-Test.

## Einziger Quellpatch

Geändert wird ausschließlich `tools/tests/test_nextgen_runner.py`:

1. Die bisherigen neun Standard- und zwei Puzzle-Menüaufrufe behalten ihre
   exakten Marker, Modi und Zeitbudgets. Fünf neue Aufrufe werden mit ihren
   tatsächlichen Markern und Budgets verlangt; die beiden neuen Rendereraufrufe
   müssen ausdrücklich `-- --capture` übergeben.
2. Die positive Fixture enthält alle bisherigen 30 Bilder, die drei tatsächlichen
   Cards-Dateinamen mit `.layout.json` und die vier vorgegebenen
   `*-landscape-cutout.png` mit `mobile-safe-area.json`. Der echte, unveränderte
   Python-Rosterblock aus dem Shell-Harness verarbeitet diese Daten.
3. Die Ausgabe muss genau 37 Bilder in den sieben richtigen Gruppen enthalten.
   Für jede Cards-Layoutdatei werden der tatsächlich geschriebene Pfad,
   Byteumfang und SHA-256 im erzeugten Roster nachgeprüft.
4. Zwölf Cards-Gegenfälle verwerfen fehlendes Bild/Layout, ungültiges JSON,
   boolesche oder falsche Schemaversion, unsettled/hidden/pending,
   falsche Beobachtungsquelle, abweichende Fenstergröße sowie fehlende Hand- oder
   Ablagegeometrie.
5. Zwölf Mobile-Gegenfälle verwerfen fehlende/falsch benannte/falsch dimensionierte
   Bilder, fehlenden/ungültigen Messbericht, gemeldete Fehler, unvollständige
   Zielmenge, unsichere/zu kleine letzte Touchfläche, falschen letzten Bildhash
   und fehlende/zusätzliche Roster-Einträge. Kein abgelehnter Fall darf eine
   `renderer-images.json` hinterlassen.

Die drei bisherigen Menübild-Gegenfälle und der strenge Test gegen eine native
Enginefehlerzeile trotz PASS-Marker/Exit 0 bleiben erhalten. Die neuen PNGs sind
explizit synthetische schwarze Testfixtures, **keine Renderer- oder Gerätebilder**.

## Tatsächlich ausgeführte Läufe

| Lauf | Befehl / Ergebnis |
| --- | --- |
| Unveränderter roter Gegenlauf | `python3 -m unittest discover -s tools/tests -p test_nextgen_runner.py -v`: **6 Tests, genau 2 FAIL**, Exit 1, 6,488 s. Dieselben Fehler wie im Originaljoblog. |
| Vollständige Testsuite nach dem Patch | `python3 -m unittest discover -s tools/tests -v`: **68/68 PASS, 0 Skip**, Exit 0, 13,735 s. Einschließlich aller acht Runner-Testmethoden und der 24 zusätzlichen negativen Unterfälle. |
| Quellbestand und Format | Alle 21 Dateien des unveränderten Safe-Area-Freezes, alle 54 übrigen verglichenen Test-/Top-Level-Tooldateien und der Studio-Workflow unverändert. `git diff --check -- tools/tests/test_nextgen_runner.py`: Exit 0. |

Ungekürzte Logs, Ausführungsmetadaten, Verzeichnis-Blobs, Nachhervergleich und der
Diff gegen 20fd liegen neben diesem Bericht. Der neue Test-SHA-256 lautet
`58bc8cf4ddec61355bdd349612d99360b6142a3c3969ce12366e14c91c7e7560`.

## Grenze und Integration

Keine Änderung an produktiver Szene, Gameplay, Saveformat, nativen Prüfskripten,
Shell-Harness, Workflow, Zeitbudget oder Abnahmeschwelle. Keine GitHub-Mutation
durch den Autor. Der Integrator übernimmt nur den ausdrücklich gelisteten Patch
und die Belege in einen neuen Commit. Ein vollständiger neuer Native-CI-Lauf,
dessen aktuelle Originalbilder und spätere Android-Abnahme bleiben erforderlich.
