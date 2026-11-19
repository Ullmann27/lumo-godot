# TEST_RESULTS – ccr-54af69f2-4uged4 (Integration-2 auf Nullpunkt) – 17.11.2026

## Nachtrag 18.11.2026, Teil 7 – alle 13 Strecken im Kart-Hauptmenü, Dorf mit Wachen, Schutzbauten und Angriffen (alles in dieser Sitzung selbst ausgeführt; kein Gerät)

- **Kart-Hauptmenü** (`808d167`): Die Strecken-Leiste zeigte vier fest eingetragene Strecken; jetzt jede der 13 Katalogstrecken mit eigenem, aus der echten Strecke gerendertem Bild, Pfeile auf dem großen Bild gehen durch alle. `kart_neon_home` 114, `kart_track_selection` 150 (29 Starts, 13 Strecken), `kart_race_kinds` 125, `kart_result_reachability`, `kart_complete_flow` PASS; Menübild 1280×720 gesichtet.
- **Dorfwelt Teil 3** (Merge `4dc2ad0`): Wachen ausbilden, Mauer in drei Stufen, Wachtürme, Tor/Zugbrücke, Graben, Netzfallen, Bündnis, Verhandeln, Kundschafter; drei Gegner mit Grund und drei Tagen Vorwarnung; niemand wird verletzt, Gebäude werden repariert. Vom Helfer begonnen (bei 134 Prüfungen mit 5 Fehlern gestoppt), fertiggestellt: Stärkewerte bleiben beim Laden Kommazahlen, zwei Testszenarien berichtigt, „Wache ausbilden“ steht im Schutz-Plan oben. `build_village_raids` 137 und elf weitere Dorf-Tests PASS auf dem Zweig mit Hauptstand; im Hauptstand danach Import ohne Fehler, `build_village_raids`, `build_village_scene`, die fünf APK-Vorprüfungen und `game_hub_magic` PASS. Zwei Bilder gesichtet (Dorf mit Mauerring, Türmen, Tor, Wachen; Schutz-Plan). Offen: Mauern frei setzen (heute ein Ring in Stufen), Balance über viele Spieltage nur im Regeltest geprüft, Langzeit-Kampagne.

## Nachtrag 18.11.2026, Teil 6 – Tempo im Jump & Run, Kart-Detailschicht, Dorf-Tutorial und KI-Nachbardörfer, CI-Ursachen (alles in dieser Sitzung selbst ausgeführt; kein Gerät, keine FPS)

