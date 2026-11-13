# Rhythm Party – spielbare Sternentour und eigene Liedmuster

## Befund

Der Ausgangsstand enthielt vier Originallieder, eine echte räumliche Bühne und vierzig Tap-/Hold-/Slide-/Star-Noten je Runde. Alle Lieder verwendeten dasselbe Lane-Muster; Schwierigkeit änderte allein das Zeitfenster. Die ursprüngliche Notenfolge mit 1,35 Beats Abstand lag nicht durchgehend auf dem musikalischen Raster. Dauerhafte Daten waren kindgetrennte Bestwerte pro Lied ohne Kampagnenpfad.

## Produktive Änderung

- `rhythm_state.gd`: vier unterscheidbare, deterministische Phrasen mit antwortenden Folgen, drei Abstände/Dichten und drei bestehenden Timingfenstern. Jede Schwierigkeit behält vierzig Noten und gleiches maximales Rohpunktepotential. Noten liegen auf ganzen/halben Beats; Hold und Slide erhalten eine tatsächliche Abschlusszeit vor der nächsten Note. Slide-Ziele sind immer direkt benachbart. Bestehende Combo-, Stern- und Reward-Regeln bleiben erhalten.
- `rhythm_audio.gd`: vier eigenständige synthetisierte Melodieverläufe aus dem bestehenden Originalmaterial, mit passender Halbbeat-Percussion. Keine fremden Aufnahmen oder Online-Anforderung.
- `rhythm_tour.gd`: vier freischaltbare Bühnen pro Schwierigkeit – Wiesenbühne, Wolkenkonzert, Funkenfest, Mondfinale. Ziele verlangen 16–26 von vierzig Tönen und später jeweils einen gehaltenen beziehungsweise gewischten Ton. Fehler und nur „Gut“-Treffer sind ausdrücklich zulässig. Die drei Schwierigkeitswege speichern unabhängig; abgeschlossene Bühnen sind erneut spielbar.
- `rhythm_world.gd`: tatsächliche Modusauswahl, Tourkarte, Ziele im laufenden Spiel, Rückmeldung, nächste freigeschaltete Bühne und vier mit dem Fortschritt verbundene 3D-Bühnensterne. Die freie Liedauswahl bleibt unmittelbar verfügbar. Keine isolierte neue Szene oder nicht angeschlossene Modell-Demo.
- Die bisherigen `user://lumo_rhythm_<kind>.cfg`-Dateien erhalten ausschließlich eine additive `tour_v1`-Sektion. Bestehende Song-Bestwerte und unbekannte Einstellungen bleiben erhalten. Dateien werden über eine temporäre Datei atomar ersetzt. Unlesbare oder unbekannte Tour-Versionen werden nicht überschrieben; freies Spielen bleibt möglich.
- Tatsächliche Touch-Zuordnung je Finger ersetzt die für Drag/Hold unvollständige Maus-Emulation. Fingerwechsel in eine andere Lane löst die ursprüngliche Lane, und Loslassen außerhalb der Buttons lässt keinen Ton hängen. Ein gehaltener zweiter Finger bleibt unabhängig. Pause funktioniert auch mit einer noch gehaltenen Lane; nach dem Pausenmenü bleiben zwei Sekunden zum erneuten Halten, bevor Lied und Bewertung weiterlaufen.
- Für echte Audiotreiber folgt die Spieluhr der Wiedergabeposition plus Mischzeit minus einmalig erfasster Ausgabelatenz. Rückwärts springende Samples drehen die Bewertung nicht zurück. Der Dummy-Treiber bleibt eine ausdrücklich getrennte Testuhr. Grundlage: [Godot 4.6 Audio-Synchronisation](https://docs.godotengine.org/en/4.6/tutorials/audio/sync_with_audio.html) und [AudioServer](https://docs.godotengine.org/en/4.6/classes/class_audioserver.html). Dies ist keine Messung der Android-Ausgabelatenz.

## Ausgeführte Prüfungen

Godot 4.6.3, Linux Headless. Logs unter `docs/evidence/nextgen-rhythm-20261113/`.

| Prüfung | Neuer Nachweis |
| --- | --- |
| `rhythm_tour_regression.gd` | 2118 Checks bestanden: zwölf faire Charts, musikalisches Raster, benachbarte Slides, frühe Hold-Freigabe/verspätete Hits, ganze Tour auf jeder Schwierigkeit mit zehn absichtlichen Fehlern und nur „Gut“-Timing, gesperrte/unfinished/duplizierte Runden, additive Datei und getrennte Fortschritte. |
| `rhythm_tour_play_regression.gd` | 48 Checks bestanden: tatsächlicher Tour-/Start-/Ergebnis-Touch, reale Tap-/Hold-/Slide-/Zweifinger-Ereignisse, Pause während Hold, Wiederaufnahme, absichtlich unperfekte gespielte Runde, Disk-Save/Kind-Wechsel/Scene-Reload und Menüs/Tasten in 412×915, 690×829 und 914×411. Die Notenzeit wird im Test kontrolliert; damit wird keine akustische Gerätelatenz behauptet. |
| `rhythm_party_regression.gd` | Bestehende Song-/Combo-/Save-/Reward-Prüfung erneut ohne Assertion-/Script-Fehler bestanden. Der Test fand zunächst ein echtes Problem: ein während der Runde hinzugekommener Bestwert wurde durch die neue Cache-Instanz überschrieben. Frisches Zusammenführen beim Rundenende behebt dies. |

Der Produktionstest fand außerdem einen tatsächlichen Mehrfingerfehler des Pausenbuttons und ein Entfernen von GUI-Knoten während der Eingabezustellung. Der native Pausentouch und verzögertes Freigeben ausgeblendeter Menüknoten beheben beide Fälle.

## Visuelle Evidenz und Grenzen

`rhythm_tour_play_regression.gd -- --capture` benötigt einen tatsächlichen Renderer sowie `LUMO_CAPTURE_DIR` und erzeugt:

1. `01_rhythm_tour_map.png`
2. `02_rhythm_slide.png`
3. `03_rhythm_tour_result.png`

Headless wird für Bilder abgelehnt. Diese neue Rhythm-Etappe benötigt einen eigenen GitHub-/Renderer-Snapshot; frühere Bauwelt-Bilder belegen sie nicht. Die finale visuelle Prüfung, Android-Audio-/Touch-Latenz und Fold7-FPS stehen separat aus. Der bestehende Rhythm-Begleiter wurde in dieser Etappe nicht durch ein neues Charaktermodell ersetzt.
