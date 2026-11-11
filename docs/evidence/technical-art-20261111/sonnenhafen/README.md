# Sonnenhafen: echte Renderer-Nachweise vom 11. November 2026

Die Dateien sichern bereits ausgeführte Aufnahmen und Prüfungen. Für diesen
Dokumentationscommit wurde kein neuer Renderer- oder Testlauf gestartet.
PNG-, MP4-, JSON- und Logdateien wurden unverändert übernommen;
`manifest.json` enthält ihre Größen, SHA-256-Werte und Git-Blob-Identitäten.

## Quellstände und Aussagebereich

| Stand | Commit | Bedeutung |
| --- | --- | --- |
| Geprüfte 2014-Basis | `207bfbc5377c0f3e8be800854c83ddf2110ac3f6` | Vorher-Aufnahmen |
| Sonnenhafen-Artstand | `977f120bf586db96250b3f3eb5f2503d2994a8d4` | Hier dokumentierte Sonnenhafen-Implementierung und Aufnahmen |
| Späterer Integrationsstand | `b357b2f8decb4b11b0cc45e9fde2b8df5ec9cbe1` | Godot-PR #152; übernimmt die Art-Implementierung und den Renncontroller-Hook zusammen mit Garage/Lumo |

Die Rennkamera- und Clip-Metadaten nennen den Aufnahme-SHA `977f120…`
ausdrücklich. Die frühere Hafen-Fixture schrieb keinen Commit-SHA in ihr
JSON; ihre Zuordnung zur gleichen Sonnenhafen-Implementierung beruht auf dem
Arbeitsprotokoll. Diese Dateien werden nicht als neue Aufnahmen von `b357b2f8…`
ausgegeben. Die Integration benötigt weiterhin ihre eigenen Fahr-, Android-
und Update-Gates.

Umgebung: Godot 4.6.3, Linux/X11, GL Compatibility, Mesa/llvmpipe
(LLVM 19.1.7). Standbilder: HIGH, 1280 × 720. Das sind echte Spiel-Rendererbilder,
keine generierten Konzepte und keine Messung realer Android-Leistung.

## Vergleich mit den Originalreferenzen

Die tatsächlich zugängliche `Lumo_Referenzmappe_2026-11-03.pdf`, Seiten 16–17,
wurde vor der Gestaltung betrachtet. Diese Seiten sind Gestaltungsvorlagen.

| Bereich | Zustand der 2014-Basis | Originalreferenz | Konkrete Umsetzung | Nachweis |
| --- | --- | --- | --- | --- |
| Straßenseiten | Große, überwiegend glatte Seitenwände | Warmer Hafenort mit cremefarbenen Bögen und blauen Fenstern | Bogenlaibungen, Läden, Fensterbänke und Steinbänder auf straßenseitigen Fassaden | [Rennkamera 60 m](race/race-060m.png) |
| Balkone | Platte und einzelne Stäbe | Durchgehende dunkle Geländer, bepflanzte Kästen | Handläufe, seitliche Rückläufe und Terrakottakästen | [Hafenfassade](harbor/02_harbor_shopfront.png) |
| Erdgeschoss | Einfache Tür- und Markisenformen | Blau-cremefarbene Markisen und warme Ladenfronten | Bögen, Markisenstreben, Lampenflächen und Sockelterrassen | [Hafeneinfahrt](harbor/01_race_camera.png) |
| Materialien | Wenig Fassadentiefe | Zusammenhängende warme Architektur | Vier gemeinsame opake Materialfamilien; vorhandene Häuser, Dächer und Türme erhalten | [GL-Protokoll](logs/streetfronts-gl.log) |
| Bewegung | Bestehende reagierende Hafenattraktionen | Ruhiges, lebendiges Hafenmilieu | Begrenzte Wimpelbewegung mit Annäherung, Rückkehr und kontrollierter Pause | [Sechssekündiger Clip](sonnenhafen-pennants.mp4) |

