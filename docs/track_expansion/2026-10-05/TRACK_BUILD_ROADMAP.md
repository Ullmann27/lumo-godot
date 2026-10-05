# Kart-Streckenausbau – Roadmap

- Referenzbasis: Godot-PR #14, `7351f1756e1910389450e041185b846823a97e92`.
- Aktueller Umsetzungsstand: Godot-PR #15; Turbo-Code und Regression `1c090c112400762e349647b60d20733be824b46c`.
- Die zehn ZIP-Pakete und ihre PNGs sind Themen-/Detailreferenzen, keine fertigen Laufzeitmodelle oder Strecken. Keine zusätzlichen Strecken oder Geräte-FPS werden hier als fertig behauptet.

## Reihenfolge und Abhängigkeiten

1. **Boost-Reaktion – implementiert, automatisiert geprüft.** Die physische Beschleunigung reagiert ab dem ersten Physikschritt auf einen akzeptierten Turbo; VFX-/Audiostatus und Bedien-Sperren sind im Regressionstest enthalten. Echte Geräte-Latenz bleibt offen.
2. **Fold-/Resize-Pass – eingeplant, vor Streckenausbau und Fold-Freigabe.** Der momentane `size_changed`-Handler wendet nur Safe-Area-Margen neu an. Controls und Kamera sind noch nicht als adaptive Fold-Layouts abgenommen; der Startpfad wartet auf Landscape. Laufzeitfixes erst nach separatem Claim und Abgleich mit dem Flutter-Auftrag PR #197.
3. **Bodenpfeile – offen.** Tatsächliche Pfeilrichtung mit lokaler Tangente und Fahrtrichtung auf geraden, gebogenen, geneigten und gespiegelten Segmenten vergleichen. Vor Änderung betroffene Renderer-/Geometriepfade feststellen; keine globale 180°-Korrektur.
4. **Ein vollständiger Ausbauabschnitt – offen.** Auf vorhandenem Kursstil aufbauen: echte 3D-Fahrbahn, stabile Anschluss-Sockets und Collider, längere Streckenführung, Rampe mit Landung, Checkpoints/Respawn und KI-Weg. Erst nach vollständiger Runde und Vorher-/Nachher-Spielaufnahmen abnehmen.
5. **Zehn eigenständige Welten – offen und von Schritt 4 abhängig.** Unterschiedliche Streckengeometrie und Dramaturgie statt Farbvarianten; gemeinsam nutzbare, geprüfte Bauteil-Schnittstellen.
6. **Detailkatalog, Gegner, Items und Fahrzeuge – offen.** Pro Welt reale Platzierungen mit eindeutigen IDs, Transform, Funktion, Kollisionsrolle, LOD, Quelle und Prüfstatus dokumentieren. Checklisten-Platzhalter zählen nicht als Modelle.
7. **App-/Flutter-Integration und Stilabnahme – separat koordinieren.** Godot-Pin, Sterne/Unlocks, Wallet und APK nicht in diesem technischen Boost-Schritt ändern. Opus-Stilabnahme erst nach einem echten Laufzeitbild aus dem fertigen Abschnitt; Modell-/Sitzungsstart nicht behaupten, bevor er erfolgt ist.

## Fold-/Resize-Abnahme

### Befund vor Umsetzung

- `scripts/games/kart_island.gd` setzt intern eine 1280×720-Landschaftsfläche, fordert Sensor-Landscape an und bricht die Initialisierung ab, wenn die Fläche nicht rechtzeitig Landscape meldet.
- Das `Viewport.size_changed`-Signal ruft aktuell `_update_safe_area()` auf; es gibt dort keine getrennte adaptive Neuberechnung der HUD-, Joystick-, Pedal-, Boost-, Item- und Pause-Layouts.
- Safe-Area-Werte werden skaliert, aber es gibt noch keinen belegten Godot-/Host-Vertrag für die Position oder Breite einer inneren Falz. Safe-Area allein darf nicht als Hinge-Erkennung ausgegeben werden.
- Die Flutter-Seite meldet eine portrait-Orientierung der erzeugten `LumoGameActivity`, während Kart Sensor-Landscape anfordert. Diese Host-/Godot-Grenze muss mit PR #197 geklärt werden; kein Portrait-Lock oder ungeprüfter Manifest-/Pin-Wechsel in diesem Kart-PR.

### Begrenzter technischer Pass und Testmatrix

1. Öffnen, Schließen und Resize-Ereignisse robust behandeln: tatsächliche Fenster-/Viewportmaße nach dem Host-Übergang abwarten, Layout erneut berechnen und keine veralteten Safe-Area-Werte behalten.
2. Adaptives Layout für Garage/Modus-/Fahrzeug-/Streckenauswahl, HUD, Joystick, Gas/Bremse, Boost, Item-Button, Minimap, Pause und Ergebnis definieren. Nach jedem Resize Touch-Flächen, Mindestgrößen und Überlappungen erneut prüfen.
3. Cutout und Falz als gesperrte Interaktionsfläche behandeln. Vor Implementierung klären, welche Hinge-/Occlusion-Metadaten der Android-Host tatsächlich an Godot liefern kann. Controls müssen in den verfügbaren Paneelen liegen; wenn eine Falzgeometrie nicht verfügbar ist, das als Plattformlücke melden und nicht als gelöst markieren.
4. Kamera-/Szenenkomposition bei geschlossenem Außendisplay, geöffnetem Innendisplay und Zwischen-/Split-Screen-Größen visuell prüfen. Seitenverhältnis nicht durch Skalieren der 3D-Szene verfälschen; vertikales FOV, sichtbare Strecke und UI-Safe-Framing gezielt abstimmen.
5. Auf echtem Foldable vollständigen Ablauf prüfen: Garage und Auswahl → Start/Rennen → Sprung/Looping → Resize/Fold während Rennen → Pause/Fortsetzen → Zieleinfahrt → Ergebnis/Neustart. Zusätzlich Resize beim Öffnen/Schließen der Activity sowie Rückkehr vom Host testen.
6. Physik, Geschwindigkeit, Streckenmaß, Collider und Boost bleiben in Welt-/Sekundeneinheiten; Fenster- und Pixelmaße beeinflussen ausschließlich Darstellung, Layout und Eingabeabbildung.
7. Vor Laufzeitänderungen die genaue Datei `docs/TASK_FOLD_2026-10-05.md` und Testmatrix aus lumo-lernen PR #197 lesen, mit dem zuständigen Flutter-Bearbeiter koordinieren und dessen Branch/PR unverändert lassen. Diese Datei war bei der Erstellung dieser Roadmap nicht abrufbar; die Matrix oben übernimmt daher nur die ausdrücklich im Godot-Kommentar genannten Punkte.

## Abnahmegrenzen

- Geometrie und Kollision werden im Godot-Spiel getestet; PNG-Referenzen und Konzeptbilder sind keine Laufzeitnachweise.
- Jede Strecke benötigt vollständigen Rundenlauf, KI-Durchfahrt, Checkpoint-/Respawn-, Pause- und Host-Prüfungen.
- Eine bestandene Desktop-/Headless-Resize-Regression ist keine Fold-Geräteabnahme. Geräte-, Hinge-, Touch-, Renderer- und Frame-Pacing-Befunde getrennt dokumentieren.
- Headless-Ergebnisse belegen keine visuelle Qualität und keine 60 FPS auf einem Fold 7. Dafür sind echte Geräteaufnahmen und Frame-Pacing-Messungen nötig.
- Kein Produktionsmerge, APK-Release oder Zahlungswechsel ohne gesonderte Freigabe.
