# Lumo Kart: tatsächlicher Menü-Ist/Soll-Vergleich

Stand: 11. Oktober 2026. Vor Eingriffen wurden beide Repository-Stände und die relevanten offenen Pull Requests geprüft. Die aktuelle originale Referenz `50666.gif` und die anschließend ausdrücklich bestätigte `50665.jpg` gehen für die Moduswahl vor dem älteren sechsfachen Kart-Konzept; die dort gezeigten Lern-Boost-Funktionen werden ausdrücklich nicht umgesetzt.

## Quellen und Ausgangsstand

Die Originaldokumente `DESIGN_ZIEL_2026-10-04.md`, `DESIGN_ZIEL_KART_2026-10-04.md`, `DESIGN_ASSETS_2026-10-04.md` und `DESIGN_BESTANDSSCHUTZ.md` wurden im vorhandenen Flutter-Checkout gelesen. `50666.gif`, `50294.png` und `k09_modus_waehlen.png` wurden als echte Originalbilder geöffnet.

Der Ausgangscommit dieser Menüetappe ist `b840e7e`, die bereits echte Renn-Animationsintegration aus [PR #52](https://github.com/Ullmann27/lumo-godot/pull/52). Der neue eigene Branch heißt `computer/lumo-kart-production-menu-2026-10-10`.

## Tatsächlicher Besitzer des sichtbaren Einstiegs

Flutter `games_content.dart` startet über `launchLumo3D(scene: kart)` die bestehende Android-Integration. Flutter zeigt den Start-/Speicherstatus, aber keine zweite native Kart-Moduswahl. In Godot erzeugt `kart_island.gd` die tatsächliche Oberfläche `kart_garage_menu.gd`. Dieser native Bildschirm wird verbessert; es wird kein zusätzlicher konkurrierender Menüweg gebaut.

## Abweichungen vor der Änderung

| Bereich | Originalreferenz | Tatsächliche Laufzeit / Code | Eingriff |
|---|---|---|---|
| Grundaufbau | Fünf links angeordnete Karten, echter Lumo im Kart rechts, eine goldene Weiter-Aktion | Aufbau bereits grundsätzlich vorhanden; keine zweite Hauptaktion sichtbar | Funktionierenden Aufbau erhalten |
| Figur | Lebendiger, originalgetreuer Lumo | Menü nutzt noch den alten prozeduralen Fahrer, nicht das vorhandene Rig aus PR #51 | Bestehende Renn-Animationsverbindung auch in der realen Menü-Fabrik nutzen |
| Kompakte Karten | Klar lesbare und sinnvoll bedienbare Auswahl | Teilweise 28px Mindesthöhe und 12px Titel | Echte dp-Skalierung und mindestens 48dp Touchflächen; nötigenfalls korrektes Scrollen statt Verkleinerung |
| Fold-Dichte | Große, gut lesbare Bedienung auf dem tatsächlichen Gerät | Größen wurden in Rohpixeln statt Android-dp berechnet | Dichte aus Godot/Android bzw. expliziten Host-Metriken verwenden |
| Hintergrund | Tiefe blaue Schloss-/Inselwelt mit Wasserfällen | Das bereits vorhandene hochwertige Bild ist sichtbar | Originalmotiv nicht neu erzeugen oder ersetzen |
| Materialwirkung | Zurückhaltendes dunkles Glas mit Cyan/Gold | Große Figur, Ringe und Farbflächen sind vorhanden; Quellfigur weicht noch in Detailform und Finish ab | Keine unbelegte Pixelgleichheit behaupten; vorhandenen Lumo verwenden |
| Logo | Korrektes Lumo-Kart-Branding | Textlogo korrekt geschrieben, aber visuell nicht identisch mit allen Originalen | Gesondert prüfen; keine erfundene neue Marke |
| Ladepfad | Reale Vorbereitung, verständliche Fehlerbehandlung, kurzer animierter Übergang | Vorhandener Boot-Cover zeigt unbestimmten Status und wechselt nach einem Frame in synchrones Laden | Nach der Menü-/Rig-Stabilisierung echten Ladezustand und Fehlerpfad verbessern |

Die ersten echten Ausgangsscreenshots entstanden mit 1280 × 720, 640 × 360 und 1200 × 896. Das ursprüngliche AAA-Capture verwendete 48 Test-Sterne und Seed 1923; die erste neue Fold-Fixture zeigte 0 Test-Sterne. Die finale Fixture verwendet wieder 48 Test-Sterne und Seed 1923. Keine dieser Wallet-Anzeigen ist tatsächlicher Kinderfortschritt; aus dem Vorher/Nachher-Vergleich wird kein verdienter Lernfortschritt abgeleitet.

## PR-Abhängigkeiten und Risiken

[Godot PR #45](https://github.com/Ullmann27/lumo-godot/pull/45) war zum Auditzeitpunkt gegenüber seinem aktuellen Basisbranch konfliktbehaftet. Die Menükorrektur wird deshalb nicht blind auf einen alten Stand zurückgesetzt. [PR #47](https://github.com/Ullmann27/lumo-godot/pull/47) und [PR #49](https://github.com/Ullmann27/lumo-godot/pull/49) hatten erfolgreiche Stage-2-Prüfungen; ältere #44 und #46 sowie der Rivalen-Vorbereitungsstand #50 hatten nicht durchgängig grüne Prüfungen.

Die relevanten Flutter-PRs #246, #248, #253, #255, #256 und #257 wurden nach geänderten Dateien und verfügbaren CI-Prüfungen geprüft. Sie sind offene, gestapelte Arbeiten, keine Behauptung über eine bereits installierte Integration. Der zuletzt geprüfte lokale Flutter-Godot-Pin ist weiterhin `e37674692c047c41a6fb1485e499be1ed0c0f758`.

Das vorhandene Rig besitzt 65 Knochen und neun Clips; das GLB wurde unverändert wiederverwendet und technisch erneut geprüft. Gesichts-Morphs fehlen. Das neue Menü behauptet deshalb keine echte Lippen-Synchronisation und keine automatisch ergänzte Gesichtsanimation.

## Umgesetzte Detailkorrektur nach `50665.jpg`

Der bisherige einfache Schriftzug wurde durch eine native, skalierbare zweizeilige Wortmarke mit Gold/Cyan, Stern im o, beiden Zielflaggen und dem vorhandenen Motto ersetzt. Sie ist eine Nachbildung mit der vorhandenen Projekt-Schrift, kein behaupteter pixelidentischer Original-Logoexport. Das separat vorhandene weiße, waagerechte Flutter-Logo passt nicht zur zuletzt bestätigten zweizeiligen Referenz und wurde deshalb nicht als Ersatz eingebaut.

Die fünf Buttons behalten ihre richtigen Spielaktionen. Doppelte dunkle Symbolrahmen wurden aus den vorhandenen SVG-Symbolen entfernt; die eigentlichen Motive bleiben unverändert. Eine leichte gerundete Lichtkante, passend getönte Glasflächen und genau ein Auswahlhaken ersetzen die vorher flachen großen Farbblöcke. Die Weiter-Aktion bleibt die einzige goldene Hauptaktion.

Die Figur in der Menü-Fabrik verwendet jetzt ausdrücklich dasselbe vorhandene animierte Modell wie das echte Rennen. Die Begrüßung und der Auswahl-Nick laufen über den bestehenden Adapter, mit Sitzpose und Lenkrad-Kontakt, statt eine zweite Figur oder einen neuen Timer-Animationsweg zu bauen.

## Prüfbare Ergebnisse und verbleibende Abweichungen

- **Layout:** Neun Dichte-/Safe-Area-Konfigurationen, 336 Prüfungen, 0 Fehler. Alle geprüften Modus-/Hauptaktionen mindestens 48 dp; alle fünf Modi auf den geprüften großen Quer-/Fold-Layouts gleichzeitig sichtbar. Kleine Cover-Displays scrollen echte Buttons.
- **Navigation:** Bestehender StartHero-Test 222 Prüfungen / 0 Fehler. Echte Godot-GL-Touch-Gesamtprüfung mit Android-Rändern bei 1280 × 720, 800 × 480 und 640 × 320 erfolgreich.
- **Animation:** Echter finaler GL-Lauf 75 Prüfungen / 0 Fehler, Fold-Screenshot plus 28 tatsächliche Winke-Frames; anschließend wieder Sitzpose. Keine KI-generierte Laufzeitaufnahme.
- **Produktgrenzen:** Kein physisches Samsung-Gerät angeschlossen, kein neuer APK-Build, keine vollständige Android-Performance-Abnahme.
- **Noch nicht referenzgleich:** Die Form/Materialwirkung des vorhandenen geriggten Lumo und Karts unterscheiden sich weiterhin vom illustrierten Original. Die Körpergeometrie und die Originaltexturen wurden in dieser UI-Etappe nicht verändert; ein rig-sicherer Art-Pass bleibt getrennt von funktionierender Menü-/Touch-Integration.
- **Noch offen:** Echtes asynchrones Laden samt Fehler-/Retry-Zustand und Übergang; vollständige Sky-Raceway-/Looping-/Rundenzeitphase; Flutter-Gesamtabnahme; neuer abgestimmter APK-Pin.

Für eine optionale Astra-Übergabe sind die Grenzen klar: Im Hochmodus nur der gezielte Referenzvergleich von Logo, Kartenlichtkante und Bildkomposition; im Sehr-Hochmodus nur komplexere rig-erhaltende Körper-/Kartmaterial- und Beleuchtungsarbeit. Keine zweite Figur, kein Austausch der Stimme, keine bezahlte Neugenerierung. Die technischen Menü-, Touch- und Ladefehler benötigen derzeit keinen Modellwechsel.
