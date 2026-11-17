# LUMO Kart: elf erweiterte Strecken und Themenpassagen

Stand: 14. November 2026. Quellbasis: `9f8341494ea316c9e36ed6722915ab34b22e67bd`.
Dieser Handoff beschreibt den Arbeitsstand im isolierten Branch; er behauptet keine bereits veröffentlichte Version, keinen Merge und keine Android-Freigabe.

## Gemessene Streckenlängen

Die Werte stammen aus der tatsächlich gebackenen Produktions-`Curve3D` in Godot 4.6.3, einschließlich der vorhandenen Himmelsinseln-Skalierung. Die Tabelle übernimmt die gespeicherten Messwerte unverändert. Alle elf Erweiterungen überschreiten Sonnenhafen und liegen zwischen 1.959 und 2.040 Metern. Vollständige Strecken-/Tunnelmessungen: [track-adventure-report.json](evidence/track-adventure-report.json).

| Track-ID | Vorher, m | Nachher, m |
| --- | ---: | ---: |
| `sonnenhafen` | 1851.68286132812 | 1851.68286132812 |
| `zauberwald` | 376.52685546875 | 1994.19970703125 |
| `bergwelt` | 472.778137207031 | 2009.17834472656 |
| `holo_city` | 442.781799316406 | 1984.18896484375 |
| `crystal_canyon` | 755.213745117188 | 1959.05151367188 |
| `jungle_temple` | 691.457092285156 | 2004.10375976562 |
| `candy_cloud` | 802.833862304688 | 1979.361328125 |
| `volcano_night` | 742.316101074219 | 2009.07336425781 |
| `winter_sprint` | 800.331787109375 | 1989.17993164062 |
| `galaxy_ringway` | 749.615844726562 | 2024.00244140625 |
| `desert_drift` | 774.800598144531 | 2039.32153320312 |
| `learning_lab` | 765.418395996094 | 1979.26232910156 |

Sonnenhafen erhält keine neue Adventure-Route und keinen neuen Adventure-Tunnel. Sein Kontrollpunkt-Array bleibt identisch; die Längenabweichung gegenüber der Originaldefinition wird unter 0,001 m geprüft. Sein vorhandener Darkride und seine Streckenmodule bleiben bestehen.

## Verbundene Themenpassagen

Längen und Abfahrten dieser Tabelle sind auf Millimeter gerundet; die JSON enthält die gespeicherte Präzision, Ein-/Ausstiegsdistanzen und Aufstiege. Die Abfahrt ist die gemessene Höhendifferenz vom Portal zum tiefsten Punkt der echten Fahrkurve innerhalb der Passage.

| Track-ID | Passage | Bauart | Länge, m | Abfahrt, m |
| --- | --- | --- | ---: | ---: |
| `zauberwald` | Wurzelbibliothek | `hillside` | 371.150 | 14.267 |
| `bergwelt` | Kristallwolken-Galerie | `cloud_gallery` | 308.523 | 11.597 |
| `holo_city` | Aurora-Metro | `city_gallery` | 240.135 | 11.597 |
| `crystal_canyon` | Amethyst-Tiefengrotte | `hillside` | 273.328 | 11.598 |
| `jungle_temple` | Versunkene Tempelhalle | `hillside` | 261.390 | 11.596 |
| `candy_cloud` | Zuckerbäcker-Galerie | `cloud_gallery` | 259.265 | 11.598 |
| `volcano_night` | Basalt-Glutstollen | `hillside` | 273.540 | 11.596 |
| `winter_sprint` | Gletscher-Kristallhöhle | `hillside` | 252.824 | 11.600 |
| `galaxy_ringway` | Sternen-Observatorium | `orbital_gallery` | 250.842 | 11.600 |
| `desert_drift` | Oasen-Katakomben | `hillside` | 267.664 | 11.600 |
| `learning_lab` | Entdecker-Kernlabor | `laboratory_gallery` | 254.953 | 11.600 |

`hillside` bedeutet eine Fahrbahn unter einer breiten, geschlossenen Hügel-/Felshülle mit verbundenen Portalflächen. Sky, Candy und Galaxy nutzen zur Welt passende überdeckte Galerien; City und Lab haben technisch geformte Hallen. Die Höhe fällt tatsächlich entlang derselben Fahrkurve und steigt zum Ausgang wieder an. Es gibt keine zusätzliche versetzte Fahrbahn oder Teleportation. Die Gewölbe besitzen ein nominelles lokales Mittelprofil von mindestens 9,8 m und seitliche Themendetails: unter anderem Wurzelregale mit Büchern, Tempelzeichen, Kristalle, Basalt-/Glutbänder, Säulen, Zuckerornamente, Moleküle und Planeten.

## Geometrie und Integration

