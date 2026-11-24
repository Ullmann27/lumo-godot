# LUMO Kart: Leistungsteile (Garage) – Bestand und Umsetzung

Stand 19.11.2026. Auftrag: „mehr Bauteile zum Wechseln mit echtem Leistungsunterschied“.

## 1. Bestand der Fahrphysik (vor den Leistungsteilen, Hauptstand 7be1690)

Alle Werte eines Karts entstehen in `kart_fleet.gd:multipliers()` (Zeile 174) aus den fünf
Werten 0–12 (Wert 6 = Faktor 1,0) plus zwei Eigenschaften (`traits`). Die Werkstatt-Stufen
(`kart_tuning.gd`, `PARTS`) erhöhen nur diese Werte. Das Rennen liest die Faktoren über
`kart_island._refresh_kart_factors()` (Z. 2021) → `workshop.multipliers(kart)`.

| Größe | Faktor (Formel) | gelesen in | Wirkung im Rennen |
|---|---|---|---|
| Endtempo | `speed = 1 + (Tempo−6)·0,03` | `kart_powertrain.top_speed()` (Z. 18) ← `kart_island._drive_player` (Z. 2047) | 20,5 m/s · 2 · speed · 1,17 = 173 km/h (Comet) |
| Beschleunigung | `accel = 1 + (Beschl.−6)·0,06` | `kart_powertrain.acceleration()` (Z. 28) ← `_drive_player` (Z. 2092) | 40 m/s² · accel, Rampe `move_toward` |
| Bremsen | `brake = 1 + (Bremsen−6)·0,07` | `acceleration(…, true)`, `stopping_distance()` | 80 m/s² · brake |
| Lenkung | `turn = 1 + (Handling−6)·0,045` | `_drive_player` Lenkrate (alt Z. 2098) | (1,42 [+0,35 Drift]) · turn · 2 rad/s, in der Luft · 0,35 |
| Haftung | `grip = 1 + (Handling−6)·0,03` | `_drive_player` (alt Z. 2108), `kart_rival_racecraft.corner_speed()` | Nachlauf der Fahrtrichtung 9·grip·2 /s (Drift fest 3,1·2) |
| Drift | – (kein Faktor) | `_drive_player` (alt Z. 2129) | Ladung `|Lenkung|·2` pro s, Stufen 0,8/1,8/2,7 (`kart_race_rules.gd` Z. 6) |
| Turbo-Stärke | `boost_power = 1 + (Turbo−6)·0,07` | `_drive_player` (alt Z. 2059) | Endtempo · (1 + 0,42·boost_power), Beschleunigung ·2 |
| Turbo-Dauer | `boost_time = 1 + (Turbo−6)·0,05` | `_boost_for()` (Z. 2032), alle Turbo-Quellen | Sekunden · boost_time |
| Gelände | `traits.offroad` (0,50–0,82) | `_drive_player` (Z. 2086) | Endtempo · offroad neben der Fahrbahn |
| Rempler | `traits.stability` (0,40–0,66) | `_drive_player` (Z. 2078) während `hit_timer` | Endtempo · stability nach Treffer/Rempler |
| Landung | – (kein Faktor) | Landung in `_drive_loop` (alt Z. 2387) | Lenkberuhigung 0,10–0,32 s, Lenkung bis ·0,62 |

Die Werkstatt-Stufen (Motor +0,4 Tempo/+0,2 Beschl., Bremsen +0,5, Reifen +0,4 Handling,
Turbo +0,5 je Stufe, max. Stufe 5, begrenzt auf Wert 12) machen ein Kart nur „besser“, nie
anders. Die zwei Garagen-Steckplätze (Radaufsätze, Auspuffblenden) waren reine Optik.
Rivalen (`kart_rival_racecraft.factors()`) fahren mit den Grundwerten ihres Karts, ohne
Stufen; das Gummiband bremst nur weit vorne liegende Rivalen, schiebt aber keine an.

## 2. Was neu ist

- Gemeinsame Fahrformeln in `kart_powertrain.gd` (`boost_scale`, `turn_rate`, `grip_rate`,
  `drift_charge_rate`, `landing_settle`); `_drive_player` ruft genau diese auf. Neue Faktoren
  `drift_charge`, `drift_grip`, `air_turn`, `landing` sind ohne Teile 1,0 – Serie fährt
  bitgleich wie vorher (geprüft in `kart_dyno_parts_regression.gd`).
- Katalog `kart_part_catalog.gd`: fünf Steckplätze (Motor, Reifen, Flügel, Turbo,
  Fahrwerk), je Serie + 2–3 Varianten mit Vorteil und Nachteil.
