# LUMO Kart – Blender-Modelle und geprüfte Godot-Exporte

Dieses Paket liefert bearbeitbare LUMO-Kartgrafik, zugehörige Godot-Dateien und
eine eigenständige Prüfszene. Die Quellen und Exporte sind im selben Repository
enthalten. Die endgültige Inventarliste mit SHA-256, Dateigrößen, Polygonzahlen,
Materialien, Animationen und Prüfbelegen steht in
[release_manifest.json](release_manifest.json).

## Umfang

| Bereich | Bearbeitbare Blender-Dateien | Godot-GLBs | Inhalt |
| --- | ---: | ---: | --- |
| Karts | 3 | 9 | Comet, Glider und Aurora GT/Turbo, jeweils LOD0/1/2 |
| Fahrer | 5 | 15 | Löwe, Eule, Hase/Nova, Eichhörnchen und Schildkröte, jeweils LOD0/1/2 |
| Tunnel | 11 | 385 | Je sieben Module, Hauptstufe, LOD1, Kollisionshülle und Landschaftsdecke in zwei Detailstufen |
| **Gesamt** | **19** | **409** | Materialien und benötigte Texturen enthalten |

Die elf Themen sind Zauberwald, Bergwelt, Holo-City, Kristall-Canyon,
Dschungel-Tempel, Candy Cloud, Volcano Night, Winter Sprint, Galaxy Ringway,
Desert Drift und Learning Lab. Sonnenhafen und der vorhandene Original-LUMO
bleiben Referenzen des Projekts.

Die sieben Tunnelmodule je Thema sind Eingangsportal, Ausgangsportal,
12-Meter-Gerade, Links- und Rechtskurve mit 36 Metern Radius und 30 Grad
Richtungsänderung sowie ein abfallender und ein ansteigender Übergang.

## Dateien öffnen

- [Blender-Quellen](../../../art/lumo_kart/blender/)
- [Godot-Modelle](../../../assets/kart/production/)
- [Kartmaße, Lenkung und Fußraum](karts/README.md)
- [Fahrerrig, Posen und Herkunft](drivers/DRIVER_CONTRACT.md)
- [Tunnelanschlüsse, Fahrfreiraum und Collision](tracks/CONNECTION_CONTRACT.md)
- [Godot-Import und vollständige Animationskanäle](GODOT_IMPORT.md)
- [Herkunft der neuen Arbeit](PROVENANCE.md)

Blender 4.3.2 hat die Autoren-Dateien erzeugt und erneut geöffnet. Die
Godot-Prüfungen verwenden 4.6.3. Die selbstständige Review startet aus dem
Repository-Wurzelordner mit:

```sh
godot --path tools/lumo_kart_art/review
```

Pfeiltasten wechseln zwischen Ansichten. „Prüfbilder“ erzeugt die gesamte
Bildserie, „Kamerafahrt“ eine Bildfolge aus der fahrenden Tunnelkamera.
Die Szene zeigt die tatsächlichen GLBs und läuft unabhängig vom Rennspiel.

## Sichtbare Belege

Die Bilder liegen unter [evidence/lumo_kart_art](../../../evidence/lumo_kart_art/).
Blender-Stills zeigen die Autorenmodelle. Die gesonderte Godot-Serie zeigt
deren tatsächlichen Import, einschließlich Rückansichten, Unterseite,
Lenkposen, Rennkamera, Tunnelinnenräumen und Modulübergängen.

| Vorschau | Inhalt |
| --- | --- |
| [Kartvideo](../../../evidence/lumo_kart_art/review/lumo_aurora_karts.mp4) | Alle drei Varianten, Kameraumlauf, vier rollende Räder, Vorderachslenkung und Lenkrad |
| [Fahreranimationen](../../../evidence/lumo_kart_art/review/lumo_driver_animations.mp4) | Die sechs Hasenclips und die vier weiteren Fahrer in der gemeinsamen Kartpose |
| [Tunnel-Kamerafahrt](../../../evidence/lumo_kart_art/review/lumo_zauberwald_flythrough.mp4) | Gerade und anschließende R36-Kurve aus 2,52 Metern Kamerahöhe |

