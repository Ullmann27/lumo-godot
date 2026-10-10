# Lumo Produktion: Fortschritt und sichere Fortsetzung

Stand: 11. Oktober 2026. Der neue Masterauftrag wird in der vorgegebenen Reihenfolge bearbeitet. Die neu bestätigte Originalreferenz `50665.jpg` ergänzt die Moduswahl `50666.gif`. Fertige Modellimporte werden nicht mit einer ausgelieferten App oder einer akzeptierten visuellen Oberfläche gleichgesetzt.

## Ausgangsstand und Arbeitsgrenzen

- **Godot-Ausgangscommit:** `b056d5349c5d111a4c9ca41710681b87585f2d62`, vorhandene Animation aus [PR #51](https://github.com/Ullmann27/lumo-godot/pull/51).
- **Renn-Animationsintegration:** Commit `b840e7e54a961f162d209f01679bb9e8af77fcf6`, [PR #52](https://github.com/Ullmann27/lumo-godot/pull/52), alle vier GitHub-Prüfungen erfolgreich.
- **Menü:** [PR #53](https://github.com/Ullmann27/lumo-godot/pull/53), letzter Commit `2eab464b0bec37163424965bc5fc309b1a434ced`. Alle vier GitHub-Prüfungen erfolgreich.
- **Aktueller Branch:** `computer/lumo-kart-real-loading-2026-10-11`, auf dem geprüften Menüstand aufgebaut, eigenes Arbeitsverzeichnis `lumo-godot-animation`.
- **Flutter:** Der bestehende Rivalen-Checkout enthält noch uncommittete Arbeiten. Diese Dateien werden nicht überschrieben; weitere App-Arbeiten benötigen ein separates eigenes Worktree.
- **Git-Sicherheit:** Keine Force-Pushes, keine automatischen Merges nach `main`, keine Änderung fremder Arbeitsverzeichnisse.
- **Audio:** Sulafat, Sprachprovider und die zugehörigen Einstellungen sind ausdrücklich außerhalb dieser grafischen Integrationsphase.

## Nachweislich implementierte Renn-Animationsintegration

Der normale Kart-Spieler bindet beim Fuchs das vorhandene 65-Knochen-Modell ein. Lenken, Boost, Drift, wirklicher Rampenflug, Treffer, Pause, Ruhemodus, Kart-Neuaufbau und der vorhandene Zieleinlauf erreichen den visuellen Adapter. Während des Ausrollens hält die linke Hand das Lenkrad; die Figur kehrt nach dem Jubel zur Sitzpose zurück.

Geändert wurden `kart_island.gd`, `kart_vehicle.gd`, die beiden vorhandenen Lumo-Animationsskripte, die isolierte Jubelassertion und zwei bestehende CI-Workflows. Hinzu kommen der echte Produktszenen-Test, ein reproduzierbarer Prüf-Runner und eine eng begrenzte Dokumentations-Importgrenze. Details stehen in `docs/design/2026-10-10-kart-animation-integration/README.md`.

Keine Änderungen an Rennphysik, Kollisionen, Lernfunktionen, Save-Schema oder Belohnungsberechnung. Kein zweiter Charakter und kein neuer kostenpflichtiger 3D-Auftrag.

## Tatsächliche Testergebnisse

- **Produktszene:** Headless 2.069 Prüfungen / 0 Fehler; echter GL-Lauf 2.116 Prüfungen / 0 Fehler und 12 Laufzeitscreenshots.
- **Exportiertes PCK:** 2.069 Prüfungen / 0 Fehler ohne Quellprojekt; das native importierte Modell wird geladen.
- **Rampensprung:** Ein wirklicher Sprung und eine Landung; 36 Physikframes in der Luft, kein Gap-Sturz.
- **Kontakt:** Maximal etwa 1,14 mm Abstand zwischen Hand-Anker und Lenkrad-Anker im Produkttest; keine Garantie für Fingerkollisionen.
- **Bestandsregressionen:** Physik, Sprung, Host-/Save-/Reward-Pfad sowie Fahrzeuggeometrie erfolgreich.
- **Animation:** 21 Charakter-, 379 isolierte Kart- und 165 CPU-Prüfungen erfolgreich.
- **Geräteprüfung:** Linux/Godot 4.6.3, Mesa/llvmpipe; kein angeschlossenes physisches Android-/Samsung-Gerät.

Der Fahrzeugtest druckt keinen allgemeinen `PASS`-Marker, sondern die vollständige Zeile `Geometry/colours, shadows, animations, effects, LOD and hysteresis passed`. Ein erster Wrapper-Aufruf scheiterte nur am falsch gewählten Marker; der eigentliche Lauf war sauber. Die isolierte CI-Fixture wurde danach mit korrektem Marker und den neuen Abhängigkeiten erfolgreich geprüft.

Ebenso erzeugte der erste Export ein gültiges PCK, während der Prüf-Wrapper vergeblich einen `PASS`-Marker erwartete. Der neue Runner verwendet den tatsächlichen `savepack`-Marker. Das entstandene Paket bestand anschließend den vollständigen echten Produktszenentest.

## Echte Bild- und Videobelege

Gesichert sind Vorher/Nachher im gleichen Rennen, Lenken links/rechts, Pause, Chase-Kamera mit 1280 × 720 und 640 × 320, Rampensprung, Landung und Zieleinlauf. Das kurze Video besteht aus tatsächlich aufgenommenen Godot-Frames, nicht KI-generierten Bildern. 15 Videobilder pro Sekunde sind die gespeicherte Aufnahmerate, kein Android-FPS-Messwert.

## Referenzmenü und neu bestätigte Detailkorrektur

Der tatsächlich sichtbare Kart-Einstieg gehört Godot: Flutter startet die native Szene, `kart_island.gd` erstellt `kart_garage_menu.gd`. Es wurde keine zweite Moduswahl in Flutter entwickelt.

- **Darstellung:** Fünf native Modusbuttons, große goldene Weiter-Aktion, vorhandenes Original-Weltbild und echte transparente 3D-Vorschau erhalten.
- **Fold-Größen:** Android-Dichte wird in dp berücksichtigt, statt Rohpixel als Bediengrößen zu verwenden. Alle geprüften Hauptaktionen und Moduskarten bleiben mindestens 48 dp groß. Kleine Außendisplays scrollen vollständige Karten; auf den geprüften großen Quer-/Fold-Ansichten passen alle fünf gleichzeitig.
- **Schriftzug:** Skalierbarer zweizeiliger Lumo/Kart-Schriftzug, Gold/Cyan, Stern im o, gezeichnete Zielflaggen und der bestehende Motto-Text. Die Projekt-Schrift wird weiterverwendet; keine Emoji-Flagge und keine neue erfundene Marke.
- **Karten:** Dezente gerundete Glas-Lichtkante, geringere Deckkraft, saubere ursprüngliche Symbole ohne doppelte dunkle Rahmen, eindeutiger Auswahlhaken und korrekt geschriebene kurze deutsche Beschreibungen.
- **Menü-Lumo:** Derselbe vorhandene 65-Knochen-Charakter; echtes `greeting_wave` bei Eintritt und `agree_nod` bei Auswahl. Keine wiederkehrende Begrüßungsschleife; der Ruhemodus lehnt die Geste ab. Keine Änderungen am GLB, Sprachprovider, Profil- oder Belohnungsschema.
- **Safe-Area-Reparatur:** Der zusätzliche Android-Randtest deckte einen echten Platzengpass auf. Die große Queransicht verwendet dort einen kompakteren Header/Footer und 60-dp-Karten. Auf einer 640 × 320-Surface mit Systemrändern entfällt nur die redundante Überschrift, nicht die Moduswahl oder die echte Figur.

### Tatsächliche Tests dieser Menüetappe

- **Neun Layout-/Dichte-/Safe-Area-Fixtures:** 336 Prüfungen, 0 Fehler; Orphan-Nodes vorher/nachher identisch. 360 × 800, 640 × 360, 1280 × 720, 1200 × 896, 2176 × 1812 bei Dichte 2,25, 2316 × 904 bei Dichte 2,5 und 640 × 320; zusätzlich 1280 × 720 und 640 × 320 mit 16/32/16/48-Pixel-Systemrändern.
- **Bestehende Touch-Gesamtprüfung:** 222 Prüfungen, 0 Fehler, inklusive 320 × 568, gespeichertem Rennen, Fortsetzen und dem tatsächlichen fünfstufigen Setup.
- **Echter GL-Menüfluss:** Erfolgreich bei 1280 × 720, 800 × 480 und 640 × 320 mit simulierten Android-Rändern. Cup gewählt, anderes Kart per Touch gewählt, alle Schritte durchlaufen, Rennen mit fünf Gegnern gestartet; kompakter zweiter Durchlauf ebenfalls erfolgreich.
- **Renn-Animationsregression nach Menüanbindung:** 2.069 Prüfungen, 0 Fehler. Der vorhandene tatsächliche Rampensprung und die unveränderten Finish-Fixtures bleiben erfolgreich.
- **Aktuelle Fold-Laufzeitaufnahme und Winken:** Echter Godot-GL-Lauf mit 75 Prüfungen / 0 Fehler; Screenshot 2176 × 1812, Dichte 2,25, sowie 28 echte Menü-Animationsframes bei 1280 × 720. Das daraus erstellte 2,8-Sekunden-Video hat 10 gespeicherte Bilder/s, keinen gemessenen Android-FPS-Wert.
- **Statische Prüfungen:** Projektvalidator 117 PASS / 7 bereits bestehende WARN / 0 FAIL; vier strukturierte Streckenpakete und Sky-Halo-Authoring-Vertrag erfolgreich; `git diff --check` erfolgreich.

Alle neuen Laufzeitnachweise stammen aus Linux/Godot 4.6.3/Mesa-llvmpipe. Die Dichte und Android-Systemränder sind explizite Desktop-Testkonfigurationen. `adb devices -l` zeigte kein angeschlossenes Gerät; eine physische Samsung-Galaxy-Z-Fold-Abnahme wird nicht behauptet.

Die neue CI-Konfiguration prüft das Menü und den vorhandenen StartHero-Touchpfad zusätzlich. Die Menüetappe ist inzwischen selbstständig grün: [Stage 2](https://github.com/Ullmann27/lumo-godot/actions/runs/38090713647/job/114326387579), [Rivalenfeedback](https://github.com/Ullmann27/lumo-godot/actions/runs/38090713899/job/114326388827), [Video Grade](https://github.com/Ullmann27/lumo-godot/actions/runs/38090713780/job/114326388223) und [Fahrzeugregression](https://github.com/Ullmann27/lumo-godot/actions/runs/38090713727/job/114326387885).

**CI-Nachtrag:** Die erste neue Stage-2-Prüfung aus [PR #53](https://github.com/Ullmann27/lumo-godot/pull/53) bestand Import, PCK-Rennanimation, neue Menü-Fixtures, Physik, Save-/I/O-Tests und Pause-Abdeckung. Der echte GL-Menüfluss hatte auf dem GitHub-Renderer eine 318-Pixel-Scrollfläche statt lokal 330 Pixeln; die 322 Pixel hohe Liste passte dort nicht vollständig. Die Produktkarten der systemrandbelegten Queransicht erhalten deshalb 60 statt 62 dp Höhe, weiterhin deutlich über 48 dp. Der Test wartet außerdem fünf statt zwei Frames auf verschachtelte Container-/Font-/Safe-Area-Updates. Keine Assertion wurde abgeschaltet. Die drei anderen CI-Prüfungen des ersten Laufs waren grün.

## Offene Produktionsabnahme

- **Priorität 1:** Repository-/Referenzaudit, Menübesitzer, Fold-Größen, realer Menü-Lumo und die aktuelle Button-/Schriftzugkorrektur sind implementiert, lokal und in GitHub geprüft. Der neue reale Ladepfad ist implementiert und lokal geprüft; dessen eigene GitHub-Abnahme und Android-Integration stehen noch aus.
- **Priorität 2:** Gesichtstauglichkeit separat prüfen. Das aktuelle Modell hat keine Gesichtsmorphs; keine neue Lippen-Synchronisation wird behauptet.
- **Priorität 3:** Sky-Raceway-Bauteile, Looping-Physik und echte Rundenzeit untersuchen. Die neue Renn-Animationsintegration ist kein Beleg für eine fahrbare 50-Sekunden-Strecke.
- **Priorität 4:** Danach Flutter-Lernmodule, neue Rechengrafiken, Profile und Datenbeständigkeit prüfen, ohne offene Schreibcoach- oder Sprachänderungen zurückzusetzen.
- **Priorität 5:** Abgestimmter Godot-Pin, neuer Test-APK-Build, Signatur-/Versionsprüfung und tatsächliche Android-Runtime-Abnahme. Noch keine neue APK erstellt.

## Fortsetzung nach Unterbrechung

Zuerst dieses Dokument und den aktuellen Git-Status lesen. Beide Repository- und PR-Köpfe erneut prüfen. Keine fremden uncommitteten Änderungen übernehmen oder verwerfen. Den eigenen Ladebranch und seine CI sichern, anschließend einen separaten Flutter-Integrationsbranch auf dem neuesten kompatiblen Sprach-/Schreib-/Designstand verwenden. Godot-Pin erst auf den tatsächlich geprüften Ladecommit setzen. Keine neue kostenpflichtige Assetgenerierung.

## Neuer tatsächlicher Ladepfad

`app_boot.gd` lädt die vorhandene Produktszene und das native importierte Lumo-Modell mit `ResourceLoader.load_threaded_request`. Der Balken bildet ausschließlich den gemessenen Engine-Ressourcenfortschritt ab. Er behauptet keine Prozentzahl für die gesamte Initialisierung, und es gibt keine zeitgesteuerten Fantasieprozente oder künstliche Mindestwartezeit.

Die vorhandene Weltgrafik, der gemeinsame Schriftzug und derselbe animierte Kart-Lumo werden wiederverwendet. Portrait- und Fold-Kameras zeigen auch die tatsächlich gerenderten Reifen vollständig. Die kurze Ausblendung und ein temporärer Layer mit dem Original-Weltbild überbrücken den echten `SceneTree`-Szenenwechsel, ohne schwarze Lücke und ohne zweites Menü. `kart_island.gd` überspringt nach diesem vorbereiteten Einstieg das zusätzliche 4,4-Sekunden-Intro; die explizite Intro-Testoption bleibt erhalten.

Bei fehlenden Ressourcen, einem fehlgeschlagenen Übergang oder nach 30 Sekunden gibt es verständliche Fehlertexte, einen echten Wiederholungsbutton und einen Rückweg. Eine Wiederholung verwendet noch laufende Engine-Anfragen statt doppelter Requests. Ruhemodus, vorhandene Audioeinstellungen und Host-Rückkehr bleiben erhalten. Keine Sprachprovider-, Daten-, Belohnungs- oder Fahrphysikänderung.

### Tatsächlich ausgeführte Ladeprüfungen

- **Headless-Produktszene:** 83 Prüfungen / 0 Fehler.
- **Echter GL-Lauf:** 84 Prüfungen / 0 Fehler; vier Layouts und ein Fehlerbild. 360 × 800, 640 × 360, 1200 × 896 und 2176 × 1812 bei Dichte 2,25.
- **Exportiertes PCK ohne Quellprojekt:** 94 Prüfungen / 0 Fehler; tatsächliches importiertes Modell und normaler Szenenrouter.
- **Fehler-/Retry-Abdeckung:** Ungültiges Ziel, kontrolliert abgelaufene Testuhr, tatsächlicher Wiederholungsbutton, Ruhemodus und realer Übergang in das Kart-Menü. Der Timeout-Test wartet nicht künstlich 30 Sekunden; er setzt die Startuhr kontrolliert zurück.
- **Normaler Startmitschnitt:** 48 echte post-draw-Frames, `auto_begin` und `auto_transition` unverändert, kein angehaltener Bereit-Zustand, tatsächlicher Ressourcenfortschritt und natives Menü ohne zweites Intro. Die JSON-Provenienz enthält echte Zeitstempel. Software-Rendering und PNG-Readback verlangsamen diese Aufzeichnung; sie belegt keine Android-Ladezeit oder FPS.
- **Vorheransicht:** Die unveränderten alten Methoden `_show_cover` und `_layout` aus Commit `2eab464` werden mit den echten ursprünglichen Assets im Godot-Renderer ausgeführt. Die alte Navigation wird bewusst nicht ausgeführt, damit die nur einen Frame dauernde Oberfläche aufgenommen werden kann. Dies ist eine angehaltene historische visuelle Fixture, keine Aufnahme des alten normalen Starttimings.
- **Bestandsprüfungen:** Die sechs ursprünglichen Spieleinstiegsbilder und die explizit erzwungene Kart-Intro-Regression erfolgreich; keine Orphan-Nodes im Lade-Regressionslauf.

Die Zahlen der Assertions können zwischen Läufen variieren, weil der Test echte asynchrone Fortschrittsabfragen zählt. Das Erfolgskriterium ist null Fehler, nicht eine künstlich festgelegte Zahl von Polls. Die CI wurde um Quellprojekt- und PCK-Ladeprüfungen erweitert; ein grüner Menülauf ist kein Beleg für diese noch unveröffentlichte Änderung.

## Dauerhafte kreative Arbeitsgrenze

Der Nutzer hat eigenständige kreative und technische Verbesserungen im vorhandenen Produkt erlaubt. Diese dürfen Originaldesign, Lernprofile, Lernstände und Sulafat nicht ersetzen oder gefährden; große Ideen bleiben isoliert und rückgängig machbar. Zuerst Menü, Fold, Animation, Laden und tatsächliche Rennübergänge abschließen. Eine größere lokale Lern-KI beginnt nicht während dieser offenen Integrationsphase. Keine zusätzlichen kostenpflichtigen Aufträge ohne konkrete Freigabe.
