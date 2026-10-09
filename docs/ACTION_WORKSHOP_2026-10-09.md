# Action-Parcours und Werkstatt-Prüfstand – 9. Oktober 2026

Fortsetzung auf a6c4d69 (integriert Claudes 99cdb77: 14 Karts, Teile/Tuning sowie profilbezogene Sterne).

- Sonnenhafen: 30 m Aquarium mit transparentem Innenbogen, animierter Wasserhaut, Fischen und Lichtstreben. Sechs seitliche Hütchen lassen die zentrale Fahrlinie frei. Treffer bremsen kurz; der Schild schützt.
- Werkstatt: Serie/Tuning-Vergleich für Tempo, 0–50, Bremsweg und Turbodauer. Kostenloser animierter Beschleunigungs-/Bremslauf. Die Werte verwenden dieselben Antriebsformeln wie das Rennen; sie sind als Simulation auf ebener Straße ohne Boost gekennzeichnet.
- Zusätzliche Beleuchtung macht die Fahrzeugvorschau heller. Alle 14 Karts und vorhandenen Upgrades bleiben erhalten.

## Geprüft

Godot 4.6.3, OpenGL/Mesa: Werkstatt in fünf Fenstergrößen, Flotten-Fahrwerte, neue Action-/Prüfstand-Regression, vollständiger Zwei-Runden-Ablauf mit 16 Toren, Speichern/Fortsetzen, Ergebnis-Wiederöffnung und einmaliger Belohnung; 104 Runden-/Sitzungsprüfungen, 10 Rückkehr-/ACK-Prüfungen, 29 Zeitformat- und 24 Profilbudget-Prüfungen. Die strengen Android-Evidenzleser akzeptieren die frisch erzeugten Rohdaten und Quellhashes.

Die abschließenden Spieltests wurden sequenziell mit eigenen Benutzerverzeichnissen ausgeführt. Parallele frühere Läufe hatten uneinheitliche Save-/ACK-Ergebnisse; daraus wird kein behobener Gerätefehler abgeleitet. Der Android-Workflow führt die Proben ebenfalls sequenziell aus.

## Bilder

Die drei PNGs unter `docs/proof/2026-10-09-action-workshop/` sind echte Renderings der laufenden Spielszene, keine Entwurfsbilder. Die Streckenposition wurde für die Aufnahme gesetzt. Der Werkstatt-Test benutzt ein isoliertes Sternbudget; das Bild zeigt keinen realen Kinderkontostand.

## Grenzen

Android-Installation, Laufzeit und API-35/36-Tests werden im zugehörigen APK-Workflow separat geprüft. Noch keine Aussage über 60 FPS auf einem physischen Fold-Gerät oder vollständige Gleichheit mit allen Designvorlagen. Kein Main-Merge und kein Release.