- **Lumo Lauf schneller** (`40d5f08`, Merge `e912668`): Der Dschungelpfad läuft 1,3-fach (Lumo, Tiere, Plattformen, Sprünge gleichermaßen), dazu Sprint aus freiem Lauf, zwei Tempo-Felder, großzügigere Sprungfenster, Kamera öffnet sich beim Sprint. Messung mit dem automatischen Spieler, 30 Läufe: 109–120 s, Schnitt 113 s (vorher rund 180 s). Am Bildschirm: Grundtempo 11,1 m/s (vorher 8,5), Sprint 15,0, Tempo-Feld 20,9, Lore 16,9 m/s. `lumo_run_regression` 496 (alle 30 Läufe im Ziel, alle vier Buchstaben, beide Wege jeder Gabelung), `lumo_run_flow_regression` 13 (neu), `jump_nextgen` 84 PASS. Verworfen: reines Erhöhen des Lauftempos – dabei lief Lumo am Kristallsims unter der Plattform durch (Buchstabe O unerreichbar, vom Test gefunden). Die Mindestdauer-Prüfung eines Laufs wurde bewusst von 150 s auf 100 s gesenkt. Offen aus dem Tempo-Auftrag: fließende Übergänge der Bewegungen, Aufgaben je Abschnitt, Gegner mit Charakter; Eingabegefühl nur am Gerät zu beurteilen.
- **Laufzeitfehler der Dschungelkulisse** (`94ca0af`, vom Helfer gefunden): `global_shader_parameter_get_list` wurde in jedem Bild aufgerufen und schrieb je Bild ERROR-Zeilen (betraf auch APK 0.13.31). Jetzt einmal je Prozess.
- **Kart-Detailschicht** (Merge `fbd6a60`): Abrieb, Bremsspuren, Kleinteile, Publikum, Streckennamen-Banner, Zielbühne auf 13 Strecken in drei Profilen. 16 Tests auf dem zusammengeführten Zweig grün (u. a. `kart_detail_layer` 13 × 3, `kart_physics`, `kart_complete_flow`, `kart_gameplay_items` 139, `kart_courses_driving` 4 Strecken). Vorher/Nachher-Bilder gesichtet: nichts kaputt, aus der Rennkamera aber zurückhaltend (Holo City kaum sichtbar; Selbsteinschätzung des Helfers 2/5). Zweite Runde offen.
- **Dorfwelt Teil 1 und 2** (Merge `e36799c`): Lumos Einführung in neun Schritten, die ins laufende Spiel übergeht; Nachbardörfer, die nach denselben Regeln sichtbar mit aufbauen. 12 Tests grün (`build_village_tutorial` 49, `build_village_neighbors` 31, `build_village_scene` 232, `build_village_economy` 339, `build_settlement_play` 127, `build_settlement` 194, `build_defense` 162 …). Frische Bilder gesichtet. Offen: Angriffe mit Sinn, Langzeit-Kampagne, App-Anschluss für Sterne.
- **Kartentisch-Namensschilder** (`6fd3e4c`, `aef4dca`): stehen neben dem Kopf, wenn darüber kein Platz ist, und weichen einander aus. `cards_safe_area` 2176/0 (vorher 1 Überlappung im Hochformat), `cards_table` 590. Nicht übernommen: Umbau des 3D-Memory-Tischs (`memory_table_regression` mit Renderer rot, 61 Fehlerzeilen – bleibt auf dem Helfer-Zweig).
- **CI-Ursachen im Spiele-Repository** (seit den Merges vom Vormittag rot): (1) Die neue Kart-Kulisse erzeugte je Streckenaufbau ein neues Himmel-Objekt; wird es vor dem ersten Bild freigegeben, bleiben im Kompatibilitäts-Renderer zwei Texturen hängen („Texture … leaked 87380 bytes“). Jetzt ein Himmel je Vorlage (`cea266b`); `kart_sonnenhafen_darkride_regression` mit Renderer: vorher 2 Leck-Zeilen, nachher 0. (2) `kart_loading_regression` endete, während die Menümusik noch lief („2 resources still in use at exit“); der Test löst die Wiedergabe vor dem Ende (`5734d01`): vorher 4 von 4 Läufen mit Meldung, nachher 2 von 2 ohne. Weitere CI-Schritte dahinter sind erst mit dem nächsten CI-Lauf belegt.
- Hauptstand nach allen Merges: Import ohne Fehler; `kart_complete_flow`, `kart_track_selection` (Fall A), `kart_detail_layer`, `kart_loading` (96), `kart_real_lumo`, `cards_table` (590), `cards_safe_area` (2176), `native_table_boot`, Dorf-Tests, `real_lumo_everywhere` (376), `game_soundscape` (308), `game_hub_magic` PASS.

## Nachtrag 18.11.2026, Teil 5 – schwarze Partikel, Lumos Laufstil (Stand `9636a3c`; alles in dieser Sitzung selbst ausgeführt; kein Gerät, keine FPS)

- **Schwarzes Quadrat auf Dschungelherz** (`ed6ec66`): Ursache war ein Partikel-`QuadMesh` ohne Farbattribut zusammen mit `vertex_color_use_as_albedo`; im Kompatibilitäts-Renderer (mit dem die App die Spiele am Handy startet) wurden einzelne Partikel schwarz gezeichnet. Probe-Szene: 110 dunkle Pixel mit QuadMesh, 4 mit eingefärbtem Quad. `kart_jungle_environment_regression` und der Item-Test der Strecke PASS.
- **Gleiche Ursache an drei weiteren Stellen** (`3ccdf2e`): Kart-Konfetti, Item-Wölkchen, Lauf-Staub nutzen jetzt `scripts/systems/particle_quad.gd`. `kart_gameplay_items` 139, `kart_complete_flow`, `kart_drive_fx` 155, `lumo_run` 496 PASS. Additive Effekte (Kartenstaub, Glühen, Memory-Funkeln, Himmelsinseln) sind nicht betroffen und unverändert.
- **Lumo läuft sichtbar** (`9636a3c`): Messung im Jump & Run bei 8 m/s – Fußabstand vor/zurück 0,42 m → 0,76 m, Fußhub 0,12 m → 0,35 m, Arm-Spreizung 70° → 101°, 2,8 → 2,3 Schritte je Sekunde. Die Lauf-Pose hat einen optionalen Stil (`set_style`), Standard bleibt der ruhige Gang der Erkundungswelten. `lumo_studio_motion` 1047, `lumo_teacher_pose` 34, `jump_nextgen` 84, `real_lumo_everywhere` 370, `lumo_run` 496 PASS; Bildfolge von der Seite vorher/nachher gesichtet.
- Nicht in APK 0.13.31+2043 enthalten (die steht auf `6e54cfb`); kommt mit dem nächsten Build.

