# Stehende Tierfiguren und Clip-Bibliothek (Lieferung an Team C)

Stand 26.11.2026, Team B2. Erzeugt mit
`/home/user/tools/bpyenv/bin/python tools/lumo_animation/animals/build_standing_animals.py`
(alle neun) bzw. `… -- --species lion` (eine). Dauer je Figur ca. 10 s.

## Warum neue Figuren

Die Rennfahrer `assets/kart/production/drivers/<id>/driver*.glb` sind in die **Sitzpose des
Karts** eingepasst (Kopf ×2, dicke Gliedmaßen, Beine nach vorn angewinkelt). Als stehende
oder gehende Figur verformen sie sich, und sie haben keinen Geh-Clip
(`docs/qa/figuren_fahrzeuge_inventar.md`). Für Welt, NPCs, Publikum und alles, was steht oder
geht, gibt es jetzt eigene Figuren aus den **stehenden A-Pose-Originalen** (dieselbe Meshy-
Quelle, dieselbe Textur, dieselben geprüften Anatomiepunkte und Lidschalen).

Die Fahrer bleiben unverändert für Kart, Karten/Vier gewinnt (Sitz am Tisch) und Mitfahrer.

## Pfade

| id | Figur | Datei |
|---|---|---|
| lion | Löwe | `res://assets/characters/animals/lion/figure.glb` |
| owl | Eule | `res://assets/characters/animals/owl/figure.glb` |
| rabbit | Nova (Hase) | `res://assets/characters/animals/rabbit/figure.glb` |
| squirrel | Eichhörnchen | `res://assets/characters/animals/squirrel/figure.glb` |
| turtle | Schildkröte | `res://assets/characters/animals/turtle/figure.glb` |
| frog | Frosch | `res://assets/characters/animals/frog/figure.glb` |
| otter | Milo (Otter) | `res://assets/characters/animals/otter/figure.glb` |
| badger | Bruno (Dachs) | `res://assets/characters/animals/badger/figure.glb` |
| cat | Mika (Katze) | `res://assets/characters/animals/cat/figure.glb` |

Im Code: `LumoOpponentRoster.figure_model_path(id)` (leer, wenn nicht vorhanden) und
`LumoOpponentRoster.figure_info(id)` (Clipdaten aus `assets/characters/animals/figures.json`).

Eigenschaften: Höhe 1,6 m (Füße auf y = 0, Blick nach −Z wie die Fahrer), 30 Knochen,
ca. 15–18 k Dreiecke (Gesicht voll, Körper reduziert), Godot erzeugt Entfernungs-LODs beim
Import, Albedo 1024 px JPEG, doppelseitiges Material wie im Original, 1,6–2,0 MB je Datei.

## Rig (30 Knochen)

Die 26 Namen der Fahrer bleiben gleich (Root, Pelvis, Spine, Chest, Neck, Head, Tail, je Seite
UpperArm/Forearm/Hand/Thigh/Shin/Foot/Ear, Jaw, Eye.L/R, Lid.L/R). Neu: **TailMid, TailTip**
(dreigliedrige Schwanzkette mit Nachschwingen), **Toe.L/R** (Abrollen über den Ballen).
Gewichte in der Original-A-Pose; Schwanz entlang der Kette, Fuß am Ballen geteilt.
Ein Dehnungstest mit elf Extremposen repariert gerissene Gewichte harmonisch
(Schildkröte: Handschuh-Kanten hingen vorher am Panzer, Dehnung ×100 → ×5,8 am Ellbogen;
übrige Figuren ≤ ×3,3). Werte je Figur in `figures.json` → `rig_check`.

## Clips

Schleifen (Import mit `loop_mode = LINEAR`): `idle` 4,0 s, `walk`, `run`, `turn_left` 1,0 s,
`turn_right` 1,0 s, `sit_idle` 4,0 s, `listen` 4,0 s, `talk` 3,0 s, `think` 4,0 s, `drive` 2,0 s.

Einmalig: `stop` 0,8 s, `sit_down` 1,2 s, `stand_up` 1,2 s, `wave` 2,0 s, `joy` 1,6 s,
`surprise` 1,6 s, `disappointed` 2,4 s, `interact` 1,8 s, `enter_vehicle` 1,6 s,
`exit_vehicle` 1,4 s.

Kompatible Namen (die Welt, das Konzert und die Tische nutzen sie schon für die Fahrer):
`greeting_wave` (= `wave`), `celebrate` (= `joy`), `agree_nod` 1,5 s (zweimal nicken),
`point_portal` 2,0 s (zur rechten Seite zeigen), `card_play` 1,5 s (Karte zeigen und ablegen).

