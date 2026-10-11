# Lumo Kart: tatsächlicher Ladepfad und sichere Menüübergabe

Stand: 11. Oktober 2026. Eigener Branch `computer/lumo-kart-real-loading-2026-10-11`, Ausgangscommit `2eab464b0bec37163424965bc5fc309b1a434ced` aus [PR #53](https://github.com/Ullmann27/lumo-godot/pull/53). Kein Merge nach `main`, kein neuer Charakter, keine bezahlte Generierung und keine neue APK in dieser Etappe.

## Umsetzung und Navigation

Der bestehende Weg bleibt Start → Spielen → Lumo Kart. Flutter startet den bisherigen nativen Godot-Host; `scenes/app/boot.tscn` bleibt der Einstieg, das tatsächliche Menü entsteht weiter in `kart_island.gd` und `kart_garage_menu.gd`.

- **`scripts/app/app_boot.gd`:** Asynchrones Laden der tatsächlichen Produktszene und des importierten GLB, gemessener Engine-Ressourcenfortschritt ohne Prozentversprechen, gleicher Schriftzug und gleicher 65-Knochen-Lumo im Kart. Kein simulierter Countdown und keine künstliche Mindestwartezeit.
- **`scripts/app/scene_router.gd`:** Prüft geladene `PackedScene`-Identität und verhindert gleichzeitige Übergaben. Die ursprüngliche Weltgrafik überbrückt den echten Zwischenframe ohne aktive Szene. Der Router meldet den Wechsel erst nach `SceneTree.scene_changed`.
- **`scripts/games/kart_island.gd`:** Ein bereits vorbereiteter Einstieg spielt nicht erneut das lange Intro ab. Eine ausdrücklich erzwungene Intro-Fixture funktioniert weiter.
- **Fehlerbehandlung:** Bounded Timeout von 30 Sekunden, verständlicher Fehler, Retry und Rückkehr zur Spielewelt. Bestehende Host-Speicher-/Rückgabeprüfung bleibt zuständig; keine Save- oder Reward-Schemaänderung.
- **Performancegrenze:** Native Modelle werden aus den tatsächlichen ResourceLoader-Ergebnissen verwendet. Ruhemodus stoppt die Begrüßung und Kamerabewegung; niedrige Qualität deaktiviert Preview-MSAA und den Key-Schatten. Android-Leistung ist noch nicht gemessen.

## Testbelege

`test-results/` enthält die tatsächlich erzeugten JSON-Berichte: Headless 83/0, GL 84/0 und exportiertes PCK 94/0. Vier Oberflächen einschließlich Fold-Dichte 2,25 werden mit echten importierten Assets geprüft. Keine Orphan-Nodes nach der Szene. Die Zahl hängt von echten asynchronen Polls ab und ist kein plattformübergreifend fixer Erwartungswert.

`kart_loading_regression.gd` prüft Ressourcenfortschritt, native Szenen-/Modellidentität, 65 Knochen, echte Reifensilhouette in Portrait/Fold, Fehlerzustand, kontrollierten Testuhr-Timeout, Retry, Ruhemodus und tatsächliche Navigation ins Menü. Die Timeout-Fixture wartet nicht 30 Sekunden, sondern versetzt die Startuhr kontrolliert in die Vergangenheit.

`kart_loading_runtime_capture.gd` zeichnet den normalen Ablauf ohne angehaltenen Bereit-Zustand auf. Die 48 tatsächlichen Frame-Zeitstempel und die tatsächlichen Ladezustandsereignisse stehen in `test-results/runtime-capture.json`. Ein daraus gekürztes Video verwendet die gemessenen Zeitabstände, keine erfundene Aufnahmerate. Der langsame Desktop-Software-Renderer mit synchronen PNG-Lesevorgängen belegt weder Samsung-FPS noch Samsung-Ladezeit.

`kart_loading_before_capture.gd` ruft die beiden unveränderten ursprünglichen visuellen Methoden aus einem mit `git show` extrahierten Controller auf. Die alte normale Navigation wird nicht ausgeführt: Sie verlässt den Boot bereits nach einem Frame und ist für einen stabilen post-draw-Vergleich nicht zuverlässig aufnehmbar. Das Vorherbild ist deshalb ausdrücklich eine angehaltene historische Godot-Testansicht, keine Aufnahme des alten Starttimings. Es ist keine generierte Konzeptgrafik.

## Reproduzieren

```sh
Godot_v4.6.3-stable_linux.x86_64 --headless --audio-driver Dummy --path . \
  --script res://scripts/tests/kart_loading_regression.gd -- /tmp/lumo-loading-check

Godot_v4.6.3-stable_linux.x86_64 --rendering-method gl_compatibility \
  --audio-driver Dummy --path . \
  --script res://scripts/tests/kart_loading_runtime_capture.gd \
  -- /tmp/lumo-loading-movie --scene=kart
```

Ein PCK-Lauf verwendet denselben Test als externes Skript mit `--main-pack`, ohne Quellprojekt. Die CI-Schritte verwenden den bestehenden strikten Probe-Runner und dieselbe zuvor exportierte PCK-Datei.

## Noch offen

Eigene GitHub-Abnahme dieser Ladeetappe, kompatibler neuer Flutter/Godot-Pin, neue eindeutig versionierte Test-APK, Signatur- und Updateprüfung sowie echte Android-Runtime-Abnahme. Hier ist kein physisches Samsung Galaxy Z Fold angeschlossen. Das vorhandene Modell hat keine nachgewiesenen Gesichtsmorphs; keine echte Lippensynchronisation wird behauptet. Looping und 50-Sekunden-Zielrunde gehören zur späteren Streckenphase.

## Exportnachtrag: native Modelltexturen

Der ursprüngliche Ladecommit `b7c4114` ist in [Stage 2](https://github.com/Ullmann27/lumo-godot/actions/runs/38092021550), Rivalenfeedback und Video Grade vollständig erfolgreich. Die getrennte Android-Integration aus [PR #259](https://github.com/Ullmann27/lumo-lernen/pull/259) deckte danach eine nicht versionierte GLB-Importregel auf: Der Standardimport extrahiert drei PNGs neben dem Modell. Der geschützte APK-Exporter lehnt diesen nachträglich veränderten Source-Checkout zu Recht ab.

Eine rein nachträgliche Dateibereinigung ist keine Lösung: Bei einem erneuten Export können dann externe Texturreferenzen fehlen. Dieser experimentelle Weg wurde durch den tatsächlichen PCK-Test verworfen und nicht veröffentlicht. Die Schutzprüfung bleibt bestehen.

Die native `Lumo-Animated-Mobile.glb.import` wird deshalb ausdrücklich versioniert. Der erste Basis-Universal-Versuch (`2`) bestand Headless/PCK, blieb aber im echten GL-Menütest beim Weiterwechsel hängen. Er ist kein akzeptierter Android-Kandidat. Die endgültige Regel verwendet `gltf/embedded_image_handling=3`, verlustfreie unkomprimierte Einbettung des verwendeten Godot-Importers. Die drei tatsächlichen 1024 × 1024-RGBA-Texturen benötigen rechnerisch zusammen 12 MiB Bilddaten; das ist kein gemessener Gesamtverbrauch der App.

Das ursprüngliche GLB, alle Knochen, Materialien und Clips bleiben unverändert. Der Lade-Regressionslauf prüft zusätzlich tatsächlich vorhandene Albedo-/Normal-/PBR-Texturen mit gültigen Größen und ohne externe PNG-Abhängigkeit. Der erweiterte Headless-Lauf bestand 90 Prüfungen / 0 Fehler. Die verlustfreie Regel bestand den echten 1280 × 720-GL-Menütest einschließlich Moduswahl, Weiterwechsel und Orphan-Baseline mit 46 Prüfungen / 0 Fehler. Ein frischer und ein wiederholter exportierter Lauf sind zusätzlich erforderlich, bevor ein neuer APK-Kandidat gebaut wird.
