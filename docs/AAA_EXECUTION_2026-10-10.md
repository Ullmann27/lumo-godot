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

## M2: Fold-/Stage2-Restfehler gezielt schließen

Der StartHero-Test klickte einen absichtlich ausgeblendeten Schnellstart und
leitete Kartenindizes aus einer anderen Katalogreihenfolge ab. Er folgt jetzt
dem einzigen goldenen Weiter-Knopf durch alle fünf echten Touch-Schritte;
Moduskarten werden über ihren sichtbaren Titel gewählt. Ein Startsignal ist
nur nach Schritt5 erlaubt. Gespeicherte Training-/Cup-Setups müssen Fahrer,
Kart, Strecke und Tempo unverändert weitergeben.

Zwei echte Layoutfehler wurden behoben:
- Beim normalen Wechsel Schritt0→1 blieb `page_margin` auf einer alten,
  überhöhten Containergröße. Ein Minimum-Size-Signal stellt die erreichbaren
  Safe-Area-Grenzen wieder her; der Guard vermeidet eine Resize-Schleife.
- Bei320×568 mit gespeichertem Rennen lag Weiter auf der Kartseite bei
  `(8,547,148,56)`, unterhalb des Bildschirms; das Seitenminimum war611px.
  Die bestehende44px-Kompaktregel gilt nun für alle Schritte, mit einzeiligem
  bestehendem LUMO-KART-Schriftzug und2px-Sternenpanel-Rändern. Nur die
  Einstiegsseite nutzt weiterhin den kleineren80px-Hero. Danach liegt Weiter
  bei `(8,516,112,44)` und die Seite bleibt320×568.

Echte Vorher-/Nachher-PNGs, unveränderte horizontale Vergleiche und
SHA256/Viewport-/Setup-Metadaten:
`docs/qa/visual/kart-aaa/2026-10-10/m2-layout/manifest.json`.
Die Bilder zeigen dieselben Produktionsmenüseiten bei1280×720 und320×568;
keine neuen Assets, keine Retusche, keine Geometrie-/Materialänderung.

Lokale fokussierte Prüfung: gespeichert320×568 mit71 Checks grün;
voller StartHero headless mit222 Checks grün; einmaliger echter GL-Lauf mit
225 Checks,35 realen Weiter-Touches, fünf Viewports und beiden gespeicherten
Journeys grün. Kein GDScript-/Engine-Fehler und keine RID-/Ressourcenmeldung
im GL-Log. Beide strikten Workflow-Zähler wurden69→225 angeglichen; die
StartHero-Zeitgrenze beträgt600s. Ein redundantes Screenshot-Warten entfällt,
Touch-Prüfungen und `run_godot_probe.py`-Fehlerablehnung bleiben unverändert.

Der übernommene Renderer-Profilfix liest den tatsächlichen RenderingServer
statt des Projektdefaults und setzt nicht unterstützte/vererbte SSAO-/SSR-/
SSIL-/SDFGI-Effekte beim LOW-/Mobilwechsel zurück. Zwölf Kombinationen plus
Full→LOW→Full sind grün und werden zusammen mit Stage-Lifetime in Stage2
abgesichert. Der veraltete Podium-Kommentar im Wangen-Capture ist korrigiert.

Die zwei Ogg-Ressourcen beim abrupten Capture-Prozessende sind ein
AudioServer-Abbau-Race, kein weiterer Produkt-RID-Leak. Die übernommenen
beiden Menü-Capture-Fixes geben das Spiel frei und warten anschließend sechs
Frames,0.25s und zwei Frames; die Fehlerprüfung wird nicht abgeschwächt.
Die abgeschlossene Auditdiagnose wird nicht erneut ausgeführt.

Abnahmegrenze: Funktionale Gates werden auf demselben Featurebranch-Commit
verifiziert; Main übernimmt Bildprüfung. Keine APK-/Flutter-/neue Art-Arbeit,
kein Main-Merge, Release oder Force-Push.
