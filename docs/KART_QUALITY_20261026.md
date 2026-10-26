# Kart-Qualitätsrunde, 26. Oktober 2026

## Gesicherte Basis und Umfang

Arbeitsbranch: `sol/kart-quality-20261026`, Basis `494416b` (Nextgen-Audit).
Er enthält den aktuell verwendeten App-Pin
`4d0fd40fdf188be6ca86057596c7b51f41701fa3` und Landing-Fit `3a31426`.
Der Rival-Branch `66b280a` enthält `6fa6fe6` und stammt ebenfalls von
`3a31426`, enthält aber den Hub-Fix `4d0fd40` nicht. Er wird hier **nicht**
übernommen: diese Abschlussrunde behebt ausschließlich nachgewiesene Fehler.
Godot: `4.6.3.stable.official.7d41c59c4`. Flutter/Pindatei bleiben unberührt.

## Bestandsaufnahme

- Sonnenhafen: prozedurale Küstenstrecke mit Hafen, Aquarium, Pavillons,
  Aussichtstürmen, Viadukt, langer Brücke, Küstenszenen und animiertem Kran.
  Die zentrale Road-Projektion berücksichtigt Y für übereinanderliegende Wege.
  Dekoration wird räumlich in MultiMeshes gebündelt; LOW reduziert Details.
- Kristalltunnel: Teil von Sonnenhafen bei 69–80 % der Runde, kein separates
  Rennen. `kart_sonnenhafen_darkride.gd` erzeugt Schale, Fahrbahnlicht,
  Neonrippen und Kristalle. Der Event-Director steuert die zweite Runde,
  unterdrückt Bewegungen bei reduzierten Animationen und bereinigt Rebinds.
- Figuren/Fahrzeuge: eigene Flotte und Tierfahrer, Lumo-Farben Orange,
  blaue Brille, Navy-Jacke im Kart-System; animierter GLB-Lumo nur am
  tatsächlichen Spielerkart. Garage, Rivalen und Geister haben getrennte
  prozedurale Darstellungen. Distanz-LOD verwendet Hysterese.
- Garage: echtes Premium-Landing mit fünf Setupschritten, Live-Vorschau,
  Tuning, gespeichertem Fortschritt und Einbettung in den Host.
- Items/Effekte: Boost, Schild, Impuls; Gegnerimpuls mit Vorwarnung und
  Ausweich-/Schildfenster. Kameralokale Speed-Streaks deaktivieren sich
  bei reduzierter Bewegung. Tunnel-/Wasser-/Materialshader haben LOW-Pfade.
- Physik: gemeinsamer Antrieb für Rennen/Werkstatt, Leitplankenbegrenzung,
  Driftstufen, Pedale/Rückwärtsfahrt, Sprünge, Checkpoints und Respawn.
  Bestehende Physikregression fährt tatsächlich gegen die Leitplanken.
- Kamera: Chase, geschwindigkeitsabhängiger Abstand/FOV, Neigung,
  Resize-FOV-Kompensation und separate Loop-/Zielkamera. Nachgewiesener
  Ansatzpunkt: lineares `min(1, delta * rate)` springt bei 250 ms komplett
  zum Ziel; Loop-Zweig beachtet `snap` nicht.

Diese Quelleninventur ist keine visuelle Android-Abnahme oder vollständige
Qualitätsfreigabe. Gerätelauf, Fold, Ton und gemessene 60 FPS bleiben offen.

## Kleiner Reparaturplan

1. Neue echte Engine-Regression für Chase-Position/FOV bei 30/60/120 Hz,
   250-ms-Hitch, Nullschritt, reduzierte Bewegung und Loop-`snap` schreiben.
2. RED am unveränderten Basiscode festhalten.
3. Ausschließlich Kameradämpfung zeitunabhängig machen und explizites
   Loop-`snap` beachten; Bildgestaltung, Physik, Gegner und Items erhalten.
4. GREEN sowie vorhandene Physik-, Bridge-, Landing-/Kamera-/Tunnelprüfungen
   ausführen; reale Renderprüfung soweit lokal verfügbar.
5. Ergebnisse/Begrenzungen ergänzen, kleine Commits pushen, Draft-PR und
   genaue SHA-Übergabe liefern. Kein Merge, Release oder Flutter-Pinwechsel.

