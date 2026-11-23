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

### Nachrechenbare Beispiele aus den gemeinsamen Formeln

Referenz ist ausschließlich **Comet, ohne Ausbaustufen, andere Leistungsteile oder Feinregler**, auf ebener Straße ohne Items, Aufholhilfe oder Streckeneffekte. Dies sind exakte Formelwerte vor der Rundung in der Oberfläche, keine Messwerte eines echten Autos:

- Serie: Beschleunigung **40 m/s²**, Bremsverzögerung **80 m/s²**, Endtempo **172,692 km/h**. Formel: `20.5 × 2.0 × 1.17 × speed × 3.6`.
- Axial-Antrieb: Beschleunigung **48,8 m/s²**, Endtempo **165,78432 km/h**.
- Performance-Reifen: Bremsverzögerung **84,8 m/s²**; Geländetempo **74,25756 km/h** statt **93,25368 km/h**, weil der Geländefaktor von **0,54 auf 0,43** fällt.
- Venturi-Flügel: Haftungsrate **21,6 s⁻¹** statt **18 s⁻¹**; Endtempo **164,0574 km/h**.
- Superkondensator: erster Drift-Turbo dauert **1,42 s** statt **1,00 s**; das in diesem Prüfstand erreichbare Turbo-Endtempo beträgt **231,788583936 km/h** statt **245,22264 km/h**.
- Adaptive Dämpfer: Beruhigungszeit bei Aufprall mit 9 m/s **0,1125 s** statt **0,225 s**; Beschleunigung **37,6 m/s²**.
- Vector-Lenkung: Lenkrate ab 16 m/s **3,3512 rad/s** statt **2,84 rad/s**; Drift-Haftungsrate **6,82 s⁻¹** statt **6,2 s⁻¹**; Endtempo **168,3747 km/h**.
- Keramikbremse: Bremsverzögerung **104 m/s²**; Beschleunigung **38,4 m/s²**.
- Doppelkupplung: Beschleunigung **46,4 m/s²**; Drift-Laderate **2,16 s⁻¹** statt **2 s⁻¹**; Endtempo **165,78432 km/h**.
- Carbon-Chassis: Beschleunigung **44,8 m/s²**; Fluglenkrate bei vollem Lenken und mindestens 16 m/s **1,1928 rad/s** statt **0,994 rad/s**; Landungsberuhigung **0,252 s**; Stabilitätsfaktor **0,35** statt **0,45**.

Die vollständigen, im 60-Hz-Prüfstand erzeugten Einzelteil-Datensätze werden von `kart_evolution_regression.gd` als `[KartEvolutionPart]` ausgegeben und in `vehicle-evolution-regression.json::single_part_comet` gespeichert. Sie unterscheiden sich bewusst von bloßen Faktorprozenten.

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

Belegter erster Durchlauf: `KartEvolution PASS checks=112145 pairwise=1877 sampled=5760 actual_race_setups=4`; zusätzlich `KartDynoParts PASS 921 checks`, jeweils im nativen Job des [Laufs 45131743157](https://github.com/Ullmann27/lumo-godot/actions/runs/45131743157) auf `d169e1555d8f5ee39e0b06153927f518df4cdb0e`. Der Gesamtlauf wurde später abgebrochen; diese erfolgreichen Teilproben sind kein grüner Gesamtstatus. Die spätere mechanische Geometriekorrektur (`d84631b45eeb7a1f14b5237efb20cf37a5803dfd`) ist von diesem ersten Befund getrennt zu bewerten.

Ein tatsächlicher Bildvergleich ist über `kart_evolution_capture.gd` vorgesehen: Serienkart, vollständige Kurventechnik-Auswahl, Sprung-/Rallye-Auswahl sowie echte Werkstattwerte. **Eine 60-FPS-Messung auf physischer Android-Hardware ist damit nicht nachgewiesen.**

## Maßgebliche Quellen im Repository

- [Teilekatalog und gemeinsame Grenzen](../../scripts/games/kart_part_catalog.gd)
- [Fahrzeuggrundprofile](../../scripts/games/kart_fleet.gd)
- [Gemeinsame Fahrformeln](../../scripts/games/kart_powertrain.gd)
- [Tatsächlicher Werkstatt-Prüfstand](../../scripts/games/kart_dyno.gd)
- [Werkstattanzeige](../../scripts/games/kart_parts_bay.gd)
- [Prozedurale Bauteilgeometrie](../../scripts/games/kart_evolution_geometry.gd)
- [Kombinations- und Fahrregression](../../scripts/tests/kart_evolution_regression.gd)
- [Echte Bildaufnahme](../../scripts/tests/kart_evolution_capture.gd)
