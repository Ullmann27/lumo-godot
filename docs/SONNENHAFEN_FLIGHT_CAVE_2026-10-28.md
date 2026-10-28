# Sonnenhafen – Integration und Sol-Übergabe (28.10.2026)

## Ausgangspunkt
Lumo Lernen 0.12.87+1999 verwendet nachgewiesen Godot 4.6.3 Commit `4d0fd40fdf188be6ca86057596c7b51f41701fa3`.
Dieser Zweig ist **kein Release** und wurde nicht in eine neue APK integriert. Die Version 1999 bleibt unverändert.

## Maßnahme A – echte Panorama-Schanze
Quellen: `scripts/games/kart_action_course.gd`, `kart_island.gd`, `kart_action_course_regression.gd`, neue gezielte OpenGL-QA.

- Ein neuer Sonnenhafen-Kicker bei 55 % der Rundendistanz; 12 m Rampenlänge, 2,2 m Rampenhöhe.
- Nur dieser Kicker bekommt einen längeren, geschwindigkeitsabhängigen ballistischen Flug mit 14 m/s² Schwerkraft. Alle anderen Kicker und die Himmelsinseln-Lücke behalten 30 m/s² und ihren bisherigen Impuls.
- Drei Cyan-Landeleitmarken, abseits der Fahrspur. Die bestehende Landung, der bestehende Turbo, Rennen, Checkpoints, Profil und Savegame bleiben unverändert.
- **Gemessen im echten Godot 4.6.3/Software-OpenGL-Lauf:** 27,6 m Flugweite, 4,4 m Spitzenhöhe über Fahrbahn, 1,33 s Luftzeit, kein Reset. Testergebnis `[KartSonnenhafenFlight]` und vollständiger `[KartActionCourse] PASS`, Workflow https://github.com/Ullmann27/lumo-godot/actions/runs/40720584632 .
- Zusätzlich sind drei echte 1280×720-Screenshots aus Anfahrt, Flug und Landung über `kart_sonnenhafen_hero_flight_capture.gd` und den gesonderten OpenGL-Workflow vorgesehen. Sie gelten erst nach erfolgreichem Lauf als geliefert.

## Maßnahme B – Kristallhöhlen-Wasser und Fantasy-Lava
Quellen: `kart_sonnenhafen_darkride.gd`, `kart_sonnenhafen_darkride.gdshader` und Dunkelfahrt-Regression.

- Tatsächliche, an die Streckengeometrie angepasste seitliche Meshkanäle bei mindestens 5,85 m Querabstand: Wasser links, warmes Fantasy-Lavaorange rechts.
- Ein zusätzliches Mesh mit genau einer Oberfläche, gemeinsam mit dem Straßen-Shader-Material. Animation über den bestehenden, pausierbaren `animation_time`-Takt, ohne unabhängiges `TIME`, neue Lichter oder CollisionBodies.
- Low-/High-LOD mit rund 5 m/2,5 m Längssampling.
- **Godot-Dunkelfahrt-CI inklusive echter Szenenbilder und Mobilvarianten erfolgreich:** https://github.com/Ullmann27/lumo-godot/actions/runs/40720234131 .
- Die Farbkanäle sind vorerst Fantasy-Effekte **neben** der sicheren Fahrbahn, keine gefährliche Lava-Spielmechanik.

## Maßnahme C – Flutter-Nachhilfe, separates Repository
Im Flutter-Repository `Ullmann27/lumo-lernen`, PR https://github.com/Ullmann27/lumo-lernen/pull/410:
- drei didaktisch unterschiedliche Offline-Hilfen für zweistellige Zehner/Einer-Fragen (Bündel, Zerlegung, Zehnerstangen + Transfer);
- eindeutige Abgrenzung für dreistellige Stellenwerte und unveränderte Testmodus-Sperre;
- fünf neue Flutter-Tests. Die zusammenhängende Gesamtprüfung muss je aktuellem PR-HEAD berücksichtigt werden.
Nicht in Android-Build 1999.

## Integrationsreihenfolge für Sol
1. Alle PRs als getrennte Diff-Pakete lesen: Sonnenhafen-Flug #115, Wasser/Lava #116, Tutor #410. Keine ältere `main`-Basis blind übernehmen.
2. **Diesen** kombinierten Godot-Branch vollständig prüfen. Besonders: `kart_courses_driving_regression`, `kart_action_course_regression`, `kart_sonnenhafen_darkride_regression`, UI/Save-Resume/Fold und echte Szenenscreenshots.
3. Nur nach erfolgreicher Prüfung diesen Godot-HEAD in einem neuen Flutter-2000-Arbeitszweig über `config/godot-source.json` pinnen. Zusätzlich Tutor-Diff aus Flutter-PR #410 integrieren, ohne die Version 1999 zu überschreiben.
4. Flutter-Tests, Godot-Android-Integration, Signaturgleichheit und **echtes Update von 1999 auf den neuen Build mit unveränderten Kinderprofilen** prüfen.
5. Anschließend neue signierte ARM64-**Haupt-App** als öffentliche direkte Chrome-HTTPS-`.apk` veröffentlichen. Keine ZIP/Demo/alte APK als Fortschritt ausgeben.
6. Nachweis mit Godot-Commit, Flutter-Commit, Versionscode, APK-SHA256, Testlogs und echten Bildern.

## Offene Arbeiten
- Hochwertige Felsnormalmaps, komplexe Wasserspritzer und transparente Lava-Physik sind noch **nicht** implementiert.
- Noch keine überprüfte Faltgerät-60-FPS-Messung, keine finale neue APK; 1999 bleibt der installierbare Referenzstand.
- Ein echter lernprofilbasierter Tagesplan mit aktiver Lernstandsdiagnose ist **separat** umzusetzen; vorhandene Missionen nicht überschreiben.
