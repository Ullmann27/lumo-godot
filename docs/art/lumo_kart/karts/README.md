# LUMO Aurora – bearbeitbare Kart-Modelle

## Gelieferte Modelle

Die drei Modelle sind eigenständige Blender-Geometrie mit Godot-Exporten, keine Konzeptbilder. Sie übernehmen die mechanischen Bezugspunkte aus `scripts/games/kart_vehicle.gd` und die Spurbreiten aus `scripts/games/kart_fleet.gd` des geprüften Ausgangsstands `9f8341494ea316c9e36ed6722915ab34b22e67bd`.

| Modell | Gestaltung | Radmitten X | Editierbare Quelle | Godot-Datei |
|---|---|---:|---|---|
| Comet | Marineblauer Lack, satinierte Goldakzente, kompakte Heckeinheit | ±0,7700 m | `art/lumo_kart/blender/karts/aurora_comet.blend` | `assets/kart/production/karts/aurora_comet.glb` |
| Glider | Perlweiß/Türkis, schmale Seitenkästen, breiter Aero-Flügel | ±0,7007 m | `art/lumo_kart/blender/karts/aurora_glider.blend` | `assets/kart/production/karts/aurora_glider.glb` |
| Aurora GT (`turbo`) | Violett/Gold, breitere Spur, eigener Heckflügel | ±0,8470 m | `art/lumo_kart/blender/karts/aurora_turbo.blend` | `assets/kart/production/karts/aurora_turbo.glb` |

Jedes Modell besitzt zusätzlich `_lod1.glb` und `_lod2.glb` mit identischen Knoten-, Marker- und Animationsverträgen. Die Originaldateien enthalten getrennte Karosserieflächen, Radteile, Felgen, Naben, Pedale, Sitzpolster, Beleuchtung, Stoßfänger und Federungsdetails. Der Export fasst statische Teile je Baugruppe zusammen.

Lack, Gummi, Metall, Sitzpolster und Linsen nutzen getrennte Standard-PBR-Materialien. Die Reifen besitzen tatsächlich modellierte Seitenwände, Laufflächenrillen und diagonale Einschnitte. Das geschlossene Lenkrad besteht aus einem durchgängigen Ring. Es gibt keine externen Bildtexturen; sämtliche Farbflächen bleiben durch die Materialien unabhängig von einer Bitmap-Auflösung scharf. Alle Oberflächen besitzen nutzbare UVs einschließlich Kappen und Fasen.

## Maßstab und Achsen

Eine Einheit entspricht einem Meter. Blender verwendet `+Z` oben und `+Y` vorwärts. Der Standard-GLB-Export liefert Godot `+Y` oben und `-Z` vorwärts. Die Umrechnung lautet `(Godot x,y,z) → (Blender x,-z,y)`.

| Bezugspunkt | Godot-Position / Eigenschaft |
|---|---|
| Ursprung | `(0,0,0)` auf der Fahrbahnebene unter der Fahrzeugmitte |
| Vorderradachsen | `Y=0.35`, `Z=-0.66`; X gemäß Modellspalte oben |
| Hinterradachsen | `Y=0.35`, `Z=+0.66`; X gemäß Modellspalte oben |
| Reifen | Rollradius `0.35 m`, Breite `0.38 m` |
| Radstand | `1.32 m` |
| `DriverOrigin` | `(0,0,0)` – Referenz für Fahrer, deren Sitzpose in Fahrzeugkoordinaten erzeugt wurde |
| `DriverSeat` | `(0,0.69,0.07)` – feste Sitzreferenz des Bestands innerhalb des Kissens, **kein** Ersatz für den Ursprung eines bereits sitzenden Rigs |
| `SteeringWheel` | `(0,1.035,-0.33)`, Grundneigung `X=-0.45 rad` |
| `Grip_L`, `Grip_R` | Welt-Restposition `(±0.16,1.055,-0.34)`; Kinder von `SteeringWheel` |
| `Foot_L`, `Foot_R` | `(±0.18,0.80,-0.24)` – Stiefelmitten |
| Pedal-Oberkante | `Y=0.7115 m`, Gripleisten bis `Y=0.7175 m` |
| Stiefelsohle | Unterkante mindestens `Y=0.720 m`; der Schuhkörper darf nicht darunter hervorragen |
| `Boost_L`, `Boost_R` | `(±0.12,0.467,1.13)` |

