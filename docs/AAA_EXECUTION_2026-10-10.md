# Lumo Kart: nachprüfbare AAA-Weiterentwicklung

## Unveränderte Basis

Godot `ff67107caf35a8a533a61c348168fbe3949d67a9` (PR46 auf PR45),
Flutter `8b308aeec8a6858b93a5b4626c4dd136d1e17ced` (Build1922).
Arbeitszweig: `computer/lumo-kart-aaa-2026-10-10`.
Kein Main-Merge oder Release. Originalreferenzen bleiben verbindlich.

## Werkzeugbestand

| Werkzeug | Tatsächlich geprüft | Einsatz / Grenze |
| --- | --- | --- |
| Godot | 4.6.3 stable, Linux CLI | Import und echte X11/GL-Aufnahmen |
| Flutter / Dart | 3.44.9 / 3.12.2 | Bestehende Lern-App, Widget-Regressionen |
| Android SDK / ADB | ADB 37.0.1, Buildtools36 | Paketprüfung, CI-Gerätetests |
| Xvfb / Mesa | reale GL-Ausführung erfolgreich | Software-Rendering, kein physischer Geräte-FPS-Nachweis |
| ffmpeg | 8.0.1 | ausschließlich echte Aufnahmen / Schnitt |
| Blender | 5.0.1, offizielles Ubuntu-Paket; Background-CLI-Test erfolgreich | offene Werkzeugkette statt bezahlter Lizenzen |
| GitHub | Lesen/Push/Actions verfügbar | separate Branches, keine Secrets ändern |
| Claude Opus 5.5 | realer read-only Teilagent gestartet | Renderer-Lifetime-Gegenprüfung |
| Claude Sonnet 5.5 | realer read-only Teilagent gestartet | vorhandenen Android-/Gameplay-QA-Pfad prüfen |

Lokales `/dev/kvm` und GPU-Gerät fehlen. API35/36-Installation muss daher
auf geeignetem bestehendem CI-Runner erfolgen. Kein erfundener Creditbetrag,
keine Käufe, keine fremden bezahlten 3D-Dienste. Godot/Blender werden als
freie Werkzeuge verwendet; projektspezifische Assetrechte bleiben separat
zu dokumentieren.

## Erste echte Menü-Baseline

Unveränderter `kart_premium_menu_capture.gd`, echtes Godot 4.6.3
Compatibility-Rendering unter Xvfb. Kontrollierter Teststand: Modus race,
Schritt0, 48 Teststerne. Keine echten Nutzerdaten. Kamera/Assets wie im
bestehenden Capture-Harness; die zeitbasierte Idle-Bewegung ist noch nicht
für pixelgenaue Vergleiche eingefroren.

Dateien: `docs/qa/visual/kart-aaa/2026-10-10/ff67107-before/`.
Auflösungen 1280×720, 640×360, 1200×896. Alle fünf Moduskarten sind
im Querformat erreichbar. Das bestehende Harness meldet funktionales PASS,
aber der Prozess hinterlässt ein Renderer-Instance-RID und Ressourcen:
keine saubere Gesamtfreigabe.

Sichtbare Befunde:

- Kompakt: Lumo/Kart zu klein, Header verbraucht zu viel Höhe,
  Weiter steht nicht rechts unten.
- Groß: Originalwelt und echte 3D-Figur vorhanden, Figur/Materialien
  weichen weiterhin deutlich vom Referenzbild ab.
- Keine Umgestaltung des Originalgesichts ohne getrennten
  Vorher-/Nachher-Review.

## Abnahmezustand

VISUAL_GAP / IN_ARBEIT. Keine finale APK- oder Referenztreue-Freigabe.
Jeder sichtbare Patch erhält einzelne echte Vorher-/Nachher-Bilder und
zusätzlich einen Vergleich, mit direkten GitHub-URLs im Chat.

## M1: kompakte Vorschau und Renderer-Lifetime

Die Bühne erzeugte selbst bei `with_podium=false` ein unparented
`MeshInstance3D`. Jedes ausgelassene Podest hinterließ genau einen
RendererSceneCull-RID. Hauptagent und unabhängiger Claude-Opus-5.5-Audit
bestätigten die Ursache getrennt; der Fehler entstand nicht durch den
Neonbogen-Adapter oder zu kurze Wartezeit.

Minimaler Produktfix in `kart_stage.gd`: das optionale Podest nur bei
tatsächlichem Bedarf anlegen. Der bekannte manuelle Workaround im
Wangen-Capture prüft nun `null`, statt eine nicht mehr angelegte Instanz
freizugeben. Regression `kart_aaa_stage_lifetime.gd`: vorher 2 FAIL,
nachher 0 FAIL in vier Lebenszyklen. Vorhandener Studio-Lichttest PASS.

Kompaktes Menü:
- gleiche bestehende 3D-Geometrie und Materialien, keine neue Lumo-Identität;
- Welcome-Kamera näher wie in der vorhandenen großen Vorschau, FOV 34°
  statt43° im kompakten Modus;
- Weiter am rechten Rand mit elastischem Zwischenraum statt links neben Zurück;
- echte Sterne sichtbar, doppelter Lernshortcut auf der kurzen Einstiegsseite
  ausgeblendet, bestehender Rückweg über Spieleauswahl bleibt.

Reproduzierbares Capture `kart_aaa_menu_capture.gd`: Seed1923, 48 Teststerne,
Schritt0/Race, stehender Kart, Pose -0.25, reduzierte Bewegung, 1280×720,
640×360, 1200×896. Vorher und Nachher benutzen denselben Harness und
unveränderte Geometrie. Die absichtlich korrigierte Kameraposition/FOV
ist je Aufnahme in `capture.json` dokumentiert.

Nachher-Capture: alle fünf Modi sichtbar, nur ein Weiter, kein RID-Leak.
Es bleiben aktuell eine ObjectDB-Warnung und zwei Ressourcen beim
Prozessende des neuen Capture-Harness; Ursache wird separat untersucht.
Keine Gesamtfreigabe aus dem Screenshot-Test allein.

Sichtbare Restabweichungen: Gesicht und Karosserie sind noch nicht
referenzidentisch, die Kopfzeile nimmt im kurzen Format zu viel Raum ein,
echte Reflexionen/Materialtiefe fehlen gegenüber der Illustration.
Der erste Patch ist eine überprüfbare Verbesserung, keine AAA-Abnahme.
