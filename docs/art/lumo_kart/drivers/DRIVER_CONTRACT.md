# LUMO Kart – Fahrerpaket und Anschlussvertrag

## Dateien und Zuständigkeit

Die fünf Modelle folgen der bestehenden Rivalenliste: `lion`, `owl`, `rabbit` (Nova), `squirrel`, `turtle`. Die bestehenden Referenzbilder wurden vor der Modellierung angesehen. Der originale LUMO-Fuchs bleibt unverändert und wird ausschließlich für den dokumentierten Größenvergleich importiert.

| Inhalt | Pfad relativ zum Repository |
|---|---|
| Bearbeitbare Szenen | `art/lumo_kart/blender/drivers/<id>.blend` |
| Hochwertiges Modell | `assets/kart/production/drivers/<id>/driver.glb` |
| Mittlere Detailstufe | `assets/kart/production/drivers/<id>/driver_lod1.glb` |
| Entfernte Detailstufe | `assets/kart/production/drivers/<id>/driver_lod2.glb` |
| Blender-Generator | `tools/lumo_kart_art/drivers/build_drivers.py` |
| Verformungs- und Geometrieprüfung | `tools/lumo_kart_art/drivers/check_driver_poses.py` |
| Einzelansichten, Originalvergleich, Kartpassung | `tools/lumo_kart_art/drivers/render_driver_reviews.py` |
| Gemeinsame Ansichten aller fünf Fahrer | `tools/lumo_kart_art/drivers/render_roster.py` |
| Gemessene Geometrie, Texturen, Hashes | `evidence/lumo_kart_art/drivers/<id>/measurement.json` |
| Tatsächlich ausgewertete Posen | `evidence/lumo_kart_art/drivers/<id>/pose_check.json` |
| Vollständiges Exportmanifest | `assets/kart/production/drivers/manifest.json` |
| Kompakte Messwerttabelle | `docs/art/lumo_kart/drivers/MEASUREMENTS.md` |

Die Modelle sind eigenständige Produktionsassets und werden in der isolierten Godot-Prüfszene instanziiert. `assets/characters/rivals/roster.json`, `kart_vehicle.gd`, `kart_world.gd` und `kart_island.gd` werden durch diesen Generator nicht verändert. Das Hauptteam übernimmt die Zuordnung im tatsächlichen Rennspiel.

## Maße, Achsen und Bindung

Eine Einheit entspricht einem Meter. Blender verwendet X nach rechts, Y nach vorn und Z nach oben. Der GLB-Export wandelt dies in Godot-X nach rechts, Y nach oben und **−Z nach vorn** um. Die Modelle werden mit identischem Ursprung und einheitlicher Skalierung 1 an den Kartknoten gebunden.

| Anschluss | Godot-Koordinate in der neutralen Kartpose |
|---|---|
| Modellursprung | `(0, 0, 0)` |
| `SeatAnchor` | `(0, 0.69, 0.07)` |
| `Grip_L` / `Hand.L` | `(-0.16, 1.055, -0.34)` |
| `Grip_R` / `Hand.R` | `(0.16, 1.055, -0.34)` |
| `Foot_L` / `Foot.L` | `(-0.18, 0.80, -0.24)` |
| `Foot_R` / `Foot.R` | `(0.18, 0.80, -0.24)` |
| `HeadAnchor`, `NeckAnchor` | `(0, 1.42, 0.015)` |

Die neue Kopfgruppe wurde nach einem tatsächlich gerenderten Vergleich mit dem Original-LUMO einheitlich auf 0,84 ihrer ersten Größe reduziert. Gesichtsgeometrie, Augen, Ohren, Brille, Head-/Ear-Bindungen und Animationsruhelagen wurden gemeinsam angepasst. Sitz, Becken, Hände und Füße bleiben an den oben angegebenen Anschlüssen. Diese Proportionsanpassung ist bereits in den Exportdateien enthalten.

Die Stiefelsohle beginnt bei Y = 0,720 m; das obere Schuhvolumen beginnt bei mindestens Y = 0,741 m. Diese Werte folgen der gemeinsamen Prüfung gegen die Pedalgriffe und das angepasste Sitzpolster des Kartpakets. Die vollständigen Dreieckskontaktprüfungen liegen unter `evidence/lumo_kart_art/karts/rabbit_boot_clearance.json` und nennen die tatsächlich geprüften Modellhashes.

