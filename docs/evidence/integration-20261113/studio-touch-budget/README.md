# Studio-Touch-Budget: enger Workflow-Anschluss

Die einzige eigene Workflow-Änderung erhöht `touch-density.timeout-minutes` in
`.github/workflows/lumo-nextgen-2018.yml` von 40 auf 50. Die Prüfung in
`validation.json` vergleicht die vollständigen Workflowbytes mit
`a76f26b1d19662f6429a9cff063991e994d1e19a`; außerhalb dieses einen Werts sind sie
identisch. `exact-workflow.diff` und die beiden vollständigen YAML-Dateien
bewahren den Vergleich.

## Anlass und Umfang

Der veröffentlichte Studio-Beitrag
`24fb85800dfb58ec11dd409449e276299aa72b06` →
`76980a941fa05d047574d8cc386d3249d93ffca3` setzt das gerenderte Workshop-Budget
auf 2100 Sekunden. Zusammen mit den vorhandenen 600 Sekunden für Headless
ergeben sich 2700 Sekunden beziehungsweise 45 Minuten. Die gemeinsame
Nextgen-Matrix benötigt deshalb ebenfalls die vom Producer verwendeten
50 Minuten; rechnerisch bleiben 300 Sekunden für Einrichtung, Import und
Artefaktübertragung. Diese Rechnung ist keine Messung der tatsächlichen
CI-Laufzeit. Der unveränderte Producer-Diff ist in `producer-budget.diff.gz`
gesichert.

Testergebnis-, Source-, Bildroster-, Archiv- und Publisher-Bedingungen bleiben
unverändert. Es wurden keine Tests ergänzt oder verändert. Der separate
Build-HUD-/Scroll-Konflikt und dessen Produktkorrektur sind nicht Gegenstand
dieses Pakets.

## Tatsächlich ausgeführte Prüfungen

- Actionlint 1.7.12: Exit 0, leere unveränderte Ausgabe in `actionlint.log`.
- `python3 -m unittest tools.tests.test_nextgen_runner -v`: 8 Tests erfolgreich,
  21.956 Sekunden laut Originalausgabe in `nextgen-orchestration.log`.
- `git diff --check` für die geänderte Workflowdatei: Exit 0.
- Die acht ausdrücklich aufgeführten Workflow-/Runner-/Testdateien haben vor
  und nach diesen Prüfungen dieselben SHA256-Werte. Der Arbeitsbaum enthielt
  einen noch nicht committeten Studio-Merge; dies ist kein Gesamtabnahme-Stempel.

`validation.json` enthält Kommandos, Arbeitsverzeichnis, Zeitpunkte, Exitcodes
und Loghashes. Die Logs wurden direkt als unveränderte gemeinsame stdout-/stderr-
Bytes aufgezeichnet. Der frühere 8-Test-Lauf ist nur im ursprünglichen
Tooltranskript erhalten; `prior-observed-validation.json` dokumentiert diese
Grenze. Um einen dauerhaften Rohlog zu erhalten, wurde ausschließlich derselbe
enge Lauf erneut ausgeführt. Seine Ausgabe wird nicht als Rekonstruktion des
früheren Laufs bezeichnet.

Die Tests verwenden vorhandene Orchestrierungs-Fixtures. Sie prüfen unter
anderem fehlende beziehungsweise ungültige Raster, fehlgeschlagene Probes und
die Source-/Archivbedingungen. Sie liefern keine Renderer-, Android-,
Produkt- oder Releasefreigabe. Es wurde kein neuer CI-Lauf gestartet.

`manifest.json` bindet die Paketdateien an ihre Hashes; `SHA256SUMS` umfasst
zusätzlich das Manifest und kann mit `sha256sum -c SHA256SUMS` geprüft werden.

Der Producer-Diff ist verlustfrei gzip-komprimiert; das Manifest nennt auch Originalgröße und Originalhash.
