# cf039: drei echte Kart-Audio-Teardowns repariert

**Die drei reparierten Probes bestehen den strikten lokalen Engine-Runner.**
Alle drei absichtlich gehaltenen echten Audioreferenzen werden fristgerecht
als Fehler erkannt; sie erzeugen keinen PASS. Das ist eine lokale headless
Quellabnahme der drei Testdateien, keine neue CI-, Renderer- oder Androidfreigabe.

## Originalbefund

Der originale [Nextgen-Lauf 43444649016](https://github.com/Ullmann27/lumo-godot/actions/runs/43444649016)
auf `cf039ad8c834522f355b858e3bee1e201e397da4` ist insgesamt **FAILURE**.
Sein [Gameplay-Job 131950806261](https://github.com/Ullmann27/lumo-godot/actions/runs/43444649016/job/131950806261)
ist bei GitHub **SUCCESS**, obwohl folgende echte Fehler jeweils nach PASS stehen:

| Probe | Originaler Exitfehler | Bestätigte Ursache |
| --- | --- | --- |
| KartAI | 4 Ressourcen | Ogg-Wiedergaben von garage.ogg und sonnenhafen.ogg |
| GarageTargets | 2 Ressourcen | Ogg-Wiedergabe von garage.ogg |
| KartFullField | 2 Ressourcen | Ogg-Wiedergabe von sonnenhafen.ogg nach dem bisherigen einzelnen Warte-Frame noch lebend |

Die damalige pauschale Fehlerfilterung erklärt die GitHub-SUCCESS-Anzeige.
Die Originaltexte bleiben unverändert. Root entfernt die Filter separat;
diese Reparatur verändert nur die drei tatsächlichen Testdateien.

Originalartefakt **14047474807**, ZIP-SHA256
`49f400c6b6c697e01cf8b797ce55aed567c4098be614377d68fd4ec7c1d77877`.
Das vollständige ZIP bleibt im Scratch. Hier liegen finale originale
Run-/Job-/Artefaktmetadaten, der vollständige Joblog sowie die beiden relevanten
Artefaktlogs verlustfrei komprimiert. Die drei Ausgangstests und kart_audio.gd
wurden zusätzlich aus dem unveränderlichen cf039-Commit geladen: Git-Blob-Hashes
stimmen und die Inhalte entsprechen den lokalen Ausgangsdateien bytegenau.

## Reparatur und Grenze

Vor dem vorhandenen Szenenabbau werden schwache Referenzen auf die tatsächliche
Szene und ihre vorhandenen AudioStreamPlaybacks erfasst. Anschließend bleibt die
normale Szenenfreigabe erhalten. Der Test wartet auf den realen Verlust dieser
Referenzen, mit einer Grenze von **2000 ms echter Laufzeit**. Er prüft die Grenze
vor der Erfolgsausgabe. Eine feste Zahl Simulationsframes ersetzt diese
Beobachtung nicht. Erst danach darf der ursprüngliche PASS-Marker erscheinen.

Alle bisherigen Fahr-, Physik-, Schwierigkeits-, Layout- und Touchgrößenprüfungen
bleiben erhalten. Produktcode, Audiosystem, Fehlerfilter und globale Timeouts
wurden durch diesen Patch nicht geändert. In FullField wird jede der sechs
erzeugten Szenen einzeln abgebaut und nachgewiesen.

## Tatsächliche lokale Ergebnisse

| Probe | Strenger Positivlauf | Wirklich freigegebene Wiedergaben |
| --- | --- | --- |
| KartAI | PASS, alle ursprünglichen AI-Prüfungen | 2, nach 68 ms |
| GarageTargets | PASS, 255 sichtbare Bedienelemente ≥ 48×48 dp | 1, nach 50 ms |
| KartFullField | PASS, 6 Szenarien, insgesamt 30 Zwei-Runden-Zieleinläufe | je Szene 1/3/1/1/4/1, nach 72/62/39/73/0/58 ms |

Engine: **Godot 4.6.3.stable.official.7d41c59c4**, headless, Dummy-Audio,
fester Simulationsschritt 60 FPS. Das ist keine gemessene Bildrate.
Die tatsächlich ausgeführten vollständigen Argumentlisten, Logs, Zeiten und
Quellhashes stehen unter `runs/after-typed/`. Der unveränderte
`tools/run_godot_probe.py` verlangt den Marker, einen sauberen Prozessabschluss
und keine Engine-/Scriptfehler. Zusätzlich wurden die finalen Logs auf
ObjectDB-/Ressourcenlecks geprüft: keine solchen Meldungen.

Die isolierten Negativvarianten halten jeweils die erste **echte** Wiedergabe
in einer starken Referenz. Szene und übrige Wiedergaben werden weiterhin normal
freigegeben. Alle drei Varianten schlagen bei 2001/2001/2002 ms Beobachtungszeit
fehl: `retained_scene=false`, genau ein gehaltenes Playback, kein PASS.
Die Frist wird wegen dieses Zustands nicht verlängert; die wenigen Millisekunden
darüber sind der nächste Beobachtungstakt. Fixtures und minimale Deltas liegen
unter `sources/negative-fixtures/`, vollständige Rohlogs unter
`runs/held-reference-negative/`.

## Quellenbindung und nachvollziehbare Zwischenstände

Basis-HEAD der lokalen Prüfungen: `97b91e312eb982ab1fe9083b7415d11085385235`,
mit dem hier dokumentierten noch nicht committeten Drei-Dateien-Patch.
Die 287 final gestempelten Quell-/Szenen-/Audiodateien waren vor und nach
Positiv- und Negativläufen unverändert. Die parallel bearbeitete Bauweltdatei
`scripts/creative/build_world.gd`, fremde Tests, Dokumente und Shell-Gates sind
ausdrücklich außerhalb dieses Kart-Manifests. Es wird kein sauberer Gesamtbaum
und keine Abnahme der parallelen Build-Reparatur behauptet.

Die strengen ursprünglichen Vorherläufe waren für AI und FullField rot.
Garage war dort zunächst sauber, reproduzierte seinen ursprünglichen Fehler
aber mit festem Simulationstakt. Zwei direkte FullField-Diagnosen waren ebenfalls
sauber. Das dokumentiert die zeitabhängige Mixerfreigabe; es widerlegt weder
die Originalfehler noch den direkt beobachteten noch lebenden Ogg-Owner.
Alle diese Rohlogs sind erhalten. Die gezielte FullField-Beobachtungsfixture
hat ausschließlich WeakRef-Ausgaben ergänzt und nutzte den bereits vorhandenen
pro/clear-Auswahlpfad; sie ist kein Ersatz für den finalen vollständigen Lauf.

Ein erster Patch-Zwischenstand wurde vom strikten Parser wegen impliziter
Variant-Typinferenz abgewiesen (`runs/after/`). Die finale explizite
WeakRef-Typisierung ist im neu geprüften Stand `runs/after-typed/` enthalten.
Keine fehlgeschlagene Zwischenprüfung wird als grün bezeichnet.

`verification/final-source-hashes.json` bindet die drei freigegebenen Testdateien,
`verification/final-test-only.patch` enthält das vollständige Delta.
`manifest.json` ordnet jede Datei ihrer Originalquelle zu und speichert die
komprimierten sowie unkomprimierten Hashes. `sha256sum -c SHA256SUMS` prüft
das kompakte Paket; sämtliche gzip-Rückprüfungen waren bytegenau erfolgreich.
