# Lumo Sonnenhafen – Fortsetzung

Aktuelle Integration in **eine Flutter-Android-App** im Zweig
`codex/lumo-unified-kart-2026-10-03`: [Host-Schnittstelle, neue Rennlogik und
ausgeführte lokale Prüfungen](docs/LUMO_HOST_2026-10-03.md).
Die unten dokumentierten Android-Releases 41/43/45 gehören zum vorherigen
separaten Godot-Paket; sie bestätigen keinen Build der gemeinsamen APK.

Aktueller überprüfbarer Übergabestand: Der JNI-Fix `3759c156` ist in der
installierten gemeinsamen APK 279 bestätigt: vollständiges Rennen, native
Ergebnisbestätigung, Neustart, zweimal Rückkehr zu Spielen und Wiederöffnung
mit gespeichertem HUD/Grafikmodus. Das abgeschnittene kompakte Pausenmenü ist
im gespeicherten Pin `77269301` durch feste Rückkehrknöpfe korrigiert.
Vollständiger Godot-Validator und reale Desktop-Touch-/Fold-Prüfungen bestehen.

Die gemeinsame APK 280 (0.10.5) absolvierte im KVM-Lauf `37130107394` erneut
zwei Runden, Ergebnis, Neustart und zweimal Spiele-Rückkehr; Flutter zeigte
neun Sterne. Beide Rückkehrknöpfe waren bei 800×480 vollständig sichtbar.
Nach dem tatsächlichen „Zum Lernen“-Touch verschwand jedoch der gesamte
Emulator. Host-gfxstream meldete fehlende GL-Kontexte; eine Renderer-Störung
ist wahrscheinlich, ohne gesicherten Gastlog/Exit-Signal kein belegter
App-Crash. Der vollständige Androidlauf bleibt **offen und unveröffentlicht**.
Der folgende KVM-Lauf `37132721782` mit Emulator 36.3.10 bestätigt auch den
nativen Lern-Rückweg: Flutter bleibt aktiv, die Engine beendet, Akademie und
lokale Plusaufgabe mit Hilfe/Antwort/gespeichertem Fortschritt funktionieren.
Dieser Gesamtlauf scheiterte erst an der Memory-QA-Beobachtung. Das vollständige
Memory-/Karten-/Fold-/Neustartergebnis und der Download bleiben offen.
Die bereits gebauten APK-Bytes bleiben unverändert. Aktueller Prüfstand und endgültiger Download werden im
[Flutter-Integrationsbericht](https://github.com/Ullmann27/lumo-lernen/blob/codex/lumo-unified-android-2026-10-03/docs/UNIFIED_ANDROID_2026-10-03.md)
geführt. Kein Test auf einem echten Nutzerhandy.

Historischer separater Spielstand: Sonnenhafen-Cup im Zweig
`codex/lumo-kart-sunharbor-2026-10-02`. Stand: 3. Oktober 2026.

[Geprüfte Testpakete und echte Bilder: school-3d-45](https://github.com/Ullmann27/lumo-godot/releases/tag/school-3d-45).
Programmstand `a3beff602481dee993736bc15e9d0f1f6572ca07`: PR-Lauf und
wiederholter Push-Lauf bestanden. Installierter Android-Normalstart, direkter
Kart-URI, Querformat und vollständiges Rennbild im API-35-Emulator geprüft.
Bild 45 wurde zusätzlich visuell kontrolliert. Frühere Pakete 41/43 besitzen
Darstellungsfehler und sind keine Android-Freigabe. 60 FPS, arm64-Gerätetest
und endgültige Grafikqualität bleiben offen.

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
