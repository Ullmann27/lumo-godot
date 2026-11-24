# World CH-2: Dialog- und Quest-Integrität

Ausgangsstand: 27bce1719ed52ba35b89ec6fa2d395e013963778 (ungeprüfter Grok-Zwischenstand). Keine Änderung an der laufenden 2080-Integration, Flutter-Pin, APK, main, bestehenden Nachweisen oder Spielstandformaten.

Behobene konkrete Schwachstellen: untypisierte Inhaltscontainer/erster Missionsschritt/Belohnungscontainer konnten vor der Validierung dereferenziert werden; nicht-endliche Fortschrittswerte waren nicht explizit abgewiesen; eine Kartenliste mit einem Duplikat und einer fehlenden tatsächlich erspielten Karte konnte die bisherige Wiederherstellungsprüfung passieren. Die neue Prüfung verwirft diese Fälle und erhält bisherigen Fortschritt.

Regression: echte Inhaltsdatei, zwölf Klassenstufen-Fragen (drei Dialoge je vier Klassen), falsch/richtig/erneuter Versuch, Karten-Voraussetzungen, alle vier Missionsketten, korrekte Orts- und Fahrbedingungen, neun eindeutige Karten, keine doppelte Schrittbelohnung, Legacy-Save, Ablehnung beschädigter Daten ohne Fortschrittsänderung. CI muss am exakten Commit laufen. Modell-/Dialogtest ist kein Android-/Grafik-/Spielsteuerungsnachweis. Kart-Bodenkontakt bleibt separat. Kein automatischer Merge oder Release.
