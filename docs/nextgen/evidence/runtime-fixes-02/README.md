# Tatsächliche Runtime-Prüfung nach kanonischem Avatar-Fix

Produktionscode: `cdb624e9f7d76d577acdb6c3c82be1b61bcce906`, bei Root als
`4db6c1f` integriert. Die Produktionsdateien wurden für diesen Beleg nicht
weiter verändert. `manifest.json` hält Quell- und Artefakthashes fest. Die
Headless-Matrix stammt aus den Testdateien dieses Produktionscommits; die
anschließende Software-Matrix ergänzt zwei klar bezeichnete Viewports.

## Ergebnisse

| Tatsächlich ausgeführte Probe | Ergebnis |
| --- | --- |
| Importierter Actor, kanonisches JSON, Rig-/Mund-/Audio-/Abbruchvertrag | 300 Checks, 0 Fehler |
| Original-Base mit ursprünglichem Fox, unabhängig von Next | 69 Checks, 0 Fehler |
| Geroutete Szene, alle 12 begrenzten nativen Aufgabenarten, fünf Größen und 150%-Text | 5.478 Checks, 0 Fehler |
| Geroutete Szene mit realem Software-Renderer, 8+5/Banane/Muster/Aufgabenkarte, sieben Größen | 2.110 Checks, 0 Fehler, 18 Screenshots |
| Read-only Geometriebeitrag der tatsächlichen 8+5-Szene | `geometry.json`, echter Godot-Lauf |
| 5-s-Leistungsmeldungen aus der tatsächlichen Szene | Drei echte Fenster; keine 60-FPS-Freigabe |
| Projektvalidator | 118 PASS, 0 WARN, 0 FAIL |

Headless-Logs enthalten keine Scriptfehler oder Warnungen. Die beiden
Software-Läufe enthalten ausschließlich die dokumentierten Rendererwarnungen:
V-Sync kann im isolierten Treiber nicht umgestellt werden; Screen-space AA und
volumetrischer Nebel benötigen andere Renderermodi. Es gibt dort keine
GDScript-/Laufzeitfehler.

Die zusätzliche Größe **412×960** und **750×832** sind indirekte
Viewport-Szenarien. Sie sind keine Messung eines physischen Fold 7, seiner
Pixeldichte, Safe Areas oder seiner Audio-/GPU-Leistung. Die anderen Formate
sind 360×800, 412×915, 900×1100, 1280×720 und 2400×1080; im letzten Szenario
wird die ausdrücklich vorgegebene Testdichte 2,625 benutzt.

## Echte Software-Messwerte

Umgebung: Godot 4.6.3, X11, `gl_compatibility`, Mesa/llvmpipe
`LLVM 19.1.7, 256 bits`, Viewport 412×915. Kein Messskript setzt ein Framelimit
oder ändert das Qualitätsprofil. Der Actor, seine Morphs und die vorhandene
bewegte Ambience laufen im tatsächlichen `_process` der gerouteten Szene.

Für diesen lokalen Lauf benutzt die offen deklarierte Sprachbridge-Fixture
einen echten `AudioStreamPlayer` mit erzeugtem 440-Hz-PCM-Signal. Position und
RMS werden aus diesem Signal gelesen; Ausgabe ist der **Dummy-Treiber**.
`audible` beschreibt in dieser Fixture das aktive Signal vor der Ausgabe.
Das belegt **keine hörbare Android-TTS oder physische Akustik**. Die produktive
Android-Probe muss die echten Host-/MediaPlayer-Meldungen einer aktuellen APK
und deren eigenen Prozess auswerten.

| Fenster | Dauer / Samples | Mittel / P50 | P95 / P99 | >16,7 ms | Sprache + Figur + Effekte |
| --- | --- | --- | --- | --- | --- |
| 1, Start | 6.672,35 ms / 1 | 6.672,35 / 6.672,35 ms | 6.672,35 / 6.672,35 ms | 100 % | 1 |
| 2 | 5.040,70 ms / 30 | 168,02 / 152,06 ms | 229,38 / 313,64 ms | 100 % | 29 |
| 3 | 5.008,99 ms / 24 | 208,71 / 209,83 ms | 275,26 / 291,48 ms | 100 % | 22 |

Das erste Fenster hat nur **ein Intervall**; seine Perzentile sind keine
belastbare Verteilung. Die Intervallraten der folgenden Fenster betragen
rechnerisch 5,95 beziehungsweise 4,79 Hz. Ein vorangegangener eigener Lauf
ist ebenfalls roh erhalten: dessen zweites Fenster ergab 42 Samples in
5.058,93 ms, Mittel 120,45 ms. Die beobachtete Streuung und die Softwareumgebung
erlauben keine Übertragung auf eine Android-GPU.

