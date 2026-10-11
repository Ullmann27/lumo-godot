# Lumo: Handkontakt, Ansichten und vorhandener Modellbestand

11. Oktober 2026. Aufbau auf Godot PR #56, `3d377f149c8193e245b9be0ddd977e70fc97d890`, Branch `computer/lumo-next-level-menu-2026-10-11`. Produktkorrektur und Prüfwerkzeuge: `b8bc4bd`, eigener Branch `astra/lumo-animation-quality-2026-10-11`. Lernsystem bleibt Priorität 1: [App PR #263](https://github.com/Ullmann27/lumo-lernen/pull/263).

## Konkrete Korrektur

Beim Nicken (`agree_nod`) folgt Lumos rechte Hand jetzt auch zwischen den auf 30 Hz begrenzten Animationsschritten dem Lenkrad. Bisher aktualisierte dieser Zwischenpfad während einer Geste nur die linke Hand. Der vollständige Animationsschritt behandelte Nicken bereits korrekt als Geste mit beiden Händen am Lenkrad. Beide Pfade verwenden nun dieselbe Bedingung.

Die neue Regression verwendet das echte Kart mit ausdrücklich aktiviertem animiertem GLB-Lumo, echte Skeletttransformationen und echte Lenkradanker. Sie prüft Zielankunft auf Platz 4 und die Menügeste bei Eingabeschritten von 60 und 120 Hz, jeweils mit wechselnder Lenkung. Die maximale gemessene Abweichung sank von **64,14 mm auf 1,15 mm**. Vorher schlagen vier Kontaktprüfungen fehl; nachher bestehen alle **200 Prüfungen**, einschließlich unveränderter Fahrzeugtransformation bei jedem Animationsschritt. Die Toleranz beträgt 6 mm.

Gemessen wird der Handgelenkanker. Das ist kein Nachweis für gekrümmte Finger um den Lenkradkranz oder für kollisionsfreie Hände. Mesh, Rig, neun Clips, Karosserie, Fahrphysik und Kollisionen wurden nicht verändert.

## Echte Godot-Aufnahmen

Desktop Godot 4.6.3, Compatibility-Renderer, Mesa-Softwaredarstellung auf Xvfb. Identische Testszene, Kamera, Licht und Eingaben vor/nach der Adapterkorrektur. Dies sind Aufnahmen des tatsächlichen importierten Modells, keine generierten Entwürfe, keine Android-/Fold-Aufnahmen.

| Situation | Vorher | Nachher |
|---|---|---|
| Nicken nach Zielankunft, 60-Hz-Schritte | [Bild](before/gesture/finish-nod-60.png) | [Bild](after/gesture/finish-nod-60.png) |
| Menü-Nicken, 60-Hz-Schritte | [Bild](before/gesture/menu-nod-60.png) | [Bild](after/gesture/menu-nod-60.png) |
| Nicken nach Zielankunft, 120-Hz-Schritte | [Bild](before/gesture/finish-nod-120.png) | [Bild](after/gesture/finish-nod-120.png) |
| Menü-Nicken, 120-Hz-Schritte | [Bild](before/gesture/menu-nod-120.png) | [Bild](after/gesture/menu-nod-120.png) |
| Bewegungsfolge | [Video](before/gesture/nod-steering.mp4) | [Video](after/gesture/nod-steering.mp4) |

Die Lenkvideos enthalten je 48 deterministisch fortgeschaltete Godot-Frames, exportiert mit 60 Bildern pro Sekunde. Die Wiedergaberate ist keine gemessene Laufzeit-Bildrate.

| Ansicht | Bestehender Lumo, stehend | Bestehendes Kart mit Lumo |
|---|---|---|
| Vorne | [Bild](after/character/view-front.png) | [Bild](after/gesture/kart-front.png) |
| Seite | [Bild](after/character/view-side.png) | [Bild](after/gesture/kart-side.png) |
| Hinten | [Bild](after/character/view-back.png) | [Bild](after/gesture/kart-back.png) |
| Dreiviertel | [Bild](after/character/view-three-quarter.png) | [Bild](after/gesture/kart-three-quarter.png) |

