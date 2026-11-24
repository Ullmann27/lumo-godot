# Lumo Kart – Gameplay, Items, Effekte (17.11.2026)

Branch `lumo-kart/gameplay-items-20261117`. Alles eigenständig (keine fremden Namen, Assets oder Items).

## Items (datengetrieben: `assets/kart/items/kart_items.json`)
| id | Name | Verhalten | Rolle |
|---|---|---|---|
| boost | Rückenwind | 3 s Turbo | Tempo |
| triple_boost | Kometen-Trio | 3 Ladungen à 1,6 s | Aufholen (Platz 3–6) |
| shield | Sternenschild | 6 s Schutz | Verteidigung |
| pulse | Lichtimpuls | Rivalen im Umkreis 13 m langsamer | Fläche |
| star_rocket | Sternrakete | zielsuchend zum nächsten Kart vorne, Treffer = Dreher | Angriff (nie auf Platz 1) |
| spark_ball | Funkenkugel | gerade, prallt von Banden ab | Angriff |
| bubble_trap | Blubberblase | hinten abgelegt, fängt auch Raketen ab | Verteidigung |
| star_magnet | Sternmagnet | 4 s Sterne-Sog (6 m), doppelte Windschatten-Ladung | Aufholen |
| aurora | Nordlicht-Lauf | 4,5 s Schutz + Tempo, Berührung dreht Rivalen | Aufholen (Platz 4–6) |

Neues Item = neue JSON-Zeile (Gewichte je Platz 1–6), ggf. neues `behaviour` in `kart_item_runtime.gd`.
Treffer sind kindgerecht: das Kart dreht sich zweimal und fährt weiter (Tempo kurz ×0,3).

## Mechaniken (`scripts/games/kart_items/kart_race_rules.gd`)
- Drift-Turbo in drei Stufen: Blau 0,8 s, Orange 1,8 s, Lila 2,7 s.
- Windschatten: 1,6–10 m hinter einem Kart, ±1,5 m seitlich, ab 10 m/s → nach 1,1 s Schub 1,3 s.
- Luft-Trick: DRIFT in der Luft tippen → Rolle; Landung gibt Trick-Turbo 1,7 s.
- Turbo-Kette: Boost-Quellen innerhalb 2,6 s steigern die Combo (+0,25 s je Stufe, max ×6).
- Aufholhilfe: Spieler weit hinten bis +10 % (gemütlich) / +7 % / +4 % Topspeed; Rivalen weit vorne bremsen bis −12 %, weit hinten schieben bis +10 %. Item-Glück verschiebt sich bei großem Rückstand bis zu zwei Plätze nach hinten.
- Rivalen-KI nutzt alle Items (Rakete auf Vordermann, Blase gegen Verfolger, Schild bei anfliegender Rakete) und jubelt kurz nach einem Treffer.

## Wiederverwendbare Szenen für den Strecken-Bot
Alle hängen sich in die Gruppe `lumo_kart_triggers`; das Rennen findet sie unter `ActiveRace` automatisch.
- `scenes/games/props/kart_item_box.tscn` (`LumoKartItemBox`): `pickup_radius`, `respawn_seconds`, `spin_speed`. Ursprung 0,85 m über der Fahrbahn.
- `scenes/games/props/kart_boost_ring.tscn` (`LumoKartBoostRing`): `ring_radius`, `boost_seconds`, `ring_color`. Ursprung auf der Fahrbahn, Durchfahrt entlang lokal −Z.
- `scenes/games/props/kart_boost_pad.tscn` (`LumoKartBoostPad`): `pad_size`, `boost_seconds`. Ursprung auf der Fahrbahn, Pfeile zeigen nach −Z.

Effekte (`kart_fx_director.gd`): Partikel-Pool (CPU, 6 Emitter, Menge nach Grafikprofil), Bildschirmblitz, FOV-Schub, Wackler; alles reduziert bei „weniger Bewegung“. Sound-Hooks über Signal `sound_hook(event_id, fallback)`; derzeit werden die vorhandenen Effektklänge genutzt.

## Fahrer und Lenkrad
- Rivalen (Otter, Hase, Dachs, Katze): kleinere, eingesetzte Augen mit artgerechter Irisfarbe, kürzere Schnauze, artgerechte kleine Nasen, eigene Schwänze (Otter, Dachs, Katze). Lumo unverändert.
- Lenksäule läuft jetzt entlang der Lenkradachse nach vorn in einen Armaturen-Pod (vorher aus dem Sitz zwischen den Stiefeln).
- Animation Rivalen: Kurvenneigung, Boost-/Bremshaltung, Treffer-Reaktion (Ruck, Kopfschütteln, Augen zukneifen, Ohren), kurzer Jubel mit Arm.

Tests: `scripts/tests/kart_gameplay_items_regression.gd` (128 Prüfungen), Review-Bild: `scripts/tests/kart_driver_fit_capture.gd`.
