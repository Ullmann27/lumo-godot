# LUMO Technical Art — Integrationsbericht vom 11. November 2026

## Ergebnis und verbindlicher Prüfstand

Sonnenhafens Eingangsviertel, Garage und Original-Lumo sind gemeinsam im vorhandenen Spiel eingebunden. Die Fassadenaufwertung konzentriert sich auf die **ersten ungefähr 150 Streckenmeter**. Garage und Fahrer verwenden weiterhin die bestehenden Fahrzeuge, Auswahlzustände und Originalmodelle. Die neue Darstellung ist im tatsächlichen Godot-Renderer dokumentiert; vollständige Spieler- und Gegnerfahrten sind zusätzlich automatisiert geprüft.

Der gemeinsame **Produktstand ist `b357b2f8decb4b11b0cc45e9fde2b8df5ec9cbe1`**. Der Flutter-Host **`2718f405e69c193d0121c6f6447fe53769d7c803`** bindet genau diesen Godot-Commit über `config/godot-source.json` ein. Daraus wurde **LUMO 0.13.3+2015** erfolgreich gebaut und als CI-Artefakt gesichert. Die Android-Tour und die tatsächliche Aktualisierungsprüfung 2014 → 2015 sind erfolgreich abgeschlossen. Ein zusätzlicher Android-Garagentest läuft gesondert. Eine physische Geräteabnahme oder Veröffentlichung wird daraus nicht abgeleitet.

| Abnahmebereich | Belegter Stand |
|---|---|
| Implementiert und gemeinsam eingebunden | Sonnenhafen-Startviertel, Garage, Original-Lumo in b357 |
| Automatisiert getestet | Alle zwölf Godot-Workflows erfolgreich; native Projektprüfung, 18 Programme der 2014-Abnahme und zusätzlicher Artgate mit sieben Programmen erfolgreich |
| Tatsächlicher Renderer | Linux/X11, Godot 4.6.3, GL Compatibility, Mesa llvmpipe; Vergleichsbilder, Animationsclips und Renderertests geprüft |
| Flutter und APK | `verify-and-build` erfolgreich: vollständige Flutter-Suite, native Gates, APK-Bau, Archivprüfung und Artefaktupload |
| Android-Emulator | Standardtour auf API35/x86_64 bestanden; zusätzliche Garage-/Resume-Probe läuft |
| Aktualisierung 2014 → 2015 | Tatsächliches In-place-Update, Offline-Kart, Neustart und Lernstandkontrollen bestanden |
| Echte Android-/Fold-Hardware | Nicht geprüft; keine FPS-, Temperatur-, Energie- oder RAM-Messwerte |

