# Lumo Kart – Menü und Abenteuer-Strecken (17.11.2026)

Branch `lumo-kart/menu-strecken-20261117`, Basis `6a26a158` (fix/lumo-playready-hub-20261117 → bb478880 playready-Integration).

## Zuständigkeit
- **Menü/Strecken-Bot (dieser Branch):** Hauptmenü, Buttons, Streckenführung/Dramaturgie, Deko, Licht, Lesbarkeit, Platzierung von Hindernissen, Item-Ringen, Turbo-Feldern und Bauteil-Markern.
- **Lumo · Design (`lumo-2040/kart-*`):** baut die Gefahren-/Sprung-Bauteile und Loop-/Rampen-Anschlüsse. Hier gibt es dafür nur `Marker3D`-Platzhalter. Loop- und Rampengeometrie wird nicht angefasst.
- **Gameplay-Bot (`lumo-kart/gameplay-*`):** Items und Fahrphysik. Die Hindernisse nutzen nur die bestehende Schnittstelle `world.action_obstacles`: Ein Treffer kostet 12 % Tempo, sonst nichts.

## Bauteil-Platzhalter
Die Marker liegen unter `AbenteuerDramaturgie/AbenteuerBauteilPlatzhalter`. Jeder Marker heißt `Bauteil_<id>_<nr>` und trägt diese Metadaten: `bauteil`, `beschreibung`, `distance_m`, `lateral_m`, `laenge_m` (14 m) und `lieferant`. Die Transform-Basis ist `world.frame(distance)`. 26 m vor jedem Marker steht ein Warnschild.

| Bauteil-ID | Bedeutung |
|---|---|
| gefahr_lavaspalt | Lava-Spalt quer, mit Brücke oder Sprung, fair breite Spur |
| gefahr_wasserfurt | Wasserfurt, flaches Wasser, bremst leicht |
| gefahr_pendel | bewegliche Falle: Pendel oder Liane im Takt |
| gefahr_rollfelsen | bewegliche Falle: rollender Felsen quer, mit Pause |
| gefahr_eisrutsche | Glatteis, weniger Grip, markiert |
| gefahr_meteor | Meteor-Einschläge mit Schattenkreis-Vorwarnung |
| gefahr_sandwirbel | Sandwirbel, der seitlich schiebt |
| gefahr_geysir | Dampf- oder Lava-Geysir im Takt |
| sprung_rampe | Sprungrampe auf der Hauptspur |
| abkuerzung_risiko | Abkürzung mit Risiko: schmal, offene Kante |

Die gesetzten Positionen je Strecke (in Metern) gibt `scripts/tests/kart_adventure_drama_regression.gd` im Feld `markers` aus.

## Dramaturgie je Strecke (`scripts/games/kart_adventure_drama.gd`)
Jede Strecke hat vier Akte mit Akt-Schildern, einen Höhepunkt mit Torbogen, leuchtende Randlinien und Lichtmasten. Dazu kommen Hindernisse (Felsen, Slalom, Lianen), Bauteil-Marker, Turbo-Felder und Item-Ringe.

| Strecke | Abenteuer |
|---|---|
| volcano_night | Flucht vom Glutberg: Basaltdorf → Lava-Spalten → Feuerbrücke → Turbo-Abfahrt |
| winter_sprint | Gletscher-Abenteuer: Tannenwald → Eissee → Lawinenrinne → Sternenrampe |
| galaxy_ringway | Sternenjagd: Raumstation → Asteroidenfeld → Meteorschauer → Planetenring |
| desert_drift | Sturm über den Dünen: Markt → Felsschlucht → Sandsturm → Oasen-Furt |
| jungle_temple | Wilde Fahrt durch den Dschungel: Lianenpfad → Flussfurt → Tempelhalle → Seilbrücke |
| jungle_emerald_3600 | Expedition Dschungelherz: Daten fertig, die Strecke lädt auf der Basis aber nicht (`kart_jungle_environment.gd` fehlt) |
| sonnenhafen | nur Deko, Akte und Marker; keine zusätzlichen Hindernisse, damit die 6-Hütchen-Tests gültig bleiben |

Alle Strecken bekommen automatisch gelbe Chevron-Tafeln an engen Kurven (mehr als 0,26 rad Richtungswechsel auf 30 m).

## Fairness (getestet)
- An jeder Hindernisstelle bleibt mindestens 4 m freie Spur.
- Keine Hindernisse an Start/Ziel, in der Loop-Zone, im Tunnel oder auf Sprung- und Parcours-Abschnitten.
- Turbo-Felder und Item-Ringe liegen nie hinter einem Hindernis.

## Menü
Stufe = 1 + Sterne / 10. Der Sternenpfad zeigt den Weg zur nächsten echten Freischaltung aus `kart_catalog.gd` bzw. `kart_fleet.gd`. Event = Wochen-Abenteuer, eine Offline-Rotation über vorhandene Strecken. Es gibt keine erfundenen XP, keinen Saisonpass und keine Käufe.
