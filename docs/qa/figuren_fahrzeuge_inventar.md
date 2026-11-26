# Bestandsaufnahme Figuren, Rigs, Animationen und Fahrzeuge (26.11.2026)

Team B2, Basis `opus/lumo-intelligence-2-0-20261126` = `62108c03`. Alle Zahlen sind aus den
GLB-Dateien gelesen (eigenes Python-Leseprogramm für glTF-Header, Skins und Animationen) bzw.
aus dem Code per Suche belegt. Bilder wurden mit Godot 4.6.3 (gl_compatibility, xvfb) selbst
gerendert und angesehen. „Verdacht“ heißt: nicht vollständig geprüft.

## 1. Lumo (der echte geriggte Fuchs)

| Datei | Dreiecke | Knochen | Clips im GLB | Verwendung |
|---|---:|---:|---|---|
| `assets/characters/lumo_facial/Lumo-Facial-Mobile.glb` | 34.320 | 65 | idle, agree_nod, celebrate, greeting_wave, point_portal, kart_seated, kart_steer_left/right, kart_jump | `lumo_rigged_actor.gd` (Welt, Jump, Run, Karten, Vier gewinnt, Memory, Lernwelten, Garage-Servicestation …) |
| `assets/characters/lumo_animated/Lumo-Animated-Mobile.glb` | 30.000 | 65 | dieselben 9 | Original/Fallback, `app_boot.gd`, Kart-Adapter |
| `assets/lumo_next/character/Lumo-Learning.glb` | 35.483 | 67 | 23 (u. a. listening, thinking, explain, answer, encourage, farewell, unsure, idle_breathe) | `learning_lumo_actor.gd` (Lern-App) |

- Rig (65): Root, Pelvis, SpineLower, SpineUpper, Chest, Neck, Head, Crown; je Seite Clavicle,
  UpperArm, Forearm, Wrist, Hand + 16 Fingerknochen; Thigh, Shin, Foot, Toe, ToeTip;
  Schwanzkette TailBase, Tail1–3, TailTip. Gesicht über 13 Morph-Ziele (Blick, Blinzeln in
  vier Stufen, Kiefer); die Lern-Version hat 37 Morph-Ziele (u. a. Viseme).
- Zusätzliche Bewegung: `assets/characters/lumo_animated/lumo_studio_clips.gd` (aus Blender,
  `tools/lumo_animation/author_platform_clips.py`): walk (0,78 m Schritt), sprint (1,42 m),
  jump_rise, jump_fall, land, brake – als Körperraum-Rotationen auf dem Original-Skelett,
  abgespielt von `lumo_walk_locomotion.gd` / `lumo_platform_pose.gd`.
  Test `lumo_65bone_walk_gait_regression` prüft Schritt und Fußhub.
- Fehlt bei Lumo (in keiner Quelle gefunden): Drehen auf der Stelle, Hinsetzen/Aufstehen,
  Überraschung, Enttäuschung, Ein-/Aussteigen. Zuhören/Nachdenken/Sprechen gibt es nur in der
  Lern-Version (`Lumo-Learning.glb`), nicht im Welt-Lumo.

## 2. Tierfiguren (neun Rivalen)

Quelle: Meshy-Originale (A-Pose, stehend, 0,95 m, texturiert, ohne Skin) unter
`art/lumo_kart/meshy/20261123/drivers/<id>.glb`. Daraus baut
`tools/lumo_kart_art/drivers/rig_meshy_drivers.py` die Laufzeitfiguren
`assets/kart/production/drivers/<id>/driver{,_lod1,_lod2}.glb`.

| id | Name | Dreiecke LOD0/1/2 | Knochen | Textur |
|---|---|---|---:|---|
| lion | Löwe | 24.073 / 16.367 / 12.515 | 26 | 1024² |
| owl | Eule | 24.168 / 14.700 / 9.966 | 26 | 1024² |
| rabbit | Nova (Hase) | 23.548 / 14.736 / 10.331 | 26 | 1024² |
| squirrel | Eichhörnchen | 24.141 / 15.394 / 11.020 | 26 | 1024² |
| turtle | Schildkröte | 24.265 / 14.804 / 10.074 | 26 | 1024² |
| frog | Frosch | 22.081 / 12.950 / 8.385 | 26 | 1024² |
| otter | Milo (Otter) | 24.166 / 15.368 / 10.970 | 26 | 1024² |
| badger | Bruno (Dachs) | 24.174 / 14.675 / 9.927 | 26 | 1024² |
| cat | Mika (Katze) | 24.152 / 14.190 / 9.209 | 26 | 1024² |

- Rig (26): Root, Pelvis, Spine, Chest, Neck, Head, **ein** Tail-Knochen, je Seite UpperArm,
  Forearm, Hand, Thigh, Shin, Foot, Ear; Jaw, Eye.L/R, Lid.L/R. Keine Zehen, keine
  Schwanzkette.
