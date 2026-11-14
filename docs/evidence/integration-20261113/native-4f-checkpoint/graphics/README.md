# Grafik-Zwischenstand 4f34492

Dieses Paket bewahrt ausschließlich den erfolgreichen Grafiklauf 43466005184
für Native PR160, Head 4f3449253fd59023a2544432a178eb9efcafe4f9,
Tree 189b7a66c731067559469e2503e3a190b337031d. Alle drei Jobs sind erfolgreich;
der Lauf wurde am 13.11.2026 um 17:03:51 UTC abgeschlossen.

Es behauptet keinen Native-Gesamterfolg, keine spätere Loop-/Village-Abnahme,
keine Android-Abnahme und keine gemessene Bildrate. Es wurde kein Receipt
erstellt. Dieser historische Zwischenstand bleibt getrennt vom Quellstand des
Repositories, in dem sein Nachweis aufbewahrt wird.

## Inhalt und Originalbindung

| Bereich | Artefakt | Aktuelle PNG | Baseline-PNG | Vollständige Artefaktlogs |
|---|---:|---:|---:|---:|
| Home | 14059154186 | 24 | 20 | 19 |
| Worlds | 14059251203 | 6 | 6 | 15 |
| Feedback | 14058227051 | 6 | 0 | 6 |

Die vollständigen ZIPs und PNG bleiben im ursprünglichen Verzeichnis
/workspace/scratch/b3485b7bb989/pipeline-evidence/pr160-4f34492-graphics/.
Hier gibt es keine PNG- oder ZIP-Payloadkopien. archive-index.json bindet alle
drei unveränderten ZIPs an ihre originalen REST-Digests und Größen.
raster-index.json enthält sämtliche 62 Raster mit Archivbezug, Bildmaßen,
Bytegröße, SHA256 und aktueller bzw. historischer Quellidentität.
zip-entry-hashes.json.gz bewahrt zusätzlich den vollständigen Hashindex aller
regulären Einträge dieser drei Archive.

Vor dieser kompakten Sicherung wurden alle 186 Dateien der eingefrorenen
Original-Hashliste erneut auf unveränderte Bytes geprüft. Beim Packen wurden
die drei Original-ZIP-Digests gegen die vollständigen REST-Artefaktobjekte
verglichen; alle regulären Archiveinträge wurden gelesen und gehasht.
Sämtliche PNG, Rohlogs, Stempel und übernommenen Berichte wurden außerdem mit
ihren unveränderten extrahierten Originalen verglichen. Der frühere vollständige
Pillow-Decode jedes PNG ist in den unveränderten Verifikationsberichten erhalten;
es wurde hier kein neuer Renderer- oder Spieletest durchgeführt.

## Rohdaten und Verlustfreiheit

original/proofs/ enthält die endgültigen unveränderten Run-, Jobs- und
Artefakt-API-Antworten sowie die vollständigen Artefaktobjekte. Die genaue
Originalsammlung und deren Byteausschnitt sind in
original/artifact-metadata-provenance.json gebunden; ihre benötigten Rohquellen
sind ebenfalls enthalten. Keine normalisierte Kurzfassung ersetzt die Proofs.

Alle drei vollständigen Joblogs liegen als verlustfreie gzip-Dateien unter
original/. Sie sind die unveränderten, vom Connector dekodierten UTF-8-Ausgaben;
eine unveränderte HTTP-Transportkodierung wird damit nicht behauptet.
artifact-logs/ bewahrt alle 40 vollständigen ursprünglichen Engine-/Gate-Logs
aus den ZIPs. Jede gzip-Datei hat mtime=0 und keinen Dateinamen im gzip-Header.
Manifesteinträge nennen jeweils Hash und Größe vor und nach Kompression;
das Entpacken wurde bytegenau gegen die Originaldatei geprüft.

original-artifacts/ enthält aktuelle und historische Quellstempel,
Bildmanifeste und die unveränderten Captureberichte. Die separat ausgeführte
Baseline ist ada5ed81ad62339f15289da62670c0a4f9f7f2b9,
Tree 2e93cc5587b477ceee2d159c8aa981ff5188171b. Beide Importpfade und die
aktuellen Renderer-Gates waren erfolgreich. Alle 40 geprüften Artefaktlogs
sind frei von Engine-/Script-/Parse-/Ressourcen-/Leakfehlern; die ursprünglichen
sieben Projektvalidator-Warnungen bleiben vollständig erhalten.

## Tatsächliche Bildsichtung

Root hat die fünf frischen Originale Home 1280×720, Home 412×915,
Winter/Crystal Landmark 02 und Drift Release tatsächlich geöffnet. Seine
unveränderte Auswahl und die quellengebundenen Beobachtungen stehen unter
original/root-review/. Der Sichtungsbeleg hat SHA256
c87800000a35f7169eefc7a682b30055c6ad9381875358da49a4761c6874c927.
Bildgleichheit mit älteren Aufnahmen ersetzt weder diesen neuen Artefaktbezug
noch die tatsächliche Sichtung.

Der ursprüngliche Handoff ist bytegleich unter original/handoff.json erhalten,
SHA256 92fbcbc9826bc34e911c75c55799eb9408c5b35736da1d2bb5380850e3255cbd.
Die ebenfalls unveränderte Recorder-Eingabeprüfung fand vor der Root-Sichtung
statt; ihr damaliger Hinweis auf noch nötige Sichtung wird bewusst nicht
nachträglich umgeschrieben. Der dortige Eingabename artifact.json bezeichnet
das separat beigegebene originale REST-Artefaktobjekt, keinen ZIP-Eintrag.

manifest.json ordnet jede gespeicherte Originaldatei ihrem ursprünglichen Pfad,
Originalhash, Archivmitglied und gespeicherten Hash zu. SHA256SUMS bindet
zusätzlich alle Dateien dieses kompakten Pakets. Das eingefrorene Originalpaket
wurde durch diese Sicherung nicht verändert.
