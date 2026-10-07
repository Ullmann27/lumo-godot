# Lumo Kart – verbindlicher Erweiterungsauftrag vom 05.10.2026

## Auftraggeber, Ausgangspunkt und Schutz des Bestands

Heinz hat den Upload aller zehn Strecken-ZIPs und der gemeinsamen Assets sowie die Beauftragung von Copilot ausdrücklich freigegeben. Er ist mit Opus' bestehender Grafik und dem grundlegenden Fahrgefühl zufrieden. **Diese Grafik nicht ersetzen, vereinfachen oder neu erfinden.** Vorhandene Rennstrecken räumlich und spielerisch erweitern, nicht durch flache Bildkulissen austauschen.

Dieser Referenzimport liegt isoliert auf `codex/track-reference-import-2026-10-05`, ausgehend von Godot `6803426876b6f40f3171c63a51dd2c69237e6720` (PR #13, auf PR #4 aufgebaut). Er ändert keine Laufzeitgrafik, Physik, Figuren, Flutter-Dateien oder Godot-Pins. Kein automatischer Merge nach main, kein produktiver APK-Release und keine Aktivierung von Zahlungen.

Vor jeder Umsetzung aktuelle PRs, Branches und Claims erneut lesen: Godot #4, #6, #7, #8, #13; Flutter `Ullmann27/lumo-lernen` #170, #183, #186, #192, #193, #195 sowie aktuelle Nachfolger. Ältere SHAs in historischen Tickets sind keine Aufforderung zum Zurücksetzen. Sonnet/Luna/Claude-Arbeiten erst prüfen und übernehmen, wenn passend; keine konkurrierenden Änderungen derselben Dateien. Geschlossene Aufgaben nicht pauschal erneut starten. Den bereits geprüften Fahrzeug-Geometriefix aus #13 erhalten.

## Ehrliche Bestandsaufnahme der gelieferten ZIPs

Die unveränderten Original-ZIPs sind **Referenzpakete, keine fertigen 3D-Strecken oder 3D-Bauteile**. Pro Strecke: zwei Versionen desselben Hero-Bildes, zehn gemeinsam wiederverwendete PNG-Icons und sechs Text-/JSON-Dateien, insgesamt 18 Dateien. Das separate Shared-Paket hat 11 Dateien. Es gibt keine GLB-/Blend-/OBJ-Modelle, keine Kollisionen, UV-Sätze, Strecken-Splines oder Mehransichten. Die 120-Punkte-Datei enthält pro Strecke 104 generische `Implement or review track detail ...`-Platzhalter. Das ist kein Nachweis von 120 gestalteten Details. Die vergrößerten Bilder sind resampelte Fassungen, keine zusätzlich modellierten Details.

Originaldateien bleiben zur Nachvollziehbarkeit unverändert. Veraltete ZIP-Anweisungen liegen unter `legacy_reference_notes/` und sind **nicht** der aktive Arbeitsauftrag. Insbesondere die dort erwähnten Quiz-/Lernzonen im Rennen nicht implementieren. Maßgeblich ist dieser aktuelle Auftrag. Track 07 ist das Schneethema; das eingebrannte Skyline-Sprint-Titelbild ist fehlerhaft und darf nicht unbemerkt als korrekte Streckenbeschriftung übernommen werden. Die Bilder enthalten außerdem generierte Beschriftungen/Logos, die nicht automatisch als Lumo-Branding gelten.

`IMPORT_MANIFEST.json`, `SHA256SUMS.txt` und der durch den Import erzeugte `IMPORT_REPORT.json` belegen Archividentität, SHA-256, CRC, Mitglieder und Zielpfade. Laufzeitmodelle müssen erst gebaut und geprüft werden. Original-ZIPs werden als klar bezeichnete GitHub-Referenz-Vorabveröffentlichung gespeichert. Im Repository liegen die Bilder entpackt und dedupliziert unter `docs/design_targets/2026-10-05-tracks/`, nicht automatisch im Android-Export. Gemeinsame Icons nur einmal verwenden.

## Phase 0 – tatsächliche Arbeit zuerst prüfen

Erste Antwort von Copilot: tatsächlicher Agent/Modellname soweit angezeigt, aktueller Basis-SHA, zuständiger Branch, bereits vorhandene Funktionen, bestätigte Lücken und konkrete zu bearbeitende Dateien. Nicht behaupten, ein Modell wie Sonnet 5.5 oder Opus 5.5 Max gewählt zu haben, wenn die Oberfläche dies nicht bestätigt. Kein Modellwechsel oder Tarifkauf zur Umgehung von Limits.

Bestehenden Kart-Controller, Track-Builder, Ressourcen, Materialsystem, KI, Itemzustände, Tests und Host-Brücke anhand echter Pfade kartieren. Den effektiven Godot-Pin in der Flutter-App prüfen; der APK-Inhalt folgt dem Pin, nicht dem neuesten sichtbaren Commit. Aktuelle reale Screenshots/Video einer vollständigen Runde aufnehmen. Vergleich: bestehender Opus-Look ist die Stilbasis; neue Bilder liefern zusätzliche Motive und Detailideen. Was bereits gut und korrekt ist, bleibt erhalten. Eine Abweichung nur mit Vorher/Nachher-Beleg verbessern, keinen pauschalen Grafikumbau starten.

Vor Schreibarbeit einen kleinen CLAIM in Godot #6 bzw. dem zugeordneten Umsetzungs-PR veröffentlichen: Basis-SHA, exakte Dateien, Tests und ausgeschlossene Fremdbereiche. Auf einem separaten Umsetzungszweig arbeiten; den Referenzimport nicht nachträglich zur unkontrollierten Großbaustelle machen.

## Phase 1 – Boost und Richtungsfehler vor zusätzlicher Komplexität

Heinz meldet: Turbo reagiert erst mehrere Sekunden nach Betätigung. Ursache ist noch nicht diagnostiziert. Eingabezeit, tatsächlich angenommenen Itemzustand, Physikbeginn, Geschwindigkeitsänderung, VFX und Audiobeginn gemeinsam protokollieren. Touch-Down, Cooldown, Timer, Animation, asynchrone Signale, Beschleunigung und Frame-Reihenfolge untersuchen. Ein gültiger Boost soll im ersten verfügbaren Physikschritt wirken; keine Animation oder Roulette-Ziersequenz darf einen bereits verfügbaren Boost verzögern. Eine sichtbar gesperrte Taste darf keine versteckte spätere Aktivierung einreihen.

Regressionen: lenken + boosten gleichzeitig, gedrückt halten, Doppeltippen, Pause/Fortsetzen, Neustart, Countdown, leerer Itemslot, Überfahren eines Boostpads, Boost auf Rampe/Looping, verschiedene Bildraten. Keine Behauptung einer gemessenen Smartphone-Latenz ohne Gerätedaten.

Leuchtpfeile und UV-/Effektbewegung anhand der lokalen Streckentangente und tatsächlichen Fahrtrichtung ausrichten. Nicht bloß global um 180 Grad drehen: gebogene, geneigte, gespiegelte und vertikale Segmente sowie gegebenenfalls Rückwärtsvarianten prüfen. Collider, optische Pfeile und angewandter Impuls müssen dieselbe Richtung beschreiben.

## Phase 2 – zehn unterschiedliche, längere echte 3D-Strecken

Erst einen vollständigen hochwertigen Ausbauabschnitt mit Vorher/Nachher-Abnahme liefern, danach dieselben geprüften Bauteil-Schnittstellen für zehn eigenständige Strecken verwenden. Keine zehn Farbvarianten derselben flachen Runde. Vorhandene gute Welten sinnvoll weiterverwenden, Fortschritts-IDs nicht unbegründet austauschen.

| Nr. | Streckenthema | Räumliche Dramaturgie und besondere Bauteile |
| --- | --- | --- |
| 01 | Skyline Sprint / Himmelsstadt | Lange Glasbrücken, schwebende Inseln, Wasserfall-Durchfahrt, Dachterrassenkurve, großer befahrbarer Looping, Landebalkon, sichere und schnellere Linien. |
| 02 | Crystal Canyon Dash | Felsdurchbruch, Kristallhöhle mit Lichtwechsel, Schluchtbrücken, bankierte Haarnadel, Kristallbogen, Sprung über Wasserfall, separater Rückweg auf anderer Höhe. |
| 03 | Jungle Temple Turbo | Tempeltor, Seilbrücke mit stabiler Fahrfläche, Wurzeltunnel, angekündigter Schwingstamm, Steinwalze, mehrstufige Schanzen und Dschungelruinen. |
| 04 | Aqua Harbor Rush | Hafenkais, Leuchtturm, Wellen-/Glastunnel, Schiffsquerung außerhalb der Ideallinie, Dock-Sprung, Wasserbogen mit eigener Fahrbahn, breite nasse Kurven. |
| 05 | Candy Cloud Circuit | Keksinseln, Zuckerstangenstützen, Glasur-Serpentinen, Donut-Looping, weiche Sprungpolster und gut angekündigte klebrige Nebenflächen. Keine Kopie fremder Strecken. |
| 06 | Volcano Night Run | Obsidianbrücken, Lavafälle außerhalb der Fahrspur, beleuchteter Felstunnel, großer Kraterbogen, geneigte Steilkurven und abgesicherte Sprungkanten. |
| 07 | Snow Peak Glide / Schneegipfel | Eishöhle, verschneite Viadukte, Ski-Schanze, lange kontrollierbare Bergabkurve, begrenzte Eisflächen, Schneewehen und gut sichtbare Leitplanken. Titelbildfehler korrigieren. |
| 08 | Galaxy Ringway | Orbitalstation, Asteroidenkulisse, echte Antigravitationssegmente, vollständiger Ring-Looping, Startplattform, klarer Horizont-/Kameraübergang und sichere Auslaufstrecke. |
| 09 | Desert Dune Drift | Sandsteinbögen, Oasenbrücke, Ruinenhof, Dünenüberquerung, breite Driftkurven, angekündigter Sandverwehungsbereich und Sprung über ein trockenes Flussbett. |
| 10 | Learning Lab Circuit / Entdecker-Campus | Wissenschaftstürme, mechanische Tore, Bücher-/Planeten-Dekoration, zwei zusammenführende Routen, Laborbogen und große Spirale. **Nur Kulisse, keine Lernfragen während des Rennens.** |

Jede Strecke bekommt einen nachvollziehbaren Ablauf: Start/Eingewöhnung → Tempowechsel → technischer Abschnitt → großer Höhepunkt → Erholungs-/Überholabschnitt → spannender Zielsprint. Konkrete Länge und Rundenzeit erst aus aktueller Geschwindigkeit und Spieltests festlegen, nicht künstlich durch leere Geraden verlängern. Hindernisse ankündigen; nicht jeden Meter zustellen. Aufhol- und Überholmöglichkeiten ohne garantierten Sieg.

### Echte Entwickler-Bauteile statt Bildattrappen

Fahrbahn als echte 3D-Geometrie mit stabilen Anschluss-Sockets, passendem Maßstab, Oberflächennormalen, UVs, getrennten Collider-Proxys und materialgetreuen mobilen LODs. Ein- und Ausgänge dokumentieren. Loopings benötigen einen durchgängigen befahrbaren Querschnitt, konsistente lokale Aufrichtung/Haftung, Kameraübergänge und Rücksetzlogik; kein dekorativer Ring als falscher Ersatz. Sprungrampe, Flugbahn und Landefläche zusammen testen. Abkürzungen korrekt an Checkpoints und KI-Fahrwege anschließen.

Für Modelle Quelle/Generator, GLB oder vorhandenes natives Ressourcenformat, Maße, Ursprung, Anschlussrichtungen, Materialien, Kollision und LOD-Grenzen dokumentieren. Vorder-/Rück-/Seiten-/Draufansichten und Turntable **aus demselben Modell** rendern. Unabhängig erzeugte widersprüchliche Bilder sind keine konsistenten Modellansichten.

Heinz erwartet über 100 Details je Strecke. Dafür einen konkreten Katalog mit mindestens 100 sinnvoll platzierten Detailinstanzen erstellen: ID, Bauteil/Asset, Sektor, Transform, Funktion, Kollisionsrolle, LOD, Quelle und Prüfstatus. Wiederverwendung ist erlaubt, aber separat ausweisen: Anzahl einzigartiger Bauteile versus platzierte Instanzen. Bloße Checklistenzeilen und umbenannte Duplikate zählen nicht als fertig gestaltete Modelle. Noch fehlende Modelle offen kennzeichnen.

## Phase 3 – Items, Gegner, Fahrzeuge und Klang

Items: vorhandene Mechanik prüfen, dann passende Lumo-Varianten von Turbo-Kristall, Schutzblase, Magnet, Schleimfalle, Energieimpuls und einem räumlichen Sammelobjekt ergänzen. Das Sammelobjekt darf wie ein leuchtendes Lumo-Buch gestaltet sein; eine Aufnahme startet eine kurze, gut lesbare Item-Auswahl im HUD, keine Lernaufgabe. Kostenlose Renn-Item-Zufallsverteilung von Echtgeldkäufen strikt trennen. Gewichte nach Platzierung nachvollziehbar konfigurierbar machen, Tests mit deterministischem Seed.

Extremer Aufholboost: Heinz nennt als Idee einen „10fach-Boost“ für hintere Plätze mit automatischem Lenken. Nicht blind die physische Geschwindigkeit verzehnfachen. Erst begrenztes, überzeugend schnelles Aufholmanöver mit sicherem Fahrkorridor, Kurven-/Sichtweiten-Geschwindigkeitslimit, Hindernisbehandlung, Kollisionsprüfung und sanfter Rückgabe der Kontrolle bauen. Aktivierung bei ungeeigneter Landung/Looping-Einfahrt verhindern oder passend begrenzen. Kein Teleport auf Platz 1 und kein garantiertes Aufholen unabhängig von Leistung. HUD benennt Lenkhilfe und Restdauer deutlich.

KI soll gewinnen wollen: überholen, günstigere Linie wählen, Risiken einschätzen und Items gezielt gegen erreichbare Gegner einsetzen. Leicht/Normal/Schwer getrennt abstimmen, keine allwissenden Treffer oder endlose Trefferketten. Reaktionszeit, Zielwahl, Angriffsfenster, Schutz nach Treffern, Lückenwahl und Rückfallstrategie testen. Härter heißt nicht unfair; Spieler und KI erhalten nachvollziehbare Regeln.

Garage: auswählbare Autos mit nachvollziehbaren Stärken bei Beschleunigung, Kurvenlage, Drift, Gewicht und Boost; Upgrade-Teile und Optik auf bestehendem Design aufbauen. Lumo-Gesicht anhand des App-Fuchses angleichen, insbesondere Verhältnis Pupille/Iris/Auge; andere gelungene Figuren, besonders den Hasen, erhalten. Kein globaler Austausch aller Figuren.

Musik und Effekte kindlicher, lebendiger und variantenreicher: eigenständige fröhliche Melodien, rhythmische Instrumente, kurze Freude-/Sprung-/Boost-Laute, abwechslungsreiche Tonhöhe, begrenzte Wiederholungen und sauberer Mix. Kein kopierter Nintendo-Soundtrack, keine übernommenen Stimmen oder Sounds. UI-, Musik-, Sprache- und Effektlautstärke getrennt; nicht bei jedem gleichzeitigen Pad viermal denselben Ruf stapeln.

## Phase 4 – Lernfortschritt, Lumo Cards und konsistente App-Menüs

Mit dem zuständigen Flutter-/Sonnet-Bearbeiter anhand tatsächlicher Schnittstellen koordinieren. Lernen bleibt der Hauptweg zu Sternen, dauerhaft freigeschalteten Spielen, Autos und Teilen. Lernfortschritt, ausgebbares Sterneguthaben und dauerhafte Freischaltrechte getrennt speichern. Ausgeben in Cards darf ein bereits freigeschaltetes Kart-Spiel nicht wieder sperren. Profiltrennung, Offline-Neustart, Migration, doppelte Ereignisse und abgebrochene Speichertransaktionen testen. Stars in Kart und Cards über dieselbe atomare Buchung verwalten, keine zwei voneinander abweichenden Wallets. Keine produktiven Preise/Schwellen als bereits von Heinz genehmigt ausgeben.

Echtgeld-Ingamekäufe nur als spätere, getrennte Schnittstelle vorbereiten: zunächst deaktiviert/Sandbox, Elternfreigabe und nachvollziehbare Belegprüfung; keine heimliche Produktivzahlung, Kaufaufforderung an Kinder oder zahlungsexklusiver Pflichtvorteil. Lernen soll nicht durch Bezahlen ersetzt werden.

Alle Menüs, Elternbereich, Garage, Streckenwahl, Tests, Dialoge, Lade-/Fehlerseiten und Navigationsleisten im bestehenden dunkelblau/cyan/weißen Glas-/Hologramm-Stil prüfen. Glas darf Kontrast und Lesbarkeit nicht zerstören. Touch-Ziele, Fold-Breiten, Querformat, Schriftvergrößerung und reduzierte Bewegung berücksichtigen.

Den gewünschten IQ-/Denkbereich außerhalb der Rennen mit Lumo und Ideenlampe ergänzen, sofern nicht schon vorhanden. Als spielerische Logik-/Denkaufgaben kennzeichnen, nicht als wissenschaftlich validierten IQ-Test und keine erfundene diagnostische IQ-Zahl ausgeben. Bestehenden Testbereich prüfen, bevor ein zweiter gebaut wird.

## Arbeitsaufteilung und dauerhafte Übergabe

Copilot: zuerst Bestandsprüfung, dann kleine überprüfbare Engineering-Schritte an Boost, Richtungen, modularen Strecken, KI/Items und Datenanschlüssen. Laufende Sonnet-/Claude-Arbeiten nicht duplizieren. Die erste konkrete Reparatur nach einem abgegrenzten Claim umsetzen; nicht wieder nur einen Gesamtplan liefern.

Für Opus 5.5 Max vorbehalten: stilkritische Charakterproportionen und Lumo-Konsistenz, finale Landmarkenkomposition, Material-/Lichtabstimmung, Übergänge und hochwertige visuelle Endabnahme. Das ist eine fachliche Rollenaufteilung, kein Nachweis einer gestarteten Opus-Sitzung. Technische Vorbereitung darf den bestehenden guten Look nicht verschlechtern.

`TRACK_PROGRESS.md` je Etappe führen: tatsächlicher Agent, Datum, Basis-/Ergebnis-SHA, Dateien, fertig/geprüft/offen, bekannte Probleme, Tests und nächste konkrete Opus-Aufgabe. `TRACK_BUILD_ROADMAP.md` mit Abhängigkeiten und aktueller Strecke führen. Die geänderten Einzelteile in Szenen/Code wiederfinden können. Notizen nach jedem sinnvollen Commit in bestehender Koordination verlinken.

## Abnahme und Nachweise

Erst Bestandsaufnahme und Boost-/Richtungsregression, dann ein hochwertiger Referenzabschnitt, anschließend zehn Strecken mit je vollständigem Rundenlauf, KI-Durchfahrt, Checkpoint-/Respawn-/Shortcut-/Pause-/Host-Tests. Echte Szenenbilder aus mehreren Blickwinkeln und Gameplay-Video beilegen. Referenzbilder niemals als Screenshots der fertigen App darstellen.

MultiMesh/Instancing, LOD, Culling, Texturbudget, mobile Material-Fallbacks und Frame-Pacing gegen realen Profiling-Befund optimieren. 60 FPS auf Fold 7 bleiben ein Ziel, kein Ergebnis ohne Gerätetest; Auflösung, Renderprofil, thermische Laufzeit, Durchschnitt und schlechte Frame-Zeiten dokumentieren. Kopflose Tests beweisen keine optische Abnahme.

Nach unabhängigem Review getesteten Godot-SHA an Flutter-Integration übergeben; nur dort Pin und signierte Test-APK mit korrekter Provenienz bauen. Keine bestehenden Tests abschwächen, um grün zu werden. Kein Produktionsmerge ohne Freigabe. Immer trennen: hochgeladen / implementiert / automatisiert geprüft / visuell geprüft / auf Gerät geprüft.