| Bedeutung | Clip |
|---|---|
| Ruhen/Atmen, Blinzeln, Umschauen | `idle` |
| Gehen / Laufen | `walk` / `run` |
| Drehen (auf der Stelle trippeln, Körper lehnt in die Drehung) | `turn_left`, `turn_right` |
| Anhalten | `stop` (beginnt in der `walk`-Pose bei Phase 0, endet in `idle`) |
| Sitzen / Hinsetzen / Aufstehen | `sit_idle`, `sit_down`, `stand_up` (Sitzhöhe in `seat_height_m`) |
| Winken | `wave` |
| Zuhören / Sprechen / Nachdenken | `listen`, `talk`, `think` |
| Freude / Überraschung / Enttäuschung | `joy`, `surprise`, `disappointed` |
| Interaktion (Greifen/Drücken vor der Figur) | `interact` |
| Einsteigen / Fahren / Aussteigen | `enter_vehicle`, `drive`, `exit_vehicle` |

### Fortbewegung richtig abspielen

Geh- und Laufzyklen sind **auf der Stelle** gebaut: der Standfuß gleitet mit genau der
Reisegeschwindigkeit nach hinten. Die Figur steht also in der Welt still, wenn der Knoten mit
`speed_mps` aus `figures.json` vorwärts bewegt wird (oder: `player.speed_scale =
velocity / speed_mps`). Werte (Löwe): `walk` 0,97 s, Schritt 0,80 m, 0,83 m/s;
`run` 0,63 s, 1,43 m, 2,26 m/s. Andere Figuren je nach Beinlänge 0,56–0,87 m/s bzw.
1,53–2,37 m/s. Bei Maßstab `s` am Knoten gilt `s × speed_mps`.

Fußkontakt (geprüft in `lumo_figure_animation_regression`): beim Gehen immer mindestens ein
Fuß am Boden, mit Doppelstandphase (Gewichtsverlagerung), Becken schwingt zur Standseite,
Becken-Hub zweimal je Zyklus, Arme gegengleich; beim Laufen Flugphase. Fersenaufsatz und
Abrollen über den Ballen mit Zehengelenk.

### Übergänge

Aufeinanderfolgende Clips passen ohne Sprung zusammen (geprüft, Abstand jedes Knochens
< 3 cm): `sit_down → sit_idle → stand_up → idle`, `walk → stop → idle`,
`enter_vehicle → drive → exit_vehicle`, `idle ↔ wave/joy/interact/disappointed`,
`idle → surprise`. Empfohlene Überblendung beim Wechsel: 0,15–0,25 s.

### Ein- und Aussteigen

`enter_vehicle` beginnt **neben** dem Sitz: Figurwurzel auf den Bodenpunkt unter dem Sitz
setzen; die Figur steht zu Beginn um `vehicle_entry_offset_m` (links, ca. −0,55 × Beinlänge)
versetzt, macht zwei Schritte hinüber und setzt sich auf `drive_seat_height_m`.
`exit_vehicle` ist die Umkehrung und endet stehend am selben seitlichen Punkt.

## Angeschlossen

| Ort | Datei | Stand |
|---|---|---|
| Offene Welt (NPCs) | `scripts/creative/lumo_world_open_world.gd` | stehende Figur, Rückfall Fahrer; Gehtempo der Routine (0,65 m/s) über `speed_scale` an die Schrittlänge angepasst |
| Rhythmus-Konzert (Publikum) | `scripts/creative/rhythm_concert_art.gd` | stehend, zur Bühne gedreht, `joy` als Schleifen-Kopie |
| Karten-, Schach-, Memory-Tisch | `scripts/games/cards/cards_seat.gd` | **bleibt Fahrer-Rig**: die Figuren sitzen dort wirklich (Sitzclips) |
| Dorf: Boote, Fuhrwerk | `build_village_life.gd`, `build_village_neighbors_view.gd` | **bleibt Fahrer-Rig**: Mitfahrer sitzen |
| Kart, Zieleinlauf | `kart_production_driver.gd` | **bleibt Fahrer-Rig**: Jubel im Sitz |

Eine Siegerehrung mit stehenden Figuren gibt es im Projekt nicht (gesucht nach Podest/Sieger/
Zeremonie); Sieger jubeln im Kart bzw. am Tisch.

## Was die Figuren nicht können

- Kein Wurzel-Bewegungsexport (Root Motion): Drehen und Vorwärtsbewegung macht die Spiellogik.
- Kein Gelände-IK: auf Treppen/Hängen schweben oder versinken die Füße um die Neigung.
- Sitzen und Fahren ohne konkretes Möbel/Fahrzeug: Sitzhöhe ist ein fester Wert je Figur.
- Die Turtle-Weste wird beim Armheben an den Seiten vom Panzer durchstoßen (Original-Geometrie).
