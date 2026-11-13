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

## Renderer-Abnahme: Stand des ersten Home-Commits

Zum Zeitpunkt des ersten Home-Commits stand in dieser lokalen Umgebung kein funktionierendes Display für den Godot-Renderer bereit. Es lagen daher noch keine gesichteten Rendererbilder und kein APK-/Fold7-Nachweis vor. Der neue Capture läuft nur mit echtem Renderer:

```sh
godot --headless --path . --script res://scripts/tests/kart_home_experience_regression.gd
LUMO_CAPTURE_DIR=/tmp/lumo-kart-home godot --path . --rendering-method gl_compatibility --audio-driver Dummy --script res://scripts/tests/kart_home_experience_capture.gd
```

Erwarteter Marker: `[KartHomeExperienceCapture] PASS`. Der Capture erstellt pro Format Home, laufende Modus-Kamerafahrt, bestätigte Moduswahl, Garage, Home nach Kartwechsel und Rennstart. `home-render.json` enthält tatsächliche Bildgrößen, Renderer und Drawcall-/Primitive-Zähler. Desktopzähler belegen keine Geräte-FPS.

Für den identischen Vergleichspfad auf dem unveränderten `ada5ed81` dürfen die beiden Capture-/Regression-Skripte in diesen Ausgangsstand kopiert und mit `-- --baseline` gestartet werden. Dieser explizite Modus ist im JSON als Baseline gekennzeichnet und liefert keine Bestätigung für die neue Hafenbühne. Die bestehenden Spatial-/Garage-Prüfungen bleiben als zusätzliche Schranken erhalten.

## Folgekorrektur aus dem unabhängigen Review

Die Ränder und Mittelmarkierungen der geschwungenen Küstenstraße skalieren nun entlang ihrer lokalen Basisachsen. Damit bleiben Breite, Höhe und rechtwinklige Querschnitte auch in Kurven erhalten. Die wiederholte Synchronisierung der reduzierten Bewegung schreibt nur noch beim Sichtbarwerden oder beim Wechsel in diesen Modus einen ruhenden Animationszustand. Ausgeblendete Kulissen führen dabei keine Animationsupdates aus.

Die gezielte `kart_home_promenade_regression.gd` wurde zuerst gegen den vorherigen Quellstand ausgeführt und wies beide Fehler nach. Nach der Korrektur besteht sie **11 Checks**: sämtliche statischen Quader ohne Scherung, alle 152 Randsegmente und 26 Mittelmarkierungen mit ihren vorgesehenen Abmessungen sowie sichtbare, ausgeblendete und wechselnde Bewegungszustände. Aufruf:

```sh
godot --headless --path . --audio-driver Dummy --script res://scripts/tests/kart_home_promenade_regression.gd
```

Erwarteter Marker: `[KartHomePromenade] PASS checks=11`. Diese Prüfung liest die tatsächlich erzeugten Transformationsdaten; sie ersetzt weiterhin keine Bildabnahme.

Der vollständige Home-Touch-Pfad wurde nach dieser Folgekorrektur erneut ausgeführt: **223 Checks, 4/4 Formate, PASS, headless**. Das Protokoll liegt in `docs/evidence/kart-home-20261113/home-followup-headless.log`.

Bestandsgrenze: Der geerbte Menüprozess `super._process()` und dessen ältere Hintergrundanimationen wurden nicht umgebaut. Die Anwendungs-Pausenprüfung belegt das Stoppen der neuen Hafenbühne und ihrer Kamerafahrt, keine umfassende Ruhestellung aller bestehenden Garagenprozesse.

## Capture-Metadaten nach dem Rennstart

Der echte Renderer-Lauf `43430078141` erzeugte die sechs neuen 1280×720-Ansichten und die entsprechende Baseline, brach aber jeweils nach dem Rennstart an einem Metadatenzugriff auf die bereits korrekt freigegebene Garage ab. Das war ein Fehler des Capture-Skripts. Die Metadaten werden nun aus dem aktiven Rennzustand gelesen; nur während des Menüs wird eine noch gültige Garagenauswahl verwendet. Der tatsächlich ausgewählte Karttyp wird ebenfalls festgehalten.

Zusätzliche Assertions führen denselben Metadatenpfad ohne Renderer aus und überprüfen die Moduswahl, den Kartwechsel, die tatsächliche Garagenfreigabe und den anschließenden Rennzustand. Ergebnis nach Korrektur: **239 Checks, 4/4 Formate, PASS, headless**; Protokoll `docs/evidence/kart-home-20261113/home-metadata-headless.log`. Diese Prüfung ist ausdrücklich kein Bildnachweis. Die Wartezeiten des Capture-Ablaufs wurden nicht verkürzt.

## Artkorrektur anhand echter Rendererbilder

Die tatsächlichen 1280×720-PNGs von Workflow `43430078141`, Quellstand `01cf063a7c11681b0060430cdb72c16d56a0b061`, wurden mit der gleich aufgenommenen Baseline verglichen. Zusätzlich wurden die Rückkehr mit dem ausgewählten Gecko-Kart und die bestehende Garage geöffnet. Die neue Außenwelt, Moduswahl und klare Sicht auf den Originalfahrer waren erkennbar. Der Lauf ist wegen des oben beschriebenen Capture-Fehlers kein vollständiger Abnahmenachweis für alle vier Formate.

