# Grafikcheckpoint 90d34181: PR 160, Lauf 43483977529

Dieser kompakte Originalcheckpoint gehört ausschließlich zu Native
90d34181409c15d1b1ad3a6a9643539453155c1d / Tree
9b407d61633a6421dc47b6858e6a6fb3fa60bea5. Der Pull-Request-Lauf, Versuch 1,
endete am 13.11.2026 um 18:51:56 UTC erfolgreich. Home, Worlds und Feedback
waren jeweils SUCCESS. Der separat belegte Geometry-Gatefehler eines anderen
90d-Prüflaufs bleibt bestehen; dieser Pack ist keine Native-Gesamtfreigabe.

## Enthaltene Originalbytes

- original/ enthält sämtliche gesicherten REST-Antworten einschließlich der
  endgültigen vollständigen run/jobs/artifacts-Proofs, die drei vollständigen
  Joblogs, die eingefrorenen Auswertungen und Immutable-Quellen, den ursprünglichen
  Handoff und dessen SHA256SUMS sowie beide unveränderten Root-Sichtungsbelege.
- artifact-logs/ enthält alle 40 vollständigen Logdateien aus den drei ZIPs,
  einschließlich aktueller und historischer Imports, Capture- und Engineprotokolle.
  Die Dateinamen sind für diesen Ordner abgeflacht; das Manifest bindet jeweils
  den exakten Original-ZIP-Pfad.
- original-artifacts/ enthält die tatsächlichen Quellen-/Tree-/Dirty-/Engine-Stempel,
  unveränderte Bildmanifeste, Baseline-Harness-Hashes und Captureberichte.
- original/archive-indexes/ enthält die drei unveränderten vollständigen
  ZIP-Mitgliederindizes als verlustfreie gzip-Dateien. Alle 2487 regulären Einträge,
  auch nicht kopierte Laufzeit-Caches, sind über Größe, CRC und SHA-256 gebunden.

Die API-JSON-Dateien und Logs wurden nicht neu serialisiert, gekürzt oder
inhaltlich verändert. Joblogs sind die vollständigen vom GitHub-Connector
dekodierten UTF-8-Logtexte mit erhaltener BOM; dies behauptet keine Identität
mit unbekannten ursprünglichen HTTP-Transportbytes.

## Nur per Originalartefakt gebundene Bytes

Die drei großen ZIP-Dateien und sämtliche PNG-Payloads wurden nicht in diesen
Git-Pack kopiert. Sie bleiben unverändert im Originalcheckpoint:
 /workspace/scratch/b3485b7bb989/pipeline-evidence/pr160-90d34181-graphics/

archive-index.json nennt für jedes ZIP Artefakt-ID, originale API-/Downloadquelle,
Bytezahl, REST-Digest, lokalen Originalpfad und den vollständigen Mitgliederindex.
raster-index.json.gz bindet alle 62 Original-PNG: 36 aktuelle und 26 frisch
ausgeführte historische Baselinebilder, jeweils mit Quellstand, ZIP-Mitglied,
Maßen, Bytezahl und SHA-256. Die wiederverwendbare Baseline ist ada5ed81 / Tree
2e93cc55; sie wird nicht als aktuelle Produktion bezeichnet.

| Bereich | Artefakt | Aktuelle PNG | Baseline-PNG | Vollständige Logs |
|---|---:|---:|---:|---:|
| Home | 14066484109 | 24 | 20 | 19 |
| Worlds | 14065768763 | 6 | 6 | 15 |
| Feedback | 14066577938 | 6 | 0 | 6 |

## Prüfung und tatsächliche Sichtung

Beim ursprünglichen Sammeln wurden alle PNG mit Image.verify() und vollständigem
Image.load() dekodiert; alle 40 Artefaktlogs bestanden den strengen Fehlercheck.
Beim Packen wurden die 194 eingefrorenen Hashbindungen, die ZIP-Digests und
Bytezahlen, sämtliche 2487 ZIP-Mitglieder sowie die kopierten Rohbytes erneut
verglichen. Das Packen führte keine Engine-, Renderer- oder Regressionstests aus.
Der direkte aktuelle Feedbacknachweis bleibt der gerenderte PASS75 mit Freigabe
dreier tatsächlicher Audio-Playbacks nach 15 ms vor PASS; ein älterer lokaler
Headless-PASS56 oder separater aktueller Nextgen-PASS56 wird nicht übernommen.

Root hat fünf aktuelle Originalbilder tatsächlich geöffnet: Home1280×720,
Home412×915, Winter-Landmark, Crystal-Landmark und Drift-Release. Die vollständigen
Beobachtungen stehen unverändert in original/root-current-five-viewed.json
(SHA256 1783699114d664a7ed1851688c7eec0e6ea30546ddedee3422972f1633d2c520).
Der vorherige Dreierreview bleibt als frühere begrenzte Sichtung unverändert
erhalten. Der eingefrorene ursprüngliche Handoff und seine Hashliste entstanden
vor dem ergänzenden Fünferreview und wurden nicht nachträglich umgeschrieben;
dieses Manifest bindet den späteren Fünferreview zusätzlich ausdrücklich.

## Speicherformat und Grenzen

Logs und größere Daten sind deterministisch komprimiert: gzip, leerer Dateiname,
mtime=0, Kompressionsstufe9. Das Manifest nennt Originalgröße/-hash,
Speichergröße/-hash, die Herkunft und den erfolgreichen bytegleichen Roundtrip.
SHA256SUMS bindet alle gespeicherten Dateien einschließlich dieses Manifests.

Dieser Checkpoint erzeugt kein Receipt und verändert weder Pin, Quelle, Index
noch Ref. Er gilt nicht für einen späteren Geometry-Folgehead. Beobachtete
stationäre Worlds-/Landmarkbilder, softwaregerenderte X11-Captures und geprüfte
PNG-Bytes belegen keine physische Android-Abnahme, APK/AAR-Freigabe oder gemessene
Bildrate. Die originalen Projektvalidator-Warnungen bleiben vollständig erhalten.
