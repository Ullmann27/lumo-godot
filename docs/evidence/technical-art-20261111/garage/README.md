# Garage — echte Vorher-/Nachherbelege, 2026-11-11

Dieses Paket enthält unveränderte Aufnahmedateien aus dem tatsächlichen Godot-Renderer, einen aus tatsächlichen Frames codierten Clip und die abschließenden Eingabeprüfungen. Es enthält keine Konzeptbilder. Produktcode wird durch diesen Evidenzcommit nicht verändert.

## Aufnahmeumgebung und Vergleich

Godot **4.6.3-stable (official)**, Linux, **GL Compatibility**, Mesa **llvmpipe (LLVM 19.1.7, 256 bits)**. Die drei Bildpaare verwenden High-Qualität, denselben Comet mit derselben vorbereiteten Tuning-Auswahl, Seed 2014, Originalanimation `kart_seated` bei 0,3 s, Yaw −0,25, FOV 37° und Kameraposition `(3.2, 2.2, -4.5)`. Die vollständigen Fensteraufnahmen sind jeweils in `before/` und `after/` enthalten; zugehörige `capture.json` bleiben unverändert erhalten.

| Fensterauflösung | Vorher | Nachher | Vorschau-Draw-Calls |
|---|---|---|---:|
| 1280 × 720 | [Bild](before/garage-1280x720.png) | [Bild](after/garage-1280x720.png) | 213 → 147 |
| 412 × 915 | [Bild](before/garage-412x915.png) | [Bild](after/garage-412x915.png) | 207 → 138 |
| 690 × 829 | [Bild](before/garage-690x829.png) | [Bild](after/garage-690x829.png) | 220 → 150 |

[paired-comparison.json](paired-comparison.json) prüft Bild- und Vorschauauflösung, FOV, Position, Animation und Yaw. Eine Kamerabasis-Komponente unterscheidet sich durch Godots Transform-Rundung um höchstens `0.000001`; Position und FOV sind gleich. Die Bilder wurden tatsächlich visuell geprüft. Ein erfolgreicher Renderlauf allein ersetzt keine gestalterische Abnahme.

[selection-camera.mp4](selection-camera.mp4) zeigt 36 tatsächliche Rendererframes mit festem Animationsschritt 1/15 s: Wechsel zu Gecko Velo und anschließende Kameraansichten. Der 2,4-s-Clip wurde mit FFmpeg/H.264 codiert; er ist kein Echtzeit-FPS-Benchmark. Rohframes und zusätzliche Vorschau-Ausschnitte sind bewusst nicht Teil dieses Pakets.

## Quellen: lokaler Commit ↔ veröffentlichter Commit

| Stand | Lokaler Commit | Veröffentlichter Commit | Identischer Git-Tree |
|---|---|---|---|
| Erste Garage-Umsetzung | `b0e8687c48ba815696f7e57f6892184d058ac21b` | `7280343692d490a81f1f245c53957b9edbec4cd3` | `727f24780f0cd5c6ac3288769cc5daa8d8a5d6a6` |
| Finale optische Aufnahme / Kamera-Review | `2d2288dced90b49e8df7a9427f3e5b8be62ba170` | `6e0759be728c130dcff87a170d4bb671aefa60ee` | `b1d637e73c8931ab994530fecda1c51d5670c3c7` |
| Abschließender Eingabefix / Testlogs | `219454c2563582c23a119c2bb29e6a4355a18948` | `ac506cf49f87f18d1420ab329de8d52c17b0e25a` | `e11f453121dd4e8f627af32d39462d556417c74d` |

Die Vorherbilder wurden gegen den lokalen Commit `c9b77eeab3750508268cbff45cde2d0a5ea4ef37` aufgenommen (Tree `fa3387f5fc6d8dee922fe9988b23bc8f862dfc80`). Dessen Unterschied zum geprüften ursprünglichen Godot-Commit `207bfbc5377c0f3e8be800854c83ddf2110ac3f6` besteht ausschließlich aus Dokumentation/Evidenz und `scripts/tests/kart_technical_art_capture.gd`; Produktquellen waren noch unverändert. Für diesen Dokumentations-Zwischenstand wird keine identische veröffentlichte Commit-ID behauptet. Die Bilder entstanden vor der Integration von Sonnenhafen, Garage und Lumo.