Die Front der Original-Stiefel liegt ungefähr bei `Z=-0.38`. Ein größerer Schuh, der bis `Z=-0.42` reicht, muss individuell gegen die ansteigende Haube geprüft werden. Die Füße dürfen nicht lediglich auf den niedriger liegenden Fußknochen eines stehenden Rigs gesetzt werden.

Das neu geformte Sitzkissen endet vorne bei `Z=-0.08`, hinter den geprüften Stiefelfersen. Sein Volumenmittelpunkt liegt bei `(0,0.69,0.12)` und seine Halbachsen sind `(0.29,0.09,0.20)`. Der vorhandene Sitzmarker bleibt unverändert. Diese lokale Formkorrektur entstand aus dem tatsächlichen gemeinsamen Fahrer/Kart-Meshtest.

## Mechanische und Animationsschnittstelle

Die GLB-Wurzel heißt `Aurora_comet`, `Aurora_glider` beziehungsweise `Aurora_turbo`. Jeder Export enthält:

- `Steer_FL`, `Steer_FR`, `Steer_RL`, `Steer_RR`: feste Achspositionen; die vorderen Lenkhalter drehen um Godot `+Y`, maximal `±0.34 rad`.
- `Wheel_FL`, `Wheel_FR`, `Wheel_RL`, `Wheel_RR`: Kinder der jeweiligen Lenkhalter; Rollbewegung um ihre lokale Godot-X-Achse.
- `SteeringWheel`: Lenkrad mit seinen beiden Griffmarkern. Die Grundneigung bleibt erhalten; Lenkauslenkung erfolgt um seine lokale Z-Achse.
- `mechanical_demo`: ein tatsächlicher zweisekündiger Animationsclip mit sieben veränderlichen Rotationskanälen: vier Räder, zwei vordere Lenkhalter und das Lenkrad. Derselbe Clip liegt in den bearbeitbaren Blender-Dateien als Keyframes vor.

Für die Prüfung kann Godot den Clip direkt abspielen. Bei einem späteren Anschluss an die tatsächliche Fahrphysik muss das Hauptteam die Demonstrationsanimation stoppen und die genannten Knoten aus dem vorhandenen Fahrzustand setzen. Animation und Spielsteuerung dürfen nicht gleichzeitig dieselben Rotationen schreiben. Die mitbewegten Griffmarker können die vorhandenen Hand-Constraints versorgen.

Diese Lieferung verändert weder `kart_vehicle.gd` noch Fahrphysik, Auswahlmenü, Gegnerzuordnung oder Kollisionsregeln. Die gemeinsame Review-Szene des Hauptteams zeigt den Import. Ein vollständiger Anschluss in einer ausgelieferten Android-APK ist daraus nicht abzuleiten.

## Gemessene Prüfungen

Die konkreten Dreieckszahlen, Materialzahlen, Dimensionen, Dateihashes, UV-Prüfungen und Animationskanäle stehen in `evidence/lumo_kart_art/karts/export_validation.json`. Die ungerundeten Blender-Messungen liegen für jedes Modell in `mesh_report.json`, `lod1_report.json` und `lod2_report.json`.

`mechanical_clearance.json` dokumentiert die BVH-Prüfung der tatsächlich ausgewerteten Dreiecke: sieben Lenkwinkel für jedes Vorderrad sowie die beiden Hinterräder. Sie prüft Reifen gegen die Karosserie; konstruktive Verbindungen zu Naben, Achsen und Bremsteilen werden dabei bewusst getrennt behandelt. Alle drei Varianten durchlaufen diese Prüfung. Beim Glider deckte sie einen Kontakt mit den ursprünglichen Seitenkästen auf; deren Querschnitt wurde schmaler geformt, ohne die vorgegebene Spur zu verändern.

