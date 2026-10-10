# Lumo Grafik-Grundgerüst und Astra-Übergabe

Diese Phase bereitet den vorhandenen Bestand für eine eng begrenzte visuelle
Überarbeitung vor. Sie ersetzt weder die Lern-App noch das getestete
Laufzeitmodell. Originalreferenzen, vollständige Spielpfade und gespeicherte
Lern-/Profil-/Belohnungsdaten bleiben die Vorgabe.

## Eingefrorene Ausgangsbasis

- App: [Build-1926-Quellstand dcebfbc](https://github.com/Ullmann27/lumo-lernen/commit/dcebfbc469c3f6d2fdee39cc33e3c5eef0b6cf7e).
- App-Pin: [Godot ec1040c2](https://github.com/Ullmann27/lumo-godot/commit/ec1040c2ab18f2ed207eee6c8490608cbb6a5518).
- Kart-Produktcode: [f672e02](https://github.com/Ullmann27/lumo-godot/commit/f672e02cf1101f3366b6d506fa7d7b77bb535b42), enthalten in ec1040c2.
- Vorherige Abnahme: [Fold grün](https://github.com/Ullmann27/lumo-godot/actions/runs/38055937553) und [Stage 2 grün](https://github.com/Ullmann27/lumo-godot/actions/runs/38055934253), beide für f672e02.

Der Unterschied von f672e02 zum integrierten ec1040c2 betrifft ausschließlich
den Audio-Manager. Diese Grafikphase verändert dort nichts. Sulafat-Opt-in,
Offline-Verhalten, Schreibcoach, Namenseingabe und Datenschutz werden nicht
auf den alten App-Stand zurückgesetzt. Der genaue neue Werkzeug-/Aufnahmestand
wird durch die erzeugten JSON-Manifeste festgelegt.

## Verbindliche Bildhierarchie

- Moduswahl: [50666.gif](https://raw.githubusercontent.com/Ullmann27/lumo-lernen/codex/lumo-reference-assets-2026-10-10/docs/design/2026-10-10-lumo-games/references/50666.gif). Fünf vorhandene Moduskarten links, lebendiger Original-Lumo im blauen Kart rechts, Schwebewelt, Holo-Ringe, genau eine goldene Weiter-Hauptaktion.
- Garage/Materialanmutung: [50294.png](https://raw.githubusercontent.com/Ullmann27/lumo-lernen/codex/lumo-reference-assets-2026-10-10/docs/design/2026-10-10-lumo-games/references/50294.png). Nur Ergänzung, kein Austausch der Moduswahl.
- Renn-/Ergebniskontext: [50288.png](https://raw.githubusercontent.com/Ullmann27/lumo-lernen/codex/lumo-reference-assets-2026-10-10/docs/design/2026-10-10-lumo-games/references/50288.png). Darstellung darf keine nicht implementierte Rennfunktion vortäuschen.
- Geschützte Lernwelt: [50610.png](https://raw.githubusercontent.com/Ullmann27/lumo-lernen/codex/lumo-reference-assets-2026-10-10/docs/design/2026-10-10-lumo-games/references/50610.png) und [Design-Bestandsschutz](https://github.com/Ullmann27/lumo-lernen/blob/codex/lumo-reference-assets-2026-10-10/docs/design/2026-10-10-lumo-games/DESIGN_BESTANDSSCHUTZ.md).

Alle zehn Originalbilder werden anhand des vorhandenen SHA256SUMS-Manifests
geprüft. Generierte Konzepte und SVG-Skizzen sind keine neuen Marken- oder
Laufzeit-Referenzen. Kein Ersatzfuchs und keine neue Designrichtung.

## Bereits wiederverwendbare Bausteine

| Bereich | Vorhandener Einstieg | Grenze / Aufgabe |
| --- | --- | --- |
| Originalfiguren, Logos, Hintergründe | Flutter `assets/lumo_design/`, `lib/widgets/design/lumo_design_system.dart` | Originaldateien wiederverwenden; keine parallele Asset-Familie |
| App-Farben | `lib/theme/lumo_visual_tokens.dart` | Keine globale Neufärbung oder neue Token-Bibliothek |
| Glas und Feedback | `lib/features/shared/widgets/lumo_premium_effects.dart` | Nur vorhandene Komponenten gezielt verfeinern |
| Kartenlayout | `lib/features/games/lumo_cards/` | Kleine Querformate haben eine reservierte Arena; alle Regeln bleiben erhalten |
| Kart-Menü | `scripts/games/kart_garage_menu.gd` | Fünf Schritte, echte Moduswahl, Weiter, Zurück, gespeichertes Rennen erhalten |
| Originalfigur/Kart | `scripts/games/kart_vehicle.gd`, `kart_character_finish.gd`, `kart_fur_geometry.gd` | Erst Bestand prüfen; editierbare Quelle ist ein statischer Snapshot, kein neues Rig |
| Garagenlicht | `scripts/games/kart_stage.gd` | Gesicherte Podium-Lebensdauer nicht rückgängig machen |
| Renderer-Fallback | `scripts/games/visual/kart_environment_polish.gd` | Tatsächlich aktiven Renderer berücksichtigen, mobile/GL-Fallback erhalten |
| Glas, Neon, Schwanz | `scripts/games/visual/kart_premium_glass.gd`, `kart_neon_gates.gd`, `kart_tail_spring_adapter.gd` | Kein zweites konkurrierendes Effekt-System |
| Sonnenhafen | `kart_harbor_dressing.gd`, `kart_landmarks.gd`, `kart_track_detail.gd` | Fahrgeometrie/Checkpoint-System nicht durch Dekoration verändern |

## Technische Aufnahme- und Importwerkzeuge

- `kart_aaa_menu_capture.gd`: gleiche Seed-, Stern-, Pose- und Menüwerte; echte
  1280×720-, 640×360- und 1200×896-Aufnahmen; fünf sichtbare Modi, Weiter im
  sichtbaren Bereich; sauberes Audio-Drain beim Prozessende.
- `kart_reference_capture.gd`: vier echte 900×900-Modellansichten mit Position,
  FOV, Quellcommit und ausdrücklich separater Studio-Beleuchtung.
- `aaa_export_runtime_asset.gd`: existierendes Modell mit Pivot-Hierarchie
  exportieren; unsichtbare Fernansicht und Laufzeitpartikel auslassen.
- `aaa_blender_archive.py` / `aaa_verify_glb.gd`: editierbares Blender-Archiv,
  GLB-Roundtrip, Geometrieanzahl, Materialbelegung und Prüfsummen.
- `aaa_reference_packet.py`: vorhandene Referenzen, Metadaten, Aufnahmen und
  das 3D-Archiv offline zu einem geprüften Paket sammeln.

Werkzeuge, Tests, Dokumente und Produktionsarchive sind über die vorhandenen
Export-Filter von der Android-/Web-/Linux-Laufzeit ausgeschlossen.
Software-GL-Aufnahmen sind keine Smartphone-Messung. Eine gestellte
Streckenansicht ist kein Nachweis einer tatsächlich gefahrenen Runde.

## Genau diese Arbeit soll Astra übernehmen

### Hoch: gezielte Referenzprüfung und visueller Feinschliff

Zuerst nur den gemeinsamen Original-Lumo/Comet und die Moduswahl bearbeiten.
Referenz gegen die gelieferten echten Aufnahmen vergleichen. Eine priorisierte,
kurze Abweichungsliste erstellen und nur die wichtigsten Punkte umsetzen:
Kameraframing, Größenverhältnis von Figur/Kart, Materiallesbarkeit, weiche
Lichtführung und kontrollierte Cyan-/Gold-Akzente. Keine neue Konzeptserie.

Nach einer zusammenhängenden sichtbaren Verbesserung genau dieselben
Aufnahmen erneut erzeugen und echte Vorher/Nachher-Bilder vorzeigen. Erst
nach Abnahme diesen Stil auf Sonnenhafen und Ergebnisdarstellung anwenden.
Ergebnisabzeichen müssen zum tatsächlich berechneten Rennplatz passen;
Zeit, Runden, Sterne und Fortschritt stammen weiter aus der echten Logik.

### Sehr hoch: nur wenn Geometrie oder Shader die Referenz begrenzen

Nur die identifizierten schwierigen 3D-Punkte übernehmen: Gesicht-/Wangen-
und Augenproportionen, Ohren, Brille, Fellübergänge, Kart-Silhouette,
Materialkonsolidierung/UVs, bei begründetem Bedarf Topologie oder Rig.
Orange/cremefarbenes Fell, warmbraune Augen, Originalbrille und blaues Outfit
beibehalten. Komplexe Shader nur bearbeiten, wenn Standardmaterialien und
die vorhandenen Adapter die konkrete Referenzabweichung nicht lösen.

Das `.blend` ist editierbarer Bestand und keine fertig freigegebene,
mobileoptimierte Figur. Anzahl der Dreiecke und Materialien ist Inventar,
kein Leistungsbudget und keine Geräte-FPS-Zusage. Neue Laufzeitmodelle
erst nach Import-, Animations-, Kollisions- und Geräteprüfung ersetzen.

### Nicht an Astra vergeben

Gewöhnliche Programmierung, Fehlersuche, Tests, Pin-Integration, APK-Builds,
Sprach-Backend, Profil-/Wallet-Migrationen und wiederholte Referenzsuche
bleiben technische Aufgaben. Keine erneuten Bildgenerierungen für bereits
vorhandene Assets, keine vollständige Neugestaltung aller Welten parallel.

## Abnahme vor Integration und Android-Build

Geänderte Bereiche gezielt testen, nicht unveränderte Abnahmen mehrfach
wiederholen. Nach tatsächlichen Produkt-/Shader-/Fahrgeometrieänderungen
Fold und Stage 2 auf genau demselben neuen Commit laufen lassen. Erst dann
App-Godot-Pin aktualisieren und ein einziges Android-Kandidatenpaket bauen.
Datenerhalt, Android-Installation, Navigation und Geräteperformance bleiben
separate, reale Abnahmeaufgaben und dürfen nicht als erledigt ausgegeben werden.

Aktuell implementierte Rennen verwenden zwei Runden; Referenzbilder mit
drei Runden allein berechtigen nicht, die Anzeige ohne entsprechende Logik
zu ändern. Die Sprache darf nicht wieder auf alte TTS-Aufnahmen zurückfallen.