## Nachtrag 18.11.2026, Teil 4 – Klangwelt, Dorfwelt, Lumo-Lauf-Kulisse, Spielzimmer (Stand `6e54cfb`; alles in dieser Sitzung selbst ausgeführt; kein Gerät, keine FPS, Klänge nicht angehört)

Die Helfer dieser vier Pakete wurden am Nutzungslimit gestoppt. Ihr letzter Arbeitsstand wurde gesichert, mit dem Hauptstand zusammengeführt, getestet und – wo es Bilder gibt – gesichtet:
- **Klangwelt** (`b594543`): eigene Musik, Atmosphären, Ereignistöne; `AudioManager` mit echten Samples, Autoload `GameSoundscape`. `game_soundscape_regression` 308 Prüfungen (nach Zuordnung des neuen Vier-gewinnt-Tons `disc_clack` → `piece_drop`, `6e54cfb`), `kart_audio`, `lumo_run` (490), `cards_table`, `rhythm_party`, `treasure_island`, `validate_project` PASS.
- **Dorfwelt** (`cbeb7c0`): Höhenkarten-Gelände, Fluss, Fachwerkhäuser, Blattbüschel-Bäume, Gründerlager, Kapitel 1/12, HUD mit Kamera-Gesten. 17 Tests grün (u. a. `build_village_scene` 232, `build_village_economy` 339, `build_settlement_play` 127, `build_settlement` 194, `build_defense` 162, `build_dialog_density` 2016). Ein Typfehler im letzten Arbeitsschritt (Laub-Material) wurde behoben; 14 Bilder gesichtet. `build_premium_props_regression` braucht einen Renderer und hängt im reinen Rechenmodus (auch im Hauptstand vor dem Merge) – NICHT AUSGEFÜHRT.
- **Lumo Lauf – Dschungelkulisse** (`abbc3f3`): Bäume, Farne, Bodendecker, Schatz, Kristalllicht aus eigenen Blender-Modellen. `lumo_run_regression` 496 Prüfungen; 24 Bilder aus dem gespielten Lauf gesichtet (alle sechs Abschnitte, Fass, Liane, Seilbahn, Felsball, Schatzhalle, Lore, Lernstopp).
- **Spielzimmer** (`fbac669`): Kartentisch, Memory, 4 Gewinnt, Quiz mit eigenen Texturen und Blender-Möbeln. `cards_table` 591, `cards_safe_area` 2176 (9 Bildschirmformen), `cards_rules` 212 968, `connect_four_return` 21, `native_table_boot` 26. Kartentisch-Bilder gesichtet. Offen: am 3D-Memory-Tisch ist Lumo im Querformat angeschnitten (von der App nicht gestartet); `memory_table_regression`, `connect_four_runtime`, `quiz_studio_runtime` brauchen Aufnahme-Verzeichnisse – NICHT AUSGEFÜHRT.
- Kombination im Hauptstand nach allen Merges: Import ohne Fehler; `kart_track_selection` (Fall A), `kart_items_all_courses` (3 Strecken, 164), `kart_complete_flow`, `kart_real_lumo`, `real_lumo_everywhere` (369), `game_hub_magic`, `native_table_boot`, Dorf- und Lauf-Tests grün; die fünf Vorprüfungen des APK-Workflows grün.

Noch nicht zusammengeführt (Helfer laufen weiter): Figuren der Rivalen, Garage/Fahrzeug-Feinheiten/Item-Anzeige/Siegerbild, Kart-Detailschicht (eigener Test: 2 Fehler bei Zauberwald-Zählern, 12 Fehlerzeilen aus einem verzögerten Aufruf).

## Nachtrag 18.11.2026, Teil 3 – Streckenwahl (#204), Items auf allen Strecken (#205), Zusammenführungen (alles in dieser Sitzung selbst ausgeführt; kein Gerät, keine FPS, kein Mobile-Renderer)

