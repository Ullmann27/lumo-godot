# CPU-Kosten der neuen Original-Lumo-Animation

## Ergebnis

Die neuen Posen kosten relativ mehr CPU-Zeit: Der Gehpfad benötigt im Median
etwa das 3,14- bis 3,25-Fache, der Plattformpfad das 2,67- bis 2,84-Fache der
Quelle aus `ada5ed81`. Diese Mehrkosten werden nicht als unveränderte Leistung
ausgegeben. Absolut liegen sie auf dem hier gemessenen Linux-Rechner bei etwa
19–20 Mikrosekunden pro gehender Figur beziehungsweise 32–33 Mikrosekunden
pro Plattformfigur und Simulationsschritt.

Die acht gleichzeitig aktualisierten Plattformfiguren benötigen im aktuellen
Lauf zusammen einen Median von **0,2615 ms** und ein P95 von **0,379 ms**.
Das ist eine begrenzte CPU-Messung des Animationspfads, kein vollständiger
Frame, kein GPU-Messwert und keine Messung auf dem Galaxy Z Fold7.

## Aktueller Messlauf

Alle Werte in Mikrosekunden. „Gesamt“ bezeichnet einen Simulationsschritt
über die angegebene Anzahl realer Figuren; „pro Figur“ ist derselbe gemessene
Batchwert geteilt durch die Figurenanzahl.

| Pfad | Figuren | Vorher gesamt Median / P95 | Nachher gesamt Median / P95 | Nachher pro Figur Median / P95 |
| --- | ---: | ---: | ---: | ---: |
| Gehen | 1 | 6 / 9 | 19 / 21 | 19 / 21 |
| Gehen | 4 | 24 / 27 | 78 / 133 | 19,5 / 33,25 |
| Gehen | 8 | 49 / 73 | 154 / 208 | 19,25 / 26 |
| Plattform | 1 | 12 / 18 | 32 / 39 | 32 / 39 |
| Plattform | 4 | 47 / 88 | 132 / 181 | 33 / 45,25 |
| Plattform | 8 | 92 / 150 | 261,5 / 379 | 32,6875 / 47,375 |

Der neue Gehpfad animiert 22 statt zuvor 12 Knochen; er enthält nun auch die
zusätzlichen Körper-, Kopf- und Schwanzbewegungen aus den Studio-Clips.
Der Plattformpfad sampelt und überblendet echte Quaternion-Keyframes und
rechnet sie in die jeweiligen Knochenachsen um. Daher ist zusätzliche Arbeit
gegenüber den bisherigen vereinfachten Sinusposen zu erwarten. Die Messung
weist diese tatsächlichen Kosten aus.

## Methode und Messgrenzen

- Godot **4.6.3 stable**, Linux, Headless, derselbe Prozess für Vorher/Nachher.
- Identisches Original-GLB mit separatem echten 65-Bone-Skelett je Figur.
- Timer: `Time.get_ticks_usec()`, native monotone Mikrosekunden.
- Fester Simulationsschritt `1/60 s`; 30 Aufwärmschritte pro Durchlauf.
- Zwei Durchläufe mit jeweils 240 Messschritten. Reihenfolge zuerst alt/neu,
  danach neu/alt: **480 Samples pro Pfad und Figurenanzahl**.
- Plattformzyklus: 60 Geh-, 60 Sprint-, 40 Aufstiegs-, 40 Abstiegs- und 40
  Boden-/Landeschritte. Der Gehpfad erhält konstant 1,4 m/s.
- Erfasst sind Pose-Sampling und tatsächlich ausgeführtes Skeleton3D-Update.
  Figurenaufbau, GLB-Import, Physik, GPU-Skinning, Rendering, TTS und Flutter
  liegen außerhalb des Messbereichs.
- Baseline-Skripte sind als exakte Texte aus `ada5ed81` eingefroren. Die JSON-
  Datei enthält SHA-256 für sämtliche tatsächlich gemessenen aktuellen Quellen.
  `9eb25fcb` ist die zugehörige Integrations-Snapshotbezeichnung; Quellhashes
  machen die lokale Probe unabhängig von der lokalen Git-HEAD-Bezeichnung.

Die geringe Timerauflösung von einer Mikrosekunde und die Hostauslastung
beeinflussen besonders einzelne kurze Messungen. Ein vorausgehender Lauf
hatte bei acht Plattformfiguren 0,424 ms P95; die Mediane waren nahezu gleich.
Der aktuelle vollständige Lauf steht in `performance_cpu_comparison.json`
und `performance_cpu_comparison.log`.

## Speicher und Allokationen

In keinem Messbatch steigen Object-, Resource- oder Orphan-Zähler während
der Pose-Ticks an. Das statische Speicherdelta ist bei alt und neu in allen
Batches identisch: 788 Byte. Eine Kontrollmessung ohne einen einzigen Pose-
Tick erzeugt allein durch das zusätzliche Counter-Dictionary bereits 660 Byte.
Die verbleibenden 128 Byte sind ebenfalls in alt und neu und unabhängig von
der Figurenanzahl vorhanden; sie belegen keinen neuen Animations-Speicherwuchs.

Vorübergehende Allocator-Aktivität wurde nicht profiliert. Deshalb folgt aus
diesen Countern ausdrücklich keine Behauptung, dass überhaupt keine temporäre
Allokation stattfindet. Die neuen Quellen erstellen in `advance()` keine
zusätzlichen Nodes, Resources, Tweens oder Arrays. Sie lesen vorbereitete
konstante Tracks; die Posenbindungen werden vor den gemessenen Ticks erzeugt.

## Blattwind

Die tatsächliche importierte Lernatelier-Szene verwendet den neuen Shader auf
**zwei Mesh-Oberflächen**. Beide haben im geprüften normalen Modus
`motion_weight = 1.0`. Der Materialaufbau setzt das Gewicht einmal auf 0 oder 1,
abhängig vom vorhandenen Modus für reduzierte Bewegung.

Der Shader verwendet `TIME`, `sin`, `cos` und eine auf 0–1 begrenzte
`smoothstep`-Gewichtung. Die zusätzliche Auslenkung beträgt höchstens
**0,022 m in X**, **0,013 m in Z** beziehungsweise **0,025554 m insgesamt** in
Modellkoordinaten. Es gibt keine Schleife und keinen Texturzugriff im Shader.

Zur Laufzeit waren am Atelier sowohl `_process` als auch `_physics_process`
deaktiviert. Der Blattwind fügt somit keinen eigenen Skripttick und kein
fortlaufendes Setzen von Shaderuniforms hinzu. GPU-Zeit wurde nicht gemessen.

## Entscheidung

Für die laufende Integrationsprüfung wurde kein Produktivcode geändert. Die
relativen Mehrkosten sind real, der gemessene absolute CPU-Aufwand bleibt
begrenzt. Eine kleine mögliche spätere Optimierung wäre, im bestehenden
Bindungsschritt `neutral_rotation * inverse_bone_frame` zu speichern und diesen
Teil der Quaternionumrechnung nicht bei jedem Knochen und Tick neu zu bilden.
Sie ist hier nur vorgeschlagen, nicht als bereits umgesetzt ausgegeben.

## Reproduktion

```bash
godot --headless --path . \
  --script docs/evidence/studio-character-20261113/performance_probe.gd
```

Die Probe schreibt den JSON-Messbeleg. Für den Logbeleg die Standardausgabe
in `performance_cpu_comparison.log` umleiten.
