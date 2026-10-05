# Lumo Kart – zehn Strecken-Referenzpakete

**Status dieser Lieferung: Referenzbilder und technischer Bauauftrag, keine fertig implementierten zusätzlichen 3D-Strecken.**

Heinz hat den Upload und die technische Weitergabe am 05.10.2026 ausdrücklich beauftragt. Opus' bestehende Laufzeitgrafik bleibt unverändert. Diese Dateien werden in einem separaten Branch gespeichert, nicht automatisch in main oder die Test-APK übernommen.

## Einstieg für Copilot, Claude und Opus

1. [Vollständiger aktueller Arbeitsauftrag](IMPLEMENTATION_ORDER.md): Review zuerst, Boost/Richtung reparieren, bestehende 3D-Strecken in zehn Welten ausbauen, keine Stilverschlechterung, klare Zuständigkeiten und Nachweise.
2. [Importmanifest](IMPORT_MANIFEST.json): elf Original-ZIPs mit Dateigröße und SHA-256. Nach erfolgreichem Import: `IMPORT_REPORT.json` und `SHA256SUMS.txt`.
3. Entpackte, deduplizierte Bildreferenzen: `docs/design_targets/2026-10-05-tracks/`. `.gdignore` hält Referenzmaterial aus dem Godot-Import. Das ist keine automatische Runtime-Asset-Registrierung.
4. Historische ZIP-Texte liegen unverändert unter `legacy_reference_notes/`. Sie sind keine aktiven Agentenanweisungen; generische Checklistenzeilen zählen nicht als gebaute Details.

## Downloads nach erfolgreichem Importlauf

GitHub-Referenz-Vorabveröffentlichung: `track-reference-packs-2026-10-05` in diesem Repository. Kein produktiver Spiel-Release, keine neue APK. Elf unveränderte Original-ZIPs sowie ein daraus gebildetes Master-ZIP und Prüfsummen werden dort abgelegt. Ein erfolgreicher Workflow und die Release-Assetliste sind der Uploadnachweis, nicht allein dieser Text.

| Paket | Thema | Originalarchiv |
| --- | --- | --- |
| 01 | Himmelsstadt / Skyline Sprint | `Track_01_skyline_sprint_clouds.zip` |
| 02 | Kristallschlucht | `Track_02_crystal_canyon_dash.zip` |
| 03 | Dschungeltempel | `Track_03_jungle_temple_turbo.zip` |
| 04 | Wasserhafen | `Track_04_aqua_harbor_rush.zip` |
| 05 | Süßigkeitenwolken | `Track_05_candy_cloud_circuit.zip` |
| 06 | Vulkan-Nachtrennen | `Track_06_volcano_night_run.zip` |
| 07 | Schneegipfel; eingebrannter Bildtitel ist fehlerhaft | `Track_07_skyline_sprint_winter.zip` |
| 08 | Weltraum | `Track_08_galaxy_ringway.zip` |
| 09 | Wüste / Oase | `Track_09_desert_dune_drift.zip` |
| 10 | Entdecker-Campus; keine Lernfragen im Rennen | `Track_10_learning_lab_circuit.zip` |
| Gemeinsam | zehn 2D-Item-/Modul-Referenzicons | `Shared_Core_Assets.zip` |

## Was tatsächlich enthalten ist

Je Streckenarchiv 18 Dateien: 12 PNG-Dateien (zwei Fassungen desselben Hero-Bildes und dieselben zehn gemeinsamen Icons), sechs Text-/JSON-Dateien. Keine GLB-/Blend-/OBJ-Modelle oder Collider. Je 120-Punkte-Liste sind 104 Zeilen allgemeine Platzhalter. Die größeren PNG-Fassungen wurden lediglich skaliert; der Import verändert oder erweitert sie nicht. Dedupliziert ergeben sich 30 PNG-Dateien: zehn ursprüngliche Hero-Bilder, zehn vergrößerte Fassungen und zehn gemeinsame Icons.

## Übergabe an Opus

Technik: Copilot prüft vorhandene Umsetzung/Claims zuerst und bearbeitet kleine abgegrenzte Schritte. Opus übernimmt stilkritische Figur-/Material-/Licht- und Kompositionsarbeit; Lumo soll dem App-Fuchs entsprechen. Das bedeutet keine behauptete neue Opus-Sitzung. Die aktuelle Laufzeitgrafik und der korrigierte Fahrzeug-Geometriepfad aus #13 werden beim Referenzimport nicht geändert.

Der anschließende Bearbeiter führt `TRACK_PROGRESS.md` und `TRACK_BUILD_ROADMAP.md` mit Basis-/Ergebnis-SHA, konkreten Dateien, Tests, echten Szenenbildern und offenen Opus-Aufgaben. Ein Upload ist keine Umsetzung, ein bestandener Importtest ist kein Rennspieltest und eine Konzeptgrafik ist kein Geräte-Screenshot.
