# Lumo Kart – Action-Parcours (9. Oktober 2026)

Heinz' Auftrag: Strecken „mit Action laden“ – Rampen, Slalom, Sprungschanzen, Tauchen, von der
Strecke fallen können – und Runden so lang wie bei Mario Kart.

## Recherche (öffentliche Quellen, keine Nintendo-Inhalte übernommen)

- Mario Kart 8 Deluxe: Staff-Ghost-Runden 34–48 s, Weltrekorde 28–39 s je Runde; Rennen mit drei
  Runden etwa 2–2,5 min. Kurslängen sind offiziell nur für Mario Kart 64 bekannt (527–2000 m,
  meist 700–1036 m). Quellen: mariowiki.com (Kursseiten), mkleaderboards.com.
- Pro Runde etwa 6–10 Set-Pieces (alle 4–7 s eins): Rampen mit Gleiten, Boostspuren,
  Unterwasserabschnitte, Hindernisse. Wer abstürzt, wird zurückgesetzt und verliert einige Sekunden.
- Need for Speed Underground 2: Teile in Kategorien (Motor, Turbo, Reifen, Bremsen, Fahrwerk …),
  Stufen Street/Pro/Extreme; Optik getrennt von den Werten.

## Rundenlängen in Lumo Kart (gemessen, `world.length`)

| Welt | Länge | Bemerkung |
|---|---|---|
| Sonnenhafen | 545 m | echte Testfahrt: beste Runde 41,2 s |
| Zauberwald | 377 m | kürzeste Runde – neue Streckenführung nötig |
| Himmelsinseln | 473 m | |
| Holo-City | 443 m | |
| Kristall-Canyon, Dschungeltempel, Candy Cloud, Vulkan, Winter-Sprint, Galaxie-Ring, Wüste, Lernlabor | 690–803 m | Mario-Kart-Länge |

Die vier Grundstrecken liegen schon nahe am Inselrand; sie lassen sich nicht einfach strecken.
Längere Führungen (zusätzliche Kehren) sind der nächste Schritt (OFFEN).

## Elemente (`scripts/games/kart_action_course.gd`)

| Element | Wirkung | Darstellung |
|---|---|---|
| Turbo-Feld (2 je Runde) | 1 s Turbo, je Feld einmal pro Runde | türkise Leuchtfläche mit gelben Pfeilen |
| Slalom (4 Tore, 16 m Abstand) | alle Tore → 1,3 s Turbo; Hütchen bremst um 14 % | große orange-weiße Hütchen, grünes Leuchtband in der Gasse |
| Sprungschanze (7 m, 1,1 m hoch) | abheben, Flug, Landung mit Turbo | gelb-dunkel gestreifte Schanze mit Leuchtkante |
| Unterwasser-Tunnel (Zauberwald, Dschungel, Winter, Wüste) | Höchsttempo 90 %, leicht blaues Bild | Wasserwände und -decke, Glasrippen, Fische, Luftblasen |
| Offene Kante (Kristall-Canyon, Candy Cloud, Vulkan, Galaxie) | keine Wand außen in der Kurve; Sturz → Lumo-Wolke setzt nach ≤ 2 s mittig mit 6 m/s und 2 s Schutz zurück | gelb-schwarze Warnstreifen, rote Kante, Hütchen, Warnschild |

Alle Elemente meiden Start/Ziel (35 m/30 m), Sprunglücke und Looping (Abstand 14 m) und
überlappen nicht. **Sonnenhafen bleibt vorerst unverändert**: Er ist die Referenz- und Prüfstrecke
des vollständigen Android-Rennablaufs (Ergebnis, ACK, Belohnung).

## Prüfung

- `kart_action_course_regression.gd`: Planung auf 11 Strecken ohne Überlagerung; echte Fahrt über
  Turbo-Feld, Slalom (alle Tore) und Hütchen, Schanze mit Flug über Schanzenhöhe und Landung,
  Unterwasser-Tempo und -Färbung, offene Kante mit Sturz und Rettung, Wand auf der geschlossenen Seite.
- `kart_action_capture.gd`: Verfolgerkamera-Bilder der fünf Elemente (Proof unter
  `docs/proof/2026-10-09-action/`).
- Gerät, Bildrate und Spielgefühl auf dem Fold: NOT EXECUTED.

## Offen

- Längere Führungen für Zauberwald, Holo-City und Himmelsinseln.
- Sonnenhafen mit Parcours, sobald der Android-Rennablauf dafür neu abgenommen ist.
- Gleiter nach großen Schanzen, Trick-Sprünge, weitere Unterwasser-Physik (Auftrieb).
