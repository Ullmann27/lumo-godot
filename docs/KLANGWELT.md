# Klangwelt – Musik, Atmosphäre und Bedientöne

Stand 18. November 2026. Alle Klänge sind für Lumo selbst komponiert und mit numpy
synthetisiert (`tools/art/generate_klangwelt_audio.py` + `tools/art/klangwelt_synth.py`,
fester Seed, reproduzierbar). Keine Aufnahmen, keine fremden Samples, Loops oder Melodien.
**Nichts davon wurde abgehört.** Geprüft wurde nur messbar, siehe
[KLANGWELT_MESSWERTE.md](KLANGWELT_MESSWERTE.md).

Neu erzeugen: `/home/user/tools/bpyenv/bin/python tools/art/generate_klangwelt_audio.py`
(etwa 10 Minuten; `--only hub cards` für einzelne Stücke, `--measure` nur messen). Danach in
Godot neu importieren.

## Dateien (`assets/audio/klangwelt/`)

| Ordner | Inhalt | Format |
|---|---|---|
| `music/` | 12 Stücke + 2 synchrone Schichten, 40–80 s je Schleife | OGG Vorbis, 32 kHz, schmales Stereo, ~80–98 kbit/s, −16 LUFS |
| `ambience/` | 7 Atmosphären, 30–60 s je Schleife | OGG Vorbis, 32 kHz, mono, ~52 kbit/s, −27 LUFS |
| `sfx/` | 37 Töne in 93 Varianten (`<name>_<n>.ogg`) | OGG Vorbis, 32 kHz, mono |
| `manifest.json` | Generator, Seed, Tonart/Tempo, Messwerte je Datei | – |

Zusammen 12,3 MB, die größte Datei ist 0,95 MB. Der Android-Export (`export_filter="all_resources"`)
nimmt die importierten OGG-Dateien automatisch mit; zur Laufzeit wird kein JSON gelesen.

### Das Lumo-Motiv

Stufen so–do'–ti–so · la–so–mi (ein 4/4-Takt). Es ist der Kopf des Home-Themas und kommt in
jedem anderen Stück einmal in dessen Tonart und Takt vor (Spielewelt im B-Teil, Kartentisch
gleich im ersten Takt, Memory in Takt 11, Vier gewinnt in Takt 3, Quiz in Takt 5, Schatzsuche in
Takt 3, Puzzle als Walzer im zweiten A-Teil, Bauwelt Takt 5, Dorf Takt 5 im 6/8-Takt, Abend und
Lernwerkstatt Takt 5). `lumo_jingle` ist das Motiv als kurzer Ton (6 s).

### Stücke je Route

| Route(n) | Musik | Atmosphäre | Schichten |
|---|---|---|---|
| boot, intro, home | `lumo_theme` (F-Dur, 96 BPM) | – | – |
| parent | `lumo_theme` (6 dB leiser) | – | – |
| games, jump, stars | `hub` (C-Dur, 112 BPM) | `playroom` (leiser) | – |
| cards | `cards` (B-Dur Swing, 100 BPM) | `playroom` | – |
| memory | `memory` (G-Dur, 76 BPM) | `playroom` | – |
| connect_four | `connect_four` (D-Dur, 116 BPM) | `playroom` | – |
| quiz | `quiz` (Es-Dur, 120 BPM) | `studio` | `tension` = `quiz_tension` |
| treasure | `treasure` (D-Dorisch, 96 BPM) | `island` | `discovery` = `treasure_discovery`; Atmosphären-Schicht `waterfall` |
| rhythm | – (das Spiel hat eigene Musik) | `stage` | – |
| puzzle | `puzzle` (E-Dur, 3/4, 84 BPM) | `playroom` (leiser) | – |
| build | `build` (G-Dur, 108 BPM) | – | – |
| settlement | `settlement_day` (D-Dur, 6/8) / abends `settlement_evening` (72 BPM) | `village_day` / `village_evening` | Variante nach Uhrzeit (18–6 Uhr Abend) oder `set_variant()` |
| learning, tutor, learn, reading_hub, alphabet, word_*, sound_letter_match, learn_old | `learning` (F-Dur, 88 BPM, 4 dB leiser, bis 6,5 kHz gefiltert) | – | – |
| kart, run | **nichts** – eigene Musik; das System blendet nur seine eigene Musik aus | – | – |
| loading, unbekannte Routen | laufende Musik bleibt | | |

