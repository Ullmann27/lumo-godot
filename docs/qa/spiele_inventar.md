# Spiele-Inventar LUMO (Stand 26.11.2026, Team B3b)

Ermittelt aus dem Code, nicht aus älteren Dokumenten: Flutter-App
`Ullmann27/lumo-lernen` (`lib/features/games/spielwelt/spielwelt_routes.dart`,
`lib/features/games/games_content.dart`) und Godot `Ullmann27/lumo-godot`
(`scripts/app/scene_router.gd`, `scripts/games/game_hub_routes.gd`,
`scripts/systems/host_bridge.gd`). Nicht Teil dieses Teams: LUMO Kart
(B3a/B1/B2) und die Open World „Lumo World“ mit Dorf und Bauwelt (Team C).

## Wie ein Kind die Spiele erreicht

- **Spielwelt (Flutter)**: 12 Portale. Flutter-Spiele öffnen einen Flutter-Bildschirm,
  native Spiele starten Godot mit `launch3D scene=<id>`.
- **„Zusätzliche Spielmodi“ (Flutter, aufklappbar)**: Flame-Abenteuer, Vier gewinnt,
  Würfelrennen, Sternenpfad, Wolkeninseln (Godot) und die Lernspiel-Karte mit 50 Stufen.
- **Native Spielewelt (Godot `games`)**: über „3D-Spielewelt“ aus der App; 11 Kacheln
  (`game_hub_routes.gd`), darunter Sternenjagd, die nur hier erreichbar ist.

## Flutter-Spiele (App)

| Spiel | Einstieg | Code | Gegner/KI | Sterne an Wallet |
|---|---|---|---|---|
| Logikspiele: Sudoku-Insel, Wörterwerkstatt, Zahlenbrücken | Portal `logic` | `features/games/logic/` | – | ja (Logik-Fortschritt) |
| Memory | Portal `memory` | `features/games/memory/` (Regeln Dart, Tisch Godot `memory`) | Lumo merkt sich Karten | ja |
| Vier gewinnt | Portal `connectFour`, Zusatzmodi | `features/games/connect_four/` (Regeln Dart, Tisch Godot `connect_four`) | Lumo (Stufen), zu zweit | ja |
| Quizshow „Wer wird Lumo-Meister?“ | Portal `quizShow`, Lernstufe 50 | `features/quiz/` (Studio Godot `quiz`) | – | ja |
| Würfelrennen | Zusatzmodi | `features/games/dice_race/` | Lumo würfelt mit | ja |
| Sternenpfad (Kartenabenteuer) | Zusatzmodi | `features/games/star_trail/` | kooperativ mit Lumo | ja |
| Flame-Abenteuer (Jump & Run 2D) | Zusatzmodi | `features/games/flame/lumo_jump_game.dart` | – | ja |
| Lernspiel-Karte, 49 Stufen + Finale | Zusatzmodi | `domain/games/`, `features/games/mini_games/` | – | ja (je Stufe einmal) |
| – Sterne sammeln (Rechenpfad) | Stufen 1, 3, 4, 6, 9, 11, 12, 16, 17, 39, 41, 42, 45, 46, 48, 49 | `stars_path_game.dart` | – | |
| – Rechenhaus | Stufen 7, 8, 15, 19, 37 | `number_house_game.dart` | – | |
| – Mengen anmalen | `colorBoxes` | `color_boxes_game.dart` | – | |
| – Buchstaben-Lücke (Wortspiel) | `letterFill` | `letter_fill_game.dart` | – | |
| – Zahlenweg, Wörterwald, Lumos Mix | `numberPath`, `wordForest`, `mixedQuiz` | `lesson_trail_game.dart` | – | |

Die Schulstunde der Lumo World (`world/world_school_lesson_screen.dart`) gehört zur Open World.

## Godot-Spiele (nativ)

| Spiel | Szene (`launch3D`) | Code | Gegner/KI | Belohnung an die App |
|---|---|---|---|---|
| Lumo Karten: Sternenstich, Sternenleiter, Lumo-Quartett, Punktlandung | `cards` | `scripts/games/cards/` | 1–3 Mitspieler, 3 Stärken | ja, je Partie einmal (`resultId`) |
| Lumo Schach (Lernweg, Proben, Partie, „Für Große“) | `chess` | `scripts/games/chess/` | Lumo, 4 Stufen | ja bei Sieg/Remis ab Stufe 3 |
| Vier gewinnt – Tisch | `connect_four` | `scripts/games/connect_four/` | Darstellung, Regeln in Flutter | über Flutter |
| Memory – Tisch | `memory` | `scripts/games/memory/` | Darstellung, Regeln in Flutter | über Flutter |
| Quiz-Studio | `quiz` | `scripts/games/quiz/` | Darstellung, Regeln in Flutter | über Flutter |
| Lumo Lauf (Jump & Run 3D) | `run` | `scripts/games/run/` | Geist-Läufer | ja |
| Lumos Sternenpost | `skypost` | `scripts/games/skypost/` | Rivalen-Flieger | ja |
| Wolkeninseln | `jump` | `scripts/games/jump_islands.gd` u. a. | – | ja |
| Puzzle-Atelier | `puzzle` | `scripts/creative/puzzle_world.gd` | – | ja |
| Rhythm Party | `rhythm` | `scripts/creative/rhythm_world.gd` | – | ja |
| Schatzsuche | `treasure` | `scripts/creative/treasure_world.gd` | – | ja |
| Sternenjagd | nur native Spielewelt (`stars`) | `scripts/games/star_collect_game.gd` | – | nein (bewusst, nur Bestzeit) |
| Lese-Welt: Buchstaben-Karussell, Wort-Bild, Laut-Buchstabe, Wörter bauen | `reading_hub`, nur Standalone | `scripts/games/reading_hub.gd` u. a. | – | nein; in der App führt „Lernen“ zurück in die App |
| Lernwerkstatt, Nachhilfe, Holo-Lernraum | `learning`, `tutor`, `holo` | `scenes/learning/` | – | Lernmodule (Team A) |

Ausgeschlossen (andere Teams): `kart`, `kart_parcours` (B3a/B1/B2), `world`, `settlement`,
`build` (Team C).

## Prüfstand je Spiel

Siehe Abschnitt „Ergebnis“ unten und den Bericht von Team B3b.
