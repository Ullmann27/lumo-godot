# Sichtprüfung der tatsächlichen Rennansichten

Prüfung am 15. November 2026: Alle 22 Bilder aus
`evidence/lumo_kart_runtime/review/*_{entry,inside}.png` wurden einzeln
visuell geöffnet und beurteilt. Der zugehörige Index benennt
`scenes/games/kart_island.tscn`, Godot 4.6.3, X11 und 1280 × 720 Pixel.
Die Ansichten enthalten die tatsächliche Renn-HUD, Spieler, Rivalen und
das vorhandene Streckendekor.

## Ergebnis nach gezielter Nachprüfung

**Alle elf Themen sind in beiden abschließend geprüften Ansichten
visuell freigegeben hinsichtlich Straßenanschluss, freier Fahrspur und
geschlossener Tunnelwirkung.** Die erste Bildserie enthielt einen
Beleuchtungsbefund bei Volcano Night. Dieser wurde durch eine lokale
Lichtkorrektur behoben und anhand zweier neuer nativer Bilder überprüft.

| Thema | Eingang | Innenraum | Sichtbefund |
|---|---|---|---|
| Zauberwald | PASS | PASS | Wurzelbögen und Wandflächen folgen der Kurve; durchgehende Straße und sichtbarer Ausgang. |
| Bergwelt | PASS | PASS | Gebankte Straße setzt sich ohne sichtbare Stufe fort; steinerne Bögen und Kristalle bleiben außerhalb der Fahrspur. |
| Holo City | PASS | PASS | Geschlossene technische Hülle; seitliche Leuchtfelder und durchgehende Fahrbahn. Der bestehende cyanfarbene Rennring verdeckt im Eingangsbild einen Teil des Portals. |
| Crystal Canyon | PASS | PASS | Portalstützen, Kristallgruppen und Innenhülle sind lesbar; keine sichtbare Unterbrechung des Straßenbelags. |
| Jungle Temple | PASS | PASS | Durchgehender gebogener Innenraum; Pfeiler und Pflanzen stehen hinter den Straßenrändern. |
| Candy Cloud | PASS | PASS | Pastellfarbener Tunnel mit erkennbarer Tiefe; die Regenbogenstraße läuft durchgehend bis zum Ausgang. |
| Volcano Night | PASS nach Korrektur | PASS nach Korrektur | Bogenform, Wandtextur und Basaltspitzen sind in den neuen Bildern erkennbar; die Nachtstimmung bleibt erhalten. |
| Winter Sprint | PASS | PASS | Heller Eisraum, erkennbare Deckenformen und seitliche Kristalle; freie, zusammenhängende Fahrbahn. |
| Galaxy Ringway | PASS | PASS | Geschlossene technische Röhre mit Wandfeldern und Zierringen; freie Strecke bis zum Ausgang. |
| Desert Drift | PASS | PASS | Sandsteinfarbener Innenraum, Kurve und Ausgang gut lesbar; der cyanfarbene Rennring verdeckt einen Teil der Eingangsansicht. |
| Learning Lab | PASS | PASS | Helle, zusammenhängende Laborhülle mit seitlichen Ornamenten; keine sichtbare Straßenüberdeckung. |

In keinem der 22 Bilder wurde eine sichtbare Bodenlücke oder eine
Überdeckung der Fahrspur durch altes Landschafts- beziehungsweise
Gebäudedekor festgestellt. Leuchtende Rennringe, Sammelsterne, Bodenfelder
und Richtungszeichen bleiben als vorhandene Spielelemente sichtbar.
Die unmittelbar sichtbaren Portalränder und Straßenanschlüsse zeigen
keinen offenen Spalt. Breite Geländeansichten außerhalb der
Verfolgerkamera sind in dieser Bildserie nicht enthalten.

## Behobener Befund: Volcano Night

In der ersten Fassung von `volcano_night_entry.png` und
`volcano_night_inside.png` waren die leuchtenden Fahrbahnränder, Fahrzeuge
und der Ausgang erkennbar. Große Bereiche der Tunnelwände und der Decke
gingen jedoch in Schwarz über. Das beeinträchtigte die sichtbare Form des
gelieferten Basalttunnels.

Der Capture aktiviert den LightSocket-Pool ausdrücklich nach der
Kamerapositionierung und wartet drei tatsächliche Renderbilder.
Die anfängliche Vermutung eines noch nicht aktivierten Pools ist damit
ausgeschlossen. Ein gezielter Laufzeit-Probeaufbau bestätigt vier aktive
Lichter auf den korrekten Mounts, etwa 6,19 m über der Straße.
Ihre Entfernungen zum Straßenpunkt in der Tunnelmitte betragen
6,89 / 10,92 / 6,89 / 16,26 m. Bei der bisherigen 11-m-Reichweite trägt
einer der vier Punkte dort nicht und ein weiterer nur am Rand seiner
Reichweite bei. Die globalen Nachtwerte bleiben ACES, Belichtung 0,95
und Kontrast 1,12.

Ein ausschließlich für Volcano Night freigegebener lokaler
Beleuchtungspatch wurde anschließend umgesetzt:

| Lichtwert | Vorher | Nachher |
|---|---:|---:|
| Energie | 1,6 | 4,8 |
| Reichweite | 11 m | 15 m |
| Dämpfung | 0,80 | 0,60 |
| Tatsächliche Lichtfarbe | #ee9548 | #f9c896 |
| Maximal aktive Lichter vollständig / mobil | 4 / 3 | 4 / 3 |
| Schatten | aus | aus |

Die hellere warme Farbe entsteht durch eine Mischung der vorhandenen
Socket-Farbe mit 65 Prozent Warmweiß. Mounts, Materialien, Geometrie und
globale Environment-Einstellungen bleiben unverändert. Der reale
Probeaufbau bestätigt die neuen Werte in
`volcano_lighting_after.json`; die Ausgangswerte stehen in
`volcano_lighting_before.json`. Zusätzlich bestätigt
`volcano_lighting_after_mobile.json` genau drei aktive, unverschattete
Lichter auf der mobilen Stufe.

Die beiden neu aufgenommenen nativen Rennansichten wurden anschließend
erneut einzeln geöffnet. Am Eingang sind nun die Bögen, die Wandtextur
und die seitlichen Basaltspitzen sichtbar. Im Innenbild ist die umgebende
Hülle lesbar, während weiter entfernte Flächen im nächtlichen Schatten
bleiben. Fahrbahn, Randführung und Ausgang bleiben zusammenhängend.
Der Beleuchtungsbefund ist damit visuell geschlossen. Die übrigen
20 Bilder wurden nicht ersetzt.

## Nachvollziehbarkeit

`evidence/lumo_kart_art/tracks/runtime/visual_qa.json` enthält die
SHA-256-Hashes der 22 abschließend freigegebenen Bilder, die ursprünglichen
Hashes der beiden ersetzten Volcano-Aufnahmen, die Einzelbewertungen
und den behobenen Befund. Insgesamt wurden 24 Bildansichten manuell
geprüft. Die Sichtprüfung ergänzt die bereits ausgeführten Geometrie-
und Physiknachweise; sie ersetzt diese nicht und behauptet keine
gemessene Gerätebildrate.
