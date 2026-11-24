# Original-Lumo: Blender-Bewegungsclips und produktiver Anschluss

## Ausgangspunkt und behobener Fehler

Geprüfte Git-Baseline: `ada5ed81` (vollständige Revision in
`before_pose_provenance.json`). Der Originalfuchs war bereits als tatsächlich
skinned GLB mit 65 Knochen und neun Gesten-/Kartclips vorhanden. Jump hatte
bereits variable Sprünge, Puffer, Absprungtoleranz, bewegliche Plattformen und
die Originalfigur. Diese Funktionen wurden nicht neu erfunden oder ersetzt.

Die bisherige Geh-/Plattformpose wandte dieselbe lokale X-Rotation auf Knochen
mit unterschiedlichen Ruheachsen an. Die Fußachsen zeigen etwa in die
entgegengesetzte Richtung der Oberschenkelachsen. Zusätzlich wurde das
Fußgelenk zum Anheben versetzt; dadurch änderte sich die Länge des
Unterschenkels. Die alte Prüfung maß genau diese Gelenkverschiebung.

## Tatsächliche Änderungen

`tools/lumo_animation/author_platform_clips.py` wurde in Blender 4.3.2 auf dem
vorhandenen Original-GLB ausgeführt. Es erzeugt sechs Actions: Gehen, Sprint,
Sprungaufstieg, Sprungabstieg, Landung und Bremsen. Die Beine werden beim
Authoring mit zwei starren Segmenten und einem vorwärts gerichteten Knieziel
gelöst. Die Sohlen bleiben beim Bodenkontakt waagrecht. Es gibt keine
Knöcheltranslation und keine Streckung der Knochen.

Die tatsächlichen Blender-Posen werden als 25 Quaternion-Keyframes pro Clip
in `assets/characters/lumo_animated/lumo_studio_clips.gd` exportiert. Die Datei
ist 196.296 Byte groß und enthält keine zusätzliche Figur oder Textur.
`Lumo-Studio-Actions.blend` enthält die sechs editierbaren Blender-Actions;
sie können zum bestehenden Originalrig hinzugefügt werden. Das Verzeichnis
hat `.gdignore`, damit die Autorenquelle nicht als zusätzliche Figur importiert
wird. Die Android-Exportfilter schließen Dokumentation zusätzlich aus.

Der Produktionspfad lautet:

- `jump_islands.gd` und `build_explorer.gd` liefern die tatsächliche Bewegung
  und Bodenberührung an `lumo_rigged_actor.gd:set_platform_motion()`.
- `lumo_platform_pose.gd` wählt/sampelt die Blender-Clips und blendet Gehen und
  Sprint nach tatsächlicher Geschwindigkeit. Auf-/Abstieg folgt der vertikalen
  Geschwindigkeit; Landung folgt dem Wechsel von Luft zu Boden. Bremsen nutzt
  die tatsächliche Geschwindigkeitsänderung.
- `lumo_body_space_pose.gd` übersetzt Körperraum-Rotationen in die jeweiligen
  Ruheachsen des Originalrigs. Die Schrittlänge berücksichtigt auch die
  Skalierung des Fuchses im jeweiligen Spiel.
- `lumo_walk_locomotion.gd` verwendet dieselben Blender-Gehkurven für bestehende
  Aufrufer von `set_locomotion_speed()`. Die Lehrer-API bleibt unverändert.

Die alte Gehprüfung misst jetzt die tatsächliche Fußhöhe im Skelett statt eine
unerwünschte Translation des Fußgelenks. Sie prüft weiterhin Gehbewegung,
Pause, ruhige Animation, Rückkehr zur Ruhepose und Erhalt der Kartclips.

## Originalschutz

`assets/characters/lumo_animated/Lumo-Animated-Mobile.glb` bleibt bytegleich:

```text
3559f700784bc1006905ee3aae01e8bcfbffb95b4f621f7430ce771ba0e3efd5
```

Das betrifft Geometrie, Hautgewichte, UVs, Materialien, Texturen, alle 65 Bones
und alle neun bisherigen Animationsclips. Die Kollisionskapsel, Sprungphysik,
Eingabesteuerung und Speicherstände wurden durch diese Änderung nicht geändert.

## Ausgeführte Prüfungen

