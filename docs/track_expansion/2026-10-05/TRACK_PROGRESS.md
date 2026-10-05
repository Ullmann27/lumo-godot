# Track implementation progress

## Etappe 1 – unmittelbare Turbo-Reaktion

- Agent: GitHub Copilot Coding Agent; konkreter Modellname in dieser Sitzung nicht sichtbar.
- Datum: 2026-10-05.
- Arbeitszweig: `copilot/lumo-kart-upload-streckenpakete`, Umsetzungs-PR #15 auf Referenz-PR #14.
- Basis-SHA: `7351f1756e1910389450e041185b846823a97e92`.
- Ergebnis-SHA für Laufzeitänderung und Regression: `1c090c112400762e349647b60d20733be824b46c`.
- Produktdateien: `scripts/games/kart_island.gd`, `scripts/tests/kart_physics_regression.gd`.

### Befund und Änderung

Der Touch-Callback nimmt einen gültigen Boost synchron an, setzt `boost_time` und startet den Boost-Sound. Die bisherige Physik erhöhte aber nur das Zieltempo um 42 Prozent; die Beschleunigung blieb gleich. Solange das Kart unter seinem normalen Zieltempo lag, brachte der Boost deshalb im ersten Physikschritt keinen zusätzlichen Geschwindigkeitszuwachs. Die Beschleunigung ist jetzt bei aktivem Turbo und steigendem Zieltempo verdoppelt; auch während eines Sprungs kann ein aktiver Turbo die Geschwindigkeit erhöhen. Das bestehende Zieltempo, der Controller und das Fahrgefühl außerhalb aktiver Turbozustände bleiben unangetastet.

Der gezielte Engine-Test protokolliert den Touch-Signalpfad, die angenommene Boostladung, den ersten Physikschritt, die Geschwindigkeitsänderung sowie den Zustand von Flammen-VFX und Audioplayer. Im Testlauf: +0,333 m/s mit Boost gegenüber +0,167 m/s ohne Boost; die vom Harness gemessenen Abstände waren 869 µs bis zur Annahme und 129 µs bis zum explizit aufgerufenen Physikschritt. Das sind synthetische Headless-Testwerte, keine Messung der realen Touch- oder Geräte-Latenz.

### Prüfung

- Godot 4.6.3 Headless-Import: bestanden.
- `scripts/tests/kart_physics_regression.gd`: bestanden, einschließlich gleichzeitiger Lenkung, Doppeltippen/leerem Slot, Countdown-/Pause-/Finish-Sperre, Neustart, Boost-Pad und Sprung.
- `tools/validate_project.py`: 117 PASS, 7 WARN, 0 FAIL. Die Warnungen betreffen fehlende optionale Modell-Assets und ein nicht ausführbares Build-Tool.
- `tools/validate_project.sh`: alle vorhandenen Testgruppen bestanden (Kart, Physik, Sprung, Touch, Welt, Pause-Layout, Fahrzeug und Host-Brücke).
- `git diff --check`: bestanden. `gdlint` und `gdformat` waren in der Sandbox nicht installiert.
- Read-only Kart-Physics-Review: keine hochsicheren Regressionen gefunden. PR-Validierung lieferte keine CodeQL-Analyse für GDScript; der allgemeine Code-Review-Dienst konnte das angeforderte Modell nicht starten. PR #15 hatte zum Prüfzeitpunkt keine GitHub-Check-Runs.
- Keine Geräteprüfung, kein Laufzeit-Screenshot und keine FPS-Messung durchgeführt.

### Offen und nächste Schritte