Die Bilder zeigten vier konkrete Artprobleme, die der Folgepatch bearbeitet:

- Die Häuser bestanden überwiegend aus Kästen und ungerahmten Fensterflächen. Sie erhalten sichtbare Fensterrahmen, Kreuzteilungen, Simse und Läden, eigene Türen mit Stufen sowie einzelne Balkone und überdachte Eingänge. Diese Teile bleiben in den bestehenden Material-Batches.
- Die einzelnen Baumkronen wirkten wie einfache Kugeln. Elf Bäume bestehen nun aus 55 gegliederten Kronenteilen mit zwei Blattfarben, zusammengefasst in zwei MultiMeshes.
- Der ursprüngliche Himmelsverlauf blieb im tatsächlich sichtbaren flachen Blickwinkel beige. Der neue Verlauf zeigt Blau bereits im niedrigen Blickwinkel und beschränkt die Wärme auf den Horizont. Niedrigere, bläuliche Fernberge und vier räumliche Wolkengruppen in einem gemeinsamen MultiMesh staffeln die Ferne.
- Der Leuchtturm war oben abgeschnitten; der Originalpavillon lag außerhalb der Ansicht. Die Landmarken stehen weiter hinten und werden kleiner eingerahmt. Der Pavillon zeigt seine originale Vorderseite über einem Steg. Auch der große Loop rückt in die Ferne, damit er nicht mehr am oberen Bildrand abgeschnitten wird.

Die neue Prüfung projiziert die tatsächlichen Meshgrenzen von Leuchtturm und Originalpavillon in die unveränderten vier Produktionskameras. Beide passen vollständig in den jeweiligen Bildausschnitt; ihre projizierten Rechtecke überschneiden sich nicht. Diese geometrische Schranke verhindert erneutes Abschneiden und die Verdeckung des Leuchtturms durch den Pavillon, ersetzt aber keine Prüfung der tatsächlichen Farben, Lichtwirkung und übrigen Szenenüberdeckungen.

Nach dem Artpatch: **251 Checks, 4/4 Formate, PASS, headless** für den vollständigen Home-Ablauf und weiterhin **11 Checks, PASS** für Geometrie und ruhende Kulisse. Protokoll: `docs/evidence/kart-home-20261113/home-art-headless.log`. Zum Zeitpunkt dieses Commits standen die neuen Rendererbilder noch aus. UI-Abmessungen, Kamerafit des Fahrers, native Navigation, Physik und externe Assets wurden durch den Artpatch nicht verändert.

## Bildabnahme des Artpatches

Die echten PNGs aus Renderer-Lauf `43433485068`, Quellstand `b83437ce50b6fc395f56bdcb698aab17e80818f7`, wurden geöffnet: `home`, `mode-transition`, `selected-time-trial`, `garage-selected` und `home-return`, jeweils in 1280×720, 412×915, 690×829 und 640×320. Das sind 20 tatsächlich gesichtete Menübilder. Der blaue Himmel, die gegliederten Häuser und Baumkronen sowie die offene Wasserfläche sind sichtbar. Der Originalfahrer bleibt in den regulären Ansichten groß und frei erkennbar. Modusmarkierung und Rückkehr mit dem tatsächlich ausgewählten grünen Gecko-Kart stimmen in allen vier Größen. Die Zwischenbilder zeigen eine andere Kameraposition ohne Verdeckung des Fahrers durch die UI.

Die sehr kurze 640×320-Ansicht verwendet erwartungsgemäß einen kleinen Bühnenausschnitt zugunsten der bedienbaren Controls. In der Garage ist nach dem Scrollen zur Gecko-Auswahl ein Teil der vorherigen Comet-Karte oben angeschnitten; die ebenso geöffnete exakte Baseline zeigt denselben Zustand. Das ausgewählte Gecko-Kart und seine Beschriftung sind vollständig im Scrollbereich sichtbar.

Grenze der Artabnahme: Fahne und Segel verdecken Teile des Leuchtturms. Auch der Originalpavillon lässt sich in diesen Ausschnitten nicht als vollständig frei sichtbare Landmarke bestätigen. Die erfolgreichen Frustumtests bestätigen nur die geometrische Einpassung. Die Bildprüfung ergab keinen neuen blockierenden Fehler an Figur, Moduswahl oder Navigation. Diese Bilder stammen **vor** der nachfolgenden Renderingkorrektur; deren Darstellung benötigt weiterhin einen eigenen Renderer-Lauf.

## Physische Auflösung der gemeinsamen Home-/Garagenvorschau

Die Prüfung des langsamen Software-GL-Captures zeigte einen produktrelevanten Aufwand: Die bestehende SubViewportContainer-Streckung übernimmt den 1280er logischen UI-Canvas als Vorschaugröße. Vor dieser Korrektur renderte die 412×915-Ansicht dadurch ein 1205×2730 großes 3D-Bild für tatsächlich etwa 388×879 angezeigte Pixel. Das sind rund 9,65-mal so viele Pixel. Dieser Befund stammt aus der unveränderten Produktionsszene, nicht aus einer besonderen Captureauflösung.