Die MP4s bestehen aus einzeln aufgenommenen Godot-Renderframes. Ihre
24 Bilder pro Sekunde sind die Wiedergaberate des Videos. Sie sind keine
Messung der Echtzeitbildrate auf Android. Die Aufnahmebelege nennen den
tatsächlich verwendeten Software-Renderer, Framezahlen und Quelldateihashes.
Das kompakte Fahrervideo durchläuft längere Clips beschleunigt; die
vollständigen Animationszeiten bleiben in den GLBs erhalten.

## Was geprüft wird

Die Prüfung beginnt bei den gespeicherten Dateien. Sie verlässt sich nicht
allein auf die Werte des Generators.

| Beleg | Tatsächliche Prüfung |
| --- | --- |
| `review/final_glb_audit.json` | GLB-Struktur und Accessoren, endliche Geometrie und Normalen, Nullflächen, Skin-Gewichte, eingebettete Texturen, veränderliche Animationskanäle |
| `review/blender_sources.json` | Erneutes Öffnen aller 19 `.blend`-Dateien, editierbare Meshes und Rigs, verfügbare Bildabhängigkeiten |
| `review/final_godot_import.json` | Import und Instanziierung aller 409 GLBs in Godot, Materialien, Skeleton3D und tatsächliche Auswertung aller Fahrerclips |
| `review/godot_driver_kart_fit.json` | Alle fünf Fahrer und drei Karts, vier Fahrposen, drei Zeitpunkte, Hände gegen bewegte Lenkradgriffe und Füße gegen feste Kontaktmarker |
| `review/godot_collision_contract.json` | Verbinden realer Modulsockets und Godot-Physikstrahlen gegen freie Fahrspur, Dach und beide Wände |
| `karts/export_validation.json` | Kart-LODs, UVs, Geometrie, mechanische Knoten und sieben bewegliche Animationskanäle |
| `karts/rabbit_boot_clearance.json` | Ausgewertete Stiefeldreiecke gegen die Karosserie in 72 Fällen |
| `karts/driver_appendage_clearance.json` | Ausgewertete Schwanz-/Panzergeometrie gegen die drei Sitz-/Kartvarianten |
| `karts/driver_torso_clearance.json` | Untere Anzug-/Gürtelflächen in 300 Fahr-/Kartfällen mit 600 getrennten Komponentenprüfungen |
| `tracks/<theme>/blender_reimport_verification.json` unter den Assetdateien | Unabhängiger GLB-Reimport, geschlossene Geometrie, UVs, Sockel und tatsächlicher Freiraum für alle 21 Dateien des Themas |
| `tracks/<theme>/terrain_blender_verification.json` unter den Assetdateien | Erneuter Import, Nahtgeometrie und Fahrfreiraum der 14 Landschaftsdecken-Exporte je Thema |

Die sechs Fahrerclips heißen `idle`, `kart_seated`, `kart_steer_left`,
`kart_steer_right`, `kart_jump` und `celebrate`. Sie bewegen ein echtes
21-Knochen-Rig. Beim Import müssen feste Rückstellkanäle erhalten bleiben;
die Einstellung und ihr gemessener Fehlerfall sind in `GODOT_IMPORT.md`
dokumentiert.

Der endgültige Stand besteht die 409 GLB-Prüfungen, die 409 tatsächlichen
Godot-Importe und das erneute Öffnen aller 19 Blender-Quellen. Im
[Kontaktbericht](../../../evidence/lumo_kart_art/review/godot_driver_kart_fit.json)
liegt die größte gemessene Hand-/Fußabweichung der 720 Stichproben bei
0,721 mm; die Prüfgrenze beträgt 10 mm. Diese Messung gilt für die
dokumentierten Clips und Zeitpunkte. Anhänge und untere Anzugflächen
bestehen jeweils 300 dynamische Fahrer-/Kartfälle, die Hasenstiefel 72 Fälle.

