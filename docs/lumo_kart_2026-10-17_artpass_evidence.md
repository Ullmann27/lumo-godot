# Lumo Kart: QA-Nachtrag vom 17. Oktober 2026

Die aktuellen Heads der gestapelten PRs sind #95 `605f5b5a784f0af41ab80d6a37997475d0c5acac`, #96 `59b1154e4c9ffa30c4b6c2938e963ddbdd201320`, #97 `b70c623d7dfed57e0ff3fbeb7b5812f8f228292d` und #98 `aff8dd367f271b654d24db28a2a686b9e5acb626`.

Die Workflow-Pruefung ergab fuer diese Heads 16, 2, 4 und 2 erfolgreich abgeschlossene Actions. Auf #98 waren insbesondere Event-QA `39062332478` und Stage-2 `39062332562` erfolgreich. Das Event erzeugte zwei echte Godot-OpenGL-Bilder; der Vergleich meldete 108 geaenderte Raster-Samples. Die Stage-2-Tests enthalten 2325 CharacterPose-Checks und 225 StartHero-Checks ohne Fehler.

PR #99 baut isoliert auf #98 auf und ergaenzt ausschliesslich die mineralische Felsdarstellung des Dunkeltunnels. Der neue Godot-Test erstellt zwei echte Bilder am identischen Kamerastandpunkt: `deep_neon_flat_baseline.png` und `deep_neon.png`. Die Sichtbarkeit wird durch Pixelvergleich geprueft. Die finale CI-Pruefung von #99 steht noch aus.

Flutter-APK 1975, Lern-App, Kinderprofile, Voice, Savegames, Kontrollpunkte und Rennphysik werden nicht geaendert. Keine physische Fold7-FPS-Messung liegt vor.
