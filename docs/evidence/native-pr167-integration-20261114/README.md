# PR167: Face- und Treasure-Anschluss an den aktuellen C4-Stand

## Ergebnis

Das Paket enthält **16 exakt veröffentlichte Native-Dateien** aus PR167. Sie sind für die Übernahme auf `27ae427029a5199699c95a79a84b0027d7571752` vorbereitet. Sieben bestehende Dateien wurden mit den veröffentlichten Hunks ohne Offset oder Fuzz rekonstruiert; neun Dateien sind neu. Alle finalen Git-Blobs stimmen mit PR167 überein. Der vollständige Patch einschließlich des GLB-Binärinhalts besteht `git apply --check` gegen die gespeicherten Ausgangsdateien.

Die sechs bereits integrierten C4-Dateien sind bytegleich mit PR167 und wurden nicht nochmals kopiert. Keine Worktree-, Index-, Commit-, Ref-, Pin-, Versions- oder Workflowdatei wurde geändert. Die finalen Quellen stehen ausschließlich unter `final-source/`.

| Bindung | Exakter Stand |
|---|---|
| Integrationsbasis | `27ae427029a5199699c95a79a84b0027d7571752` |
| Basisbaum | `c389c0de01d9a6ca9fd6e9332fafdf2dedbc8153` |
| Veröffentlichter Producer | `8be3a95d5d948d457c4c39bc6694138d60b70027`, PR167 |
| Producerbaum | `9edd7afed143c83fec5d2dc89949ca9325e042ce` |
| Producerparent | `803e7a626ea6ef0aeeda9c37010e844033d3a8e3` |
| Sourcefreeze | `source-freeze.json` |
| Vollständiger Patch | `integration.patch` |
| Neue CI-Pflichten | `gate-handoff.json` |

**Dies ist ein Quellen- und Integrationsnachweis.** Hier wurde kein neuer Godot-Import, Headless-Spieltest, Renderer-, Android- oder Leistungstest ausgeführt. Die neue kombinierte Quelle braucht weiterhin ihre eigene Abnahme. Lokal fehlt der benötigte Xvfb-Renderer; ein Headlesslauf wurde nicht als Ersatz ausgegeben.

## Enthaltene Änderungen

### Gesicht und bestehender Lehrer

Die zwölf Face-Dateien liefern das abgeleitete GLB mit Attribution und Importsidecar, den neuen Morph-Adapter, den Anschluss im vorhandenen Lumo-Actor und den bestehenden Speech-Statuspfad der Lernwelt. Zwei neue Probes und vier angepasste vorhandene Probes prüfen die neue tatsächlich vorhandene Schnauzenform und den Erhalt der bisherigen Animationen.

Der Actor lädt das abgeleitete Modell über seinen bestehenden gecachten PackedScene-Pfad. Die neue Poseklasse bindet Körper- und Lidmeshes einmalig und steuert vier Blickmorphs, eine geschlossene Schnauzenartikulation und acht Lidmorphs. Sie verändert keine Körperbone-Quaternionen. Unterbrechung, reduzierte Bewegung, Stopp, Mute, ungültige Samples und eine länger unveränderte Wiedergabeposition schließen den Kiefer. Dies ist keine phonembasierte Lippenanimation; das Modell erhält keine Mundhöhle oder Viseme.

Die Lernwelt akzeptiert weiterhin nur Statusantworten für die aktuelle Äußerungs-ID. Neue Bewegung verlangt `state=playing` und `audible=true`; für Kieferamplitude müssen zusätzlich `envelopeAvailable=true`, eine tatsächliche `positionMs` und `envelope` vorliegen. **Die passende Host-PCM-Implementierung und ihre Installerliste sind eine notwendige Paarabhängigkeit**, die Root und Flutter getrennt integrieren. Ohne dieses Hostpaket ist keine vollständige Sprachintegration behauptet. Der Native-Pin wurde nicht geändert.

### Treasure

Der produktive Treasure-Hunk enthält genau fünf zusätzliche Zeilen beim Aufbau des Titels: Ein vorhandener `KIT.panel()`-Style mit vier Pixeln Innenabstand wird dem Label zugewiesen. Aufgaben, Speicherzustände, Kamera, Regeln, Touchziele und sonstige UI-Logik bleiben unverändert. Die neue Originalfixture und die Kontrastprobe gehören dazu.

