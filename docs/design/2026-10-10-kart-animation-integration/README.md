# Lumo Kart: animierter Lumo im produktiven Renn-Code

Stand: 10. Oktober 2026. Das vorhandene geriggte Lumo-Modell ist nun mit der echten Spieler-Fabrik und den tatsächlichen Rennzuständen verbunden. Dies ist eine Quellcode-Integration mit echten Godot-Laufzeittests, noch keine ausgelieferte Android-APK.

## Entwicklungsstand und Schutz paralleler Arbeiten

- **Repository:** Die Integration liegt im eigenen Branch `computer/lumo-kart-animation-integration-2026-10-10` des [bestehenden Godot-Projekts](https://github.com/Ullmann27/lumo-godot).
- **Grundlage:** Der Branch setzt auf `b056d5349c5d111a4c9ca41710681b87585f2d62`, dem isolierten Animationsstand aus [PR #51](https://github.com/Ullmann27/lumo-godot/pull/51), auf. PR #51 allein enthält diese neue Verbindung zum Produktcode nicht.
- **Abgrenzung:** Keine Änderungen an Flutter, Lerninhalten, Save-Schema, Belohnungsberechnung, Fahrzeugkollisionen, Rennphysik oder Sulafat. Die parallelen [Godot-Spracharbeiten #48](https://github.com/Ullmann27/lumo-godot/pull/48) und [Flutter-Spracharbeiten #255](https://github.com/Ullmann27/lumo-lernen/pull/255) bleiben unberührt.
- **Auslieferung:** Der Flutter-Godot-Pin bleibt in dieser Phase unverändert. Änderungen sind nicht automatisch auf dem Samsung-Gerät installiert; ein nachfolgender APK-Build muss den geprüften Integrationscommit ausdrücklich übernehmen.

## Tatsächliche Produktverbindung

- **Spieler-Fabrik:** `kart_island.gd` aktiviert die Animation am normalen Renn-Spieler. `kart_vehicle.gd` bindet das vorhandene Modell nur beim Fahrer `fox` ein. Andere Fahrer, Gegner, Garage und Ghosts behalten ihre bisherigen Darstellungen.
- **Lenken:** Die echten Lenkwerte bewegen das vorhandene Lenkrad. Arm-IK folgt dessen beiden Ankern, ohne Knochenlängen oder Kart-Geometrie zu strecken. Clips werden mit 30 Hz aktualisiert; der Handkontakt folgt auch in dazwischenliegenden visuellen Frames.
- **Beschleunigung, Boost und Drift:** Reaktionen übernehmen bestehende Bewegungswerte und wirken nur auf das Skelett. Kein Animationscode vergibt Geschwindigkeit, Grip oder Turbo.
- **Sprung und Landung:** Der Adapter erhält den wirklichen `airborne`-Zustand aus dem Rennen. Der Rampentest fährt die bestehende Bergwelt-Rampe; er setzt den Flugzustand nicht künstlich.
- **Treffer:** Ein durch die vorhandene Kontaktprüfung erzeugter Treffer löst eine abklingende Reaktion aus. Ein mehrere Frames lang aktiver Trefferstatus startet sie nicht ständig neu.
- **Zieleinlauf:** Der existierende `celebrate(place)`-Pfad startet einen einmaligen Jubel oder ein freundliches Nicken. Beim Ausrollen hält die linke Hand das Lenkrad; nach dem Clip kehrt Lumo zur Sitzpose zurück.
- **Pause und Ruhemodus:** Der Fahrzeugknoten besitzt den einzigen visuellen Takt. Pause friert die Pose ein; Fortsetzen setzt sie fort. Die vorhandene Einstellung für reduzierte Bewegung stoppt die Clipbewegung.
- **Neuaufbau und LOD:** Kart-Varianten geben den alten Rig-Knoten frei und binden den neuen korrekt. Nah-/Fernwechsel zeichnen keine zweite alte Lumo-Figur. Die Chassis-Proxies entstehen vor dem Material-Batching, nicht aus bereits zusammengefasster Geometrie.

## Behobene Integrationsfehler

- **Exportiertes Modell:** Laden und Packen geschehen nicht mehr innerhalb von `assert()`. Der Charakter verwendet bevorzugt die native importierte `PackedScene`, damit der Export nicht auf entfernte Roh-GLB-Dateien angewiesen ist.
- **Animationsuhr:** Wiederholte Zustandsmeldungen setzen den Zeitakkumulator nicht mehr zurück. Sonst hätte die mit 30 Hz aktualisierte Animation bei 60-Hz-Physik stillstehen können.
- **Kontakt zwischen Updates:** IK wird auch zwischen Clip-Updates nachgeführt. Der Kontakt bleibt bei kontinuierlicher Lenkung erhalten.
- **Jubel-Ende:** Endet der Jubel während eines Animationsschritts, werden beide Hände noch im selben Schritt wieder ans Lenkrad geführt.
- **Material- und LOD-Sicherheit:** Der Chassis-Fernproxy wird aus der ursprünglichen Geometrie erstellt und später umgeschaltet. Dabei bleiben bestehende Zusatzknoten am Fahrzeug erhalten.
- **CI-Abhängigkeit:** Die isolierte Fahrzeugprüfung kopiert jetzt die beiden neu benötigten Charakter-Skripte. Stage 2 prüft die echte Spieler-Fabrik und zusätzlich das exportierte PCK.
- **Importgrenze:** Eine `.gdignore` im vorhandenen Entwicklungs-Kandidatenordner schließt dessen Blender-Datei und Dokumentationsbilder vom Spielimport aus. Die Originaldateien werden nicht gelöscht oder überschrieben.

## Echte Prüfungen und Grenzen

| Prüfung | Ergebnis | Aussagegrenze |
|---|---|---|
| Produktive Rennszene, Headless | 2.069 Prüfungen, 0 Fehler | Linux/Godot 4.6.3, kein Android-Gerät |
| Produktive Rennszene, echter GL-Lauf | 2.116 Prüfungen, 0 Fehler, 12 Screenshots | Compatibility-Renderer auf Mesa/llvmpipe |
| Exportiertes Linux-PCK, ohne Quellprojekt | 2.069 Prüfungen, 0 Fehler | Editor-Binary führt das exportierte Paket aus; keine Release-APK-Abnahme |
| Tatsächliche Bergwelt-Rampe | Ein Sprung, eine Landung, 36 Physikframes in der Luft, kein Sturz | Startposition und Geschwindigkeit sind Testvoraussetzungen |
| Lenkradkontakt im Produkttest | Größter gemessener Hand-Anker-Abstand etwa 1,14 mm | Kein kollisionsgeprüfter Kontakt jedes einzelnen Fingers |
| Bestehende Physikregression | Erfolgreich | Bestehender automatisierter Prüfumfang |
| Bestehende Sprungregression | Erfolgreich | Start/Flug/Landung, Rettung und Checkpoints |
| Bestehende Host-/Save-/Reward-Regression | Erfolgreich | Pause, stabile Ergebnis-ID, einmalige Belohnung, Fortsetzen und Altsave |
| Bestehende Fahrzeugregression | Erfolgreich | Geometrie, Farben, Schatten, Effekte, LOD und Hysterese |
| Isolierte CI-Fahrzeugprüfung | Erfolgreich | Neue Skript-Abhängigkeiten mitkopiert; kein Lumo-Modell für unveränderte Alt-Fahrer nötig |
| Frühere Animationsprüfungen | 21 Charakter-, 379 Kart- und 165 CPU-Prüfungen bestanden | Keine Android-GPU-/FPS-Messung |
| Projekt- und Streckenvalidator | 0 Fehler; Projektvalidator mit 7 bestehenden Warnungen | Bisherige Placeholder-Pfade und Shell-Ausführbarkeit unverändert |

Der Zieleinlauftest setzt Distanz und Checkpoints als Testvoraussetzungen und ruft anschließend den unveränderten Produktabschluss auf. Er behauptet nicht, zwei vollständige Runden manuell gespielt zu haben. Eine erneute Abschlussmeldung erzeugt keine doppelte Belohnung; reine Animationsschritte verändern weder Fahrzeugtransform, Rennfortschritt noch Sterne.

Die Aufnahmen entstehen aus der tatsächlich instanziierten Rennszene, nicht durch Bild-/Videogenerierung. Die kompakte Ansicht mit 640 × 320 und die große Ansicht mit 1280 × 720 sind logische Desktop-Viewport-Prüfungen, kein Galaxy-Z-Fold-Gerätetest. Das kurze Video hat 15 gespeicherte Bilder pro Sekunde und ist kein FPS-Benchmark.

Der aktuelle CPU-Lauf misst beim einzelnen visuellen Kart-IK-Adapter etwa 0,107 ms p95 und 0,120 ms maximal. Er schließt GPU-Skinning, Zeichnen und das vollständige Rennen aus. Es ist kein physisches Android-Gerät angeschlossen; Samsung-/Android-16-Leistung, thermisches Verhalten und eine neue APK wurden in dieser Phase nicht geprüft.

## Modell, Stimme und Credits

Das vorhandene mobile GLB bleibt unverändert: SHA-256 `3559f700784bc1006905ee3aae01e8bcfbffb95b4f621f7430ce771ba0e3efd5`, 30.000 Dreiecke, 65 Knochen, neun Clips und drei Texturen mit 1024 × 1024 Pixeln. Es wurde kein weiterer Meshy-Auftrag, keine zusätzliche kostenpflichtige Generierung und keine neue Fahrerproduktion gestartet.

Sulafat und die Sprachausgabe werden nicht geändert. Die bestehende Audio-Synchronisationsschnittstelle bleibt erhalten, ist hier aber nicht an die Renn-Audiowiedergabe angeschlossen. Das Modell hat keine Gesichts-Shape-Keys; echte Lippen-Synchronisation oder neue Blinzelanimationen werden nicht behauptet.

Die ursprüngliche Modellnamensnennung und Lizenz stehen unverändert unter `assets/characters/lumo_animated/ATTRIBUTION.md`. Computer-Credits wurden nicht zuverlässig ermittelt; eine konkrete Budgeteinhaltung wird nicht zugesichert.

## Reproduktion und nächste Entwicklungsgrenze

```bash
# Godot 4.6.3 muss lokal vorhanden sein.
GODOT_BIN=/pfad/zu/Godot_v4.6.3-stable_linux.x86_64 \
  bash tools/lumo_animation/run_kart_integration.sh /tmp/lumo-kart-integration

# Vorhandene isolierte Animationstests:
GODOT_BIN=/pfad/zu/Godot_v4.6.3-stable_linux.x86_64 \
  bash tools/lumo_animation/run_phase_one.sh /tmp/lumo-animation-review

# Echte Bilder der Produktszene, optional mit Video-Einzelbildern:
xvfb-run -a /pfad/zu/Godot_v4.6.3-stable_linux.x86_64 \
  --path . --rendering-method gl_compatibility --audio-driver Dummy \
  --script res://scripts/tests/lumo_kart_production_regression.gd \
  -- /tmp/lumo-kart-production-render --video
```

Der Integrationsbranch muss gemeinsam mit seinem Animations-Vorgänger übernommen werden. Für eine installierbare Lern-App ist danach ein abgestimmter neuer Godot-Pin im Flutter-Repository sowie ein APK-Build mit Android-Runtime-Abnahme erforderlich. Garage, weitere Gegner, Gesichtsanimation und optionale Flutter-Begleiterdarstellung sind nicht Bestandteil dieser Integration.
