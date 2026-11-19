# Lumo Kart – erweiterte Items (Entwicklernotiz)

Stand 19.11.2026, Zweig `agent/items-neu`. Erweitert das bestehende Item-System, ersetzt es
nicht: Ziehen (`kart_item_catalog.gd` → `roll()`), Halten im Item-Knopf, Speichern des
gehaltenen Items, Sternenschild, Schonzeit und HUD bleiben, wo sie waren.

## Aufbau

| Datei | Rolle |
|---|---|
| `assets/kart/items/kart_items.json` | eine Datenzeile je Item (Name, Farbe, Verhalten, Gewichte Platz 1–6, Töne) |
| `scripts/games/kart_items/ext/kart_item_ext_registry.gd` | Verhalten → Verhaltensdatei, Liste der Töne, Symbolpfad |
| `scripts/games/kart_items/ext/kart_item_ext_effect.gd` | Basisklasse: `use`, `rival_wants`, `tick`, `incoming`, `save/restore`, Knoten-Pool |
| `scripts/games/kart_items/ext/kart_item_ext.gd` | Wirt-Knoten unter `race_root`: Treffer-Auflösung (Schild → Schonzeit → Wirkung), Tempo-/Lenk-/Haftungsfaktoren, sicherer Korridor, seitlicher Versatz, Kinderschutz, Speichern |
| `scripts/games/kart_items/ext/kart_item_ext_fx.gd` | gemeinsame Bausteine: Materialien, Partikel-Rezepte, verästelte Blitze, kameragerichtete Bänder |
| `scripts/games/kart_items/ext/effects/<item>.gd` | je Item eine Verhaltensdatei |
| `assets/kart/hud/items/icon_<id>.webp` | HUD-Symbol (`tools/art/render_kart_item_ext_icons.py`) |
| `assets/audio/kart/items/<ton>.ogg` | Töne (`tools/art/generate_kart_item_ext_audio.py`, eigene Synthese, `ext_manifest.json`) |
| `scripts/tests/kart_item_ext_regression.gd` | Test im echten Rennen (headless) |
| `scripts/tests/kart_item_ext_capture.gd` | Bildfolgen aus dem echten Rennen (gl_compatibility) |

### Einhängepunkte in bestehenden Dateien (je ein paar Zeilen, markiert „Hook items-neu“)

- `kart_island.gd`: Wirt anlegen/leeren; `_use_catalog_item` Standardzweig → `item_ext.player_use`
  (false = Item bleibt im Knopf); `_rival_use_catalog_item` → `item_ext.rival_use`;
  `_update_gameplay_layer` → `item_ext.tick`; Tempo `_gameplay_speed_factor` /
  `_rival_gameplay_factor`; Lenkung/Haftung des Kindes in `_drive_player`; Lenkgrenze und
  Ausweich-Spurversatz der Rivalen in `_drive_opponents`; `_rival_threatened` kennt die neuen
  Anflüge (KI hebt den Schild); Warnanzeige `player_warning`; Schild-Gesamtdauer im HUD;
  Speichern (`item_ext`-Schlüssel), Fortsetzen, Grafik-Neuaufbau; Anzeige-Versatz für den
  Bild-Glätter (`_display_offset`: Raketen-Wirbel + Anhebung der Schwerkraft-Welle).
- `kart_item_catalog.gd`: Verhalten aus der Registry gelten als gültig.
- `kart_item_hud.gd`: unbekanntes Item → gerendertes Symbol `icon_<id>`.
- `kart_audio.gd`: Töne aus der Registry laufen wie die Raketen-Töne.

## Ein weiteres Item hinzufügen

1. Zeile in `kart_items.json` mit neuem `behaviour`, vorsichtigen Gewichten, `sounds`.
2. `effects/<item>.gd` erbt `kart_item_ext_effect.gd`; Daten nur im Streckenraum
   (Fortschritt/Querlage/Alter), damit Speichern/Fortsetzen ohne Knoten auskommt.
   Treffer immer über `host.resolve()`, Tempo/Lenkung über `host.add_mod()`, seitlich nur über
   `host.push()` (sicherer Korridor), Ziele über `host.pick_target()` (Schonzeit, Kinderschutz).
3. Eintrag in `REGISTRY.BEHAVIOURS` (+ Töne in `SOUNDS`), Symbol in den Icon-Generator.
4. Abschnitt im Regressionstest und in der Bildfolge.

Gemeinsame Wirt-Funktionen, die die Welle-2-Items nutzen: `offset_for()` (reine Anzeige-Anhebung,
Schwerkraft-Welle), `absorb()`-Abfang vor dem Schild (Sternen-Duplikat), `lane_bias()` (KI weicht
Falle/Feld/Meteor aus), `add_mod()` (Tempo-/Lenkfaktoren), `push()` (sicherer Korridor).

## Gemeinsame Regeln

- **Schild** (Sternenschild, Sternenfestung, Nordlicht) wehrt jeden neuen Treffer ab und zeigt
  die Welle an der Kuppel; Abwehr setzt keine Schonzeit.
- **Schonzeit**: dieselbe wie bei den Raketen (`_lock_rules().grace`: 3,5 / 2,6 / 2,0 s); jeder
  Treffer setzt sie, Ziele in Schonzeit werden nicht anvisiert.
- **Kinderschutz**: Rivalen greifen das Kind mit neuen Items höchstens alle 9 / 6 / 4 s an.
- **Sicherer Korridor** (`safe_at`): 6 m hinter bis 30 m vor dem Ziel kein Brückendeck, keine
  offene Kante, keine Rampe, keine Passagen-Zone, nicht in der Luft/im Looping; seitlicher
  Versatz endet 1,15 m vor der Planke.
