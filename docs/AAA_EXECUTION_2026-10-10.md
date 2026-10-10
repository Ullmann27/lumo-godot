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
| Blender | noch nicht installiert, offizielles Ubuntu-Paket verfügbar | offene Alternative statt bezahlter Lizenzen; nicht als bereits benutztes Tool behauptet |
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