## Abschluss und Übergabe

Runtime-/Regressionscommit: `b5ef1d2a65bb93965cd24786b80a377371341a40`,
bereits auf dem Arbeitsbranch gepusht. Geändert sind ausschließlich die drei
Kamerainterpolationen und das bisher ignorierte Loop-`snap`; neuer Enginetest
und Aufnahme in `tools/validate_project.sh`. Der Folgecommit enthält nur
diese Übergabe und Prüflogs.

Tatsächlich ausgeführt:

| Prüfung | Ergebnis |
| --- | --- |
| Godot-4.6.3-Erstimport | Exit 0, keine ERROR-/SCRIPT-ERROR-Meldungen |
| Neue Kamera-Regression auf unveränderter Basis | RED: 22 Checks, 10 Failures |
| Dieselbe Regression nach Reparatur, Headless | GREEN: 22 Checks, 0 Failures, Exit 0 |
| Dieselbe Regression mit Xvfb/OpenGL/Mesa llvmpipe | GREEN: 22 Checks, 0 Failures, Exit 0 |
| Tunnel-Lap-Event-Regression, Headless | PASS, Exit 0 |
| Strukturvalidator `validate_project.py` | 117 PASS / 7 WARN / 0 FAIL, Exit 0 |
| Neuer Test: gdlint / gdformat | PASS / PASS |
| `kart_island.gd`: gdlint / gdformat | 61 Befunde / Formatabweichung, auch auf Basis `494416b` |
| `git diff --check`, `bash -n tools/validate_project.sh` | PASS |
| Gesamtsuite `tools/validate_project.sh` | **FAIL** nach erstem Karttest: 4 Ressourcen beim Exit noch in Benutzung |

Der erste Test der Gesamtsuite meldete ein tatsächlich simuliertes vollständiges
Rennen (178,9 Spielsekunden, 10 666 Physikschritte, ein Reset), einen Award und
seine PASS-Zeile. Anschließend meldete Godot `ObjectDB instances leaked` und
`4 resources still in use at exit`; der strenge Validator stoppt deshalb.
Die nachfolgenden Suiteprüfungen (u. a. Physik-/Bridge-/Touchmatrix) wurden
in diesem Lauf nicht erreicht. Der Ursprung des Cleanupfehlers wurde wegen
des ausdrücklichen Abschlussauftrags nicht weiter untersucht und wird hier
nicht als bereits bestehend behauptet. Keine Gesamtsuite-Freigabe.

Der Kamera-Vergleich nach 200 ms ergab vor Reparatur 23,1 cm Unterschied
zwischen 30/60 Hz und 10,9 cm zwischen 120/60 Hz. Danach jeweils unter
0,01 mm; Loop unter 0,02 mm. 250-ms-Schritte nähern sich nun gedämpft an;
explizites `snap` bleibt sofortig. Dies sind synthetische Zeitschrittproben
auf tatsächlichen Enginekameras, keine gemessenen Geräteframeraten.

Die sieben Strukturwarnungen betreffen sechs Manifest-Modelle und die
fehlende Ausführungsberechtigung von `tools/build_web_bundle.sh`.
GL-Kompatibilität meldet die erwarteten V-Sync-/Forward+-Featurewarnungen.
Es wurden keine neuen Bilder, APKs oder Android-Abnahmen erstellt.

**Integrationsentscheidung:** kleiner, abgegrenzter Reparaturkandidat als Draft;
aktuellen Flutter-Pin beibehalten. Vor Übernahme den Ressourcen-Cleanupfehler
einordnen und die vollständige Suite sowie den passenden Androidlauf beenden.
Keine Rival-Änderung, kein Main-Merge, Force-Push, Release oder Pinwechsel.
193 bei Import erzeugte `.uid`-Dateien bleiben lokal und sind vom
Autosave-Sicherheitsfilter ausgeschlossen; keine fremden Dateien gelöscht.

Belege: [evidence/kart-quality-20261026](evidence/kart-quality-20261026/).
Die ursprüngliche fehlerhafte Testprototyp-Ausführung mit ungültiger
Teststrecken-ID wurde verworfen; die archivierte RED-Probe verwendet die
gültige Loop-Strecke `candy_cloud` und endet regulär mit Exit 1.
