# Kartentisch (Sternenstich, Sternenleiter, Lumo-Quartett) – Anschluss an die App

Stand: 18.11.2026, Godot-Branch `agent/kartentisch`. Geprüft gegen den App-Stand
`lumo-lernen` `b538a3f3` (nur gelesen, nichts geändert).

## Kurzfassung

Der neue Tisch ist **eigenständig**: Regeln, KI, Spielstand und Ergebnis-ID liegen
vollständig in Godot (`scripts/games/cards/`). Er braucht von der App **keinen
Spielzustand und keinen Token** mehr. Die bisherige Mailbox-Architektur des
UNO-artigen Tisches (Dart hält die Runde, Godot zeigt sie nur an) entfällt.

## 1. Was der neue Tisch von der Brücke nutzt

Alle Aufrufe laufen über `HostBridge` (`scripts/systems/host_bridge.gd`) und
damit über das Android-Plugin `LumoHost` in `LumoGameActivity`:

| Godot-Aufruf | `LumoHost`-Methode | Wozu |
|---|---|---|
| `HostBridge.launch_options()` | `getLaunchOptions()` | liest `childKey`, `sessionId`, `reduceAnimations`, `displayDensity`, optional `soundEnabled` |
| `HostBridge.new_result_id()` | – (lokal) | eindeutige Ergebnis-ID je Partie: `cards-<spiel>-<sessionId>-<ms>-<µs>` |
| `HostBridge.reward(payload)` | `reward(json)` | meldet das Ergebnis einer **beendeten** Partie genau einmal |
| `HostBridge.return_to_app("games")` | `returnToApp("games", json)` | Zurück-Knopf der Spielauswahl, Android-Zurück, „Spielewelt“ im Endstand |
| `HostBridge.is_embedded()` | – | unterscheidet App-Start und Desktop-Start |
| `MobileRuntime` Safe-Area | vorhandene Rand-Messung | unverändert wie bisher (Edge-to-Edge für `game == "cards"`) |

Ergebnis-Payload (`cards_session.gd`, `settle()`):

```json
{"resultId": "cards-stich-…", "game": "cards", "variant": "stich|leiter|quartett",
 "sessionId": "…", "status": "completed", "stars": 1-5, "xp": 10×stars,
 "place": 1-4, "players": 2-4, "difficulty": 0-2, "rounds": 1|3|5, "points": n}
```

Doppelbuchung ist in Godot dreifach ausgeschlossen: Ergebnis-ID wird beim
Partiestart festgelegt und mitgespeichert; `settle()` führt eine Liste gebuchter
IDs in der Kinddatei (`user://lumo_cards_<sha256(childKey)>.json`); `HostBridge`
merkt sich gemeldete IDs und hält unbestätigte Ergebnisse bis zur Bestätigung.

Spielstand-Speicher: eine Datei je Kind (`childKey`), atomar geschrieben;
enthält laufende Partien je Spiel, Einstellungen, gesehene Einführungen,
gebuchte IDs und Statistik. Die App muss dafür nichts tun.

## 2. Was die App ändern **muss** (sonst gehen Sterne verloren / Rückkehr hängt)

1. **`GameEventStore.recordReward` (Kotlin)** lässt nur
   `game in {kart, jump, puzzle, build, rhythm, treasure}` zu. Ein Ergebnis mit
   `"game": "cards"` wirft dort eine Ausnahme → `reward()` liefert `false` →
   `HostBridge` behält das Ergebnis als offen, zeigt „Speichern fehlgeschlagen“
   und **`returnToApp` scheitert**, solange das Ergebnis nicht angenommen ist.
   → `"cards"` in die erlaubte Menge aufnehmen.
2. **`EmbeddedGameService._readEvents` (Dart, `lib/core/embedded_game_service.dart`)**
   überspringt Ergebnisse, deren `game` nicht in derselben Liste steht, und
   verlangt `xp` (oder `solved`). → `'cards'` aufnehmen. `xp` liefert der Tisch
   jetzt mit (zehn je Stern).