Die neue `lumo_studio_motion_regression.gd` vergleicht alle 300 Fußendpunkte
(6 Clips × 25 Keyframes × 2 Füße) zwischen Blender und Godot. Größte gemessene
Abweichung: **0,000000733 m**. Größte Änderung einer starren Beinsegmentlänge:
**0,000000179 m**. Zusätzlich werden Sohlenausrichtung, Bodendurchdringung im
Clip, tatsächliches Anheben, Skalierung, Modusbesitz, Lehrergesten, Pause und
die neun Originalclips geprüft. Ergebnis: **PASS, 1.046 Einzelprüfungen**.

Eine unabhängige Codeprüfung fand außerdem, dass `AnimationPlayer.play()` bei
einem bereits ausgewählten Idle dessen bisherige Zeitposition fortsetzt.
Die Bindung übernahm dadurch bis zu 3,278613 mm Resthöhenversatz aus der
Atemanimation. Zwei explizite `seek(0.0, true)` setzen vor dem Binden die
Originalpose einschließlich Root-Höhe zurück. Die Gegenprobe mit sechs
vorherigen Idlephasen zwischen 0 und 2,5 Sekunden ergibt danach in beiden
Bewegungs-APIs exakt 0,0 m Unterschied. Zwölf Regressionprüfungen sichern das.

Der Blender-Authoringlauf misst zusätzlich den IK-Zielfehler; Maximum:
**0,000000337 m**. Die Werte sind mathematische Übereinstimmungsprüfungen des
Skeletts, keine Aussage über medizinische Anatomie oder Android-Performance.

Weiterhin tatsächlich ausgeführt und bestanden:

| Prüfung | Ergebnis |
| --- | --- |
| `jump_nextgen_regression.gd` | PASS, 84 Prüfungen: echte CharacterBody-Sprünge, Puffer, Absprungtoleranz, Originalrig, Pause, Touchgrößen, getrennte Spielstände |
| `lumo_65bone_walk_gait_regression.gd` | PASS: reale Fuß-/Kniebewegung, Pause, ruhige Animation, Reset |
| `lumo_teacher_pose_regression.gd` | PASS, 34 Prüfungen: Originalgesten, geteilter Kopf-/Halsblick, exklusiver Posenbesitz, Pause |
| Python-Kompilierung | `author_platform_clips.py` erfolgreich kompiliert |
| `git diff --check` | keine gemeldeten Whitespacefehler im geprüften Stand |

## Bilder und Evidenzgrenzen

`walk.png`, `sprint.png`, `jump_rise.png` und `land.png` sind echte Blender-Cycles-
Renderings des vorhandenen Originalfuchses, jeweils 720 × 840 Pixel. Verwendet
wurden CPU-Rendering und 32 Samples ohne Denoiser. Sie wurden visuell geöffnet
und geprüft. Es sind keine generierten Konzeptbilder und keine Androidbilder.

`scripts/tests/lumo_studio_motion_capture.gd` ist der zusätzliche native
Godot-Vorher-/Nachher-Capture. Er prüft die SHA-256 der eingefrorenen
Baselinequelle und rendert beide Posen auf derselben Originalfigur. Er
verweigert Headless-Screenshots ausdrücklich. Seine Ausführung benötigt einen
funktionierenden Display-/GPU-Renderweg; ein Parserlauf allein ist kein
Rendererfolg. Echte Spielsteuerung wird separat durch
`scripts/tests/jump_nextgen_capture.gd` aufgenommen.

Gesichtsmorphs, Augenlider und Kiefersteuerung wurden nicht hinzugefügt: Das
Original besitzt dafür weder Morph-Targets noch eigene Bones. `mouth_supported`
bleibt deshalb `false`; es wird keine Lippensynchronität behauptet. Eine
authentische Gesichtserweiterung benötigt Bearbeitung des Originalgesichts,
insbesondere eine nutzbare Mundinnengeometrie und abgegrenzte Lidbereiche.

Auf dem physischen Galaxy Z Fold7 wurden durch diesen Arbeitsblock keine
FPS-, GPU-, Temperatur- oder Eingabelatenzmessungen vorgenommen.

## Reproduktion

```bash
blender --background --factory-startup \
  --python tools/lumo_animation/author_platform_clips.py -- \
  --input assets/characters/lumo_animated/Lumo-Animated-Mobile.glb \
  --runtime assets/characters/lumo_animated/lumo_studio_clips.gd \
  --evidence docs/evidence/studio-character-20261113 --render

godot --headless --path . \
  --script scripts/tests/lumo_studio_motion_regression.gd

LUMO_CAPTURE_DIR=/tmp/lumo-studio-native \
  godot --path . --rendering-method gl_compatibility \
  --script scripts/tests/lumo_studio_motion_capture.gd
```
