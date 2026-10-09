# Lumo Kart – Fahrzeugflotte, Werkstatt und Rennanzeige (8. Oktober 2026)

Stand: zusammengeführt mit Codex PR 27/28 (Referenzkarosserie, Lumo mit Fell, Kontakte,
Rennspeicherung, Glasknöpfe). Lokal mit Engine-Tests geprüft. Nicht auf einem echten Gerät
ausgeführt (NOT EXECUTED: Android-Gerät, Touch-Gefühl, Bildrate).

Referenzen von Heinz: `docs/design_targets/2026-10-08-kart-fahrzeuge/` (7 Bilder + README).

## Die Flotte (`scripts/games/kart_fleet.gd`)

Vierzehn eigene Karts, alle in der Engine aus Formen gebaut (keine fremden Modelle, keine fremden
Namen). Fünf Werte von 0 bis 10; Comet steht mit 6/6/6/6/6 genau in der Mitte, alle Fahrfaktoren
sind dort 1,0. Freigeschaltet wird mit **Fortschrittssternen** (verdient, nie bezahlt).
Karosserie „Loft“ = geloftete Aurora-Karosserie (Codex, PR 27/28, mit Profil je Design);
„Baukasten“ = Plattenbaukasten (Claude).

| Kart | Rolle | Tempo | Beschl. | Bremsen | Handling | Turbo | ab ★ | Karosserie |
|---|---|---|---|---|---|---|---|---|
| Comet | Allrounder | 6 | 6 | 6 | 6 | 6 | 0 | Loft |
| Gecko Velo | Flink | 7 | 7 | 5 | 8 | 5 | 0 | Loft-Profil |
| Boru Rally | Rallye | 5 | 9 | 7 | 6 | 6 | 4 | Loft-Profil |
| Glider | Wendig | 5 | 7 | 6 | 9 | 5 | 8 | Loft |
| Nala Comet | Sportlich | 8 | 7 | 5 | 7 | 6 | 10 | Loft-Profil |
| Noa Tide | Komfort | 6 | 8 | 6 | 9 | 5 | 12 | Loft-Profil |
| Iva Aurora | Aero | 9 | 5 | 5 | 7 | 7 | 16 | Loft-Profil |
| Aurora GT | Highspeed | 9 | 5 | 5 | 5 | 8 | 18 | Loft |
| Zuri Volt | Elektro | 7 | 8 | 6 | 5 | 8 | 20 | Loft-Profil |
| Blitz | Dragster | 6 | 9 | 5 | 6 | 8 | 32 | Baukasten |
| Terra | Gelände | 6 | 6 | 8 | 8 | 6 | 48 | Baukasten |
| Koloss | Schwergewicht | 7 | 4 | 10 | 5 | 8 | 66 | Baukasten |
| Phantom | Drift-Profi | 8 | 7 | 6 | 8 | 7 | 88 | Baukasten |
| Stella | Champion | 9 | 8 | 7 | 8 | 9 | 120 | Baukasten |

Die Werte der sechs Profil-Designs sind aus ihren bisherigen Fahrfaktoren (Codex) abgeleitet und
auf ganze Zahlen gerundet; jedes Design hat eine echte Stärke und eine Schwäche.

Die Werte wirken wirklich in der Fahrphysik (Höchsttempo, Beschleunigung, Bremsweg, Lenkung,
Boost-Stärke, Gelände-Tempo, Stabilität bei Treffern) – siehe `multipliers()` und
`scripts/tests/kart_fleet_regression.gd`.

## Tuning-Werkstatt (`scripts/games/kart_tuning.gd`, `kart_workshop.gd`)

- **Budget** = Summe aller je verdienten Fortschrittssterne (die App meldet sie beim Start,
  `lifetimeStars`). Die Sterne für die Belohnungen der App (Sticker, Spielzeit …) bleiben
  unberührt: Tuning nimmt dem Kind nichts weg. „Ausgegeben“ wird immer aus den Stufen neu
  gerechnet.
- **Teile** (Stufe 0–5, Preis je Stufe 4/8/12/18/26 ★): Motor (Tempo + Beschleunigung),
  Bremsen (+0,5 je Stufe), Reifen (Handling), Turbo. Kein Wert steigt über 12.
- **Aussehen**: Lack (9), Felgen (5), Neon-Leuchten (6). Erst ansehen (Vorschau sofort), dann
  kaufen, dann wählen. Gekauftes Aussehen bleibt auch nach „Alles zurück“.