`rabbit_boot_clearance.json` enthält zusätzlich **72 bestandene gemeinsame Fahrer/Kart-Fälle**: drei Karts, vier Clips (`kart_seated`, `kart_steer_left`, `kart_steer_right`, `kart_jump`), jeweils Anfang/Mitte/Ende und beide Füße. Der tatsächlich importierte Rabbit-GLB besitzt SHA256 `3f21d290e77fee2e7d0ac66f1f8af0195759628895a2a3d391a1db2b419a13e3`. Die starr auf `Foot.L`/`Foot.R` gewichteten Schuhdreiecke berühren keine Karosseriedreiecke. Zuvor entdeckte Kontakte mit Pedalleisten und Sitzkissen wurden durch die angepasste Schuhunterseite und die kompaktere Kissenfront behoben. Diese Prüfung bezieht sich ausdrücklich auf die Füße und ersetzt nicht die getrennte Prüfung des restlichen Rigs.

`driver_appendage_clearance.json` enthält **300 bestandene Anhangprüfungen**: fünf tatsächliche Fahrer-GLBs gegen die drei tatsächlichen Kart-GLBs, vier Fahrclips und fünf Phasen (0/25/50/75/100 Prozent). Die Viertelphasen erfassen auch die seitlichen Extremwerte der Schwanzbewegung. Die vollständigen Tail-gewichteten Flächen beziehungsweise die zusammenhängenden Schildkrötenpanzerteile schneiden keine Karosseriedreiecke. Die Dateihashes im Bericht stimmen mit den eingefrorenen finalen Exporten überein. Die anfänglichen Sitzüberschneidungen wurden lokal an den Fahreranhängen korrigiert; der untere Schildkrötenpanzer wurde zusätzlich für die seitliche Körperbewegung im schmalen Glider eingezogen.

`driver_torso_clearance.json` enthält **300 bestandene Körper-/Kartfälle mit 600 einzelnen Komponentenprüfungen**. Geprüft werden ausschließlich die zwei tatsächlich auffällig gewordenen Kleidungsflächen `TailoredRacingSuit` und `Belt`: fünf importierte Fahrer-GLBs, drei Blender-Kartquellen, vier Fahrclips und dieselben fünf Phasen, jeweils gegen `BucketSeatShell`. Die hintere Tiefe dieser beiden Kleidungsflächen wurde an die gemessene Schalenkontur angepasst; Frontflächen, Ringhöhen/-breiten und Knochenpositionen bleiben erhalten. Der Bericht identifiziert die geprüften Fahrer-GLBs, die verwendeten Kartquellen und ihre separat validierten GLB-Exporte mit SHA256. Dies ist eine gezielte Prüfung der harten Sitzschale und keine pauschale Behauptung vollständiger Körperfreiheit gegenüber jedem weichen Polster.

Die früheren negativen Befunde bleiben mit ihren damaligen Dateihashes in `driver_appendage_initial_findings.json`, `driver_appendage_motion_findings.json` und `driver_torso_initial_findings.json` erhalten. Für den endgültigen Stand gelten die drei positiven Berichte `rabbit_boot_clearance.json`, `driver_appendage_clearance.json` und `driver_torso_clearance.json`. Die Phasenprüfungen sind diskrete Messungen; die visuelle Bewegungsprüfung ergänzt das Hauptteam in Godot.

Das Export-Gate verlangt für alle neun GLBs:

- keine geometrisch flächenlosen Dreiecke;
- keine Dreiecke mit flächenlosen UVs;
- keine nicht-manifold Kanten in den gemessenen Autoren-Meshes;
- gültige endliche Attribute, Materialien und Normalen;
- identische mechanische Marker über alle drei LODs;
- den echten Clip `mechanical_demo` mit sieben bewegten Kanälen und zwei Sekunden Dauer;
- maximal 50.000 / 25.000 / 17.000 Dreiecke für LOD0 / LOD1 / LOD2.

Diese Werte sind Asset-Budgets. Sie belegen keine Bildrate auf einem Android-Gerät. Die finale LOD-Umschaltung, Material-Batching über mehrere Rennfahrer und die GPU-Zeit müssen im tatsächlichen Rennen auf dem Fold7 profiliert werden.

## Renderbilder und Kameras

