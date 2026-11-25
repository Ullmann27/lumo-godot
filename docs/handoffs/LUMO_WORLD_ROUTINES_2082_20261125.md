# LUMO 2082 – Tagesaktivitäten und Lernaufträge in der World

## Ausgangspunkt

- Repository: Ullmann27/lumo-godot.
- Basis: c814e35249e4038f903d1fca3e19bb4751040a43 (integration/godot-2081-20261124).
- Feature-Zweig: feature/intelligence-2082-world-kart-20261125.
- Die bestehende World enthält neun zusätzliche Figuren aus dem originalen Fahrer-Roster. Ihr Auftragssystem und ihre gespeicherten Karten bleiben die Grundlage.

## Änderungen

1. Alle neun Figuren bekommen individuelle Interessen und vier beschriebene Tagesaktivitäten. Die aktive Phase steht am vorhandenen Rollenschild und lässt sich im Dialog erfragen.
2. Der simulierte Tageslauf gehört zur laufenden World-Sitzung. Er beginnt bei einem neuen Besuch am Morgen, läuft nur bei aktivem Spiel und pausiert während Gesprächen und Pausen. Es entstehen keine Fristen oder zeitabhängigen Quest-Sperren.
3. Der neue Gesprächsweg ist auch erreichbar, solange die Figur einen offenen Auftrag hat. „Zum Auftrag“ führt zurück; die Lernseite kann den tatsächlich vorhandenen Auftrag auf der Karte verfolgen.
4. Die vorhandenen passenden Gesten werden verwendet. Ihre Wiedergabe folgt der World-Zeit. Im Gespräch bewegt sich nur die Sprechgeste der angesprochenen Figur; ihr Standort und der Tageslauf bleiben stehen.
5. Kurze lokale Wege sind durch Nähe, reduzierte Animationen, eine maximale Schrittweite, Bodenprüfung und Kapsel-Kollisionsabfrage begrenzt. Es kommen keine neuen blockierenden Physikkörper hinzu. Modellposition, Interaktionsabstand, Namen, Questmarker und Karte bleiben verbunden.
6. Gespräche über Interessen/Alltag erzeugen keine Lernleistung, Quest-Abschlüsse, Karten, Sterne oder XP. Die bestehende Speicherung und die Schulbelege werden nicht umgedeutet.

## Grenze der vorhandenen Charaktere

Die World lädt derzeit ROSTER.racing_model_path(...). Das Produktionsmanifest unter assets/kart/production/drivers/manifest.json und kart_rival_model_contract.gd beschreiben sitzend ausgelegte Fahrer mit zwölf Clips. Es ist kein walk, walking oder walk_forward enthalten. Diese Figuren bleiben deshalb am bisherigen Standort. Ein sitzendes Modell wird nicht als gehender NPC über den Boden verschoben.

Der Code unterstützt kurze Wege erst, wenn ein passender echter Gehclip vorhanden ist. Eine neue Animation benötigt weiterhin eine visuelle Prüfung. Tätigkeiten wie „Bücher sortieren“ werden durch Dialog, Rollenschild und vorhandene Gesten beschrieben; es wird kein physisches Umräumen von Requisiten behauptet.

## Kart-Befund

Die vorhandene Rivalensteuerung wurde hinsichtlich Kurvenvorausschau, Verkehrsbremsung, Spurwahl, Überholmanöver und Boost-Voraussetzungen gelesen. Dabei wurde kein hinreichend isolierter neuer Defekt nachgewiesen. Es wurden keine spekulativen Änderungen an Kart-Physik oder Schwierigkeit vorgenommen.

## Prüfungen

Neu:

- scripts/tests/lumo_world_routines_regression.gd: alle Identitäten und Tagesphasen, Dialogerreichbarkeit, keine erschlichenen Fortschritte, Gehclip-Sperre, Zeit-/Nähe-/Pause-/Barrierefreiheitsgrenzen und begrenzte Wege.
- scripts/tests/lumo_world_routines_integration_regression.gd: Produktionsszene, originale Clips, reale Dialogtasten, Rückkehr zum Auftrag, Karten-/Markerverbindung, Pausen und reale Kollision mit einer Testwand.

Aufrufe nach vollständigem Asset-Import, mit der Projektversion Godot 4.6.3:

    godot --headless --path . --script res://scripts/tests/lumo_world_routines_regression.gd
    godot --headless --path . --script res://scripts/tests/lumo_world_routines_integration_regression.gd
    godot --headless --path . --script res://scripts/tests/lumo_world_open_world_integration_regression.gd
    godot --headless --path . --script res://scripts/tests/lumo_world_quest_integrity_regression.gd

Status dieses Quellcode-Checkpoints: **NOT EXECUTED**. Die lokale Ausführungsumgebung war nicht verfügbar. Ein erfolgreicher Remote-Commit beweist weder Kompilierung noch eine gelaufene Godot-Prüfung. Die Integration muss die oben genannten Prüfungen ausführen; deren Ergebnisse ersetzen diesen ausdrücklich vorläufigen Status. Kein Fold7-, APK- oder FPS-Nachweis wird hier behauptet.