- **Alles zurück** gibt die Sterne aller Teile zurück (zwei Tipps: erst fragen, dann ausführen).
- **Spielstand** pro Kind in `user://kart_workshop_<kind>.cfg`; beim Profil-Zurücksetzen der
  App wird die Datei gelöscht (`tools/auto_install/MainActivity.kt` in lumo-lernen).

## Garage

Schritt 3 „Kart“ zeigt alle vierzehn Karts als Karten (Vorschaubild, Name, Rolle, fünf Balken,
Tuning-Stufe; gesperrte gedimmt mit „noch N ★“). Darunter die 3D-Vorschau mit Fahrer und die
Wertebalken (Tuning-Anteil in Gold) sowie die Prüfansichten Vorne, Links, Hinten, Rechts und Oben (Codex). Der Knopf „Werkstatt · ★ N“ öffnet die Werkstatt als
Vollbild-Ebene; Zurück schließt zuerst die Werkstatt. Layouts geprüft auf 1280×720, 800×480,
640×320, 412×915 und 690×829.

## Wie die Karts gebaut werden (`scripts/games/kart_vehicle.gd`)

`_build()` wählt nach `look.body`: „loft“ → `_build_loft()` (Codex-Karosserie aus Loft-Ringen,
Cockpit, Heck mit Diffusor und Auspuff, Profil-Anbauteile aus `FLEET.decorate`), sonst
`_build_aero()` mit dem Plattenbaukasten (`BODY_DEFAULTS` + `BODIES`: Radgröße, Spur, Nase,
Hutze, Überrollbügel, Flügel, Rammschutz, Auspuffrohre, Stollenreifen, Stern; Bausteine
`_round_slab`, `_tube`, `_bar`, `_make_kit_wheel`). Lenkrad, Fahrer (Fell, Brille, Anzug,
Ärmel-/Handkontakt) und Fernstufe sind für alle gleich. Alles wird je Materialfamilie zu wenigen
Flächen verschmolzen (höchstens 64 Flächen). Werkstatt-Lack, -Felgen und -Neon wirken auf
beide Karosserien. Rivalen fahren mit anderen Karts der Flotte (`_rival_karts`).

## Rennanzeige

Gas, Bremse, SPEED, Item und Drift nutzen die Glasknöpfe aus PR 28
(`assets/kart/controls/reference/`, je Normal/Gedrückt/Deaktiviert), der Lenkstick Basis und
Knopf von dort. Zusätzlich zeigt der Item-Knopf als Abzeichen, was darin liegt: Schild, Impuls
oder Wind (`assets/kart/hud/icon_*.png`, erzeugt mit `python3 tools/art/make_hud_icons.py`).

## Bilder erzeugen (alles aus der Engine, ohne Bildbearbeitung)

```
godot --rendering-method gl_compatibility --script scripts/tests/kart_thumbnail_capture.gd -- assets/kart/fleet
godot --rendering-method gl_compatibility --script scripts/tests/kart_sheet_capture.gd -- out.png comet fox --no-driver --views=front,side,rear,top,three,three_rear
godot --rendering-method gl_compatibility --script scripts/tests/kart_lineup_capture.gd -- out.png
godot --rendering-method gl_compatibility --script scripts/tests/kart_garage_capture.gd -- <ordner>
```

Nach neuen Bildern: `godot --headless --path . --editor --import --quit` (die `.import`-Dateien
sind nicht im Repository).

## Tests

- `kart_fleet_regression` (Codex): alle 14 Karts bauen, Flächenbudget, Räder, LOD, Drift/Boost,
  Prüfansichten der Garage, Fahrt und Speichern jedes Profil-Designs.
- `kart_fleet_stats_regression`: Werte, Wirkung bei Tempo, Beschleunigung, Bremsen, Lenken und
  Turbo, Werkstatt (Kauf, Rückgabe, Speichern, Schutz vor kaputten Dateien).
- `kart_workshop_regression`: Karten, Sperren, Verbessern/Kaufen/Zurückgeben, Zurück-Taste,
  Layout auf fünf Größen.
- `kart_vehicle_regression`: Flächenbudget, Fern-Stufe (unabhängige Referenz-Verschmelzung).
- `kart_fold_controls_regression`, `kart_touch_regression`: Rennanzeige, Fold-Größen, Touch.

## Noch offen

- Baukasten-Karts an Codex’ abgesenkten Fahrer und Sitz angleichen (Sichtprüfung offen).
- Fahrer-Anzug: Schulterpolster, Nähte, Gurt mit Sechseck-Schnalle.
- Echtes Gerät: Bildrate und Tastgefühl mit den neuen Karts und der neuen Anzeige.
