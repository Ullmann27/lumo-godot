# Lumo Jump: Eingabe, Original-Fuchs und getrennte Spielstände

Ausgangsbasis: Godot PR #156, `1d5c5cb45a323228f627ec529e6ff1ddd86f1c57`.

## Tatsächlicher Vorher-Zustand

Die produktive `scenes/games/jump_islands.tscn` verwendete bereits zwölf kollidierende Inseln, bewegliche Bonusplattformen, Sprungfedern, Kristalle, drei Lernstopps und den vorhandenen 65-Bone-Fuchs. Vier nebeneinanderliegende Richtungsknöpfe ersetzten einen analogen Stick. Der Sprungbutton reagierte über `pressed` beim Loslassen; die Sprunghöhe blieb gleich. Der sichtbare Originalfuchs wechselte in der Luft auf Idle; die Sprungpose des alten Ersatzmodells war ausgeblendet. Ein globaler Speicherpfad konnte gleichaltrigen Kindern denselben Abenteuerstand geben. Die vorhandene Abschlussgeste wurde durch `finished` sofort eingefroren.

## Implementierung im produktiven Szenenpfad

- Linker analoger Stick verwendet das bestehende Kart-Control und Original-Steuerungsassets; rechts liegt ein eigenständiger großer Sprungknopf. Jeder besitzt seinen Finger unabhängig, einschließlich Freigabe außerhalb des Knopfes. Sprung beginnt beim Drücken, frühes Loslassen verkürzt die echte Flugbahn. Kein Doppelsprung und kein Luftsprung nach abgelaufener Kantentoleranz.
- Bewegungsbeschleunigung, Bodenbremsung und Luftkorrektur sind getrennt; die Geschwindigkeit bleibt 5,5 m/s. Die vorhandene Gravitation, Plattformgeometrie, Sprungfedern und erreichbare Hauptstrecke bleiben bestehen. 150 ms Sprungpuffer und 120 ms Kantentoleranz sind über reale Kollisionen geprüft.
- `lumo_platform_pose.gd` besitzt während der Bewegung allein die Originalknochen. `set_platform_motion(velocity, grounded, delta)` verbindet Walk/Run, Aufstieg, Fall, Landefederung, Kopf/Hals und Schwanz mit tatsächlicher Bewegung. Geometrie und Kollision werden nicht durch die Animation verschoben. Nach Landung setzt die originale Idle-Animation fort; bestehende Gesten und Kart-APIs bleiben erhalten. Der Original-GLB wurde nicht geändert.
- Die Kamera folgt mit zeitstabiler Dämpfung und begrenztem Bewegungsvorlauf. Pause und Lernmodal löschen Eingaben und blockieren neue Steuerkontakte. Die Abschlussanimation darf abspielen.
- HUD und Daumensteuerung berücksichtigen Fenstermaßstab, übergebene Android-Dichte und Safe-Area. Native Eingabeziele bleiben mindestens 48 dp; Phone, Fold und 2400 × 1080 bei Dichte 2,625 werden geprüft.
- Speicherpfade werden für bekannte Kinder nach SHA-256 des `childKey`, Schulklasse und Fach getrennt. Resultatkennung, abgeschlossene Lernstopps und atomare Speicherung bleiben erhalten. Eine alte unzuordenbare `jump_session.cfg` bleibt unverändert und ist für den anonymen Standalone-Modus weiter verfügbar; sie wird keinem bekannten Kind ungeprüft zugeordnet.

## Nachweise

Die neuen Prüfungen ergänzen die vorhandenen Gates. Die konkreten lokalen Einzelbefehle lauten:

```sh
godot --headless --audio-driver Dummy --path . --script scripts/tests/jump_nextgen_regression.gd
godot --headless --audio-driver Dummy --path . --script scripts/tests/jump_regression.gd
godot --headless --audio-driver Dummy --path . --script scripts/tests/jump_extras_regression.gd
godot --headless --audio-driver Dummy --path . --script scripts/tests/lumo_original_jump_visual_regression.gd
godot --headless --audio-driver Dummy --path . --script scripts/tests/lumo_65bone_walk_gait_regression.gd
```

Die neue Regression besteht 84 Prüfungen. Gemessene tatsächliche Scheitelhöhen: 2,079 m bei gehaltenem Sprung und 1,090 m beim kurzen Tippen. Der bestehende Gesamtdurchlauf erreicht weiterhin alle zwölf Inseln und drei Lernstopps ohne Sturz (1013 Physikframes, zehn Kristalle). Die Save-Prüfung wechselt A → B → andere Klasse → anderes Fach → A und führt einen tatsächlichen SceneRouter-Neustart aus; fremde und ältere Stände bleiben erhalten.

Jeder dokumentierte lokale Prozess verwendet einen eigenen Testdatenordner. `RESULT.json` und die zugehörigen Rohlogs binden Ergebnisse an SHA-256 der getesteten Dateien.

Der zusätzliche Renderer-Test ist `scripts/tests/jump_nextgen_capture.gd`. Er verweigert Headless-Betrieb und benötigt `LUMO_CAPTURE_DIR`; echte `Input.parse_input_event`-Ereignisse steuern Stick und Sprung gleichzeitig. Vier Formate liefern jeweils Ready/Touch-Aufstieg/Flug/Landung plus JSON-Metadaten. **Zum Zeitpunkt dieses lokalen Berichts ist die Syntax geprüft; eine erfolgreiche Renderer-/Android-Ausführung ist hier noch nicht behauptet.** Die CI-Artefakte und der Integrationsbericht müssen das tatsächliche Ergebnis separat festhalten.

## Genaue Grenzen

Der Originalrig besitzt keine Augenlid-, Ohr- oder Kieferknochen und keine Gesichtsmorphs. Es wird kein neues Blinzeln oder Lip-Sync behauptet. Die Bewegungsposen sind berechnete Skelettanimationen auf dem bestehenden Skin, keine neue Motion-Capture-Bibliothek oder Terrain-Fuß-IK. Es gibt keinen physischen Fold7-, Temperatur- oder 60-FPS-Nachweis. Eine vollständige Neuinszenierung sämtlicher Jump-Level wird ebenfalls nicht behauptet.