- `scripts/games/kart_adventure_routes.gd` enthält die elf eigenständig definierten Kontrollpunktfolgen und Portalanker. `kart_tracks.gd` und `kart_expansion_tracks.gd` liefern sie über den bestehenden Katalog.
- `kart_world.gd::_make_curve()` bleibt die gemeinsame Autorität für Fahrbahn, Bankwinkel, Projektion, Leitplanken und acht Kontrollpunkte. `kart_adventure_tunnels.gd` baut daran die Innenhülle, Außenhaut, Portale und gebündelte Details. Der Tunnel fügt keine `CollisionObject3D` hinzu.
- `world.adventure_tunnel` steht nach `_make_curve()` bereit. Der erzeugte `AdventureTunnel`-Knoten und die Welt tragen identische `adventure_tunnel`-Metadaten mit `start_m`, `end_m`, `length_m`, `name`, `theme`, `covered_type`, `descent_m`, `clearance_m` und Geometriezählungen. Der Plan steht außerdem unter `adventure_tunnel_plan`.
- `kart_action_course.gd` reserviert die Tunnelspannen einschließlich bestehendem Sicherheitsabstand. Die deterministische Suche kann auf langen Strecken weiter ausweichen; Start/Ziel-, Sprung-, Loop-, Kicker-, Slalom- und Tauchstreckenbedingungen bleiben erhalten. Der Test prüft auch die fest gesetzten Sprünge und Loops gegen die Tunnelspannen.
- Die Innenflächen verwenden Godots Uhrzeigersinn als Vorderseite; die beabsichtigte Beleuchtungsnormale bleibt erhalten. Portalnormalen zeigen nach außen. Backface-Culling bleibt eingeschaltet.
- Outdoor-Kits, Fleet-Möbel und Expansion-Landmarken meiden die reservierten Passagen; überlappende alte Tunnel-/Brücken-/Tor-Dekoration wird ausgespart. Materialien, Formmeshes und MultiMesh-Infrastruktur stammen weiterhin aus dem vorhandenen Weltaufbau.

## Dichte und Weltgrenzen

Der Zauberwald verteilt seine Cluster entlang der neuen Kurve statt im alten ±100-m-Feld. Es gibt 180/300 deterministische Platzierungsversuche für niedrige/hohe Detailstufe; Straßen-, Wasser- und Bibliothekskonflikte werden verworfen. Der neue Geometrievertrag verlangt mindestens 80 erhaltene Cluster, Bedeckung aller acht Streckenachtel und freien Kronenumraum zur Fahrbahn und Bibliothek.

Holo-City ergänzt 60/96 geprüfte Boulevardblöcke als Platzierungsversuche und setzt seine äußere Skyline relativ zur neuen Weltausdehnung. Die Terrainränder von Zauberwald und City bekommen 48 m statt 18 m Zugabe. Sonnenhafens Randberechnung bleibt unverändert. Expansion-Landmarken verwenden ungefähr 30/17 m Abstand bei höchstens 76/128 Versuchen; die vorhandene 900 × 900 m Bodenfläche bleibt bestehen. Der Test prüft, dass Kurve plus 29-m-Hügelhalbbreite innerhalb dieser Fläche liegen.

Die historische Bibliotheksregression bleibt auf der ursprünglichen 376-m-Waldroute als festem Vergleichsfall erhalten: sämtliche bisherigen Zufalls-, Identitäts-, Freiraum- und Entfernungsbedingungen bleiben aktiv. Die absichtlich neu verteilte Adventure-Vegetation wird separat im aktuellen Geometrievertrag geprüft.

## Tatsächliche Validierung und Grenzen

