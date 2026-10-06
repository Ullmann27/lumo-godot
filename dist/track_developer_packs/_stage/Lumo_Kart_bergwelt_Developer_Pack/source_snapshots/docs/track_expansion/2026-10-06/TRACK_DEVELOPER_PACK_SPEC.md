# Lumo Kart – Developer Track Packs (2026-10-06)

Ausgangspunkt ist PR #18 / Branch `chatgpt/kart-himmelsinseln-stage2-2026-10-05`, vorheriger Head `1aa81a603948aa574a49105fdc74a76ead3baa55`.

## Verbindlicher Produktumfang

Für jede der vier aktuell real vorhandenen Rennwelten wird ein eigenes Entwicklerpaket gepflegt:

1. `sonnenhafen` – Sonnenhafen
2. `zauberwald` – Zauberwald
3. `bergwelt` – Himmelsinseln
4. `holo_city` – Hologramm-City

Jedes Paket muss mindestens **120 einzeln prüfbare Bau-/Gameplay-/QA-Details** und **48 definierte Ansichten** enthalten. Es ist kein Bildordner, sondern ein Level-Design-/3D-Handoff.

## Pflichtinhalt je Welt

- aktueller Godot-Control-Point-/Spline-Bezug aus `kart_tracks.gd`
- 10,8 m Fahrbahnbreite; sichtbare Rail und Collision dürfen nicht auseinanderlaufen
- top-down Route + Centerline-Daten
- Guide-Geometrie/Authoring-Vorgabe für:
  - Straße
  - Rampe
  - Brücke
  - Tunnel
  - Voll-Looping
- mindestens zehn benannte Signature-Setpieces mit Status `implemented`, `planned` oder `planned_requires_inverted_physics`
- Checkpoints, Respawn, Abkürzungen, Jump-/Landing-Korridore
- AI-Racing-Line-Anker, Zielgeschwindigkeiten, Überholbreite, Shortcut-Eignung
- Mystery-Item-Zonen
- Materialien, Beleuchtung, VFX, Audio, Kamera, LOD/Performance und Collision-QA
- 48 Shot-/View-Definitionen: Orbit, Orthographic, Fahrersicht, Setpiece, Item, AI- und Collision-Debug
- eindeutige Dateinamen, IDs und Maße in Metern

## Mystery-Item-System

Die sichtbaren Zufallsobjekte heißen **Lumo Mystery Prisms**. Aktive Core-Items bleiben kompatibel zum aktuellen Runtime-Stand:

- `boost`
- `shield`
- `pulse`

Empfohlene positionsabhängige Gewichtung:

| Position | Boost | Shield | Pulse |
|---|---:|---:|---:|
| 1 | 0.25 | 0.45 | 0.30 |
| 2 | 0.32 | 0.40 | 0.28 |
| 3–4 | 0.45 | 0.35 | 0.20 |
| 5 | 0.60 | 0.25 | 0.15 |
| 6 | 0.70 | 0.20 | 0.10 |

Catch-up erfolgt über die Itemgewichtung, nicht über Teleportation oder versteckte Top-Speed-Vorteile. Rivalen verwenden dieselben Item-IDs und sichtbare Cooldowns.

## Weltidentität

### Sonnenhafen
Pflichtanker: LUMO GRAND PRIX Starttor, Stadiongerade, Klippen-S-Kurve, Wasserfallterrasse, Hafenabfahrt, Waterfront-Sweep. Nächste Module: Leuchtturm-Haarnadel, Pier-Tunnel, Fähranleger-Abkürzungsrampe, Zugbrücken-Sprung, **Seabreeze Loop**.

### Zauberwald
Pflichtanker: Leuchtbögen, Kristall-/Pilz-Beacons, Pilzhain, Baumtunnel, LICHTERHAIN. Nächste Module: Wurzelbrücke, Kristallhöhlen-Seitenroute, Baumkronen-Rampe, Mondlicht-Sprung, **Vine Loop**.

### Himmelsinseln
Pflichtanker: schwebende Inseln, bestehender Sprung/Gap, Tempelruinen, WOLKENWEG/Hauptweg-Split, Sternentor, Kristallhöhle, Luftschiff, Insel-Wasserfälle. Nächste Module: Doppelbrücke/Abkürzung und **Sky Halo Loop**.

### Hologramm-City
Pflichtanker: NOVA-LINK, AURORA-LINK, LUMO NEXUS, STAR CORE, Billboard-Canyon, Holo-Gates. Nächste Module: Maglev-Tunnel, Rooftop-Split, Drone-Port-Sprungsequenz, **Neon Orbital Loop**.

## Looping-Sicherheitsregel

Die vier Looping-Module dürfen als Guide-/3D-Authoring-Modul gebaut werden. Sie werden **nicht als befahrbare Runtime-Strecke freigeschaltet**, bevor alle folgenden Punkte technisch erfüllt sind:

1. Kart-Up-Vektor/Gravitation folgt der Streckennormalen über volle 360°.
2. Kamera bleibt relativ zur Fahrbahn stabil und kippt nicht unkontrolliert.
3. Rivalen verwenden dieselbe invertierte Fahrphysik und Racing Line.
4. Checkpoint/Respawn kann innerhalb und nach dem Loop sicher zurücksetzen.
5. Collision kennt Ober-/Unterseite der Loop-Fahrbahn korrekt.
6. Ein vollständiger Player- und AI-Lauf besteht als Engine-Test.

Keine optische Fake-Lösung.

## 3D-/Ansichtenstandard

Pro Welt 48 Views:
- 32 Orbit-Views: 8 Azimute (0/45/90/135/180/225/270/315°) × 4 Höhenwinkel (12/30/55/75°)
- Top/Front/Left/Right Orthographic
- Driver Start, erster Turn, Mitte, letzter Sektor
- Signature-Setpiece front/back
- Loop side/top
- Mystery-Item-Lane
- Shortcut Entry
- AI Debug Top
- Collision Debug

## Fairness / Lerntrennung

Lumo Kart bleibt Freizeitspiel. Im Rennen gibt es **keine Lernfragen, Antworttimer, Lern-Cups oder Richtig=Turbo-Mechanik**. Bücher/Bibliotheksmotive dürfen Kulisse oder Sammelobjekt sein, nicht Prüfmechanik. Lernfortschritt darf das Spiel in Flutter freischalten.

## Performance

- repeated props/crowds über MultiMesh
- mobile LOD0/LOD1/background separation
- einfache Collision-Meshes
- wenige transparente Materialien
- gemeinsame Atlanten/Materialinstanzen
- keine Hintergrund-Props mit unnötigen dynamischen Schatten
- Low-Detail-Profil muss spielerisch gleich lesbar bleiben
- 60 FPS ist Zielbudget; **kein Fold-7-FPS-PASS ohne echten Gerätetest**

## Nächste Engineering-Reihenfolge

1. Pack-Dateistruktur und IDs repo-seitig anlegen.
2. Himmelsinseln als Loop-/Setpiece-Prototyp technisch fertig machen.
3. Inversion-Physik nur nach eigenem Testvertrag aktivieren.
4. Danach Sonnenhafen, Zauberwald und Holo City weltweise skalieren.
5. Pro Welt Runtime-Captures aus den 48 View-Definitionen erzeugen.
6. Erst danach freigegebenen Godot-SHA bewusst in lumo-lernen pinnen und Test-APK bauen.
