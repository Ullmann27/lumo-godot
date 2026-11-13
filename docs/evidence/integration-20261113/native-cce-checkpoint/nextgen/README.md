# Abgeschlossener Quellencheckpoint ccebbe24

Dieser Ordner bindet ausschließlich Native-PR 160 an Commit
ccebbe24b489ba7971c605a2bc5187fcfea26f9e, Tree
8409dc27958dc102d7fc84b413f28642782668aa. Der lokale Commit
197f4058736150a755adc9ec0ef8b98565af636b besitzt denselben vollständigen Tree.
Die drei tatsächlichen Parent-SHAs stehen unverändert im Original-Commit-JSON
und im abgeleiteten Quellenbericht; sie werden nicht aus früheren Checkpoints übernommen.

## Tatsächlich bestandener Vertrag

Nextgen-Lauf 43474541452 ist beim ersten PR-Versuch vollständig erfolgreich
beendet. Alle sieben Pflichtjobs und der ausschließlich evidenzarchivierende
achte Job sind SUCCESS. Der finale Original-API-Satz zeigt alle 15 Workflows
dieses exakten Heads als SUCCESS. Die detaillierten Graphics- und
Zusatzworkflow-Nachweise werden getrennt von den zuständigen Agenten gesichert.

Der vor der Prüfung eingefrorene Host-Prüfer stammt aus
4098d8992a649640c408e89f0aeab78fd9e7d1a4, Tree
86e6ed0f439b9ec8fda6d83d6f1e7d0c5e24b3b1. Sein Hauptparser hat Git-Blob
c0e6df50ff2ff171baf38d33f6fa5abdd97d77ac und SHA256
56859949a678bfdbe0dd2d749bbae661a10a83be9a8af5c64fe34e190ea101c2.
Alle vier tatsächlichen Parserdateien, deren unverändertes Quellenmanifest
und der Original-Host-Commitnachweis sind enthalten. Die Parser sind
verlustfrei als .py.gz gespeichert. storage-map.json nennt ihre ursprünglichen
und gespeicherten Pfade; auch ursprüngliche Leerzeilen am Dateiende bleiben erhalten.

| Bestandteil | Tatsächlich geprüfter Originalnachweis |
| --- | --- |
| Core | 41 exakte Probe/Modus-Paare PASS |
| Studio | 24 verpflichtende Original-PNG |
| Dorf | Vier verpflichtende Original-PNG samt tatsächlicher Root-Sichtung |
| Touch | Sechs Probe/Modus-Paare PASS, 32 Original-PNG: Werkstatt 6, Schatz 14, Bauwelt 12 |
| Quellen | Vier aktuelle Capture-Trees exakt 8409dc27; sämtliche vorhandenen vorherigen/nachherigen Dirty-Stempel leer |
| Native-Bundle | 140 vollständig dekodierte PNG: 130 aktuell und zehn ausdrücklich alte Vergleichsaufnahmen |
| Native-Protokolle | Alle 104 Bundle-Logs streng ohne die geprüften Engine-, Skript- oder Ressourcenfehler |
| Bauwelt | BuildNextgen 71 headless und 79 tatsächlich gerendert |
| Dorf-Szene | 223 headless und 231 tatsächlich gerendert |
| Dorf-Modell / Gestaltung | Economy 337; VillageArt 2259 Prüfungen, null Fehler |
| Bauweltdialog | 2016 headless und 2043 tatsächlich gerendert |
| Lernstudio | 183 tatsächliche Prüfungen |
| Werkstatt | 4129 headless und 4148 tatsächlich gerendert |
| Schatz-Touch | 1085 headless und 1114 tatsächlich gerendert |

Der aktuelle Schritt Existing gameplay regression suite ist erfolgreich.
Alle 13 angeschlossenen Lifetime-Verbraucher sind an 19 unterschiedlichen
Quell-Aufrufstellen durch 23 tatsächliche Freigabemarker belegt. KartTests
wartet vor Resume auf fünf Playbacks (65 ms) und vor seinem abschließenden
PASS auf vier (17 ms). Der gerenderte Core-PlayerFullRoute wartet zusätzlich
auf zwei Playbacks (69 ms) und meldet erst danach PASS. Der getrennte
Live-/Action-/Lasso-Schritt ist erfolgreich; Lasso meldet 26 Assertions.

