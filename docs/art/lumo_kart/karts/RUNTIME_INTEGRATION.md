# Aurora-Karts im tatsächlichen Spiel

Comet, Glider und Aurora GT (`turbo`) werden im regulären `LumoRaceKart` aus den neun eingefrorenen Godot-Importen aufgebaut. Die Rennen, die Garagenauswahl und die Werkstatt benutzen dieselbe Fahrzeugklasse. Die übrigen elf Flottenmodelle behalten ihren bestehenden prozeduralen Aufbau; Fahrzeugwerte, Fahrphysik und Freischaltungen werden durch diesen Anschluss nicht verändert.

Diese Datei beschreibt den Runtime-Anschluss. Die ursprüngliche Asset-Übergabe, Blender-Dateien und Geometriebelege bleiben unter `docs/art/lumo_kart/karts/` und `evidence/lumo_kart_art/karts/` erhalten.

## Zuständigkeiten und Schnittstellen

| Datei | Aufgabe |
| --- | --- |
| `scripts/games/kart_production_vehicle.gd` | Importierte Kart-Szenen, Materialanpassungen, Rad- und Lenkwinkel, Detailwechsel |
| `scripts/games/kart_vehicle.gd` | Bestehende Fahrzeug-API, einziger Animationstakt, Effekte, Anbindung beider Fahrerpfade |
| `scripts/games/kart_garage_menu.gd` | Auswahl zeigt das tatsächliche Modell; volle Fahrzeugdetails; sitzende Rivalen werden bei der Kamerabegrenzung berücksichtigt |
| `scripts/games/kart_workshop.gd` | Tatsächliche Lackvorschau, volle Fahrzeugdetails und bestehender Original-Lumo-Adapter |
| `scripts/games/kart_production_lumo_seat.gd` | Sitzrahmen, unveränderte Original-Lumo-Proportionen, tatsächlicher Sohlenkontakt und freie Schwanzführung |
| `scripts/games/kart_production_driver.gd` | Separater Fahrer-Helper für Rabbit, Lion, Squirrel, Owl und Turtle; vom Fahrer-Agent implementiert und geprüft |

Die öffentlichen Aufrufe `configure`, `set_look`, `set_motion`, `set_braking`, `set_graphics_quality`, `set_driver_runtime_state` und `celebrate` bleiben nutzbar. `set_preview_detail(true)` hält ein Vorschaufahrzeug auf Kart-LOD0. Nur Comet, Glider und Turbo wählen den neuen Kart-Helper.

Die GLBs werden über `ResourceLoader` als regulär importierte `PackedScene` geladen. Es gibt keinen direkten GLB-Parser im Runtime-Pfad. Die importierten Demonstrations-`AnimationPlayer` werden beim Instanziieren entfernt, damit sie nicht gegen die Fahrzustände animieren. Die eigentlichen Modelle und Blender-Dateien werden nicht verändert.

## Mechanik und Koordinaten

Die importierte Identitätstransformation bleibt erhalten: Godot-Y ist oben und −Z ist die Fahrtrichtung. Die Radmittelpunkte liegen bei Y = 0,35 m und Z = ±0,66 m. Die halbe Spurweite beträgt 0,77 m, mit Faktor 0,91 beim Glider und 1,10 beim Turbo.

Der Fahrzeugtakt integriert die Radphase aus `speed * delta / 0.35`. Eine Vorwärtsfahrt dreht den importierten Rotor um seine negative lokale X-Achse; Rückwärtsfahrt kehrt die Drehung um. Die vorderen `Steer_*`-Knoten lenken um bis zu ±0,34 rad; die Hinterachse bleibt gerade. Das `SteeringWheel` dreht um seine lokale Z-Achse bis ±0,40 rad. Seine geneigte Ausgangsbasis bleibt erhalten.

Die vorhandenen Boost-, Drift- und Bremszustände steuern die Effekte an den realen Anschlussstellen. Bremsen erhöhen zusätzlich die Emission der importierten hinteren Linsen. Die zwei vorhandenen Bremslicht-Referenzen bleiben für den Spielcode erhalten.

