# Native703: abgeschlossener Quellencheckpoint

Dieser Checkpoint gehört ausschließlich zu **703a8f3ff7714d079223c7f0a03ab2400ba6a36a**, Tree **049c8a5be914b9babad0e9af8712ada777e5a077**. Er bewahrt die abgeschlossene technische Abnahme und ausgewählte tatsächlich durchgeführte Bildsichtungen. Er ist **keine vollständige visuelle Freigabe** und keine Android-/APK-Freigabe.

## 15 erfolgreiche Workflows

Die unveränderte GitHub-API-Antwort `metadata/all-workflow-runs.json.gz` enthält genau **15 Workflow-Runs für diesen Head**, sämtlich `completed` / `success`. Das ist von den acht Jobs innerhalb des Nextgen-Workflows getrennt zu lesen. Abfragezeit: 2026-11-13,15:54:14 UTC.

| Workflow | Run | Ergebnis |
|---|---|---|
| Verify committed Kart vehicle geometry | [43452287015](https://github.com/Ullmann27/lumo-godot/actions/runs/43452287015) | success |
| Lumo original 65-bone grounded walk gait QA | [43452283890](https://github.com/Ullmann27/lumo-godot/actions/runs/43452283890) | success |
| Verify Lumo Kart Stage 2 | [43452283988](https://github.com/Ullmann27/lumo-godot/actions/runs/43452283988) | success |
| LUMO Next Generation 2018 native acceptance | [43452284466](https://github.com/Ullmann27/lumo-godot/actions/runs/43452284466) | success |
| Lumo Kart and Bauwelt integration QA | [43452283720](https://github.com/Ullmann27/lumo-godot/actions/runs/43452283720) | success |
| Lumo Kart dynamic neon surge event inside real race | [43452283721](https://github.com/Ullmann27/lumo-godot/actions/runs/43452283721) | success |
| Sonnenhafen hero flight actual Godot regression | [43452283622](https://github.com/Ullmann27/lumo-godot/actions/runs/43452283622) | success |
| Lumo native lifecycle and Bauwelt play proof | [43452283792](https://github.com/Ullmann27/lumo-godot/actions/runs/43452283792) | success |
| Lumo Sonnenhafen 2003 real bird eye and jump QA | [43452283668](https://github.com/Ullmann27/lumo-godot/actions/runs/43452283668) | success |
| Lumo Kart deterministic resonance racing gameplay | [43452283571](https://github.com/Ullmann27/lumo-godot/actions/runs/43452283571) | success |
| Lumo Next Gen visual smoke and real Kart screenshots | [43452283790](https://github.com/Ullmann27/lumo-godot/actions/runs/43452283790) | success |
| Lumo Kart Rival Feedback | [43452283749](https://github.com/Ullmann27/lumo-godot/actions/runs/43452283749) | success |
| Lumo Kart Video Reference Grade | [43452283646](https://github.com/Ullmann27/lumo-godot/actions/runs/43452283646) | success |
| Sonnenhafen 2027 stunt integration | [43452283760](https://github.com/Ullmann27/lumo-godot/actions/runs/43452283760) | success |
| LUMO Kart world, home and driving graphics | [43452283809](https://github.com/Ullmann27/lumo-godot/actions/runs/43452283809) | success |

## Vollständige Nextgen-Abnahme

Der originale [Nextgen-Lauf 43452284466](https://github.com/Ullmann27/lumo-godot/actions/runs/43452284466), Ereignis `pull_request`, Versuch 1, hat alle sieben Pflichtjobs und den anschließenden Archivjob erfolgreich abgeschlossen. Deren endgültige Run-/Jobs-/Artefakt-Metadaten sind unverändert unter `metadata/` erhalten; alle acht ungekürzten Joblogs stehen verlustfrei komprimiert unter `job-logs/`.

| Bestandteil | Tatsächlich nachgewiesen |
|---|---|
| Kern | 37 eindeutige Probe/Modus-Paare, alle PASS |
| Studio-Raster | 24 exakte Original-PNG, Pfade, Größen, Bytezahlen und SHA256 geprüft |
| Touch | 6 eindeutige Probe/Modus-Paare, alle PASS |
| Touch-Raster | 28 Original-PNG: Werkstatt 6, Schatz 14, Bauwelt 8 |
| Quellen | Vier aktuelle Capture-Trees exakt 049c8a5…; sämtliche erforderlichen Dirty-Stamps leer |
| Gesamt-ZIP | 132 PNG: 122 aktuelle und 10 ausdrücklich getrennte historische Baseline-Bilder |
| Rohlogs im Gesamt-ZIP | 96 ohne ERROR-, Script-/Parsefehler oder ObjectDB-/Leaked-instance-Zeilen |

Die beiden integrierten Bauwelt-Reparaturen sind erstmals auch im tatsächlichen Renderer nachgewiesen: **BuildPlay 70 PASS** nach den unveränderten 62 Headless-Assertions und **DialogDensity 1656 PASS** nach 1637 Headless-Assertions. Die vier ursprünglich gescheiterten BuildPlay-Assertions wurden erhalten. Der Dialog-Log zeigt beide betroffenen nativen Desktop-Übergänge mit `hovered=false` vor und `hovered=true` nach der Pointer-Vorbereitung, vor demselben echten ScreenTouch. Die vollständigen ursprünglichen Protokolle sind `new-worlds-job-131977254690.log.gz` und `touch-build-job-131977255197.log.gz`.

Der unveränderte bestehende Host-Verifier aus `f80fe6b3d6a3c58c89f8507853dcbfc15a84525e` prüfte das feste Profil `nextgen-2019` erfolgreich. Sein Blob ist `55f600365a5158e3deca8514a88f952a7608547d`, SHA256 `074fa561e078b56476f539827db516e27a815104d51b74ea898644a1cb0bba8a`. Die Hashbelege der vier unveränderten Verifiermodule und der 13 maßgeblichen Native-Dateien stehen unter `source-hashes/`. Letztere wurden erneut an den unveränderlichen Git-Objekten des treegleichen lokalen Commits `a76f26b1d19662f6429a9cff063991e994d1e19a` geprüft.

## Öffentliche unveränderte Originalquelle

[Archivtag und Release](https://github.com/Ullmann27/lumo-godot/releases/tag/integration-evidence-703a8f3ff7714d079223c7f0a03ab2400ba6a36a-14054081246) · [Originales native-evidence.zip](https://github.com/Ullmann27/lumo-godot/releases/download/integration-evidence-703a8f3ff7714d079223c7f0a03ab2400ba6a36a-14054081246/native-evidence.zip).

- Actions-Artefakt: 14054081246; Prerelease: 444416762; ZIP-Asset: 744207951.
- Quelltag: `integration-evidence-703a8f3ff7714d079223c7f0a03ab2400ba6a36a-14054081246`, exakt auf 703 gerichtet.
- ZIP: 163275110 Bytes; SHA256 `c3c0b856b3236c7288640cf27f390833b7cf9f2ac3b49ee32a4fff922ada898e`.
- Der lokale ursprüngliche Actions-Download, veröffentlichte Assetdigest und die Größe stimmen überein. Der erfolgreiche Archivjob enthält zusätzlich den öffentlichen erneuten Download samt unverändertem `cmp`.

ZIP und PNG sind nicht in diesem Git-Verzeichnis dupliziert. `original-handoff/review-index.json.gz` und die ursprünglichen Verifikationsberichte erhalten Bildpfade, Größen und Hashes; deren damalige Scratch-Pfade bleiben als historische Daten unverändert. Die GitHub-Artefakt-IDs und ursprünglichen Digests der getrennten Preview-/Legacy-ZIPs sind ebenfalls erhalten. Der gespeicherte Python-Sammler dokumentiert die damals ausgeführte Prüfung; die Original-ZIP-Dateien bleiben externe Eingaben.

## Tatsächlich gesichtete Bilder und Grenzen

Root hat ausgewählte 703-Bilder tatsächlich geöffnet. Die beiden unveränderten Beobachtungsdateien unter `observations/` nennen vier konkrete Bilder mit Originalhashes und begrenzten Befunden: Mathematikstart im Hochformat, abgeschlossene Pflanzenteile, BuildPlay-Walking und `bridge_hundred-complete-2400x1080.png` aus Preview-Artefakt 14053671218. Bei letzterem erscheint das obere beabsichtigte **`=` als zusammenhängender heller Block; zwei getrennte Balken sind nicht erkennbar**. Das untere Gleichheitszeichen ist getrennt erkennbar. Dieser dokumentierte visuelle Mangel verhindert eine Behauptung vollständiger visueller Freigabe des703-Stands.

Der veröffentlichte Studio-Nachfolger 76980a mit korrigierter Gleichheitsausrichtung, zusätzlichem Bauwelt-Gestenschutz und zwölf Build-/insgesamt 32 Touchbildern benötigt seine eigene frische kombinierte Abnahme. Die 703-Ergebnisse, Bilder und der alte 8-/28-Rastervertrag werden nicht auf ihn übertragen. Auch der saubere 703-Gameplay-Lauf ist kein behaupteter Quellfix des separat berichteten Producer-Lasso-Teardownfehlers.

## Verlustfreie Speicherung

`manifest.json` ordnet jedes erhaltene Original seiner gespeicherten Datei zu: Originalgröße und SHA256, Speichergröße und SHA256 sowie verlustfrei geprüfte gzip-Dekompression. Original-JSON und Handoff-Inhalte wurden nicht normalisiert, gekürzt oder redigiert. Alle acht Joblogs sind vollständig und ohne Fehlerfilter erhalten. Große Originalberichte und die 15-Workflow-Antwort sind ebenfalls gzip-komprimiert. `SHA256SUMS` schützt zusätzlich alle Dateien dieses Packs einschließlich des Manifests.
