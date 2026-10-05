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
