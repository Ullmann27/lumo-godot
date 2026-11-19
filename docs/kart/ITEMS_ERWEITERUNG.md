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

### Wirbelwind (`whirlwind`)

| Zeit | Phase | Was passiert |
|---|---|---|
| 0,00–0,15 s | Auslöser | Wirbel entsteht vor dem Kart, Staub am Boden |
| 0,15–3,0 s | Weg | Kart-Tempo + 12 m/s (mind. 26 m/s); das Kind lenkt ihn (3,2 m/s quer), sonst zieht er mit 2 m/s zur Spur des Rivalen; drei drehende Windbänder, Streckenteilchen je Thema (Sand, Schnee, Blätter, Glut, Funken) |
| Kontakt | Einschlag | Böe, Trichter fällt in eine Teilchenwolke auseinander |
| +0–0,55 s | Reaktion | Versatz bis 2,2 m (weg von der Wirbelmitte, sonst zur Mitte), geklemmt 1,15 m vor der Planke, an Brücke/Kante/Rampe gar nicht; 0,8 s 85 % Tempo, Lenkung 80 % |
| +0,55–1,3 s | Abklingen | Teilchen fliegen aus und sinken, Staub legt sich |

### Schwerkraft-Welle (`gravity_wave`)

| Zeit | Phase | Was passiert |
|---|---|---|
| 0,00–0,20 s | Auslöser | Lichtpuls unter dem eigenen Kart |
| 0,20–0,75 s | Weg | drei wellige Verzerrungsringe (cyan → violett) laufen auf der Fahrbahnebene bis 13 m; Mittelpunkt fährt mit dem Kart |
| Kamm erreicht Gegner | Einschlag | Abstand Kart–Wellenmitte ≤ Kammradius → Treffer (Schild/Schonzeit/Luft ausgenommen) |
| +0–0,9 s | Reaktion | Kart schwebt bis 1,2 m (nur Anzeige über den Bild-Glätter, `_display_offset`; die Fahrposition bleibt auf der Fahrbahn = sichere Landung), Hologramm-Säulen + Teilchen; Tempo 72 % für 1,1 s |
| +0,9–1,3 s | Abklingen | Landung, Ringe verblassen |

### Sternen-Duplikat (`star_decoy`)

| Zeit | Phase | Was passiert |
|---|---|---|
| 0,00–0,30 s | Auslöser | Lichtblitz, holografische Kopie gleitet 2,1 m seitlich / 0,8 m zurück heraus (Seite mit mehr Platz) |
| 0,30–6,0 s | Wirken | Kopie aus den echten Kart-Meshes, Holo-Shader (Lichtzeilen, Fresnel, additiv) – das echte Kart bleibt fest und farbig; Sternraketen auf das Kart (≤ 35 m) verlieren die Zielerfassung und biegen zur Kopie ab |
| Treffer | Einschlag | Raketenpaar oder neuer Angriff trifft die Kopie: Lichtsplitter, „DUPLIKAT!“ – das Kart bleibt unberührt (eine Abwehr je Kopie) |
| 5,4–6,0 s | Abklingen | Kopie verblasst |

### Turbo-Kette XL (`turbo_xl`)

| Zeit | Phase | Was passiert |
|---|---|---|
| 0,00–0,12 s | Zündung | Zündring am Heck, zwei Auspuffstrahlen schießen heraus |
| 0,12–1,50 s | Schub | vorhandener Kart-Schub (gleiche Fahrphysik) + 8 % Höchsttempo; Strahlen pulsieren, Energielinien an den Flanken (Länge ∝ Tempo) |
| 1,50–1,80 s | Abklingen | Strahlen schrumpfen |

Drei Ladungen (Kind: je Tipp eine; KI: nacheinander mit 1,1 s Pause). Keine Zündung, wenn bis 30 m
voraus Brücke, Kante, Rampe oder Passagen-Zone liegt; kommt so eine Stelle, endet der Schub weich.

### Lichtbogen-Falle (`arc_trap`)

