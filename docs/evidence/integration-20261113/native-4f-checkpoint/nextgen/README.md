# Abgeschlossener Quellencheckpoint 4f34492

Dieser Ordner sichert ausschließlich Native-PR 160 auf Commit
4f3449253fd59023a2544432a178eb9efcafe4f9, Tree
189b7a66c731067559469e2503e3a190b337031d. Der einzige Parent ist 74c246d.
Der lokale Prüfcommit edb39e1 hat denselben vollständigen Tree.

## Tatsächlich bestandener Vertrag

Der originale Nextgen-Lauf 43466004918 ist im ersten Versuch erfolgreich
beendet. Alle sieben Pflichtjobs und der achte, ausschließlich
evidenzarchivierende Job sind SUCCESS. Das finale originale GitHub-Inventar
zeigt außerdem alle 15 Workflows dieses exakten Heads als erfolgreich.
Die 13 Zusatz-Workflows sind im benachbarten auxiliary-Ordner mit ihren
unveränderten Originalmetadaten gesichert; Graphics bleibt ein eigener
Nachweissatz unter graphics.

Der vor der Prüfung eingefrorene Host-Prüfer entspricht Reviewcommit
9e285e17a8cbd54f73cf5a14ccdad07c0ad29199 und dem treegleichen lokalen
3deae002. Sein verify_studio_delivery-Blob ist
b4a65471f71eabd723cb767ef722491ca1228025, SHA256
e41de3892c8a3756b90eb208272b686a03ac3e9253664975580d1de9d7c6d2b4.
Alle vier tatsächlichen Parserdateien und ihre Quellenbindung sind enthalten.

Der unveränderte Snapshot validator-9e285e/verify_studio_delivery.py.gz ist
verlustfrei mit gzip und mtime=0 gespeichert. Nach dem Entpacken ergeben
sich exakt die 41593 ursprünglichen Bytes einschließlich der abschließenden
Leerzeile und der oben genannte Rohhash. Die anderen drei Parser-Snapshots
bleiben unkomprimiert.

| Bestandteil | Verifizierter Originalnachweis |
| --- | --- |
| Core | 37 exakte Probe/Modus-Paare PASS |
| Studio-Raster | 24 verpflichtende Original-PNG |
| Touch | Sechs exakte Probe/Modus-Paare PASS |
| Touch-Raster | 32 Original-PNG: Werkstatt 6, Schatz 14, Bauwelt 12 |
| Aktuelle Quellen | Vier Capture-Trees exakt 189b7a66; vorherige/nachherige Dirty-Stempel leer |
| Native-Bundle | 136 dekodierte PNG: 126 aktuell und zehn ausdrücklich alte Vergleichsbilder |
| Native-Protokolle | Alle 96 enthaltenen Logs streng ohne die geprüften Engine-/Leakfehler |
| Bauwelt | BuildNextgen 62 headless und 70 tatsächlich gerendert |
| Bauweltdialog | 2016 headless und 2043 tatsächlich gerendert |
| Lernstudio | 183 tatsächliche Prüfungen |
| Werkstatt | 4129 headless und 4148 tatsächlich gerendert |
| Schatz-Touch | 1085 headless und 1114 tatsächlich gerendert |

Der zuvor auf 74c fehlgeschlagene Schritt Existing gameplay regression suite
ist auf 4f vollständig erfolgreich. Der getrennte vorangehende
Live-/Action-/Lasso-Schritt ist ebenfalls erfolgreich.
Alle 13 neu angeschlossenen Lifetime-Verbraucher sind im aktuellen Gameplay
an 19 verschiedenen Quell-Aufrufstellen durch 23 tatsächliche Freigabemarker
belegt. KartTests wartet vor Resume auf fünf Playbacks (65 ms) und vor dem
finalen PASS auf vier (114 ms). Der gerenderte Core-PlayerFullRoute wartet
zusätzlich auf zwei Playbacks (91 ms) und meldet erst danach PASS.
Diese neuen Beobachtungen klassifizieren nicht nachträglich die acht
Ressourcen des früheren nicht-verbosen 74c-CI-Fehlers.

## Originalarchiv und Erhaltung

Das unveränderte Native-Artefakt 14061435964 umfasst 169825813 Bytes,
SHA256 dab5b9e929c64adcd1a366f730a721a00d11c6ba0676b3218ed854d27529f565.
Originalrelease 444509776 / Asset 744488778:

https://github.com/Ullmann27/lumo-godot/releases/tag/integration-evidence-4f3449253fd59023a2544432a178eb9efcafe4f9-14061435964

Der Tag zeigt auf den exakten Commit. Release-Metadaten, Digest, Bytegröße
und der vollständige erfolgreiche Archivjob mit öffentlichem Rückdownload
und Bytevergleich sind gesichert. Dieses Archiv enthält kein APK.

Alle acht vollständigen GitHub-Joblogs und alle 148 vollständigen Logs aus
den heruntergeladenen Preview-, Legacy- und Native-Originalartefakten sind
verlustfrei mit gzip, mtime=0, enthalten. Vollständige Eintrags- und
PNG-Hashindizes binden jedes gespeicherte Original-ZIP. PNG- und ZIP-Payloads
werden hier nicht dupliziert. Die vier nicht zusätzlich heruntergeladenen
Komponenten-ZIPs sind in den originalen finalen Artefaktmetadaten mit ID und
Digest verzeichnet; ihre vereinten Originaleinträge sind im Native-Bundle.

manifest.json unterscheidet Original-API-Daten, unveränderte Logs und
Quellen, bereits erstellte Prüfberichte sowie abgeleitete Hashindizes.
Für jeden Payload nennt es ursprüngliche und gespeicherte Größe und SHA256.
Alle Manifest-Payloadpfade sind relativ. Unveränderte Rohdaten können
ursprüngliche absolute Runnerpfade und URLs enthalten; diese wurden nicht
bereinigt oder umgeschrieben. SHA256SUMS erfasst auch das Manifest.

## Bildsichtung und klare Grenze

Die Godot-Agent- und Root-Sichtungen des neuen Hundert-Bildes sind als
getrennte, unveränderte Beobachtungen enthalten. Beide tatsächlichen
Sichtungen erkennen beim oberen und unteren Gleichheitszeichen zwei
getrennte Balken. Root hat anschließend zwölf Originalbilder tatsächlich
geöffnet: alle neun Modulfamilien und alle drei Touchgruppen, zusätzlich
die kurze und die hochkante Bauzielansicht sowie Bauwelt und Garten.
Dieser neue Audit und seine Auswahl sind unverändert enthalten und wurden
erneut gegen die Original-PNG-Hashes, Größen und Modulzuordnung gebunden.
Die Beobachtungen behalten ausdrücklich die sichtbaren Scroll- und
Ellipsenhinweise bei. Der frühere Kandidatenindex ist nur ein Auswahlindex;
der spätere tatsächliche Audit ist für die zwölf Sichtungen maßgeblich.
Eine Raster-/Hashprüfung behauptet keine Sichtung sämtlicher Bilder.

Dieser erfolgreiche Quellencheckpoint ist ein historischer Zwischenstand
vor den folgenden Loop-/Village-Erweiterungen. Der neuere 41-Core-/Village-
Vertrag wird nicht rückwirkend auf 4f angewendet. Dieser Ordner erzeugt
keinen Visual-Receipt, keine APK-/Android-Abnahme, keine Pin-Änderung und
keine Freigabe einer späteren Quelle.
