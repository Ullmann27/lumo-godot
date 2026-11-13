# LUMO Kart: offene Hafenbühne für das Hauptmenü

Ausgangsstand: Godot `ada5ed81`, eigener Arbeitszweig `chatgpt/lumo-kart-home-20261113`.

## Gestaltungsgrundlage

Vor der Implementierung wurden die tatsächlichen aktuellen LUMO-Landingbilder in Quer- und Hochformat sowie echte Menüaufnahmen von Mario Kart World und Sonic Racing: CrossWorlds verglichen. Die sichtbare Lücke war der geschlossene kühle Garagenraum mit weitgehend gleichartigen blauen Schaltflächen. Die Vergleichsmenüs geben der Welt und der Figur deutlich mehr Bildgewicht und unterscheiden die Spielmodi durch große eigene Zeichen.

Öffentliche Quellen für den Vergleich und die funktionale Einordnung:

- [Nintendo: Mario Kart World – World](https://www.nintendo.com/us/gaming-systems/switch-2/featured-games/mario-kart-world/world/)
- [Nintendo: Mario Kart World – Free Roam](https://www.nintendo.com/us/gaming-systems/switch-2/featured-games/mario-kart-world/free-roam/)
- [Nintendo: offizielle Direct- und Treehouse-Videos](https://www.nintendo.com/us/gaming-systems/switch-2/featured-games/mario-kart-world/videos/)
- [SEGA: CrossWorlds 2.0, Abschnitt zur erneuerten Moduswahl](https://sonicracing.sega.com/en/details/0002126gfgbf5vluio.html)

Die gesichteten Menüaufnahmen dienten nur dem Vergleich. Es wurden keine Nintendo-/SEGA-Grafiken, Figuren oder Menübilder in LUMO eingebaut.

## Tatsächlich implementiert

- `kart_home_promenade.gd` erzeugt eine offene räumliche Hafenbühne im bestehenden Vorschau-Viewport. Vorn stehen das tatsächlich ausgewählte Kart und der originale animierte Lumo. Dahinter liegen eine gepflasterte Promenade, Wasser, Segelboote, eine geschwungene Hochstraße, Inseln, ein Leuchtturm, Küstenhäuser und ein entfernter Looping. Die originale bereits vorhandene `wave_pavilion_lod2.glb` wird wiederverwendet. Die Strecke im Hintergrund ist ausdrücklich Menükulisse und keine zusätzliche Rennsimulation.
- Wiederholte Bauteile werden nach Materialfamilie in MultiMesh-Batches zusammengefasst. Die Szene enthält keine zusätzlichen Physikkörper. Der Himmel ist ein eigener geometrischer Hintergrund mit Farbshader; es wird keine neue Sky-/Reflexionsressource angelegt.
- Wasser, Wimpel, Boote und Möwen verwenden eine gemeinsam begrenzte Szenenuhr. Reduzierte Bewegung hält diese Uhr an; der Anwendungs-Pausenpfad deaktiviert die Bühne. Beim Öffnen der Garage wird die vorhandene Werkstatt einschließlich Originalfigur, Auswahl und Inspektion wieder sichtbar.
- Die Moduswahl verwendet native Buttons mit eigenen schrägen Rennflächen, unterschiedlichen Akzentfarben und den vorhandenen LUMO-Symbolen. Im schmalen Format bleiben die Symbole sichtbar. Die Startfläche bekommt mehr Breite, die vorhandenen Rück- und Navigationsaktionen bleiben verbunden.
- Betreten und Modusauswahl lösen eine reale, auf 550 ms begrenzte Kamerafahrt aus. Sie beginnt etwas weiter vom vollständig eingepassten Modell entfernt und skaliert den optischen Versatz mit. Reduzierte Bewegung beendet die Kamerafahrt sofort. Die Moduswahl gibt zusätzlich einen bestehenden zustimmenden Gesicht-/Kopfausdruck an den Original-Lumo weiter.

Kartenregeln, Lernstände, Freischaltungen, Rennphysik, Fahrzeugdaten, Main und der Flutter-APK-Pin wurden in diesem Patch nicht verändert.

## Lokale Prüfungen

| Prüfung | Tatsächlich ausgeführtes Ergebnis |
| --- | --- |
| Godot 4.6.3 Import | Keine Parsefehler der neuen Quellen |
| Unveränderte `kart_spatial_menu_regression.gd` | **554 Checks, 5/5 Fälle, PASS, headless** |
| Neue `kart_home_experience_regression.gd` | **223 Checks, 4/4 Fälle, PASS, headless** |

Die 554 Prüfungen sind ausdrücklich der Headless-Zähler ohne die zusätzlichen Screenshot-/Pixelprüfungen des Renderer-Modus. Der neue Test verwendet echte native Touch-Ereignisse: Zeitrennen wählen, Garage öffnen, Gecko-Kart auswählen, zum Hauptmenü zurückkehren und dasselbe gewählte Kart tatsächlich starten. Geprüfte Formate: 1280×720, 412×915, 690×829 und 640×320. Die unveränderte Spatial-Prüfung umfasst zusätzlich 2400×1080 mit Dichte 2,625, vollständige 48-dp-Ziele und echte Projektion der sichtbaren Kartgeometrie/des Fuchskopfes gegen die UI.

Die neuen Tests prüfen außerdem Kameraänderung, eingefrorene Animation bei reduzierter Bewegung, Anwendungs-Pause/Fortsetzen und Wiederverwendung desselben 3D-Viewports. Die Originalprotokolle liegen unter `docs/evidence/kart-home-20261113/`.

## Noch ausstehende sichtbare Abnahme

In dieser lokalen Umgebung steht kein funktionierendes Display für den Godot-Renderer bereit. Es liegen für diesen Patch noch keine lokal gesichteten Rendererbilder und kein APK-/Fold7-Nachweis vor. Der neue Capture läuft nur mit echtem Renderer:

```sh
godot --headless --path . --script res://scripts/tests/kart_home_experience_regression.gd
LUMO_CAPTURE_DIR=/tmp/lumo-kart-home godot --path . --rendering-method gl_compatibility --audio-driver Dummy --script res://scripts/tests/kart_home_experience_capture.gd
```

Erwarteter Marker: `[KartHomeExperienceCapture] PASS`. Der Capture erstellt pro Format Home, laufende Modus-Kamerafahrt, bestätigte Moduswahl, Garage, Home nach Kartwechsel und Rennstart. `home-render.json` enthält tatsächliche Bildgrößen, Renderer und Drawcall-/Primitive-Zähler. Desktopzähler belegen keine Geräte-FPS.

Für den identischen Vergleichspfad auf dem unveränderten `ada5ed81` dürfen die beiden Capture-/Regression-Skripte in diesen Ausgangsstand kopiert und mit `-- --baseline` gestartet werden. Dieser explizite Modus ist im JSON als Baseline gekennzeichnet und liefert keine Bestätigung für die neue Hafenbühne. Die bestehenden Spatial-/Garage-Prüfungen bleiben als zusätzliche Schranken erhalten.