Die gemeinsame `kart_garage_menu.gd` passt deshalb ausschließlich `preview_viewport.scaling_3d_scale` an. Sie berechnet die physisch angezeigten Pixel aus Fenstergröße, logischem Viewport und globaler Vorschaufläche. Der größere Faktor beider Achsen erhält die Details bei Rundungsunterschieden; der Faktor ist auf höchstens 1,0 begrenzt. Eine zusammengefasste verzögerte Aktualisierung reagiert sowohl auf Container-/SubViewportänderungen als auch auf Fenstergrößenänderungen. Damit wird auch eine Halbierung des physischen Fensters bei gleichbleibendem logischem Layout erfasst.

Bei identischen synthetischen Safe-Area-Rändern links/rechts 12 und oben/unten 16/20 Pixel ergeben sich für Home und Garage:

| Physisches Fenster | Unveränderte logische Ausgabetextur | 3D-Skalierung | Angeforderte 3D-Zielgröße, gerundet |
| --- | --- | --- | --- |
| 1280×720 | 1256×684 | 1,000000 | 1256×684 |
| 412×915 | 1205×2730 | 0,321992 | 388×879 |
| 690×829 | 1235×1470 | 0,539456 | 666×793 |
| 640×320 | 1386×639 | 0,444444 | 616×284 |

Die Zielwerte sind die im laufenden Godot angeforderten Dimensionen aus Viewportgröße und Skalierungsfaktor; interne Ganzzahlrundung des GPU-Backends ist darin nicht separat gemessen. Die Prüfung toleriert weniger als 1,5 Pixel positive beziehungsweise 0,5 Pixel negative Rundungsabweichung.

Die [offizielle Godot-4.6-Dokumentation zur Auflösungsskalierung](https://docs.godotengine.org/en/4.6/tutorials/3d/resolution_scaling.html) beschreibt bilineare Skalierung für sämtliche Renderer und die Laufzeiteinstellung über `Viewport.scaling_3d_scale`. [SubViewportContainer](https://docs.godotengine.org/en/4.6/classes/class_subviewportcontainer.html) dokumentiert dagegen ganzzahliges `stretch_shrink` und die automatische Größenübernahme bei `stretch=true`. Die gewählte Korrektur erhält diese logische Präsentation und die vorhandenen Inputkoordinaten. Originalkamerafit, Figurenmaße und die vorhandene Profilwahl für MSAA bleiben erhalten, einschließlich 4×MSAA im hohen Profil.

Bewusster Umfang: Die logische Ausgabetextur und ihre 2D-Komposition bleiben groß. Reduziert wird die angeforderte 3D-Auflösung samt deren MSAA-Aufwand; es wird keine Reduktion sämtlicher Texturallokationen behauptet. Es liegen keine gemessenen Android-FPS oder thermischen Werte vor. Bilineares Hochskalieren benötigt eine erneute reale Bildprüfung, insbesondere für die kleinen Details in der Handyansicht.

### Regression und Erhaltungsprüfungen

```sh
godot --headless --path . --audio-driver Dummy --script res://scripts/tests/kart_preview_resolution_regression.gd
```

Ergebnis: **`[KartPreviewResolution] PASS checks=52`**. Die neue Prüfung verwendet die vollständige Produktionsszene und kontrolliert alle vier Größen jeweils in Home und Garage: physische 3D-Zielgröße, 4×MSAA, bilinearen Modus, unveränderte logische Streckung/Inputkoordinaten und den Verzicht auf zusätzliche Supersampling-Skalierung. Außerdem prüft sie 1280×720 → 640×360 → 1280×720 mit unverändertem 1280×720-Canvas und identischer logischer Vorschautextur. Nur die angeforderte 3D-Zielgröße wechselt dabei 1280×720 → 640×360 → 1280×720.

| Erneut ausgeführte Prüfung nach der Renderingkorrektur | Ergebnis |
| --- | --- |
| `kart_preview_resolution_regression.gd` | **52 Checks, PASS, headless** |
| `kart_home_experience_regression.gd` | **251 Checks, 4/4 Fälle, PASS, headless** |
| Unveränderte `kart_spatial_menu_regression.gd` | **554 Checks, 5/5 Fälle, PASS, headless** |
| Unveränderte `kart_nextgen_garage_regression.gd` | **93 Checks, PASS, headless** |

Die Originalprotokolle stehen unter `docs/evidence/kart-home-20261113/preview-resolution-headless.log` und `resolution-{home,spatial,garage}-headless.log`. Die neue Auflösungsprüfung gilt ausschließlich für den aktuellen Produktstand. Die Vergleichsbaseline bleibt exakt `ada5ed81`; weder der Renderingfix noch die neue Auflösungsanforderung werden in sie kopiert. Die bestehenden Capture-/Touch-Abläufe und deren Wartezeiten wurden nicht verändert.