[Idle, Winken und Jubel in Bewegung](after/character/idle-wave-celebrate.mp4), aus echten Godot-Frames mit 12 Hz exportiert. Die neun vorhandenen Clips sind einzeln unter `after/character/` abgebildet. Diese Bestandsaufnahmen zeigen den unveränderten Modellzustand; sie sind kein Vorher-/Nachher-Beleg für eine neue Modellierung.

## Modell-, Rig- und Integrationsstatus

| Figur | Befund im aktuellen Repository |
|---|---|
| Lumo | Laufzeitfähiger GLB, 30.000 Dreiecke, 21.659 exportierte Vertices, 65 Bones, neun Clips, drei 1024er Texturen, maximal vier Gewichte pro Vertex. Blender-Audit: keine ungewichteten Vertices und keine fehlerhaften Gewichtssummen. |
| Löwe | Originalreferenz vorhanden; katalogisierter `driver.glb` fehlt; `runtimeReady: false`. Kein importiertes Rig prüfbar. |
| Eule | Originalreferenz vorhanden; katalogisierter `driver.glb` fehlt; `runtimeReady: false`. Kein importiertes Rig prüfbar. |
| Nova / Hase | Originalreferenz vorhanden; katalogisierter `driver.glb` fehlt; `runtimeReady: false`. Kein importiertes Rig prüfbar. |
| Eichhörnchen | Originalreferenz vorhanden; katalogisierter `driver.glb` fehlt; `runtimeReady: false`. Kein importiertes Rig prüfbar. |
| Schildkröte | Originalreferenz vorhanden; katalogisierter `driver.glb` fehlt; `runtimeReady: false`. Kein importiertes Rig prüfbar. |

Die bisherigen prozeduralen Gegner bleiben funktionsfähig; sie ersetzen nicht die fünf angefragten neuen Modelle. Vollständiger Bestand: [rivals-audit.json](rivals-audit.json), [GLB-Audit](model-audit.json), [Blender-Audit](blender-rig-audit.json).

Meshy wurde mit dem vorhandenen CLI-Zugang geprüft: `authenticated: false`, keine gespeicherten Profile. Der entfernte Modellbestand war damit nicht lesbar. Kein neuer Modellierungsauftrag, keine neue Anmeldung und kein Verbrauch von Generierungsguthaben. Lokale Originalquellen bleiben erhalten:

- `assets/characters/lumo/reference/`
- `assets/characters/lumo_animated/Lumo-Animated-Mobile.glb`
- `docs/design/2026-10-10-animation/editable/Lumo-Animated-Mobile.blend`
- `docs/design/2026-10-10-animation/source/Lumo-Meshy-Smart-Rig-Original.glb`
- `docs/design/2026-10-10-rivals/` und `assets/characters/rivals/reference/`
- CC-BY-4.0-Attribution unter `assets/characters/lumo_animated/ATTRIBUTION.md`

Verbindlicher Fahrzeug-/Rennfigurenvergleich: `docs/design_targets/2026-10-08-kart-fahrzeuge/`, insbesondere die Ganzkörpervorlage im Rennanzug. Die Menü-/Garagenreferenzen unter `docs/design/2026-10-10-lumo-games/references/` liegen im **App-Repository lumo-lernen**.

## Ausgeführte Prüfungen und Messgrenzen