Die rückseitigen unteren Anzug- und Gürtelringe folgen der tatsächlich vermessenen inneren Sitzschale. Nur die hintere Hälfte dieser beiden Kleidungsflächen wird in der Tiefe komprimiert; Vorderfläche, Ringhöhen, Breiten, Gelenke und die obigen Anschlussmarker bleiben gleich. Die Form wurde mit 30 mm Abstand zur zentral gemessenen Schalenkontur entworfen und anschließend am tatsächlichen Mesh geprüft.

Die Körperanhänge bleiben anatomisch verbunden. Die Hasenquaste sitzt im freien Raum am unteren Rücken oberhalb des engen Schalenanstiegs. Löwen- und Eichhörnchenschwanz beginnen am Körper, steigen vor der Lehne auf und führen erst oberhalb ihrer Oberkante nach hinten. Die Eulenfedern liegen eng am Rücken. Der Schildkrötenpanzer zieht sich unten sowohl in Tiefe als auch Breite zur Körperkontur ein; seine charakteristische obere Wölbung bleibt erhalten. Die seitliche Reserve berücksichtigt die tatsächliche Körperauslenkung beim Lenken.

## Rig und Animationen

`DriverRig` enthält 21 Knochen und ein gemeinsames skinned `DriverMesh`. Alle Vertices besitzen normalisierte Gewichte; die tatsächlichen maximalen Einflusszahlen und Gewichtssummen stehen in den Messdateien. Ärmel und Hosenbeine werden über benachbarte Gelenke verformt. Gesichtsteile folgen `Head`, Ohren `Ear.L`/`Ear.R`; Tieranhänge haben eigene Bindungen.

| Knochen | Elternknochen |
|---|---|
| `Root` | Modellursprung |
| `Pelvis` | `Root` |
| `Spine` | `Pelvis` |
| `Chest` | `Spine` |
| `Neck` | `Chest` |
| `Head` | `Neck` |
| `UpperArm.L`, `UpperArm.R` | `Chest` |
| `Forearm.L`, `Forearm.R` | jeweiliger `UpperArm` |
| `Hand.L`, `Hand.R` | jeweiliger `Forearm` |
| `Thigh.L`, `Thigh.R` | `Pelvis` |
| `Shin.L`, `Shin.R` | jeweiliger `Thigh` |
| `Foot.L`, `Foot.R` | jeweiliger `Shin` |
| `Ear.L`, `Ear.R` | `Head` |
| `Tail` | `Pelvis` |

Die Namen L/R bezeichnen die bestehenden Anschlussseiten des Kartvertrags. Der Import darf sie nicht anhand einer Bildschirmansicht vertauschen.

| Clip | Inhalt | Aktive Key-Spanne bei 24 FPS | Godot-Cliplänge |
|---|---|---:|---:|
| `idle` | Standpose, Atmung, kleine Arm-/Ohr-/Anhangsbewegungen | 2,958333 s | 3,0 s |
| `kart_seated` | Sitzpose mit Atmung und gehaltenem Lenkradkontakt | 2,958333 s | 3,0 s |
| `kart_steer_left` | tatsächlich bewegte Lenkgriffbahn, Gelenknachführung | 1,958333 s | 2,0 s |
| `kart_steer_right` | entgegengesetzte Lenkgriffbahn | 1,958333 s | 2,0 s |
| `kart_jump` | Abfedern/Oberkörperbewegung bei gehaltenen Griffen | 1,458333 s | 1,5 s |
| `celebrate` | beide Arme heben und zurückführen | 2,958333 s | 3,0 s |

Der erste exportierte Key liegt bei 1/24 s, nicht bei t = 0. Die Spanne zwischen erstem und letztem Key ist daher um 1/24 s kürzer als die von Godot gemessene Cliplänge. Die Lenkradkopplung normalisiert die aktive Phase als `clamp((Zeit - 1.0 / 24.0) / (Cliplänge - 1.0 / 24.0), 0.0, 1.0)`. Dadurch bleiben die tatsächlich exportierten Fahrerbewegungen und der Kartgriff synchron. Der Wert `duration_s` in den Blender-Messdateien bezeichnet diese aktive Key-Spanne.

Die Clips enthalten vollständig gekeyte Translation, Rotation und Skalierung aller Knochen. Die Armbewegungen verwenden analytische Zweiknochen-IK mit konstanten Segmentlängen. Die Godot-Lenkgriffbahn folgt der vorhandenen Lenkradmitte `(0, 1.035, -0.33)`, X-Neigung −0,45 rad und Lenkraddrehung ±0,40 rad.

