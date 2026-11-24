# Godot: vollständige Zweiginventur und Fahreranschluss

Stand: 22. November 2026. Ausgangspunkt ist der tatsächlich für APK 2065 vorgesehene Godot-Commit `25fc4ff1f43c0adeb2c56b67ad4a9611922aac8a`. Diese Prüfung ergänzt die ältere `docs/ZWEIG_INVENTUR_2026-11-19.md` um frische Branch-Heads, lokale Quellvergleiche und neue Laufzeitbelege. Sie ist kein Nachweis eines bereits fertigen Android-Builds.

## Was angeschlossen wurde

**Borin und Yuki waren bereits vollständig als Produktionsmodelle vorhanden, aber nicht auswählbar.** Der gemeinsame Fahrerkatalog enthält nun auch `badger` und `cat`. Verwendet werden die bestehenden Namen, Menüporträts, GLB-Modelle, LODs und der vorhandene Produktionsadapter. Es wurden keine Ersatzfiguren erzeugt.

| Fahrer | ID | Freischaltung |
|---|---|---:|
| Lumo | `fox` | sofort; bestehendes Original-Lumo-Modell |
| Nova | `rabbit` | bestehende 6 Sterne |
| Milo | `otter` | bestehende 12 Sterne |
| Frosch | `frog` | sofort |
| Borin | `badger` | sofort |
| Yuki | `cat` | sofort |

Für Borin und Yuki fand die Git-Historiensuche keine vorgesehenen Katalog- oder Sternenwerte. Entsprechend dem Integrationsauftrag erhalten beide keine zusätzliche Sternensperre. Vorhandene IDs und Freischaltwerte bleiben erhalten; der Gegnerpool wird durch die Fahrerauswahl nicht geändert. Der Flutter-Host führt laut separatem Host-Abgleich keinen zweiten Fahrerkatalog und keine entsprechende Fahrer-Whitelist.

Der neue Test `kart_extra_drivers_regression.gd` durchläuft für beide Figuren die tatsächliche Fahrerkarte und den sichtbaren Startknopf, startet ein Windwerk-Rennen mit fünf Rivalen, prüft das sichtbare importierte Modell, speichert die Fahrt, zerstört die Szene und setzt dieselbe Fahrt nach neuer Szenenerzeugung fort. Dabei wurde ein weiterer echter Fehler sichtbar: Der verzögerte Jubel-Callback hielt eine bereits beim Rennstart freigegebene Vorschaufigur fest. Ein typisierter `WeakRef` prüft jetzt deren Lebensdauer, bevor der Callback das Jubeln beendet.

Die vorhandene Produktionsmodell-Regression umfasst zusätzlich zu den sechs Gegnermodellen jetzt auch die spielbaren Arten Otter, Dachs und Katze. Ihre Prüfung aller LODs und Animationsverträge bleibt Bestandteil des APK-Gates.

## Umfang der Zweiginventur

[godot-branch-inventory.json](godot-branch-inventory.json) dokumentiert **301 vor Beginn dieser Integration vorhandene Zweige mit 285 unterschiedlichen Commit-Heads**. Der anschließend angelegte Lieferzweig `integration/lumo-complete-20261122` ist nicht seine eigene Quellgrundlage.

| Verhältnis zur Ausgangslinie | Zweige | Bewertung |
|---|---:|---|
| Vorfahren | 196 | Historisch bereits enthalten |
| Identischer Head | 1 | Aktuelle Ausgangslinie |
| Abweichende Historie | 103 | Exakte Heads und geänderte Quellpfade mit den früher dokumentierten Familienentscheidungen abgeglichen |
| `gh-pages` | 1 | Getrennte Website-Historie ohne gemeinsamen Spiel-Commit |

Alle Heads wurden nach dem GitHub-Vergleich zusätzlich anhand lokal geladener Git-Objekte überprüft. Die 103 abweichenden Zweige wurden für `scripts/`, `scenes/`, `assets/` und `tools/` vollständig gegen ihre Merge-Basis verglichen. Damit sind auch die drei auf 300 Dateien begrenzten GitHub-Vergleichsansichten abgedeckt. In 1.406 Dateibeobachtungen waren 597 Blobs aktuell identisch, 365 bereits in der Ausgangshistorie enthalten und 444 abweichend. Letztere entsprechen 253 verschiedenen Quellfassungen; ein historisch vorhandener Blob wird ausdrücklich nicht automatisch als Nachweis gleicher heutiger Spielwirkung gewertet.