| Prüfung | Beobachtetes Ergebnis |
| --- | --- |
| `kart_track_contract.gd` | 12/12 Strecken bestanden: Naht, Projektion, acht Kontrollpunkte, Bankrahmen, Trennung anderer Streckenabschnitte und ursprünglicher Mindestradius >18 m. Kleinster gemessener Radius der elf neuen Kurse: 60,2 m. |
| `kart_adventure_regression.gd` | 11/11 vollständige Welten in niedriger Detailstufe aufgebaut; jeder Tunnel zusätzlich in hoher Geometriedichte geprüft. Spannen, Höhenprofil, Action-Abstand, Weltgrenzen, Freiraum, Polygon-Winding und Waldabdeckung bestanden. Dies ist kein vollständiger High-Detail-Welt-Render. |
| `kart_track_theme_world_regression.gd` | Alle elf Welten in niedriger Detailstufe: 793 Prüfungen und 282 echte Geometrie-Stützproben bestanden. |
| `kart_theme_ground_contact_contract.gd` | 12 Fälle / 102 Prüfungen bestanden. |
| `kart_zauberwald_library_regression.gd` | Ursprünglicher Vergleichsfall in beiden Detailstufen: 601 Prüfungen bestanden. |
| `kart_adventure_winding_render_regression.gd` | Echter Godot/Mesa-Rasterizer, Exit 0: sechs positive Innenansichten (drei Positionen je Detailstufe) mit 0,0–0,1 % sichtbarem Testhintergrund. Sechs Negativkontrollen mit ausgeblendeter Innenhülle zeigten jeweils 100 % Hintergrund. Außenhülle und andere Geometrie konnten eine falsch orientierte Innenhülle nicht verdecken. |
| `kart_courses_driving_regression.gd` | Aggregiert 12 Strecken × zwei Runden = 24 Runden, 192 geordnete Kontrollpunkte, null Resets durch Produktions-`_physics_process()` mit physischer Lenkung. Zehn Strecken beendeten ihre Einzelasserts, bevor der erste Prozess ohne Gesamterfolgssentinel endete. Desert und Lab wurden anschließend in einem frischen Prozess mit Exit 0 und PASS abgeschlossen. Kein sauber abgeschlossener gemeinsamer 12-Strecken-Prozess wird behauptet. |
| Große Software-Renderer-/Action-Läufe | Vollständige Welt-Captures und beide großen Action-Renderer-Läufe wurden durch externes SIGKILL beendet. Diese Läufe gelten nicht als erfolgreiche End-to-End-Renderer-/Action-Abnahme; die vollständige Ursache ist nicht belegt. Die zwölf Action-Pläne hatten zuvor ihre Prüfungen bestanden. |
| Android | Auf keinem physischen Android-Gerät gemessen; keine Aussage über 60 FPS oder eine fertige APK-Freigabe. |

Die genaue Aufteilung der Fahrnachweise steht in [track-driving-evidence.json](evidence/track-driving-evidence.json). Die vorhandenen Track-Pack-Exporter/Capture-Werkzeuge akzeptieren alle zwölf IDs; für die acht Expansion-Welten erzeugt das 48-View-Werkzeug Ansichten aus der aktuellen Kurve und Tunnelspanne, falls kein historisches Pack-JSON existiert. Der Parser wurde geprüft; eine fertige Serie von 48 Bildern je Welt wird nicht behauptet.

## Reproduzierbare lokale Aufrufe

Vom Projektverzeichnis aus, nach dem Godot-Import. Jeder Aufruf nutzt ein eigenes Datenverzeichnis. `tools/run_godot_probe.py` beendet bei Engine-/Scriptfehlern und verlangt einen echten Erfolgssentinel.

```bash
mkdir -p /tmp/lumo-kart-adventure-qa
XDG_DATA_HOME=/tmp/lumo-kart-adventure-qa/curve-data python3 tools/run_godot_probe.py --log /tmp/lumo-kart-adventure-qa/curve.log --timeout 120 --required '[TrackContract]' -- godot --headless --path . --script scripts/tests/kart_track_contract.gd
XDG_DATA_HOME=/tmp/lumo-kart-adventure-qa/geometry-data python3 tools/run_godot_probe.py --log /tmp/lumo-kart-adventure-qa/geometry.log --timeout 300 --required '[KartAdventure] PASS:' -- godot --headless --path . --script scripts/tests/kart_adventure_regression.gd -- --report=/tmp/lumo-kart-adventure-qa/track-adventure-report.json
XDG_DATA_HOME=/tmp/lumo-kart-adventure-qa/theme-data python3 tools/run_godot_probe.py --log /tmp/lumo-kart-adventure-qa/theme.log --timeout 300 --required '[ThemeWorld] PASS' -- godot --headless --path . --script scripts/tests/kart_track_theme_world_regression.gd -- --track=all --quality=light
python3 tools/run_local_renderer.py --display 109 --output /tmp/lumo-kart-adventure-qa/winding-render --timeout 180 -- --script res://scripts/tests/kart_adventure_winding_render_regression.gd -- --output=/tmp/lumo-kart-adventure-qa/winding-frames
XDG_DATA_HOME=/tmp/lumo-kart-adventure-qa/drive-data python3 tools/run_godot_probe.py --log /tmp/lumo-kart-adventure-qa/drive.log --timeout 300 --required '[KartCourseDriving] PASS:' -- godot --headless --path . --script scripts/tests/kart_courses_driving_regression.gd -- --tracks=desert_drift,learning_lab
```

Für einzelne frische Fahrprozesse kann `--tracks=<Track-ID>` mit jeder der zwölf Tabellen-IDs verwendet werden; ohne Filter prüft das Skript alle zwölf. Die acht Kontrollpunkte pro Runde, zwei Runden, Zielankunft und null Resets bleiben in jedem Modus dieselben Pflichtasserts. Die Displaynummer des Renderer-Aufrufs muss lokal frei sein. Separate Studio- oder Blender-Ansichten können die echte Geometrie zeigen, ersetzen aber weder die vollständige Weltabnahme noch Android-Messungen.