**Issue #204 – gewählte Strecke startete Sonnenhafen.** Reproduziert mit echten Bildschirm-Tipps (`kart_track_selection_regression`, vor der Reparatur 18 Fehler):
- Ursache 1: Ein angetipptes Streckenbild im Hauptmenü wurde nur hervorgehoben, nicht an das Rennen übergeben; die Kachel „Rennen“ startete die Voreinstellung Sonnenhafen. Auch ohne Tippen war Vulkan hervorgehoben und Sonnenhafen wurde gestartet.
- Ursache 2: Die große Strecken-Kachel öffnete die Rennwelten mit der Vorgabe „Sternen-Cup“; START begann den Cup auf Strecke 1, die Streckenliste war nicht sichtbar.
- Nach der Reparatur (`932b33f`): 150 Prüfungen / 0 Fehler, 29 Rennstarts, 13 verschiedene geladene Strecken, 71 echte Touch-Eingaben. Wege: Streckenbild → „Rennen“ (Vulkan, Dschungelherz, Wüste, Sonnenhafen); angezeigtes Highlight → „Rennen“; Highlight-Kachel → Rennwelten → START; Leiste „Strecken“ → Streckenkarte → START für alle 13 Strecken (Liste wird gescrollt); Zeitfahren und Training; Rückkehr ins Menü und erneuter Start; nach einem Cup. Geprüft wird die tatsächlich gebaute Welt (`world.track_id`), nicht die Menüauswahl.
- Bildbelege mit Renderer: 14 Bilder (Menü nach dem Tipp und laufendes Rennen), gesichtet.
- Dazu grün: `kart_complete_flow`, `kart_regression`, `kart_modes`, `kart_race_bridge`, `kart_race_kinds` (125), `kart_neon_home` (40, an den neuen Vertrag angepasst), `kart_neon_readability` (1180), `kart_nextgen_garage` (93, erwartet jetzt 13 statt 12 Strecken); mit Renderer `kart_menu_flow`, `kart_start_hero`, `kart_reference_landing_fit`.
- Diagnosezeilen im Log: `[Kart] track_selected: <id> mode=<modus>` und `[Kart] race_world_ready: <id> mode=<modus>` (mit Fehlerzeile, falls die gebaute Welt abweicht). Unbekannte Strecken starten nicht mehr stillschweigend Sonnenhafen.
- **Nicht geprüft:** Android-Emulator und Fold. Der Fehler gilt erst nach Heinz' Gerätetest als abgenommen.

**Issue #205 – Items und Fahr-Effekte auf allen 13 Strecken** (`kart_items_all_courses_regression`, 634 Prüfungen / 0 Fehler): je Strecke 6 Überraschungsboxen (innerhalb der Planken, auf Kart-Höhe, nicht an Rampe/Looping/Hindernis), 5–12 Könner-Ringe, 2 Turbo-Ringe; eine Box wird durch echtes Fahren eingesammelt (etwa 67 Physikschritte), das Item-Rad kommt zur Ruhe; Sternraketen: schärfen, Zielerfassung, Paar feuern, Rivale dreht sich, Schonzeit; Schild wehrt ab; ohne Schild genau ein Treffer und keine Trefferschleife in der Schonzeit; Rivale warnt und feuert; Drift-Funken und -Spuren; Belag je Strecke (Wald, Sand, Schnee, Lava, Sternenglas, Stein, Fliesen). Dschungelherz fuhr mit Asphalt-Effekten und nutzt jetzt den Waldboden. **Nicht geprüft:** Balance im echten Rennen über mehrere Runden, Gerät.

**Zusammengeführt** (jeweils auf dem zusammengeführten Stand geprüft):
- Abenteuerwelten (`5a3747d`): Schatzinsel, Konzertbühne, Puzzle-Atelier, Spielewelt. 14 Tests grün; ein Rückschritt der neuen Kamera (Meldungszeile verdeckte Lumo im Hochformat, `treasure_title_contrast_regression` 4 Fehler) wurde vor der Übernahme behoben (941 Prüfungen).
- Kart-Kulisse und Fahr-Effekte Runde 2: siehe Merge-Commit darunter.

Bekannt veraltet (prüfen das frühere Menü, laufen in keinem Workflow dieses Zweigs): `kart_home_experience_regression`, `kart_spatial_menu_regression` (greifen auf `_mode_buttons`/`_modes` zu, die es im Neon-Menü nicht gibt).

## Nachtrag 18.11.2026, Teil 2 (Stand `8ec2910`, alles in dieser Sitzung selbst ausgeführt; kein Gerät, keine FPS, kein Mobile-Renderer)

