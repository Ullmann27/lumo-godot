# Lumo: erste Phase der bestehenden 3D-Charakteranimation

Stand: 10. Oktober 2026. Dies ist eine echte, isoliert geprüfte Godot-Testintegration eines vorhandenen Lumo, keine neue App und keine ausgelieferte Android-Version. Die erste Phase endet mit diesem einzelnen Kandidaten zur visuellen Abnahme; weitere Fahrer werden nicht automatisch verarbeitet.

## Bestand, Abgrenzung und Auswahl

- **Repositories:** `Ullmann27/lumo-godot` und `Ullmann27/lumo-lernen` sowie ihre offenen Pull Requests wurden geprüft. Grundlage dieses eigenen Branches ist `daaf78b` aus [der vorhandenen Lumo-/Rivalen-Vorbereitung](https://github.com/Ullmann27/lumo-godot/pull/50), nicht ein überschriebenes Arbeitsverzeichnis anderer Agenten.
- **Parallelentwicklung:** Der bestehende Fahrzeugcode, Lerninhalte, Spielstände, Belohnungen, Flutter-Paketkonfiguration und Sulafat bleiben unverändert. Insbesondere [Godot-Spracharbeit #48](https://github.com/Ullmann27/lumo-godot/pull/48) und [Flutter-Spracharbeit #255](https://github.com/Ullmann27/lumo-lernen/pull/255) werden nicht bearbeitet.
- **Modellauswahl:** Verwendet wurde der bereits erzeugte, separate Meshy-Lumo in A-Pose mit orangefarbenem Fell, hellen Wangen, cyanfarbener Brille und L-Rennanzug. In den geprüften Repository-Zweigen wurde kein passender bereits geriggter separater Tripo-/T-Pose-Kandidat gefunden. Das ist keine Aussage über nicht freigegebene Dateien anderer Agenten.
- **Originalschutz:** Die heruntergeladene Smart-Rig-Datei bleibt unverändert unter `source/`. Die erkennbare Figur wurde nicht neu generiert; UVs und Materialien wurden wiederverwendet. Die mobile Ableitung reduziert Geometrie und Texturgröße und bindet die Gesichtsregion starr an den Kopf.

## Meshy, Credits und Lizenz

Der geprüfte Web-Workflow bot Smart Rig ohne Creditkosten an. Die offizielle Web-Preisliste führt Rigging und Animation ebenfalls mit null Credits auf; API-Preise sind nicht mit diesem Web-Workflow gleichzusetzen ([Meshy-Webpreise](https://docs.meshy.ai/en/webapp/pricing)).

Tatsächlich wurde ein Smart Rig für genau den vorhandenen Lumo ausgeführt. Der sichtbare Kontostand blieb bei 155 Meshy-Credits, also null zusätzliche Meshy-Credits für diese Phase; ein vorhandenes kostenfreies Downloadkontingent wurde verbraucht und zwei Downloads blieben angezeigt. Es wurde kein Abo gekauft und keine kostenpflichtige Generierung gestartet.

Im geprüften Smart-Rig-Dialog waren Bibliotheksanimationen ausdrücklich nicht unterstützt. Deshalb wurden die Bewegungen lokal in Blender erstellt, statt einen kostenpflichtigen alternativen Rigging-/Preset-Auftrag zu starten. Die allgemeine Meshy-Anleitung beschreibt T-/A-Pose, Rigging und Animationsexporte; sie ist kein Beleg für präzise Gesichtsanimation dieses konkreten Modells ([Meshy-Animationsanleitung](https://docs.meshy.ai/en/webapp/guides/animate)).

Die vorhandene Free-Plan-Modelllizenz und Namensnennung bleiben erhalten: [Meshy Free Plan](https://help.meshy.ai/en/articles/15696428-what-is-included-on-the-free-plan) und [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Die vollständige Modifikationsnotiz liegt bei `assets/characters/lumo_animated/ATTRIBUTION.md`.

Computer-Credits wurden nicht zuverlässig ermittelt. Es wird keine Einhaltung eines Computer-Creditbudgets behauptet.

## Tatsächlich vorhandene Modellstruktur

| Merkmal | Smart-Rig-Original | Animierte mobile Ableitung |
|---|---:|---:|
| GLB-Dateigröße | 9.819.320 Bytes | 5.156.596 Bytes |
| Dreiecke | 107.386 | 30.000 |
| Echte Meshes | 1 | 1 |
| Skelett / Knochen | 1 / 65 | 1 / 65 |
| Texturen | 3 × 2048² | 3 × 1024² |
| Skin-Einflüsse | maximal 4 | maximal 4 |
| Ungewichtete Mesh-Vertices | 0 | 0 |
| Fehlerhafte Gewichtssummen | 0 | 0 |
| Exportierte Animationsclips | 0 | 9 |
| Gesichts-Shape-Keys | keine | keine |

Die 65 Knochen enthalten Arme, Beine, Kopf, Finger und eine fünfgliedrige Schwanzkette. Blender zeigt beim glTF-Import zusätzlich eine Icosphere als Knochenanzeige an; dieser Display-Helfer zählt nicht zur GLB-Laufzeitgeometrie.

Das GLB enthält 21.659 exportierte Positions-Vertices. Blender zählt 21.658 Mesh-Vertices; die Exportaufteilung ist separat im GLB-Audit erfasst. Animations-Accessor-Daten belegen 40.776 Bytes im Export; dies ist ausdrücklich nicht der gesamte Arbeitsspeicherbedarf der Godot-Animationsobjekte.

Die drei RGBA-1024-Texturen hätten ohne Kompression und ohne Mipmaps zusammen 12 MiB Texeldaten. Dies ist eine Rechengröße, keine gemessene Android-GPU-Speichernutzung.

## Was tatsächlich funktioniert

- **Idle:** Kleine Atem-, Kopf- und Schwanzbewegung aus echten Knochenanimationen.
- **Winken und Jubel:** Hände bewegen sich im exportierten Skelett sichtbar. Die Videos wurden aus tatsächlichen Godot-Frames erstellt, nicht durch KI-Videogenerierung.
- **Weitere Clips:** `point_portal`, `agree_nod`, `kart_seated`, `kart_steer_left`, `kart_steer_right` und `kart_jump` werden geladen und auf gültige Posen geprüft. Es existieren insgesamt neun exportierte Clips.
- **Kart-Test:** Ein neuer, opt-in visueller Adapter setzt den Lumo in das vorhandene Kart. Er übernimmt vorgegebene Geschwindigkeit, Lenkeingabe, Luftzustand und Trefferereignis; er schreibt keine Rennphysik, Kollision, Runden, XP oder Spielstände.
- **Handkontakt:** Die vorhandenen Lenkrad-Anker werden in den Skelett-Raum überführt. CCD bewegt echte Arm-/Schulterknochen ohne Knochenstreckung. In den festen Review-Samples liegt der größte Ankerabstand bei etwa 1,15 mm. Im zuletzt protokollierten kontinuierlichen Lenktest beträgt der größte Abstand 4,39 mm.
- **Finger:** Eine moderate Fingerbeugung ist vorhanden. Die Messwerte beziehen sich auf Hand-Anker, nicht auf kollisionsgeprüften Kontakt jedes Fingers mit dem Lenkrad.
- **Siegesjubel im Kart:** Der obere Körper jubelt, während die Beine ihre wirkliche Sitzpose behalten. Fußpositionen werden separat geprüft. Nach Ende der Bewegung kehrt Lumo zur Sitzpose und zum Lenkradkontakt zurück.
- **Unterbrechung:** Pause stoppt die Animation; unbekannte Clips werden abgewiesen. Der Charakteradapter unterstützt einen Ruhemodus.
- **Ressourcen:** Die GLB-Szene wird einmal geladen und als PackedScene wiederverwendet. Sechs Charakterinstanzen haben getrennte Skelette und Zustände, teilen aber das Mesh.

Der Test liefert synthetische Fahrzeugzustände an die reale visuelle Architektur. Das Sprungbild zeigt eine Körperreaktion bei `airborne=true`, keinen neu implementierten Looping oder gespielten Sprung auf einer Rennstrecke.

## Prüfbelege und Leistung

Die Tests laufen mit Godot 4.6.3, die Bearbeitung erfolgte mit Blender 5.0.1. Die GL-Aufnahmen verwenden den Compatibility-Renderer auf Linux/Mesa llvmpipe. Die erwarteten Warnungen zu VSync, Screen-space-AA und volumetrischem Nebel werden nicht als unterstützte Grafikfunktionen verkauft.

- **Charakter-Regressionslauf:** Export, Skelett, Posen, Handbewegung, Ruhemodus, Unterbrechung, Synchronisationsschnittstelle und sauberes Freigeben. Headless 21 Prüfungen; GL-Lauf inklusive Video 117 Prüfungen bestanden.
- **Kart-Regressionslauf:** Beide Lenkrad-Anker, unveränderte Fahrzeugtransformation/-Skalierung, Pause, echter Jubel, Sitzbeine, Fußpositionen, Rückkehr zum Lenkrad und keine verwaisten Nodes. Headless 379 Prüfungen; GL-Lauf einschließlich Bild-/Videodateien 460 Prüfungen bestanden.
- **CPU-/Mehrinstanztest:** Eine und sechs Instanzen, getrennte Skelette, gemeinsame Mesh-Ressource und 150 Schritte kontinuierlicher Lenkung. Werte und genaue Anzahl stehen in `qa/cpu-benchmark.json`. Der Lauf misst AnimationPlayer-/Bone-Updates und einen visuellen IK-Adapter, nicht GPU-Skinning oder das ganze Rennen.
- **Fehlerprüfung:** Der strikte Runner verwirft auch Godot-Logs mit Skriptfehlern, `ERROR:`, verwaisten ObjectDB-Instanzen oder RID-Leaks. Fehler werden nicht unterdrückt.
- **Statische Bestandsprüfung:** `tools/validate_project.py` meldete 117 PASS, sieben bestehende Warnungen und null FAIL. Sechs Warnungen betreffen die bisherigen Placeholder-Modellpfade, eine die Ausführbarkeit von `build_web_bundle.sh`; diese Bestandsdateien wurden nicht verändert.

Die vorliegenden CPU-Zeiten sind Desktop-/Headless-Messwerte. Sie rechtfertigen keine Aussage zu FPS, Akkulaufzeit oder Ladezeiten auf einem Samsung Galaxy Z Fold. Es war kein physisches Android-Gerät verbunden; kein Android-GPU- oder Samsung-Test wurde ausgeführt.

| Zuletzt gemessener Linux-Headless-CPU-Anteil | Mittelwert | 95. Perzentil |
|---|---:|---:|
| AnimationPlayer / Bone-Update, 1 Lumo | 0,00555 ms | 0,006 ms |
| AnimationPlayer / Bone-Update, 6 Lumos | 0,03179 ms | 0,032 ms |
| 1 Kart-Animationsadapter mit Hand-IK | 0,19897 ms | 0,573 ms |

Der erste Charakteraufbau benötigte in diesem Lauf 103,037 ms; weitere Instanzen 0,183 bis 0,249 ms. GPU-Arbeit, vollständiges Rennen, Flutter und Android sind in diesen Messungen nicht enthalten. Der Mehrinstanz-/CPU-Lauf bestand 165 Laufzeitprüfungen zuzüglich der Prüfung, ob der Bericht geschrieben werden kann.

Reale Belege:

- `qa/meshy-smart-rig.png`: tatsächliches Meshy-Skelett und Creditstand.
- `qa/runtime/`: echte Godot-Frames der neun Clips.
- `qa/kart-runtime/before-procedural-driver.png`: unveränderter bisheriger Fahrer.
- `qa/kart-runtime/seated.png`, `steer-left.png`, `steer-right.png`, `jump-reaction.png`, `hit-reaction.png`, `victory.png`: tatsächlicher neuer Testkandidat.
- `qa/Lumo-Character-Godot-Review.mp4`: Idle, Winken und Jubel, mit 12 Bildern/s aus festen Testzeitpunkten zusammengesetzt.
- `qa/Lumo-Kart-Godot-Review.mp4`: Kart-Reaktionen, mit 15 Bildern/s aus festen Testzeitpunkten zusammengesetzt.
- `qa/character.log`, `kart.log`, `cpu.log`, `character-gl.log`, `kart-gl.log`: tatsächliche Laufprotokolle.

Die Vorschauvideos sind keine Echtzeit-FPS-Messung.

## Gesicht, Sulafat und Flutter: klare Grenze

Dieses Modell enthält keine getrennten Augen-/Lid-Meshes oder Gesichts-Morphs. Natürliches Blinzeln, Blicksteuerung, neue Mimik und Mundformen wurden nicht erfunden. Die vorhandene Gesichtsform und Sprecheridentität bleiben unverändert.

`apply_speech_sample(media_seconds, envelope, speaking)` nimmt eine Wiedergabezeit und einen Pegel entgegen und setzt den Pegel beim Stoppen zurück. Die Schnittstelle ist noch nicht an den produktiven Sulafat-Abspieler angeschlossen; ihr Test nutzt numerische Fixture-Werte. `mouth_supported=false` bleibt bewusst gesetzt. Es gibt weder eine behauptete Lippensynchronisation noch eine heimliche Audioaufnahme.

Für Flutter wurden die bestehende `LumoCharacterController`-Steuerung, echte `cheer()`-/`comfort()`-Reaktionen des Lernbildschirms sowie der vorhandene semantische Interaktionsbus untersucht. Es wurde keine zweite Ereignisarchitektur gebaut. Eine Flutter-Integration und Lern-App-Testansicht wurden in dieser ersten Phase nicht umgesetzt, damit parallele Sprach-/Lernarbeiten nicht verändert werden.

Als ressourcenschonender Anschluss kommt ein vorgerendertes Animationsatlas aus genau diesem geprüften GLB in Betracht, ausgelöst vom vorhandenen Controller. Das ist ein Anschlussvorschlag, keine bereits funktionierende Flutter-Integration.

Es wurde keine neue APK gebaut, kein Android-Paket-/Update-Test für diese Animation ausgeführt und kein produktiver Fahrer automatisch ersetzt.

## Reproduktion und Weitergabe

Aus dem Repository-Wurzelverzeichnis:

```bash
GODOT_BIN=/path/to/Godot_v4.6.3-stable_linux.x86_64 \
  bash tools/lumo_animation/run_phase_one.sh /tmp/lumo-animation-review

blender --background --python tools/lumo_animation/inspect_rig.py -- \
  --input docs/design/2026-10-10-animation/source/Lumo-Meshy-Smart-Rig-Original.glb \
  --output /tmp/meshy-rig-audit.json

blender --background --python tools/lumo_animation/prepare_animations.py -- \
  --input docs/design/2026-10-10-animation/source/Lumo-Meshy-Smart-Rig-Original.glb \
  --output /tmp/lumo-animation-rebuild

xvfb-run -a "$GODOT_BIN" --audio-driver Dummy --path . \
  --rendering-method gl_compatibility \
  --script scripts/tests/lumo_rigged_animation_capture.gd -- \
  /tmp/lumo-character-render --video

xvfb-run -a "$GODOT_BIN" --audio-driver Dummy --path . \
  --rendering-method gl_compatibility \
  --script scripts/tests/lumo_kart_animation_review.gd -- \
  /tmp/lumo-kart-render --video
```

Die editierbare Datei liegt in `editable/Lumo-Animated-Mobile.blend`, das Laufzeitmodell in `assets/characters/lumo_animated/Lumo-Animated-Mobile.glb`. Der Dokumentationsordner ist mit `.gdignore` von der Godot-Ressourcenimportierung ausgeschlossen.

Der eigene Branch lautet `computer/lumo-character-animation-2026-10-10`. Er verändert keine bestehenden Produktdateien; die Testintegration muss bewusst aufgerufen werden. Ein Merge in einen APK-Branch oder ein neuer Source-Pin erfolgt nicht ohne die folgende Integrations-/Geräteabnahme.

## Nächste Phase nach visueller Abnahme

- **Art Direction / Astra Hoch:** Übergänge und Bewegungsbögen verfeinern, Sitzausrichtung an das parallel optimierte Kart anpassen, Ellbogen-/Fingerkontakt und Schwanzfreiheit visuell prüfen.
- **Komplexe Gesichtsarbeit / Astra Sehr hoch nur bei Bedarf:** Bestehende Kopfgeometrie lokal um Augenlider und Mund-Morphs erweitern, ohne die erkennbare Figur zu ersetzen. Erst danach sind aussagekräftige Sprachsynchronisationsversuche sinnvoll.
- **Technik / Sol:** Produktive Fahrzeugereignisse anbinden, bestehenden Flutter-Controller anschließen, reale Sulafat-Wiedergabedaten verbinden und Android-/Fold-Abnahme durchführen. Stimmen, Lernlogik und Spielstände dürfen dabei nicht verändert werden.

Gehen, Einstieg ins Kart, vollständige Denk-/Ermutigungs-/Fragegesten und Gesichtsanimationen sind noch nicht fertig. Weitere Figuren oder kostenpflichtige Meshy-Aktionen werden nicht automatisch gestartet.