- Fold-/Resize-Pass ist jetzt als separate Etappe vor Fold-Freigabe und Streckenausbau in `TRACK_BUILD_ROADMAP.md` aufgenommen. Befund: `size_changed` aktualisiert nur Safe-Area-Margen; Kart fordert Landscape an; adaptive Controls und Hinge-Handling sind noch nicht nachgewiesen.
- Als nächstes vor Laufzeitänderungen die genaue Flutter-Testmatrix aus lumo-lernen PR #197 (`docs/TASK_FOLD_2026-10-05.md`) abrufen und die portrait-Activity-/Sensor-Landscape-Grenze mit dem zuständigen Bearbeiter koordinieren. Die Web-Abfrage auf den angegebenen Dateipfad lieferte 404; Matrix hier daher nur anhand des Godot-Kommentars erfasst. Keine Flutter-Datei oder kein Manifest wurde geändert.
- Auf einem echten Android-Gerät Eingabe-zu-Physik-/Audio-Latenz prüfen; keine Gerätewerte aus dem Harness ableiten.
- Bodenpfeile anhand lokaler Streckentangenten prüfen und gegebenenfalls pro Segment korrigieren; gekrümmte, geneigte und gespiegelte Segmente abdecken.
- Erst nach separatem Claim einen vorhandenen Abschnitt mit echter Streckengeometrie erweitern und Runde, Rampe, Landung, Checkpoints und KI-Fahrt nachweisen.
- Opus wurde nicht gestartet. Spätere konkrete Aufgabe: nach einem echten Gameplay-Nachweis den vorhandenen Look des ausgebauten Abschnitts stilkritisch prüfen, ohne Laufzeitgrafik oder Figuren pauschal zu ersetzen.


## Etappe 2 – Fold-/Resize-Pass und Fahrtrichtungs-Chevrons

- Agent: ChatGPT, direkt auf dem bestehenden Umsetzungszweig von PR #17.
- Ausgangs-Head vor dieser Etappe: `00cb001369d081a97d660e4a249a4539d502558b`.
- Aktueller Ergebnis-Head: `d190ee4d64019aa813644b7123635122e20c884f`.
- Produktdatei: `scripts/games/kart_island.gd`.
- Regressionen: `scripts/tests/kart_pause_layout_regression.gd`, `scripts/tests/kart_physics_regression.gd`.

### Umsetzung

1. `Viewport.size_changed` führt jetzt nicht mehr nur die Safe-Area-Neuberechnung aus, sondern einen gemeinsamen Resize-Pass.
2. Joystick und rechter Pedal-Cluster werden aus der aktuellen logischen Viewport-Höhe neu dimensioniert; feste Ausgangsmaße bleiben als Designbasis erhalten.
3. Minimap und Pause-/Ergebnis-Modal werden bei Größenänderungen neu eingerahmt.
4. Die Kamera verwendet eine begrenzte, seitenverhältnisabhängige Basis-FOV und behält den Boost-FOV-Aufschlag bei, statt auf jedem Seitenverhältnis starr 68/76 Grad zu verwenden.
5. Der vorhandene Pause-/Fold-Regressionstest deckt nun zusätzliche Innen-/Querformatgrößen ab und prüft, dass Rennsteuerung und Kamera nach Resize innerhalb der Safe-Area bleiben.
6. Die leuchtenden Turbo-Chevrons werden geometrisch aus der lokalen Fahrtrichtung `-basis.z` aufgebaut. Die Arme konvergieren damit explizit in Fahrtrichtung statt ihre Richtung nur aus einer Rotationskonvention abzuleiten.
7. Ein Regressionstest prüft den positiven Richtungs-Dot-Product der Chevron-Arme und ihre Links-/Rechts-Symmetrie.

### Abgrenzung / noch offen

- Der Android-Host-Fix liegt getrennt in lumo-lernen PR #197: `LumoGameActivity` wird dort von `portrait` auf `sensorLandscape` umgestellt und durch einen Regressionstest abgesichert.
- Hinge-Geometrie wird nicht erfunden. Solange der Android-Host keine explizite Falz-/Occlusion-Geometrie an Godot übergibt, kann Godot nur Safe-Area/Cutout und die tatsächliche Fenstergröße berücksichtigen.
- Für die Godot-Commits dieser Etappe war zum Dokumentationszeitpunkt kein automatischer GitHub-Workflow-Run vorhanden. Die neuen Regressionen sind eingecheckt, aber ein tatsächlicher Godot-Lauf muss noch als PASS/FAIL/SKIP nachgetragen werden.
- Kein echter Fold-7-Test und keine FPS-Messung ausgeführt.
- Nächster Produktblock: vollständigen Muster-Streckenabschnitt im bestehenden Opus-Stil ausbauen und danach die zehn Welten skalieren.


## Etappe 3 – Himmelsinseln Stage 2 + Mystery Items