Zusammengeführt und auf dem jeweils zusammengeführten Stand geprüft (headless, ohne `ERROR`-Zeilen):
- **Echter Lumo in Schatzsuche, Rhythmus, Home und Lernszenen** (`60127d0`, `94ceb3a`): `real_lumo_everywhere_regression` 344 Prüfungen.
- **Kart-Item-System** (`ddf5bc7`, Korrekturen `a3ddf7e`): Sternraketen mit Haltern links/rechts, Zielerfassung, Schildkuppel, Falle, Glücksstern. `kart_gameplay_items_regression` 139 Prüfungen. Zwei Fehler aus der CI behoben: fehlender Schlüssel `pair` bei Fallen, aufschaukelndes Blickfeld (`p_fov > 179`).
- **Gerenderte Renn-Knöpfe und neues Renn-HUD** (`4e632df`): `kart_hud_controls_regression` 978 Prüfungen; dazu `kart_complete_flow`, `kart_regression`, `kart_race_bridge`, `kart_result_reachability` (11 Displaygrößen), `kart_modes`, `kart_real_lumo` (13); mit Renderer `kart_pause_layout`, `kart_menu_flow`, `kart_start_hero`.
- **Fahr-Effekte an echten Fahrzuständen** (`8ec2910`): Funken und Schleifspur an der Leitplanke, Bremsspur und -rauch, Turbo, Drift in vier Stufen, Staub je Untergrund, Landung, Motor in drei Lastschichten. `kart_drive_fx_regression` 120 Prüfungen (u. a. gerade Fahrt erzeugt nichts, Pause friert ein, Budgets je Profil); dazu `kart_regression`, `kart_complete_flow`, `kart_gameplay_items` (139), `kart_hud_controls`, `kart_physics`, `kart_audio`, `kart_real_lumo` (13), `kart_race_bridge`, `kart_modes`; `kart_courses_driving_regression -- --tracks=sonnenhafen,volcano_night`: je zwei Runden ohne Rücksetzer. Messung des Helfers (HIGH, 1600x720, gl_compatibility): +4 Zeichenaufrufe (277 → 281).

Ehrliche Einordnung der Fahr-Effekte nach Sicht der Engine-Bilder: Funken, Turbo-Linien und Lava-Glut wirken; Bremsspur (Leiter-Muster), Bremsrauch und Staub auf Sand/Wald sind noch zu schwach, die Turbo-Flamme ist ein Strahl. Zweite Runde läuft. Klänge wurden nur rechnerisch geprüft, nicht angehört.

## Nachtrag 18.11.2026 (Stand `786f3fa`, alles in dieser Sitzung selbst ausgeführt; kein Gerät, keine FPS)

Zusammengeführt und geprüft:
- **Kartentisch** (`e80a4cb`): drei eigene Spiele statt UNO. `cards_rules_regression` 212 968 Prüfungen / 0 Fehler, `cards_table_regression` 595, `cards_safe_area_regression` 2 176 (9 Bildschirmformen), `native_table_boot_regression` 26, `game_hub_magic_regression` und `host_bridge_regression` grün; 32 Engine-Bilder gesichtet.
- **Lumo Lauf – Dschungelherz** (`3b3b16e`, `5c23f67`): `lumo_run_regression` 490 Prüfungen, 30/30 Testläufe im Ziel (Mittel 180 s); Messung im Renderer: höchstens 316 Zeichenaufrufe, 382 320 Dreiecke; 48 Engine-Bilder nach Aufhellung gesichtet.
- **Karts** (`5b42231`, `353ea2b`): alle 14 Karts auf den drei in Blender gebauten Karosserien, neuer Frontflügel. `kart_fleet_regression`, `kart_production_vehicle_regression` (495), `kart_vehicle_detail_regression`, `kart_cinema_kart_regression`, `lumo_kart_production_regression`, `kart_character_pose_regression` (2 306) grün; Blender-Prüfungen `inspect_mechanics.py` (Reifen frei bei sieben Lenkwinkeln) und `verify_kart_exports.py` bestanden; Dreiecke 48 450 / 49 166 / 49 166 (Grenze 50 000).
- **Echter Lumo im Kart** (`786f3fa`): `kart_real_lumo_regression` 13 Prüfungen; `kart_modes_regression` grün.
- CI auf `3b3b16e`: keine fehlgeschlagene Prüfung (zuvor rot: `kart-stage2` wegen zweier Tests, die noch die Ersatzfiguren erwarteten – angepasst; Vorher-Importe der Küsten-Workflows stürzten am Referenz-CSV ab – behoben).

Bekannt veraltet, nicht in der CI, nicht behoben: `kart_modular_parts_regression`, `kart_rival_finish_regression` (prüfen die im Code gebauten Ersatzfiguren/-karosserien, die nur noch Notfall-Ersatz sind), `kart_track_pass_regression`, `kart_adventure_regression` (erwarten 12 statt 13 Strecken).

In Arbeit (noch nicht in diesem Stand): Item-System mit Raketen/Zielerfassung/Schild, Grafik-Durchgang Dschungelherz, echter Lumo in Schatzsuche und Rhythmus-Spiel.

Basis `lumo-nullpunkt/integration-20261117` @ `ebd3401`. Nicht nach main gemergt, kein Release, keine APK aus diesem Stand.
Alle Angaben: in dieser Sitzung selbst ausgeführt, Linux, Godot 4.6.3. Renderer-Tests unter Xvfb mit Software-GL. Keine Geräte- und keine FPS-Aussage.