## Wie das System die Szene erkennt

`GameSoundscape` (Autoload nach `AudioManager`) hört auf `EventBus.scene_changed(from, to)`,
das `SceneRouter.goto()` und `SceneRouter.goto_loaded()` senden (auch der direkte Start aus der
Flutter-App über `app_boot.gd`). Zusätzlich hört es auf `SceneTree.scene_changed` und sucht den
Pfad der aktuellen Szene in `SceneRouter.SCENES` – so passt die Musik auch, wenn eine Szene ohne
Router gewechselt wird.

## Pegel und Verhalten

- Musik spielt bei −12 dB (Datei −16 LUFS → etwa −28 LUFS, wie die Kart-Musik), Atmosphäre bei
  −6 dB (≈ −33 LUFS), Töne bei −4 dB mit Spitzen bei −3 dBFS (Klicks −9 dBFS). Sprache bleibt
  damit deutlich vorne.
- Überblenden 1,6 s; gleiche Musik in Folgerouten (Intro → Home) läuft weiter statt neu zu starten.
- Ducking: während `AudioManager.play_voice()`, während eine Lern-Szene spricht
  (`_speech_state` = preparing/playing) oder nach `duck()`/`duck_for()` sinkt die Musik um etwa
  10 dB, die Atmosphäre um etwa 4 dB.
- Pausenmenü (`paused == true` oder `_state.paused`) senkt die Musik um 6 dB.
- Hintergrund: `NOTIFICATION_APPLICATION_PAUSED` (und auf Mobilgeräten Fokusverlust) pausiert alle
  Spieler, die Rückkehr setzt sie an derselben Stelle fort.
- Stumm: `AudioManager.is_muted()`, stummer Master-Bus (Elternbereich) oder Startoption
  `soundEnabled=false` → alle Spieler auf −80 dB und pausiert (kein Dekodieren).
- Lautstärke: Musik- und Effektregler aus `user://kart_preferences.cfg` (dieselben Regler wie
  Lumo Kart und Lumo Lauf), multipliziert mit eigenen Reglern `set_music_volume()` /
  `set_ambience_volume()` (`user://lumo_soundscape.cfg`).
- Weiche Klicks: Jeder Knopf (`BaseButton`) ohne eigenen Ton bekommt beim Drücken `ui_click`.
  Hat das Spiel im selben Frame selbst `play_sfx` aufgerufen, entfällt der Klick (kein
  Doppelklang). Nicht in Kart und Lumo Lauf. Abschaltbar: `GameSoundscape.auto_ui_clicks = false`.

### Automatische Ereignisse (ohne Eingriff in die Spiele)

Das System liest alle 0,1 s öffentliche Zustände der laufenden Szene. Fehlt eine Eigenschaft
(Spiel umgebaut), passiert einfach nichts.

| Route | beobachtet | Reaktion |
|---|---|---|
| rhythm | `model.last_cheer` steigt (Serien-Bonus) | `stinger("applause")` |
| treasure | `model.found` wächst | `stinger("treasure_found")` + Entdeckungsschicht 20 s |
| treasure | `model.discoveries` wächst | Entdeckungsschicht 12 s |
| quiz | `_state.canSelect` und nicht `revealed`/`paused`/`gameOver` | Spannungsschicht an |
| quiz | `_state.revealed` wird wahr | `answer_correct` bzw. freundliches `answer_wrong` |
| memory | `_state.complete` wird wahr | `stinger("celebrate")` |
| connect_four | `_discs` wird größer | `piece_drop` |

Sobald ein Spiel selbst Aufrufe einbaut: `GameSoundscape.set_auto_events("<route>", false)` in
dessen `_ready()`, sonst klingt es doppelt. Global: `GameSoundscape.auto_events = false`.

## Öffentliche Feinsteuerung

```gdscript
GameSoundscape.set_layer("tension", true)        # Quiz: Spannungsschicht (synchron)
GameSoundscape.set_layer("discovery", true)      # Schatzsuche: Entdeckungsschicht (synchron)
GameSoundscape.pulse_layer("discovery", 15.0)    # für 15 s, danach von selbst aus
GameSoundscape.set_layer_level("waterfall", 0.0..1.0)  # Wasserfall-Atmosphäre nach Nähe
GameSoundscape.stinger("treasure_found")         # Ereignis-Ton, Musik weicht kurz zurück
GameSoundscape.set_variant("evening")            # Dorf: Abend; "day"; "" = nach Uhrzeit
GameSoundscape.duck(true) / duck_for(3.0)         # z. B. während eigener Sprachausgabe
GameSoundscape.set_music_volume(0.8) / set_ambience_volume(0.5)
GameSoundscape.debug_state()                      # Zustand für Tests
AudioManager.play_sfx("piece_drop")               # echte Samples, mehrere Varianten
AudioManager.has_sample(name) / sample_paths(name) / set_sfx_volume(linear)
```