Die finale Godot-Serie enthält 63 Bilder: Fahrer, Karts, elf Themen mit
jeweils Innenraum, Kurvenanschluss und vollständiger Portal-/Geländekette
sowie die Sonnenhafen- und Terrainnormalen-Vergleiche. Alle 33 Themenbilder
wurden auch visuell angesehen. Das Vergleichsbild der Terrainnormalen zeigt
die beseitigte dunkle Modulnaht bei gleicher Geometrie. Die drei MP4s
enthalten 96, 144 und 312 tatsächlich aufgenommene Renderframes
(Tunnel, Karts und Fahrer).

## Übergabe an die Spielintegration

Ausgangsstand ist Commit
`9f8341494ea316c9e36ed6722915ab34b22e67bd` auf
`integration/lumo-complete-native-20261114-7a1`. Die Arbeit liegt auf dem
eigenständigen Branch `art/lumo-blender-production-20261114-eb2882`.

Die ursprünglichen `kart_world.gd`, `kart_vehicle.gd`, `kart_island.gd`, die
Rivalen-Rosterdatei und beide Original-LUMO-GLBs werden gegen diesen
Ausgangsstand per Hash verglichen. Diese Lieferung setzt keinen
`runtimeReady`-Schalter und verändert keine Hauptszene.

Das Hauptteam kann die Modelle über den beigelegten
`tools/lumo_kart_art/asset_contract_loader.gd` laden und Tunnel über ihre
Sockets verbinden. Fahrer und Karts teilen denselben Fahrzeugursprung;
eine bereits sitzende Fahrerpose darf nicht zusätzlich um die Sitzhöhe
verschoben werden. Für die Fahrsteuerung werden die Demonstrationsclips
der Karts gestoppt und die dokumentierten Rad-/Lenkknoten an den echten
Fahrzustand angeschlossen.

Tunnel benötigen die passende Fahrbahn und Geländeoberfläche. Die
Höhenübergänge sind feste Geometrie mit definiertem Profil. Die gesonderte
Kollisionshülle wird als konkave statische Form eingesetzt, damit die
Durchfahrt offen bleibt. Beleuchtung lässt sich an den exportierten
LightSocket-Markern befestigen; sichtbare Emission allein beleuchtet
den Tunnel nicht automatisch in jedem Renderer.

Die Umschaltung der LODs, Material-Batching, die Gegnerzuordnung und ein
Profiling des vollständigen Rennens auf dem Fold7 gehören zum anschließenden
Integrationsschritt. Dieses Paket enthält keinen neu geprüften APK-Build und
keinen Nachweis stabiler 60 FPS auf einem physischen Android-Gerät.

## Prüfungen reproduzieren

```sh
python tools/lumo_kart_art/audit_glb.py --root . --output evidence/lumo_kart_art/review/final_glb_audit.json
blender -b -t 1 --python-exit-code 1 --python tools/lumo_kart_art/verify_blend_sources.py -- --root .
godot --headless --path tools/lumo_kart_art/review --script verify.gd
godot --headless --path tools/lumo_kart_art/review --script contract_probe.gd
godot --headless --path tools/lumo_kart_art/review --script fit_probe.gd
python tools/lumo_kart_art/build_release_manifest.py
```

Für Renderbilder ist eine grafische Godot-Sitzung erforderlich. Die
`--capture`, `--movie=karts`, `--movie=drivers` und `--movie=tunnel`-Optionen
der Review erzeugen die dokumentierten Aufnahmen. `encode_previews.py`
kontrolliert die Framehashes, kodiert H.264 und prüft das fertige Video
mit FFprobe. Generatoren und detaillierte Reproduktionsbefehle stehen in
den jeweiligen Bereichsdokumentationen.