## Reparaturen
- `8eb2493` Ergebnisdialog: „Zur Spieleauswahl“/„Zum Lernen“ lagen unterhalb des sichtbaren Scrollbereichs (Handy quer, Fold außen/innen, 800×480). Ursache des roten `kart_complete_flow_regression.gd:450`. Neu: `kart_result_reachability_regression.gd` (5 Displaygrößen; ohne Fix rot).
- `a5061c7` Himmelsinseln-Sprung: seit der verlängerten Route (`f5cc417`, per Bisect bestimmt) nur noch 0,48 s Flug. Jetzt 0,75 s; Schleichfahrt fällt weiter. Ursache des roten `kart_jump_regression`.

## Integration-2 (einzeln gemergt)
memory-godot `90f0c4e`, kreativ `f6a2b44`, bauwelt `6005586`, kart (Bauteile) `a1587ff`, tutor-godot `55c0135` (WIP, in der App nicht erreichbar), menu-strecken `9f5e30b` (2 Konflikte gelöst).
Nicht gemergt: `lumo-kart/gameplay-items-20261117` @ `17b63b4` – zweites Item-System neben den Resonanz-Ringen, 24 Konfliktblöcke; braucht ein eigenes Paket. Stream-Berichte unverändert unter `docs/integration-2/`.

## Grün
- Import ohne Fehler.
- Alle Schritte aus `tools/validate_project.sh` (22 Tests). Der Gesamtlauf brach unter Parallellast bei `kart_pause_layout_regression` am 180-s-Limit ab; einzeln wiederholt grün, ebenso die vier folgenden.
- Kart: complete_flow, result_reachability, jump, regression, physics, touch, race_bridge, host_bridge, precision_jump (55), neon_home (38), neon_readability (1180), adventure_drama (874), track_pieces, loop_seam, nextgen_ui_smoke; unter Xvfb: rival_flight, stunt_continuity, sonnenhafen_stunt, pause_layout.
- Memory: `memory_table_regression` mit CI-Parametern (7020 Prüfungen, 8 Bilder), `memory_table_capture`.
- Bauwelt/Dorf: campaign_map (54), defense (162), frontier, settlement (194), settlement_play (127), village_economy (339), village_scaling, nextgen_play, sandbox_tools.
- Schatzsuche: island, density (1085), exploration (92), wisp. Rhythmus: party, tour (2118), tour_play (87).

## Szenenkosten vorher/nachher (Xvfb, gl_compatibility, 1280×720, Rennansicht; lastunabhängige Zähler)
| Strecke | Zeichenaufrufe Basis → jetzt | Dreiecke Basis → jetzt | Lichter |
|---|---|---|---|
| Sonnenhafen | 666 → 671 | 2.133.163 → 2.136.945 | 2 → 2 |
| Himmelsinseln | 425 → 425 | 792.596 → 792.596 | 6 → 6 |
| Vulkan | 409 → 436 | 884.096 → 889.844 | 6 → 6 |
| Dschungelherz | 324 → 329 | 882.946 → 887.998 | 0 → 0 |
| Holo City | 438 → 438 | 1.137.618 → 1.137.618 | 6 → 6 |

Die Integration-2-Streams machen die Szenen nicht spürbar schwerer. Unabhängig davon ist Sonnenhafen mit rund 670 Zeichenaufrufen und 2,1 Mio. Dreiecken pro Bild für Handys viel; das ist keine Gerätemessung.

## CI-Fristen
`kart_reference_host_visual` lief in CI nach bestandenen Prüfungen ins 120-s-Limit (auf der Basis ebenso), ein Fall in `real-godot-tests` ins 180-s-Limit. Beide Fristen für Software-Rendering angehoben (300 s bzw. 360 s); keine Prüfung geändert.

## Nicht gelaufen
- Übrige rund 300 Testskripte, alle Capture-/Visual-Workflows, CI auf diesem Kopf.
- Nachhilfe-Szene (kein Test vorhanden), Puzzle, Karten-, 4-Gewinnt-, Quiz-Tisch.
- APK, Emulator, Gerät, Fold: NOT RUN.

---

# TEST_RESULTS – lumo-2040/bauwelt-20261117 (PR #195)

Stand: 17.11.2026 ca. 13:30 (Europe/Vienna). Basis bb478880. Godot 4.6.3, Xvfb/llvmpipe, gl_compatibility. Keine FPS-Aussagen.

