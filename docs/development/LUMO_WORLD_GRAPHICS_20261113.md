# LUMO: Winterwelt und Kristall-Resonanzschlucht

Ausgangsbasis: Godot `ada5ed81ad62339f15289da62670c0a4f9f7f2b9`.

## Gestaltung

Die Übertragung betrifft Gestaltungsmethoden, keine fremden Figuren, Assets oder Strecken:

- Nintendos [Entwicklerinterview Teil 2](https://www.nintendo.com/en-gb/News/2025/May/Ask-the-Developer-Vol-18-Mario-Kart-World-Chapter-2-2832717.html) beschreibt zusammenhängende Landschaften, Klimawechsel und Landmarken als verbindende Elemente.
- [Teil 4](https://www.nintendo.com/en-ca/whatsnew/ask-the-developer-vol-18-mario-kart-world-part-4/) erläutert erkennbare Landmarken und intuitive Streckenführung.
- Die [offizielle SEGA-Beschreibung](https://asia.sega.com/SonicRacingCrossWorlds/en/about.html) und der [SEGA-Beitrag zum Gameplay](https://blog.playstation.com/2025/02/12/sonic-racing-crossworlds-gameplay-revealed-new-mechanics-detailed/) zeigen unterschiedliche Rennabschnitte und markante Veränderungen innerhalb einer Runde.

Daraus leitet dieser Patch eine eigene Winterwelt ab: zusammenhängender Bergrücken, eine Eisgalerie auf der bestehenden Rennlinie und ein erkennbarer Seilbahnkomplex. Es wird keine Gleichwertigkeit mit den Referenzspielen behauptet.

## Produktiver Anschluss

`kart_expansion_world.gd` ruft das neue Modul `kart_winter_alpine_world.gd` im tatsächlichen Weltaufbau auf. Der Verlauf der Straße, die Physik und die vorhandene Sprungsequenz werden nicht verändert.

- Sechs beziehungsweise neun gestaffelte Berggipfel mit Schneehauben.
- Zwei eigenständig modellierte Stationen mit Dach, Fenstern, Stützen, Podest, Treppen und warmen Leuchten.
- Eine doppelte durchhängende Seiltrasse mit Trägern und vier bewegten räumlichen Kabinen. Die aufrechten Kabinen verkehren in beide Richtungen in einem einzigen zusätzlichen MultiMesh mit gemeinsamem Mesh. Rennpause, reduzierte Bewegung und ausgeblendete Darstellung halten die Bewegung an.
- Vier breite Eisrippen mit seitlichen Gesteins-/Schneewänden; die bestehende Strecke führt durch ihre freien Öffnungen.
- 174 neue statisch instanzierte Teile im niedrigen, 242 im vollen Detailprofil sowie vier Kabinen in einem gemeinsamen bewegten Mesh; statische Teile nutzen die bestehenden MultiMesh-Batches. Keine zusätzlichen Spielkollisionen oder dynamischen Lichter.

## Kristall-Canyon

Das zweite abgegrenzte Modul, `kart_crystal_resonance_world.gd`, ist an derselben Produktionsstelle angeschlossen. Über eine bestehende Rennpassage entwickelt sich eine zusammenhängende Resonanzschlucht: gestaffelte Gesteinswände mit Mineraladern, ein breites geologisches Felsentor mit hoch sitzender Geode und ein offener Ausblick auf große Kristallformationen. Die Fahrbahn verläuft frei durch das Tor; keine flächige Portaltextur blockiert den Blick. Der Ausbau umfasst 89 beziehungsweise 133 statisch instanzierte Teile (low/full).

## Tatsächliche Prüfung

Godot 4.6.3, echter Headless-Produktionsweltaufbau: `kart_world_expansion_regression.gd` bestand **65 Prüfungen, null Fehler**, beide Welten in beiden Detailprofilen. Je Profil wurden alle 3.447 Winter- beziehungsweise 3.408 Canyon-Fahrbahnsegmente berücksichtigt. Die Prüfung kontrolliert transformierte Meshgrenzen und, bei räumlicher Nähe, insgesamt 6.072 Dreieckgrenzen gegen einen 17 Meter breiten und sechs Meter hohen freien Fahrkorridor. Wiederholter Aufbau und Wechsel zur Laborwelt hinterließen keine zusätzliche Geometrie.

Die Bewegungstests prüfen die tatsächlichen vier CPU-Transformationen, die an das MultiMesh übergeben werden, über 60 Sekunden. Dabei bleiben die Kabinen aufrecht, fahren in Gegenrichtungen und halten bei Rennpause, reduzierter Bewegung und Unsichtbarkeit. Der Headless-Dummy kann MultiMesh-Transformationen nicht aus dem Renderer zurücklesen. Deshalb vergleicht derselbe Test **bei einem echten X11-Lauf zusätzlich alle 480 Transformationen pro Profil mit dem Renderer-Readback**; dieser zusätzliche Nachweis steht bis zum Integrationslauf aus. Der Headless-PASS behauptet ausdrücklich keine grafische Readback-Prüfung.

Alle sechs berührten GDScript-Dateien bestanden `gdlint` und `gdformat --check`. Das Capture-Skript bestand den echten Godot-Compiler. `validate_project.py` ergab 117 PASS, sieben bereits bestehende Warnungen und null Fehler. Der vollständige letzte lokale Funktionslog steht in `docs/evidence/world-graphics-20261113/headless.log`.

`kart_world_expansion_capture.gd` lädt die tatsächliche Kart-Produktionsszene einschließlich Lumo, Kart, HUD und Beleuchtung. Es erstellt drei gestellte Rennansichten und ein Manifest mit Quellstand, Kamera, Bildhash und Renderer. Dieselbe Datei kann auf der Ausgangsbasis ausgeführt werden, da sie keine neuen Modulklassen voraussetzt. Ausgabe: `LUMO_CAPTURE_DIR`; Nutzerverzeichnis: gesondertes `XDG_DATA_HOME`.

**Pixelnachweis in der Integration:** Workflow `43430078141` renderte auf Quelle `01cf063a7c11681b0060430cdb72c16d56a0b061` jeweils drei echte X11/Mesa/GLES-Bilder beider Strecken und derselben Kameras auf der Ausgangsbasis. Alle zwölf Bilder wurden geöffnet und verglichen. Die Winter-Fahransicht zeigt die zusammenhängende Eisgalerie und deren Schatten; die Canyon-Anfahrt und Landmarkansicht zeigen das geologische Tor mit seitlichen Gesteinsstaffeln. Die Ausfahrten bleiben lesbar, einschließlich Leitplanken, Sterne, Kurvenpfeile und Booster. Keine Android-Bildrate, Gerätewärme oder echte gefahrene Runde wird durch diesen statischen Grafiktest behauptet.

Die erste Winter-Landmarkaufnahme war unbrauchbar: Die bestehende Rennstrecke verdeckte die obere Bildhälfte und damit die Bergstation. Die Capture-Kamera wurde deshalb von `base + (-30,12,36)` auf `base + (-14,25,50)` und das Blickziel auf `base + (20,22,-36)` geändert. Sie liegt nun östlich der vollständigen Fahrbahnhülle und über deren Deck. Eine gezielte Probe gegen die tatsächlichen Meshdreiecke reproduzierte mit der alten Position die Verdeckung der oberen Station und zweier Kabinen. Mit der neuen Position sind die Sichtlinien zu beiden Stationsdächern und allen vier Kabinen frei; die Zielpunkte liegen im 1280×720-Bild. Die neue Kamera ist auf beiden Quellen identisch berechenbar und benötigt keine neue Modulklasse. **Die neue Ansicht ist bis zum erneuten echten Renderer-Lauf noch nicht visuell abgenommen.** Die Produktionsgeometrie wurde dafür nicht verändert.


## Integrationskorrektur: tatsächlicher Besitzer der Bewegungszustände

Die Integrationsprüfung fand einen echten Anschlussfehler: Im Rennen liegt die Welt unter `KartIsland/ActiveRace/World`. Die ursprüngliche Bindung an den unmittelbaren Elternknoten erreichte deshalb `paused` und `reduced_motion` nicht. Die ursprüngliche Testfixture hatte diese Zwischenebene unzutreffend ausgelassen.

Die Regression bildet jetzt `ActiveRace` nach. Mit unverändertem altem Code wurde der Fehler reproduziert: 39 Prüfungen, sechs Fehler. Der Fix sucht die jeweils nächsten Vorfahren mit `paused` beziehungsweise `reduced_motion` unabhängig voneinander. Beim Eintritt in den SceneTree wird neu gebunden, weil die Garage ihre Vorschauwelt vor dem Anhängen an Pivot/SubViewport aufbaut. Eine zusätzliche Fixture bildet genau diese zeitliche Reihenfolge und die Menü-/SubViewport-/Pivot-Hierarchie nach; sie prüft auch spätere Einstellungsänderungen.

Danach bestand die vollständige Probe 65 Prüfungen mit null Fehlern. Beide geänderten GDScript-Dateien bestehen Linter und Formatprüfung. Das vorherige Fehlerprotokoll steht als `pause-owner-red.log` neben dem aktuellen `headless.log`. Der nachfolgende Integrationslauf `43430078141` bestand auch die Prüfung mit tatsächlichem Renderer-Readback.

## Capture-Abbau: Audiomischer wirklich freigeben

Der echte Canyon-Capture meldete nach drei gespeicherten Bildern vier noch verwendete Ressourcen, sowohl auf der neuen als auch auf der unveränderten Ausgangsbasis. Die gezielte Headless-Lifecycle-Reproduktion mit `--fixed-fps 60 --verbose` identifizierte genau die beiden Ogg-Musikstreams `garage.ogg` und `sonnenhafen.ogg` samt ihren PacketSequences. Ohne feste beschleunigte Framerate trat der Fehler nicht auf. Die Beobachtung entspricht der asynchronen serverseitigen Playback-Freigabe, die im [offiziellen Godot-Issue #76745](https://github.com/godotengine/godot/issues/76745) beschrieben wird.

Der Capture hält jetzt vor dem Szenenabbau nur schwache Referenzen auf die aktiven Audiowiedergaben fest. Nach dem regulären `queue_free()` wartet er, bis diese tatsächlich verschwunden sind. Kleine 2-ms-Pausen lassen auch bei beschleunigten Frames den Audiomischer arbeiten. Spätestens nach zwei Sekunden führt jede verbleibende Wiedergabe zu Fehler und Exitcode 1; keine Warnung wird unterdrückt. Der PASS-Marker folgt erst nach diesem erfolgreichen Abbau.

Die lokale Reproduktion ist nach dem Fix mit beiden Strecken sauber: keine ObjectDB-/Ressourcen-Leaks. Im ersten korrigierten Canyon-Lauf wurden beide Wiedergaben nach 88 ms freigegeben. Eine absichtlich festgehaltene Wiedergabe löste wie vorgesehen nach der Grenze Exitcode 1 aus. Der normale Capture verweigert Headless weiterhin mit Exitcode 2.

Reproduzierbare **bildlose** Lifecycle-Probe, die die echte Produktionsszene und die Capture-Abfolge ausführt, aber weder PNG noch Bildmanifest schreibt:

```sh
XDG_DATA_HOME=/tmp/lumo-world-capture-lifecycle \
godot --headless --verbose --fixed-fps 60 --rendering-method gl_compatibility \
  --path . --script res://scripts/tests/kart_world_capture_lifecycle_probe.gd \
  -- --track=crystal_canyon
```

`--track=winter_sprint` prüft dieselbe Abfolge für Winter. `views=0` ist in dieser ausdrücklichen Lifecycle-Probe beabsichtigt; sie liefert keinen Pixelnachweis. Die zugehörigen Logs `capture-lifecycle-red.log`, `capture-lifecycle-green.log` und `capture-lifecycle-winter-green.log` liegen unter `docs/evidence/world-graphics-20261113/`. Der anschließende echte X11-Capture muss die drei Bilder und den fehlerfreien Exit erneut gemeinsam nachweisen.
