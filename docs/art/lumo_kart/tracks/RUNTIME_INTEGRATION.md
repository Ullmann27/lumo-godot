# Blender-Tunnel in den tatsächlichen Rennstrecken

Stand: 15. November 2026. Diese Anschlussstufe folgt auf die eingefrorene Blender-Lieferung. Der Bericht `production_summary.json` bleibt der historische Abschluss der Asset-Produktion; die tatsächliche Spielanbindung ist separat unter `evidence/lumo_kart_art/tracks/runtime/` belegt.

## Ergebnis und Zuständigkeit

Jede der elf Strecken außerhalb von Sonnenhafen erhält einen geschlossenen, 44 m langen Blender-Tunnel auf der vorhandenen Fahrbahn. Ein Abschnitt besteht aus einem 4-m-Eingang, drei 12-m-Innenmodulen und einem 4-m-Ausgang. Sichtbare Innenhülle, Landschaftsdecke, physische Hülle, Eingang, Ausgang und Lichtbefestigungen folgen derselben vorhandenen Straßenkurve.

Die Strecke und ihre Kontrollpunkte bleiben geometrisch unverändert. Die bestehende Fahrbahn bleibt die sichtbare Fahrfläche und dieselbe Quelle für das manuelle Fahrzeugmodell. Sonnenhafen erhält keinen Produktions-Tunnel. Original-LUMO und Lernmodule werden von diesen Dateien nicht angesprochen.

Diese Implementierung umfasst `kart_world.gd` und drei neue Tunnel-Helper. Der übergeordnete Integrationsschritt ruft die öffentlichen Bewegungs- und Kameraabfragen in `kart_island.gd` auf. APK-Export, Signatur, Geräteprüfung und die eigenständige Prüfung der tatsächlichen Insel-Fahrschritte liegen außerhalb dieses Tunnel-Berichts.

## Tatsächlich gewählte Abschnitte

Die Distanzen sind Meter entlang der vorhandenen gebackenen Rennkurve. Der Planer berücksichtigt Sprunglücken, Landewege, Loopings, Schanzen, Wasserabschnitte, offene Kanten, Slalomtore, Start/Ziel, Steigung, Krümmung und benachbarte Fahrbahnen. Die aktuellen Routen liefern folgende Abschnitte:

| Thema | Eingang | Ausgang | Module | Mobile sichtbare Dreiecke einschließlich Decke |
|---|---:|---:|---:|---:|
| Zauberwald | 247 | 291 | 5 | 37.628 |
| Bergwelt | 151 | 195 | 5 | 33.036 |
| Holo City | 243 | 287 | 5 | 36.712 |
| Crystal Canyon | 159 | 203 | 5 | 32.976 |
| Jungle Temple | 367 | 411 | 5 | 34.736 |
| Candy Cloud | 427 | 471 | 5 | 28.344 |
| Volcano Night | 423 | 467 | 5 | 34.144 |
| Winter Sprint | 419 | 463 | 5 | 28.784 |
| Galaxy Ringway | 363 | 407 | 5 | 47.752 |
| Desert Drift | 419 | 463 | 5 | 33.248 |
| Learning Lab | 383 | 427 | 5 | 39.192 |

Die bestehenden Sprung- und Slalomabschnitte belegen die frühere Höhleninsel in Bergwelt. Der neue Tunnel liegt deshalb vollständig auf der zweiten vorhandenen Insel, mit mindestens 2 m verbleibendem geologischem Anschluss an ihren gepolsterten Enden. Der Sprung und die vier Slalomtore werden nicht verschoben.

Die Obergrenzen im Planer betragen 0,045 rad Richtungsänderung pro Meter und 0,25 für den Betrag der vertikalen Komponente des normierten Fahrtrichtungsvektors. Andere, nicht benachbarte Fahrbahnabschnitte müssen horizontal mindestens 27 m entfernt sein, sofern sie auf ähnlicher Höhe liegen. Die derzeit ausgewählten Abschnitte liegen jeweils mehr als 41 m von solchen Fahrbahnabschnitten entfernt.

## Verbindung mit Fahrbahn und Gelände

`kart_production_tunnel_mesh.gd` liest die importierten Szenen und erstellt einmalig beim Streckenaufbau eigene ArrayMeshes. Die lokale Godot-Längskoordinate `-Z` wird auf die tatsächliche Straßendistanz abgebildet. Seitliche und vertikale Koordinaten werden über den vorhandenen Bankwinkel und Straßenrahmen abgetragen. Eine gemeinsame Tabelle mit 0,25-m-Schritten liefert beiden Seiten jedes Modulstoßes denselben Rahmen.

Die Deformation berücksichtigt auch Normalen und Tangenten. Normalen werden mit der invers transponierten lokalen Ableitung der Verformung transformiert. Die Quelldateien und importierten Quellmeshes werden dabei nicht verändert.

