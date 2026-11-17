# C4: bestätigte Rückkehr nach vorübergehender Android-Ablehnung

## Quellen und enger Eingriff

Integrationsbasis: `504c8ba70d02702cbccc370d0d96c36a292c5d27`.
Die produktive C4-Datei ist gegenüber dem tatsächlich geprüften Studio-Stand
`785413d395292a243eaa0a0748671eb15d3f80ff` bytegleich:
`cdeb31fc6cfe30c18fc6c96afb2b1d749532c37f`.
Auch `scripts/systems/host_bridge.gd` (Blob
`dab96a1b918dc754568c0eda14cdda05175c89fb`) und
`scripts/app/mobile_runtime.gd` (Blob
`53c6974ef2e1ba82bbb1fff71c9be4d9c16a911f`) sind auf beiden Quellen identisch.

Bisher beendet `apply_state()` die Verarbeitung sofort, wenn der gepollte
Hostzustand unverändert ist. Lehnt Android die erste Rückkehr ab, obwohl Dart
den Sitzungsabschluss bereits dauerhaft bestätigt hat, bleibt die Szene offen.
Die folgenden unveränderten Hostzustände lösen keinen weiteren Versuch aus.

Der Patch wiederholt ausschließlich die bereits bestätigte Rückkehr. Die
vorhandenen Sitzungs-, Revisions- und Pending-Prüfungen bleiben wirksam.
Eine erfolgreiche Android-Bestätigung verhindert weitere Versuche. Geometrie,
Spielregeln, Botzüge, Spielstände und Belohnungsaktionen werden nicht erneut
ausgeführt; die Rückkehr enthält weiterhin keine fremden Kart-Payloads.

## Tatsächlich ausgeführte Prüfung

Godot `4.6.3.stable.official.7d41c59c4`, Linux headless, echte
`connect_four_table.tscn` und produktive `_send()`/`_process()`-Wege.
Nur die Android-Hostgrenze wird durch ein ausdrücklich benanntes Fixture
ersetzt: erster Rückkehrversuch abgelehnt, zweiter akzeptiert.

- Unveränderter C4-Produktcode: **20 Checks, 3 Fehler, Exit 1**.
  Ausschließlich Wiederholung, Sitzungsabschluss und die daraus folgende
  Anzahl der Rückkehrversuche scheitern.
- Produktpatch: **21 Checks, 0 Fehler, Exit 0**;
  `CONNECT_FOUR_RETURN_PASS checks=21`.
- Die zusätzliche Prüfung im erfolgreichen Lauf prüft die zweite tatsächlich
  aufgezeichnete Rückkehrantwort; daher die unterschiedliche Checkzahl.
- Neuer Test: `gdformat --check` und `gdlint` erfolgreich. Die ausdrücklich
  erhaltenen Java-Hostmethodennamen sind lokal von `function-name` ausgenommen.
- `python3 tools/validate_project.py`: Exit 0 auf dem lokalen 785-Testbaum.
- Die bestehende Lernwelt-Regressionsprobe bestand unabhängig **5.340 Checks**.
  Ein zuerst vermuteter Multitouchfehler ließ sich nicht reproduzieren und führte
  deshalb zu keiner Änderung an der Lernwelt.

Aufruf nach normalem Godot-Import:

```bash
godot --headless --path . --script scripts/tests/connect_four_return_regression.gd
```

## Erhaltene Integration und Grenzen

Der bestehende `tools/validate_nextgen.sh` von 504 bleibt bytegleich
(Blob `e5c02cf83818a4fd1c958db12f56332bb8ec93de`), ebenso seine
52 verpflichtenden Probe-/Moduskombinationen und Raster-/Movie-Gates. Der neue
Test ist hier eine separat ausführbare Regression. Seine Aufnahme als weiterer
Pflichtmodus erfordert einen bewussten gemeinsamen Anschluss von Runner und
den auf exakt 52 Modi gebundenen Verträgen; dieser Patch umgeht diese Bindung nicht.

Die Laufzeitumgebung wurde nach den oben beobachteten Ergebnissen unavailable.
Der Quellpatch und derselbe erfolgreiche Teststand wurden daher anschließend
auf der neueren Integrationsbasis gesichert. Ein vollständiger kombinierter
504-Lauf, vollständige erneute CI, Android-Hostlauf, Rendererabnahme und
Fold7-Messungen werden hier nicht behauptet. Begonnene, vor dem Laufzeitverlust
nicht abgeschlossene Runner-Tests gelten nicht als bestanden.