Integrations-PRs: [Godot #152](https://github.com/Ullmann27/lumo-godot/pull/152) und [Flutter #455](https://github.com/Ullmann27/lumo-lernen/pull/455). Die Arbeit liegt auf eigenen Zweigen; kein Force-Push, kein automatischer Merge nach main und keine Veröffentlichung wurden vorgenommen. Spätere Dokumentationscommits sichern Nachweise, ohne den genannten getesteten Produktstand zu verändern.

## Ausgangsbasis und Originalquellen

Ausgangspunkt war der geprüfte Kandidat **0.13.2+2014**, Godot `207bfbc5377c0f3e8be800854c83ddf2110ac3f6` aus PR #150 und Flutter `696db258693465acfc27d051c9c0874710ac9046` aus PR #451. Vor Änderungen wurden GitHub-Branches, PRs, Commits und CI neu eingelesen. Die damalige Inventur ergab keine neuere abgenommene Integrationsbasis; der ältere konfliktbehaftete Godot-Arbeitszweig #151 wurde nicht als solche übernommen. Bestehende Godot-/Flutter-Architektur und Datenwege bleiben maßgeblich. Verwendet werden **Godot 4.6.3** und in der Host-CI **Flutter 3.44.9**; eine Engine-Migration war nicht erforderlich.

Die zugängliche `Lumo_Referenzmappe_2026-11-03.pdf` wurde tatsächlich gelesen. Visuell geprüft wurden Seite 10 zur Figur sowie Seiten 16–17 zu Sonnenhafen. Drive-Datei: `1bQuAZdoaTk-wCuo5oTfuCt2WDMVhi-R_`; SHA-256: `d29b4e3709765eb7f179bf7094bc2a3a088cd2428760195780544d99a59b636c`. Ergänzend dienten die vorhandenen Flutter-Referenzen `docs/design/2026-10-10-lumo-games/references/50294.png` und `docs/design_targets/2026-10-04/kart/k01_garage.png`, bestehende Szenen und Originalassets.

Die Designseiten sind Gestaltungsvorlagen. Umsetzungsbelege sind ausschließlich die tatsächlichen Rendereraufnahmen. Die Konzeptfigur trägt teilweise andere Kleidung und Proportionen als das bereits ausgelieferte Rennanzug-Modell. Erhalten wurde dieses vorhandene Originalmodell einschließlich Gesicht, Brille, Farben und Silhouette. Die neuen Umgebungsdetails bestehen aus selbst erstellter prozeduraler Geometrie und wiederverwendeten Projektmaterialien; kostenpflichtige Dienste oder neu heruntergeladene Fremdmodelle wurden nicht eingesetzt.

| Bereich | Zustand der 2014-Basis | Originalreferenz | Konkrete Umsetzung | Nachweis |
|---|---|---|---|---|
| Straßenfassaden | Große glatte Straßenflanken, einfache Fenster | Mappe S. 16–17: warme Putzbauten, Steinbögen, blaue Läden | Straßenorientierte Bogenlaibungen, Gesimse, Läden, Fensterbänke und Sockel | [Gemeinsame Rennbilder](evidence/technical-art-20261111/integrated/race/capture.json) bei 18/60/110/160 m |
| Hafen-Erdgeschosse | Einfache Balkone, Türen und Markisen | Dunkle Geländer, Terrakottakästen, blau-creme Stoffe | Handläufe mit Rückläufen, Pflanzkästen, Markisenstreben, warme opake Lampenflächen | [Sonnenhafen-Bericht](evidence/technical-art-20261111/sonnenhafen/README.md) und Hafenbilder |
| Umgebungsbewegung | Bestehende reagierende Hafenattraktionen | Ruhige, lebendige Hafenwelt | Begrenzte Wimpelbewegung mit Annäherungsauslöser und Rückkehr | Sechssekündiger Rendererclip und GL-Lebenszyklusprüfung |
| Garage | Dunkler Boden, wenig Wandtiefe, abrupte Ansichtswechsel | Vorhandene marineblaue Garage mit Cyan-Akzenten | Bodenfelder, Wandgliederung, Werkstattschrank, inszeniertes Podium und geglättete Kamera | [Gemeinsame Garagebilder](evidence/technical-art-20261111/integrated/garage/capture.json) in drei Formaten |
| Original-Lumo | Statischer Sitzclip; Auswahl-Nicker verlor beim Previewwechsel seine Figur | Mappe S. 10 und tatsächlich vorhandener GLB | Kleine Atmung, begrenzter Blick, einmaliges Abfedern und Nicken auf der neuen Vorschau | [Charakterbericht](evidence/technical-art-20261111/character/README.md), Bildpaare, Clips und Knochenprüfungen |

## Sonnenhafen: Umsetzung und räumliche Grenzen

Das wiederverwendbare Fassadenset ergänzt vorhandene Häuser und orientiert die Details zu den sichtbaren Straßenseiten. Hausmassen, Dächer und Türme bleiben wiedererkennbar. Besonders bei 18, 60 und 110 Metern sind Bögen, Läden, Balkone und Markisen aus der Produktions-Rennkamera sichtbar. Bei 160 Metern bleibt das Vergleichsbild weitgehend unverändert. Eine vollständige Neugestaltung der gesamten Strecke, des Wassers oder aller Hafenkonstruktionen ist mit diesem Stand nicht abgeschlossen.

Vier gemeinsame opake Materialfamilien trennen Mauerwerk, lackierte Bauteile, Verglasung und Stoff. Die Ergänzung benötigt keine neuen Texturen, transparenten Fensterschichten oder zusätzlichen Lichtquellen. Geometrie wird materialweise in räumlichen 48-Meter-Zellen zusammengefasst und über Entfernung ausgeblendet. HIGH enthält 15 ausgearbeitete Häuser und 95.196 zusätzliche Architekturdreiecke in 24 Oberflächen; LOW neun Häuser und 35.676 Dreiecke in 20 Oberflächen. Diese Zahlen beschreiben ausschließlich das neue Set, nicht die gesamte Szene.

Wimpel liegen in einem gemeinsamen MultiMesh. Ihre Bewegung läuft auf LOW höchstens mit 20 Hz, auf HIGH mit 30 Hz. Ein Annäherungsreiz besitzt getrennte Eintritts-/Austrittsschwellen; die kurze Reaktion klingt zur Ruhebewegung ab. Der bestehende Renncontroller übergibt Zeit, Spielerposition, Rennzustand und reduzierte Bewegung. Pause, beendetes Rennen und reduzierte Bewegung frieren den Zustand ein; außerhalb des festgelegten Entfernungsbereichs werden keine Instanztransformationen aktualisiert.

Die Ergänzungen erzeugen keine Collider. Fahrweg, Looping-/Rampenflächen, Checkpoints und KI-Anfahrten wurden für die Fassadenarbeit nicht verändert. Die Weltprüfung untersucht 26.256 LOW- und 72.864 HIGH-Punkte gegen den Straßenabstand; die kleinsten gemessenen Abstände liegen bei rund 12,315 Metern gegenüber weiterhin geforderten mindestens sieben Metern. Die vorhandene Grenze von 1.400 generierten Instanzen bleibt bestehen. Details und Originalprotokolle stehen im [Sonnenhafen-Nachweis](evidence/technical-art-20261111/sonnenhafen/README.md).

## Garage und Bedienung

Die Fahrzeugpräsentation erhielt gegliederte Wände, einen lesbareren Boden, Werkstattschubladen und Podiumsmarkierungen in der vorhandenen dunkelblauen/Cyan-Gestaltung. Die originalen Fahrzeuge bleiben im Mittelpunkt. Ansichtswechsel werden geglättet; bei reduzierter Bewegung wird die Einstellung berücksichtigt. Schnelle aufeinanderfolgende Fahrzeugwahlen werden auf die tatsächlich zuletzt erzeugte Vorschau zusammengeführt. Erst diese Figur erhält den Auswahl-Nicker. Das Blickziel wird nach der Drehung des Vorschaukarts aktualisiert und anschließend wieder freigegeben.

Ein bei der Prüfung gefundener Eingabefehler wurde behoben: Während einer Kamerabewegung waren die projizierten Plaketten unsichtbar; das Beenden der Bewegung beim Pointerbeginn ließ Sichtbarkeit und Treffercache unsynchronisiert. Der korrigierte Pfad hält diese Ziele tatsächlich bedienbar. Die unveränderte bestehende GL-Touchprüfung besteht mit neun Assertions für Ray-Picker, Fingerfreigabe, fremden Finger, Ziehen, Abbruch sowie emulierte und primäre Maus. Die Präsentationsprüfung umfasst 66 Assertions einschließlich zweier gezielter Kontrollen der Kameraphasen.

Geprüfte Trefferflächen und 2D-Navigation erreichen mindestens 48 × 48 dp in den dokumentierten Display-/Dichtefällen, darunter 904 × 2316 bei Dichte 2,5 und 2176 × 1812 bei 2,25. Dies sind automatisierte Layoutfälle und keine physischen Fold-Geräte. Fahrzeugbestand, Freischaltungen, Eigenschaften und gespeicherte Auswahl bleiben an die vorhandene Logik angeschlossen. Protokolle, Clip und Grenzen enthält der [Garagenbericht](evidence/technical-art-20261111/garage/README.md).

## Lumo: Originalschutz und Animation

`assets/characters/lumo_animated/Lumo-Animated-Mobile.glb` bleibt bytegleich, SHA-256 `3559f700784bc1006905ee3aae01e8bcfbffb95b4f621f7430ce771ba0e3efd5`. Das Modell besitzt ein Mesh, eine Skin, ein Material, 65 Knochen und neun Clips. Es besitzt keine Gesichts-Morphs sowie keine Augen- oder Lidknochen. Blinzeln wurde daher nicht als vorhandene Funktion ausgegeben oder durch eine beliebige Gesichtsverformung ersetzt.

Der bestehende Adapter bleibt alleiniger Besitzer der 30-Hz-Animationszeit. Ein langsamer 3,8-Sekunden-Atemzyklus bewegt Brust und Kopf geringfügig; bei Fahrt ist er schwächer. Der Blick verwendet endliche Weltkoordinaten, geglättete Winkel und Grenzen von 0,28 rad seitlich beziehungsweise 0,12 rad vertikal. Ein Ziel hinter der Figur führt zur Vorwärtspose. Die Landereaktion dauert 420 ms und startet einmalig beim bereits vorhandenen Übergang von Luft zu Boden. Wiederholte Bodensamples lösen sie nicht erneut aus.

Pause hält Pose und Zeit an. Reduzierte Bewegung deaktiviert die sekundären Überlagerungen und verwirft ausstehende Landereaktionen. Originale Nicker-/Erfolgsclips, Sitzbeine und Lenkradkontakte bleiben erhalten. Vier lokale Prüfprogramme enthalten zusammen 3.618 erfolgreiche Assertions; das sind keine 3.618 unabhängigen Testfälle. Der größte gemessene Hand-Ankerabstand beträgt rund 1,150 mm. Die eigens ergänzte Aufmerksamkeits-/Landungsprüfung besteht auch im gemeinsamen Gate mit 1.843 Assertions und null Fehlern.

## Automatisierte Integration und APK

Für b357 wurden **zwölf von zwölf Godot-Workflows erfolgreich** neu abgerufen. Die [native Abnahme 43023920936, Job 130533693167](https://github.com/Ullmann27/lumo-godot/actions/runs/43023920936/job/130533693167) umfasst Projekt-/Gameplay-Prüfungen, `tools/validate_2014.sh` mit 18 Programmen und den ergänzenden `tools/validate_technical_art.sh` mit sieben Programmen. Bestehende Prüfungen werden dabei wiederverwendet; ihre Assertions wurden nicht zum Erreichen eines grünen Laufs gelockert.

Die Spielerprüfung durchfährt die Produktionsszene mit Steuereingaben: **zwei vollständige Runden, vier Sprünge, vier Landungen, zwei Loopings und null Rücksetzungen**, bei 16 Checkpoints. Sechs Gegnerfelder ergeben **30 abgeschlossene Zweirundenfahrten**. Ihre protokollierten Ereignisse enthalten insgesamt 22 Loopingdurchfahrten und 120 Landungen, ohne fehlgeschlagene Loopings, Flugrettungen oder Stillstandsfenster. Nicht jeder Gegner wählt bei jeder Gelegenheit den Looping. Diese Resultate stammen aus den ausgeführten Fahrprüfungen, getrennt von den gestellten Vergleichsbildern. Der [native Ergebnisdatensatz](evidence/technical-art-20261111/integrated/native-acceptance-ci.json) bewahrt Details und Erfolgsmarker.

Im [Hostlauf 43024454590, Buildjob 130535492985](https://github.com/Ullmann27/lumo-lernen/actions/runs/43024454590/job/130535492985) sind vollständige Flutter-Regression, statische Analyse, Vertragsprüfungen, Gates des exakt gepinnten Godot-Quellstands, APK-Bau, Archivprüfung und Artefaktupload **SUCCESS**. Die Version 0.13.3+2015 ist im tatsächlichen Host-Quellstand verifiziert. Die bestehende Paket-/Signatur- und Nutzerdatenkontinuität erhält zusätzlich ihre eigene Aktualisierungsprüfung; deren Ergebnis wird nicht durch den erfolgreichen Build vorweggenommen.

Die heruntergeladene ARM64-Datei wurde nochmals lokal gehasht: **318.708.477 Bytes**, SHA-256 `3bb833935d47fca64efeceb753a48f663d48d3d43b3f02f3e9c798ba9538a4cb`. Paketkennung: `dev.ullmann.lumo.lumo_lernen.coachpreview`; Signaturzertifikat: `a6b1ef61bf59db4e0794c742aeb3b5506d130f4d21175c9975140e6acdb80702`. Beide entsprechen dem bisherigen Familienkandidaten. Das eingebettete Godot-PCK hat SHA-256 `b5a500087a21dbf42f9b0e34deaf5e22b631fbba5831e01155b8f393f6f6b6bc`. Die unveränderten Buildnachweise stehen in [APK-VERIFICATION.json](evidence/technical-art-20261111/integrated/android-build/APK-VERIFICATION.json) und [BUILD-PROVENANCE.json](evidence/technical-art-20261111/integrated/android-build/BUILD-PROVENANCE.json). Dies ist die bestehende Testsignatur, keine behauptete Play-Produktionssignierung.

**Android-Tour bestanden:** [Job 130547247521](https://github.com/Ullmann27/lumo-lernen/actions/runs/43024454590/job/130547247521), API35/x86_64, 21 erfolgreiche Schritte. Der echte Rennstart führt zu 26,78 Metern zusätzlichem Weg und 5,02 Sekunden zusätzlicher Rennzeit. Zwei gespeicherte Pausenzustände bleiben im Drei-Sekunden-Beobachtungsfenster unverändert. Rückkehr zu Flutter, weiterhin bedienbare Lernseite und Neustart bestehen ebenfalls. Keine fatalen Abstürze wurden protokolliert. [Originalergebnis und Screenshots](evidence/technical-art-20261111/integrated/android-tour/tour-result.json) sowie ein separates Provenienzmanifest sind gesichert.

**Update 2014 → 2015 bestanden:** [Job 130553327493](https://github.com/Ullmann27/lumo-lernen/actions/runs/43024454590/job/130553327493) installiert die tatsächliche 2014-Baseline, erzeugt über UI eine richtige Lernantwort mit einem Stern/fünf XP und installiert 2015 mittels `install -r`. Android-userId und firstInstallTime bleiben erhalten. Sieben vorhandene Lernschlüssel, dasselbe Testprofil und die verdienten Werte stimmen nach Update, Offline-Kart, Neustart sowie simulierten Fold-Außen-/Innen- und Querformaten überein. [Originales Updateergebnis](evidence/technical-art-20261111/integrated/android-update/update-result.json) und Artefakthashes sind gesichert. Beide Androidprüfungen verwenden den unveränderten x86_64-Build. Sein PCK-Digest wurde zusätzlich gegen die tatsächlichen aus der ARM64-APK gelesenen PCK-Bytes geprüft; sie sind identisch.

**Begrenzter Android-Prüfumfang:** Die Standardtour tippt nicht auf „Weiterfahren“ und wechselt kein Fahrzeug. Ihre Fold-Umstellungen betreffen Flutter nach der Kart-Rückkehr. Die zusätzliche [Garage-/Resume-Probe in PR456](https://github.com/Ullmann27/lumo-lernen/pull/456) prüft diese Lücke am unveränderten Paket; aktueller Lauf [43032732151](https://github.com/Ullmann27/lumo-lernen/actions/runs/43032732151), Prüfcode `dced87723cdea084f08519a97f9decbcbff03b6b`, ist noch nicht abgeschlossen. Dieser Prüfcode ist nicht die APK-Quelle. Die vollständigen Zwei-Runden-/Looping-/Rampen-/Gegnernachweise oben sind Desktop-Native-Prüfungen. Echte Hardware wurde nicht geprüft.

Der historische native JSON-Snapshot enthält noch den damaligen APK-Status „pending“; maßgeblich für den inzwischen abgeschlossenen Build ist der oben verlinkte Hostjob. Der öffentliche APK-Release ist nicht erstellt. Die verfügbare GitHub-Anbindung bietet keine Release-Erstellung oder Asset-Uploads, die Browser-Sitzung ist abgemeldet. Der normale Actions-Token darf laut [GitHub-API-Dokumentation](https://docs.github.com/en/rest/releases/releases#create-a-release) keinen Release für diesen gegenüber main in Workflowdateien veränderten Zielcommit erstellen. Diese dokumentierte Voraussetzung ist am Sourcevergleich belegt; ein realer 403/404 wurde nicht ausgelöst. Eine lokale, abgesicherte Releasevorbereitung ersetzt die fehlende Veröffentlichungsfähigkeit nicht.

## Rendererbelege und gemessener Aufwand

Der abschließende gemeinsame Vergleich umfasst vier Rennbilder und drei Garageformate auf b357. Umgebung: Godot 4.6.3, Linux/X11, GL Compatibility, Mesa llvmpipe, HIGH. Rennen: 1280 × 720, FOV 55°, identische Kamera-/Spielertransformationen, Seed 2014. Garage: 1280 × 720, 412 × 915 und 690 × 829; FOV 37°, Sitzclip bei 0,3 s und Yaw −0,25. Bildschirm-/Preview-Auflösungen stimmen zu den Baselines; eine gespeicherte Kamerakomponente unterscheidet sich nur um 0,000001.

Ein erster gemeinsamer Renncapture hatte ein leeres Quell-SHA-Feld. Er wurde mit unverändertem Fixture, gesetztem b357-SHA und sauberem Source vor/nach der Aufnahme wiederholt. Alle vier PNG-Hashes sowie Fixture- und Rennskripthashes wurden geprüft. [Provenienz](evidence/technical-art-20261111/integrated/race/provenance.json) und [unabhängige visuelle QA](evidence/technical-art-20261111/integrated/visual-review.md) dokumentieren die Zuordnung.

| Ansicht | Vorher | b357 | Differenz | Zählbereich |
|---|---:|---:|---:|---|
| Rennen 18 m | 350 | 391 | +41 | Gesamter Frame |
| Rennen 60 m | 278 | 313 | +35 | Gesamter Frame |
| Rennen 110 m | 269 | 287 | +18 | Gesamter Frame |
| Rennen 160 m | 250 | 250 | 0 | Gesamter Frame |
| Garage 1280 × 720 | 213 | 147 | −66 | Sichtbarer Preview-SubViewport |
| Garage 412 × 915 | 207 | 138 | −69 | Sichtbarer Preview-SubViewport |
| Garage 690 × 829 | 220 | 150 | −70 | Sichtbarer Preview-SubViewport |

Die Rennen-Zähler stammen aus dem RenderingServer, die Garage-Zähler aus ihrem Vorschau-Viewport. Beide Bereiche sind nicht unmittelbar gegeneinander vergleichbar. Fassadentiefe kostet zusätzlichen Zeichenaufwand; die Garagenansichten benötigen weniger Draw Calls. Daraus folgt keine gemessene Verbesserung der Android-Bildrate.

Zusätzlich liegen echte Animationsclips vor: Wimpel sechs Sekunden/72 Frames bei 960 × 540; Garage 2,4 Sekunden/36 Frames; Lumo vorher/nachher jeweils 7,6 Sekunden/114 Frames bei 1000 × 800 und MEDIUM. Die festen Wiedergaberaten sind keine gemessenen Spiel-FPS. Komponentenclips behalten ihren jeweiligen Aufnahmecommit; sie werden nicht nachträglich als b357-Aufnahmen bezeichnet.

## Reproduzierbarkeit und verbleibende Mängel

Reproduktion erfolgt mit Godot 4.6.3 und importierten Originalassets in einem getrennten Checkout des genannten Commits. `tools/validate_project.sh`, `tools/validate_2014.sh` und `tools/validate_technical_art.sh` sichern die automatisierten Gates. Renderprüfungen benötigen GL Compatibility mit echtem Display oder Xvfb. Eigene XDG-Datenverzeichnisse verhindern Wechselwirkungen mit vorhandenen Spielständen. Rennbilder erzeugt `scripts/tests/kart_technical_art_capture.gd` mit Ausgabeordner, Qualitätsargument `high` und `LUMO_SOURCE_SHA`; Garagebilder erzeugt `scripts/tests/kart_garage_presentation_capture.gd`. Logs, JSONs, Original-PNGs, Clips und Hashmanifeste sind unter `docs/evidence/technical-art-20261111/` gesichert. Die Komponentenberichte erläutern zusätzliche Capture-Helfer und abweichende historische Aufnahmecommits.

Drei getrennte Agenten bearbeiteten Fassaden, Garage und Lumo in eigenen Worktrees; gemeinsame Renncontroller-Anschlüsse und Host-Pins verantwortete der Integrator. Diese Zuständigkeiten vermieden konkurrierende Änderungen an denselben Produktdateien.

Offen bleibt das **vorbestehende Gecko-Schuh-/Karosserie-Clipping**: Ein Original-GL-Seitenframe zeigt den Schuh bereits unter der Karosserie. Original/neu stimmen in der verglichenen Sitzpose für alle 65 Knochen-, Mesh- und Actor-Transformationen überein; die Erweiterung behebt diesen Sitzfehler nicht. Statistiktexte bleiben klein, der neue dekorative Wandslogan ist auf Phone/Fold ebenfalls klein. Im Fold-Bildausschnitt ist nur die erste Fahrzeugkarte sichtbar; die Liste erfordert Scrollen. Der bestehende bunte Menühintergrund bleibt unruhig.

In den geprüften Standbildern wurden keine zusätzlichen offensichtlichen Überschneidungen oder Textabschneidungen gefunden; sämtliche Kamerawinkel und zeitliches Z-Fighting sind damit nicht ausgeschlossen. Blinzeln, eine umfassendere Hafenüberarbeitung sowie reale Android-/Fold-Leistungsabnahme bleiben weitere Arbeit. Der gesicherte Stand ist sichtbar verbessert, integriert und automatisiert spielbar geprüft. Die ursprüngliche Android-Tour und Datenmigration sind bestanden; das Ergebnis der zusätzlichen nativen Garage-/Resume-Prüfung wird separat ausgewiesen.
