# Lumo-Gesicht und Anzug – Zwischenstand (9. Oktober 2026)

**Status: ZWISCHENSTAND, NICHT ABGENOMMEN (VISUAL_GAP).** Diese Änderung ist **nicht** im Spiel und
nicht in APK 1913/1914. Sie liegt als Patch vor, damit die Arbeit nicht verloren geht und ein
Nachfolger sie prüfen, verbessern und erst danach einbauen kann.

## Inhalt

- `lumo_gesicht_wip.patch` – Änderungen an `scripts/games/kart_vehicle.gd`,
  `kart_character_finish.gd`, `kart_stage.gd` und das neue Aufnahmeskript
  `scripts/tests/kart_lumo_views_capture.gd`. Passt auf Godot `de91cc9`
  (`git apply --check` geprüft):
  `git apply docs/wip/2026-10-09-lumo-gesicht/lumo_gesicht_wip.patch`
- `vorher_nachher_engine.png` – links der Stand `de91cc9`, rechts der Zwischenstand. Echte
  Engine-Renderings (Godot 4.6.3, `gl_compatibility`), nur zusammengestellt und verkleinert, nicht
  bearbeitet. Zeilen: Gesicht von vorn, von der Seite, Kopf dreiviertel, Ganzkörper, im Kart von
  vorn, Kart von hinten.

## Was der Patch ändert

- **Kopf:** neues Profil (oben schmaler, an den Wangen am breitesten), weiße Gesichtsmaske in das
  Kopfnetz eingefärbt statt aufgesetzter Wangenkissen, drei Wangenbüschel je Seite.
- **Augen:** Augapfel kleiner und runder, dunkler Lidrand, Iris und Pupille als Kappe, die genau
  auf dem Augapfel liegt (nichts steht mehr seitlich ab), zwei Glanzpunkte (`iris_cap` in
  `kart_character_finish.gd`).
- **Schnauze, Nase, Mund:** längere Schnauze mit orangem Nasenrücken, kleinere glänzende Nase,
  Lächeln auf der Schnauzenoberfläche.
- **Ohren:** dunkle Spitzen und Ränder, steiler gestellt.
- **Brille:** Chromringe, dunkler Rahmen, Band liegt auf der Kopfform, Steg zwischen den Gläsern.
- **Anzug (stehende Figur):** weiße Seitenteile mit orangem Vorstoß, Gürtel mit Schnalle,
  Schulterpolster, Knieschoner, Stiefel mit weißer Sohle und orangem Rand, Handschuhe.
- **Garage/Werkstatt:** Hauptlicht kommt jetzt von vorn (vorher von hinten, das Gesicht lag im
  blauen Umgebungslicht).
- **Messpunkte:** `face_metrics` am Kopf (reine Daten) für die Proportionsmessung.

## Messwerte am gerenderten Kopf (Frontansicht, lange Brennweite)

| Maß | `de91cc9` | Zwischenstand |
|---|---|---|
| Augenbreite / Kopfbreite | 0,319 | 0,239 |
| Iris / Auge | 0,884 | 0,663 |
| Pupille / Iris | 0,667 | 0,556 |
| Augenabstand (Mitte–Mitte) / Kopfbreite | 0,464 | 0,444 |
| Nasenbreite / Kopfbreite | 0,223 | 0,156 |

Die Referenzwerte aus den Blättern `docs/design_targets/2026-10-08-kart-fahrzeuge/03_…` und `06_…`
sind **noch nicht belastbar ausgemessen**. Ein „nah an der Vorlage“ ist deshalb nicht belegt.

## Geprüft

Im Arbeitsbaum bestanden: `kart_vehicle_regression`, `kart_vehicle_detail_regression`,
`kart_arm_contact_regression`, `kart_steering_grip_regression`, `kart_fleet_regression`,
`kart_workshop_regression`, `kart_menu_flow_regression`, `creative_scene_smoke`.
**Nicht gelaufen:** `creative_adventure_capture` (die Schatzsuche nutzt den Begleiter-Fuchs mit den
neuen Gliedmaßen; Ordner `exports/creative-build` musste angelegt werden), `holographic_companion_export`,
`kart_driven_capture`, Gerät/Bildrate.

## Offen (nächste Schritte)

1. Referenzmaße aus den Blättern 03/06 ausmessen und die Tabelle oben gegen sie vergleichen.
2. Augen: in der Dreiviertelansicht wirken sie flach; Lider (oben kräftiger), Wimpern/Brauenansatz,
   Blickrichtung. Fell und Anzugstoff als eigene Materialien (Nachweis per Detailaufnahme).
3. Handschuhe, Schulterpolster, Brust-L (leuchtend), Rückseite und Schwanzansatz.
4. Ansicht 8 (Verfolgerkamera) und „im Kart von hinten“ mit der neuen Figur neu aufnehmen.
5. COMET-Premiumkart (Lack, Lichtkanten, Reifenprofil, Felgen, Fahrwerk, Heck) – noch nicht begonnen.
6. Danach Patch einbauen, alle Regressionen und die langen Aufnahmen laufen lassen, APK bauen.

## Aufnahme erneut erzeugen

```
godot --path . --rendering-method gl_compatibility \
  --script res://scripts/tests/kart_lumo_views_capture.gd -- <ausgabeordner>
```

Schreibt acht Ansichten (Gesicht vorn/seitlich, Kopf dreiviertel, Ganzkörper, im Kart vorn,
Kart seitlich, Kart hinten, Verfolgerfahrt) und `face-metrics.json`. Läuft unter `xvfb-run`.