- **Mobil**: alles unshaded/additiv oder Alpha, keine Screen-/Depth-Textur; Knoten gepoolt
  (je Item 3–4 Darstellungen); Partikelbudget LOW 40 %, MEDIUM 70 %, HIGH 100 %, ruhige
  Bewegung halbiert und verzichtet auf Flackern/Drehen – die Aussage bleibt gleich.

## Zeitachsen der Effektketten

### Donnerstern (`lightning_strike`)

| Zeit | Phase | Was passiert (aus echten Positionen) |
|---|---|---|
| 0,00–0,45 s | Auslöser | Stern steigt vom eigenen Kartdach auf, kleine Blitzbögen am Kart |
| 0,45–0,80 s | Weg | Stern fliegt im Bogen vom eigenen Kart über das Ziel, Leuchtspur |
| 0,80 s–Einschlag | Vorwarnung | Gewitterwolke 6,2 m über dem fahrenden Ziel, gelber Ring auf der Fahrbahn schrumpft; Einschlag bei 0,95 s (Rivale), 1,15 s (Kind), 1,35 s (Kind, „Entdecken“) |
| Einschlag +0,28 s | Einschlag | verästelter Blitz Wolke → Kartdach, dreimal neu verästelt, Lichtblitz + Funken; mit Schild endet er an der Kuppel und leitet in drei Ästen zur Fahrbahn ab |
| +0–1,15 s | Reaktion | Tempo 68 %, ab ⅓ weich zurück auf 100 %; Funkenbögen kriechen über das Kart |
| +0–1,1 s | Abklingen | Brandring am Boden glüht aus, Wolke weitet sich und verblasst |

### Frostkristall (`frost_capsule`)

| Zeit | Phase | Was passiert |
|---|---|---|
| 0,00 s | Auslöser | Eiskapsel (facettierter Kristall mit Leuchtkern) löst sich vorn vom Kart |
| 0–Flug | Weg | Bogen vom Abwurfpunkt zum *aktuellen* Ziel (folgt ihm); Höhe 1,2 m + 4 % der Distanz; Flugzeit = Abstand / 38 m/s (0,55–1,30 s); weiß-blaue Frostspur zeichnet die Bahn nach |
| Flug | Einschlag | Kapsel zerspringt in Splitter + Frostnebel; mit Schild an der Kuppelseite, die zur Kapsel zeigt |
| Flug + 0–0,2 s | Reaktion | Eiskrusten wachsen an allen vier echten Radnaben (`wheel_pivots`) |
| Flug + 0–1,6 s | Reaktion | Lenkung 58 %, Haftung 55 %, Tempo 90 % (ab ⅓ weich zurück); Raureif-Spur hinter den Hinterrädern bleibt kurz auf der Fahrbahn liegen |
| letzte 0,6 s | Abklingen | Krusten schrumpfen, Tropfen fallen, Dampf steigt |

Sperre: Ziel nur, wenn `safe_at()` gilt; wird es im Flug unsicher, verpufft der Frost (Splitter, keine Wirkung).

### Feuermeteor (`fire_meteor`)

| Zeit | Phase | Was passiert |
|---|---|---|
| 0,00–0,15 s | Auslöser | Kugel löst sich vorn vom Kart, Feuerschweif + Rauch setzen ein |
| 0,15–1,70 s | Weg | 1,1 m über der Fahrbahn, Kart-Tempo + 22 m/s (mind. 30 m/s), lenkt mit 5 m/s quer zum Rivalen vorn (≤ 32 m); Schweif, Rauchfahne, Funken |
| Kontakt | Einschlag | Glutblitz + Funkenregen am Kart (jeder Fahrer in der Bahn, nicht nur das Ziel) |
| +0–1,2 s | Reaktion | Tempo 62 % (weich zurück), Rußwolke steigt 1,0 s vom Kart |
| 1,35–1,70 s | Landung (ohne Treffer) | Kugel senkt sich auf die Fahrbahn |
| +0–3,5 s | Glutfeld | nur auf sicherer Fahrbahn und mit Platz zur Planke: Glutscheibe Ø 2,8 m glüht orange → rot → aus, Brandfleck verblasst, Glutfunken steigen; Durchfahrt einmal je Fahrer 0,7 s 82 % Tempo |

KI weicht anfliegenden Meteoren (≤ 22 m dahinter) und Glutfeldern (≤ 26 m davor) über `lane_bias()` aus.

### Sternenfestung (`fortress`)

| Zeit | Phase | Was passiert |
|---|---|---|
| 0,00–0,45 s | Aufbau | goldene Außenkuppel wächst vom Boden, Sternfunken; innen hebt sich die cyanfarbene Schildkuppel (gleiche Schilduhr) |
| 0,45–10 s | Schutz | Doppelkuppel; Boden-Ring läuft ab (gold → cyan), 12 Sekundenmarken erlöschen; HUD-Ring auf 12 s; Treffer → Welle an beiden Kuppeln |
| 10–12 s | Ende naht | Ring und Kuppel atmen langsam (0,8 Hz, kein Blinken) |
| 12–12,6 s | Abbau | Kuppel sinkt, Funkenregen, Ton |

Regeln: Obergrenze 12 s (erneutes Einsammeln frischt auf, addiert nicht); die Festung hält die
Schilduhr mindestens auf ihrer Restzeit, ein Sternenschild währenddessen verlängert/verkürzt nicht.
