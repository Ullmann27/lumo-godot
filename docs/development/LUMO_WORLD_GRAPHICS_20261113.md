# LUMO: Winterwelt und räumlicher Streckenausbau

Ausgangsbasis: Godot `ada5ed81ad62339f15289da62670c0a4f9f7f2b9`.

## Gestaltung

Die Übertragung betrifft Gestaltungsmethoden, keine fremden Figuren, Assets oder Strecken:

- Nintendos [Entwicklerinterview Teil 2](https://www.nintendo.com/en-gb/News/2025/May/Ask-the-Developer-Vol-18-Mario-Kart-World-Chapter-2-2832717.html) beschreibt zusammenhängende Landschaften, Klimawechsel und Landmarken als verbindende Elemente.
- [Teil 4](https://www.nintendo.com/en-ca/whatsnew/ask-the-developer-vol-18-mario-kart-world-part-4/) erläutert erkennbare Landmarken und intuitive Streckenführung.
- Die [offizielle SEGA-Beschreibung](https://asia.sega.com/SonicRacingCrossWorlds/en/about.html) und der [SEGA-Beitrag zum Gameplay](https://blog.playstation.com/2025/02/12/sonic-racing-crossworlds-gameplay-revealed-new-mechanics-detailed/) zeigen unterschiedliche Rennabschnitte und markante Veränderungen innerhalb einer Runde.

Daraus leitet dieser Patch eine eigene Winterwelt ab: zusammenhängender Bergrücken, eine Eisgalerie auf der bestehenden Rennlinie und ein erkennbarer Seilbahnkomplex. Es wird keine Gleichwertigkeit mit den Referenzspielen behauptet.

## Produktiver Anschluss

`kart_expansion_world.gd` ruft das neue Modul `kart_winter_alpine_world.gd` im tatsächlichen Weltaufbau auf. Der Verlauf der Straße, die Physik und die vorhandene Sprungsequenz werden nicht verändert.

- Sechs beziehungsweise neun gestaffelte Berggipfel mit Schneehauben.
- Zwei eigenständig modellierte Stationen mit Dach, Fenstern, Stützen, Podest, Treppen und warmen Leuchten.
- Eine doppelte durchhängende Seiltrasse mit Trägern und vier räumlichen Kabinen. In diesem ersten Prüfstand sind diese Kabinen statisch.
- Vier breite Eisrippen mit seitlichen Gesteins-/Schneewänden; die bestehende Strecke führt durch ihre freien Öffnungen.
- 206 neue instanzierte Teile im niedrigen, 274 im vollen Detailprofil; statische Teile nutzen die bestehenden MultiMesh-Batches. Keine zusätzlichen Spielkollisionen oder dynamischen Lichter.

## Tatsächliche Prüfung

Godot 4.6.3, echter Headless-Produktionsweltaufbau: `kart_world_expansion_regression.gd` bestand 23 Prüfungen, null Fehler. Je Profil wurden alle 3.447 gebackenen Fahrbahnsegmente berücksichtigt. Die Prüfung kontrolliert transformierte Meshgrenzen und, bei räumlicher Nähe, insgesamt 4.128 Dreieckgrenzen gegen einen 17 Meter breiten und sechs Meter hohen freien Fahrkorridor. Wiederholter Aufbau und Wechsel zur Laborwelt hinterließen keine zusätzliche Alpengeometrie.

Alle vier berührten GDScript-Dateien bestanden `gdlint`. Die neuen Dateien bestanden `gdformat --check`. Das Capture-Skript bestand den echten Godot-Compiler.

`kart_world_expansion_capture.gd` lädt die tatsächliche Kart-Produktionsszene einschließlich Lumo, Kart, HUD und Beleuchtung. Es erstellt drei gestellte Rennansichten und ein Manifest mit Quellstand, Kamera, Bildhash und Renderer. Dieselbe Datei kann auf der Ausgangsbasis ausgeführt werden, da sie keine neuen Modulklassen voraussetzt. Ausgabe: `LUMO_CAPTURE_DIR`; Nutzerverzeichnis: gesondertes `XDG_DATA_HOME`.

**Noch kein frischer Pixelnachweis:** Die lokale Umgebung stellt keinen verwendbaren X11-Renderer bereit. Ein Grafiklauf wird durch die Integration ausgeführt. Keine Android-Bildrate, Gerätewärme oder echte gefahrene Runde wird durch diesen statischen Grafiktest behauptet.
