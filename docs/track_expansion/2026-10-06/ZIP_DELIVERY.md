# Lumo Kart - Developer ZIP Delivery

Branch: chatgpt/kart-developer-packs-zip-2026-10-06
Base candidate: c650ff17a5b6a8016fccab0d9b530e0260c6c797

## Ziel

Aus den bereits strukturierten Track-Packs werden reproduzierbare Entwickler-ZIPs
erzeugt. Die ZIPs sind kein Bildarchiv, sondern ein umsetzbares 3D-/Level-Design-
Handoff mit Route, Maßen, Setpieces, Ansichten, Items, AI, QA und Source-Snapshots.

## Aktueller Umfang

| Welt | Details | Views | Route-Punkte | Signature-Setpieces | Mystery Prisms |
|---|---:|---:|---:|---:|---:|
| Sonnenhafen | 130 | 48 | 17 | 10 | 5 |
| Zauberwald | 120 | 48 | 12 | 10 | 5 |
| Himmelsinseln / Bergwelt | 120 | 48 | 12 | 10 | 5 |
| Hologramm-City | 122 | 48 | 13 | 10 | 5 |

Jede Welt liegt damit ueber den geforderten 100 einzeln pruefbaren Details.

## Erzeugte ZIPs

- Lumo_Kart_sonnenhafen_Developer_Pack.zip
- Lumo_Kart_zauberwald_Developer_Pack.zip
- Lumo_Kart_bergwelt_Developer_Pack.zip
- Lumo_Kart_holo_city_Developer_Pack.zip
- Lumo_Kart_Track_Developer_Packs_ALL.zip

Jede Einzel-ZIP und die Gesamt-ZIP muessen hart unter 30 MiB bleiben. Der Build
bricht ab, wenn diese Grenze ueberschritten wird.

## Inhalt je Einzelpaket

- README.md
- pack.json
- manifest.json
- tables/details.csv
- tables/views.csv
- tables/signature_setpieces.csv
- tables/checkpoints.csv
- tables/ai_racing_line.csv
- tables/mystery_prisms.csv
- tables/route_control_points.csv
- guides/geometry_guides.json
- guides/palette.json
- guides/fairness.json
- guides/SHOTLIST_48_VIEWS.md
- guides/IMPLEMENTATION_CHECKLIST.md
- guides/LOOPING_INVERSION_CONTRACT.md
- guides/ITEM_SYSTEM.md
- guides/QA_ACCEPTANCE.md
- source_snapshots/ mit den relevanten Godot-/Shader-/Testquellen

## 48 Ansichten je Strecke

Die vorhandene Spezifikation wird unveraendert in die Entwicklerpakete uebernommen:

- 32 Orbit-Views aus 8 Azimuten x 4 Hoehenwinkeln
- 4 Orthographic-Views
- 4 Driver-Views
- 2 Signature-Setpiece-Views
- 2 Loop-Views
- 1 Mystery-Item-Lane
- 1 Shortcut-Entry
- 1 AI-Debug-Top
- 1 Collision-Debug

Damit bekommt ein 3D-/Level-Designer nicht nur eine schoene Perspektive, sondern
definierte Ansichten fuer Raumaufbau, Collision, Racing Line, Loop, Items und QA.

## Loopings

Pro Welt existiert ein Full-Loop-Guide. Er bleibt Authoring-only, bis Player,
Kamera, AI, Collision und Respawn die 360-Grad-Inversionsphysik als realen
Engine-Test bestehen. Keine optische Fake-Loesung.

## Item-/Zufallssystem

Die sichtbaren Zufallsobjekte bleiben Lumo Mystery Prisms. Core-Items:

- boost
- shield
- pulse

Die positionsabhaengige Gewichtung aus dem bestehenden Pack bleibt Teil des
Handoffs. Catch-up erfolgt ueber Itemgewichtung statt verstecktem Top-Speed oder
Teleportation.

## Lerntrennung

Lumo Kart bleibt Freizeitspiel. Keine Lernfragen, Antworttimer oder
Richtig=Turbo-Mechanik waehrend eines Rennens. Lernfortschritt darf das Spiel im
Flutter-Hub freischalten.

## Build

1. python3 tools/validate_track_packs.py
2. python3 tools/build_track_developer_packs.py
3. unzip -t fuer jede erzeugte ZIP
4. Groessenlimit pruefen
5. SHA256SUMS erzeugen
6. GitHub Actions Artefakte hochladen

Die ZIPs werden bewusst nicht als Binaerdateien in Git eingecheckt. Git enthaelt
die reproduzierbare Quelle und GitHub Actions liefert die gebauten Archive.
