# Lumo Kart – Codex-Übernahme vom 8. Oktober 2026

Ausgangspunkt: Opus-Branch `claude/continue-previous-chat-KtY7p`, Godot-Commit `5cdf5659d2cb86b6f826860a5f594d1064176402`. Die Arbeit liegt auf `codex/lumo-kart-fleet-2026-10-08`. Der Opus-Branch wurde nicht verändert.

## Implementiert

- Neun auswählbare physische Kartdesigns: die bisherigen Comet, Glider und Turbo sowie Gecko Velo, Boru Rally, Nala Comet, Noa Tide, Iva Aurora und Zuri Volt.
- Eigene Karosserieprofile, Lackierungen und Anbauteile; alle nutzen den korrigierten Lumo und die bestehenden Gelenk-, Rad-, LOD-, Drift- und Boostanimationen.
- Vorder-, Rück-, Links-, Rechts- und Draufsicht in der Garage. Feste Ansichten sind orthografisch; Ziehen kehrt zur drehbaren Ansicht zurück. Die Streckenansicht bleibt perspektivisch.
- Sechs modulare Streckendetails: Boxenstand, Tribüne, Pflanzkasten, Bank, Wegleuchte und Kristallgruppe. Sie nutzen die vorhandenen räumlichen MultiMesh-Batches, prüfen Abstand zur Straße und werden auf den drei Landstrecken am Gelände ausgerichtet.
- Rivalen fahren fünf verschiedene zusätzliche Kartdesigns.
- Exportwerkzeuge für neun statische Fahrzeug-GLBs und sechs einzeln editierbare Streckenmodule. Fahrzeuganimationen laufen weiter prozedural im Spiel; GLBs enthalten keine gebackenen Animationsclips.

## Prüfung und Reproduktion

Der lokale Headless-Projektvalidator und 28 Python-Prüfungen sind bestanden. Neue GDScript-Dateien bestehen `gdlint` und `gdformat --check`. Die vollständige alte Formatprüfung findet weiterhin bestehende lange Zeilen und Layoutabweichungen; dieser Ausbau formatiert die alten Großdateien nicht vollständig neu.

`kart_fleet_regression.gd` prüft echte Geometrie, 54 sichtbare Oberflächen je Lumo-Kart, vier animierte Räder, LOD, Drift/Boost, Garage, Fahrbewegung und gespeicherte neue Kart-IDs. `kart_fleet_prop_export.gd` exportiert und reimportiert sechs GLBs. Die grafischen Prüfungen, 52 echten PNG-Aufnahmen, das Modellvideo und der Web-Build laufen im Workflow `lumo-fleet-quality.yml` mit Godot 4.6.3. Maßgeblich sind dessen Ergebnis und der jeweilige Artefakt-Commit; ein grüner Build ist keine Behauptung von AAA-Grafik oder 60 FPS auf echter Hardware.

Zwei alte Testfixtures wurden an Opus’ neue Startaufstellung angepasst: Physik- und Sprungtests beenden die Vorschau, bevor sie Position und Fahrtrichtung für den Test setzen. Sonst überschreibt der erste Physikschritt die Testposition durch die Startaufstellung. Die getesteten Spielregeln wurden beibehalten.

## Bild- und Modellgrenzen

Die umfangreiche externe Bildserie ist Modellierungsreferenz und Zielgrafik. Die zusätzlich erstellten Figuren Piko, Boru, Nala, Noa, Iva und Zuri sind bisher Figurenentwürfe; neue spielbare Fahrer sind damit nicht behauptet. Die aktuellen Fahrer bleiben Lumo, Nova und Milo. Frühere Bildnamen Mira und Tavi sind keine Umbenennung dieser Fahrer.

Generierte verschiedene Kamerawinkel sind nicht exakt kalibrierte Ansichten einer gemeinsamen CAD-Geometrie. Die echten Godot-GLBs sind die räumlich konsistente aktuelle Geometrie. Hochwertige neue Produktionsmodelle, UVs, PBR-Texturen, Skinning und mobile Optimierung sind weitere Arbeit.

Die vorhandene gemeinsame Flutter/Godot-Apparchitektur bleibt die Integrationsbasis. Eine eigenständige Kart-App ist eine spätere Verpackungsoption. Diese Änderung aktualisiert weder den Flutter-Pin noch veröffentlicht sie eine neue APK.

## Erhaltene Opus-Funktionen

Intro mit Einfahrt/Drift, korrigierter Lumo, Streckenvorschau, einrollende Startaufstellung, Startampel, Zielfahrt, Musik/Lautstärken, Touch/Safe Area und HostBridge bleiben erhalten. Rennen enthalten weiterhin keine Lernfragen oder Antwort-Turbos.