Der Renderzähler liegt in den drei Fenstern bei ungefähr **236 Draw Calls**
und **294.359–294.454 Primitiven**. Die Prozessmonitore sind getrennte
Engine-Messwerte: Im Startfenster ist noch kein Prozesswert verfügbar (0),
Fenster 2 enthält einen Maximumwert von 6.670,54 ms, Fenster 3 meldet Mittel
250,46 ms und P95/Maximum 290,19 ms. Diese Werte werden weder als einzelne
Mesh-Kosten noch als isoliertes CPU-/GPU-Profil ausgegeben.

## Größter Geometriebeitrag

Die read-only Bestandsaufnahme zählt aktuell sichtbare Nodes, deren reale
Meshflächen und aktive MultiMesh-Instanzen. Sie führt keine Frustum-, Occlusion-
oder LOD-Auswahl durch. **Mesh-Surfaces sind keine gemessenen GPU-Drawcalls.**
Schatten, Materialpässe und UI sind darin nicht zugeteilt.

| Gruppe | Dreiecke | Mesh-Surfaces | sichtbare Geometrie-Nodes |
| --- | ---: | ---: | ---: |
| LUMO | 31.163 | 7 | 2 |
| Lernobjekte | 14.952 | 18 | 18 |
| Umgebung | 71.232 | 60 | 53 |
| Gesamt | 117.347 | 85 | 73 |

| Einzelknoten | Dreiecke | Mesh-Surfaces / aktive Instanzen |
| --- | ---: | ---: |
| LUMO `Mesh_0` | 30.213 | 4 / 1 |
| `OpeningPetals` | 5.880 | 1 / 35 |
| `StudioTealBatch` | 5.744 | 1 / 1 |
| `StudioBrassBatch` | 4.156 | 1 / 1 |
| `StudioLeafBatch` | 4.144 | 1 / 1 |
| Atelier `MultiMeshInstance3D@11` | 4.032 | 1 / 24 |
| erstes `ten_frame` | 3.760 | 1 / 1 |
| zweites Ten-Frame-Mesh | 3.760 | 1 / 1 |
| `StudioCoralBatch` | 3.536 | 1 / 1 |
| `potted` | 2.688 | 1 / 16 |

Es wurde keine Produktionsgeometrie verändert und keine Optimierung behauptet.
Für eine sinnvolle Priorisierung bleiben die tatsächlichen Android-Messwerte
und gegebenenfalls ein echtes GPU-Profil entscheidend.

## Visuelle Prüfung und offene Presenter-Grenzen

Die PNGs stammen aus `scenes/learning/learning_world.tscn`, nicht aus
zusätzlichen Demo-Szenen. `bridge_ten_after_two.png` zeigt dieselben zwei
Objekte im Zehner und die verbleibenden drei; `syllables_412x960.png` zeigt
die echten drei Ba/na/ne-Karten und das importierte Bananenmodell.

Bei Banane überschneidet sich die extrudierte Wortüberschrift weiterhin mit
dem unteren Oberkörper der Figur und der Blumenreihe. Die Aufgabenkarte liegt
vor Teilen von LUMOs Körper, während der Kopf sichtbar bleibt. Diese inneren
Überlagerungen sind auf den Bildern festgehalten; reine Rand-/Bounds-Prüfungen
können sie nicht ausschließen. Es wird daher keine fertige visuelle Abnahme
behauptet. Musterhinweise und Vorschläge erzeugen keine Bewertung; die
Bestätigung bleibt in der tatsächlichen Flutter-Aufgabe.

## Reproduktion

Alle Skripte verwenden die bereits importierten Produktionsassets; kein erneuter
Vollprojektimport und keine zusätzliche Engine sind nötig. Beispiele:

```sh
godot --headless --path . --script scripts/tests/nextgen_avatar_contract_review.gd
godot --headless --path . --script scripts/tests/nextgen_learning_base_audio_regression.gd
godot --headless --path . --script scripts/tests/nextgen_learning_route_review.gd
godot --headless --path . --script scripts/tests/nextgen_learning_geometry_probe.gd
python3 tools/run_local_renderer.py --display 186 --output /tmp/lumo-perf-new --project . --timeout 90 -- --script scripts/tests/nextgen_learning_perf_capture.gd
```

`run.json`-Dateien enthalten die tatsächlich benutzten Argumente der beiden
gesicherten Renderläufe. Ein frisches Ausgabeverzeichnis und ein freies,
isoliertes Testdisplay sind erforderlich. Der Prüfstand belegt zwölf native
Darstellungsarten, keine vollständige Abdeckung aller Flutter-Aufgabenrouten.