### Töne (`AudioManager.play_sfx`)

Vorhandene Namen (bekommen jetzt echte Klänge): `ui_confirm`, `ui_cancel`, `ui_back` (`back`),
`portal_tap`, `card_next`, `star_collected`, `celebrate`, `card_deal`, `card_play`, `card_draw`,
`card_select`, `card_refuse`, `card_pass`, `trick_win`, `quartet`, `round_win`, `turn_ping`.

Neu und bereit für Aufrufe: `ui_click`, `card_shuffle`, `card_flip`, `piece_drop`, `pair_found`,
`pair_miss`, `answer_correct`, `answer_wrong` (freundlich, nie strafend), `coin`, `count_tick`,
`build_place`, `build_remove`, `level_up`, `treasure_found`, `puzzle_snap`, `dig`, `applause`,
`crowd_ooh`, `lumo_jingle`, `whoosh`.

## Empfohlene Aufrufstellen (nicht eingebaut – Spieldateien gehören anderen Helfern)

| Datei | Stelle | Aufruf |
|---|---|---|
| `scripts/games/connect_four/connect_four_table.gd` | `_drop_finished()` (Stein landet) | `AudioManager.play_sfx("piece_drop")`, dann `set_auto_events("connect_four", false)` |
| `scripts/games/connect_four/connect_four_table.gd` | `_update_win()` bei Sieg | `GameSoundscape.stinger("celebrate")` |
| `scripts/games/memory/memory_table.gd` | `_flip_finished()` | `play_sfx("card_flip")`; Paar → `pair_found`, kein Paar → `pair_miss` |
| `scripts/games/memory/memory_table.gd` | Runde komplett | `GameSoundscape.stinger("celebrate")` |
| `scripts/games/quiz/quiz_studio.gd` | Frage erscheint / Antwort gewählt / Auflösung | `set_layer("tension", true/false)`, `play_sfx("answer_correct"/"answer_wrong")`, Publikum `play_sfx("crowd_ooh")` beim Joker |
| `scripts/games/cards/cards_table.gd` | `_start_match()` vor dem Austeilen | `play_sfx("card_shuffle")`; Umdrehen → `card_flip` |
| `scripts/creative/treasure_world.gd` | Graben/Suchen, Fund, `_win()` | `play_sfx("dig")`, `stinger("treasure_found")`, `pulse_layer("discovery", 20)`; Nähe zum Wasserfall → `set_layer_level("waterfall", nähe)` |
| `scripts/creative/puzzle_world.gd` | `_play_snap_fx()` / `_win()` | `play_sfx("puzzle_snap")` / `stinger("celebrate")` |
| `scripts/creative/build_world.gd` | `_place_feedback()` (ersetzt `_place_tone()`), Abreißen | `play_sfx("build_place")` / `play_sfx("build_remove")` |
| `scripts/creative/build_settlement_world.gd` | Bauen, `_demolish()`, Stufenaufstieg, Tagwechsel | `build_place`, `build_remove`, `stinger("level_up")`, `set_variant("evening")` am Abend |
| `scripts/creative/rhythm_world.gd` | `_finish()` | `stinger("applause")` |
| `scripts/games/game_hub.gd` | Portal/Spiel gewählt | `play_sfx("portal_tap")` |
| Belohnungs-/Ergebnisanzeigen | Sterne/Münzen hochzählen | je Schritt `play_sfx("count_tick")`, am Ende `play_sfx("coin")` |
| `scripts/learning/**` | eigene Sprachausgabe über den Host | wird über `_speech_state` schon erkannt; sonst `duck_for(sekunden)` |

## Prüfung

- `scripts/tests/game_soundscape_regression.gd` (headless, `--audio-driver Dummy`).
- `tools/tests/test_klangwelt_audio.py`: Größenbudget, Schleifen, Lautheit, Schichtlängen,
  Abgleich Manifest ↔ `AudioManager.SFX_SAMPLES`.