## Grün (lokal, dieser Branch)
| Test | Ergebnis |
|---|---|
| build_campaign_map_regression (neu) | PASS 54 checks |
| build_defense_regression (neu, nur Logik) | PASS 162 checks |
| build_dialog_density_regression | PASS 2018 checks |
| build_sandbox_ui_regression | PASS |
| build_sandbox_tools_regression | PASS |
| build_village_scene_regression | PASS 232 checks |
| build_settlement_play_regression | PASS 127 checks |
| build_settlement_regression | PASS 194 checks |
| build_village_economy_regression | PASS 339 checks |
| build_village_scaling_regression | PASS 42 checks |
| build_village_art_regression | 2259 checks / 0 failures |
| build_frontier_regression | PASS 14 checks |
| build_transform_regression | PASS 38 checks |
| build_premium_props_regression | PASS |
| build_nextgen_play_regression | PASS 71 checks |
| village_host_launch_regression | PASS |
| mobile_safe_area_regression | 380 checks / 0 failures, aber 1 SCRIPT ERROR in `scripts/lumo_next/learning_world_next.gd:375` (nicht von diesem Branch geändert) |

## Rot
- `tools/validate_project.sh`: Exit 1 bei `[KartPhysics] FAIL: 22 of 24 checks completed`. Dieser Branch ändert keine Kart-Datei. Ob der Fehler auf der Basis bb478880 auch auftritt, wurde nicht geprüft. Möglicherweise lief gleichzeitig ein anderer Strang mit denselben `/tmp/lumo-*.log`-Pfaden. Alle Schritte davor waren PASS (Import, Kart, HostBridge, Jump, Gait, RenderKit, EnvApply, CreativePresets, KartRaceBridge, KartSplit). Die Schritte danach sind NOT RUN.

## Draw Calls Startansicht (scripts/tests/bauwelt_hud_capture.gd)
| Ansicht | vorher LOW/MED/HIGH | nachher LOW/MED/HIGH | Ziel LOW/HIGH |
|---|---|---|---|
| Freie Bauwelt | 230 / 304 / 304 | 237 / 311 / 313 | ≤170 / ≤255 → **verfehlt** |
| Dorf | 121 / 173 / 187 | 157 / 209 / 223 | erfüllt |
| Kampagnenkarte (neu) | – | 184 / 184 / 224 | – |
Bauwelt-Analyse: 3D allein 114 auf LOW. Das HUD kostet in gl_compatibility ca. 123 Draw Calls (je sichtbarer Button Stylebox plus Text). Das alte HUD kostete etwa gleich viel. Für das Ziel müsste die Werkzeugleiste umgebaut werden (weniger gleichzeitig sichtbare Buttons). Offen.

## NOT RUN
- DEVICE TEST NOT RUN · FOLD7 NOT RUN.
- After-Captures im Hochformat: Bauwelt vorhanden, Dorf und Karte im Hochformat nicht (Capture-Lauf abgebrochen, Exit 143). Ein früherer Lauf mit Karte im Hochformat liegt vor dem letzten Farbfix.

## Offen (nicht im Spielfluss)
- Strategie: Regeln, Hasen-Wellen-KI, Stufen-Schwierigkeit, Übernahme und Rückeroberung sowie Tutorial-Status existieren nur als getestete Logik (`build_defense_sim.gd`, `build_defense_state.gd`, `spend_committed`). Keine UI, keine 3D-Einheiten, nicht im Spiel erreichbar.
- Einheitenvisuals, Formationen, große Weltkarte, sichtbar wachsende KI-Dörfer, Effekte (Pfeile, Staub, Fahnen): nicht begonnen.
- Sandbox-Möbel und Robo-Dialoge: nicht begonnen.

---

# TEST_RESULTS – lumo-2013/bauwelt-sandbox-20261110 (PR #144)

