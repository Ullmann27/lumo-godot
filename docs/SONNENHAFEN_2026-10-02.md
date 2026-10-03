# Lumo Sonnenhafen – spielbare Kart-Ausbaustufe, 2. Oktober 2026

## Tatsächlich implementiert

Weiterentwicklung des bestehenden Godot-Rennens aus Commit
`3435acd4a1b1265467d58aca7d7d8033e1437e9e`, kein Neuaufbau der Lern-App.
Aufgabengenerator, Klassen-/Fachwahl, lokale Sterne, Android-Routenbridge und
das vorhandene Sprungspiel bleiben erhalten. Die Flutter-App wird in diesem
Änderungssatz nicht geändert.

- Geschlossener Sonnenhafen-Kurs: etwa 398 m, zwei Runden, Höhenwechsel bis
  zur Holzbrücke, geneigte Kurven, Leitplanken, Hafenhäuser, Boote,
  Leuchtturm, Windmühle, Vegetation, Wolken und Wegweiser.
- Sechs Fahrzeuge mit fünf eigenen Tierarten: Lumo-Fuchs, Otter, Hase,
  Dachs und Katze. Geformte Karosserien, Reifen/Felgen, Aufhängungen,
  Lenkräder, Gesichter, Blinzeln, Kopf-/Schwanzbewegung und Boost-Effekte.
- Analoger Neon-Stick links, eigenständige Touch-Flächen rechts. Ein Finger
  hält den Stick, während der zweite Boost oder Drift ausführt.
- Automatisches Gas. Stick links/rechts dosiert die Lenkung; nach unten
  verringert er das Tempo. Loslassen zentriert den Griff. Am Streckenrand
  fährt das Kart langsamer, es fällt nicht von der Strecke.
- Drift halten und gleichzeitig lenken; ausreichende Driftladung ergibt
  beim Loslassen einen kurzen Boost. Gesammelte Kristalle und richtige
  Lernantworten laden zusätzliche Boosts, maximal drei.
- Drei sichtbare Boost-Felder und vier weiche Hindernisse. Berührung eines
  Hindernisses verringert kurz das Tempo, ohne Neustart oder Punktverlust.
- Live-Streckenkarte mit allen Fahrern, Rangfolge, Runden und Tempo,
  nähere Verfolgerkamera, Querformat während des Rennens.
- Sechs freiwillige Lernfragen pro Rennen. Während der Frage fährt eine
  Fahrhilfe weiter; falsche Antworten liefern Hinweise. „Später“ lässt
  eine Frage aus. Pause bleibt möglich. Das Rennen kann auch ohne gelöste
  Fragen enden.
- Zwei Gegner-Tempi: gemütlich und flott, während der Pause umschaltbar.
- Pause, Rückkehr zur Welt mit gespeichertem Rennen, Fortsetzen nach
  erneutem Öffnen und ausdrücklich auswählbarer Abbruch.
- Lokaler Zwischenstand alle fünf Sekunden sowie bei Pause/Verlassen;
  temporäre Datei plus Umbenennung. Keine Namen oder Serverübertragung.
  Ein aktiver Zwischenstand für die gewählte Klasse und das Fach.
- Einstellungen für ruhige Bewegung, leichte Grafik und Ton. Ruhige
  Bewegung reduziert Figurenbewegung und unterbindet die Boost-Zoomfahrt.
  Leichte Grafik spart Schatten, Wasseranimation und Vegetationsdetails.
- Ergebnis mit Bestzeit und Sternen. Mehrfacher Ergebnisaufruf vergibt
  innerhalb derselben Runde keine zusätzlichen Sterne.

Die Fahrhilfe folgt einer vorberechneten Strecke mit seitlichem Lenken.
Diese Ausbaustufe besitzt noch keine frei fahrbare Fahrzeugphysik.
Die Referenzbilder dienen als visueller Qualitätsmaßstab. Fahrzeuge,
Figuren, Strecken, Texte, Symbole und Materialien sind Lumo-Originale;
die gelieferten Mario-Kart-Bilder sind nicht im Spielpaket enthalten.

## Starten

Engine: Godot **4.6.3 stable**. Repository öffnen und ausführen oder:

```sh
godot --path . -- --scene=kart --grade=2 --subject=Mathematik
```

Ohne Argumente öffnet sich die bestehende Spieleauswahl. „Sonnenhafen-Cup“
startet das Rennen. Desktop: Pfeiltasten oder A/D, Umschalt für Drift,
Leertaste für Boost, Escape für Pause/Fortsetzen. Der Stick funktioniert
auch mit der Maus. Auf Mobilgeräten mit zwei Daumen bedienen.

