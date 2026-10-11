# Sky-Capture: echte Fixture-Lebensdauer repariert

Stand: 11. Oktober 2026. Eigener Testbranch `computer/lumo-kart-stage2-fixture-cleanup-2026-10-11`, Ausgangscommit `6063f56fd4ff13afef61509f52d1d4fdab012654` aus [PR #54](https://github.com/Ullmann27/lumo-godot/pull/54).

## Befund trotz grüner CI

Der [Stage-2-Lauf 38097533036](https://github.com/Ullmann27/lumo-godot/actions/runs/38097533036/job/114346440254) ist als erfolgreich abgeschlossen. Sein Sky-Screenshot-Schritt enthält trotzdem eine ObjectDB-Warnung und `4 resources still in use at exit`. Der ursprüngliche Schritt prüfte den Exitcode und Bilddateien, nicht diese Fehlerausgaben.

Ein echter lokaler GL-Lauf des unveränderten Captures mit `--verbose` reproduzierte die Warnung. Er identifizierte einen verwaisten `Node3D` sowie die zurückgehaltenen Skripte `kart_island.gd`, `kart_vehicle.gd`, `kart_records.gd` und `kart_physical_loop.gd`. Dies ist kein Nachweis der früher separat beschriebenen AudioServer-Verzögerung.

## Eng begrenzte Reparatur

- **Temporäre Factory:** Der Capture leiht weiterhin die echte `_item_box`-Implementierung. Nach dem Aufbau der fünf Prismen wird ausschließlich dieser nicht in den Szenenbaum eingehängte Controller mit `free()` freigegeben. Ihn in den Baum einzuhängen würde unerwünscht ein zweites Spiel initialisieren.
- **Originalprismen:** Die fünf tatsächlichen Prismenknoten gehören bereits zum eigenen `item_root`. Ihre Zahl bleibt nach der Factory-Freigabe unverändert; alle acht bisherigen Bilder werden weiterhin gerendert.
- **Orphan-Prüfung:** Vor dem Ausleihen, nach der Freigabe und nach dem letzten Bild wird dieselbe echte Orphan-Baseline geprüft.
- **Strenge CI:** Der Sky-Schritt verwendet jetzt den vorhandenen `tools/run_godot_probe.py`. Script-/Enginefehler, fehlender Erfolgsmarker, Timeout oder fehlerhafter Exit scheitern tatsächlich, auch wenn PNGs vorhanden sind.

Keine Änderung an Produktcode, Fahrphysik, Weltgeometrie, Rig, Clips, Audioprovider, Save-Schema, Profilen oder Belohnungen. Der APK-Kandidat aus [Flutter-Lauf 38097768063](https://github.com/Ullmann27/lumo-lernen/actions/runs/38097768063) bleibt auf dem geprüften Produktpin `6063f56`; eine reine Testreparatur rechtfertigt keinen erneuten APK-Bau.

## Tatsächliche lokale Prüfung

- **Vorher:** Godot 4.6.3, echter GL-Compatibility-Lauf unter Mesa/llvmpipe, acht Bilder vorhanden, trotzdem verwaister Controller und vier Skriptressourcen bei Exit.
- **Nachher:** Derselbe tatsächliche Renderer und alle acht Ansichten; fünf Prismen erhalten, Orphan-Nodes `0 → 0`, vollständiger Erfolgsmarker und sauberer Exit unter dem strengen Runner.
- **Fehlerausgaben:** Im Nachher-Log keine `ERROR:`, ObjectDB-Leak-Warnung, zurückgehaltenen Ressourcen oder `Leaked instance`.
- **Statisch:** Workflow-YAML erfolgreich gelesen und `git diff --check` erfolgreich.

Der lokale Vergleich ist kein Android-Performance- oder physischer Samsung-Test. Die zusätzliche GitHub-Abnahme dieses Testbranches ist erst nach dem tatsächlichen CI-Ergebnis als abgeschlossen zu dokumentieren; der ältere grüne Lauf wird nicht rückwirkend als warnungsfrei umgedeutet.
