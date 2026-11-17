# cf039: Grafiklauf mit fehlgeschlagenem Vergleichsimport

**Gesamtergebnis: FAILURE. Home und Feedback: SUCCESS. Worlds: FAILURE.**

Dieses Paket dokumentiert ausschließlich [Lauf 43444648887, Versuch 1](https://github.com/Ullmann27/lumo-godot/actions/runs/43444648887)
aus PR 160, Native `cf039ad8c834522f355b858e3bee1e201e397da4`,
Tree `4fdbcbfcf069c6790e17101a09d4fb3f2955c2e2`.
Es enthält keine Freigabe und keinen Nachweis für einen späteren kombinierten Kopf.

## Tatsächliche Ergebnisse

| Bereich | Ergebnis | Gesicherter Umfang |
| --- | --- | --- |
| Home, Job 131950805238 | SUCCESS |251 Produktionschecks; PreviewResolution 52; CardsHeader 295; X11-Capture 324; Baseline-Capture 240; Promenade 11, Spatial 554, Garage 93 |
| Worlds, Job 131950805514 | FAILURE |Aktuelle Regression 72, WinterVisibility 50 und views=0 sowie beide aktuellen Streckencaptures bestanden; alter Vergleichsimport abgestürzt |
| Feedback, Job 131950805506 | SUCCESS |71 Rendererchecks; sechs aktuelle Szenenframes |

Alle 56 vorhandenen PNGs wurden gegen die Originalmanifeste in Größe und SHA256 geprüft:
Home 24 aktuell + 20 Vergleich, Worlds 6 aktuell und kein Vergleichsbild, Feedback 6 aktuell.
Die Home-Ansichten decken 1280×720, 412×915, 690×829 und 640×320 ab.
Alle drei aktuellen Artefakte nennen exakt cf039 und den angegebenen Tree;
ihre Dateien `source-dirty.txt` sind leer. Das frühere Produkt im Home-Vergleich
ist `ada5ed81ad62339f15289da62670c0a4f9f7f2b9`, mit dem aktuellen Aufnahmeharness.

## Fehlerursache und tatsächliche Grenze

Der Worlds-Job scheitert beim headless Editorimport der Vergleichsquelle ada5.
Godot 4.6.3 meldet einen unzulässigen Thread-Aufruf von `propagate_notification()`
auf `/root`, danach Signal 11; die Shell beendet den Schritt mit Exit 134.
Die zuletzt angezeigte Importdatei ist `lumo_reference_manifest.csv`.
Das ist ein Reihenfolgebefund und beweist nicht, dass diese Datei den Absturz verursacht.

Der vollständige originale Joblog und `baseline/import.log` liegen verlustfrei
unter `raw/`. Die erfolgreichen aktuellen Weltenprüfungen und Bilder ändern
weder den fehlgeschlagenen Vergleich noch das fehlgeschlagene Gesamtergebnis.

## Archivbindung

| Originalartefakt | ZIP-SHA256 |
| --- | --- |
| Home 14049265406 |`a311a60de79fd82a479a6070915707041f54a0160c68a5ee5168944defb8be4c`|
| Worlds 14047548008 |`faa5624566720da5e85b21ed3beaf624f9a61d6d11d0820ad1dcedb4f11bd226`|
| Feedback 14046817841 |`d0a9425c0759e27f3142c14aaee8861e6fa6df38b29b620d447da0c014cca4c6`|

Die drei vollständigen ZIPs und die Originalbilder bleiben unter
`/workspace/scratch/b3485b7bb989/pipeline-evidence/pr160-cf039ad8-graphics/`.
Dieses kompakte Paket enthält die originalen Run-/Job-/Artefaktmetadaten,
alle relevanten Pflichtgate-/Import-/Renderlogs, Source-Stamps, Captureberichte
und Bild-Hashmanifeste. Die Artefakt-Connector-Antwort ist als solche bezeichnet;
Run-/Job-Payloads stammen aus dem direkten GitHub-REST-Abruf.

## Übernommene Reparaturentscheidung

Der zunächst geplante unveränderte Einzeljob-Rerun wurde **gestrichen**.
GitHub hatte den ersten Versuch noch während Home mit 403 abgelehnt; kein
Rerun wurde gestartet. Danach lag die fertige Producerkorrektur
`25e3a1187234860414fa69822e7b301e75880c82` vor.

Die Korrektur setzt getrennte XDG-Verzeichnisse vor beiden Imports,
entfernt das zusätzliche `--quit` und startet den Vergleichsimport im
Vergleichs-Arbeitsverzeichnis. Der lokale unveränderte Godot 4.6.3-Hilfetext
bestätigt: `--import` wartet auf den Import und beendet anschließend selbst;
`--quit` beendet nach der ersten Iteration. Vollständige CLI-Ausgabe,
Version und lokaler Binärhash sind unter `local-cli/` gesichert.
Das ist eine Prüfung der CLI-Semantik, keine neue Laufabnahme.

Der integrierte Workflow in `97b91e312eb982ab1fe9083b7415d11085385235`
wurde unabhängig mit der veröffentlichten Producerdatei verglichen:
Er übernimmt die beiden Importblöcke und erhält den vorhandenen PR-Trigger
sowie `github.event.pull_request.head.sha || github.sha`.
Alle übrigen Schritte, Pflichtmarker, Import-ERROR-Prüfungen, Sourcechecks
und Artefaktbedingungen sind unverändert. Root meldete zusätzlich
erfolgreiches Actionlint. Die tatsächliche neue CI-Abnahme bleibt separat offen.

## Teilbildsichtung

Root hat fünf aktuelle Originalbilder tatsächlich angesehen:
Winter-Landmark, Crystal-Landmark, Drift-Release sowie Home 412×915 und 1280×720.
Dokumentiert sind lesbare Fahrbahn/HUD, die aktuellen Seilbahn-/Brückenelemente,
zwei Abgasstrahlen sowie vollständig erkennbare Kart-/Figuransichten und
lesbare Home-Bedienelemente. Im Hochformat sind Solo/Pokal/Zeit und
Zahnradoptionen sichtbar. Daraus folgt keine vollständige Landmark-Abnahme.
Die fünf exakten PNG-Hashes stehen in `analysis/partial-visual-observations.json`.

Diese Sichtung ist ein begrenzter Befund innerhalb des insgesamt
fehlgeschlagenen cf039-Laufs. **Kein Receipt, kein Pin und keine Android-
oder 60-FPS-Freigabe werden damit ausgestellt.**

`manifest.json` ordnet jede Paketdatei ihrer Quelle zu und enthält
komprimierte und unkomprimierte SHA256-Werte. Sämtliche gzip-Rückprüfungen
waren bytegenau erfolgreich; `sha256sum -c SHA256SUMS` prüft das Paket.
