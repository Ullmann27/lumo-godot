# Lumo Produktion: Fortschritt und sichere Fortsetzung

Stand: 10. Oktober 2026. Der neue Masterauftrag wird in der vorgegebenen Reihenfolge bearbeitet. Fertige Modellimporte werden nicht mit einer ausgelieferten App oder einer akzeptierten visuellen Oberfläche gleichgesetzt.

## Ausgangsstand und Arbeitsgrenzen

- **Godot-Ausgangscommit:** `b056d5349c5d111a4c9ca41710681b87585f2d62`, vorhandene Animation aus [PR #51](https://github.com/Ullmann27/lumo-godot/pull/51).
- **Aktueller Branch:** `computer/lumo-kart-animation-integration-2026-10-10`, eigenes Arbeitsverzeichnis `lumo-godot-animation`.
- **Flutter:** Der bestehende Rivalen-Checkout enthält noch uncommittete Arbeiten. Diese Dateien werden nicht überschrieben; weitere App-Arbeiten benötigen ein separates eigenes Worktree.
- **Git-Sicherheit:** Keine Force-Pushes, keine automatischen Merges nach `main`, keine Änderung fremder Arbeitsverzeichnisse.
- **Audio:** Sulafat, Sprachprovider und die zugehörigen Einstellungen sind ausdrücklich außerhalb dieser grafischen Integrationsphase.

## Nachweislich implementierte Renn-Animationsintegration

Der normale Kart-Spieler bindet beim Fuchs das vorhandene 65-Knochen-Modell ein. Lenken, Boost, Drift, wirklicher Rampenflug, Treffer, Pause, Ruhemodus, Kart-Neuaufbau und der vorhandene Zieleinlauf erreichen den visuellen Adapter. Während des Ausrollens hält die linke Hand das Lenkrad; die Figur kehrt nach dem Jubel zur Sitzpose zurück.

Geändert wurden `kart_island.gd`, `kart_vehicle.gd`, die beiden vorhandenen Lumo-Animationsskripte, die isolierte Jubelassertion und zwei bestehende CI-Workflows. Hinzu kommen der echte Produktszenen-Test, ein reproduzierbarer Prüf-Runner und eine eng begrenzte Dokumentations-Importgrenze. Details stehen in `docs/design/2026-10-10-kart-animation-integration/README.md`.

Keine Änderungen an Rennphysik, Kollisionen, Lernfunktionen, Save-Schema oder Belohnungsberechnung. Kein zweiter Charakter und kein neuer kostenpflichtiger 3D-Auftrag.

## Tatsächliche Testergebnisse

- **Produktszene:** Headless 2.069 Prüfungen / 0 Fehler; echter GL-Lauf 2.116 Prüfungen / 0 Fehler und 12 Laufzeitscreenshots.
- **Exportiertes PCK:** 2.069 Prüfungen / 0 Fehler ohne Quellprojekt; das native importierte Modell wird geladen.
- **Rampensprung:** Ein wirklicher Sprung und eine Landung; 36 Physikframes in der Luft, kein Gap-Sturz.
- **Kontakt:** Maximal etwa 1,14 mm Abstand zwischen Hand-Anker und Lenkrad-Anker im Produkttest; keine Garantie für Fingerkollisionen.
- **Bestandsregressionen:** Physik, Sprung, Host-/Save-/Reward-Pfad sowie Fahrzeuggeometrie erfolgreich.
- **Animation:** 21 Charakter-, 379 isolierte Kart- und 165 CPU-Prüfungen erfolgreich.
- **Geräteprüfung:** Linux/Godot 4.6.3, Mesa/llvmpipe; kein angeschlossenes physisches Android-/Samsung-Gerät.

Der Fahrzeugtest druckt keinen allgemeinen `PASS`-Marker, sondern die vollständige Zeile `Geometry/colours, shadows, animations, effects, LOD and hysteresis passed`. Ein erster Wrapper-Aufruf scheiterte nur am falsch gewählten Marker; der eigentliche Lauf war sauber. Die isolierte CI-Fixture wurde danach mit korrektem Marker und den neuen Abhängigkeiten erfolgreich geprüft.

Ebenso erzeugte der erste Export ein gültiges PCK, während der Prüf-Wrapper vergeblich einen `PASS`-Marker erwartete. Der neue Runner verwendet den tatsächlichen `savepack`-Marker. Das entstandene Paket bestand anschließend den vollständigen echten Produktszenentest.

## Echte Bild- und Videobelege

Gesichert sind Vorher/Nachher im gleichen Rennen, Lenken links/rechts, Pause, Chase-Kamera mit 1280 × 720 und 640 × 320, Rampensprung, Landung und Zieleinlauf. Das kurze Video besteht aus tatsächlich aufgenommenen Godot-Frames, nicht KI-generierten Bildern. 15 Videobilder pro Sekunde sind die gespeicherte Aufnahmerate, kein Android-FPS-Messwert.

## Offene Produktionsabnahme

- **Priorität 1:** Aktuelle PRs und Originalreferenzen lesen; das tatsächlich verantwortliche Kart-Menü und den Flutter-Einstieg bestimmen; echte Ausgangsbilder mit `50666.gif` vergleichen; Fold-Menü, Ladeübergang und animierten Menü-Lumo korrigieren.
- **Priorität 2:** Gesichtstauglichkeit separat prüfen. Das aktuelle Modell hat keine Gesichtsmorphs; keine neue Lippen-Synchronisation wird behauptet.
- **Priorität 3:** Sky-Raceway-Bauteile, Looping-Physik und echte Rundenzeit untersuchen. Die neue Renn-Animationsintegration ist kein Beleg für eine fahrbare 50-Sekunden-Strecke.
- **Priorität 4:** Danach Flutter-Lernmodule, neue Rechengrafiken, Profile und Datenbeständigkeit prüfen, ohne offene Schreibcoach- oder Sprachänderungen zurückzusetzen.
- **Priorität 5:** Abgestimmter Godot-Pin, neuer Test-APK-Build, Signatur-/Versionsprüfung und tatsächliche Android-Runtime-Abnahme. Noch keine neue APK erstellt.

## Fortsetzung nach Unterbrechung

Zuerst dieses Dokument und den aktuellen Git-Status lesen. Beide Repository- und PR-Köpfe erneut prüfen. Keine fremden uncommitteten Änderungen übernehmen oder verwerfen. Die nächste konkrete Arbeit ist die referenzbasierte Kart-Menü-Abnahme, nicht eine neue kostenpflichtige Assetgenerierung.
