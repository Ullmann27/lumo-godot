# 74c: Native-Gesamtakzeptanz abgelehnt, Grafikteil erfolgreich

Dieser Checkpoint gilt ausschließlich für **74c246d0b0af01c5d2d5438400ddd9ff3a3b0fef**, Tree **05f547fd58ccdc1002d98ff1031d4208b992b0ee**. Er enthält unveränderte Originalbelege zweier getrennter Läufe. Die nächste Quellenrevision und ihre Lifetime-Reparaturen sind hiervon nicht abgenommen.

| Teil | Originaler Run | Tatsächlicher Abschluss |
|---|---|---|
| Nextgen | [43458898046](https://github.com/Ullmann27/lumo-godot/actions/runs/43458898046) | **failure**: sechs erfolgreiche Pflichtjobs, ein fehlgeschlagener Gameplay-Job; Archiv skipped |
| Graphics | [43458897683](https://github.com/Ullmann27/lumo-godot/actions/runs/43458897683) | **success**: Home, Worlds und Feedback erfolgreich |
| Alle Workflows dieses Heads | Unveränderte API-Antwort in `metadata/all-workflow-runs.json.gz` | 14 success, 1 failure; keine Gesamtfreigabe |

## Konkreter unveränderter Fehler

Gameplay-Job **132000245650** endet in `scripts/tests/kart_regression.gd`, aufgerufen durch `tools/validate_project.sh`. Nach dem eigentlichen `[KartTests] PASS` folgen am 13.11.2026 um 16:11:46 UTC eine ObjectDB-Leak-Warnung und **`ERROR: 8 resources still in use at exit`**. Der strenge Gate endet mit Exit 1. Die acht Ressourcen sind im ursprünglichen nicht-verbose CI-Protokoll nicht typisiert; eine Audio-Klassifikation wird daraus nicht abgeleitet.

Der ungekürzte Originaljob liegt in `native/gameplay-job-132000245650.log.gz`. `native/legacy-failure-artifact-verification.json` erhält die konkreten Fehlerzeilen, Quellblobs, Original-Loghashes und ZIP-Digest. Das frühere `[KartLassoProduction] PASS: 26 assertions` gehört zu einem vorher abgeschlossenen Schritt und macht den späteren Fehler nicht grün. Original-Legacy-Artefakt: 14056855034, SHA256 `8b672f73e0141c138b2ee0631e4146dc72181258cc7ac1a3c926e6059a44681c`.

## Erfolgreiche aktuelle Core-/Touch-Komponenten

Das echte Bundle hängt nur von Core und Touch ab und wurde daher trotz rotem Gameplay erzeugt. Es ist ein **Teilnachweis des gescheiterten Runs**, kein Freigabebundle.

| Prüfbereich | Verifiziert |
|---|---|
| Core | 37 eindeutige Probe/Modus-Paare, alle PASS |
| Studio-Raster | 24 exakte Original-PNG einschließlich Größen, Bytezahlen und SHA256 |
| Touch | 6 eindeutige Probe/Modus-Paare, alle PASS |
| Touch-Raster | 32 Original-PNG: Werkstatt 6, Schatz 14, Bauwelt 12 einschließlich vier current-goal |
| Quellstempel | Vier aktuelle Trees exakt 05f547fd…; erforderliche Dirty-Dateien leer |
| Bundle insgesamt | 136 Original-PNG: 126 aktuelle und 10 getrennte historische Baselines; 96 Rohlogs streng sauber |

Die tatsächlichen neuen Originalmarker belegen **BuildPlay 62 headless / 70 rendered**, **DialogDensity 2016 headless / 2043 rendered** und **LearningStudio 183**. Die Werkstatt meldet 4129 / 4148 Assertions, Schatz 1085 / 1114. Alle sieben ausgeführten Nextgen-Joblogs sind vollständig unter `native/` gespeichert. Der achte Job, Archiv 132017522479, ist **skipped**; dafür sind die originalen Jobs-Metadaten und `native/archive-skip-observation.json` erhalten, ohne einen erfundenen leeren Log.

Originalbundle **14057710633**, 169806952 Bytes, SHA256 `9d289b2073e6504223f2ca615928a42e994a1393bb5847ca003aa76243a560a9`. Der Download und alle entpackten Originalbytes wurden geprüft. Es gibt für diesen Run keinen durch den übersprungenen Archivjob erzeugten Release-Nachweis.

Der tatsächliche, unveränderte Host-Verifier aus **233cdf4029edb30f007ef7be19693388b17145fe** wurde vor der Prüfung mit seinen drei lokalen Parserabhängigkeiten eingefroren. Die komplette Akzeptanzfunktion wurde auf die originalen Metadaten angewendet und lehnt ausdrücklich ab:

> Current Studio native workflow did not succeed at the exact pin

Die getrennten Quell-/Rasterfunktionen prüfen weiterhin unverändert 37/24 und 6/32. Der vollständige negative Akzeptanzbefund steht in `native/partial-native-artifact-verification.json.gz`. Die verwendeten Parserdateien und ihre ursprünglichen Blobs/Hashes stehen unter `native/validator-233cdf/` und im zugehörigen Source-Manifest. Das unveränderte volle Prüfsammlerskript und der ausdrücklich als Teilprüfung bezeichnete Sammler sind zur Nachvollziehbarkeit erhalten; sie erzeugen keinen Receipt.

## Getrennter erfolgreicher Grafikteil

Der vollständige erfolgreiche Graphics-Run hat drei erfolgreiche Originaljobs, **62 PNG** (36 aktuell, 26 Baselines) und **40 streng geprüfte Artefaktlogs**. Alle drei vollständigen Joblogs, die 40 Original-Artefaktlogs, Pflichtstempel, Import-/Renderlogs, Original-Metadaten und Verifikationsberichte sind unter `graphics/` erhalten. Die ursprünglichen Warnungen der Projektstrukturprüfung bleiben in den Rohdaten erhalten.

| Bereich | Artefakt | SHA256 des originalen ZIP |
|---|---:|---|
| home | 14056672152 | `f699c6cf5a0d61c398afded89ce67ce8eb871f002db5bc48db63c625b7facf4c` |
| worlds | 14055182823 | `55b6cad5e63684d483b1704563015350b47c05c780d1199a5cff21f5b322e196` |
| feedback | 14054878169 | `c099f7f20aec7f94b7c862082bb53cda1d11b4862d8987eefff86d5f12ccebd6` |

`graphics/artifact-metadata-provenance.json` beschreibt die exakten unveränderten Objekt-Byteausschnitte der ursprünglichen API-Antworten. Diese Quellen und Schnitte sind gemeinsam erhalten und gegeneinander geprüft. `graphics/handoff.json` ist die unveränderte eingefrorene Übergabe des Graphics-Agenten. Ihr Erfolg wird nicht auf den fehlgeschlagenen Nextgen-Run übertragen.

## Wirklich gesichtete Originalbilder

Root hat drei gezielte Native-Bilder geöffnet: das neue `bridge_hundred`-Querformat und die Bauziel-Dialoge mit 640×360 sowie 1080×2400 Pixeln. Das obere Gleichheitszeichen zeigt zwei getrennte Balken; die Bauzielbilder zeigen Beschreibung, Testaktion und Abbrechen innerhalb des Dialogs. Der genaue begrenzte Befund steht unverändert in `native/root-targeted-observations.json`.

Fünf aktuelle Grafikbilder wurden von Root tatsächlich gesichtet: Winter-Landmarke, Kristall-Landmarke, Drift-Release und Home in Hoch-/Querformat. Der Originalaudit liegt unter `graphics/74c-graphics-viewed-audit.json`. `viewed-image-index.json` gibt alle acht Auswahlbilder mit relativen Archivmitgliedern, Artefakt-IDs und Originalhashes wieder. Die Sichtungen sind gezielte Teilbeobachtungen, **keine vollständige native oder Android-Freigabe**.

## Integrität und Dateipfade

`manifest.json` ordnet jedem kopierten Original den relativen Speicherpfad, Originalgröße/-SHA256 und Speichergröße/-SHA256 zu. Sämtliche gzip-Dateien wurden deterministisch mit `mtime=0` erzeugt und vollständig gegen die unveränderten Originalbytes zurückgeprüft. Alle ursprünglichen JSON-/Log-/Handoff-Inhalte bleiben unverändert; darin enthaltene historische absolute Runner- oder Scratch-Angaben wurden nicht nachträglich redigiert. Die Pfade des neuen Packmanifests und der zusammenfassenden Indizes sind relativ.

`original-png-hashes.json.gz` enthält die vollständigen Native-/Graphics-Bildhashes und ursprünglichen Archivmitgliednamen. Große ZIPs und PNGs sind im Git-Pack nicht dupliziert. Die Original-Graphics-SHA256SUMS bleiben als ursprünglicher Übergabebeleg erhalten und referenzieren auch externe Payloads; die **obersten SHA256SUMS** prüfen dagegen ausschließlich alle tatsächlich enthaltenen Packdateien.

Die 40 Native-Quelldateien wurden erneut an den unveränderlichen Git-Objekten des treegleichen lokalen Commits a59dca033d1ad6afa4afbf0b51b03e04fe8c4ef9 geprüft. Die parallel entwickelten Folgekorrekturen sind in diesen Ergebnissen nicht enthalten. Pins, Receipts, Quellen, Probes, Workflows und Refs wurden durch diesen Checkpoint nicht geändert.
