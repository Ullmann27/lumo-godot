# Kart-Menü: tatsächliche Android-Schriftkürzung

Stand: 11. Oktober 2026. Fortsetzung auf `computer/lumo-kart-real-loading-2026-10-11`, über dem geprüften nativen Commit `a981e8b08f89b3d995cb1e0f8d2edc9027ef75f4` und [PR #54](https://github.com/Ullmann27/lumo-godot/pull/54).

## Tatsächlicher Fehler

Der [Android-16-Lauf zu APK 1928](https://github.com/Ullmann27/lumo-lernen/actions/runs/38096079080) hat die neue APK ohne Deinstallation über 1927 installiert. UID, ursprüngliche Installationszeit und fiktives Lernprofil blieben unverändert; der Test bestätigte den Offline-Zustand. Die echte Godot-Moduswahl mit dem vorhandenen animierten Lumo wurde sichtbar.

Die erste Moduskarte zeigte jedoch `Einzelrenn...` statt des vollständigen Namens. Der unveränderte Android-Screenshot wurde als Fehlerbeleg gesichert; die Runtime-Probe hat diesen echten Produktfehler nicht als bestanden markiert. Frühere Bounds-/Touch-Tests prüften die Erreichbarkeit der Karten, aber nicht die vollständige Länge ihrer Beschriftungen.

## Produktkorrektur

- **Adaptive Kartenbreite:** Auf kurzen Querflächen wird die bislang feste linke Spalte von 175 dp abhängig von der tatsächlichen logischen Breite erweitert, maximal auf 240 dp. Die vorhandene echte 3D-Vorschau und der einzelne Weiter-Button bleiben erhalten; kein konkurrierendes Menü und keine Schriftverkleinerung.
- **Belohnungsstatus:** Das dekorative Sternsymbol verschwindet gemeinsam mit seiner Zahl, wenn die kompakte Ansicht diese Zahl bewusst ausblendet. Es bleibt kein abgeschnittener Stern neben der Rückkehr zum Lernen.
- **Vollständige Namen:** Die Regression misst jede echte Modusbeschriftung mit ihrer tatsächlichen Font-/Schriftgröße gegen die verfügbare Label-Breite. Ellipsen genügen nicht als Erfolg.
- **Zusätzliche Dichtefälle:** 1920 × 1080 bei 1,875 und 2,75, jeweils mit expliziten 0/63/72/0-Pixel-Rändern. Diese ergänzen die bisherigen neun Telefon-, Fold- und Safe-Area-Fixtures.

Keine Änderung an Fahrphysik, Rig, GLB, Animationsclips, Profilen, Belohnungslogik, Originalweltbild oder Sulafat.

## Tatsächlich ausgeführte Prüfungen

- **Headless:** Alle elf Dichte-/Layoutfälle, 474 Prüfungen / 0 Fehler, Orphan-Baseline 0 → 0.
- **Echter GL-Renderer:** 1920 × 1080, Dichte 1,875 und definierte Ränder; 51 Prüfungen / 0 Fehler einschließlich kompletter Modusnamen, echter Auswahl, Weiter und Ressourcenfreigabe.
- **Laufzeitbild:** Tatsächlich gerendertes Godot-Bild `menu-1920x1080-density-1.88-safe-area.png`, keine Bildgenerierung.
- **Grenze:** Das korrigierte Bild ist ein Linux-/Mesa-Lauf mit Android-Dichtefixture, noch keine korrigierte Android-APK-Aufnahme. Der vorherige echte Android-Lauf gilt weiterhin als fehlgeschlagen, bis ein neuer nativer Pin tatsächlich im APK-Kandidaten erprobt wurde.

Die endgültige Android-16-Menü-/Fold-/Rennabnahme und deren tatsächliche Screenshots bleiben erforderlich. Einen grünen Desktop-Test nicht als Samsung-Abnahme ausgeben.
