# Abgeschlossene Native-Abnahme des reparierten Stands 703a8f3

Der originale Nextgen-Lauf [43452284466](https://github.com/Ullmann27/lumo-godot/actions/runs/43452284466) hat alle sieben Pflichtjobs und den nachgelagerten Archivjob erfolgreich abgeschlossen. Quelle ist ausschließlich `703a8f3ff7714d079223c7f0a03ab2400ba6a36a`, Tree `049c8a5be914b9babad0e9af8712ada777e5a077`, Ereignis `pull_request`, Versuch 1.

## Vollständiger Originalnachweis

| Umfang | Geprüftes Ergebnis |
|---|---|
| Gemeinsamer Kern | 37 eindeutige Probe/Modus-Paare, alle PASS |
| Studio-Raster | 24 exakte Original-PNG samt Bytezahlen, SHA256 und Größen |
| Drei Touch-Matrizen | 6 eindeutige Probe/Modus-Paare, alle PASS |
| Touch-Raster | 28 exakte Original-PNG: Werkstatt 6, Schatz 14, Bauwelt 8 |
| Quellen | Alle vier aktuellen Capture-Trees exakt `049c8a5…`; alle erforderlichen Dirty-Stamps leer |
| Alle Bilder im Gesamt-ZIP | 132 unveränderte PNG: 122 aktuell und 10 getrennte historische Baselines |
| Native-Rohlogs | 96 enthaltene Logs ohne ERROR, Script-/Parsefehler, ObjectDB- oder Leaked-instance-Zeile |
| Ergänzende Originalarchive | Preview: 25 PNG; Legacy/Gameplay: 22 PNG; beide ZIP-Digests geprüft |

Der unveränderte bestehende Host-Verifier aus `f80fe6b3d6a3c58c89f8507853dcbfc15a84525e` wurde mit dem festen Profil `nextgen-2019` erfolgreich auf das echte Gesamt-ZIP angewendet. Sein Blob ist `55f600365a5158e3deca8514a88f952a7608547d`, SHA256 `074fa561e078b56476f539827db516e27a815104d51b74ea898644a1cb0bba8a`; alle drei lokalen Abhängigkeiten sind ebenfalls auf die unveränderten Git-Blobs gebunden. Die Fortschreibung des lebenden Host-Verifiers auf einen späteren Rastervertrag verändert diesen Nachweis nicht.

## Tatsächlicher Renderer-Nachweis der beiden Build-Reparaturen

- BuildPlay: 62 Assertions headless und 70 Assertions mit echtem Renderer erfolgreich. Unveränderte Prüfungen für Auswahl, Drehen, Verschieben, Speichern, Wandkollision und Untersuchen wurden nicht entfernt.
- DialogDensity: 1.637 Assertions headless und 1.656 Assertions mit echtem Renderer sowie acht echte PNG erfolgreich. Der native Desktop-Pointer zeigt in beiden betroffenen Übergängen vor dem Eingriff `hovered=false` und danach `hovered=true`; anschließend wird derselbe echte ScreenTouch verarbeitet.
- Werkstatt: 4.129 / 4.148 Assertions; Schatz: 1.085 / 1.114 Assertions, jeweils headless / rendered.

Ungekürzte Originaljoblogs aller acht Jobs und die tatsächlichen relevanten Logzeilen stehen in diesem Ordner beziehungsweise im `handoff-manifest.json`. Originalbilder für alle neun Produktmodule sind in `review-index.md` und vollständig mit Hashes in `review-index.json` erschlossen. Dieser Pack erteilt keine visuelle oder Androidfreigabe.

## Unverändertes Originalarchiv

Gesamtartefakt `14054081246`: `native-14054081246.zip`, 163.275.110 Bytes, SHA256 `c3c0b856b3236c7288640cf27f390833b7cf9f2ac3b49ee32a4fff922ada898e`.

Der bestehende Workflow archivierte exakt diese Bytes als Prerelease `444416762`, Tag `integration-evidence-703a8f3ff7714d079223c7f0a03ab2400ba6a36a-14054081246`, ZIP-Asset `744207951`. Tag und Ziel verweisen exakt auf 703; Größe und veröffentlichter Assetdigest entsprechen dem heruntergeladenen Original-GitHub-Artefakt. Der erfolgreiche Archivjob enthält zudem den öffentlichen erneuten Download und dessen unveränderten `cmp`. Lokal wurde das originale Actions-ZIP heruntergeladen; ein zusätzlicher lokaler Release-ZIP-Download wird nicht behauptet. Es wurde kein APK erzeugt oder veröffentlicht.

Originale Run-/Jobs-/Artifacts-/Release-/Ref-JSON sind ungekürzt gespeichert. `archive-verification.json`, `native-artifact-verification.json` und `handoff-manifest.json` binden alle Metadaten und Dateien.

## Geltungsgrenze

Die neue Studio-Quelle 76980a mit zwölf Build- und insgesamt 32 Touchbildern ist hierin nicht abgenommen. Sie benötigt den nachfolgenden eigenen kombinierten Lauf. Der saubere aktuelle Gameplay-Lauf ist außerdem kein behaupteter Quellfix des separat berichteten Producer-Lasso-Teardownfehlers. Pins, Freigaben und Produktdateien wurden bei dieser Abnahme nicht geändert.
