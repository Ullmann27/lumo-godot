# Lumo Kart: vier eigenständige Rennwelten

Die Welten werden als echte Godot-3D-Geometrie aufgebaut. Die Screenshots in
`exports/screenshots/world-*.png` und `lumo-holo-cover.png` sind unveränderte
Aufnahmen des Godot-Viewports; sie sind keine Konzeptbilder.

## Umgesetzt

- **Sonnenhafen:** geformte Küsteninsel, blaues Meer, eigene Segel-/Motorboote,
  Marina, mehrseitig ausgearbeitete Häuser, Fensterläden, Blumenkästen,
  Markisen, Leuchtturm, Windmühle und eine Hängebrücke mit Seilen und Pfeilern.
- **Zauberwald:** deutlich größere Baumkronen, verzweigte Baumstämme, organisches
  Kronendach, Unterholz, leuchtende Pilze, Kristalle und kleine Lichtpunkte.
- **Kristallalpen:** verschneite Bergsilhouetten, Tannen, Felsen, Kristalle,
  Hängebrücke und ein durchgehender, gewölbter Steintunnel mit sauberen Portalen.
- **Hologramm-City:** erhöhte Fahrbahn, abgeschrägte Glasfassaden mit Fenster- und
  Rahmenraster, Blickwinkelreflexen und leuchtenden Fenstern, cyan/violette
  Gebäudekanten, Hologrammtore und eine zentrale Orbit-Skulptur.

Alle Strecken haben eigene Höhenverläufe, überhöhte Kurven, Asphalt, Randstreifen,
Leitplanken, sichtbare Checkpointfahnen und Richtungsschilder. Die Grundpalette
ist je Welt verschieden; Starttore verbinden sie mit dem dunkelblauen Lumo-Design.

## Geometrie und Fahrphysik-Schnittstelle

`build(lightweight: bool, selected_track: String = "sonnenhafen")` akzeptiert
`sonnenhafen`, `zauberwald`, `bergwelt` und `holo_city`.

Bestehende Methoden `position_at`, `forward`, `frame` sowie `curve`, `length` und
`WIDTH` bleiben erhalten. Bei `frame` ist X rechts, Y die Straßennormale und -Z
vorwärts. Neue Methoden:

- `sample_road(position, hint_distance)` liefert `distance`, `lateral`, `height`,
  `position`, `basis`, `on_road`, `width` und `forward`. Die Distanz liegt in Metern
  im Bereich `[0, length)`. Eine lokale Suche um den letzten bekannten Fortschritt
  vermeidet vollständige Streckensuchen während normaler Fahrt.
- `reset_transform(distance, lateral)` liefert eine sicher orientierte Position.
- `checkpoint_positions` enthält acht geordnete Kontrollpunkte.

Die Kontrollpunkte werden einmal geglättet. Dadurch bleiben die Kurven frei
lenkbar, statt unvermittelt in sehr enge Ecken überzugehen.

| Strecke | Länge | kleinster gemessener Kurvenradius |
| --- | ---: | ---: |
| Sonnenhafen | 383,7 m | 24,4 m |
| Zauberwald | 376,5 m | 19,5 m |
| Kristallalpen | 401,2 m | 20,6 m |
| Hologramm-City | 442,8 m | 22,5 m |

## Darstellungsprofile und Leistung

Dekoration wird je Mesh/Material und 48-Meter-Zelle mit MultiMesh gebündelt.
Entfernte Zellen werden ausgeblendet. Der leichte Modus reduziert Bäume,
Terrainauflösung und Schatten; Meer, Landmarken und alle Fahrbahnelemente bleiben.
Asphalt-Rauschen wird abhängig von Pixelableitungen ausgeblendet, um Flimmern zu
vermindern. Glas verwendet eine kostengünstige lokale Materialberechnung ohne
Screen-Space-Reflexionen.

Der hier verwendete Godot-4.6.3-OpenGL-Renderer zeigte bei zwei parallelen
Schattenkaskaden Moiré auf Gelände und Gebäuden. Ein tatsächlicher Vergleich mit
und ohne Schatten isolierte diese Ursache. Eine orthogonale Schattenkarte mit
85 Metern Reichweite beseitigt die Streifen und erhält echte Schlagschatten.

## Nachweis und Grenzen

- `kart_track_contract.gd`: bestanden für alle vier Kurse; prüft 3.600 Projektionen,
  Höhen, Querpositionen, Bankings, Nahtschluss, Kontrollpunktanzahl, Kurvenradien
  und ausreichenden Abstand nicht benachbarter Fahrbahnabschnitte.
- Vorhandener `kart_world_regression.gd`: bestanden (Instanzfarben,
  räumliche Gruppen, Transformationen, Hintergrundschatten).
- Alle vier Welten und das neue Fahrzeug wurden tatsächlich mit Godot 4.6.3,
  GL Compatibility und Mesa llvmpipe gerendert; keine Shader-/Skriptfehler.
- Die Showcase-Aufnahmen sind 1280 × 720 Pixel. Die Renderhilfe unterstützt
  `--track=sonnenhafen`, `--cover` und `--lightweight`.
- Die Tests ersetzen keine Messung auf einem echten Android-Gerät. Die
  vorstehenden Ergebnisse enthalten keine Behauptung von 60 FPS auf einem Handy.

## Assetherkunft

Alle hier ergänzten Strecken, Gebäude, Schiffe, Tunnel, Brücken, Pflanzen,
Bergsilhouetten, Kristalle, Straßen und Weltmaterialien wurden eigens für Lumo
mathematisch modelliert. Der Quelltext in `kart_world_meshes.gd` definiert die
originalen Profil-/Loft-Meshes, `kart_tracks.gd` die Strecken und `kart_world.gd`
ihre Anordnung. Die drei Weltshader sind ebenfalls eigener Projektcode.
Es wurden keine externen Spielmodelle, Nintendo-Figuren, Strecken oder Texturen
übernommen. Die Figur/Fahrzeuge stammen aus der parallelen Lumo-Überarbeitung.