Die sechs überprüfbaren Blender-Stills liegen unter `evidence/lumo_kart_art/karts/<modell>/`. Für jedes Modell liegen Vorder- und Rückansicht aus der finalen Quelle mit 1440 × 1080 Pixeln und 32 Cycles-Samples vor. `final_render_index.json` dokumentiert die nachgeprüften Bild- und Quellhashes. `render_views.py` liest die gespeicherte Blender-Datei erneut ein; zusätzlich sind Seiten-, Unter-, Rennkamera- und Lenkansichten damit reproduzierbar. Zu jedem so erstellten Bild gehört eine `.camera.json` mit Quelle, Auflösung, Samples und tatsächlicher Kameraposition.

Der optionale Modus `chase_camera` übernimmt aus `scripts/games/kart_visual_grade.gd` die stehende Rennkamera: Abstand `4.35 m`, Höhe `2.52 m`, Blickpunkt `(0,0.78,-4.15)` und vertikales Sichtfeld `55°` im Format 16:9. Die Kamera wird dabei nicht näher an das Modell geschoben. Die zusätzliche Ansichtenprüfung und der Bewegungsnachweis erfolgen in der Godot-Review des Hauptteams. Alle hier gelieferten Blender-Bilder entstehen mit Cycles und AgX; es werden keine KI-Konzeptbilder als Renderbelege verwendet.

Der lokale Blender-Build unterstützt kein OpenImageDenoise. Die Stills werden daher ohne diese Option gerechnet. Die gemeinsame Godot-Review des Hauptteams übernimmt den tatsächlichen schnelleren Bewegungsnachweis. Die optionale `--clip`-Funktion des Generators bleibt für eine vollständige Blender-Kamerafahrt reproduzierbar, erzeugt jedoch keine Behauptung, dass ein Clip bereits berechnet wurde.

## Reproduzierbare Werkzeuge

Aus dem Repository-Wurzelordner:

```sh
blender -b -t 3 --python-exit-code 1 --python tools/lumo_kart_art/karts/build_karts.py -- --variant comet --renders none
blender -b -t 1 --python-exit-code 1 --python tools/lumo_kart_art/karts/inspect_mechanics.py -- comet
blender -b -t 3 --python-exit-code 1 --python tools/lumo_kart_art/karts/render_views.py -- --variant comet --views front_three_quarter,rear_three_quarter,side_profile,underside,chase_camera,steering_clearance --samples 32
python tools/lumo_kart_art/karts/verify_kart_exports.py
blender -b -t 1 --python-exit-code 1 --python tools/lumo_kart_art/karts/inspect_driver_fit.py -- assets/kart/production/drivers/rabbit/driver.glb
blender -b -t 1 --python-exit-code 1 --python tools/lumo_kart_art/karts/inspect_driver_appendages.py -- --source-format glb --kart-format glb
blender -b -t 1 --python-exit-code 1 --python tools/lumo_kart_art/karts/inspect_torso_motion.py
```

Die ersten beiden Befehle entsprechend mit `glider` und `turbo` wiederholen. `verify_kart_exports.py` prüft alle neun Kart-GLBs einschließlich ihrer LODs. `inspect_driver_fit.py` prüft die Füße des angegebenen GLB-Fahrers gegen die drei vollständigen Blender-Kartquellen. `inspect_driver_appendages.py` prüft die Schwänze beziehungsweise den Schildkrötenpanzer der fünf Arten; die oben genannten Formatoptionen importieren dabei sowohl die Fahrer als auch die Kart-LOD0-Modelle aus den tatsächlichen GLBs. `inspect_torso_motion.py` prüft die zwei genannten Kleidungsflächen der fünf Fahrer-GLBs gegen die drei harten Sitzschalen. `--python-exit-code 1` ist absichtlich angegeben: Blender kann Python-Exceptions ohne diese Option trotz gescheiterter Verarbeitung mit Prozesscode 0 beenden.

## Herkunft und Rechtehinweis

Geometrie, Materialien, Generatoren und Keyframes wurden als Originalarbeiten für LUMO erstellt. Vorhandene LUMO-Farben, Bezeichnungen und mechanische Abmessungen bilden die Projektbasis. Es wurden keine Nintendo-Modelle, fremden Fahrzeugdateien, Stock-Texturen oder kostenpflichtig generierten Assets verwendet. Der untersuchte Checkout enthält keine eigenständige `LICENSE`-Datei; diese Lieferung erklärt keine neue Open-Source-Lizenz und fügt keine Lizenz eines externen Asset-Anbieters hinzu.
