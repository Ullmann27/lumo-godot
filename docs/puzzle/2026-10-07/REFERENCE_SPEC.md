# Puzzle – schriftliche Ableitung vor dem Bauen

## Komposition und Sprache

Die Asset-&-Flow-Tafel zeigt eine Nachtwelt, nicht eine flache bunte
Lernkarten-Seite: links ein großer konsistenter Lumo, rechts ein annähernd
senkrechtes Puzzle mit echter Dicke; Nachtblau, cyan Konturen, goldene Sterne,
warme Laternen. Im Key Art stehen Schloss/Wasserfälle/Mond hinter dem Fuchs.
Runde fröhliche Schrift, dunkle Glaskarten und klare große Symbole.
Schloss, Wasserfälle, Brücke, Vegetation und Requisiten benötigen für eine
echte bewegliche 3D-Welt Geometrie. Eine Motivtextur auf einem räumlichen
Puzzleteil ist dagegen die vorgesehene Bildoberfläche des Puzzles.

## Vollständiges sichtbares Inventar nach Board-Bereichen

| Bereich / sichtbare Elemente | Bestand auf BASE | Umsetzung / Grenze |
| --- | --- | --- |
| Kopf: Lumo-Puzzle-Logo, cyan Titel, Goldsterne, Mond, Sterne, Blätter, Schloss, Holzschild, Laterne | Referenzbilder, Nunito; kein Puzzle-Logo-Asset | UI-Text mit Nunito; Logo-Freisteller noch fehlt |
| 1 Runtime: Lumo orange/weiß, cyan Stern-Halstuch, dunkler Rucksack, Felsboden, Laternen, Bäume, Schloss, Wasserfälle, Nachtwald | Allgemeiner Primitiv-Charakter, Kart-Weltcode; keine finale Puzzle-Szene | Finaler Lumo BLOCKED_3D_ASSET; fremde Kart-/Character-Dateien nicht verändern |
| 1 Spiel: Home-Knopf, Titel Mondlicht-Schloss, Teil-Icon, 6/12, 2/3 Sterne, Settings, Puzzlebrett, fertige/fehlende/angehobene Teile, Cyan-/Goldrand, Funken | Keine Puzzle-Runtime | Echte Meshes, eigener Kern, UI; echte Zahlen statt 6/12-Beispieldaten |
| 2 Motive: Mondlicht-Schloss, Magische Wasserfälle, Baumhaus-Dorf, Sonnenbucht mit Schiff | Nur kleine Board-Vorschaubilder | Schlossmotiv neu erzeugen; andere Motive bleiben offene Assets, keine unscharfe Hochskalierung |
| 3 Formen: gerade Außenkanten, runde Innenkanten, Knauf/Mulde; Classic, magischer Leuchtrand, Holz, Glas | Keine Puzzle-Meshes | Räumliche Classic-Teile mit passenden Knauf/Mulde-Nachbarn; Holz/Glas-Varianten offen |
| 4 Ablauf: Finger/Hand, Touch & Hold, Lift/Hover Glow, Auto-Snap, Goldfunken/Partikel | Keine Puzzle-Input-Logik | Finger/Mouse-Pick, Lift, validierter Snap, sichtbarer Erfolg; Hand-Grafik nicht nötig für Eingabe |
| 5 Stufen: Einfach 12, Mittel 24, Anspruchsvoll 48, Experte 96; vier Vorschaubilder | Keine Puzzle-Stufen | 4x3, 6x4, 8x6, 12x8; vier Stufen verbindlich |
| 6 UI: Fortschrittsbalken/Teilzähler, Glühbirne/Tipp, Drehen falls nötig, Zurücksetzen/neues Puzzle, Settings Audio/Sprache | Nunito und allgemeine Material-/UI-Technik | Große konsistente Buttons, Hilfe, Reset, Pause; Drehen optional, Audio/Sprache keine erfundene Freigabe |
| 7 Ergebnis: bis 3 Sterne, Puzzle geschafft, Share-Icon, fertiges Miniaturbild, Lumo-Gesicht/Herz | Keine Puzzle-Ergebnis-Runtime | Ergebnis mit echten Sternen; sensible Außenveröffentlichung/Share bleibt deaktiviert |
| Key Art ergänzend: Kompass, Karte, Bücher Schlösser/Wälder/Sterne/Freunde, Boden-/Randstücke, Laternen, Brücken, Wasser | Nur Referenz / Kart-Props | Nicht als Pixel-Kulisse/Fake-Geometrie verkaufen; Requisiten-Set noch offen |
| 8 Prompt und große technische Abschnittsnummern | Dokumentation | Kein Runtime-UI, nicht aus dem Board ausschneiden und als Spiel ausgeben |

## Alpha-/Quellenprüfung

Die Tafeln sind zusammengesetzte flache Bilder mit Überschneidungen, Glow und
Beschriftung. Fuchs, Schloss, Laternen und Bücher haben keine vollständigen
isolierten Konturen; daraus entsteht kein sauberer finaler Freisteller und
kein Rig. Keine verschmierten Kanten oder vorgetäuschte Rückseiten.

Einzelne Puzzleteile werden aus einer neuen scharfen Motivtextur mit exakt
derselben deterministischen Silhouette geschnitten, die auch das 3D-Mesh
verwendet. Alpha = außerhalb der Silhouette transparent, nicht Hintergrund-
Ersetzung am unscharfen Board. Runtime verwendet einen gemeinsamen Atlas und
UVs; exportierte Alpha-Teile dienen Pipeline-/Asset-Prüfung.

## Funktionale Ableitung und nicht festgelegte Regeln

- Freies Ziehen; nur das richtige Teil am richtigen Platz rastet ein.
- Hilfe zeigt Zielkontur, löst nicht ungefragt das Puzzle.
- Kein Zeitdruck. Pause/Fensterwechsel dürfen den Fortschritt nicht verlieren.
- Board legt bis drei Sterne fest, keine Wallet-Schwellen. Vorläufige lokale
  Sterne: 3 ohne Hilfe, 2 mit wenigen, 1 bei häufigen Hilfen; kein Einfluss auf
  bestehende Produktpreise/Unlocks. Host-Wallet-Handoff bleibt ungeprüft.
- Ein vollständiger Kern ist nur ein Teil der Abnahme. Fehlender 3D-Fuchs,
  Welt-/Motiv-/Materiallücken: VISUAL_GAP / NOT FINISHED, keine Freischaltung.
