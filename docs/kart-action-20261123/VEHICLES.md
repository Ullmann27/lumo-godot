# Lumo Kart: Fahrzeuge, Teile und Fahrwerte — 23.11.2026

## Was hinzugekommen ist

Neun neue, kostenlos montierbare Leistungsteile ergänzen die neun vorhandenen Steckplätze. Der Katalog wächst von **56 auf 65 Optionen einschließlich Serienteilen**. Bestehende Teile, Sternpreise, Freischaltungen und Spielstände bleiben erhalten. Die 14 bestehenden Fahrzeuge erhalten zusätzliche Splitter, beleuchtete Seitenschweller und Diffusoren; die neuen Teile besitzen eigene tatsächlich montierte 3D-Geometrie.

## Exakte Wirkungen der neun neuen Teile

Die Faktoren stammen unmittelbar aus `kart_part_catalog.gd::_evolution_parts()`. Vergleich: dasselbe Fahrzeug mit Serienteil im betreffenden Steckplatz; andere Teile und Feinregler neutral. Multiplikative Faktoren sind keine addierbaren Prozentpunkte. Bei Kombinationen gelten die unten genannten gemeinsamen Grenzen.

| Neues Teil | Wirkung | Abwägung |
|---|---|---|
| Axial-Antrieb | Beschleunigungsfaktor ×1,22 | Endtempo ×0,96; Boost-Zuschlagsfaktor ×0,95 |
| Performance-Reifen | Haftungsrate ×1,14; Bremsverzögerung ×1,06 | Geländefaktor −0,11 absolut |
| Venturi-Flügel | Haftungsrate ×1,20 | Endtempo ×0,95; Fluglenkrate ×0,88 |
| Superkondensator | Boost-Dauer ×1,42; Drift-Laderate ×1,07 | Boost-Zuschlagsfaktor ×0,88; Endtempo ×0,98 |
| Adaptive Dämpfer | Beruhigungszeit nach Landung ×0,50; Haftungsrate ×1,08 | Beschleunigung ×0,94 |
| Vector-Lenkung | Lenkrate ×1,18; Haftungsrate im Drift ×1,10 | Endtempo ×0,975 |
| Keramikbremse | Bremsverzögerung ×1,30; Haftungsrate ×1,03 | Beschleunigung ×0,96 |
| Doppelkupplung | Beschleunigung ×1,16; Drift-Laderate ×1,08 | Endtempo ×0,96 |
| Carbon-Chassis | Beschleunigung ×1,12; Fluglenkrate ×1,20 | Landungsberuhigung ×1,12; Stabilitätsfaktor −0,10 absolut |

**Wichtig für die Interpretation:** Eine um 30 % größere Bremsverzögerung bedeutet nicht automatisch einen um 30 % kürzeren Bremsweg. Der Bremsweg hängt zusätzlich von Haftung und der Integration der Bewegung ab. Eine um 7 % größere Drift-Laderate verkürzt die Ladezeit; sie verlängert sie nicht. Der Boost-Zuschlagsfaktor verändert den Aufschlag in `1 + 0.42 × boost_power`, nicht direkt das gesamte Turbo-Tempo.

Die Werkstatt berechnet deshalb **alle zwölf tatsächlichen Prüfstandswerte** für die vollständige Auswahl: Endtempo, 0–100 km/h, Bremsweg aus 72 km/h, Kurvenradius, seitliches Rutschen, Zeit bis zum ersten Drift-Turbo, Turbo-Dauer, Turbo-Tempo, Geländetempo, Fluglenkung, Landungsberuhigung und Tempo nach einem Rempler. Sie zeigt Montiert → Vorschau einschließlich relativer Änderung und nennt erreichte Kombinationsgrenzen. Dieselben Faktoren und Fahrformeln verwendet das Rennen.

### Im echten Godot-Prüfstand gemessene Einzelteilwerte