- Prüfstand `kart_dyno.gd`: kurze Fahrten im 60-Hz-Takt mit denselben Formeln.

## 3. Teileliste mit Prüfstand-Werten (Comet, Container-Messung `kart_dyno.measure`)

Serie: Endtempo 173 km/h, Anfahren 0→95 % 1,15 s, Bremsweg aus 72 km/h 3,0 m,
Kurvenradius 16,7 m, Rutschen 5,01 m, Drift-Turbo nach 0,42 s, Turbo 1,00 s / 245 km/h,
Gelände 93 km/h, Lenken im Flug 46°, Wackeln nach Landung 0,23 s, Tempo nach Rempler 45 %.

| Steckplatz | Teil | Sterne | Vorteil (gemessen) | Nachteil (gemessen) |
|---|---|---|---|---|
| Motor | Sprintmotor | frei | Anfahren 0,98 s | Endtempo 168 km/h |
| Motor | Langstreckenmotor | 10 | Endtempo 176 km/h | Anfahren 1,37 s |
| Reifen | Haftreifen | frei | Rutschen 4,09 m, Radius 16,3 m | Drift-Turbo erst nach 0,52 s |
| Reifen | Driftreifen | 8 | Drift-Turbo nach 0,32 s | Rutschen 6,08 m |
| Reifen | Stollenreifen | 12 | Gelände 119 km/h | Endtempo 170 km/h |
| Flügel | Großflügel | frei | Radius 15,6 m, Rutschen 4,40 m | Endtempo 169 km/h |
| Flügel | Flachflügel | 8 | Endtempo 175 km/h | Rutschen 5,65 m, Radius 17,4 m |
| Flügel | Gleitflügel | 12 | Lenken im Flug 82° | Endtempo 171 km/h |
| Turbo | Kurzschub | frei | Turbo-Tempo 263 km/h | Turbo-Dauer 0,72 s |
| Turbo | Langschub | 10 | Turbo-Dauer 1,35 s | Turbo-Tempo 231 km/h |
| Fahrwerk | Sprungfedern | frei | Wackeln nach Landung 0,08 s | Radius 17,4 m |
| Fahrwerk | Sportfahrwerk | 10 | Radius 15,8 m | Wackeln nach Landung 0,36 s |
| Fahrwerk | Schwerfahrwerk | 12 | Tempo nach Rempler 60 % | Anfahren 1,22 s |

Dazu die zwei Optik-Steckplätze Radkappe (Turbinenrad, Sternrad) und Auspuff
(Raketendüse, Doppelrohr) mit „Aussehen“. Serie und je eine Variante sind von Anfang an
frei; die übrigen werden mit verdienten Sternen freigeschaltet (`kart_tuning.buy_option`,
wie Lack und Felgen: nur „auf dem Papier“ ausgegeben, alte Freischaltungen bleiben).

## 4. Fairness-Grenze (Container-Messung, kein Handy-Wert)

Zeitfahren Sonnenhafen, 2 Runden, Comet, `kart_parts_lap_probe.gd`, Kind-Fahrer (0,18 s
Reaktion, kein Drift) bzw. Drift-Fahrer:

| Satz | Kind-Fahrer | Drift-Fahrer |
|---|---|---|
| Serie | 70,68 s | 68,77 s |
| schnellste gefundene Kombination | 67,67 s (−4,3 %; Langstreckenmotor, Flachflügel, Schwerfahrwerk) | 66,30 s (−3,6 %; Langstreckenmotor, Flachflügel, Driftreifen, Kurzschub) |
| langsamste Kombination (Sprintmotor, Großflügel, Stollen, Kurzschub, Sprungfedern) | 76,88 s (+8,8 %) | 74,38 s (+8,2 %) |

Zielkorridor −3 bis −6 % wird eingehalten. Vor der Dämpfung (Langstreckenmotor +3,5 %
Endtempo) brachte der Motor allein −4,8 %; deshalb jetzt +2,2 % Endtempo.

`kart_sonnenhafen_stunt_regression` PASS mit Serie, schnellster, langsamster und
„Luft“-Kombination (Gleitflügel + Langstreckenmotor + Kurzschub + Driftreifen +
Schwerfahrwerk). Rivalen: ab „Abenteuer“ mit festen Teile-Sätzen je Fahrstil
(`kart_part_catalog.RIVAL_SETS`), in „Entdecken“ Serie. Rennen Sonnenhafen gegen fünf
Rivalen (`kart_rival_fairness_probe`, sauber, Seeds 7/11): siehe Abschnitt 5.