- 12 Clips (je 78 Spuren): idle 3,0 s, kart_seated 3,0 s, kart_steer_left/right 2,0 s,
  kart_jump 1,5 s, celebrate 3,0 s, kart_celebrate 3,0 s, kart_hit 1,5 s, greeting_wave 2,0 s,
  agree_nod 1,5 s, point_portal 2,0 s, card_play 1,5 s. **Kein Gehen, kein Laufen.**
- **Ruhepose ist die Sitzpose im Kart.** Die Figur wurde dafür stark umgeformt: Kopf ×1,9–2,35,
  Gliedmaßen ×1,55–1,75 dicker, Beine angewinkelt nach vorn (`seated_bones`, `fit_to_seated`).
  Nur der Clip `idle` streckt die Beine per Knochen-IK in einen Stand (Körper um 0,43 m
  abgesenkt); alle anderen Clips sind Sitzhaltungen.

### Verdacht „Sitz-Rigs als gehende Figuren“ – bestätigt

| Ort | Datei (Verantwortung) | Was passiert | Befund |
|---|---|---|---|
| Kart-Rennen | `kart_production_driver.gd` | Fahrer im Sitz | korrekt |
| Karten / Vier gewinnt | `cards/cards_seat.gd` | sitzen am Tisch (`kart_seated`, `card_play`) | korrekt |
| Dorf: Boote, Fuhrwerk | `build_village_life.gd`, `build_village_neighbors_view.gd` | sitzende Mitfahrer | korrekt |
| **Offene Welt** | `lumo_world_open_world.gd` (Team C) | stehende NPCs mit `idle`; sucht Clip `walk`/`walking`/`walk_forward` → **nicht vorhanden**, Figuren bleiben stehen | Sitz-Rig als Stehfigur, kein Gehen möglich |
| **Rhythmus-Konzert** | `rhythm_concert_art.gd` | Publikum steht auf dem Boden, spielt `celebrate` | **sitzt in der Luft** (Bild unten), weil `celebrate` eine Sitzpose ist |

Selbst gerenderte Bildfolge (Löwe, Seite; Zeilen idle, celebrate, greeting_wave, kart_seated):
`idle` steht (mit verformten dünnen Beinen), die drei anderen Zeilen schweben sitzend über dem
Boden. Aufnahme: `scripts/tests/figure_clip_sheet_capture.gd`.

## 3. Weitere Figuren

- Dorfbewohner `assets/creative/village/{nelli_rabbit,bruno_beaver,tilda_duck}.glb`:
  3.360–4.032 Dreiecke, 7 Knochen (root, body, head, Arme, Beine), nur `Walk` (1,04 s).
  Verwendet in `build_settlement_residents.gd` und `lumo_world.gd`.
- Kein weiteres geriggtes Tier im Projekt (alle anderen GLBs ohne Skin; Fahrzeuge der Welt
  `assets/creative/lumo_world/vehicles/` sind statisch).

## 4. Fahrzeuge (14 Karts)

System: `kart_vehicle.gd` baut über `kart_production_vehicle.gd` je Design eine von drei
mechanischen Plattformen `assets/kart/production/karts/aurora_{comet,glider,turbo}{,_lod1,_lod2}.glb`
(Achsen, `Steer_*`/`Wheel_*`, Lenkrad mit `Grip_L/R`, `DriverSeat`, `Boost_L/R`, Bremslinse),
darauf die Karosserie `fleet/<id>.glb` (LOD0–2) und für die Nähe die Meshy-Hülle
`meshy/<id>.glb` (nur Karosserie, keine Räder; `_install_meshy_close_shell`).

| Design | Plattform | Meshy-Hülle Dreiecke | Fleet LOD0 Dreiecke |
|---|---|---:|---:|
| comet | comet | 19.053 | 18.078 |
| boru_rally | comet | 18.964 | 31.742 |
| nala_comet | comet | 19.070 | 24.044 |
| zuri_volt | comet | 17.786 | 20.094 |
| terra | comet | 19.083 | 28.888 |
| koloss | comet | 18.899 | 38.590 |
| glider | glider | 18.624 | 13.866 |
| gecko_velo | glider | 19.129 | 20.556 |
| noa_tide | glider | 19.205 | 18.680 |
| iva_aurora | glider | 19.015 | 15.442 |
| turbo | turbo | 18.976 | 21.208 |
| blitz | turbo | 18.961 | 17.502 |
| phantom | turbo | 19.123 | 16.900 |
| stella | turbo | 19.100 | 19.974 |

Befunde (gelesen bzw. gerendert):
- **Räder**: alle 14 Karts nutzen dasselbe Rad. Das Mesh hat 0,234 m Radius, der Radknoten
  ist ×1,5 skaliert → wirksamer Radius 0,35 m = Nabenhöhe; im Kart gemessen liegt die
  Reifenunterkante exakt auf y = 0. Die Drehung (`motion_speed * delta / 0.35`) rollt damit
  schlupffrei. (Erste Fassung dieses Inventars hatte hier fälschlich „ein Drittel zu langsam“
  – ohne den Knotenmaßstab gerechnet; per Engine-Messung korrigiert.)
