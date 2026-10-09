# Open-Source-Track-Tech-Recherche – 2026-10-05

Ziel: Lumo Kart optisch und technisch auf das Niveau eines hochwertigen Family-Kart-Racers heben, ohne geschützte Franchise-Assets, Logos, Figuren oder exakte Streckenlayouts zu kopieren.

## Verbindliche visuelle Erkenntnisse aus Heinz' Referenzbildern

Die Zielqualität kommt nicht von einem einzelnen Shader, sondern von der Kombination aus:
- breiter, sauber lesbarer Asphaltfläche,
- rot/weißen Curbs und klaren Fahrbahnmarkierungen,
- großen Kurvenradien und sichtbarer Streckenführung,
- gestaffelten Fels-/Gras-Terrassen,
- Landmarken alle ca. 10–15 Fahrsekunden,
- Wasserfällen, Brücken, Tunnel-/Cliff-Passagen,
- Tribünen, Starttor, Flutlicht und Straßenlaternen,
- großen Richtungsschildern vor Kurven,
- deutlich sichtbaren Mystery-Item-Reihen,
- mehreren Tiefenebenen der Umgebung statt leerer Fläche,
- stark gesättigter, aber sauber beleuchteter Materialpalette.

## Geprüfte öffentliche Vorlagen / Technikquellen

### Godot Road Generator – TheDuckCow / Moo-Ack! Productions
- Repo: https://github.com/TheDuckCow/godot-road-generator
- Godot Asset Library: Godot Road Generator 0.9.4
- Lizenz: MIT
- Relevante Technik:
  - Path-/RoadPoint-basierte Straßengeometrie,
  - nahtlose Segmente,
  - beliebige Fahrspuren,
  - Kollisionsmeshes,
  - Lane-Agent-Pfade für KI,
  - Export nach glTF.
- Entscheidung für Lumo:
  - nicht blind als Runtime-Abhängigkeit einbauen;
  - die Architektur als Authoring-/Validierungsreferenz nutzen;
  - Lumo behält die eigene leichte Curve3D-/SurfaceTool-Laufzeitstrecke für Android/Fold;
  - bei späteren komplexen Alternativrouten kann Road Generator im Editor als Offline-Authoring-Werkzeug dienen.

### Terrain3D – TokisanGames
- Repo: https://github.com/TokisanGames/Terrain3D
- Lizenz: MIT
- Relevante Technik:
  - große editierbare Terrainflächen,
  - LOD,
  - Textur-/Farb-Painting,
  - Heightmap-Import.
- Entscheidung für Lumo:
  - derzeit nicht als zwingende Android-Runtime-Abhängigkeit übernehmen;
  - sinnvoll für Offline-Terrain-Authoring/Baking, sobald Android-/Fold-Export in unserem Build praktisch validiert ist;
  - aktuelle prozedurale Lumo-Terrainmeshes bleiben für den Test-Build die sichere Basis.

### GDQuest godot-shaders
- Repo: https://github.com/gdquest-demos/godot-shaders
- Lizenz: Shader-/Source-Code MIT; Art-Assets CC-BY 4.0.
- Relevante Technik:
  - directional tint / stylized surface shading,
  - stylized waterfall,
  - wind / grass,
  - force-field / glow.
- Übernommen:
  - ausschließlich die MIT-Technikidee des directional tint;
  - eigener Lumo-Shader `assets/shaders/kart_stylized_vertex_tint.gdshader`,
  - umgeschrieben für unsere prozeduralen Vertex-Farben;
  - keine fremden Bild-/Audioassets übernommen.

### Godot Engine – SurfaceTool und MultiMesh
- SurfaceTool bleibt für kontinuierliche Straßen-/Terrainmeshes.
- MultiMesh bleibt für wiederholte Props: Curbs, Crowd, Felsen, Leuchten, Barrieren, Schilder.
- Das passt bereits zur bestehenden Lumo-Architektur und hält Draw-Call-Kosten beherrschbar.

## Direkt umgesetzt nach dieser Recherche

Sonnenhafen:
- rot/weiße Curbs,
- hellere filmische Beleuchtung,
- stylized directional terrain tint,
- zwei Starttribünen mit GPU-batched Crowd,
- neues LUMO GRAND PRIX Starttor,
- Startplatz-Markierungen,
- gelb/schwarze Kurven-Chevronboards,
- Straßenlampen,
- eigener Küsten-Wasserfall mit Fels-/Gras-Terrasse.

Himmelsinseln:
- bleibt eigenständige Nacht-/Fantasy-Welt und wird nicht in Sonnenhafen umgefärbt.

## Nächster Technikschritt

1. Sonnenhafen im Godot-Renderer erfassen.
2. Sichtabstände, Clipping und Draw-Calls messen.
3. Referenz-Screenshot gegen echten Runtime-Screenshot vergleichen.
4. Danach dieselbe Qualitätsmatrix auf Zauberwald/Holo City/weitere Welten übertragen.
5. Erst dann weitere High-Cost-Technik wie Terrain3D als Runtime-Kandidat erwägen.