- Neue Kontaktregression: vorher vier Fehler, nachher 200 Checks bestanden. Strikter Headless-Lauf und echte gerenderte Aufnahme. In den bestehenden Kart-Workflow aufgenommen.
- Vorhandene Produktintegration: echte Kart-Factory, Physik, Sprung, Race-Bridge, Fahrzeug, Export und Lauf aus exportiertem PCK bestanden. Der Export wurde nach Code-Commit `b8bc4bd` erneut erstellt; der gepackte Produktlauf besteht **2.069 Checks**. Hash und Protokolle in `EVIDENCE.json` / `logs/committed-export/`.
- Rig-Aufnahmen: **121 Checks** einschließlich neun Clips, vier Ansichten und Videoframes. Nach abschließender Formatkorrektur zusätzlicher Headless-Lauf: 21 Checks bestanden.
- Gegnerkatalog: 103 Checks bestanden. Projektvalidator: 117 PASS, sieben bestehende WARN, kein FAIL. GDScript-Lint der drei bearbeiteten Dateien bestanden. Die zwei vorhandenen Dateien haben bereits auf dem Basisstand Formatabweichungen; das neue Testskript besteht den Formatcheck.
- Unabhängiger lesender Agentenreview: keine wesentlichen Codebefunde; die Nicken-Bedingung stimmt mit dem bestehenden vollständigen Animationspfad überein. Keine zusätzlichen Testläufe durch den Reviewer.
- CPU der neuen Nicken-Regressionsfälle: Mittel **0,062–0,091 ms**, p95 **0,125–0,145 ms** pro manuell ausgeführtem Kart-Prozessschritt, 48 Messungen je Fall; Renderwartezeiten ausgeschlossen. Rohdaten: [gesture-cpu.json](after/gesture-cpu.json).
- Bestehender CPU-Benchmark: Adapter/IK vorher Mittel 0,0628 ms, p95 0,078 ms; nachher Mittel 0,0659 ms, p95 0,083 ms. Ein paralleler Host-Last-Ausreißer im Sechs-Figuren-Test ist in den Rohdaten erhalten. Keine belastbare Beschleunigungsaussage aus diesen kurzen Läufen. [Vorher](before/cpu.json), [nachher](after/cpu.json).

Alle CPU-Zahlen gelten für den gemeinsamen Linux-Rechner. GPU-Zeit, thermisches Verhalten, Android-/Fold-FPS und die vollständige Flutter-/Godot-App sind damit nicht gemessen. Keine neue APK; App-Pin und Sols Backend-/Sulafat-Integration bleiben unberührt.

Reproduktion aus dem Repository (Godot 4.6.3):

```sh
python3 tools/run_godot_probe.py --log /tmp/lumo-gesture.log --timeout 90 --required '[LumoGestureContact] PASS' -- godot --headless --audio-driver Dummy --path . --script res://scripts/tests/lumo_gesture_contact_regression.gd -- /tmp/lumo-gesture
GODOT_BIN=godot bash tools/lumo_animation/run_kart_integration.sh /tmp/lumo-integration
# Mit verfügbarem Display, echte Aufnahmen:
godot --rendering-method gl_compatibility --audio-driver Dummy --path . --script res://scripts/tests/lumo_gesture_contact_regression.gd -- /tmp/lumo-gesture-images --video
godot --rendering-method gl_compatibility --audio-driver Dummy --path . --script res://scripts/tests/lumo_rigged_animation_capture.gd -- /tmp/lumo-character-images --video
```

## Sichtbar offene Qualitätsarbeit

1. **Schweif im Kart:** Seiten-/Rückansicht zeigen Überschneidungen mit Cockpit/Heck. Die Rennvorlage hat einen freieren, höheren Schweif. Nächster Schritt ist eine sitzspezifische Schweifpose mit Prüfung über alle Fahrzeugvarianten und Lenk-/Sprung-/Jubelzustände; der Handkontaktfix löst dies nicht.
2. **Finger und Sitzhaltung:** Handgelenkanker sind stabil; Finger umfassen den Kranz noch nicht vollständig. Den Griff mit den vorhandenen Fingerbones und die tatsächliche Sitz-/Beinfreiheit gesondert prüfen.
3. **Gesicht:** Augenlider, Gesichtsmorphs und echte Lippensynchronisation fehlen. Der vorhandene Sprachpegelanschluss transportiert Zustandswerte und behauptet ausdrücklich keine Mundanimation. Wangen, Ohren, Brille und Fellübergänge bleiben im bestehenden Asset erhalten; keine neue Gesichtsmodellierung in dieser Etappe.
4. **Karosserie:** Die aktuelle Form ist runder/einfacher als die kantigere Fahrzeugvorlage. Haube, Heck, Rad-/Sitzproportionen und Materialien benötigen eine eigene überprüfbare Modell-/Beleuchtungsetappe. Fahrphysik und Kollisionen müssen dabei getrennt geprüft bleiben.
5. **Neue Gegner:** Modell-/Rig-Import aus vorhandenen freigegebenen Quellen ist Voraussetzung. Der nicht verfügbare Meshy-Zugang erlaubt derzeit keinen verifizierten entfernten Bestandsabgleich.