- Lenkung: Vorderräder ±0,34 rad, Lenkrad ±0,40 rad – vorhanden.
- **Federung**: auf den Produktions-Karts keine Feder- oder Aufbaubewegung (nur der alte
  Ersatz-Kart wippt die Naben). Kein Nicken beim Bremsen/Beschleunigen, kein Rollen in Kurven.
- Bremslicht: Emission der `RearBrakeLens` 0,35 → 2,6 beim Bremsen – vorhanden. Rücklicht im
  Dunkeln nicht getrennt.
- Proportionen: Terra (Gelände), Koloss (Schwergewicht) und Blitz (Dragster) haben dieselben
  Räder wie die Sportler; die Rolle ist am Rad nicht ablesbar.
- Meshy-Hüllen: Textur 2048 × 2048 (über der Regel ≤ 1024 px); `.import`-Dateien fehlen im
  Repository (werden beim Import erzeugt). Glider-Hülle zeigt ausgefranste Kotflügelkanten.
- Fahreranker: `DriverSeat` (0, 0,31, 0,20) auf allen drei Plattformen; Tiere werden per
  `kart_production_driver.gd` daran ausgerichtet, Hände folgen den Lenkradgriffen
  (Test `lumo_kart_production_driver_regression`: 8.245 Prüfungen, max. Griff-Fehler 0,2 mm).

## 5. Garage

`kart_garage_menu.gd` + `kart_garage_showroom.gd`: Drehteller, Ziehen zum Drehen, sieben
Prüfansichten, Detailtext, Werkstatt (`kart_workshop.gd`, `kart_tuning.gd`) mit Teilen, Lack,
Felgen, Neon; Anbauteile werden sichtbar montiert (`apply_parts`, mit Einflug-Animation).

## 6. Lücken, die Team B2 jetzt schließt (Reihenfolge)

1. Stehende Tierfiguren mit eigener Ruhepose (aus den Meshy-Originalen, nicht aus dem Sitz)
   und Clip-Bibliothek inkl. echtem Geh- und Laufzyklus mit Fußkontakt → Lieferung an Team C.
2. Konzert-Publikum auf stehende Figuren umstellen.
3. Federung/Aufbaubewegung, Brems-/Rücklicht, Fahrerposition je Kart prüfen.
4. Garage-Präsentation.

## 7. Umgesetzt (Team B2, 26.11.2026)

- **Stehende Tierfiguren** mit 20 Clips: `assets/characters/animals/<id>/figure.glb`,
  Details und Clipnamen in `docs/qa/figuren_clipbibliothek.md`. Konzertpublikum steht jetzt und
  schaut zur Bühne (`rhythm_concert_art.gd`). Die offene Welt nutzt die stehenden Figuren
  (kleine Änderung in `lumo_world_open_world.gd`: Pfad + Gehtempo); die vorhandenen
  Routinen schalten den echten Geh-Clip damit selbst frei.
- **Federung der Produktions-Karts**: neuer Knoten `SprungBody` unter dem Fahrwerk
  (`kart_production_vehicle.gd`); darauf hängen Karosserie-Hülle (alle LODs, Meshy-Nahhülle,
  Aufkleber), `Coachwork`, Zierleisten und Aufbauteile aus der Werkstatt (Motor, Flügel,
  Booster, Ballast). Räder, Achsen, Lenkrad, Sitz- und Pedalpunkte bleiben auf dem Fahrwerk.
  `kart_vehicle.gd` treibt eine gedämpfte Feder (k = 150, d = 13): Bremsen taucht die Nase ein
  (max. ca. 2,5°), Gas lässt das Heck einfedern (ca. 1,3°), Kurven rollen nach außen
  (ca. 1,7° bei vollem Einschlag und hohem Tempo), in der Luft federt der Aufbau aus und
  nach der Landung ein. Ruhige Darstellung (reduced motion) und Pause halten ihn still.
  Test `kart_body_motion_regression` (144 Prüfungen), Bildfolge `kart_body_motion_capture.gd`.
- **Garage, Fold innen (2176 × 1812)**: Werkzeugleiste über der Kartliste war auf „R ⌄“ und
  „We…“ gekürzt → bei hohem Querformat zweizeilig („Rundum ansehen“, darunter „Teile
  wechseln“ + „Werte“ mit gemessener Breite; `kart_spatial_menu.gd`, `kart_parts_bay.gd`).
  Werkstatt-Vorschau schnitt das Kart seitlich ab → Kamera hält bei hoher Bühne die Breite
  (`kart_workshop.gd`).
- Nicht geändert: Radmodelle und -größen je Kart (die Meshy-Radhäuser sind auf das
  gemeinsame Rad gepasst; größere Räder bräuchten neue Hüllen), Bremslicht-Logik
  (funktioniert bereits), Fahrerpositionen (Prüfungen bestehen: Griffe < 1 mm bei Rivalen).
- Bekannt und **nicht von B2 verursacht** (auf Basis 62108c03 identisch): `kart_production_vehicle_regression`
  und `kart_fleet_regression` erwarten `source_paths.size() == 3`, die Meshy-Nahhülle fügt
  einen vierten Pfad hinzu → beide Tests scheitern lokal schon auf der Basis.