Dieser Nextgen-Lauf enthält keinen eigenständigen DriveFeedback-LOGIC_PASS-56-
Marker. Die direkte aktuelle Feedbackprüfung gehört zum getrennten
Graphics-Lauf und meldet dort tatsächlich gerendert PASS 75. Es wird kein
Headless-56-CI-Nachweis aus einem älteren lokalen Lauf übernommen.

## Originalarchiv und vollständige Erhaltung

Das Native-Artefakt 14064293493 umfasst 174014246 Bytes, SHA256
4e2eb984edc779175d85bea77555a42146d9c39a443654fd2d6a5dbc573b780d.
Originalrelease 444569876 enthält ZIP-Asset 744655255 mit exakt derselben
Größe und demselben Digest. Der Tag zeigt auf ccebbe24.

https://github.com/Ullmann27/lumo-godot/releases/tag/integration-evidence-ccebbe24b489ba7971c605a2bc5187fcfea26f9e-14064293493

Der vollständige erfolgreiche Archivjob belegt den öffentlichen Rückdownload
und Bytevergleich innerhalb dieses CI-Laufs. Lokal wurde das ursprüngliche
Actions-ZIP heruntergeladen und gegen den originalen Asset-Digest geprüft;
ein zusätzlicher lokaler öffentlicher Rückdownload wird nicht behauptet.
Dieses Archiv enthält kein APK.

Alle acht vollständigen GitHub-Joblogs und alle 245 vollständigen Artefaktlogs
aus Preview, Legacy, Worlds und Native sind verlustfrei mit gzip, mtime=0,
enthalten. Die vollständigen Eintrags- und PNG-Hashindizes erfassen alle vier
heruntergeladenen Original-ZIPs. PNG- und ZIP-Payloads werden hier nicht
dupliziert. Die drei separaten Touch-Komponenten-ZIPs wurden nicht zusätzlich
heruntergeladen; ihre originalen GitHub-Metadaten mit IDs und Digests sind
gesichert und ihre vereinten Dateibytes werden im Native-Bundle geprüft.

Jede ursprüngliche Worlds-Datei ist im finalen Native-Bundle bytegleich
nachgewiesen. Das bindet auch die vier von Root geöffneten Dorfaufnahmen,
ohne ihre ursprüngliche Worlds-Artefakt-ID im Audit umzuschreiben.

manifest.json unterscheidet Original-API-Daten, unveränderte vollständige
Logs und Quellen, bereits erstellte Prüfberichte sowie abgeleitete
Hashindizes. Jeder Payload hat ursprüngliche und gespeicherte Größe und
SHA256. Sämtliche Manifest-Payloadpfade sind relativ. Unveränderte Rohdaten
können ursprüngliche absolute Runnerpfade und URLs enthalten; sie wurden
nicht bereinigt. SHA256SUMS erfasst sämtliche Payloads und das Manifest.

## Tatsächliche Bildsichtung und Grenze

Der Godot-Agent hat das neue cce-Hundert-Bild tatsächlich geöffnet und beide
Gleichheitszeichen mit getrennten Balken erkannt. Der Originaldownload ist
an cce gebunden, auch wenn dessen PNG-Bytes mit einem früheren Lauf gleich sind.

Root hat alle vier neuen Dorf-Originale tatsächlich geöffnet: Übersicht,
hochkantige Kapitelansicht, hochauflösender Lieferdialog und kurze Schatzkammer.
Der unveränderte Audit nennt präzise die sichtbare Titel-Ellipse, die bereits
gescrollten Hintergrundstreifen und die begrenzte gleichzeitige Sichtbarkeit
langer Dialoginhalte. Er belegt die sichtbaren Dialoginhalte und Schließen-
Bedienelemente, keine physische Geräteleistung. Die Bindung gegen beide
Original-ZIPs ist separat dokumentiert. Der zusätzliche Kandidatenindex
für neun Modulfamilien und drei Touchgruppen ist nur eine Auswahlhilfe;
er behauptet keine tatsächliche Sichtung dieser weiteren Bilder.

Dieser erfolgreiche Quellencheckpoint gehört ausschließlich zum eingefrorenen
41-Core-Vertrag. Die spätere Puzzle-Lieferung mit 43 Core-Paaren und sechs
zusätzlichen Puzzle-PNG wird hier nicht freigegeben. Der Ordner erstellt keinen
Visual-Receipt, keinen Android-/APK-Nachweis und keine Pin- oder Ref-Änderung.
Eine vollständige Raster-/Hashprüfung ist keine Sichtung sämtlicher Bilder.
