# Additiver52er-Native-Gate für Face, C4 und Treasure

## Fester Quellenstand

Ausgang ist der tatsächliche48er-Runner auf Native `27ae427029a5199699c95a79a84b0027d7571752`, Tree `c389c0de01d9a6ca9fd6e9332fafdf2dedbc8153`. Dieses Paket ergänzt ausschließlich fünf Source-/Testdateien. Die16 Produkt-/Probedateien aus PR167 liegen in einem getrennten, unveränderten Freeze (`adebc079…`).

Maßgeblicher Gatefreeze ist `source-freeze-v2.json`. Gegenüber dem erhaltenen v1 korrigiert v2 ausschließlich den Ziel-Gitmodus des vorhandenen Shellrunners auf100755; sämtliche Quellbytes und Git-Blobs sind gleich. Die Pythondateien bleiben100644. `integration.patch` besteht die reine Anwendbarkeitsprüfung.

| Datei | Änderung |
|---|---|
| `tools/validate_nextgen.sh` | Vier zusätzliche Modi, Face-Ausgabeverzeichnis, echter Movie-Collector und verbindlicher neuer Raster-/Sidecarabschluss |
| `tools/verify_studio_2020_rasters.py` | Strenge Nachrechnung aller16 neuen Bilder, drei Reports, Original-AVI/MP4, ffprobe und Laufprotokolle |
| `tools/verify_village_rasters.py` | Ausschließlich optionales `write=True`; der vorhandene Decoder bleibt inhaltlich erhalten |
| `tools/tests/test_nextgen_runner.py` | Erweiterte synthetische Orchestrierungsfixtures und additive52er-Gegenfälle; vorhandene Assertions bleiben |
| `tools/tests/test_studio_2020_rasters.py` | Hashgebundene Originalreport-/Statebytes, ausdrücklich synthetische Bilder/Movie-Transports und gezielte Negativfälle |

Die ersten48 vollständigen Aufrufzeilen einschließlich Marker, Modus und Argumenten sind bytegleich erhalten. Keine bestehende Frist, Fehlerausnahme, Rendererbedingung oder Rasterpflicht wird verändert. Der alte eigenständige Studio-Runner bleibt ebenfalls unverändert.

## Aufruf und Bericht

Der Produktionsaufruf bleibt:

```bash
LUMO_NEXTGEN_LOG_DIR=<evidence>/nextgen bash tools/validate_nextgen.sh
```

Der Caller muss alle52 konkreten Paare aus `gate-contract.json` verlangen. Ein Erfolg erfordert außerdem die weiterhin vorhandenen vier Rastermanifeste und den neuen `studio-2020-images.json`:

- `renderer-images.json`: bestehende24Studio-Bilder;
- `village-images.json`: bestehende4Village-Bilder;
- `puzzle-menu-images.json`: bestehende6Puzzle-Menü-Bilder;
- `safe-area-images.json`: bestehende7Safe-Area-Bilder samt Originalsidecars;
- `studio-2020-images.json`: neue16Bilder, drei Originalreports und ein vollständiger Moviebeleg.

Die sechs separaten Touch-Modi samt32Bildern und der reale C4-Dart/Godot-Zweiprozesslauf bleiben eigenständige zusätzliche Pflichten.

Der neue kombinierte Abschluss lautet `[LumoNextgen52] PASS`; auch der bestehende `[LumoNextgen] PASS` wird nur nach dem vollständigen erfolgreichen Abschluss ausgegeben. Fehler in neuen Probes verhindern beide Marker, während andere unabhängige Probes weiterhin ihre Originale sammeln können.

## Vier zusätzliche Modi

| Probe | Modus / Einzelbudget | Originale |
|---|---|---|
| `lumo_facial_regression` | Headless /180s | Exakter102er-Marker, tatsächlich importierte Meshes |
| `lumo_facial_capture` | Renderer /420s |8PNG640×640,144Originalmesszeilen, MovieMaker-AVI, geprüfter Film |
| `connect_four_visual_capture` | Renderer /600s |4PNG, `visual-state.json` |
| `treasure_title_contrast_regression` | Renderer /600s |4PNG, `treasure-title-report.json` |

Der C4-Capture liest seine Revisionsangabe aus `GITHUB_SHA`. Im Hostbuild wäre dies sonst die Hostquelle. Deshalb setzt nur dieser neue Probeaufruf die Variable lokal auf den bereits geschriebenen tatsächlichen Native-Stempel `source-sha.txt`. Nach dem Funktionsaufruf bleibt der umgebende Hostwert unverändert. Der neue Nachrechner verlangt die Übereinstimmung der C4-Reportrevision mit dem Native-Stempel.

## Reine Publisher-Nachrechnung

Die API ist:

```python
result = verify_studio_2020_rasters.verify(root, write=False)
```

Sie schreibt weder den neuen Gesamtbericht noch die drei Teilrastermanifeste. `write=False` wird bis in den vorhandenen vollständigen PNG-Decoder durchgereicht. Der Standard `write=True` erhält dessen bisheriges Verhalten.

Die CLI prüft zusätzlich den unveränderten ursprünglichen Gesamtbericht gegen die frische Berechnung:

```bash
python3 tools/verify_studio_2020_rasters.py verify <evidence>/nextgen --read-only
```