### Neuer C4-Visual-Capture

Der zusätzliche `connect_four_visual_capture.gd` liefert vier echte Rendereraufnahmen der bestehenden C4-Szene. Er erhält aufgezeichnete legale Zustände über einen **nur lesenden Fixture-Host** und weist selbst jede Spielaktion und Hostrückkehr zurück. Damit kann er Geometrie, Raster, erreichbare Menükontrollen und Scrollclips prüfen. Er ersetzt weder den vorhandenen echten Dart/Godot-Zweiprozesslauf noch Regeln, Bot, Speicherung, Belohnungen oder Android-Abnahme.

Die sechs schon identischen C4-Dateien bleiben außerhalb des Patches: Szene, Boot, Router, Table, HostBridge und Runtime-Regression. Auch die bestehenden Responsive-/Resume-Dateien und alle bisherigen 48 Core-Gates bleiben unverändert.

## Hier tatsächlich geprüfte Erhaltung

`checks/asset-preservation.json` enthält einen unabhängigen Vergleich der tatsächlichen GLB-Bytes gegen das auf27ae gespeicherte Original:

- Alle ursprünglichen Binärbytes sind als unveränderter Präfix erhalten.
- Skin und65Joint-Verknüpfungen, neun Clipdefinitionen, ursprüngliche Accessoren/BufferViews, Materialien, Bilder und Texturen sind gleich.
- Die ursprünglichen Nodes bleiben erhalten; ausschließlich neue Kindverknüpfungen wurden beim Vergleich gesondert behandelt.
- Das Körpermesh behält21.659 Vertices,30.000 Dreiecke und seine ursprünglichen Attribute/Indizes/Materialzuordnung. Es bekommt fünf Morphziele.
- Das zusätzliche Lidmesh besitzt zwei Oberflächen, insgesamt2.368 Vertices und4.320 Dreiecke sowie acht Morphziele.
- Der getrennte bestehende Sechs-Clip-Studiobaustein ist weiter Git-Blob `10b38ae0590626db40b24080e8a55edcb47ecf2b`.

Das neue GLB hat8.408.740 Bytes, exakt3.252.144 Bytes mehr als das Original. Diese Dateigröße ist keine GPU-/RAM-Messung. Der Bytevergleich beweist auch keine universelle Kollisionsfreiheit oder gute sichtbare Anatomie.

`checks/resource-dependencies.json` bindet100 tatsächlich vorhandene Ressourcen aus dem transitiven Scan der literalen `res://`-Verweise. Es bleibt kein fehlender literaler Eingangspfad. Der erwartete `.godot/imported/`-Zielpfad wird erst durch echten Import erzeugt. Der vorhandene Default `res://exports/lumo-animation` ist nach Quellenlektüre ausdrücklich ein erzeugtes Capture-Ausgabeverzeichnis; der erste unklassifizierte Scan ist getrennt erhalten. Dynamisch zusammengesetzte Ressourcenpfade werden durch diesen Scan nicht vollständig bewiesen.

Die produktiven Änderungen betreffen sieben vorhandene Actor-Funktionen plus eine neue Funktion, ausschließlich `_stop_speech`/`_tick_speech` in der Lernwelt und `_ui` in Treasure. Elf weitere Actor-,50 Lernwelt- und23 Treasure-Funktionen sind bytegleich; keine Funktion wurde entfernt. Die Funktionsabschnittsmessung ist ein Bytevergleich, kein AST- oder Laufzeitbeweis.

## Konkrete Leistungspunkte

Die Quelle vermeidet Modellladen, Meshsuche oder neue Morphindexlisten innerhalb der laufenden Gesichtsauswertung. Körpergewichte werden nur bei Änderungen geschrieben. Die ursprüngliche LOD-Erzeugung des Körpers bleibt aktiviert; nur die dünnen neuen Lidoberflächen behalten ihre volle Topologie. Zwischen Blinzlern werden die Lider ausgeblendet.

Trotzdem ist zusätzlicher Aufwand vorhanden: Jeder aktive Actor schreibt acht Lidmorphgewichte je Auswertung; das neue Modell enthält zwei zusätzliche Materialoberflächen und Morphdaten. Der Lernwelt-Speechstatus wird nun nach50 statt150ms erneut abgefragt. Diese tatsächlichen Änderungen müssen am Zielgerät unter realen Mehrfach-Actor-Szenen und Sprachwiedergabe gemessen werden.