LOD1 und LOD2 liefern ausschließlich andere Mesh-Blätter. Diese hängen unter derselben mechanischen Hierarchie wie LOD0. Radmittelpunkte, Lenkrad und Griffreferenzen werden beim Detailwechsel weder verschoben noch ersetzt. Auch in der Entfernung drehen und lenken die tatsächlichen Räder weiter.

## Detailstufen und Materialkosten

| Grafikprofil | Wechsel LOD0 → LOD1 | Wechsel zu LOD2 |
| --- | ---: | ---: |
| high | Entfernung > 16 m | Entfernung > 36 m |
| medium | Entfernung > 11 m | Entfernung > 27 m |
| low / light | Entfernung > 7 m | Entfernung > 18 m |

Die Rückschaltgrenze liegt jeweils 2 m näher an der Kamera. Die Garagen- und Werkstattvorschau verwendet Kart-LOD0. Fahrer-Qualität und Fahrer-LOD werden vom eigenen Helper gesteuert.

Pro Kart sind genau die Meshes einer Detailstufe sichtbar: Comet hat 38, Glider und Turbo je 39 Materialflächen. Der Flottentest misst mit dem tatsächlich sichtbaren Original-Lumo und ohne die gesonderten Effekte 39 beziehungsweise 40 Flächen. Das sind Strukturmessungen im Godot-Test, keine gemessenen Bildraten auf einem Android-Gerät.

Die eingefrorenen PBR-Materialien bleiben im Werkszustand erhalten. Lack-, Akzent-, Felgen- und Neonänderungen erzeugen Material-Overrides nur für die betreffende Fahrzeuginstanz. Alle drei LODs derselben Instanz teilen diese Overrides. Die Tests prüfen, dass ein getuntes Fahrzeug weder den Werkslack einer zweiten Instanz noch die importierten gemeinsamen Materialressourcen verändert.

## Fahrer und Spielzustände

Original-Lumo bleibt an seinem vorhandenen `lumo_kart_animation_adapter.gd` und unveränderten Modell. Der zusätzliche Sitz-Helper positioniert diesen Adapter um 0,14 m höher und 0,10 m nach vorne für die importierte Sitzschale. Die bestehende einheitliche Skalierung von 1,15, alle 65 Knochen, die Quelldateien und die Originalclips bleiben erhalten. Die Beine behalten ihre ursprünglichen Segmentlängen; ihre Gelenkwinkel werden auf die realen Pedale ausgerichtet. Zwei Schwanzgelenke führen den unveränderten Schwanz oberhalb und seitlich des Sitzrückens entlang. Die fünf neuen Rivalen benutzen den separaten Produktionsfahrer-Helper. Beide werden ausschließlich vom Fahrzeug getaktet, nachdem die tatsächliche Lenkraddrehung gesetzt wurde.

Pause friert den gemeinsamen Takt ein. Weniger Bewegung erhält die physikalische Radbewegung. Flug-, Treffer-, Boost-, Drift- und Zieleinlaufzustände werden an die jeweiligen bestehenden APIs weitergegeben. Die neuen Fahrer besitzen keinen erfundenen Treffer- oder Boost-Clip; ihre vorhandenen sechs Clips und die bisherigen Fahrzeugeffekte bestimmen das sichtbare Verhalten.

Der gemeinsame Test misst nach dem Lenken die tatsächlichen Hand-Bone-Positionen von Original-Lumo gegen die realen Griffpunkte. Dieser Test erhält die etablierte Handkontaktgrenze von 6 mm. Die zusätzliche dynamische Sitzprüfung misst über 54 Posen eine größte tatsächliche Handabweichung von 0,765 mm. Die fünf Rivalen bestehen zusätzlich die geprüften Lenk-, LOD-, Flug- und Zieleinlaufphasen unter der Grenze von 1 mm. Der ausführlichere Fahrer-Test gehört zum separaten Fahrerbeleg.

## Original-Lumo: Sitz- und Sohlenkorrektur