3. **Start ohne Token:** `lumo3d_launcher.dart` (Prüfung `scene == 'cards'` →
   `cardsToken` Pflicht) und `MainActivity.kt` (Fehler `invalid_cards` ohne
   32-stelligen Token) verlangen einen `cardsToken`. Der neue Tisch braucht ihn
   nicht. → Pflicht entfernen; `childKey`, `sessionId`, `reduceAnimations`
   weiter übergeben, optional `soundEnabled` aus den Einstellungen.
4. **Einstieg in der Spielwelt:** `games_content.dart` → `_launchLumoCards()`
   öffnet heute `LumoCardsShowcaseScreen`/`LumoCardsScreen` (UNO-artiges
   Flutter-Spiel) und erst von dort per `LumoCardsTableSession` den Godot-Tisch.
   → direkt `launchLumo3D(context, scene: 'cards', appState: …)` aufrufen
   (Tagesauftrag-/`canPlayToday`-Prüfung wie bei den anderen 3D-Spielen davor).
   Die Spielauswahl der drei Spiele zeigt der Tisch selbst.

## 3. Was dadurch überflüssig wird

Android (`tools/auto_install/`):

- `CardsAuthorityService.kt` – ganzer Dienst (hielt den Dart-Spielzustand sichtbar am Leben).
- `CardsTableBridge.kt` – ganze Mailbox (`lumo_cards_table_v1/<token>/state.json`,
  `request.json`, `lifecycle.json`, Kanal `lumo_lernen/cards_table`).
- In `LumoGameActivity.kt`: `CardsLifecycleHeartbeat`, `cardsAuthority`,
  `cardsBindingRequested`, `cardsConnection`, `cardsBindingTimeout`,
  `writeCardsLifecycle`, `cardsAuthorityAvailable`, `releaseCardsAuthority`,
  das Binden an `CardsAuthorityService`, `cardsToken()`, sowie die
  `@UsedByGodot`-Methoden **`getCardsState()`** und **`submitCardsAction()`**.
  **Bleiben muss:** `cardsEdgeToEdge`/`updateCardsWindowAppearance` (der Tisch
  zeichnet randlos und misst die Systemränder selbst).
- In `MainActivity.kt`: `CardsTableBridge.attach/detach`, Token-Prüfung für `cards`.
- `AndroidManifest`: Eintrag des `CardsAuthorityService` (falls vorhanden).

Flutter (`lib/features/games/lumo_cards/`):

- `lumo_cards_table_session.dart` (Mailbox-Gegenstück) – entfällt ganz.
- Das UNO-artige Flutter-Spiel (`lumo_cards_rules.dart`, `_deck`, `_bot_policy`,
  `_game_controller`, `_models`, `_session`, `_cup*`, `_screen`,
  `_showcase_screen`, `widgets/*`, `learning_question_repository.dart`,
  `lumo_cards_assets.dart`) ist von Heinz gestrichen. Wenn kein anderer Einstieg
  es mehr braucht, kann es mit seinen Tests entfernt werden; Ersatz ist der
  Godot-Tisch. Vor dem Löschen prüfen: Lernkarten-Überlagerung
  (`lumo_learning_card_overlay.dart`) und Turnier-Sterne gibt es im neuen Tisch
  **nicht**.
- Tests, die die alte Mailbox/den UNO-Tisch festschreiben (u. a.
  `test/lumo_cards_*`, `test/design/cards_*`, `test/table_games_launcher_binding_test.dart`
  für den `cardsToken`-Teil, `test/games/connect_four_native_route_test.dart`
  soweit `cards` betroffen): durch Tests für den tokenlosen Start und die
  Annahme von `game: "cards"` ersetzen.

## 4. Was gleich bleibt

- Szene/Route `cards` (`SceneRouter`, `HostBridge.validated_options`).
- Rückkehrziel `games`, Rückkehr-Payload mit `sessionId`.
- Belohnungsweg `reward` → `GameEventStore` → `EmbeddedGameService` → Wallet,
  mit `resultId` als Doppelbuchungsschutz auch auf App-Seite.

## 5. Nicht geprüft

- Kein Lauf auf einem Android-Gerät oder in der App; die obigen Befunde stammen
  aus dem Lesen des App-Codes. Die Punkte 2.1/2.2 sind Code-Befunde, kein
  beobachteter Fehler auf dem Gerät.
