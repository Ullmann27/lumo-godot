# Lumo Sonnenhafen – Fortsetzung

Aktiver Spielstand: Sonnenhafen-Cup im Zweig
`codex/lumo-kart-sunharbor-2026-10-02`. Stand: 3. Oktober 2026.

Desktop-Testpakete und echte Bilder liegen in
[school-3d-43](https://github.com/Ullmann27/lumo-godot/releases/tag/school-3d-43).
**Android-Darstellung offen:** Trotz erfolgreicher Startmarker war Bild 41
rechts abgeschnitten; Bild 43 zeigte eine leere Engine-Fläche. Diese Pakete
sind keine Android-Freigabe. Die Bildprüfung verlangt jetzt auch dargestellte
Details statt nur einer gefüllten Fläche. 60 FPS auf echter Hardware bleiben offen.

- [Implementierung, Grenzen und Prüfungen](docs/SONNENHAFEN_2026-10-02.md)
- Rennablauf: `scripts/games/kart_island.gd`
- Hafenwelt: `scripts/games/kart_world.gd`
- Fahrzeuge und Tierfahrer: `scripts/games/kart_vehicle.gd`
- Touchsteuerung: `kart_joystick.gd`, `kart_touch_action.gd`
- Android-/Web-Bau und echte Bilder: `.github/workflows/build.yml`

Die Flutter-Lernapp liegt getrennt in
[Ullmann27/lumo-lernen](https://github.com/Ullmann27/lumo-lernen).
Ihre APK 274 ist kein Sonnenhafen-Spielpaket.

Der Nutzer erwartet eine deutlich hochwertigere Kartwelt, einen analogen
Neon-Stick links, Daumenaktionen rechts und flüssige 60 FPS. Vor wesentlichen
Änderungen sollen echte Bilder gezeigt werden. Das aktuelle Rennen bleibt
eine überprüfbare Ausbaustufe: eine Strecke mit geführter Fahrt. Weitere
Strecken, freie Fahrphysik und die endgültige Grafikqualität sind offen.
60 FPS müssen auf einem echten Android-Gerät gemessen werden.

Diese Fortsetzung berücksichtigt Display-Cutouts und Fold-Resizes, bündelt
farbige Dekorationen in räumlichen GPU-Batches und reduziert die Zeichenarbeit
der Karts. Nahaufnahmen behalten die modellierten Tierfahrer und Animationen.

Prüfungen starten mit `GODOT_BIN=/pfad/zu/godot bash tools/validate_project.sh`.
Engine: Godot 4.6.3 stable. Ergebnisse und Downloads nur nach erfolgreichem
Build als abgeschlossen bezeichnen.

Installationskorrektur: Der alte Strip-Schritt komprimierte `resources.arsc`.
Android 11+ lehnt das bei targetSdk >= 30 ab, selbst wenn Signatur und
`zipalign -c` bestehen. `tools/package_android_apk.py` erhält das ZIP-Format,
speichert die Ressourcentabelle unkomprimiert und prüft deren Datenoffset
nach dem Ausrichten und Signieren. CI und lokaler Android-Bau verwenden
denselben Helfer; Build Tools 35 richten gespeicherte native Bibliotheken
zusätzlich auf 16-KB-Grenzen aus. Paketname und Signatur bleiben gleich.

Android-Startkorrektur: `_cl_` ist eine binäre Datei für Startargumente,
kein Ordner für Spieldaten. `prepare_android_assets.py` legt `lumo3d.pck`
direkt in `assets` ab und schreibt `--main-pack res://lumo3d.pck` in die
Startdatei. Die fertige APK wird auf diese Verknüpfung geprüft. CI startet
zusätzlich das exportierte Spielpaket aus einem leeren Arbeitsverzeichnis.
Der Emulator erhält eine aus demselben Gradle-Bau erstellte, ausgerichtete
und signierte x86_64-APK. Das rohe Godot-Gradle-Ergebnis ist standardmäßig
unsigniert und darf nicht direkt für einen Installationstest verwendet werden.