Browser-Build: `tools/build_web_bundle.sh`, mit installierten passenden
Export-Templates. Zum lokalen Start `python3 tools/serve_web.py`.
Web verwendet den Compatibility-Renderer. Browseraufruf kann
`?scene=kart&grade=2&subject=Mathematik` enthalten.

Android: Die bestehende GitHub-Actions-Pipeline baut ein signiertes
arm64-Test-APK für `dev.ullmann.lumo3d`. Auf einem passenden vorhandenen
Lumo-3D-Testpaket wird es als Update installiert. Es ist ein separates
Godot-Spielpaket, kein neuer Flutter-Release. Die vorhandene
`lumo3d://kart`-Bridge mit Klasse/Fach bleibt enthalten.

Der Branch veröffentlicht einen separaten Browser-Test unter
`https://ullmann27.github.io/lumo-godot/sonnenhafen/`.
Das bisherige `/island-cup/` wird durch diesen Branch nicht überschrieben.
Build-Erfolg und Veröffentlichung sind den zugehörigen Actions und
Release-Artefakten zu entnehmen; dieses Dokument allein bestätigt sie nicht.

## Ausgeführte Prüfungen

| Prüfung | Ergebnis lokal |
|---|---|
| Godot-Import mit 4.6.3 | bestanden, keine Skript-/Parserfehler |
| 4.000 Aufgabenvarianten, Lösungen und eindeutige Optionen | bestanden |
| Zwei vollständige Rennen, je beide Runden und sechs Fragen | bestanden; gemütlich und flott |
| Rennen läuft während Frage; falsche Antwort; Pause; Boost; Drift; Bremse | bestanden |
| Zwischenstand speichern, Szene schließen, erneut öffnen, fortsetzen | bestanden |
| Ergebnis mehrfach aufrufen, keine doppelte Sternvergabe | bestanden |
| Zwei Finger über tatsächlichen Godot-GUI-Eingabepfad | bestanden |
| Stick außerhalb loslassen, zweiter Finger loslassen | bestanden |
| Lernfenster lesbar, Pause innerhalb 1280 × 720 | bestanden |
| Bestehendes Sprungspiel: Kollision, Sprung, Aufgaben, Respawn, Pause, Ergebnis | bestanden |
| Android-Routenbridge, Python-Unittest | 1 Test bestanden |
| Projekt-/Assetprüfung | 118 bestanden, 6 bekannte Warnungen, 0 Fehler |
| GDScript-Lint/Format der geänderten Skripte | bestanden |
| Tatsächliche 3D-Renderbilder, normale und leichte Darstellung | fünf Bilder je Profil erzeugt und kontrolliert |

Die sechs Asset-Warnungen betreffen bereits zuvor fehlende optionale GLB-
Modelle des zentralen Manifests. Das neue Rennen verwendet seine eigenen
generierten Geometrien. Globales Lint/Format wurde ebenfalls ausgeführt:
In unveränderten Altskripten bestehen Zeilenlängen-/Formatbefunde weiter.
Diese wurden nicht durch eine pauschale Neuformatierung verdeckt.

### Leistungsmessung mit Software-Grafik

1280 × 720, OpenGL Compatibility, Mesa llvmpipe (LLVM 20.1.2), synthetische
Kamerapositionen des Render-Tests: normales Profil ca. 133 ms Median /
148 ms p95; leichte Grafik ebenfalls ca. 133 / 148 ms. Etwa 874 gegenüber
425 Draw Calls in der letzten erfassten Ansicht. Diese Umgebung erreicht
damit keine flüssige Zielbildrate. Sie ist kein Android-GPU-Benchmark.
Eine Leistungsfreigabe wird ausdrücklich nicht behauptet.

```sh
GODOT_BIN=godot bash tools/validate_project.sh
python3 -m unittest discover -s tools/tests -v
python3 tools/validate_project.py
# Mit verfügbarer grafischer Sitzung, alternativ xvfb-run:
godot --rendering-method gl_compatibility --script scripts/tests/kart_showcase.gd
godot --rendering-method gl_compatibility --script scripts/tests/kart_showcase.gd -- --lightweight
```

## Offen

- **offen:** Grafikqualität auf dem Niveau der Referenzbilder. Diese
  Strecke ist eine erste eigenständige Ausbaustufe; zahlreiche Materialien,
  Silhouetten und Umgebungsdetails brauchen weitere gestalterische Arbeit.
- **offen:** Physik mit frei fahrbarem Kart, komplexere Driftlinien,
  Sprungrampen, bessere Gegner-KI und gegenseitige Fahrzeugkontakte.