**Godot muss konstante Rücksetzspuren erhalten.** Der tatsächliche Szenenimport verwendet den gemeinsamen Helper `tools/lumo_kart_art/asset_contract_loader.gd`. Der Parameter `remove_immutable_tracks` wird bei `GLTFDocument.generate_scene` auf `false` gesetzt. Sonst können beim Wechsel von `idle` nach `kart_seated` die konstanten Sitztranslationswerte verloren gehen. Negativer und positiver Nachweis sowie die konkrete Aufrufsignatur stehen in `docs/art/lumo_kart/GODOT_IMPORT.md`.

## Geometrie und Materialien

Die Hasenaugen sind geschlossene, flache Geometrieflächen, die der gekrümmten Schädeloberfläche folgen. Die anfänglichen herausstehenden weißen Augenplatten wurden verworfen. Die lächelnde Mundöffnung ist aus Wangen und Unterkiefer ausgeschnitten und besitzt einen zurückliegenden Innenraum, Zähne und Zunge. Diese Teile sind keine Textur auf einer flachen Figur.

Vor dem Export werden die Meshes trianguliert und flächenlose Kanten aus der Mundoperation bereinigt. Jede Detailstufe wird separat vermessen. Dreieckszahlen, Materialzahlen, nicht geschlossene Kanten und Hautgewichte werden aus dem erzeugten Mesh gelesen.

Sechs PBR-Oberflächen teilen sich eine farbige Vertexpalette:

| Oberfläche | Rauheit | Metallanteil | Verwendung |
|---|---:|---:|---|
| `Finish_Organic` | 0,79 | 0 | Fell, weiche Gesichtsflächen |
| `Finish_Fabric` | 0,71 | 0 | Rennanzug, Stoffdetails |
| `Finish_Rubber` | 0,91 | 0 | Sohlen, griffige Polster |
| `Finish_Metal` | 0,30 | 0,76 | Brillenrahmen, Schnallen |
| `Finish_Glass` | 0,17 | 0,35 | reflektierende farbige Brillengläser |
| `Finish_Face` | 0,30 | 0 | Augen, Nase und Schnabel |

Die Konturfarben bleiben durch Vertexfarben scharf. Zwei lokal berechnete periodische Micro-Normalmaps mit jeweils 512 × 512 Pixeln liefern Fell- und Stoffdetails. Sie sind in `.blend` und `.glb` eingebettet. Die UVs dienen diesen wiederholten Oberflächendetails, nicht einem externen Bildatlas. Es gibt keine fehlenden Texturdateien oder herunterzuladenden Materialreferenzen.

LOD1 und LOD2 reduzieren die ursprüngliche Geometrie auf ungefähr 57 % beziehungsweise 29 %. Alle drei Dateien behalten denselben Rig-, Marker- und Animationsvertrag. Die tatsächlich erzeugten Zahlen stehen pro Modell in `measurement.json`; eine Gerätebildrate wird daraus nicht abgeleitet.

## Reproduktion und Prüfung

```bash
blender -b -t 4 --python-exit-code 1 --python tools/lumo_kart_art/drivers/build_drivers.py -- --species rabbit --no-render
blender -b -t 4 --python-exit-code 1 --python tools/lumo_kart_art/drivers/check_driver_poses.py -- --species rabbit
blender -b -t 4 --python-exit-code 1 --python tools/lumo_kart_art/drivers/render_driver_reviews.py -- --species rabbit --mode stills
blender -b -t 4 --python-exit-code 1 --python tools/lumo_kart_art/drivers/render_driver_reviews.py -- --species rabbit --mode comparison
blender -b -t 4 --python-exit-code 1 --python tools/lumo_kart_art/drivers/render_roster.py
blender -b -t 4 --python-exit-code 1 --python tools/lumo_kart_art/drivers/render_roster.py -- --with-karts
python3 tools/lumo_kart_art/drivers/write_manifest.py
```

Die Poseprüfung wertet den deformierten Mesh in sechs Clips zu je fünf Zeitpunkten aus. Sie prüft räumliche Hüllen, Bodendurchdringung und tatsächliche Handknochenpositionen, außerdem degenerierte Dreiecke, Normalen und endliche UV-Koordinaten. Ein bestandener Blender-Test ersetzt keine Godot-Importprüfung; die gemeinsame Godot-Prüfung prüft zusätzlich reale `AnimationPlayer`-Übergänge und bewegte Kontakte.

