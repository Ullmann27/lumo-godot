# Lumo Kart Next Gen – Implementierungsstand (20.10.2026)

Working branch: design/lumo-kart-premium-ui-implementation-20261020
Draft PR: https://github.com/Ullmann27/lumo-godot/pull/111
Original visual assignment: https://github.com/Ullmann27/lumo-godot/pull/110
Unchanged base at creation: main/aebfcd7634fc64dbe20b462bcb6e6bffaa2721b4

## Bereits versionierte Codeänderungen
- scripts/games/kart_ui_theme.gd: wiederverwendbare native dunkelblaue Glasplatten, Cyan-/Goldakzente, Fokus-/Pressed-Zustände, Original-Nunito-Schriften.
- scripts/games/game_hub.gd: tatsächliche veraltete helle 3D-Spieleauswahl durch Lumo-konforme Oberfläche mit bestehender Lumo-Welt-Illustration, ORIGINALER 3D-Fuchs-Szene, echtem Rückweg, Kart/Wolkeninseln/Sternenjagd sowie erhaltener Klassen-/Fachwahl.
- scripts/games/kart_garage_menu.gd: der tatsächlich verwendete Kart-Garagen-Header, die 3D-Vorschau-Glasumrahmung und der Cup-Goldakzent wurden veredelt, ohne Rennparameter oder 5-Schritt-Auswahl anzutasten.
- scripts/tests/kart_nextgen_ui_smoke.gd: headless Szenentest für Klasse/Fach, die Originalfigur, reale Game-Routen und Mindesthöhe der Touchziele.
- Bereits vor diesem Auftrag vorhanden: scripts/games/kart_intro.gd mit 4,4 s Intro. Keine irreführende Behauptung über eine neu produzierte Tondatei.

## Abnahme
GitHub-Workflows wurden durch den PR-Branch ausgelöst: Verify Lumo Kart Stage 2; Lumo 3D Build. Bei Erstellung dieses Status liefen sie noch. Der neue Smoke-Test muss auf Godot 4.6.3 mit dem Befehl ausgeführt werden:
godot --headless --path . --script res://scripts/tests/kart_nextgen_ui_smoke.gd

Keine echte APK, kein Android-Geräte-Screenshot, keine FPS-Messung und keine optische Renderfreigabe in diesem Chat erzeugt. PASS/FAIL erst nach tatsächlichem Lauf dokumentieren.

## Nächste verifizierbare Arbeit
1. Aktuelle CI-Ergebnisse prüfen, tatsächliche Fehler aus Logs korrigieren.
2. Echt gerendertes Spielmenü und Garage vorher/nachher als Screenshots im Device/Emulator fotografieren; gegen Originalreferenz prüfen.
3. Sonnenhafen-2.5D-/3D-Kulisse und adaptive Menükarten nach visueller QA veredeln; vorhandenes Intro erhalten.
4. Godot-Pin zur Flutter-App nicht blind aktualisieren; separat testen und erst dann in Unity-APK (Flutter + Godot) übernehmen.
5. Kleine Commits und aktualisierte Fortsetzung protokollieren, main bleibt geschützt.