## Vergleichbare Kameras

Die vier Rennansichten enthalten die echte Rennszene, Lumo, Kart, HUD und
Produktions-Verfolgungskamera an deterministisch gesetzten Positionen.
Capture-Skript, Auflösung, Qualität, Kamera/FOV und Spielertransformation
wurden gegen die Basis verglichen und stimmen für alle vier Ansichten überein.
Es handelt sich um gestellte Rennansichten, nicht um einen gefahrenen Rundennachweis.

| Position | Vorher im Integrationsbranch | Nachher in diesem Paket | Draw Calls vorher → nachher |
| --- | --- | --- | ---: |
| 18 m | [Vorher](../before/race/race-018m.png) | [Nachher](race/race-018m.png) | 350 → 391 |
| 60 m | [Vorher](../before/race/race-060m.png) | [Nachher](race/race-060m.png) | 278 → 313 |
| 110 m | [Vorher](../before/race/race-110m.png) | [Nachher](race/race-110m.png) | 269 → 287 |
| 160 m | [Vorher](../before/race/race-160m.png) | [Nachher](race/race-160m.png) | 250 → 250 |

[Vorher-Metadaten](../before/race/capture.json) und
[Nachher-Metadaten](race/capture.json) enthalten auch Primitive und Transformationen.
Die Zähler zeigen den zusätzlichen Aufwand; sie belegen keine FPS-Verbesserung.

Die beiden Hafenbilder verwenden ebenfalls übereinstimmende Kamera/FOV,
Auflösung und Qualität: [Vorher-Verzeichnis](../before/harbor/),
[Nachher-Metadaten](harbor/capture.json). Das unveränderte Hafen-JSON enthält
zusätzlich zwei damals aufgenommene Riesenradansichten; deren PNGs sind nicht
Teil dieses auf Fassaden konzentrierten Pakets.

## Animation und erfolgreiche Prüfungen

Der Clip enthält 72 echte Rendererframes in sechs Sekunden bei einer
deterministischen 12-Hz-Zeitleiste, 960 × 540. Ein gesetzter Annäherungsreiz
löst vier nahe Wimpel einmalig aus. [Clip-Metadaten](pennant-capture.json)
dokumentieren Kamera und Ereignisse. Die 72 Rohframes werden nicht eingecheckt.

| Prüfung | Unverändertes erfolgreiches Protokoll |
| --- | --- |
| Bestehende LOW/HIGH-Generation, freie Straße, andere Strecken | [Generation](logs/sonnenhafen-generation.log) |
| Tatsächlich eingebautes LOW/HIGH-Mesh, Materialbudget, keine Collider, alle projizierten Punkte gegen Straßenabstand | [World](logs/streetfronts-world.log) |
| Echte GL-MultiMesh-Bewegung, einmaliger Trigger, exaktes Einfrieren bei Pause/reduzierter Bewegung, Rückkehr und erneuter Eintritt | [GL](logs/streetfronts-gl.log) |
| Opake Materialien, Geometriegrenzen und räumliche Zellen | [Headless](logs/streetfronts-headless.log) |

Der World-Test prüft 26.256 LOW- und 72.864 HIGH-Punkte. Die kleinsten
Abstände zu den vorhandenen Straßensamples betragen 12,3149 beziehungsweise
12,3151 m bei unverändert geforderten mindestens 7 m. HIGH ergänzt 95.196
Architekturdreiecke in 24 Materialoberflächen, LOW 35.676 in 20 Oberflächen.
Die Originalgrenze von 1.400 generierten Instanzen bleibt erhalten.

Die GL-Logs bewahren auch die Warnungen des Softwaretreibers und der
vorhandenen nicht unterstützten Rendereroptionen. Keine Protokollzeile wurde
entfernt. Physische Android-/Fold-Messungen, Temperatur und Geräte-RAM werden
mit diesem Paket nicht behauptet.
