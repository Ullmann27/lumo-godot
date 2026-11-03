# Sonnenhafen Präzisionssprung · 3. November 2026 (Grok-Zyklus 1)

Basis: Forschungszweig `design/sonnenhafen-precision-flight-road-20261103`
(HEAD `ec61db3c6ae8715f745427a6231d014794c73c35`). Lokaler Zweig
`grok/sonnenhafen-jump-cycle1`. Kein Push, kein PR, keine Änderung an `main`,
kein Release. Build 2004 bleibt unberührt.

## Ausgangsbefund im Forschungszweig (real gemessen, Godot 4.6.3)

- `kart_sonnenhafen_stunt_regression` **FAIL** bei „Real flight“: Der neue
  Präzisions-Kicker hatte kein `max_lift`, daher deckelte `kart_island` den
  Absprung auf `JUMP_MAX_LIFT = 4 m/s`. Das Modell in `kart_precision_jump.gd`
  rechnete zudem horizontal mit `v·cos(α)`, das Spiel fliegt mit `v`.
- Landezone 20–31 m hinter der Kante: Bei Abenteuer-Höchsttempo (20,5 m/s)
  wäre jedes Kind in die Lücke gefallen.
- `_rescue_from_gap` las `world.jump.gap_end`; `jump` ist auf Sonnenhafen leer
  → Laufzeitfehler bei jedem zu kurzen Sprung.
- Langsames Abrollen über die Kante (≤ 6 m/s, kein Absprung) fuhr über der
  Lücke auf Luft; Rivalen fuhren ebenfalls auf Fahrbahnhöhe über die Lücke.

## Umsetzung

- `kart_precision_jump.gd`: Modell exakt wie der Absprung im Spiel
  (horizontal `v`, vertikal `v·sin α + lift_bonus`, Deckel `max_lift`,
  Starthöhe = Rampenhöhe, ansteigende Landefahrbahn `landing_slope`).
- Rampe 12 m / 3,0 m (14°), kein Lift-Bonus, kein Deckel; offene Lücke
  0,5–14,5 m, Landezone 14,5–31 m. Jedes Kart bei Höchsttempo ohne Turbo
  landet auf jeder Stufe in der Zone; Turbo an der Kante → zu weit.
- Zu kurz: Fall in die Lücke oder Aufprall an der Gegenkante unter
  Fahrbahnniveau, nie hochgehoben; Wolke setzt hinter der Lücke ab.
  Zu weit: harte Landung (Tempo ×0,6, kein Turbo). Zone: Turbo.
- Geschwindigkeitshinweis 70 m vor der Rampe: rot „Gib Gas!“, grün
  „Tempo passt!“, orange „Etwas bremsen!“ mit Zeiger auf der echten Zone.
- Neon-Stuntrampe im Stil des Loopings, Widerlager an der Lücke,
  markierte Landezone, Schild „STUNT-SPRUNG“.

## Prüfungen

Siehe `REPORT.md` im Artefaktordner dieses Zyklus. Nicht gemessen: Fold7-FPS
auf dem Gerät, Android-APK, Flutter-Einbettung.
