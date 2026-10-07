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

## Erzeugte ZIPs und Teile

- Lumo_Kart_sonnenhafen_Developer_Pack.zip
- Lumo_Kart_zauberwald_Developer_Pack.zip
- Lumo_Kart_bergwelt_Developer_Pack.zip
- Lumo_Kart_holo_city_Developer_Pack.zip
- Lumo_Kart_Track_Developer_Packs_ALL.zip oder
  Lumo_Kart_Track_Developer_Packs_PART_01.zip usw.

Wenn ein Weltpaket wegen seiner nativen Aufnahmen zu gross wird, erstellt der
Builder `Lumo_Kart_<welt>_Developer_Pack_PART_01.zip` usw. Jedes Teil enthaelt
einen disjunkten Satz Dateien mit identischem gemeinsamen Pack-Verzeichnis;
alle Teile in denselben Zielordner entpacken, um das vollstaendige Pack
wiederherzustellen. Bilder werden nicht weggelassen oder herunterskaliert.

Auch die äußere Auslieferung wird bei Bedarf in `..._PART_01.zip` usw.
aufgeteilt. Jede Einzel- und Teil-ZIP bleibt strikt kleiner als 30 MiB.
`pack_summary.json`, `bundle_manifest.json` und `SHA256SUMS.txt` dokumentieren
Teile, Inhalt und Hashes; der Build bricht bei Grenzwertüberschreitung ab.

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
- runtime_views/: 48 native Godot-PNGs und `capture_report.json`
- geometry/runtime_world.glb: aus der vorhandenen Godot-Laufzeitwelt exportierte
  und per GLTFDocument erneut importierte Geometrie
- geometry/runtime_geometry_inventory.json: Instanzen, Transformationen,
  Mesh-Maße, Materialien und vorhandene Collision-Nodes
- geometry/authoring_full_loop.glb und `authoring_loop_inventory.json`:
  isoliertes, erneut importiertes Authoring-Modell ohne Collision

Der runtime-world-GLB ist ein Geometrie-Handoff; die JSON-Inventare bewahren
Instanztransformationen, Maße und Materialdaten. Collision bleibt durch die
Godot-Laufzeitquellen autoritativ und wird nur exportiert, wenn echte
Collision-Nodes vorhanden sind. Geplante Module werden nicht als implementierte
Geometrie ausgegeben.

## 48 Ansichten je Strecke

Die strukturierten Pack-Spezifikationen definieren diese 48 Ansichten:

- 32 Orbit-Views aus 8 Azimuten x 4 Hoehenwinkeln
- 4 Orthographic-Views
- 4 Driver-Views
- 2 Signature-Setpiece-Views
- 2 Loop-Views
- 1 Mystery-Item-Lane
- 1 Shortcut-Entry
- 1 AI-Debug-Top
- 1 Collision-Debug

Alle Bilder werden direkt mit Godot in **1920×1080** gerendert; es gibt kein
Upscaling. Das Capture-JSON zeichnet Pixelgröße, Kamera-Projektion,
Kameraposition, Target, Route-Bounds und Route-Länge pro Bild auf.
Orthographic-Seitenansichten werden aus der projizierten Routen-Bounds und dem
16:9-Seitenverhältnis gefittet; Wasser und Terrain werden dort als Vordergrund-
Okkluder ausgeblendet. Loop-Bilder isolieren das komplette Authoring-Modell; die
Top-Ansicht ist absichtlich schräg, damit die vertikale Loop-Form sichtbar bleibt.

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
5. Weltpakete und äußere Bündel bei Bedarf verlustfrei in ZIP-Teile unter 30 MiB
   splitten
6. SHA256SUMS erzeugen und ZIP-Integrität prüfen
7. GitHub Actions Artefakte hochladen

Die ZIPs werden bewusst nicht als Binaerdateien in Git eingecheckt. Git enthält
die reproduzierbare Quelle; GitHub Actions liefert Einzel-/Teil-ZIPs und den
gegebenenfalls gesplitteten äußeren Bundle-Transport.
