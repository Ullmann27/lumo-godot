# Aktuelle C4- und Kart-Originalbilder: unabhängige Sichtprüfung

## Ergebnis

Fünf unveränderte PNG-Originale wurden angesehen: vier C4-Ansichten aus dem aktuellen Host-Lauf und genau ein Kartframe aus dem erfolgreichen aktuellen Native-Stage2-Lauf. In diesen Ansichten wurde kein neuer Geometriefehler festgestellt. Diese begrenzte Sichtprüfung ersetzt keine Android- oder Geräteabnahme.

| Herkunft | Exakter Quellstand | Lauf / Job / Versuch | Originalsammlung |
| --- | --- | --- | --- |
| Host C4 Runtime | Host `1e22d2455937e2640d1e44e153d290746f3afe49`, Native `e9a9f60f20403ffa6b2b26d1437f958b2704d2aa` | `43596913210` / `132453271437` / 1, Runtimejob erfolgreich | Artefakt `14114408787`, 259 PNGs |
| Native Kart Stage 2 | Native `e9a9f60f20403ffa6b2b26d1437f958b2704d2aa`, Tree `1c2b5da7a4485cb8b911adcac2b567481cf902b5` | `43595543000` / `132449119326` / 1, erfolgreich | Artefakt `14114083026`, 85 PNGs |

Der gesamte Host-Lauf war bei Abruf seiner Metadaten noch aktiv. Es wird hier ausschließlich der tatsächlich erfolgreiche Runtimejob bewertet.

## Sichtbefunde

- **C4 960×540, leeres Brett:** Alle 42 Brettfelder, der Originalfuchs mit blauer Brille und dunkler Kleidung sowie alle sieben Spaltenflächen sind sichtbar. Der Fuchs steht vollständig rechts neben dem Brett; Zurück und Pause bleiben frei.
- **C4 1080×2400, Botantwort:** Cyaner Spielerstein und gelbe Botantwort liegen sichtbar im vollständigen Brett. Alle sieben Spaltenflächen, Zurück und Pause passen. Der bestehende Quellcode blendet die Figur bei logischer Safe-Area-Breite unter 700 ausdrücklich aus: `scripts/games/connect_four/connect_four_table.gd`, Blob `f2ae17e7edf8ac1b2d0d72a0d477d7e1459b1458`, Zeile 609, `fox.visible = width >= 700`. Es liegt in dieser Aufnahme kein Beleg für einen Ladefehler vor.
- **C4 Fold 2400×1080:** Das tatsächliche Gewinnmodal verdeckt das Brett. Gewinnertext und „Brett ansehen“ sind vollständig sichtbar; „Neue Runde“ ist unten teilweise abgeschnitten und „Gegen Lumo spielen“ liegt im vorhandenen vertikalen Scrollbereich. Die sieben deaktivierten Spaltenflächen und Zurück sind sichtbar.
- **C4 320×740:** Gewinnertext und alle drei Modalaktionen sind sichtbar. Der vorhandene horizontale Spaltenstreifen zeigt fünf Schaltflächen vollständig und die sechste teilweise; die siebte erfordert Scrollen. Gleichzeitige Sichtbarkeit aller sieben wird ausdrücklich nicht behauptet.
- **Kart 1280×720, Aquarium, HIGH:** Die vorhandene Chase-Aufnahme zeigt das Kart auf der Fahrbahn und die Minimap oben rechts mit Kurs und Spielerpunkt. Minimap, Fahrer, Straßenmitte, Pause und die rechts liegenden Drift-/Speed-/Schild-/Bremsflächen überdecken einander nicht. Genau dieser eine Kartframe wurde angesehen.

## Originalbindung und Integrität

Beide ZIPs wurden einmalig heruntergeladen, vor Verarbeitung gegen die API-Größe und den vollständigen SHA-256 geprüft, auf unsichere Pfade, doppelte Namen und symbolische Links geprüft und vollständig per ZIP-CRC validiert. Die Indizes unter `indices/` enthalten SHA-256, Größe und CRC aller 575 Archivmitglieder sowie Abmessungen sämtlicher 344 PNGs. Die Kart-Sammlung enthält fünf ausdrücklich benannte diagnostische Weißmasken; keine davon wurde für die Sichtprüfung verwendet.

- C4-ZIP: 22.148.477 Bytes, SHA-256 `2ea72b69b30c4fbe154dc497c57c39bd69f418acb8c6548d90e0c7df38639438`.
- Kart-ZIP: 49.681.551 Bytes, SHA-256 `e21bf4c90cd075c40f4bdeccba84451168bed1c91836e40d08b53241a1c7e5d2`.

Alle 259 C4-Bilddatensätze des Originalresultatindex wurden gegen die tatsächlichen Archivbytes und Abmessungen geprüft; außerdem alle 14 Datensätze des Original-Stage2-Charakterindex. Die C4-Quellsnapshots vor und nach dem Lauf sind bytegleich. Alle 1.267 erfassten Native-Dateiidentitäten stimmen mit dem tatsächlichen e9a9-Baum überein. Die beiden identischen Quellsnapshots bleiben als Originaldateien erhalten; Git dedupliziert ihren gemeinsamen Blob.

`c4/` enthält die vier ausgewählten Original-PNGs samt unveränderten Layout-Sidecars und Originalresultaten; `kart/` enthält nur den ausgewählten Originalframe, den vorhandenen Resultatindex und dessen Original-Probelog. Die großen vollständigen ZIP-Sammlungen werden nicht zusätzlich in Git dupliziert. Der vollständige bereits archivierte aktuelle Host-Runtime-Joblog ist Gitblob `f71dc893fea8f8e8b5297b82fad151b3d866ca30`; er wurde nicht erneut abgerufen. Die zwölf nativen Originaljoblogs samt vollständigen Laufmetadaten liegen bereits in Native-Evidencecommit `935a4d8f764d993d384e21a9e2937572415028db`.

## Tatsächlich erreichte Resultate und Grenzen

Der aktuelle C4-Originalresultatindex meldet 170 Native-Prüfungen, keine Nativefehler, Dart-/Godot-Exitcode 0 und 250 aufgezeichnete Frames, davon 90 bewegte und 43 Gewinnframes. Der echte Produktions-Dart-Controller bestätigte menschlichen Zug und Botantwort, fünf Sterne, 40 XP sowie Wiederöffnung derselben Runde im verwendeten Test-SharedPreferences-Backend. Die 24 FPS bezeichnen das Aufzeichnungsformat. Sie sind kein Geräte-FPS-Nachweis; Android-Binder und echte persistente Android-Datenträger wurden in diesem Desktop-Runtimejob nicht geprüft.

Der originale Stage2-Nachweis bindet den ausgewählten Kartframe an e9a9, Godot 4.6.3 und die tatsächliche X11/OpenGL-Softwareaufnahme. Die Probe fuhr vor diesem Bild 6,43 Meter; sie ist kein vollständiger Rundennachweis und keine physische Geräte-Leistungsmessung.

Es wurden keine neuen Tests, Captures, Renderer oder Engineprozesse gestartet und keine Produktdateien geändert. Die übrigen Bilder sind vollständig auf Integrität indexiert, jedoch nicht als visuell geprüft ausgewiesen.