- **offen:** weitere vollständig ausgearbeitete Strecken, Fahrzeugtypen
  und eine Auswahl/Anpassung der Spielfigur vor dem Rennen.
- **offen:** Handheld-Test auf echten Android-Geräten, insbesondere
  gleichzeitige Daumenbedienung, Bildschirmränder, GPU-Leistung, Audio,
  Wiederaufnahme nach Betriebssystem-Unterbrechung und APK-Routenaufruf.
- **offen:** 60 FPS auf dem Zielgerät erreichen und nachweisen;
  weitere Geometrie-LOD, räumliches Culling und gebackene Beleuchtung prüfen.
- **offen:** aktuelle österreichische Lehrplanprüfung und sprachliche
  Einzelprüfung sämtlicher bestehender Aufgaben. Rechnerische Tests sind
  keine fachliche Freigabe für jeden Deutsch-Inhalt.
- **offen:** gemeinsame Fortschrittsspeicherung mit Flutter; Godot-Sterne
  und Rennzeit bleiben derzeit lokal im Godot-Paket.
- **offen:** globale PIN-Entfernung aus der Flutter-Hauptapp, Memory,
  eigenständiges Lern-Kartenspiel und echtes Intro-Video gemäß Gesamtauftrag.
  Diese Funktionen sind nicht Teil dieses Renn-Änderungssatzes. Die neuen
  Rennansichten verlangen keine PIN.

## Verbindliches Review-Ziel

Bei wesentlichen Änderungen werden echte Bilder des Spiels und der betroffenen
App-Ansichten mitgeliefert. Kein Download ist nötig, um das Erscheinungsbild zu
prüfen. Leistungsziel laut Nutzer: **flüssige 60 FPS**; noch nicht freigegeben.

## Nächste kleine Ausbaustufe

Den Android-Teststand auf dem Zielgerät prüfen, Stick-Erreichbarkeit und
Leistung messen, daraus die nächste Optimierung ableiten. Anschließend
einen Abschnitt des Sonnenhafens mit detaillierteren originalen Assets
und Fahrphysik verbessern; erst danach die zweite Strecke beginnen.

## Wartung und Asset-Herkunft

`kart_world.gd`, `kart_vehicle.gd`, `kart_joystick.gd`, `kart_touch_action.gd`
und `kart_minimap.gd` kapseln Welt, Fahrzeug, Eingabe und Karte.
`kart_questions.gd` bleibt die getrennte Inhaltsquelle. Statische Dekoration
wird als MultiMesh gruppiert, starre Fahrzeugteile pro Material zusammengeführt.
Neue Geometrien, Neon-Grafik, Wasser-Shader und Texturrauschen entstehen im
Projektcode. Es wurden keine externen Bild-, Modell- oder Audio-Assets hinzugefügt.

Für die weitere Pflege sind Engine-/Android-Updates, Sicherheitsprüfung,
Lehrplanänderungen, Gerätemessungen und manuelle Inhaltsfreigaben erforderlich.
Automatische Tests veröffentlichen keine geänderten Aufgabenlösungen.

## Fortsetzung – Bedienung und Zeichenarbeit

- Renn-HUD, Karte, Lernfenster und Touchflächen liegen in einer gemeinsamen
  Safe Area. Native Bildschirmränder/Cutouts werden in gestreckte UI-Einheiten
  umgerechnet; Fold-/Orientierungswechsel aktualisieren den Bereich.
- Dekorationen teilen Farben pro MultiMesh-Instanz und werden in räumliche
  48-m-Gruppen aufgeteilt. Wolken und große Hintergrundflächen werfen keine
  unnötigen Schatten auf die Strecke.
- Karts behalten ihre Nahgeometrie. Vertex-Farben reduzieren deren
  Materialflächen von 45 auf 25 (Fuchs/Katze) bzw. 44 auf 24 (übrige Tiere).
  Ab 28 m ersetzt eine Fläche das detaillierte Kart; rund 54–55 % weniger
  Vertices. Hysterese vermeidet Flackern am Umschaltpunkt.
- Räder, Kopf, Schwanz, Blinzeln und Drift-/Boost-Effekte bleiben animiert.
  Die Radphase läuft auch bei ferner Darstellung weiter. Kleine Augen-,
  Lenkrad- und Effektschatten entfallen. Schatten-Meshes behalten dieselbe
  Oberflächenanzahl und identische Positions-/Indexarrays wie die Nahgeometrie.
- Regressionen prüfen alle fünf Tiere, Positionsabweichung höchstens
  0,0001 m, Farbabweichung höchstens 1/255 pro Kanal, Shadow-Meshes,
  LOD-Wechsel und Animationen. Welt-Tests prüfen die tatsächlichen
  GPU-Farben/Transformationen zusätzlich mit dem OpenGL-Renderer.
