# Studio 2020: sichtbare Spielfigur und zugänglicher Hinweis

## Tatsächlich beobachteter Ausgangsfehler

Der Native-Lauf [43565059832](https://github.com/Ullmann27/lumo-godot/actions/runs/43565059832) auf `acf51d3bd2997c4b731e9a48e1791e05e756a132` bestand alle neun Jobs. Die anschließende tatsächliche Sichtprüfung von Root und drei Agenten zeigte trotzdem einen konkreten Fehler: In der Schatzsuche verdeckte das dauerhafte Aufgabenfeld Lumo am Start weitgehend, sowohl im kompakten 640×320-Format als auch im 2400×1080-Querformat mit seitlichem Displayausschnitt. Der allgemeine weiße Erkundungshinweis verlor auf heller Architektur zusätzlich Kontrast.

Die unveränderten ursprünglichen Bilder und die zurückgehaltene Freigabe sind in [Evidenzcommit d0ba260d](https://github.com/Ullmann27/lumo-lernen/blob/d0ba260dd55ec2654d25871973c696264be0f3ad/docs/evidence/studio-2020-acf51-review-root-20261114/README.md) erhalten. Ein erfolgreicher Jobstatus wurde nicht als visuelle Freigabe ausgegeben.

## Enge Produktkorrektur

In kurzem Querformat ersetzt ein großer **Hinweis**-Knopf das dauerhafte Feld. Er öffnet den vollständigen vorhandenen Aufgabentext im bestehenden scrollbaren Dialog. **Weiter erkunden** schließt den Dialog und kehrt ohne Questfortschritt oder zusätzliche Belohnung in dieselbe Welt zurück. Bereits pausierte oder offene Modalansichten werden nicht durch einen zweiten Hinweisdialog ersetzt.

In höheren Ansichten bleibt der bisherige direkte Aufgabentext sichtbar. Die allgemeine Erkundungsmeldung besitzt nun einen dunklen Hintergrund. Ihre Position hält die projizierte Spielfigur und die tatsächlichen Bewegungs-/Sprung-/Interaktionsflächen frei. Im Hochformat ist ein Abstand von zwölf logischen Bildpunkten zur oberen Grenze der unteren Steuerflächen vorgesehen.

Der unabhängige Quellenvergleich bindet die Änderungen an `_ui`, `_layout` und das ergänzte `_show_clue`. Alle 22 anderen Funktionen einschließlich Kamera, Physik, Quest, Save, Belohnung und Rückkehr bleiben textgleich. Die Weltgeometrie und die vorhandenen Modelle werden nicht ersetzt.

Zusätzlich korrigiert `build_settlement_world.gd` ausschließlich die Rückerstattungsbeschriftung bei genau einer Münze: **1 Münze**. Kosten, Mengen, Regeln und Speicherformat bleiben unverändert.

## Tatsächlich ausgeführte lokale Prüfungen

Der finale neue Treasure-Test wurde gegen beide Quellstände ausgeführt:

| Lauf | Tatsächliches Ergebnis |
|---|---|
| Unverändertes acf51-Produkt, identischer finaler Regressionstest | 3.221 Prüfschritte, 40 gezielte Fehler, Exit 1 |
| Korrigiertes Treasure-Produkt, derselbe Test | 3.341 Prüfschritte, 0 Fehler, Exit 0 |
| Unveränderte vorhandene Treasure-Dichteprüfung auf dem Endpatch | 1.085 Prüfschritte, 0 Fehler, Exit 0 |
| Tatsächlicher finaler X11-Rendererlauf | 3.351 Prüfschritte, 0 Fehler, Exit 0; fünf Original-PNGs |

Die Zahlen bezeichnen einzelne Prüfbedingungen innerhalb der benannten Läufe, keine Tausenden unabhängiger Spiele- oder Gerätetests. Die zuerst unvollständige private Runtime und ein später verworfener Portrait-Zwischenstand bleiben getrennt dokumentiert. Ein fehlender Preload wird nicht als gültiger Rotnachweis gezählt.

Der Test liest die echte Projektion der Fox-Meshgeometrie und die tatsächlichen HUD-/Touchrechtecke. Er prüft Frischstart und Wiederaufnahme eines ausdrücklich deklarierten Altstands in fünf Formaten. Dazu gehören echte Touchereignisse zum Öffnen und Schließen des Hinweises, der vollständige Text, nach Scrollen wirklich exponierte Touchflächen ab 48 dp sowie unveränderte Questdaten. Das Renderer-Report enthält zehn Zustandsbeobachtungen und genau fünf an Bytes und Bildmaße gebundene Aufnahmen.

Die fünf finalen Bilder wurden von C, unabhängig von A und zusätzlich von Root tatsächlich geöffnet. Lumo bleibt in den zuvor problematischen Ansichten sichtbar. Im Portrait wurde der zunächst zu knappe Abstand zur Sprungfläche korrigiert; der finale Readback weist etwa 12,004 dp aus. Bestehende gekürzte Hochkantüberschrift und umbrochener Entdeckungszähler bleiben ausdrücklich sichtbare Grenzen.

## Additive gemeinsame Abnahme

Die vorhandenen 20 Studio-Gate-Aufrufe und ihre Budgets bleiben erhalten. Die vier bisherigen Treasure-Titelaufnahmen werden durch `treasure-title-landscape-cutout.png` ergänzt. Zusammen mit den bisherigen Originalbildern verlangt der Studio-Roster damit 54 PNGs. Alle bisherigen Gesicht-, Movie- und Vier-Gewinnt-Verträge bleiben verbindlich.

Der Host-2020-Bildvertrag verlangt die zusätzliche Aufnahme ausdrücklich. Ein tatsächlich ausgeführter negativer Hostvertrag zeigte, dass die vorherige Anforderung die vier alten Titelansichten noch akzeptierte. Mit der zusätzlichen Pflichtaufnahme bestehen alle elf einschlägigen Hostverträge; die bisherigen Funktionen bleiben unverändert.

Diese lokalen Nachweise ersetzen weder den neuen vollständigen GitHub-Lauf des gemeinsamen Folgecommits noch die Sichtprüfung seiner eigenen Originalbilder. Erst danach folgen der neue exakte Hostpin und die Android-/Update-/Creative-/C4-Prüfungen. Main bleibt unverändert; eine physische Fold7-, Temperatur-, Latenz- oder 60-FPS-Abnahme liegt nicht vor.

## Gebundene Produkt- und Testquelle

- Treasure-Produkt SHA256: `e68fc85498b76fb7b482417a1bf6b64410a53d2f018fec7771e263ea60fa5447`.
- Finale Treasure-Regression SHA256: `ea6087ef56a96d585382f4228661d753121152aa249c4a5afdc99d2e946941ea`.
- Settlement-Sprachkorrektur SHA256: `f1c1633dfa9b35895c2c51e943fead257e9621169b0c618e3b8ce8bfbc9850a0`.

Die konkreten neuen Commit-/Runidentitäten werden durch Git und die tatsächlichen Workflow-Originalmetadaten gebunden, nicht durch einen im Voraus erfundenen Erfolgsvermerk.
