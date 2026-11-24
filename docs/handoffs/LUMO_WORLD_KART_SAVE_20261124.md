# Lumo World: Kart beim Fortsetzen wiederfinden

24. November 2026. Ausgangspunkt: `repair/lumo-device-bugs-2078`, Commit
`c3f459eca88f659da1a9e4af1c990c804e715528`, Tree
`6b7c47a3010cec04736f9cd495adf34ad0ec2e6f`.

## Belegter Fehler und Änderung

Die Welt speicherte den Standort des Kindes, aber keine Kartposition. Beim erneuten
Öffnen wurde das Kart immer am ursprünglichen Parkplatz `(77, 0.2, 18)` erzeugt.
Ein in Sternenstadt oder im eigenen Dorf fortgesetzter Spielstand konnte deshalb
weit vom zuvor gefahrenen Kart starten. Die Einstiegstaste ist ab fünf Metern
Entfernung deaktiviert; die Karte enthielt außerdem keinen Kartstandort.

Der vorhandene Version-1-Spielstand erhält jetzt einen optionalen `kart`-Eintrag
mit Position und Richtung. Spielstände ohne diesen Eintrag bleiben lesbar und
verwenden den bisherigen Parkplatz. Ungültige Daten werden vor Änderungen am
Zustand zurückgewiesen. Während eines Sturzes bleibt die letzte gültige Kartpose
erhalten: Der Bewegungspfad übernimmt die Pose nur nach tatsächlich erkanntem
Bodenkontakt durch `move_and_slide`. Beim Speichern während einer Fahrt wird
der vorhandene, physisch geprüfte sichere Ausstieg als Wiederbeginn verwendet;
während eines Sturzes bleibt der letzte sichere Fußpunkt erhalten. Die
produktive Szene speichert und lädt die Pose zusammen mit dem vorhandenen
Weltstand.

Die Weltkarte erhält einen eigenständigen Kartmarker und die Taste **Mein Kart
zeigen**. Sie erhält die tatsächliche Position des Fahrzeugs; das Rennportal ist
weiterhin ein eigener Ort. Der Marker und die Kartenfokussierung ändern weder
Spielerposition noch Auftragsfortschritt. Das feste Schild am ursprünglichen
Stellplatz heißt nun **Lumo Kart · Parkplatz**, sodass es nach einer Fahrt nicht
behauptet, das Kart stehe noch dort.

## Tatsächlich ausgeführte Prüfung

Der neue Test `scripts/tests/lumo_world_kart_persistence_regression.gd` wurde mit
Godot **4.7.2-stable** in einem kleinen Projekt ausgeführt, das dieselben
Produktionsdateien für den Weltzustand und die Karte verwendet:

```text
godot --headless --path /tmp/lumo-world-kart-persistence-20261124 \
  --script res://scripts/tests/lumo_world_kart_persistence_regression.gd

[WorldKartPersistence] PASS 63 checks engine=4.7.2-stable (official) scope=state_and_atlas
```

Geprüft wurden alte Spielstände, ein tatsächlicher JSON-Datei-Rundlauf in eine
neue Zustandsinstanz, gespeicherte Kartposition und Richtung, Zurückweisung
ungültiger Kartdaten ohne Teiländerung, Zurückweisung einer frühen Fallposition
ohne Bodenkontakt trotz noch gültiger Höhe, Kartfokussierung durch echte
`InputEventMouseButton`-Eingaben und mindestens 48 × 48 UI-Einheiten bei 280,
360, 720 und 1384 Pixeln Fensterbreite. Die Kartenaktionen ließen den gespeicherten
Fortschritt unverändert.

`git diff --check` meldete keine Formatfehler. Der unabhängige Quellreview wird
separat durch den koordinierenden Agenten festgehalten.

## Noch nicht als ausgeführt belegt

Der vorhandene `scripts/tests/lumo_world_device_regression.gd` enthält zusätzlich
einen echten Produktionsszenen-Neustart: Kart in der Stadt abstellen, normal
speichern, Szene entfernen, denselben Spielstand laden, Kartpose, Kartkarte,
Einstieg und die drei lokalen Auftragsfiguren prüfen. Die Parkpose entsteht
dabei durch echte Bewegungs-/Bodenkollisionen. Zusätzlich wird eine Pause in
einer frühen Fallphase über Wasser geprüft. Dieser erweiterte Test
wurde hier noch nicht ausgeführt. Die lokale Kopie enthält nicht alle
Produktionsassets, und lokal ist Godot 4.7.2 statt der Projektversion 4.6.3
verfügbar. Ein Display oder Xvfb für Rendereraufnahmen war nicht vorhanden.

Vor Übernahme in eine APK sind die vollständige Szene mit Godot 4.6.3, aktuelle
Rendererbilder und der tatsächliche Android-Wiedereinstieg zu prüfen. Die 63
Prüfungen ersetzen diese Nachweise nicht.

## Einordnung der anderen Figuren

Nelli, Bruno und Tilda sind lokale Auftragsfiguren. Das eigene Dorf erzeugt
zusätzlich lokale Bewohner aus seinem gespeicherten Siedlungszustand. In den
geprüften World-Pfaden ist keine Online-Mitspieler-Anbindung vorhanden. Der
Kart-Speicherfehler erklärt nicht pauschal jedes gemeldete Verschwinden dieser
Figuren. Ihre tatsächliche Sichtbarkeit muss entlang des normalen Einstiegswegs
mit dem installierten Stand und seinen enthaltenen Assets geprüft werden.