- Renderfehler brechen die Veröffentlichungs-Pipeline nun ab. Android-APK,
  echte Spielbilder und Prüfsummen werden gemeinsam als Build-Artefakt gesichert.

Die vorstehenden älteren Software-Messwerte sind die Ausgangsmessung vor
diesen Optimierungen. Eine echte 60-FPS-Freigabe auf Android bleibt offen.

### Erneute tatsächliche Renderprüfung

Beide Profile wurden erneut in der Engine mit OpenGL Compatibility und
llvmpipe gerendert; fünf aktuelle Bilder pro Profil, keine Skript-/Renderfehler.
In derselben letzten Vergleichsansicht:

| Profil | Vorher | Nachher | Veränderung |
|---|---:|---:|---:|
| Normal: Draw Calls | 874 | 492 | −43,7 % |
| Leicht: Draw Calls | 425 | 275 | −35,3 % |

Die damals gemeldeten Bildzeiten verwendeten Godots `delta`, das bei sehr
langsamer Darstellung begrenzt werden kann. Sie sind **keine verlässlichen
realen Bildzeiten** und werden nicht als FPS-Nachweis verwendet.

### Prüfung am 3. Oktober 2026

Die Bildprüfung misst nun echte monotone Zeit zwischen Frames. PNG-Auslesen
und Speichern werden aus den gewöhnlichen Bildzeit-Stichproben ausgeschlossen.
Normalprofil, 1280 × 720, llvmpipe (Software-Renderer): Median **240,4 ms**,
p95 **264,7 ms**, 66 Stichproben, 492 Draw Calls. Das ist deutlich über dem
60-FPS-Budget von rund 16,7 ms. Die verschiedenen feststehenden Kameraansichten
sind eine Renderprüfung, kein Benchmark eines vollständigen fahrenden Rennens.
Leichtes Profil: Median **125,9 ms**, p95 **145,8 ms**, 66 Stichproben,
275 Draw Calls. Ein Nachweis auf echter Android-GPU bleibt **offen**.

Die installierte Android-Prüfung hat zuvor eine Activity-Neuerstellung vor
abgeschlossenem Engine-Start gefunden. Manifest und Projekt verwenden nun
dieselbe Startausrichtung (Hochformat); die Activity verarbeitet außerdem
Orientierungs-, Farbmodus- und UI-Konfigurationswechsel selbst. Das Rennen
wechselt weiterhin ins Querformat. APK-Installation im Test erfolgt ohne
Androids inkrementelle Bereitstellung. Der erneute installierte Starttest
auf Android API 35 besteht (Actions-Lauf 37085119053): Boot, Spieleauswahl,
geladener Lumo und anschließend weiterhin lebender Prozess. Der zusätzliche
Kart-URI-Test (37085628250) fand einen bislang verdeckten Bridge-Fehler:
Der URI-Filter lag auf Godots nicht exportierter Activity. Er liegt jetzt
auf dem vorhandenen öffentlichen Launcher-Alias, beschränkt auf die Hosts
`kart`, `jump` und `home`. Die Activity bleibt privat. Der Python-Test
verwendet die echte Alias-Struktur und prüft auch wiederholte Vorbereitung
sowie unveränderten MAIN-Start. Erneute Android-Route-Prüfung noch ausstehend.

Lokal erneut bestanden: 23 Python-Prüfungen, zwei vollständige Rennen,
4000 Aufgabenvarianten, echte Zweifinger-GUI-Ereignisse, Safe-Area-Resize,
Checkpoint/Wiederaufnahme, Jump-Regression, Fahrzeug-LOD/Geometrie/Farben
und Weltfarben/-Transformationen mit OpenGL. Fünf aktuelle Spielbilder wurden
von der laufenden Engine erzeugt. Keine Skript- oder Renderfehler; die
Software-Umgebung meldet eingeschränkte VSync-Unterstützung.

Die App-Bilder haben zwei vorhandene Lumo-Animationsfehler sichtbar gemacht:
Der Pose-Reset verschob den Körper von seinem Modellversatz auf 0; Viseme
ersetzten die kleine Mundskalierung durch volle Modellgröße. Beides ist
korrigiert. Ein separater Engine-Test prüft alle Verhalten, proportionierte
Viseme und eine tatsächlich laufende Idle-Animation. Die Mimik wird nach dem
Beenden der vorherigen Animation gesetzt, damit sie nicht durch deren
Mund-Reset verloren geht. Spieleauswahl und bestehende Godot-Home wurden
erneut gerendert und visuell geprüft. Die Flutter-Hauptapp ist unverändert.