Die fortgesetzte Kontaktprüfung fand einen Fehler im begonnenen Sitzadapter: Eine erneute IK-Lösung auf der vorherigen Lösung akkumulierte axiale Beindrehung. Der 30-Hz-Originalclip setzte diese bei jedem zweiten 60-Hz-Fahrzeugtakt zurück. Dadurch änderte sich die gewichtet berechnete Fersenoberfläche trotz exakt positioniertem Fußknochen.

Jeder Beinschritt beginnt nun mit denselben ursprünglichen sitzenden Gelenkorientierungen. Ein beim Binden ermittelter schmaler Sohlenbereich korrigiert zusätzlich die kleinen Hautveränderungen beim animierten Zieleinlauf. Die vollständigen Meshes werden dafür nur beim Binden ausgewertet; der laufende Schritt benutzt wiederverwendete Knochenmatrizen und gespeicherte Kontaktpunkte.

`scripts/tests/kart_production_lumo_seat_regression.gd` prüft alle drei Karts bei Geradeausfahrt, Links-/Rechtslenkung, Sprung, Landung und Zieleinlauf zu jeweils drei Zeitpunkten. Die 225 Prüfungen bestehen. Die höchste gemessene Abweichung der tatsächlichen gewichteten Sohlenvertices vom vorgesehenen 3-mm-Abstand zur Pedaloberfläche beträgt 0,043 mm. Das ist eine geometrische Kontaktmessung, keine Bildratenmessung.

Anschließend liest `tools/lumo_kart_art/review/verify_original_lumo_seat.py` die tatsächlich von Godot ausgewerteten Hautdreiecke. Blender prüft diese unabhängig gegen die unveränderten Karosserie- und Sitzschalendreiecke. Alle 54 dynamischen Posen bestehen ohne überschneidende Schuh-/Karosserie- oder Bein-/Sitzflächen. Die Ergebnisse stehen in `original_lumo_seat_contacts.json` und `original_lumo_seat_clearance.json` unter `evidence/lumo_kart_runtime/karts/`.

```sh
env XDG_DATA_HOME=/tmp/lumo-kart-tests/seat \
  godot --headless --path . \
  --script scripts/tests/kart_production_lumo_seat_regression.gd
blender -b -t 1 --python-exit-code 1 \
  --python tools/lumo_kart_art/review/verify_original_lumo_seat.py
```

## Original-Lumo: Schwanz und Sitzrücken

Die ergänzende Seitenansicht und die anschließende Dreiecksprüfung zeigten, dass der originale Schwanz die importierten Sitzflächen durchdrang. Die Korrektur dreht ausschließlich `TailBase` und `Tail1`; Modell, Hautgewichte, Knochenlängen, Originalclips und Karosserie bleiben unverändert. Im Kartkoordinatensystem erhält `TailBase` −50° Pitch, `Tail1` −70° Pitch und +20° Yaw. Die Rotation wird als `UP-Yaw * RIGHT-Pitch` mit Quaternionen auf die jeweilige aktuelle Cliporientierung angewendet. Die seitliche Komponente hält den Schwanz auch im echten Sprungclip vom Oberkörper frei.

Vor jeder neuen Clipauswertung entfernt der Fahrzeugtakt nur die zuletzt selbst aufgebrachte Korrektur. Hat eine externe Clipänderung den betreffenden Knochen bereits ersetzt, bleibt diese erhalten. Nach der Originalanimation wird die Korrektur genau einmal wieder aufgebracht. Damit akkumuliert sie nicht zwischen dem 60-Hz-Fahrzeugtakt und der 30-Hz-Auswertung der Originalanimation.

Die versionierte Prüfung `kart_production_lumo_tail_regression.gd` erfasst 72 tatsächliche Posen aus allen drei Karts, sechs Fahrzuständen und den Frames 12, 13, 42 und 90 bei 60 Hz. Sie prüft außerdem, dass Entfernen und Wiederaufbringen der Korrektur dieselbe Gelenkorientierung herstellen. Alle 148 Prüfungen bestehen. Jeder Capture enthält die tatsächlich aktive Originalanimation und ihre Zeit sowie dieselbe Körperpose mit unverändertem Schwanz als Vergleich.