Der gemeinsame Sitzgate prüft tatsächliche Dreiecksflächen in den vier Fahrclips `kart_seated`, `kart_steer_left`, `kart_steer_right` und `kart_jump` bei 0, 25, 50, 75 und 100 Prozent ihrer aktiven Key-Spanne. Die Viertelphasen erfassen auch die seitlichen Maxima der Schwanzbewegung. Die Anhangsprüfung umfasst fünf Fahrer und drei Karts; die getrennte Kleidungsprüfung untersucht die beiden nachweislich betroffenen Komponenten Anzug und Gürtel. Die Berichte unter `evidence/lumo_kart_art/karts/` dokumentieren die konkreten Dateihashes und Stichproben. Es handelt sich um ausgewertete Mesh-Zustände, nicht um einen mathematischen Nachweis für jeden kontinuierlichen Zwischenzeitpunkt.

Abschlussstand für die in `manifest.json` verzeichneten Hauptmodelle:

| Prüfung | Umfang | Ergebnis | Bericht unter `evidence/lumo_kart_art/karts/` |
|---|---:|---|---|
| Tieranhänge gegen Kartflächen, Fahrer und Karts direkt aus GLB | 300 Zustände | PASS, keine Dreiecksüberschneidung | `driver_appendage_clearance.json` |
| Unterer Anzug und Gürtel gegen harte Sitzschale | 300 Zustände, 600 Komponentenprüfungen | PASS, keine Dreiecksüberschneidung | `driver_torso_clearance.json` |
| Rabbit-Stiefel gegen Sitz, Pedale und Karosserie | 72 Fußzustände | PASS, keine Dreiecksüberschneidung | `rabbit_boot_clearance.json` |

Die beiden letzten Prüfungen verwenden die tatsächlichen Fahrer-GLBs und die unveränderten bearbeitbaren Kart-Meshes; die Berichte identifizieren zusätzlich die entsprechenden geprüften Kart-GLB-Exporte. Diese gezielten Nachweise betreffen die benannten Komponenten. Sie behaupten keine allgemeine Kollisionsfreiheit aller Körperflächen oder einen Test der weichen Sitzkompression.

Der finale Godot-4.6.3-Anschlusslauf prüft zusätzlich 720 tatsächliche Griff-/Fußkontakte an den fünf endgültigen Fahrer-GLBs: fünf Fahrer × drei Karts × vier Fahrclips × drei Phasen × vier Kontakte. Nach Berücksichtigung des realen Key-Startversatzes beträgt die größte gemessene Abweichung **0,721 mm** bei einer Prüfgrenze von 10 mm; der Lauf enthält keine Fehler. Quelle mit allen Eingabehashes: `evidence/lumo_kart_art/review/godot_driver_kart_fit.json`. Das ist ein tatsächlicher Godot-Skelett-/Markercheck; ein physischer Android-Gerätetest wird damit nicht behauptet.

Im Originalvergleich werden nur sichtbare Skin-Meshes berücksichtigt. Blenders unsichtbares Custom-Bone-Icosphere wird ausgeschlossen. Beide Figuren erhalten dieselbe Bodenhöhe und dieselbe gemessene Körperhöhe bis zur zentralen Schädelkrone; lange Ohren werden dabei nicht als Körperhöhe verwendet. Die Gleichheit wird nach Anwendung der Vergleichstransformation erneut am tatsächlich deformierten Mesh geprüft.

## Herkunft und Nutzungsangaben

Geometrie, Rig, sechs Animationsclips und die beiden Normalmaps wurden lokal durch die mitgelieferten Blender-Skripte für LUMO erstellt. Es wurden keine Nintendo-Assets, keine fremden Kart-/Charaktermodelle und keine neuen kostenpflichtigen Generierungen verwendet. Die Modelle orientieren sich an den bereits im Projekt vorhandenen Rivalenreferenzen unter `assets/characters/rivals/reference/`; deren unveränderte Originaldateien und Hashes sind im vorhandenen `reference-input-manifest.json` verzeichnet.

Für den unveränderten Original-LUMO im Vergleich gelten die vorhandenen Herkunfts- und CC-BY-4.0-Angaben in `assets/characters/lumo_animated/ATTRIBUTION.md`. Die Vergleichsbilder übernehmen diese Originalfigur, ersetzen sie jedoch nicht. Für die neuen prozeduralen Dateien wird durch dieses Paket keine zusätzliche externe Asset-Lizenz eingeführt. Die vorhandenen Referenzbilder erhalten hier keine erfundene neue Lizenzzuschreibung.
