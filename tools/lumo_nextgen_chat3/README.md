# LUMO Nextgen | Chat 3 -- echte 3D-Produktion

Isolierter Produktionszweig: chatgpt/lumo-nextgen-chat3-3d-20261115.
Die bisherige Android-App sowie das bestehende 3D-Modell bleiben unveraendert.
Chat 1 ist fuer den Einbau in die aktuelle Flutter-/Godot-APK zustaendig.

## Original und Rechte

Verwendeter Ausgangspunkt:
assets/characters/lumo_animated/Lumo-Animated-Mobile.glb.
Das Original enthaelt 65 Bones und neun Animationen. Es basiert laut
assets/characters/lumo_animated/ATTRIBUTION.md auf einem Meshy-Modell,
CC BY 4.0. Den Meshy-Herkunfts- und Aenderungshinweis stets beibehalten.
Neue Animationen, Mundformen, Blender-Lernobjekte und Godot-Steuerung
sind eigene, lokale Arbeit ohne neue bezahlte externe Dienste.

## Produktionsdateien

Der reproduzierbare Blender-Generator steht in
tools/lumo_nextgen_chat3/build_blender_assets.py.
Er produziert im GitHub-Actions-Runner:

- Lumo-Learning-Animated.blend: editierbare Rig-Animation, Shape Keys,
  Studienkamera/Lichter und urspruengliches Skinned Mesh.
- Lumo-Learning-Animated.glb: importierbare Laufzeitfigur.
- Lumo-Learning-Objects.blend: editierbare Lernobjekte.
- Lumo-Learning-Objects.glb: acht wiederverwendbare Lernobjekte.
- Blender_Lumo_front/side/back/three_quarter.png: echte Blender-Render.
- runtime/01_math_8_plus_5.png, runtime/02_reading_ba_na_ne.png,
  runtime/03_shapes_pattern.png: getrennte native Godot-Bilder
  NUR nach erfolgreichem Import und Engine-Test.
- production-report.json und glb-audit.json: reale Export-Metadaten.

Godot-Prototypszene:
res://scenes/learning/nextgen/lumo_learning_stage.tscn.

## Schnittstelle Chat 2 -- Lernaufgaben

Die Godot-Runtime bietet:
configure_lesson(lesson_id), bridge_to_ten(), point_at_object(object_id),
get_counted_amount(), get_target_ids().

Drei verbindliche Szenen:
- math_8_plus_5: exakt 13 zaehlbare Beeren (acht + fuenf).
  bridge_to_ten bewegt zwei der vorhandenen Beeren; IDs und Anzahl
  aendern sich dabei nicht.
- reading_ba_na_ne: drei traegerbasierte Silben Ba, na, ne.
- patterns_circle_square_triangle: acht Formen und ein nicht
  zaehlbares Fragezeichenfeld fuer das naechste Musterobjekt.

Stabile ID-Beispiele: math:8plus5:right:03,
reading:banane:syllable:2, pattern:shapes:item:06.
Fingerzeig und Fokus nehmen IDs statt fester Bildschirmkoordinaten.

## Schnittstelle Chat 4 -- Stimme/Viseme

apply_speech_frame(playback_seconds, viseme, playing) akzeptiert nur
die Taktung des tatsaechlichen Audioplayers, keine generierte Pseudozeit.
Keys: viseme_A, viseme_E, viseme_I, viseme_O, viseme_U,
viseme_MBP, viseme_FV, viseme_L.
Neue Animationsaktionen: learn_idle_breathe, learn_listen, learn_think,
learn_explain, learn_point, learn_nod, learn_unsure, learn_encourage,
learn_celebrate, learn_interrupt, learn_return_listen, learn_farewell.
Dazu bleiben die neun vorhandenen Original-Clips erhalten.

interrupt() stoppt die laufende Mundform sofort. Die Blend-Shapes
belegen fuer sich allein noch KEINE phonemgetreue Lippensynchronisation.
Chat 4 muss die echten Sprach-Timestamps liefern. Die dynamische
Zielmarkierung und Kopf-Ausrichtung belegen auch noch keine exakte
Finger-IK bis zum jeweils gewaelten Objekt.

## Mobile-Budget, Raum und Tests

Skelett: originale 65 Bones; maximal 36.000 Dreiecke inkl. Gesicht;
Export GLB maximal 22 MB; Blender Z-up in Metern, glTF Y-up.
Ein 30-fps-Keyframe-Raster beweist keine Android-FPS.
Render-Vorschauen und native Godot-Frames sind getrennt zu halten.
Eine Fold7-Performance-Messung ist noch gesondert durchzufuehren.

Godot-Runtime-Probe: scripts/tests/lumo_nextgen_chat3_capture.gd
GLB-Binaeraudit: tools/lumo_nextgen_chat3/validate_glb.py.
Nur erfolgreiche Checks belegen den entsprechenden Status.