Referenz ist ausschließlich **Comet, ohne Ausbaustufen, andere Leistungsteile oder Feinregler**, auf ebener Straße ohne Items, Aufholhilfe oder Streckeneffekte. Jeder Vergleich beginnt beim vollständigen Serienkart. Die folgenden Zahlen stammen aus den nativen `[KartEvolutionPart]`-Datensätzen von [Lauf 45133703768](https://github.com/Ullmann27/lumo-godot/actions/runs/45133703768), Quelle `447ff8956a2942bafae775a9be62edb339f64cca`, und sind wie die Werkstatt gerundet:

| Einzeln montiertes Teil | Gemessener Vorteil: Serie → Teil | Gemessene Abwägung: Serie → Teil |
|---|---|---|
| Axial-Antrieb | 0–100 km/h: **0,70 → 0,58 s** | Endtempo **173 → 166 km/h**; Turbo-Tempo **245 → 232 km/h** |
| Performance-Reifen | Rutschen **5,01 → 4,18 m**; Bremsweg **3,0 → 2,7 m** | Geländetempo **93 → 74 km/h** |
| Venturi-Flügel | Rutschen **5,01 → 3,68 m** | Endtempo **173 → 164 km/h**; Fluglenkung **46 → 40°** |
| Superkondensator | Turbo-Dauer **1,00 → 1,42 s**; Drift-Turbo nach **0,42 → 0,38 s** | Turbo-Tempo **245 → 232 km/h**; Endtempo **173 → 169 km/h** |
| Adaptive Dämpfer | Landungsberuhigung **0,23 → 0,11 s** | 0–100 km/h: **0,70 → 0,75 s** |
| Vector-Lenkung | Kurvenradius **16,7 → 13,8 m** | Rutschen beim normalen Volleinlenken **5,01 → 5,73 m**; Endtempo **173 → 168 km/h** |
| Keramikbremse | Bremsweg **3,0 → 2,4 m** | 0–100 km/h: **0,70 → 0,73 s** |
| Doppelkupplung | 0–100 km/h: **0,70 → 0,60 s**; Drift-Turbo nach **0,42 → 0,38 s** | Endtempo **173 → 166 km/h** |
| Carbon-Chassis | 0–100 km/h: **0,70 → 0,63 s**; Fluglenkung **46 → 55°** | Landungsberuhigung **0,23 → 0,25 s**; Resttempo nach Rempler **79 → 72 %** |

Die ungerundeten Werte bleiben in `vehicle-evolution-regression.json::single_part_comet` erhalten. Beispiel: Serien-Comet erreicht **172,692 km/h**, mit Axial-Antrieb **165,78432 km/h**. Diese Arcade-Spielwerte sind keine Messungen eines realen Autos.

Die zwei Balken auf den Fahrzeugkarten verwenden zusätzlich `workshop.multipliers(id)`: Endtempo und tatsächliche Lenkrate ändern sich nach dem Montieren mit. Eine halbe Balkenlänge entspricht dem neutralen Serien-Comet; die Karten zeigen keine erfundenen neuen Stat-Punkte. Der Tooltip nennt das montierte Endtempo und die Lenkrate ausdrücklich.


## Kombinationen und Grenzen

Alle montierten Teile und alle fünf Feinregler werden gemeinsam berechnet. Die folgenden Grenzen gelten **relativ zum Grundprofil einschließlich vorhandener Ausbaustufen**, nicht als absolute Obergrenze für jedes Fahrzeug:

| Fahrfaktor | Untergrenze | Obergrenze |
|---|---:|---:|
| Endtempo | 0,84 | 1,12 |
| Beschleunigung | 0,65 | 1,45 |
| Bremsverzögerung | 0,65 | 1,45 |
| Lenkrate | 0,75 | 1,30 |
| Haftung | 0,65 | 1,40 |
| Drift-Laderate | 0,65 | 1,60 |
| Drift-Haftung | 0,75 | 1,35 |
| Fluglenkung | 0,70 | 2,00 |
| Landungsberuhigung | 0,30 | 1,80 |
| Boost-Zuschlag | 0,70 | 1,45 |
| Boost-Dauer | 0,65 | 1,55 |

Additive Änderungen sind für Gelände auf **−0,15 bis +0,18** und Stabilität auf **−0,12 bis +0,18** begrenzt. Anschließend wird der gesamte Geländefaktor auf **0,20 bis 0,92**, der gesamte Stabilitätsfaktor auf **0,20 bis 0,85** begrenzt. Mehrere Teile können dadurch dieselbe Grenze erreichen; ihre unbeschränkten Prozentwerte dürfen nicht einfach als Endergebnis addiert werden.

## Umfang der tatsächlichen Prüfung

- **52.706.752** ist die rechnerische Anzahl auswählbarer Steckplatzkombinationen pro Fahrzeug, ohne Feinregler, Farben oder Ausbaustufen. Das sind keine 52 Millionen gefahrenen Tests; durch Begrenzungen können verschiedene Auswahlen dieselben Faktoren ergeben.
- Die Regression bestimmt die mathematischen Minima und Maxima jedes positiven multiplikativen Fahrfaktors über sämtliche unabhängigen Teileauswahlen und Feinregler.
- Zusätzlich prüft sie **1.877** konkrete Kombinationen aus jeweils zwei unterschiedlichen Steckplätzen.
- **5.760** vollständige Auswahlen mit Feinreglern werden deterministisch geprüft: 4.096 für Comet und je 128 für die weiteren 13 Fahrzeuge.
- Vier Konfigurationen fahren tatsächlich durch `kart_island._drive_player`; Beschleunigung, Bremsen, Lenken und Drift-Ladung werden gegen die gemeinsamen Formeln geprüft.
- Alle 14 Produktionsfahrzeuge werden mit den neuen Teilen aufgebaut; Montage, Geometrie, Farbzuordnung, Distanzstufen und Speicherung werden geprüft.

Belegter Fahrzeugstand: Im nativen Job von [Lauf 45136673872](https://github.com/Ullmann27/lumo-godot/actions/runs/45136673872) auf `9368a325c508a1c2f0bd2da596ff17300d0d52fa` bestehen `KartEvolution PASS checks=112196 pairwise=1877 sampled=5760 actual_race_setups=4 boundary_race_setups=3`, `KartDynoParts PASS 921 checks` und die bestehende Produktionsfahrzeug-Regression. Dieser Stand enthält die mechanisch korrigierte Geometrie `d84631b45eeb7a1f14b5237efb20cf37a5803dfd`, die angeschlossenen Kartenbalken und die Touchkorrektur. Zwei gesonderte Streckenregressionen scheitern in diesem Lauf; der Gesamtstatus ist deshalb rot. Diese Dokumentation behauptet keine Freigabe des gesamten Projekts.

### Tatsächlich gefahrene Grenzfälle

Die drei zusätzlichen Grenzproben verwenden dieselben echten Werkstatt-APIs wie das Spiel: Sterne gutschreiben, Teile freischalten, Teile montieren und Feinregler setzen. Ein direkt gesetzter Teilewunsch ohne Besitz würde bei kostenpflichtigen Teilen korrekt auf die Serie zurückfallen.

| Gefahrene Konfiguration | Erreichtes Boosttempo | Gemessene Bremsverzögerung |
|---|---:|---:|
| Stella, alle vier Ausbaustufen auf 5, stärkster gemeinsamer Tempo-/Boostsatz, leichte Bremse | 107,842371298251 m/s | 83,664 m/s² |
| Derselbe schnelle Stella ohne Bremsen-Ausbaustufen | 107,842371298251 m/s | 71,904 m/s² |
| Gecko Velo ohne Ausbaustufen, tatsächlich schwächste erreichbare Bremse | 68,70829446 m/s | 62,496 m/s² |

Der Stella-Satz lautet Motor `lader`, Reifen `slick`, Flügel `flach`, Booster `kurz`, Bremse `leicht`, Getriebe `lang`, übrige Steckplätze Serie; Feinregler Druck +2, Flügelwinkel −2, Übersetzung +2. Für Gecko Velo bleiben die übrigen Teile und Feinregler neutral. Der Test stellt den Ausgangszustand nahe dem jeweiligen Tempoziel her und prüft anschließend echte Fahrintegrationsschritte sowie vier Bremszeitschritte. Das ist eine Prüfung der wirksamen Grenzen und Bremskräfte, keine vollständige Beschleunigungsfahrt vom Stillstand bis zum Boostmaximum.

### Echter Bild- und Bedienungsnachweis

Alle sechs Aufnahmen desselben Laufs wurden in **Godot 4.6.3 mit gl_compatibility, 1280 × 720** gerendert und anschließend visuell geprüft. Der Capture meldet `PASS`, sechs Bilder und keine Fehler. Serienkart, Kurventechnik- und Sprung-/Rallye-Aufbau unterscheiden sich sichtbar. Axialmotor, Venturi-Flügel, Räder, Carbon-Seitenteile und Diffusor sitzen am Kart. Die zwölf Vergleichswerte überlappen horizontal nicht; Zusatzinformationen sind im Schubfach scrollbar, Montieren und Zurück bleiben sichtbar. Artefaktpfade: `vehicles/vehicle-01-serie.png` bis `vehicles/vehicle-06-jump-rally.png`.

Die Kartenbalken verwenden nachweislich dieselben montierten Faktoren wie die Physik. Für Tempo/Lenken ergeben sich Serie **6,00/6,00**, Kurventechnik **5,04/7,08**, Sprung-/Rallye **5,43847239936/5,82**. Die Tooltips zeigen entsprechend **173 km/h · 2,84 rad/s**, **145 km/h · 3,35 rad/s** und **157 km/h · 2,75 rad/s**.

Die tatsächlichen Control-Rechtecke wurden nach dem Layout gemessen, nicht lediglich aus Mindestgrößen abgelesen:

| Bedienelement | Gemessene Breite × Höhe |
|---|---:|
| Montieren/Freischalten | 426 × 52 dp |
| Zurück | 74 × 52 dp |
| Kategorieauswahl | 150 × 48 dp |
| Motorteil-Auswahlkacheln | jeweils 152 × 132 dp |
| Popup-Kategoriezeile | Höhe 48 dp |

Diese Messung gilt für den ausgeführten Desktop-Render mit `dp_scale = 1,0`; sie ist kein Nachweis aller physischen Android-Displaydichten. Der vollständige Messbericht einschließlich Kartendaten und Bild-SHA-256 liegt in `vehicles/vehicle-evolution-capture.json` im Artefakt `kart-native-proof-45136673872` (ID **14800437958**, ZIP-SHA-256 `dc2e7efc7b4dbfea9cba9531f23ce0bd461021aac04b164b79245c7a9b3724af`).

**Eine 60-FPS-Messung auf physischer Android-Hardware ist damit nicht nachgewiesen.**

## Maßgebliche Quellen im Repository

- [Teilekatalog und gemeinsame Grenzen](../../scripts/games/kart_part_catalog.gd)
- [Fahrzeuggrundprofile](../../scripts/games/kart_fleet.gd)
- [Gemeinsame Fahrformeln](../../scripts/games/kart_powertrain.gd)
- [Tatsächlicher Werkstatt-Prüfstand](../../scripts/games/kart_dyno.gd)
- [Werkstattanzeige](../../scripts/games/kart_parts_bay.gd)
- [Prozedurale Bauteilgeometrie](../../scripts/games/kart_evolution_geometry.gd)
- [Kombinations- und Fahrregression](../../scripts/tests/kart_evolution_regression.gd)
- [Echte Bildaufnahme](../../scripts/tests/kart_evolution_capture.gd)