Die verbleibenden Varianten sind in den 37 früheren Familienentscheidungen und den einzelnen Branch-Datensätzen nachvollziehbar: ältere Sprung- und Gegnerlogik, durch neuere Fassungen ersetzte Menüs und Schachregeln, Diagnosewerkzeuge, Aufnahmehilfen und bewusst verworfene Gestaltungsvorschläge. Die alternative `chat3`-Lumo-Figur wird nicht über das Originalmodell gelegt. Sie und ihre Originaldateien bleiben in ihren bestehenden Zweigen erhalten. Auch früher hinter neuen Leitplanken unsichtbare Tunnel-Leitteile werden nicht erneut blind eingesetzt. Es wurden keine Quellzweige gelöscht.

Die bereits integrierten Agent-Zweige für Feinschliff, Garage, Lauf, Riesengarten, Sternenpost, Streckenprüfung und Tutor sind echte Vorfahren der Ausgangslinie. Die drei Abenteuer-Parcours, die Präzisionssprünge und Windwerk-Prüfungen sowie das LAN-Protokoll besitzen ausführbaren Code und eigene Tests. Für fehlende zusätzliche Menü-Vorschaufilme ergab die Zweigprüfung keine weiteren bereits fertig entwickelten, anschließbaren Dateien; es wurden keine neuen Filme als angeblich vorhandene Inhalte ausgegeben.

## Frische Prüfbelege

Engine: **Godot 4.6.3**, `4.6.3.stable.official.7d41c59c4`, Linux headless. [godot-runtime-checks.json](godot-runtime-checks.json) enthält Umfang, Laufzeiten, Dateihashes und die verlinkten Originalprotokolle.

| Prüfung | Ergebnis | Aussage |
|---|---|---|
| Zusätzliche Fahrer | 79/79, bestanden | Auswahl, Menügeometrie bei 390×844 und 1280×720, Rennstart, Modell, Speichern und Fortsetzen für Borin und Yuki |
| Arena | 16/16, bestanden | Echte Szene, Punkte, Ende und Lebensdauer |
| Abenteuer-Parcours | alle 3 Welten bestanden | Nova und Milo erreichen jeweils das Ziel; Alternativwege werden geprüft |
| Präzisionssprung | 55/55, bestanden | Berechnung und Sprungverträge |
| Windwerk-Prüfungen | 106/106, bestanden | Laufzeitanschlüsse der Windwerk-Aufgaben |
| LAN, zwei Prozesse | 42 Prüfungen, bestanden | ENet-Host/Gast auf localhost, Rennen und Verbindungsabbruch |
| Projektstruktur | 120 bestanden, 0 Warnungen, 0 Fehler | `tools/validate_project.py` |

Arena, Parcours, Präzisionssprung, Windwerk und LAN wurden vor dem zusätzlichen Fahreranschluss geprüft; der neue Fahrer-Lifecycle-Test danach. Der vollständige verpflichtende Build-Gate überprüft anschließend die zusammengeführte Fassung. Die neue Testdatei besteht `gdlint` und `gdformat --check`. Die drei berührten Altdateien besitzen schon in der Ausgangsfassung Format-/Lint-Befunde; der Patch erhöht deren Zahl nicht und formatiert keine fremden Bereiche um.

**Offene Nachweisgrenzen:** Der schwere Einzelprozess-Test `kart_lan_race_regression.gd` wurde ohne vorherige Assertion durch Signal 9 beendet und wird hier nicht als bestanden gezählt. Ein früherer gleichzeitig laufender Windwerk-Versuch wurde ebenfalls beendet; der dokumentierte serielle Wiederholungslauf bestand. Die erfolgreiche LAN-Prüfung benutzt zwei lokale Prozesse, keine zwei Android-Geräte. Die neue Fahrerprüfung kontrolliert sichtbare Szenenknoten und Layoutmaße headless; sie belegt keine gerenderten Bildpixel, reale Touchbedienung, Audioqualität oder 60 FPS auf einem Telefon. PCK-Inhalt, APK-Bau und Android-Abnahme haben eigene Build-Belege und dürfen aus diesen Laufzeiten nicht abgeleitet werden.