Stand: 10.11.2026 19:55 (Europe/Vienna), Abschluss nach Nutzungslimit. Basis fe493ea1 (#140).

## Commits von Lumo · Design
- 6309c9a9: leerer WIP-Checkpoint (kein Feature-Code). Lokal nichts getestet.

## Commits eines anderen Bearbeiters (Ullmann27, 14:40–14:52), nicht von mir geprüft
- cf42829..44da602: Füllen/Kopieren/Spiegeln als atomare Werkzeuge inkl. Touch-UI, Tests
  `scripts/tests/build_sandbox_tools_regression.gd`, `scripts/tests/build_sandbox_ui_regression.gd`.
- GitHub-Checks auf 44da602 (abgefragt 10.11.2026 19:55):
  real-godot-tests success, real-native-proof (bauwelt) success, real-native-proof (precision) success,
  combined-godot-runtime success, Gitar success, **verify failure**, CodeRabbit skipped.
  Ursache des verify-Fehlers: nicht untersucht.

## Nicht gelaufen (von mir)
- `tools/validate_project.sh`: NOT RUN. VISUAL PROOF NOT RUN, DEVICE TEST NOT RUN, FOLD7 NOT RUN.

## Nächster Schritt
1. verify-Fehler auf 44da602 klären.
2. M1 Rest: Chunks/MultiMesh, Migrationstest SAVE_VERSION 1, Vorher/Nachher-Captures.
3. M2: Funktionsblöcke + Spielmodus. M3: Robo-NPCs, JSON-Missionen, Wallet.

---

# TEST_RESULTS – lumo-2013/creative-godot-20261110 (PR #141)

Stand: 10.11.2026, Abschluss nach Nutzungslimit. Head vor diesem Commit: 93af86afcfebc17f9720f38a84db0c9c57ffcb4b.

## Grün (vor dem Stopp, 10.11.2026)
- `scripts/tests/treasure_island_regression.gd` – grün (Schatzsuche R3 @76f63a3)
- `scripts/tests/rhythm_party_regression.gd` – grün (nach MultiMesh-Bündelung, vor Membran-Fix)
- `creative_adventure_capture.gd -- --logic-only` – grün
- `creative_scene_smoke` – grün

## Draw Calls (Godot 4.6.3 headless, Xvfb/llvmpipe, gl_compatibility)
- Schatzsuche Overview: LOW 148→138, MEDIUM 254→243, HIGH 278→265
- Rhythm (WIP @93af86a): LOW 105, MEDIUM 187, HIGH 188 (Ziele ≤160/≤250/≤280)

## Nicht gelaufen
- Membran-Fix der seitlichen Lautsprecher (@93af86a): NICHT GETESTET, kein Recapture. `after/rhythm_*.png` gilt nicht als Optik-Abnahme; Referenz `after/rhythm_*_preopt.png`.
- `tools/validate_project.sh` nach dem letzten Commit: NOT RUN
- VISUAL PROOF (Rhythm nach Fix) NOT RUN, DEVICE TEST NOT RUN, FOLD7 NOT RUN

## Nächster Schritt
Rhythm neu rendern, mit preopt vergleichen, Regression + validate_project.sh, dann Abnahme.

---

# TEST_RESULTS – lumo-nullpunkt/integration-20261117 (PR #197) – Stand 17.11.2026 13:30 (Europe/Vienna)

Abbruch wegen Nutzungslimit (90 %). **Nicht nach main gemergt**: CI auf dem Kopf-SHA ist nicht grün.

## Reparaturen in diesem Zweig
- `scripts/games/kart_jungle_environment.gd` fehlte auf allen Branches → Dschungelherz stürzte ab. Neu implementiert (Wald, Wasser, Wahrzeichen, Glühwürmchen, Regen, Zielblüten) + `kart_jungle_environment_regression.gd` (lokal PASS).
- `kart_jungle_audio.gd`: fehlende Original-Ambience-Loops → stiller Fallback statt Fehler.
- `kart_neon_layout.gd`: griff auf nicht existierende `badge_label`/`art_frame` zu → Absturz im Kart-Menü. Lokal: `kart_aaa_menu_capture` PASS.
- `kart_regression` Lenk-Flake: Ursache ist persistiertes `auto_gas=false` in `user://kart_preferences.cfg` (von anderen Kart-Tests gespeichert). Mit dieser Datei vor dem Fix reproduzierbar FAIL, nach dem Fix PASS.
- Tests an 13 Strecken / Gate-Struktur / Jungle-Leitplanken angepasst. `build.yml`: Pillow installiert; Release/Pages nur noch bei manuellem Start mit publish=true.

## Lokal (Box, Godot 4.6.3)
validate_project rc=0, import PASS, kart_precision_jump PASS, sonnenhafen stunt/water/darkride/long/visual_finish/hero_coast PASS, kart_regression PASS, progress_profile_lifetime PASS, kart_nextgen_ui_smoke PASS, kart_reference_host_visual PASS.

## Offen / rot (mit Grund)
- CI `real-two-lap-race` (`kart_complete_flow_regression.gd:450`): nach „Zur Spieleauswahl“ ist die letzte Rückgabe nicht `completed` mit der erwarteten resultId. Lokal reproduziert, Ursache noch nicht gefunden (Diagnosemeldung ergänzt).
- CI `build` → `kart_jump_regression`: „A real flight (0.48 s)“ (> 0.5 s erwartet). Nicht untersucht.
- CI `nextgen-visual`: `kart_reference_host_visual` Timeout 120 s in CI, lokal PASS.
- CI `grounded-harbor`: einmal Segfault 139 (Vulkan-Fehler im Runner), Re-Run angestoßen.
- `kart-stage2` (kart_physics_regression): Ergebnis nach den Test-Anpassungen noch ausstehend.
- Integration-2 (lumo-2040/*, lumo-kart/*, #196/#200-Mapping, #529 Memory-Fix): **nicht begonnen**.
- lumo-2013 WIP-Stränge #143/#145/#146 und #144 nicht gemergt (Konflikte, siehe Inventur).
- DEVICE/FOLD7 NOT RUN.
