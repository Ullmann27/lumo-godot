# LUMO Kart – erste gemeinsame Material- und Kantenausarbeitung

## Stand und Grenzen

15. November 2026. Ausgangscode: `e4d6577837663ae165a3b92bff1fb4c4e7e735de` aus `chatgpt/lumo-kart-modular-parts-20261114` (PR 184).
Gepruefter Implementierungs-/Capture-Stand: `0094e693b1e921f1e8447fa2d0d3ba3f4898f39d`.
Arbeitszweig: `chatgpt/lumo-track-art-pass-20261115`.

Das ist eine erste, bereits im Spielaufbau angeschlossene Verfeinerung vorhandener Streckendekoration. Keine vollstaendige Neumodellierung, kein Blender-Assetpaket, keine neue APK und keine physische Fold7-/FPS-/Thermik-Abnahme. Bestehende uebergeordnete Renn-/Resonanzring-Fehler werden hier nicht als behoben bezeichnet.

Es wurden **keine drei autonomen KI-Agenten gestartet**. Die Implementierung wurde in der aktuellen Sitzung ausgefuehrt. Tatsaechlich eingerichtet und ausgefuehrt wurden **drei parallele GitHub-Actions-Pruef-/Renderworker** mit je vier Strecken.

## Umgesetzte Arbeit

### 1. Geometrie

`kart_track_art_meshes.gd` erstellt ein gemeinsam genutztes Bauteil mit gefasten Kanten, 44 Dreiecken und exakt denselben Aussenabmessungen wie die urspruengliche Einheitsbox. Nur geeignete nichtleuchtende Box-Batches der hohen Detailstufe werden ersetzt. Niedrige Detailstufen behalten die urspruengliche Geometrie. Die Fahrbahn und Kollisionsmodelle werden nicht veraendert.

### 2. Materialien und Lichtreaktion

`kart_track_art.gdshader` differenziert lackierte/verputzte Flaechen, Holz, Metall, Gestein, Dachziegel, Blattwerk und Kristalloberflaechen. Ergaenzt werden dezente Koernung, Fugen und Dachmuster sowie passende Rauheit/Metallizitaet. Fern- und Pixelgroessenfilter begrenzen flimmernde Feinstrukturen. Urspruengliche Instanzfarben bleiben die Grundlage; Candy und technische Welten erhalten passende Parameter.

Es wurden keine neuen Szenenlichter angelegt und keine bestehende Lichtstimmung ersetzt. Vorhandene Spezialshader fuer Wasser, Lava, Glas und Cinema-Felsen sowie transparente, leuchtende oder normaltexturierte Materialien werden ausgespart. Dies verbessert die Materialreaktion auf das vorhandene Licht, nicht die gesamte Beleuchtungsregie.

### 3. Integration und Bildvergleich

`kart_track_art_finish.gd` wird ueber zwei neue Zeilen in `kart_modular_route_props.gd` in allen drei vorhandenen Weltaufbaupfaden angeschlossen. Ein einmaliger, verzoegerter Durchlauf nach dem MultiMesh-Aufbau setzt die Oberflaechen. Keine per-frame Modellierungsarbeit, keine neuen Instanzen oder Gameplay-Kollisionen. Die Originalmaterialien und -meshes bleiben fuer einen vollstaendig umkehrbaren Vergleich erhalten.

Die Capture-Probe baut die echte vollstaendige Produktionswelt und nimmt dieselbe Kameraposition, denselben eingefrorenen Zeitpunkt und das urspruengliche Szenenlicht vor/nach der Aenderung auf. Zwei schlecht platzierte Pruefkameras wurden nach Bildsichtung korrigiert, ohne Spielgeometrie auszublenden oder die Gameplay-Kamera zu veraendern. Die Labor-Nahansicht bleibt durch vorhandene grosse Gebaeude eingeschraenkt; sie ist keine bestandene gestalterische Endabnahme.

## Drei nachweislich ausgefuehrte Worker

| Worker | Strecken | Pruefung |
|---|---|---|
| 1 | Sonnenhafen, Zauberwald, Himmelsinseln, Hologramm-City | 8 low/high-Faelle, 16 PNGs |
| 2 | Kristall-Canyon, Dschungel-Tempel, Candy Cloud, Vulkan-Nacht | 8 low/high-Faelle, 16 PNGs |
| 3 | Winter-Sprint, Galaxy Ringway, Desert Drift, Funkel-Labor | 8 low/high-Faelle, 16 PNGs |

[Finaler Godot-4.6.3-Prueflauf](https://github.com/Ullmann27/lumo-godot/actions/runs/43695154218): **alle drei Jobs erfolgreich**.

- 24 echte Produktionsfaelle: jede der zwoelf Strecken in niedriger und hoher Detailstufe.
- Hashvergleich der Fahrkurve, Streckenlaenge, Kontrollpunkte, MultiMesh-Instanzdaten und Dekorationsanzahl vor/nach Aktivieren, Deaktivieren und erneutem Aktivieren.
- Endliche Koordinaten, normierte Normalen, korrekte Vorderseitenorientierung, 132 Vertices und unveraenderte AABB des gefasten Bauteils.
- Unveraenderte Low-Detail-Geometrie, erhaltene Schattenflags und wiederholbare Anwendung ohne duplizierte Datensaetze.
- 48 echte PNGs in 1280 x 720, zwoelf Aufnahmemanifeste mit Bild-Hashes und exakt dokumentierter Quellrevision.
- Alle drei ZIP-Hashes, alle 48 PNG-Hashes, Bildgroessen, 24 PASS-Protokolle und Quellrevisionen nach Download nochmals unabhaengig im Arbeitscontainer geprueft.

Die Bilder sind Desktop-Godot-/GL-Compatibility-Aufnahmen, keine Screenshots einer installierten Handy-APK und keine KI-generierten Zielbilder.

### Artefakte zum finalen Commit

- Worker 1: Artifact `14153609726`; SHA256 `a9a916a96a615ad5bfc92daaa9391e427435702a215602f907fc4959d666b165`.
- Worker 2: Artifact `14153908964`; SHA256 `15fc0a237b30aaa7bed243a9bf69b0341b205dc31f9a08bcb427b7f2c48e50ae`.
- Worker 3: Artifact `14153863993`; SHA256 `d1f00c1821f663465b6742f98fd5d7d516a97e25eff2b9e67718dcf3f979d1b5`.

Der initiale RED-Lauf `43693979729` scheiterte vor Implementierung erwartungsgemaess an `Missing production TrackVisualFinish hook`; die anschliessenden echten Engine-Pruefungen bestanden. Tests wurden nicht abgeschwaecht, um einen Erfolg vorzutäuschen.

## Weiterer Grafikbedarf

Der sichtbare Gewinn ist bei Dach-/Fassadenoberflaechen und Gestein am deutlichsten, in einzelnen Welten subtil. Breite leere Flaechen, einfache Landschaftssilhouetten, wiederholte Objektformen, vorhandene Ueberdeckungen und zu geringe Umgebungsdichte sind damit nicht geloest. Dafuer sind streckenspezifische Modellierung, Layoutkorrekturen und gegebenenfalls bearbeitbare Blender-Assets erforderlich. Kein AAA-/Fotorealismus-/Referenzgleichheitsversprechen.

Main, Releases, Flutter-Pin, Paketname, Signatur, Figurenrigs, Originalanimationen und Rennregeln bleiben unveraendert. Vor einer neuen APK sind die Gesamtintegration, vorhandene Rennregressionen und echte Android-Leistungsmessungen separat erforderlich.
