# Himmelsinseln Sprint (Strecke `bergwelt`) – Umsetzung nach Referenz k07

Stand 4. Oktober 2026, Priorität 2 aus Issue #6. Referenzbilder liegen in
`Ullmann27/lumo-lernen` unter `docs/design_targets/2026-10-04/kart/` (k02, k03, k07, k10).
Die Strecken-ID bleibt `bergwelt` (Spielstände, Bestzeiten, Musik), der Name ist jetzt
„Himmelsinseln“. Die anderen drei Welten sind unverändert.

## Aufbau

| Abschnitt (k07) | Streckenanteil | Umsetzung |
|---|---|---|
| Start / Ziel | 0,00 | LUMO-KART-Tor: blaue Pfeiler, goldene Sterne, Karoband, Startampel, „START · ZIEL“ |
| 1 Wasserfälle | 0,13–0,27 | Steinbrücke mit Bögen und Laternen, runde Schwebeinseln mit Wasserfällen links/rechts |
| 2 Schwebestadt | 0,27–0,40 | Insel mit fünf Türmen (blaue Kegeldächer, leuchtende Fenster), Häuserzeile, „LUMO“-Schild, Banner „Kleine Schritte – große Ziele“ |
| 4 Schwebebrücke | 0,58–0,66 | Hängebrücke (Steinpfeiler, goldene Seile) |
| 5 Kristallhöhlen | 0,46–0,58 | Gewölbetunnel in Violett mit leuchtenden Kristallen an Eingängen und Wänden |
| 3 Tempelruinen | 0,66–0,77 | Säulen, Giebel mit Goldstern, Feuerschalen |
| 6 Zieleinlauf | 0,77–1,00 | lange Brücke zurück zum Tor |

Die Reihenfolge der Abschnitte folgt der vorhandenen Streckenführung. Die Kurvenradien sind
unverändert und durch `kart_track_contract.gd` abgesichert. Deshalb liegt die Kristallhöhle
vor der Hängebrücke, anders als die Nummerierung im Bild.

- **Welt:** Nachthimmel-Shader mit Sternen und Mond, Wolkenmeer-Shader, Mondlicht mit
  Schatten, warmes Gegenlicht. Die Straße liegt auf vier Inseln (Grasoberseite, Moos,
  Felskiel); dazwischen Brücken. Neun Hintergrundinseln mit Wasserfällen und Burgtürmen,
  dazu ein Zeppelin „LUMO KART“.
- **Fahrbahn:** dunkler Belag, durchgehende cyanfarbene Lichtkante, Randsteine abwechselnd
  orange/cyan leuchtend. Die Leitplanken sind blau/weiß mit Goldkappen und zugleich die Wand
  (siehe Etappe 2.1). Pfeiltafeln (Chevrons) stehen außen an jeder engeren Kurve und zeigen
  in die Kurve.
- **Gameplay-Elemente (k03, für alle Strecken):** goldene Stern-Token statt Kristallen, die
  Arena behält ihre Kristalle. Turbo-Pads: dunkle Platte, drei Leuchtpfeile, orange
  Seitenleuchten, genau über der Boost-Zone.
- **Bewusst nicht gebaut:** Lern-Boost-Tore und Buch-Token als Lernauslöser (Heinz' Regel:
  keine Lernaufgaben im Kart). Die Abkürzung mit Rampe folgt in Etappe 2.3.

## Prüfen und Belege

```bash
# Abschnittsbilder (1280x720) nach exports/sky-islands/
xvfb-run -a godot --audio-driver Dummy --rendering-method gl_compatibility \
  --script scripts/tests/kart_sky_islands_showcase.gd
# Ganzes Rennen mit Bildserie und lap.json nach exports/lap/bergwelt/
xvfb-run -a godot --audio-driver Dummy --rendering-method gl_compatibility \
  --script scripts/tests/kart_lap_capture.gd -- --track=bergwelt --every=10 --substeps=3
```

Belegbilder dieser Etappe: `docs/proof/2026-10-04-himmelsinseln/`. Alle Bilder sind
Software-Renderings (xvfb + gl_compatibility) und keine Gerätemessung. Die FPS auf Android
bzw. Fold7 sind nicht gemessen.