Normale Landstrecken erhalten zusätzlich beidseitige, geneigte Geländeanschlüsse. Im Zauberwald endet deren äußerer Rand auf der vorhandenen lokalen Geländehöhe; auf den betreffenden Erweiterungsstrecken auf deren Bodenhöhe. Die geschlossenen Decken von Bergwelt, Holo City, Candy Cloud und Galaxy Ringway behalten ihre sichtbare Unterseite auf den vorhandenen schwebenden Inseln beziehungsweise erhöhten Strecken. Die Fahröffnung bleibt frei.

Die früheren prozeduralen Baum-, Schnee- und Holo-Tunnel werden nur dann übersprungen, wenn der neue Tunnel erfolgreich aufgebaut wurde. Ein fehlender Import erzeugt einen Fehler und lässt den bisherigen Aufbau weiterhin zu; die Regression erwartet ausdrücklich einen erfolgreichen Blender-Einbau auf allen elf Themen.

## Reale Kollisionswirkung

Die separate, hohle Blender-Kollisionshülle wird mit genau derselben Abbildung auf die Fahrbahn verformt. Jedes der fünf Module erhält einen statischen konkaven Körper. Insgesamt entstehen pro Strecke 1.368 Kollisionsdreiecke auf dem ausschließlich dafür verwendeten Layer `1 << 20`.

Die Spielfahrzeuge integrieren ihre Position selbst. Der Anschluss erfolgt daher durch explizite Physikabfragen:

- `world.resolve_tunnel_motion(previous_position, desired_position)` liefert `position`, `normal` und `collided`. Die Abfrage verwendet eine aufrechte Kapsel mit 0,85 m Radius und 2,0 m Gesamthöhe. Der Eingabeursprung ist der Fuß-/Fahrbahnkontaktpunkt des Karts; der Kapselmittelpunkt liegt 1,0 m darüber. Die Abfrage arbeitet im lokalen Koordinatensystem der Rennwelt und überträgt Position und Normale korrekt in den Physikraum.
- Zwei aufeinanderfolgende Sweeps erhalten verbleibende Bewegung entlang der Kontaktfläche. Eine 15-mm-Kontaktmarge und ein zusätzlicher kleiner Rückversatz verhindern eine Platzierung direkt in der Oberfläche.
- Die Inselanbindung muss die korrigierte Position übernehmen und die Geschwindigkeit an der gemeldeten Normale gleiten lassen. Bei einem Dachkontakt während eines Sprungs muss sie die positive vertikale Geschwindigkeit beenden. Der übergeordnete Integrationsschritt hat diese Aufrufe vor beziehungsweise nach horizontaler und vertikaler Bewegung und während der Zielfahrt eingebunden.
- `world.clip_tunnel_camera(anchor, desired)` prüft eine Kugel mit 0,20 m Radius. Die Kameraabfrage erfolgt nach dem Lerp beziehungsweise nach der Berechnung des Zielabstands.

Diese Kapsel ist ein rotationsunabhängiger Fahrzeugkörper für die manuelle Fahrphysik. Sie bildet keine detaillierte Rad- oder Karosseriekollision ab.

## Licht, Detailstufen und Ressourcen

Die importierten LightSocket-Knoten werden anhand ihres Namens oder ihrer semantischen Metadaten erkannt. Ihre verformten Positionen steuern einen begrenzten Pool von drei unverschatteten Omni-Lichtern auf der mobilen Stufe beziehungsweise vier in der vollständigen Stufe. Die nächste Auswahl erfolgt alle 0,12 Sekunden anhand der tatsächlichen Kamera. Die Lichtfarbe kommt aus den Socket-Metadaten.

Die native Rennansicht zeigte zunächst zu dunkle Basaltwände in Volcano Night. Ausschließlich dieses Thema verwendet deshalb eine lokal angepasste Füllbeleuchtung: Energie 4,8, Reichweite 15 m, Dämpfung 0,60 und die Socket-Farbe mit 65 Prozent Warmweiß gemischt, tatsächlich #f9c896. Die Lichterzahl bleibt unverändert. Alle anderen Themen behalten Energie 1,6, Reichweite 11 m, Dämpfung 0,80 und ihre ursprüngliche Socket-Farbe. Ein gezielter Laufzeitvergleich und zwei neue native Rennbilder bestätigen die Korrektur; Einzelheiten stehen in `RUNTIME_VISUAL_QA.md`.

Die mobile Stufe lädt ausschließlich die gelieferten LOD1-Innenhüllen und LOD1-Decken. Die vollständige Stufe lädt beide Detailstufen und schaltet bei 65 m um. LOD1 wird auf der mobilen Stufe bis 170 m und auf der vollständigen Stufe bis 225 m angezeigt. Die Geometrie wird beim Aufbau verformt und danach nicht pro Bild neu berechnet.

