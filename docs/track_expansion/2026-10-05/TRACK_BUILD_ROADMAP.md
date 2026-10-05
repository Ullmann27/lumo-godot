# Kart-Streckenausbau – Roadmap

- Referenzbasis: Godot-PR #14, `7351f1756e1910389450e041185b846823a97e92`.
- Aktueller Umsetzungsstand: Godot-PR #15; Turbo-Code und Regression `1c090c112400762e349647b60d20733be824b46c`.
- Die zehn ZIP-Pakete und ihre PNGs sind Themen-/Detailreferenzen, keine fertigen Laufzeitmodelle oder Strecken. Keine zusätzlichen Strecken oder Geräte-FPS werden hier als fertig behauptet.

## Reihenfolge und Abhängigkeiten

1. **Boost-Reaktion – implementiert, automatisiert geprüft.** Die physische Beschleunigung reagiert ab dem ersten Physikschritt auf einen akzeptierten Turbo; VFX-/Audiostatus und Bedien-Sperren sind im Regressionstest enthalten. Echte Geräte-Latenz bleibt offen.
2. **Bodenpfeile – offen.** Tatsächliche Pfeilrichtung mit lokaler Tangente und Fahrtrichtung auf geraden, gebogenen, geneigten und gespiegelten Segmenten vergleichen. Vor Änderung betroffene Renderer-/Geometriepfade feststellen; keine globale 180°-Korrektur.
3. **Ein vollständiger Ausbauabschnitt – offen.** Auf vorhandenem Kursstil aufbauen: echte 3D-Fahrbahn, stabile Anschluss-Sockets und Collider, längere Streckenführung, Rampe mit Landung, Checkpoints/Respawn und KI-Weg. Erst nach vollständiger Runde und Vorher-/Nachher-Spielaufnahmen abnehmen.
4. **Zehn eigenständige Welten – offen und von Schritt 3 abhängig.** Unterschiedliche Streckengeometrie und Dramaturgie statt Farbvarianten; gemeinsam nutzbare, geprüfte Bauteil-Schnittstellen.
5. **Detailkatalog, Gegner, Items und Fahrzeuge – offen.** Pro Welt reale Platzierungen mit eindeutigen IDs, Transform, Funktion, Kollisionsrolle, LOD, Quelle und Prüfstatus dokumentieren. Checklisten-Platzhalter zählen nicht als Modelle.
6. **App-/Flutter-Integration und Stilabnahme – separat koordinieren.** Godot-Pin, Sterne/Unlocks, Wallet und APK nicht in diesem technischen Boost-Schritt ändern. Opus-Stilabnahme erst nach einem echten Laufzeitbild aus dem fertigen Abschnitt; Modell-/Sitzungsstart nicht behaupten, bevor er erfolgt ist.

## Abnahmegrenzen

- Geometrie und Kollision werden im Godot-Spiel getestet; PNG-Referenzen und Konzeptbilder sind keine Laufzeitnachweise.
- Jede Strecke benötigt vollständigen Rundenlauf, KI-Durchfahrt, Checkpoint-/Respawn-, Pause- und Host-Prüfungen.
- Headless-Ergebnisse belegen keine visuelle Qualität und keine 60 FPS auf einem Fold 7. Dafür sind echte Geräteaufnahmen und Frame-Pacing-Messungen nötig.
- Kein Produktionsmerge, APK-Release oder Zahlungswechsel ohne gesonderte Freigabe.