| Zeit | Phase | Was passiert |
|---|---|---|
| 0,00–0,35 s | Auslöser | zwei Pfosten fallen 3 m hinter dem Kart auf die Fahrbahn |
| 0,35–8 s | Lauern | knisternder Bogen (2,6 m breit, 1,4 m hoch) + violette Bodenlinie; Fahrer, die darauf zufahren, werden gewarnt (Kind: roter Pfeil), KI lenkt vorbei |
| Kontakt | Einschlag | Blitz und Funken am Kart; Tempo 70 % für 0,9 s |
| danach | Abklingen | Bogen bricht zusammen, Pfosten versinken (0,5 s) |

Nie unpassierbar: neben dem Bogen bleiben zur Planke immer ≥ 2,4 m frei; kein Setzen an Brücke/Kante/Rampe/Passage.

### Zeitblüte (`time_bloom`)

| Zeit | Phase | Was passiert |
|---|---|---|
| 0,00–0,45 s | Auslöser | Same fliegt im Bogen 12 m vor den nächsten Gegner (≤ 50 m), sonst 18 m voraus |
| 0,45–1,05 s | Öffnen | zwölf Blütenblätter falten sich auf, Feld Ø 9 m, Zifferblatt mit laufendem Zeiger |
| 1,05–5,5 s | Wirken | Gegner im Feld: Tempo 55 % solange drin, Zeitring am Kart; eigenes Kart und alle außerhalb normal |
| 5,5–6,2 s | Abklingen | Blätter schließen sich, Feld erlischt |

Nicht auf Brücke/Kante/Rampe/Passage und nicht über einer Checkpoint-Grenze (±8 m + Radius).

## Gewichte (Platz 1–6, vorläufig)

| Item | 1 | 2 | 3 | 4 | 5 | 6 | Begründung |
|---|---|---|---|---|---|---|---|
| Donnerstern | 0 | 1 | 1 | 2 | 1 | 1 | Angriff nach vorn: Spitzenreiter hätte kaum Ziel; Mittelfeld am meisten |
| Frostkristall | 1 | 1 | 1 | 1 | 1 | 0 | mild (kein Tempoverlust), auch Spitze darf kontern; Letzter bekommt lieber Aufholhilfen |
| Feuermeteor | 0 | 1 | 1 | 1 | 1 | 1 | Angriff nach vorn, Glutfeld nützt auch hinten |
| Sternenfestung | 1 | 1 | 1 | 0 | 0 | 0 | Verteidigung für vorn (wie Sternenschild), seltener als dieser |
| Wirbelwind | 1 | 1 | 1 | 1 | 1 | 1 | sanfteste Wirkung, überall gleich |
| Schwerkraft-Welle | 1 | 1 | 1 | 1 | 1 | 0 | Nahbereich, braucht Gegner in 13 m |
| Sternen-Duplikat | 1 | 1 | 1 | 1 | 0 | 0 | Verteidigung gegen Raketen (vorn wichtiger) |
| Turbo-Kette XL | 0 | 0 | 1 | 1 | 2 | 1 | Aufholhilfe; Platz 6 nur 1, damit Nordlicht dort > 15 % bleibt |
| Lichtbogen-Falle | 1 | 1 | 1 | 0 | 0 | 0 | Falle nach hinten: nützt dem, der vorn fährt |
| Zeitblüte | 0 | 1 | 1 | 1 | 1 | 0 | Feld vor Gegnern: braucht Gegner vorn |

Je Platz kommen mit allen zehn Items 4–10 Gewichtspunkte dazu (bisher 26–29 je Platz): jedes
neue Item liegt bei rund 2,5–6 % je Ziehung; die neun alten Items behalten ihre Gewichte und
ihr Verhältnis zueinander (Platz 6: Nordlicht 5 von 31 = 16 %).
Die vorhandenen Prüfungen (Nordlicht ab Platz 6 > 15 %, keine Rakete für Platz 1) bleiben erfüllt.
Feinabstimmung nach dem Zusammenführen mit der Ziehungs-/Zonenmessung (anderer Helfer).
