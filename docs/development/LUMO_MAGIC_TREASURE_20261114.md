# LUMO: Zauberhafte Sternenpfade auf der Schatzinsel

## Kindererlebnis
Originale räumliche Lichtsternchen führen entlang des tatsächlich freigeschalteten Abenteuers. Gold steht für das erste Ziel, Mond-Cyan für den zweiten Ast an der Weggabelung. Nach einer tatsächlichen Entdeckung oder korrekt beantworteten Frage entsteht ein kleiner Sternenkranz um Lumo. Nach dem Schatzfund zeigen die Spuren keine falschen Ziele mehr.

## Technik und Abnahme
- Echter Godot Spatial Shader und Camera-Billboards, maximal 16+16 instanzierte Führungssterne und 20 wiederverwendete Erfolgssterne; keine zusätzlichen Lichter, Schatten, Kollisionen, Touchflächen oder Texturen.
- Update der visualisierten Instanzen auf 24 Hz begrenzt. Reduzierte Bewegung stoppt das Schweben und lässt die Marker stehen; pausierte Dialoge stoppen dekorative Animationen.
- Die komplette Quest-, Speicher-, Kapitel- und XP-Autorität verbleibt unverändert in TreasureState. Die künstlerische Erweiterung kann dadurch niemals einen Schatz oder Fortschritt fingieren.
- Der neue quellgebundene CI-Workflow importiert das Originalprojekt, führt separate Sternen- und bestehende Spielpfad-Regressionen aus und zeichnet drei unverfälschte Godot-Bilder auf. Für Freigabe sind erfolgreiche Jobs und Sichtkontrolle erforderlich.
- Dieser PR verbessert ausdrücklich die Schatzinsel, noch nicht jede Welt und noch nicht das endgültige Android-Paket. Kein Merge nach main; Android-Signierung, Geräte-FPS und Freigabe sind weiterhin gesonderte Prüfungen.

Design: warmes Märchengold, sternförmige Lichtkerne, zartes Mond-Cyan, aufmerksames, kindgerechtes Orientieren statt aufdringlicher Menü-Overlays.