- Basis: integrierter Kart-Stand aus PR #17 / `edc47b6`.
- Arbeitsbranch: `chatgpt/kart-himmelsinseln-stage2-2026-10-05`.

### Direkt umgesetzt

1. **Himmelsinseln verlängert**
   - nur `bergwelt` wird horizontal um Faktor 1,18 skaliert;
   - Kurvenradien werden dadurch nicht künstlich enger;
   - prozedurale Inseln, Brücken, Cave, Ruinen und Deko folgen weiterhin der echten Streckenkurve.

2. **Neues Sternentor-Setpiece**
   - sieben leuchtende Torbögen nach den Tempelruinen;
   - Cyan/Violett-Wechsel, Goldsterne, eigener Streckenmarker;
   - kontinuierliche Fahrbahn, kein Fake-Tunnel und keine erfundene Kollision.

3. **Sicheres Respawn am Sprung**
   - neue `safe_respawn_distance()`-Regel;
   - Reset landet nicht im offenen Gap und nicht mitten in der Rampen-Gefahrenzone;
   - bestehende geordnete Checkpoint-Logik bleibt erhalten.

4. **Mystery-/Zufallsboxen**
   - fünf sichtbare, leuchtende Item-Boxen pro Runde;
   - jede Box kann pro Runde einmal eingesammelt werden;
   - Position 5–6 erhält höhere Boost-Chance als Führende;
   - vorhandene Items bleiben `boost`, `shield`, `pulse`.

### Regressionen

- `kart_track_contract.gd` schützt:
  - Himmelsinseln als Long-Form-Kurs (>400 m),
  - Respawn außerhalb des Sprung-Gaps.
- `kart_physics_regression.gd` schützt:
  - fünf Mystery-Boxen,
  - stärkere Catch-up-Boost-Gewichtung hinten,
  - unmittelbaren Item-Pickup.

### Noch offen

- tatsächlichen Godot-Prüflauf für diese Etappe ausführen;
- echte Laufzeit-Screenshots des neuen Sternentors;
- zweites physisches Sprung-/Alternativrouten-Setpiece;
- Rivalen sollen Items aktiv taktisch einsetzen;
- weitere neun Referenzwelten auf denselben Detailstandard skalieren;
- Fold-7/FPS weiterhin nicht als getestet behaupten.


### Rivalen-Item-Taktik

- Rivalen besitzen jetzt eigene Item-Slots, Cooldowns, Boost-Zeit und Schild-Zeit.
- Rivalen nehmen dieselben Mystery-Box-Positionen als Item-Quelle wahr.
- Überhol-/Comeback-Logik nutzt die aktuelle Platzierung des jeweiligen Rivalen.
- Boost wird taktisch genutzt, wenn der Spieler vor dem Rivalen liegt.
- Lichtimpuls kann den Spieler aus kurzer Distanz abbremsen, sofern kein Schild aktiv ist.
- Rivalen-Schild blockiert den Lichtimpuls des Spielers.
- `kart_physics_regression.gd` prüft Boost-Nutzung, Schild und Rivalen-Pulse.

Aktueller Stage-2-Head nach dieser Erweiterung: `b048d1eba00f8ac9f2a2c9a5d25cf69a023b2dd6`.


### Validation follow-up

- Copilot checked commit `cc8cafb0e0ac3a37b0adc6a9f927aa8908c3c870`: `tools/validate_project.py` passed with 117 PASS / 7 WARN / 0 FAIL.
- Godot parser/lint and the focused Kart regression scripts remain SKIP because Godot/gdlint/gdformat are not available in that runner.
- Manual review found a later-lap respawn edge case: cumulative race distance was compared directly with lap-local jump geometry. `cc8cafb0e0ac3a37b0adc6a9f927aa8908c3c870` fixes the local/cumulative distance handling.
- `894720592473d886b8f599a5251cec1002723898` adds a later-lap regression assertion; execution is still SKIP until a Godot runner is available.
- lumo-lernen PR #197 still pins Godot `a369da2dc208fcd9d5451c7007d8b1f9e7bf52a1`, not this Stage-2 branch. A future candidate build must deliberately update that pin only after Kart validation and then verify provenance again.
- No Fold-device or FPS claim.
