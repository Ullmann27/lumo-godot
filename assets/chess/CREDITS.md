# Lumos Schachwerkstatt

Die sechs Figuren und das Brett stammen aus eigenen Blender-Zeichnungen. Alle Maße sind in Metern, ein Feld ist 0,1 m breit. Porzellanfarbene und tintenblaue Figuren tragen eine Messingmanschette. Die Springer haben ein extrudiertes Pferdeprofil, die Damen eine offene Blütenkrone und die Könige ein breites Kreuz.

Das Skript baut die GLB-Dateien, berechnet die Texturen der salbeigrünen Spielfläche und rendert beide Figurensätze für die Draufsicht in Cycles. Getestet mit Blender 4.3.2, NumPy und Pillow.

```sh
blender -b -t 2 -P tools/lumo_chess_art/build_chess_set.py -- --only models,textures,icons
```

Lizenz wie das Projekt.