Die Nachherbilder und der Clip gehören zum optischen Stand `6e0759be…`. Der nachfolgende reine Eingabefix `ac506cf…` hält projizierte Bedienflächen während der Kamerabewegung bedienbar und synchronisiert deren Treffercache; er ändert diese fest aufgenommenen Fahrzeugauswahlansichten nicht. Die getrennten neuen Lumo- und Sonnenhafenquellen waren in diesem Garage-Worktree noch nicht integriert.

## Abschließende Prüfungen

- [garage-presentation-66.log](garage-presentation-66.log): **66 PASS**, headless. Enthält die bisherigen 64 Prüfungen sowie zwei zusätzliche Kontrollen für sichtbare und tatsächlich treffbare Plaketten während der Kamerabewegung. Display-/Dichtefälle umfassen 1280×720 bei 1,0, 640×360 bei 1,0, 904×2316 bei 2,5 und 2176×1812 bei 2,25. Die projizierten Trefferflächen und die geprüfte 2D-Navigation sind mindestens 48 dp groß.
- [garage-3d-touch-gl-9.log](garage-3d-touch-gl-9.log): **9 PASS im tatsächlichen GL-Renderer**, unveränderte bestehende Prüfung für Ray-Picker, passende Fingerfreigabe, fremden Finger, Ziehen, Abbruch, emulierte Maus und echte Primärmaus. Keine zusätzliche Testwartezeit und keine gelockerte Assertion. Die protokollierten Treiber-/Rendererwarnungen zu VSync, Screen-space AA und volumetrischem Nebel bleiben sichtbar.
- [garage-picker-cause.log](garage-picker-cause.log): gezielter Headless-A/B-Diagnoselauf mit dem echten Garage-Picker. Beim alten Stand bleiben bei Kamerafortschritt 0,147 die Plaketten unsichtbar und der Picker leer, auch nach Pointerbeginn. Im neuen Stand sind vier Ziele sichtbar; `strecke` wird vor und nach dem Pointerbeginn getroffen. Die Diagnose ergänzt den unveränderten GL-Test und ist kein weiterer Hardwaretest.

Die zusätzliche ursprüngliche Fleet-Prüfung erreichte im lokalen Zeitlimit keinen Abschluss und wird nicht als bestanden gewertet. Andere bereits ausgeführte Garagen-Regressionen sind im PR beschrieben, aber ihre Logs sind nicht Teil dieses kompakten Abschlusspakets.

## Grenzen und Integrität

Desktop-Renderer, keine Prüfung auf einem Android-Emulator oder physischen Android-Gerät. Die Draw Calls sind Vorschauwerte dieser festen Ansichten; keine Aussage zu Android-FPS, RAM oder Temperatur. Kein APK und keine Veröffentlichung. Bereits im Original vorhandenes Schuh-/Karosserie-Clipping wird nicht als durch diesen Stand behoben dargestellt.

`checksums.json` enthält Bytezahl, SHA-256 und Git-Blob-ID jeder übrigen Paketdatei. Beim Publizieren wird jede vom Git Data Connector zurückgegebene Blob-ID gegen die lokale Git-Blob-ID geprüft; anschließend wird die vollständige Remote-Tree-ID mit dem lokalen Commit-Tree verglichen. Die Original-PNG-, MP4-, JSON- und Log-Dateien werden bytegleich übernommen.

Reproduktion: `scripts/tests/kart_garage_presentation_capture.gd` aus dem optischen Aufnahmecommit mit dem tatsächlichen GL-Renderer starten, gewünschtes Ausgabeverzeichnis als erstes Nutzerargument übergeben; `--clip` aktiviert die Framefolge auf dem neuen Stand. Für die Originalaufnahme den Helper aus `7280343692d490a81f1f245c53957b9edbec4cd3` als externes Skript gegen die unveränderten 2014-Produktquellen ohne `--clip` verwenden. Seine Aufnahmeparameter sind identisch; der einzige spätere Helper-Unterschied sind die zwei Zeilen des zusätzlichen Dropdown-Bounds-Checks, der ausschließlich zum korrigierten Nachherstand gehört.