`studio-2020-images.json` enthält:

- `schema:1`, `kind:"studio_2020_extension"`;
- `source.commit`, `source.tree` und die Byte-/Hashbindungen der drei vorhandenen Source-/Tree-/Cleanstempel;
- `images[16]`, jeweils Pfad, physische Größe, Bytezahl und SHA256 sowie die zugehörige Originalreport-/Moviebindung;
- `reports[3]`: Facial-Runtime, C4-Visualstate und Treasure-Titelbericht;
- `movies[1]`: Original-AVI, kodiertes MP4, Movieproof, originales ffprobe-JSON und die Original-Encode-/Decode-/Stderrprotokolle.

Alle Pfade im Bericht sind relativ zum übergebenen Evidenzstamm. Für den reinen Replay sind Python, Pillow und der vorhandene PNG-Helper notwendig; der Replay kodiert keinen Film neu.

## Movie- und Sidecarprüfungen

Der Runner ruft den Collector ausschließlich nach dem erfolgreichen echten Facial-Capture auf:

```bash
python3 tools/verify_studio_2020_rasters.py collect-face-movie <face-capture-dir>
```

Der Collector benötigt `ffmpeg` mit H.264/AAC-Unterstützung und `ffprobe`. Er überschreibt keine vorhandenen Moviebelege, erhält das ursprüngliche AVI, kodiert das MP4, dekodiert den gesamten Film mit `-xerror` und speichert den vollständigen ffprobe-Ausgang. Die drei vorhandenen Producer-Kommandobudgets von jeweils90s bleiben. Ein Fehler oder eine leere/trunkierte Nutzlast erzeugt keinen erfolgreichen Movieproof.

Alle70 veröffentlichten Sidecarbedingungen aus den drei Producer-Funktionen wurden als explizite `require`-Prüfungen übernommen. Es gibt keine durch `python -O` abschaltbaren Runtimeasserts. Hinzu kommen die vollständige wiederverwendete PNG-Dekodierung, Quellenbindung, reguläre Originaldateien ohne Symlinks, saubere Movie-Logs und eine reine Replay-Schnittstelle.

Geprüft werden unter anderem144 geordnete Originalschritte, tatsächliche Jaw-/Lidwerte und wechselnde Playbackpositionen, geschlossener Kiefer in Mute-/Stoppintervallen, die tatsächlichen Movie-/Audiostream-Metadaten, alle vier C4-Zustände mit vollständig exponierten Zielen sowie alle vier Treasure-Profile mit Kontrast-, Größen-, Insets- und Originalbildbindung. Diese Nachrechnung ist keine neue Anwendungsausführung.

## Tatsächlicher enger Testabschluss auf 7e03

Root hat die 16 PR167-Produkt-/Probedateien und die fünf Gate-Dateien als `7e03f1113073e2f941b052028a649aa144eefe64`, Tree `a79d41272a55b1bf1ffb82e656ea34556b3a0a83`, veröffentlicht. Vor und nach dem fokussierten Lauf wurden alle 21 Quellblobs samt Gitmodus sowie alle 12 Dateien im isolierten Prüfbaum exakt an dieses Gitobjekt gebunden. Der veröffentlichte Arbeitsbaum blieb sauber; alle fünf eingefrorenen Gate-Dateien blieben unverändert.

Der tatsächliche Befehl war `python3 -m unittest -v test_studio_2020_rasters test_nextgen_runner test_safe_area_rasters`. Er bestand am 14. November 2026 mit **41 Tests, 0 Fehlern, 0 Fehlschlägen und 0 Skips** in 109,394 Sekunden. Der vollständige ungekürzte Log und die Ausführungsdaten liegen unter `local-tests/`; `focused-validation.json` bindet deren Originalbytes und den Quellenvergleich.

Die Tests prüfen den Shellrunner mit ausdrücklich synthetischen Godot-/ffmpeg-Adaptern, die 52 festen Modi, die unveränderten früheren 48 Aufrufe, die bestehenden Safe-Area-Verträge und die vollständige PNG-/Report-/Movie-Nachrechnung. Eingebettete ursprüngliche Face-/ffprobe-/Treasure-Reports und C4-Statebytes werden anhand ihrer Originalhashes geprüft; Bild- und Moviehüllen der lokalen Tests sind synthetische Transportfixtures. Der reine Publisher-Replay ist gegen unbeabsichtigte Schreibzugriffe abgesichert.

Es lief kein Godotprojekt, Import, echter Renderer, Androidgerät oder MovieMaker. Weder diese Tests noch das 24-FPS-Aufnahmeformat begründen eine visuelle Freigabe, Zielgeräte-FPS, hörbare Sprache oder den tatsächlichen C4-Zweiprozess-/Speichererfolg. Diese getrennten Abnahmen bleiben erforderlich.

Der während des Abschlusses gemeldete Producer-Nachtrag `acf51d3bd2997c4b731e9a48e1791e05e756a132` ist **nicht** Bestandteil dieses 7e03-Nachweises. Dessen Importdefaults, getrennte Original-/Facial-Modellbindung und MovieMaker-Fensterkorrektur werden in einem neuen Folgepack geprüft. Dieser Abschluss und seine Originale bleiben unverändert erhalten.