`verify_original_lumo_tail.py` prüft unabhängig 2.402 Schwanzdreiecke gegen die vollständige Karosserie und 1.823 freie Schwanzdreiecke gegen 31.205 Körperdreiecke. Alle 290 Prüfungen über 72 Posen bestehen: keine Schwanz-/Karosseriedurchdringung, kein freier Schwanz-/Körperkontakt und kein Ansatzkontakt außerhalb der ursprünglichen anatomischen Hautregion. Die bereits im Original vorhandenen Überschneidungen am Schwanzansatz werden nach tatsächlichen Knochengewichten separat dokumentiert; der Bericht behauptet dort keine vollständige Kontaktfreiheit. Die Grenze der unveränderten Ansatzregion wird für jede Vergleichspose neu berechnet, mit lediglich 1 µm numerischer Toleranz.

Die endgültige Korrektur besteht zusätzlich erneut die oben beschriebenen 225 Bein-/Sohlenprüfungen und alle 54 unabhängigen Sitz-BVH-Posen. Die Schwanzberichte stehen als `original_lumo_tail_contacts.json` und `original_lumo_tail_surfaces.json` unter `evidence/lumo_kart_runtime/karts/`.

```sh
env XDG_DATA_HOME=/tmp/lumo-kart-tests/tail \
  godot --headless --path . \
  --script scripts/tests/kart_production_lumo_tail_regression.gd
blender -b -t 1 --python-exit-code 1 \
  --python tools/lumo_kart_art/review/verify_original_lumo_tail.py
```

## Gezielte Prüfung

`evidence/lumo_kart_runtime/karts/runtime_contract.json` protokolliert 492 erfolgreiche Assertions aus `scripts/tests/kart_production_vehicle_regression.gd` mit Godot 4.6.3. Er prüft alle drei importierten Fahrzeuge, ihre neun LOD-Ressourcen, die echte Mechanik, Rückwärtsfahrt, Pause, Materialisolation, Original-Lumo, fünf Rivalen und die tatsächlichen Garagen-/Werkstattknöpfe. Eine Lackvorschau wird über den echten Farbfeld-Knopf ausgelöst; der Kaufzustand bleibt dabei unverändert.

Die betroffenen bestehenden Tests `kart_vehicle_detail_regression.gd`, `kart_fleet_regression.gd` und `kart_cinema_kart_regression.gd` bestehen ebenfalls. Sie unterscheiden die importierten Modelle von den verbleibenden prozeduralen Familien und zählen für das Flottenbudget nur die tatsächlich sichtbaren Meshes. Der Detailtest behält einen ausdrücklich isolierten Test des weiter vorhandenen prozeduralen Generators.

`kart_brake_reverse_feedback_regression.gd` bestätigt zusätzlich den echten Auto-Gas-/Rückwärtsweg, die GAS-Sperre gegen versehentliches Rückwärtsfahren und beide sichtbaren Bremslichter. Sein Testabschluss wartet auf die Freigabe der gestoppten Musik-Streams. Die im aktuellen Prüfindex erfassten abschließenden Logs sind frei von Warnungen und Fehlern. `evidence/lumo_kart_runtime/karts/runtime_gate_index.json` verknüpft die Logs mit den geprüften Testskripten, den Kart-Anschlussquellen und den SHA-256-Werten aller neun unveränderten Kart-GLBs.

Beispiel für einen reproduzierbaren Lauf mit eigenen Test-Nutzerdaten:

```sh
env XDG_DATA_HOME=/tmp/lumo-kart-tests/production \
  /usr/local/bin/godot --headless --path . \
  --script scripts/tests/kart_production_vehicle_regression.gd
```

Diese Kart-Prüfungen belegen den tatsächlichen Godot-Anschluss. APK-Export, native Gesamtansicht und die Prüfung auf einem physischen Fold7 gehören zum gemeinsamen Release-Nachweis. Aus einem bestandenen Headless-Test wird keine Gerätebildrate abgeleitet.