Materialien werden anhand ihrer Namen innerhalb einer Tunnelwelt geteilt. Wiederholte gerade Stücke und passende Detailstufen verwenden dieselben Material- und Texturreferenzen. Der vorübergehende Szenencache wird nach dem Aufbau freigegeben. Eigene Vertexdaten je gekrümmtem Modul sind erforderlich, weil sich seine tatsächliche Straßenform unterscheidet.

Der Runtimebedarf ist exakt:

| Modulname je Thema | Erforderliche Dateien |
|---|---|
| `portal_entry` | `.glb`, `_lod1.glb`, `_collision.glb`, `_terrain.glb`, `_terrain_lod1.glb` |
| `straight_12m` | dieselben fünf Varianten |
| `portal_exit` | dieselben fünf Varianten |

Das sind 15 GLBs je Thema beziehungsweise 165 GLBs mit zusammen 114.710.136 Quellbytes. Die übrigen 220 Kurven- und Steigungsdateien bleiben Teil der Autorenlieferung. Ihr Ausschluss aus der APK wird durch den übergeordneten Exportfilter vorgenommen. `runtime_summary.json` enthält alle 165 konkreten Pfade und SHA-256-Hashes.

## Ausgeführte Prüfungen

Alle folgenden Läufe wurden im tatsächlichen importierten Hauptprojekt mit Godot 4.6.3 ausgeführt:

| Nachweis | Ergebnis |
|---|---|
| Layout auf allen elf Originalrouten | 11/11 erfolgreich |
| Tatsächlicher World-Aufbau auf mobiler und vollständiger Stufe | 22/22 erfolgreich |
| Freie Kapselbewegungen in drei Fahrspuren | 1.980/1.980 |
| Freie Fahrspur-/Kamerastrahlen | 1.980/1.980 |
| Echte Seitenwand-, Dach- und Gleitkontakte | 88/88 |
| Kamerakugel gegen Wand und freie normale Verfolgerposition | 22/22 Welten |
| Aktivierung des begrenzten LightSocket-Pools | 22/22 Welten |
| Querschnitte durch tatsächlich sichtbare verformte LOD0-/LOD1-Innenhüllen und Decken | 1.958/1.958 frei |
| Maximale Abweichung zwischen Straßensocket und Modulsocket | 0,000000954 m |
| Maximale gemessene Lücke zwischen aufeinanderfolgenden Sockets | 0,000000954 m |
| Eingefrorene Autorenquellen und GLBs gegenüber dem Produktionsabschluss | 396/396 bytegleich |

Die zusätzliche sichtbare Geometrieprüfung baut ausschließlich für den Test einen Körper aus den tatsächlichen Renderdreiecken. Sie prüft alle 0,5 m einen 11,8 m breiten Querschnitt von 0,15 m bis 4,5 m über dem gebankten Straßenrahmen. Dieser Nachweis ist unabhängig von den vereinfachten Spiel-Kollisionshüllen und prüft beide sichtbaren Detailstufen.

Die JSON-Berichte enthalten Messwerte und Kontaktvektoren:

- `evidence/lumo_kart_art/tracks/runtime/physics_all_mobile.json`
- `evidence/lumo_kart_art/tracks/runtime/physics_all_full.json`
- `evidence/lumo_kart_art/tracks/runtime/visible_clearance_all.json`
- `evidence/lumo_kart_art/tracks/runtime/runtime_summary.json`

Ergänzend wurden alle 22 nativen Rennansichten visuell geprüft. Nach der ausschließlich lokalen Volcano-Lichtkorrektur wurden deren zwei Ansichten erneut aufgenommen und freigegeben. Die Physik- und Geometrieprüfungen stammen aus dem Stand vor dieser Lichtkorrektur; ihre Geometrie, Kollisionsformen und Bewegungslogik wurden dabei nicht verändert. Der abschließende Lichtzustand wird separat für vollständige und mobile Stufe belegt.

Die gemessenen Aufbauzeiten stammen vom Headless-Arbeitsrechner. Sie belegen keine Android-Bildrate. Geräte-FPS und APK-Ausführung werden in diesem Bericht nicht behauptet.

## Reproduktion

Nach dem regulären zentralen Godot-Import:

~~~sh
godot --headless --path . --script scripts/tests/kart_production_tunnel_layout_regression.gd
godot --headless --path . --script scripts/tests/kart_production_tunnel_physics_regression.gd
godot --headless --path . --script scripts/tests/kart_production_tunnel_physics_regression.gd -- --full
godot --headless --path . --script scripts/tests/kart_production_tunnel_visual_clearance.gd
python3 tools/lumo_kart_art/tracks/summarize_runtime.py
~~~

Die Physik- und Sichtprüfungen akzeptieren zusätzlich `--track=zauberwald` beziehungsweise eine andere konkrete Themen-ID. Der zusammenfassende Lauf prüft die unveränderten Autorenquellen erneut und bindet die Ergebnisberichte über ihre Hashes an einen Snapshot der beteiligten Runtime-Dateien.
