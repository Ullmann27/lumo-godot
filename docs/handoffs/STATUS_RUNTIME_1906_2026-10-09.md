# Runtime 1906 – Wiederherstellung 3, 2026-10-09

**VISUAL_GAP / NOT FINISHED. Keine neue APK gebaut oder freigegeben.**

## Tatsächliche Quellstände

| Bereich | Aktuell verifizierter Stand |
| --- | --- |
| Godot Integrationsbranch | `c95fc489219223e3d66e8ed1a7a4dbe933b05f08` |
| Godot Recovery-Code | `8bf9e2a8a3fef1bcdc902af169db4c7caeefe353`, Tree `73caa324a42ce0e8c1c0e33bcfa38c3418ffc535` |
| Godot Recovery-PR | [PR 31](https://github.com/Ullmann27/lumo-godot/pull/31) |
| App Integrationsbranch / BASE | `f6c4f3350db8153200594b52a9d82606279dc238` |
| App Recovery-Code | `4458590063b9e59fc7f36fe9dea4e798b95a192a`, Tree `acf0bf84aae1c1bb197d7a678529bed2466d02e4` |
| App Recovery-PR | [PR 221](https://github.com/Ullmann27/lumo-lernen/pull/221) |
| App-Pin | `ad3ee9c9a1e2cfa60a6d2fe4970181b3150a1a1b`; noch kein finaler 1906-Pin |
| Zuletzt gebauter APK-Inhalt | Historische APK 1905 aus App f6 / Godot ad3; keine 1906-APK |

Die Recovery-Branches sind von der automatischen APK-Pushliste ausgeschlossen.
Main, Releases und die aktiven Integrationsrefs wurden nicht verschoben.

## Geschlossene Ausführungen vor dem dritten Dateiverlust

Diese Zahlen sind tatsächlich beobachtete Ausführungen. Ihre zuletzt erzeugten
Originaldateien waren noch nicht dauerhaft gesichert und sind nach dem Neustart
nicht mehr lokal vorhanden. Es folgt deshalb eine neue Aufnahme; verlorene Dateien
werden nicht als aktuell vorhanden oder neu gehasht dargestellt.

| Prüfung | Beobachtetes Ergebnis | Gegenwärtiger Nachweisstatus |
| --- | --- | --- |
| Identische c95-BASE, 104 Continuity-Bedingungen | 54 PASS / 50 FAIL, Engine1, keine Engine-ERRORs | Originaldateien verloren; neu ausführen |
| Identische c95-BASE, 10 Lifecycle-Bedingungen | 7 PASS / 3 FAIL | Originaldateien verloren; neu ausführen |
| Kandidat headless | 104 + 10 PASS, Engine0, keine ERRORs | Originaldateien verloren; neu ausführen |
| Kandidat GL / OpenGL3 Compatibility | 104 + 10 PASS, Engine0, keine ERRORs/Texturleaks | Originaldateien verloren; neu ausführen |
| TimeFormat | 29 PASS, Engine0 | Originaldateien verloren; neu ausführen |
| Original CompleteFlow 1 | 9 PASS, 16 Tore, ACK, eine Belohnung, 6 echte PNGs, Engine0 | Originaldateien verloren; neu aufnehmen |
| CompleteFlow 2 | Prozess nicht gestartet | NOT EXECUTED: 409 environment_offline vor Prozessstart |
| App Source25 | Autor und unabhängiger Peer je 579 QA + 36 Scriptprüfungen, 0 FAIL/0 SKIP | Quellcheckpoint Git; Peer-Artefakte im gesicherten 185-Paket |
| Vollständiges Native22 / neue APK / Android35/36 | Kein neuer abgeschlossener Lauf | NOT EXECUTED |

Die zuvor gemeldeten GL-Texturleaks wurden mit zwei engen Test-Lebenszykluskorrekturen
belegt behoben: Original-Startup-Environment bis zum letzten Draw halten und vor
dem direkten Case8-Restart auf frame_post_draw warten. Fahrzeug, NoiseTexture,
Renderer, MSAA, Produktionsphysik und alle bisherigen Assert-Bedingungen bleiben
dabei unverändert. Source-Peer bestätigte genau zwei geänderte Testdateien und
858 unveränderte übrige Blobs zwischen 50350 und 8bf9.

Der Produktcode ist SHA256
`7247dd551b900194936d60d31e4436d0e2a9dc74fb4c91e2306d94f6d8689c8c`;
Continuity-Probe
`8129eea26ded1a9ddba71d7cb3dd11f38a12a89d09d89218d726354ec318c245`;
Lifecycle-Helper
`16e7349c0cfa65f0d585c8f528b9fb069b8b3d2069380d0776d83bc90342507f`.

Verlorene aktuelle Lap-JSON: 41072 B,
`a758d959bc9aaed08731796ec9adb2e5fb562ab9c78a4e2aa667e349510ec894`.
Lifecycle-JSON: 2687 B,
`53fd65a18df73bdf22fec1dcfe28844f20b7f12b2425c8e2a773b2c0087237fa`.
Letztere wurde aus der vollständig gelesenen dekodierten Ausgabe kanonisch
rekonstruiert und erreicht exakt Länge und Original-SHA; das ist Byte-Recovery,
keine neue Runtime-Ausführung. Das Lap-JSON und die neuen PNGs müssen neu entstehen.

## Dauerhaft gesicherte und wiederhergestellte Nachweise

Die zwei gespeicherten Archive wurden nach dem dritten Neustart tatsächlich
erneut geladen und auf SHA256, Mitgliederzahl und ZIP-CRC geprüft:

- Runtime-Zwischenstand: 23944311 B, 185 Mitglieder,
  `736b3f7511fb7bddc4117e0eede5f8251b46a3fa7ea38e3a993a36ea2beef89d`.
- Reader02: 71153 B, 23 Mitglieder,
  `977c396e666bdc94aa252c2bae134bb19976717190f64443276b115d5eb2355f`.

Das 185-Paket enthält historische Originalbelege, neue isolierte GPU-Kontrollen,
App-Source25-Peer, Reader02-Peer, Engine-Release-Bytevergleich, tatsächlichen
instrumentierten Finish-Trace und den verworfenen externen Kamera-/Coast-Versuch.
Es enthält **nicht** die neuesten vollständigen 114-/Time29-/Flow1-Aufnahmen.
Der Reader ist vorbereitet, aber kein Beleg eines neuen Native22-Jobs.

## Offene visuelle und Geräteprüfung

Der tatsächlich instrumentierte Finish-Trace zeigt bei ca.55 Grad
Actor-/Road-Abweichung einen auslaufenden Ergebnis-Kart außerhalb der Straße
und eine problematische Sicht auf das Zielbanner. Ein kleiner externer Versuch
wurde verworfen: im normalen Modus erfüllte er nur15/16 Kriterien und überschritt
die Wandgrenze. Kein Experiment wurde in Produktcode übernommen, keine
Grenze aufgeweicht und kein unsichtbarer Teleport ergänzt.

Sonnenhafen-Licht/Materialtiefe, Charakter-/Kamera-Referenztreue und das
Ergebnis-Coast-Verhalten bleiben VISUAL_GAP. Das Nutzer-YouTube-Video ließ sich
nicht mit tatsächlichen Frames abspielen; ein bewegter Referenzvergleich ist
NOT EXECUTED. Physischer Fold, Mehrfinger-Android-Touch, längere Stabilität,
CPU-/GPU-Framezeiten und Geräte-FPS sind NOT EXECUTED. Keine60-FPS-Zusage.

## Nächster konkreter Integrationsschritt

1. Git-Code und gespeicherte Archive unverändert wiederherstellen; neue Engine
   gegen die offiziellen Release-ZIP-/Binary-Digests prüfen.
2. Identische BASE, Kandidat104+10, Time29 und zweimal den unveränderten
   CompleteFlow neu ausführen; striktes Engine0/keineERRORs/keineTexturleaks,
   Originalasserts, eigene Prozessbereinigung und echte PNGs dokumentieren.
3. Neue Raw-Belege vor weiteren langen Schritten sichern. App-Lap-/Lifecycle-
   Fixtures und ihre Produkt-/Probe-/Helper-Bindungen aktualisieren; vollständige
   QA und unabhängigen Source-Peer erneut schließen.
4. Finalen Godot-Quellpin und App-Source konkret integrieren, einmal den
   vorgesehenen APK-Workflow starten und dessen tatsächliche neue APK prüfen.
5. Native22, Android35 und36 samt vollständigem Video-Decoding, Ergebnis-ID,
   ACK/Belohnung, Speichern, Offline-Neustart, Rückkehr und Emulator-Fold bewerten.
   Danach APK nur mit ehrlichem verbleibendem VISUAL_GAP/NOT FINISHED abgeben.

Quellen: vorhandenes Projekt und eigene reproduzierbare Tests; offizielle Godot4.6
RenderingServer-/Environment-/ResourceLoader-Dokumentation für die Test-Cleanup-
APIs, offizielle Godot4.6.3 Release-Bytes für die Engineprüfung. Kein fremder
Code oder fremdes Charakter-/Weltasset übernommen.
