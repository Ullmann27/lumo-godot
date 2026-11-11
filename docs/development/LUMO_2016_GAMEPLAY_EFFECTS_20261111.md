# LUMO 2016 – Kart-Effekte aus geprüftem WIP-Bestand

Dieser Entwicklungszweig basiert auf dem genau getesteten Godot-Kandidat b357b2f8decb4b11b0cc45e9fde2b8df5ec9cbe1 (LUMO 2015). Die Fünf-Schritt-Garage, Original-Lumo-Figur, Sonnenhafen-Fassaden, ursprüngliche Flugphysik und bestehende Fahrtests bleiben bestehen.

Aus dem früheren PR #146 wurden die isolierten, dort bereits einzeln getesteten Lufttricks integriert: Salto bei nahezu neutraler Lenkung, Rolle bei starker Lenkung während eines Sprungs, visuelle Drehung sowie eine kurze zusätzliche Boostzeit nur nach abgeschlossener Figur und erfolgreicher Landung. Der bestehende Lande- und Rettungsablauf wird beibehalten. Der Air-Trick-Test wurde als zusätzliches Pflichtgate angeschlossen. Hinzu kommen drei Driftfunken-Stufen (Aufladung, blau, orange) mit Materialwechsel nur bei Stufenänderung. Source: https://github.com/Ullmann27/lumo-godot/pull/146.

**Prüfstatus zum Zeitpunkt des Commits:** Übernahme quellcodebasiert. Für diesen neuen kombinierten Stand sind Godot-CI, reale Rennfahrt, Android-Emulator und Fold7 noch nicht als bestanden ausgewiesen. Ohne erfolgreiche Prüfungen darf kein 2016-APK-Release behauptet werden. Ein aktueller APK-Build muss das exakte Godot-Commit pinnen und das bisherige Android-Paket und Zertifikat erhalten.
