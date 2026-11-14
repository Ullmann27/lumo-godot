# Abgeschlossene lokale Followup-Nachweise

Dieses Paket bewahrt die bereits ausgeführten lokalen Prüfungen und Quellreviews
für die veröffentlichten Loop-/Village-Lieferungen und den anschließend
reparierten Dorf-Touch-/Dialoganschluss. Beim Sichern wurden keine neuen
Spiele-, Renderer-, Workflow- oder Androidtests ausgeführt.

## Gültiger Dorfvergleich

Maßgeblich sind ausschließlich die unveränderten Originalbelege unter
evidence/village-surface-comparison/published-after-import/ und /repaired/.
Nach sauberem Editorimport liefen beide Seiten mit exakt derselben touchfähigen
Probe. Die vollständigen 1.224 Quellhashes blieben jeweils während des Laufs
unverändert. Auch zwischen den beiden Ausgangslisten unterscheidet sich genau
eine Datei: scripts/creative/build_settlement_world.gd.

| Quelle | SHA256 | Originaler Befund |
|---|---|---|
| Identische Probe | 1ac6dcd8ba6c72d637ad575802fb46654d28ea541c865c053eb478fed7b1ffde | Auf beiden Seiten gleich |
| Veröffentlichtes Produkt aus 176184c | cd5e7a41991ac8591408b86094db182be85124a8ef4a48b28bf3717011bf576e | FAIL 125, sieben Reachability-/Resizefehler |
| Repariertes Produkt | a8b5b310104281f6fb9c84901c3d83ee5d3382b38ef2bd418a44ff6b83d39ae0 | PASS 223 |

Die beiden maßgeblichen Engineprotokolle enthalten keine Engine-/Script- oder
Parsefehler. Die Reparatur verbindet echte Toolbar-/Dialog-Wischgesten mit
einem HUD-Startschutz und passt dieselbe bereits geöffnete Windowinstanz nach
Größen- und Dichteänderung an. Die vollständigen Rohlogs, Ergebnisse,
Touch-Zielmessungen und Vorher-/Nachherlisten bleiben erhalten.

## Weitere abgeschlossene Nachweise

| Bereich | Erhaltenes Ergebnis | Grenze |
|---|---|---|
| feedback-loop | LOGIC_PASS 56; drei reale Playbacks nach 82 ms freigegeben | Ein vorhandener headless logic-only Lauf; Renderer ausstehend |
| village-consumers | Economy 337, Art 2259, ursprüngliche Scene 19 erfolgreich | Unveränderte veröffentlichte Probes vor der zusätzlichen Touch-/Resizeabdeckung |
| build-integration | Veröffentlichte BuildPlay 71, ursprüngliche BuildPlay 62, Density 2016 erfolgreich | Damaliger kombinierter Producer-Snapshot; vollständige Quellbindung erhalten |
| village-preservation-final | Classic SettlementPlay 127 erfolgreich | Finales repariertes Produkt |
| village-preservation-final | Headless-Capture abgelehnt: Exit 1, kein PNG, kein PASS | Beabsichtigter Negativnachweis |
| village-workflow-check | actionlint Exit 0 und leere Originalausgabe | Originalprotokoll enthält keine Workflow-Quellhashes |
| village-source-review | Unabhängiger statischer Review der beiden oben genannten Hashes | Keine vom Reviewer ausgeführten Village-Laufzeittests |
| village-touch-baseline-import | Editorimport Exit 0 ohne Fehler | Voraussetzung des gültigen Originalprodukt-Vergleichs |

Die frühe Loop-/Village-Integration wurde auf lokalem c88b100 mit gestagtem
Village-Baum geprüft. Ihre ursprünglichen Head-/Tree-/Producerangaben bleiben
unverändert. Diese Resultate werden weder in Ergebnisse für den späteren
Reparaturstand noch in CI-Abnahmen für 4f oder spätere Quellen umbenannt.

## Diagnosehistorie

diagnosis/ enthält nur die kleinen unveränderten Ergebnisdateien früherer
Prototypen. diagnosis/index.json erklärt jeden Fall:
village-surface-v1 hatte zusätzlich einen freigegebenen Windowzugriff;
village-surface-published-failure und village-surface-scroll-fix hatten noch
keinen vollständigen Desktop-Touchscreen-Vertrag. Der erste comparison/published
brach wegen fehlender Font-Importmetadaten ab. Keiner dieser Fälle gilt als
kausaler roter Produktvergleich. Dafür zählt allein published-after-import.

## Verlustfreie Aufbewahrung und Integrität

evidence/ spiegelt alle ausgewählten Originalordner. Vollständige Logs,
Quelltext-/Patchbelege und große Quellenlisten sind deterministisch gzip-
komprimiert: mtime 0, leerer gzip-Dateiname, Kompressionsstufe 9.
Bereits vorhandene gzip-Originale wurden bytegleich übernommen. Originale
kleine JSON- und Textdateien bleiben unverändert.

manifest.json ordnet jede Datei ihrem ursprünglichen absoluten und relativen
Pfad sowie dem fachlichen Umfang zu. Es nennt Original- und gespeicherte
Bytegrößen/Hashes; bei vorhandenen gzip-Dateien zusätzlich den entpackten
Originalhash. Jeder neue gzip-Roundtrip und jede gespeicherte Datei wurden
gegen die Originalbytes geprüft. Die stabilen Agentenmanifeste, deren
deklarierte Objekte und die vorhandene Loop-Hashliste wurden vor dem Kopieren
überprüft. Alle ausgewählten Quelldateien waren nach dem Kopieren unverändert.

Die ursprünglichen Untermanifeste und README-Dateien bleiben selbst ebenfalls
unverändert; ihre damaligen relativen Dateinamen beziehen sich auf den
Originalordner. Die vollständige Zuordnung zu den hier komprimierten Namen
steht im neuen übergeordneten Manifest.

XDG-Daten-, Cache-, Konfigurations- und Runtimeverzeichnisse sind ausgeschlossen.
Es gibt keine neuen Rendererbilder, keine Androidabnahme, kein Receipt und
keine Behauptung eines abgeschlossenen Native-Gesamtlaufs. Die getrennten
aktuellen CI-Nachweise bleiben eigenständige Quellencheckpoints.
