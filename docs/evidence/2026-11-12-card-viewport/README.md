# Kartauswahl in kurzer Android-Queransicht

## Ausgangspunkt und abgegrenzter Befund

Basis ist der unveränderte Remote-Commit `f04e580ec0d7d8f70e8be269523fabedd15b0766`, Tree `54c54c9d652d9908a5bf7d12ee2de0c338553a0c`. Dessen vorheriger nativer Renderer-Lauf [43214880684](https://github.com/Ullmann27/lumo-godot/actions/runs/43214880684) war erfolgreich: `[SpatialMenu] PASS 594 checks; 5/5 cases; renderer=X11`. Main und Stage2 checkten tatsächlich diesen Commit aus. Der getrennte CompleteFlow-Lauf verwendete dagegen den virtuellen PR-Merge `6d2b450adc9405fffa18ac68c832a6423d40532b`, dessen Tree nach der API-Prüfung der Integration identisch war.

Die Sichtprüfung der echten `garage-2400x1080.png` aus dem Main-Artefakt zeigte trotzdem einen konkreten Restfehler: Der ausgewählte Gecko konnte seine unteren Statbalken nicht vollständig im Scrollbereich zeigen. Das ist kein abgeschnittener Beginn der nächsten Karte. Die nachfolgende unveränderte Laufzeitmessung bestätigt 216 physische Pixel / 82,28571 dp Scrollhöhe bei 236,25 Pixel / 90 dp Kartenhöhe. Selbst Ausrichtung der Kartenoberkante an der Scrolloberkante lässt 20,25 physische Pixel überstehen (`original-card-bounds.log`).

Die offizielle ZIP wurde unabhängig aus den heruntergeladenen Bytes geprüft: Artefakt `13943123760`, `lumo-actual-gameplay-evidence`, 37.832.251 Bytes, SHA256 `8461ea7e4b54e2b72a48cc1a5fcb1830a8a71c63a2ceef7bd8d2f2d9193dedd3`, offizieller Digest identisch und ZIP-CRC fehlerfrei. Der Erfolg dieser bisherigen Renderer-Prüfung und der anschließend erkannte Kartenfehler werden ausdrücklich getrennt geführt.

## Kleine Produktionskorrektur

`scripts/games/kart_spatial_menu.gd` erweitert ausschließlich die vorhandene Werkstatt-im-Footer-Bedingung für Kartauswahl (`step == 2`): Die bisherigen `ultra_short`-Fälle bleiben erhalten; zusätzlich nutzen Queransichten mit weniger als 360 dp sicherer Höhe denselben vorhandenen Footer-Zweig. Der Werkstatt-Button verwendet unverändert seine bestehende Signalroute. Dadurch wächst die Liste im gemessenen Androidfall auf 358,5 physische Pixel / 136,5714 dp.

Der erste Kandidat mit dieser Bedingung allein war noch nicht ausreichend. Die strenge Sichtbarkeitsprüfung erkannte bei ganzzahligem Scrolloffset einen Restüberhang von 0,75 physischen Pixeln: Die 90-dp-Karte hatte bei UI-Skalierung 1,75 eine Höhe von 157,5 logischen Pixeln. `ensure_control_visible` ließ ihre Unterkante bei 743,75 statt maximal 743 Pixeln stehen (`fractional-card-bounds.log`). Deshalb wird ausschließlich die bereits skalierte Mindesthöhe der Kartkarten auf einen ganzen logischen Pixel aufgerundet. Im konkreten Fall sind das 158 logische Pixel / 90,28571 dp. Die Karte wird nicht verkleinert und die Testtoleranz bleibt unverändert bei 0,01 logischen Pixeln.

## Identische finale Positiv- und Negativprüfung

Die vier bestehenden Fälle des `kart_compact_selection_regression.gd` bleiben enthalten. Zwei zusätzliche Fälle bilden die tatsächliche Androidgeometrie ab: 2400 × 1080 Pixel, Dichte 2,625 / 420 dpi, Insets links 0, oben 32, rechts 0, unten 126 Pixel, sichere Fläche 914,2857 × 351,2381 dp, jeweils ohne und mit Fortsetzen. Jeder Fall scrollt alle 14 Karten einzeln in Sicht und verlangt die vollständige Einfassung im Scrollrechteck. Androidkarten müssen weiterhin mindestens 90 dp hoch sein. Sichtbare Footer-Ziele müssen mindestens 48 dp groß, innerhalb der sicheren Fläche und paarweise überschneidungsfrei sein.

Gecko-Auswahl und Werkstatt werden durch echte `InputEventScreenTouch`-Eingaben an den Produktionscontrols geprüft. Start und Fortsetzen werden ebenfalls real berührt und bis zum jeweiligen bestehenden Produktionssignal beobachtet. Nur die anschließenden Renn-/Speicher-Empfänger werden für diese Layoutprobe vorübergehend durch Beobachter ersetzt und danach wiederhergestellt. Die vollständige Renn-/Save-/Resume-Abnahme bleibt beim bestehenden CompleteFlow-Gate.

| Stand | Ergebnis | Android vollständig sichtbare Karten | Log |
| --- | --- | --- | --- |
| f04, finaler identischer Test | **FAIL 346**, 6/6 Fälle, Exit 1 | 0/14 in beiden Fällen | `final-baseline.log` |
| Footer plus Pixelaufrundung, derselbe finale Test | **PASS 355**, 6/6 Fälle, Exit 0 | 14/14 in beiden Fällen | `final-fixed.log` |
| Frühe f04-Diagnose, vor zusätzlicher 90-dp-Assertion | FAIL 318, 6/6 Fälle, Exit 1 | 0/14 | `baseline-initial.log` |
| Früher Footer-Kandidat ohne Pixelaufrundung | FAIL 327, 6/6 Fälle, Exit 1 | 1/14 | `footer-only.log` |

Die finalen Testbytes sind in beiden Läufen identisch: SHA256 `5da50404d04bdc584ac5174ca8123ad9cdd4b55c895954f97d17f4cb9133b93a`. Unterschiedliche Prüfzahlen entstehen durch die zusätzliche sichtbare Werkstatt im Footer und deren Größen-/Überlappungsprüfungen. Die finale Positivprobe enthält keine ERROR-, Script- oder Assertion-Fehlerzeilen. Alle sechs Fälle melden 14/14. Start meldet genau `start:gecko_velo`; Fälle mit Fortsetzen melden anschließend genau `resume`.

## Ausführung und Grenzen

Beide finalen Läufe nutzten Godot `4.6.3.stable.official.7d41c59c4`, denselben Test, den unveränderten Projektimport und getrennte lokale Daten-/Konfigurationsordner:

```sh
XDG_DATA_HOME="$PWD/exports/card-viewport/final-fixed-data" \
XDG_CONFIG_HOME="$PWD/exports/card-viewport/final-fixed-config" \
timeout 120s /usr/local/bin/godot --headless --path "$PWD" \
  --script res://scripts/tests/kart_compact_selection_regression.gd
```

Für die Negativkontrolle waren ausschließlich die Produktionsbytes von `kart_spatial_menu.gd` aus f04 aktiv; Test und sonstige Quellen blieben identisch. Danach wurden die Kandidatenbytes wiederhergestellt. Der erste strukturelle Projektvalidator-Lauf (`tools/validate_project.py`, noch vor der abschließenden Pixelaufrundung) meldet 117 PASS / 7 WARN / 0 FAIL, Exit 0. `gdlint` und `gdformat` fehlen in dieser Umgebung; beide Versuche endeten mit 127 und werden nicht als bestandene Prüfungen gezählt. Der abschließende `git diff --check` bestand.

Dies sind echte Headless-Layout-/Eingabeprüfungen, keine neu gerenderten Bilder oder Android-APK-Abnahme dieses Patches. Die neue Sichtprüfung auf dem exakten integrierten Commit und dessen APK erfolgt in der bestehenden CI. Keine zusätzlichen lokalen APK-Versuche, keine Änderung von Gameplay, Speicherverträgen, Kameraführung, Assets, Versionierung oder Veröffentlichung.