Der originale Producer-MovieMaker-Log beschreibt llvmpipe,148 aufgezeichnete Frames bei24FPS Aufnahmeformat und etwa20Sekunden tatsächlicher Aufnahmezeit; er meldet87,81ms durchschnittliche CPU- und84,88ms GPU-Renderzeit. Das ist ein Desktop-Software-Renderer mit Aufzeichnung, keine Android-Leistungsprognose und insbesondere kein60FPS-Beleg. Hier wurde keine neue Aufnahme gestartet.

## Pflichtanschluss in die frische CI

| Neue Probe | Modus / bestehendes Producer-Einzelbudget | Neue Originalausgaben |
|---|---|---|
| `lumo_facial_regression` | Headless /180s |102erMarker mit tatsächlichen importierten Meshes |
| `lumo_facial_capture` | Renderer /420s |8PNG640×640,144 echte Zustandszeilen, ursprüngliches MovieMaker-AVI, überprüftes MP4/ffprobe |
| `connect_four_visual_capture` | Renderer /600s |4PNG, `visual-state.json`, reale Geometrie-/Zielmessungen im lesenden Fixture |
| `treasure_title_contrast_regression` | Renderer /600s |4PNG in vier Displayprofilen, `treasure-title-report.json` |

`gate-handoff.json` nennt alle Originaldateinamen, Größen, Marker, Argumente, Umgebungsvariablen, Sourceblobs und Aussagegrenzen. Insgesamt kommen16PNG hinzu. Für den Face-Capture muss `LUMO_FACE_CAPTURE_DIR` gesetzt und das tatsächliche AVI über `--write-movie` aufgezeichnet werden. Der komplette Player-/Mesh-Report und die Movie-Dekodierung sind Pflicht; ein Marker oder Dateizählen allein genügt nicht.

**Diese vier Modi sind in diesem Paket noch nicht in einen aktiven Runner eingehängt.** Root/Pipeline besitzt diesen Anschluss. Alle48 bisherigen Core-Paare,24Studio-/4Village-/6Puzzle-/7SafeArea-Raster sowie die getrennten sechs Touch-Modi mit32PNG müssen erhalten bleiben. Wenn die vier neuen Modi direkt an Nextgen angehängt werden, ergibt das52 Core-Paare; der bestehende echte C4-Zweiprozess-Gate bleibt davon getrennt.

Die auf803e basierenden kompletten Producerdateien `tools/validate_studio.sh` und `tools/tests/test_nextgen_runner.py` liegen nur als exakt gebundene Referenz unter `originals/producer-harness/`. Sie werden nicht über die aktuelle Integration geschrieben. Der Producerworkflow und seine Pin-/Archivbedingungen werden nicht übernommen.

## Historische Originalnachweise

Die kleinen originalen Producerprotokolle liegen unverändert unter `producer-local-evidence/`. Ihre Hashes und Herkunft stehen in `producer-evidence-index.json`:

- Face: Der ältere101erLauf bleibt separat erhalten. Der anschließende102erLauf mit gültiger Produktionsaufgabe hat einen eigenen Log und Ausführungsbericht. Die tatsächliche144erCapture-Ausgabe ist ebenfalls separat erhalten.
- Treasure: Originaler roter Lauf mit derselben27aeProduktdatei (121Checks/4Fehler), gefolgt von129Headless- beziehungsweise137Renderer-Checks auf dem fünfzeiligen Produktfix; bestehende Dichteprüfung1085. Das sind isolierte Producerläufe, keine neue kombinierte Abnahme.

Die veröffentlichten Commit-/Tree-/Compare-Antworten, der Original-Facefreeze und die Probeverträge liegen unverändert unter `originals/`. Keine historischen PNGs, Filme oder Freigaben wurden auf die neue kombinierte Quelle übertragen. Der aktuelle PR167-CI-Status wurde in diesem Auftrag nicht zusätzlich abgefragt.

## Übergabe

Root kann die16 eingefrorenen `final-source/`-Dateien übernehmen oder den vollständig gebundenen Patch anwenden. Vor einer Pinänderung sind der passende Host-PCM-/Installeranschluss, die frischen gemeinsamen Pflichtgates und tatsächliche neue Bild-/Filmprüfung erforderlich. Der lokale source-only Status bleibt bis dahin bestehen.
