# Übergabe von Claude an ChatGPT Sol 6.1 · Godot-Seite · 9. Oktober 2026

Die vollständige Übergabe (Stände, Nachweise, Offenes, Arbeitsweise) steht in der App:
`docs/handoffs/CLAUDE_TO_SOL_2026-10-09.md` im Repository `Ullmann27/lumo-lernen`, Branch
`claude/continue-previous-chat-KtY7p`. Hier nur das Godot-Spezifische.

## Stand

Branch `claude/continue-previous-chat-KtY7p`. Basis: Codex-Recovery `4b63ec2` (PR 29/31).
Darauf: 14 Karts mit Werten (`kart_fleet.gd`), Tuning-Werkstatt mit Prüfstand (`kart_tuning.gd`,
`kart_workshop.gd`), Kart-Karten und Wertebalken in der Garage, Baukasten-Karts mit gemeinsamem
Cockpit (`kart_vehicle.gd`), Item-Abzeichen im Item-Knopf (`kart_touch_action.gd`),
Himmels-Wiederverwendung gegen Textur-Lecks (`kart_world.gd`, `kart_sky_islands.gd`),
Action-Parcours (`kart_action_course.gd`, Fahrphysik in `kart_island.gd`).

## Geprüft (lokal, strenger Runner, jede `ERROR:`-Zeile zählt)

Alle Regressionsproben bestehen mit ihrer PASS-Zeile; `kart_vehicle_regression` meldet
`[KartVehicle] Geometry/colours, shadows, animations, effects, LOD and hysteresis passed` und hat keine
„PASS“-Zeile (die CI nutzt diesen Marker). Gesamtablauf mit ACK sechsmal hintereinander grün.
Neue Proben: `kart_fleet_stats_regression`, `kart_workshop_regression`,
`kart_action_course_regression`. Aufnahmen: `scripts/tests/kart_action_capture.gd` →
`docs/proof/2026-10-09-action/` (fünf Parcours-Bilder, ein Werkstatt-Bild).

## Offen

Referenzgleichheit von Lumo und Kart (VISUAL_GAP), längere Führungen für Zauberwald, Holo-City und
Himmelsinseln, Sonnenhafen mit Parcours (erst nach neuer Abnahme des Android-Rennablaufs),
sporadischer ACK-Save-Fehler (nicht reproduziert, nicht als behoben beansprucht), Gerät/Fold/FPS
NOT EXECUTED. Details: siehe die Übergabe in der App.
